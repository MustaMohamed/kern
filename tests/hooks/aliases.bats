#!/usr/bin/env bats
# Shell aliases: a Bash command whose head word is an alias that runs git or gh is judged as its
# expansion, read from the Claude Code shell snapshot.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt" >/dev/null 2>&1
  kern_env "$R"
  SNAPS="$HOME/.claude/shell-snapshots"
  mkdir -p "$SNAPS"
  # The shape Claude Code writes for zsh: functions, then `alias -- name=value` lines.
  cat >"$SNAPS/snapshot-zsh-1791935887205-ewlszo.sh" <<'SNAP'
# Snapshot file
unalias -a 2>/dev/null || true
git_current_branch () {
	command git rev-parse --abbrev-ref HEAD
}
alias -- g=git
alias -- gp='git push'
alias -- gpf!='git push --force'
alias -- gpo='g push origin'
alias -- gcan!='git commit --verbose --all --no-edit --amend'
alias -- ghpc='gh pr create'
alias -- gst='git status'
alias -- glg='git log --stat'
alias -- gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -d'
alias -- ll='ls -l'
alias -- gbad='git push --force
alias -- gnl=$'git\npush --force'
alias -- gdq="git push --force"
alias -- after-bad='git push --force'
SNAP
}

# all CMD: every guard's decision for CMD.
all() { run_guard "$(bash_payload "$1")"; }

# same ALIAS_CMD EXPANDED_CMD: the full hook output is identical for both.
same() {
  all "$1"
  local a="$output"
  all "$2"
  [ "$a" = "$output" ] || { printf '%s -> %s\n%s -> %s\n' "$1" "$a" "$2" "$output"; return 1; }
}

# snap LINE...: a snapshot holding only LINE..., newer than the setup one, so it is the one read.
snap() {
  printf '%s\n' "$@" >"$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  touch -t 203001010000 "$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
}

# expect DECISION CMD...: every guard together gives DECISION for every CMD.
expect() {
  local want="$1" c
  shift
  for c in "$@"; do
    all "$c"
    [ "$(decision_of "$output")" = "$want" ] || { echo "$c -> $output"; return 1; }
  done
}

# noalias_hook: a copy of the hook that loads no aliases, which is how kern ran before aliases.sh.
noalias_hook() {
  local k="$BATS_TEST_TMPDIR/k"
  rm -rf "$k"
  mkdir -p "$k"
  cp -R "$(kern_root)/hooks" "$k/hooks"
  sed -i.bak '/^\[ "\$TOOL" = Bash \] && aliases_load$/d' "$k/hooks/pre-tool-use"
  ! grep -q '&& aliases_load$' "$k/hooks/pre-tool-use" || return 1
  printf '%s\n' "$k/hooks/pre-tool-use"
}

@test "gpf! origin main is denied like git push --force, in both modes" {
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"kern G1"* ]] || false
  same "gpf! origin main" "git push --force origin main"
  set_autopilot on
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ]
}

@test "gp to a protected branch asks even with push.policy auto" {
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  all "gp origin main"
  [ "$(decision_of "$output")" = ask ]
  same "gp origin main" "git push origin main"
}

@test "each alias is judged exactly like its expansion" {
  same "gst" "git status"
  same "gcan!" "git commit --verbose --all --no-edit --amend"
  same "ghpc --title t --body b" "gh pr create --title t --body b"
  same "gpo +main" "git push origin +main"
  same "gbgd" "LANG=C git branch --no-color -vv | grep ': gone' | cut -c 3- | xargs git branch -d"
  set_autopilot on
  same "ghpc --title t --body b" "gh pr create --title t --body b"
}

@test "the head word is found after assignments and in every simple command of a chain" {
  all "GIT_TRACE=1 gpf! origin feat"
  [ "$(decision_of "$output")" = deny ]
  all "cd /tmp && gpf! origin feat"
  [ "$(decision_of "$output")" = deny ]
  all "echo \$(gpf! origin feat)"
  [ "$(decision_of "$output")" = deny ]
}

@test "a quoted or escaped head word, or an alias in argument position, is not expanded" {
  for c in "'gpf!' origin main" "\\\\gpf! origin main" "echo gpf! origin main"; do
    run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$c\"}")"
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
}

@test "an alias to a command that is not git or gh is unaffected" {
  all "ll /tmp"
  [ "$(decision_of "$output")" = none ]
}

@test "a missing or unreadable snapshot changes nothing" {
  rm -f "$SNAPS"/*.sh
  all "gpf! origin main"
  [ "$(decision_of "$output")" = none ]
  printf 'alias -- gpf!=%s\n' "'git push --force'" >"$BATS_TEST_TMPDIR/snap.sh"
  chmod 000 "$BATS_TEST_TMPDIR/snap.sh"
  KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/snap.sh" all "gpf! origin main"
  [ "$(decision_of "$output")" = none ]
}

@test "malformed alias lines are ignored and the lines after them still count" {
  for c in "gbad origin main" "gnl origin main" "gdq origin main"; do
    all "$c"
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
  all "after-bad origin main"
  [ "$(decision_of "$output")" = deny ]
}

@test "the newest snapshot is read" {
  printf 'alias -- gpf!=%s\n' "'git status'" >"$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  touch -t 203001010000 "$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  all "gpf! origin main"
  [ "$(decision_of "$output")" = none ]
}

@test "the head word is found after zsh's reserved words and redirections, as zsh finds it" {
  local f
  for f in "if % origin main; then :; fi" "! % origin main" "time % origin main" "nocorrect % origin main" \
    "coproc % origin main" "repeat 2 % origin main" "while % origin main; do :; done" "{ % origin main; }" \
    "( % origin main )" "2>&1 % origin main" ">/dev/null % origin main" "> /dev/null % origin main" \
    "X+=1 % origin main" "true && % origin main" "eval % origin main"; do
    all "${f//%/gpf!}"
    [ "$(decision_of "$output")" != none ] || { echo "${f//%/gpf!} -> none"; return 1; }
    same "${f//%/gpf!}" "${f//%/git push --force}"
  done
}

@test "command, builtin, noglob, exec and - are not followed, as zsh does not expand after them" {
  expect none "command gpf! origin main" "builtin gpf! origin main" "noglob gpf! origin main" \
    "exec gpf! origin main" "- gpf! origin main" "nohup gpf! origin main"
}

@test "the original command still counts: an alias cannot hide a git or gh word" {
  snap "alias -- git='git status'" "alias -- gh='gh pr list'" "alias -- sh='git status'"
  expect deny "git push --force origin main" "sh -c 'git push --force origin main'"
  all "gh pr merge 1 --admin"
  [ "$(decision_of "$output")" != none ]
  [ "$(decision_of "$output")" != allow ]
}

@test "an alias command is never allowed unattended, and the investigator still may not run one" {
  kern_env "$BATS_TEST_TMPDIR/wt"
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  all "git push -u origin feat"
  [ "$(decision_of "$output")" = allow ]
  all "gp -u origin feat"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  all "gp -u origin feat"
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(payload PreToolUse '"agent_id":"a1","agent_type":"kern:investigator","tool_name":"Bash","tool_input":{"command":"glg"}')"
  [ "$(decision_of "$output")" = deny ]
}

@test "alias names are encoded one to one, and a chain, a cycle and a self-reference resolve" {
  snap "alias -- a-b='git push --force'" "alias -- a_b='git status'" "alias -- a.b='git status'" \
    "alias -- c1=c2" "alias -- c2=c1" "alias -- s1='s2 origin'" "alias -- s2='s3 --force'" "alias -- s3='git push'" \
    "alias -- git='git --no-pager'" "alias -- l1=l2" "alias -- l2=l3" "alias -- l3=l4" "alias -- l4=l5" \
    "alias -- l5=l6" "alias -- l6=l7" "alias -- l7=l8" "alias -- l8=l9" "alias -- l9=l10" "alias -- l10='git push --force'"
  expect deny "a-b origin main" "s1 main" "git push --force origin main" "l2 origin main"
  expect none "a_b origin main" "a.b origin main" "c1 origin main" "l1 origin main"
}

@test "snapshot text is never run: substitutions, backticks, ; and newlines stay inert" {
  local m="$BATS_TEST_TMPDIR/marks"
  mkdir -p "$m"
  # Every line names a marker file that appears only if kern runs snapshot text.
  snap "touch $m/top" \
    "alias -- h1='git status; \$(touch $m/h1)'" \
    "alias -- h2='git status \`touch $m/h2\`'" \
    "alias -- h3='git status; touch $m/h3'" \
    "alias -- h4='git status" "touch $m/h4'" \
    "alias -- h5=\$'git status\\ntouch $m/h5'" \
    "alias -- h6=\"git status \$(touch $m/h6)\"" \
    "alias -- \$(touch $m/h7)='git status'" \
    "alias -- h8='git status '\\''\$(touch $m/h8)'\\'''" \
    "alias -- h9=git\\ status\\;touch\\ $m/h9" \
    "alias -- h10='git status' ; touch $m/h10" \
    "alias -- h11='git push --force'"
  for c in h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 "h11 origin main"; do
    all "$c"
    [ "$(decision_of "$output")" != error ] || { echo "$c -> $output"; return 1; }
  done
  [ "$(decision_of "$output")" = deny ]
  run ls -A "$m"
  [ -z "$output" ] || { echo "ran: $output"; return 1; }
}

@test "a missing, empty or unparseable snapshot gives exactly the output of a hook with no aliases" {
  local h c out want
  h=$(noalias_hook)
  # NUL bytes, a carriage return alone, and bytes outside ASCII; no alias line.
  printf 'alias\000 -- \001\377=\200\nalias --\nalias -- =x\nalias -- a\rb=git\n\377\376garbage' >"$BATS_TEST_TMPDIR/garbage.sh"
  : >"$BATS_TEST_TMPDIR/empty.sh"
  for s in "$BATS_TEST_TMPDIR/none.sh" "$BATS_TEST_TMPDIR/empty.sh" "$BATS_TEST_TMPDIR/garbage.sh" "$SNAPS"; do
    for c in "gpf! origin main" "git push --force origin main" "git push origin main" "gst" "gh pr create --title t --body b" "ls"; do
      want=$(env KERN_GUARDS= bash "$h" <<<"$(bash_payload "$c")")
      out=$(env KERN_GUARDS= KERN_SHELL_SNAPSHOT="$s" bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload "$c")")
      [ "$out" = "$want" ] || { printf '%s, %s:\n%s\n%s\n' "$s" "$c" "$out" "$want"; return 1; }
    done
  done
}

@test "CRLF, NUL bytes, a long line and 10,000 aliases leave the hook working" {
  {
    printf "alias -- crlf='git push --force'\r\n"
    printf "alias -- nul='git status'\000x\n"
    printf "alias -- long='git status %s'\n" "$(head -c 200000 /dev/zero | tr '\0' a)"
    i=0
    while [ "$i" -lt 10000 ]; do printf "alias -- x%d='git status'\n" "$i"; i=$((i + 1)); done
    printf "alias -- last='git push --force'\n"
  } >"$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  touch -t 203001010000 "$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  expect deny "crlf origin main" "last origin main"
  expect none "long" "x9999" "ls"
  all "nul"
  [ "$(decision_of "$output")" != error ]
}

@test "aliases.sh never aborts a shell under set -eu, and never sets a name outside _KA_" {
  printf "alias -- gpf!='git push --force'\r\n\000\nalias -- 'x'=1\nalias -- \$(id)=git\n" >"$BATS_TEST_TMPDIR/odd.sh"
  for s in "$BATS_TEST_TMPDIR/odd.sh" "$BATS_TEST_TMPDIR/none.sh" "$SNAPS"; do
    run env KERN_SHELL_SNAPSHOT="$s" bash -euc '
      . "$1/hooks/lib/aliases.sh"
      before=$(set | sed -n "s/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p" | sort)
      aliases_load
      alias_expand "ls -l" || true
      alias_expand "" || true
      alias_expand "gpf! origin" || true
      after=$(set | sed -n "s/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p" | sort)
      comm -13 <(printf "%s\n" "$before") <(printf "%s\n" "$after") | grep -v -e "^_KA_" -e "^KERN_ALIASES$" -e "^ALIAS_EXP$" -e "^before$" || true
      echo finished' _ "$(kern_root)"
    [ "$status" -eq 0 ] || { echo "$s: $output"; return 1; }
    [ "$output" = finished ] || { echo "$s: $output"; return 1; }
  done
}

@test "a _KA_ variable from the environment is never an alias" {
  run env _KA_7878='git push --force' bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload "xx origin main")"
  [ "$(decision_of "$output")" = none ]
}
