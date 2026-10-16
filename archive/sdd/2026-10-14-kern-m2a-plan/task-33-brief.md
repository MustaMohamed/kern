### Task 33: Shell-snapshot aliases judged as their git or gh expansion

User decision, 2026-10-13: "Catch them in M2". This removes the 0.2.0 known limit on shell aliases (`CHANGELOG.md`, 0.2.0 "Known limits").

**Files:**
- Create: `hooks/lib/aliases.sh`, `tests/hooks/aliases.bats`
- Modify: `hooks/lib/gitctx.sh` (`git_words`), `hooks/pre-tool-use` (source line, need line, `aliases_load`), `CHANGELOG.md`

**Interfaces:**
- Consumes: `git_words` (M1), which every guard that reads a Bash command calls (G1 to G6, G15, and G18); the strict `need_lists_match` of Task 32; `kern_env`, `make_repo`, `run_guard`, `payload`, `bash_payload`, `decision_of` and `set_autopilot` from `tests/helpers/common.bash`.
- Produces:
  - `hooks/lib/aliases.sh`: `alias_snapshot` (the snapshot to read; `KERN_SHELL_SNAPSHOT` names one for tests; otherwise the newest `snapshot-*.sh` under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/shell-snapshots`; exit 1 when there is none), `aliases_load` (sets one variable `_KA_<hex of the alias name>` per alias that runs git or gh, holding its expansion, and `KERN_ALIASES=1` when there is one; a missing, unreadable or unparseable snapshot sets nothing), `alias_expand SEG` (sets `ALIAS_EXP` to SEG with its head word replaced; exit 1 when the head word is no such alias).
  - `git_words` replaces a record whose head word is such an alias by its expansion and splits that again, so G1 to G6 and G15 judge `gpf! origin main` exactly as `git push --force origin main`.
  - Parse rules: lines `alias [--] name=value`; value a bare word, single-quoted text with `'\''` for a quote, or backslash escapes. Skipped: a value in `$'...'` or double quotes, an unclosed quote, a name holding a quote, a slash, a `$`, a backtick or a byte outside printable ASCII. The head word is the first word after `NAME=value` words. Expansion follows zsh: when the expansion's head word names another alias, that alias's value replaces it (zsh re-expands a replacement's head word), each name at most once and at most 8 times, resolved when the table is built. Inside `git_words`, the expansion's own words are not expanded again.
  - Not followed (accepted limits, recorded in the contract): the snapshot a session sourced is not named by the hook input or the environment, so the newest snapshot stands in for it; zsh's trailing-space rule (an alias whose value ends in a space also expands the next word); aliases inside an expansion other than its head-word chain; global aliases (`alias -g`); `$'...'` values; an alias after an assignment word that holds a quote or a `$`.
- Measured on this machine (2026-10-14, Claude Code 2.1.296, zsh):
  - The Bash tool runs each call as `/bin/zsh -c source <snapshot> 2>/dev/null || true && ... eval ...`. zsh expands aliases in a non-interactive shell, and `eval` parses after the snapshot defined them, so they run.
  - Snapshots are named `snapshot-zsh-<epoch ms>-<6 chars>.sh`, one per Claude Code process, written about 33 s after the process started. This session's was the oldest of 12 on disk, two days younger than the session, so "newest" is not "this session's".
  - The hook input carries no snapshot path, and the environment has `CLAUDE_CODE_SESSION_ID` but no snapshot path.
  - All 12 snapshots had identical alias tables (sha of their `alias` lines): 248 aliases, of which 201 run git or gh.
- Cost, measured as the median of 30 runs of `hooks/pre-tool-use` on that 248-alias snapshot under macOS bash 3.2: +12 ms for a command with no alias, +19 ms when an alias is expanded, against a 50 ms budget. No cache is needed. A table held in variables keeps lookups in the shell: a first draft that searched one 10 KB string per record cost +90 ms.

- [ ] **Step 1: Write the failing tests**

`tests/hooks/aliases.bats`:

```bash
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: `tests/run-bats tests/hooks/aliases.bats`
Expected: tests 1 to 4 and 8 fail (the alias gets no vote); 5, 6, 7 and 9 pass, since they assert no vote, which already holds.

- [ ] **Step 3: Write `hooks/lib/aliases.sh`**

```bash
# shellcheck shell=bash
# Shell aliases the Bash tool's shell defines. Claude Code runs each Bash call as
# `zsh -c 'source <shell snapshot> && eval <command>'`, so an alias such as gp='git push' runs git
# with no git word in the command. kern reads the alias table from the shell snapshot, keeps the
# aliases that run git or gh, and git_words judges such an alias as its expansion.
# Needs nothing. aliases_load sets KERN_ALIASES and the _KA_* table; alias_expand sets ALIAS_EXP.

# _ALIASES_AWK: reads a snapshot and prints `<hex of name><TAB>expansion` for each alias whose
# expansion runs git or gh. Lines are `alias [--] name=value`; value is a bare word, single-quoted text with '\''
# for a quote, or backslash escapes. A value in $'...' or double quotes, an unclosed quote, a name
# holding a quote, a slash, a $, a backtick or a byte outside printable ASCII is skipped. The head word is
# the first word after NAME=value words; when it names another alias, it is replaced by that alias's
# value, as zsh re-expands a replacement's head word, each name at most once and at most 8 times.
# shellcheck disable=SC2016 # awk text
_ALIASES_AWK='
BEGIN { for (i = 32; i < 127; i++) HX[sprintf("%c", i)] = sprintf("%02x", i) }
function hex(s,    i, o) { o = ""; for (i = 1; i <= length(s); i++) o = o HX[substr(s, i, 1)]; return o }
function unq(s,    i, j, c, out, n) {
  out = ""; n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == sq) {
      j = index(substr(s, i + 1), sq); if (!j) return "\001"
      out = out substr(s, i + 1, j - 1); i += j + 1
    } else if (c == "\\") {
      if (i == n) return "\001"
      out = out substr(s, i + 1, 1); i += 2
    } else if (c == "\"" || c == "$" || c == "`" || c == " " || c == "\t") {
      return "\001"
    } else { out = out c; i++ }
  }
  return out
}
function head(v,    w, n, k) {
  n = split(v, w, /[ \t]+/)
  for (k = 1; k <= n; k++) {
    if (w[k] == "" || w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    hk = k; return w[k]
  }
  hk = 0; return ""
}
/^alias / {
  line = substr($0, 7)
  if (substr(line, 1, 3) == "-- ") line = substr(line, 4)
  e = index(line, "="); if (e < 2) next
  name = substr(line, 1, e - 1)
  if (name ~ /[^!-~]/ || name ~ /[\/"\\$`=]/ || index(name, sq)) next
  v = unq(substr(line, e + 1))
  if (v == "\001" || v == "") next
  val[name] = v; order[++cnt] = name
}
END {
  for (i = 1; i <= cnt; i++) {
    nm = order[i]; v = val[nm]; split("", seen); seen[nm] = 1
    for (d = 0; d < 8; d++) {
      h = head(v)
      if (h == "" || !(h in val) || (h in seen)) break
      seen[h] = 1
      n = split(v, w, /[ \t]+/); pre = ""; rest = ""
      for (k = 1; k <= n; k++) if (w[k] != "") { if (k < hk) pre = pre w[k] " "; else if (k > hk) rest = rest " " w[k] }
      v = pre val[h] rest
    }
    b = head(v); sub(/.*\//, "", b)
    if (b == "git" || b == "gh") print hex(nm) "\t" v
  }
}'

# alias_snapshot: prints the shell snapshot to read; exit 1 when there is none. KERN_SHELL_SNAPSHOT
# names one (tests). Otherwise the newest snapshot-*.sh under the Claude Code config dir: the hook
# input and environment do not name the snapshot a session sourced, so the newest stands in for it.
alias_snapshot() {
  local f newest=""
  if [ -n "${KERN_SHELL_SNAPSHOT-}" ]; then
    [ -f "$KERN_SHELL_SNAPSHOT" ] && [ -r "$KERN_SHELL_SNAPSHOT" ] || return 1
    printf '%s\n' "$KERN_SHELL_SNAPSHOT"
    return 0
  fi
  for f in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/shell-snapshots/snapshot-*.sh; do
    [ -f "$f" ] && [ -r "$f" ] || continue
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest=$f; fi
  done
  [ -n "$newest" ] || return 1
  printf '%s\n' "$newest"
}

# aliases_load: sets one variable _KA_<hex of name> per alias that runs git or gh, holding its
# expansion, and KERN_ALIASES=1 when there is at least one. Names are hex-encoded because alias names
# hold characters such as ! and - that a variable name cannot; nothing from the snapshot is evaluated.
# A missing, unreadable or unparseable snapshot sets nothing, which changes nothing.
aliases_load() {
  local snap out h v
  KERN_ALIASES=""
  snap=$(alias_snapshot) || return 0
  out=$(LC_ALL=C awk -v sq="'" "$_ALIASES_AWK" "$snap" 2>/dev/null) || return 0
  while IFS=$'\t' read -r h v; do
    case "$h" in '' | *[!0-9a-f]*) continue ;; esac
    printf -v "_KA_$h" '%s' "$v"
    KERN_ALIASES=1
  done <<<"$out"
  return 0
}

# alias_expand SEG: when the head word of the simple command SEG (the first word after unquoted
# NAME=value words) is an alias aliases_load set, sets ALIAS_EXP to SEG with that word replaced by its
# expansion. Exit 1 otherwise. A head word with a quote, a backslash, a $, a backtick or a slash is
# never an alias, as in zsh; an assignment word that holds one of those ends the search.
alias_expand() {
  local rest="$1" pre="" w h c i
  [ -n "${KERN_ALIASES-}" ] || return 1
  while :; do
    rest=${rest#"${rest%%[![:space:]]*}"}
    w=${rest%%[[:space:]]*}
    case "$w" in
      '' | *[\"\'\\\$\`/]*) return 1 ;;
      [A-Za-z_]*=*)
        case "${w%%=*}" in *[!A-Za-z0-9_]*) break ;; esac
        pre="$pre$w "
        rest=${rest#"$w"}
        ;;
      *) break ;;
    esac
  done
  case "$w" in *[!!-~]*) return 1 ;; esac
  h=""
  for ((i = 0; i < ${#w}; i++)); do
    printf -v c '%02x' "'${w:i:1}"
    h="$h$c"
  done
  h="_KA_$h"
  [ -n "${!h-}" ] || return 1
  # shellcheck disable=SC2034 # read by git_words
  ALIAS_EXP="$pre${!h}${rest#"$w"}"
}
```

- [ ] **Step 4: Expand in `git_words` and load in `hooks/pre-tool-use`**

In `hooks/lib/gitctx.sh`, replace the header line `# Shell and git parsing for guards. Needs settings.sh. Reads CWD and KERN_MAIN.` with:

```bash
# Shell and git parsing for guards. Needs settings.sh; uses aliases.sh when it is loaded. Reads CWD and
# KERN_MAIN.
```

and in `git_words`, insert before `printf '%s\n' "$seg"`:

```bash
    # An alias that runs git or gh (aliases.sh) is judged as its expansion, which is split again. The
    # expansion's own words are not expanded again: zsh does not re-expand the alias it is expanding,
    # and the table already followed the head-word chain.
    if [ -z "${_GW_NOALIAS-}" ] && declare -F alias_expand >/dev/null && alias_expand "$seg"; then
      _GW_NOALIAS=1
      git_words "$ALIAS_EXP"
      _GW_NOALIAS=
      continue
    fi
```

`declare -F` keeps `gitctx.sh` usable without `aliases.sh` (`tests/hooks/gitctx.bats` sources it alone).

In `hooks/pre-tool-use`, before the gitctx source line, add:

```bash
# shellcheck source=hooks/lib/aliases.sh
. "$KERN_ROOT/hooks/lib/aliases.sh" || no_lib aliases.sh
```

after the last `need gitctx.sh` line, add:

```bash
need aliases.sh alias_snapshot aliases_load alias_expand
```

and after `kern_enabled || exit 0`, add:

```bash
# The shell's aliases that run git or gh, so git_words judges `gp` as `git push`.
[ "$TOOL" = Bash ] && aliases_load
```

- [ ] **Step 5: Run the tests**

Run: `tests/run-bats tests/hooks/aliases.bats && tests/run-bats tests/hooks && shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/pre-tool-use`
Expected: `9 tests, 0 failures`; then the whole hook suite passes (504 tests in the planning sandbox after the pre-flight fix pass, the pre-tool-use need-list test included); shellcheck prints nothing.

- [ ] **Step 6: Measure the cost**

Run `hooks/pre-tool-use` 30 times on a Bash payload with and without `KERN_SHELL_SNAPSHOT` pointing at the newest real snapshot (`ls -t ~/.claude/shell-snapshots/snapshot-*.sh | head -1`), for `git status` and for `git status && gp origin feat`, and compare medians.
Expected: each added median is under 50 ms. Over it: cache the parsed table in the state dir keyed by the snapshot's path and mtime (G16 already denies tool writes there), and measure again.

- [ ] **Step 7: Changelog and commit**

Add under `## [Unreleased]` in `CHANGELOG.md`: `- Guards judge a Bash command whose first word is a shell alias from the Claude Code shell snapshot, such as gpf!, as the git or gh command it expands to. This removes the 0.2.0 known limit on shell aliases; the newest snapshot stands in for the session's, which the hook input does not name.`

```bash
git add -- hooks/lib/aliases.sh hooks/lib/gitctx.sh hooks/pre-tool-use tests/hooks/aliases.bats CHANGELOG.md
git commit -m "M2: judge shell-snapshot aliases as the git or gh they run" -m "An alias such as gpf!='git push --force' ran git with no git word in the command, so every git guard missed it; the user asked for it in M2."
```

---

