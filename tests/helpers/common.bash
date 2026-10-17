# shellcheck shell=bash
# Shared bats helpers for kern hook and script tests.

# kern_root: absolute path of the kern repo (two levels above this file).
kern_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P
}

# make_repo DIR: a git repo on main with user config, one commit (README.md), and a bare origin
# at DIR.origin with main pushed and refs/remotes/origin/HEAD set.
make_repo() {
  local dir="$1"
  git init -q -b main "$dir"
  git -C "$dir" config user.name "Test User"
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config commit.gpgsign false
  printf 'readme\n' >"$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -q -m "init"
  git init -q --bare -b main "$dir.origin"
  git -C "$dir" remote add origin "$dir.origin"
  git -C "$dir" push -q origin main
  git -C "$dir" remote set-head origin main >/dev/null
}

# kern_env DIR: isolates HOME and plugin data under the test tmpdir and points CWD at DIR. A
# CLAUDE_CONFIG_DIR from the caller would point kern at a real config folder, so it goes.
kern_env() {
  export HOME="$BATS_TEST_TMPDIR/home"
  unset CLAUDE_CONFIG_DIR
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
  export CLAUDE_PLUGIN_ROOT
  CLAUDE_PLUGIN_ROOT="$(kern_root)"
  mkdir -p "$HOME/.claude" "$CLAUDE_PLUGIN_DATA"
  unset CLAUDE_CODE_ENTRYPOINT
  export CWD="$1"
}

# payload EVENT JSON_FIELDS: a hook input object with session_id test-session and cwd $CWD.
# JSON_FIELDS is the inside of an object, for example '"tool_name":"Bash","tool_input":{...}'.
payload() {
  printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"%s",%s}' "$CWD" "$1" "$2"
}

# bash_payload COMMAND: a PreToolUse payload for the Bash tool. COMMAND must not hold a double quote
# or a backslash; tests that need them write the JSON by hand.
bash_payload() {
  payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}"
}

# tool_payload TOOL FIELDS: a PreToolUse payload whose tool_input object holds FIELDS. Callers pass
# the fields without braces: bash 3.2 brace-expands a literal {"a":1,"b":2} inside "$( )".
tool_payload() {
  payload PreToolUse "\"tool_name\":\"$1\",\"tool_input\":{$2}"
}

# run_guard PAYLOAD [GUARDS]: runs hooks/pre-tool-use with PAYLOAD on stdin.
run_guard() {
  local guards="${2-}"
  run env KERN_GUARDS="$guards" bash "$(kern_root)/hooks/pre-tool-use" <<<"$1"
}

# decision_of OUTPUT: allow|ask|deny; none when OUTPUT is empty, error when OUTPUT holds no decision
# but is not empty (a bash error, for example).
decision_of() {
  local d
  d=$(printf '%s' "$1" | sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p')
  if [ -n "$d" ]; then
    printf '%s\n' "$d"
  elif [ -n "$1" ]; then
    printf 'error\n'
  else
    printf 'none\n'
  fi
}

# parsed_decision OUTPUT: the permissionDecision of OUTPUT as JSON.parse reads it; fails when OUTPUT
# is not valid JSON.
parsed_decision() {
  printf '%s' "$1" | node -e 'const o = JSON.parse(require("fs").readFileSync(0, "utf8"));
    process.stdout.write(o.hookSpecificOutput.permissionDecision)'
}

# hook_file HOOK: hooks/HOOK in the repo, or HOOK itself when it is a path (a test's modified copy).
hook_file() {
  case "$1" in */*) printf '%s\n' "$1" ;; *) printf '%s/hooks/%s\n' "$(kern_root)" "$1" ;; esac
}

# need_list HOOK LIB: the functions that HOOK's `need LIB ...` lines name, sorted, one per line.
need_list() {
  awk -v l="$2" '$1 == "need" && $2 == l { for (i = 3; i <= NF; i++) print $i }' "$(hook_file "$1")" | sort
}

# lib_functions LIB: the functions hooks/lib/LIB defines with `name() {`, sorted, one per line.
lib_functions() {
  sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)() {.*/\1/p' "$(kern_root)/hooks/lib/$1" | sort
}

# hook_libs HOOK: the libraries HOOK sources with a `. "$KERN_ROOT/hooks/lib/X.sh"` line.
hook_libs() {
  sed -n 's|^\. "\$KERN_ROOT/hooks/lib/\([A-Za-z0-9_-]*\.sh\)".*|\1|p' "$(hook_file "$1")"
}

# odd_lib_sources HOOK: lines that load a hooks/lib file in any form but the column-0
# `. "$KERN_ROOT/hooks/lib/X.sh"` that hook_libs reads (indented, `source`, a loop, a variable path).
odd_lib_sources() {
  grep -nE '(^|[;&|[:space:]])(\.|source)[[:space:]].*hooks/lib/' "$(hook_file "$1")" |
    grep -vE '^[0-9]+:\. "\$KERN_ROOT/hooks/lib/[A-Za-z0-9_-]+\.sh"' || true
}

# need_lists_match HOOK: HOOK loads its libraries only in the form hook_libs reads, has need lines for
# exactly those libraries, and each library's need lines name exactly the functions it defines. Prints
# the difference otherwise.
need_lists_match() {
  local libs lib odd
  odd=$(odd_lib_sources "$1")
  [ -z "$odd" ] || { echo "$1 loads a hooks/lib file in a form these checks cannot read: $odd"; return 1; }
  libs=$(hook_libs "$1")
  [ -n "$libs" ] || { echo "$1 has no source line for a hooks/lib library"; return 1; }
  [ "$(printf '%s\n' "$libs" | sort)" = "$(awk '$1 == "need" { print $2 }' "$(hook_file "$1")" | sort -u)" ] ||
    { echo "$1: its need lines and its source lines name different libraries"; return 1; }
  for lib in $libs; do
    [ -n "$(lib_functions "$lib")" ] || { echo "$lib defines no functions"; return 1; }
    [ "$(need_list "$1" "$lib")" = "$(lib_functions "$lib")" ] ||
      { echo "$1, $lib: need list differs from its definitions"; diff <(need_list "$1" "$lib") <(lib_functions "$lib"); return 1; }
  done
}

# set_autopilot on|off: writes the session state the hooks read (tests only; G16 guards real sessions).
set_autopilot() {
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  printf 'voice: normal\nsurface: auto\nautopilot: %s\nsince: 2026-10-12T00:00:00Z\n' "$1" \
    >"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
}

# fake_gh: puts a stub `gh` first on PATH. FAKE_GH_STATES (comma list) answers `pr list`,
# FAKE_GH_RC its exit code, FAKE_GH_ME answers `api user`, FAKE_GH_AUTHOR answers `pr view`.
fake_gh() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat >"$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$*" in
  "pr list"*) [ -n "${FAKE_GH_STATES-}" ] && printf '%s\n' "$FAKE_GH_STATES" | tr ',' '\n'; exit "${FAKE_GH_RC:-0}" ;;
  "api user"*) printf '%s\n' "${FAKE_GH_ME:-me}" ;;
  "pr view"*) printf '%s\n' "${FAKE_GH_AUTHOR:-someone}" ;;
esac
GH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}
