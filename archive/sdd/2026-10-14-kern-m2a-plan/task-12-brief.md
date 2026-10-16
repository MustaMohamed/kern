### Task 12: Guard G18, the read-only investigator

**Files:**
- Read first: `docs/spikes/m1-payloads.md` (M1), line `agent_type in subagent PreToolUse: kern:investigator`
- Create: `hooks/guards/g18-readonly-agent.sh`
- Modify: `hooks/pre-tool-use` (`KERN_GUARD_IDS`), `docs/spikes/m1-payloads.md` (one line), `CHANGELOG.md`
- Test: `tests/hooks/g18.bats`

**Interfaces:**
- Consumes (M1): the dispatcher `hooks/pre-tool-use` sets `TOOL`, `AGENT` (from `agent_type`, empty when absent) and `TOOL_INPUT`, sources every `hooks/guards/*.sh`, calls `guard_<id>`, and fails closed for an id in `KERN_GUARD_IDS` whose function is missing; `ti_get KEY`; `git_words CMD` (one simple command per line; a `2>&1` stays inside its command, measured); `git_sub CMDLINE` (`<dir><TAB><subcommand><TAB><rest>`); `vote deny G<n> REASON`.
- Produces: `guard_g18` (votes `deny` only; never `allow`, so the normal permission flow still applies to allowed commands) and `g18_allowed SIMPLE_COMMAND` (exit 0 when the command only reads). `G18_AGENTS="kern:investigator"`, the value the M1 spike recorded (path A: the investigator keeps Bash). Denied: anything off the allowlist; a redirect to a file; `$( )` and backticks; git with `-c`, `--config-env`, `-O`, `--open-files-in-pager`, `--output`, `--ext-diff` or `--textconv`; `rg --pre`, `--search-zip` or a `-z` cluster; `file -C` or `--compile`; `sort` with `-o` in any option cluster, `--output` or `--compress-program`; `find -delete`, `-exec`, `-execdir`, `-ok`, `-fprint`, `-fls`; `sed` other than `sed -n` with a script of line numbers and `p` followed only by words that do not start with `-` (pre-flight 1 #1: `sed -n 1p -i a.txt`, `sed -n 1p a.txt -i`, `--in-place=.bak` and `-e 'w /tmp/x'` got no vote, and GNU sed 4.9 rewrote a.txt and wrote /tmp/x); `rg` with `z` in any short-option cluster, such as `-nz`. `uniq` is off the list (its second operand is an output file).

If a later Claude Code stops sending `agent_type`, G18 never fires. The fallback then is path B: set the investigator's tools to `Read, Grep, Glob` (Task 13) and replace its Rule 1 with "You have no shell. When the answer needs git history or a command's output, return NEEDS_CONTEXT naming the exact command for the controller to run."

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bats
# tests/hooks/g18.bats

load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  export KERN_GUARDS=g18
}

# payload AGENT_TYPE COMMAND: a PreToolUse Bash payload; AGENT_TYPE may be empty. COMMAND has no double quotes.
payload() {
  local extra=''
  [ -n "$1" ] && extra=",\"agent_id\":\"a1\",\"agent_type\":\"$1\""
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"}%s}' "$REPO" "$2" "$extra"
}

hook() { run bash "$KERN_ROOT/hooks/pre-tool-use" <<< "$(payload "$1" "$2")"; }
autopilot() { printf 'voice: normal\nsurface: auto\nautopilot: on\n' > "$CLAUDE_PLUGIN_DATA/sessions/s1.state"; }
denied() { [[ "$output" =~ \"permissionDecision\":\ *\"deny\" ]] && [[ "$output" == *"kern G18: "* ]]; }

@test "read commands get no G18 vote" {
  for cmd in 'git log --oneline -5' 'git -C src blame a.txt' 'rg -n foo src' 'ls -la' 'wc -l a.txt' 'find . -name a.txt' 'sed -n 1,5p a.txt' "sed -n '\$p' a.txt" 'sort -rn a.txt' 'file a.txt'; do
    hook kern:investigator "$cmd"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "unexpected vote for: $cmd"; false; }
  done
}

@test "pipes and stderr to /dev/null stay allowed" {
  hook kern:investigator 'git log --oneline 2>/dev/null | head -n 5'
  [ -z "$output" ]
  hook kern:investigator 'cat a.txt 2>&1 | wc -l'
  [ -z "$output" ]
}

@test "writes and unknown commands are denied" {
  for cmd in 'git commit -m wip' 'git checkout main' 'rm -rf build' 'sed -i s/a/b/ a.txt' 'find . -name x -delete' 'npm test' 'git diff --output=x.patch' 'sort -o out.txt a.txt' \
    'sort -uo out.txt a.txt' 'sort --compress-program=sh a.txt' 'file -C -m magic' 'uniq a.txt out.txt' 'sed -n 1w/tmp/out.txt a.txt' \
    'git -c core.pager=sh log' 'git -c diff.external=sh diff' 'git --config-env=core.pager=X log' 'git grep -Ocat foo' 'git grep --open-files-in-pager=cat foo' 'rg --pre cat foo' \
    'sed -n 1p -i a.txt' 'sed -n 1p a.txt -i' 'sed -n 1p --in-place=.bak a.txt' "sed -n 1p -e 'w /tmp/x' a.txt" 'rg -nz foo'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}

@test "a file redirect is denied" {
  hook kern:investigator 'git log > out.txt'
  denied
  hook kern:investigator 'echo hi >> notes.txt'
  denied
}

@test "a denied command anywhere in a chain denies the call" {
  hook kern:investigator 'git log -1 && git push origin main'
  denied
}

@test "other agents and the main session get no G18 vote" {
  hook '' 'rm -rf build'
  [ -z "$output" ]
  hook kern:implementer 'rm -rf build'
  [ -z "$output" ]
}

@test "autopilot changes nothing for G18" {
  autopilot
  hook kern:investigator 'git log --oneline -5'
  [ -z "$output" ]
  hook kern:investigator 'git commit -m wip'
  denied
}

@test "the dispatcher lists g18 among the guards it expects" {
  grep -q '^KERN_GUARD_IDS=".* g18[ "]' "$KERN_ROOT/hooks/pre-tool-use"
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/hooks/g18.bats`
Expected: the deny tests and the dispatcher-list test fail (no guard `g18` exists); the no-vote tests pass.

- [ ] **Step 3: Write `hooks/guards/g18-readonly-agent.sh`**

```bash
# shellcheck shell=bash
# shellcheck disable=SC2154  # TOOL and AGENT are set by hooks/pre-tool-use
# G18: kern's read-only agents may run only allowlisted read commands in Bash.
# Sourced by hooks/pre-tool-use, which sets TOOL, AGENT and TOOL_INPUT and provides ti_get, git_words,
# git_sub and vote. G18_AGENTS holds the agent_type the M1 spike recorded for the investigator.
G18_AGENTS="kern:investigator"

# g18_allowed SIMPLE_COMMAND: exit 0 when the command only reads.
g18_allowed() {
  local c w1 sub w
  c=$(printf '%s' "$1" | sed -e 's/[0-9]*>&[0-9]//g' -e 's#[0-9]*>[[:space:]]*/dev/null##g' -e 's/^[[:space:]]*//')
  case "$c" in *'>'* | *'<('* | *\$\(* | *'`'*) return 1 ;; esac
  w1=${c%%[[:space:]]*}
  case "$w1" in
    git)
      sub=$(git_sub "$c" | cut -f2) || return 1
      case "$sub" in
        log | show | blame | diff | grep | ls-files | ls-tree | rev-parse | rev-list | cat-file | merge-base | describe | shortlog | name-rev) ;;
        *) return 1 ;;
      esac
      # A config value, an external diff, a pager or an output file can run a program or write one.
      for w in $c; do
        case "$w" in -c | -c* | --config-env* | -O* | --open-files-in-pager* | --output* | --ext-diff* | --textconv*) return 1 ;; esac
      done
      ;;
    rg)
      case "$c" in *--pre* | *--search-zip*) return 1 ;; esac
      # -z runs decompression programs, alone or in a cluster such as -nz.
      for w in $c; do
        case "$w" in --*) ;; -*z*) return 1 ;; esac
      done
      ;;
    grep | ls | cat | head | tail | wc | cut | tr | nl | stat | du | pwd | echo | printf | basename | dirname | realpath | cd | true | test | jq | column | cmp | diff | comm) ;;
    file)
      case "$c" in *' -C'* | *--compile*) return 1 ;; esac
      ;;
    sort)
      # -o writes a file, also inside a cluster such as -uo; --compress-program runs a program.
      for w in $c; do
        case "$w" in --output* | --compress-program*) return 1 ;; --*) ;; -*o*) return 1 ;; esac
      done
      ;;
    find)
      case "$c" in *' -delete'* | *' -exec'* | *' -ok'* | *' -fprint'* | *' -fls'*) return 1 ;; esac
      ;;
    sed)
      # Only sed -n with a script of line numbers and p, such as 1,20p or $p, then file names: a later
      # word that starts with - (-i, --in-place, -e 'w file') could write, so it is not allowed.
      printf '%s\n' "$c" | grep -Eq "^sed -n ('[0-9,\$]*p'|\"[0-9,\$]*p\"|[0-9,]*p)( [^ -][^ ]*)*\$" || return 1
      ;;
    *) return 1 ;;
  esac
  return 0
}

guard_g18() {
  [ "$TOOL" = "Bash" ] || return 0
  [ -n "${AGENT:-}" ] || return 0
  case " $G18_AGENTS " in *" $AGENT "*) ;; *) return 0 ;; esac
  local cmd line
  if ! cmd=$(ti_get command); then
    vote deny G18 "read-only agent: the Bash input has no command"
    return 0
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! g18_allowed "$line"; then
      vote deny G18 "$AGENT is read-only; '${line%%[[:space:]]*}' with these arguments is not on its allowlist (git log, show, blame, diff, grep, ls-files; rg, grep, ls, cat, head, tail, wc; find without -exec or -delete; sed -n with line numbers). Ask the controller to run it."
      return 0
    fi
  done <<EOF
$(git_words "$cmd")
EOF
}
```

- [ ] **Step 4: Add the id to the dispatcher**

In `hooks/pre-tool-use`, change the line `KERN_GUARD_IDS="g00 g01 g02 g03 g04 g05 g06 g13 g14 g15 g16"` to:

```bash
KERN_GUARD_IDS="g00 g01 g02 g03 g04 g05 g06 g13 g14 g15 g16 g18"
```

The M1 test "the dispatcher's list of guard ids names every guard file" (`tests/hooks/pre-tool-use.bats`) fails until this line and the guard file agree.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tests/run-bats tests/hooks/g18.bats tests/hooks/pre-tool-use.bats && shellcheck -x -S warning hooks/guards/g18-readonly-agent.sh && shellcheck hooks/guards/g18-readonly-agent.sh`
Expected: g18.bats's 8 tests and every pre-tool-use.bats test pass (bats prints one total for both files, 24 at this point); both shellcheck runs print nothing.

- [ ] **Step 6: Record the path and update the changelog**

Append to `docs/spikes/m1-payloads.md`: `G18 path: A (M2a Task 12): agent_type is kern:investigator, so the investigator keeps Bash behind G18.`
Add under `## [Unreleased]` in `CHANGELOG.md`: `- Guard G18: kern's read-only investigator may run only allowlisted read commands.`

- [ ] **Step 7: Commit**

```bash
git add -- hooks/guards/g18-readonly-agent.sh hooks/pre-tool-use tests/hooks/g18.bats docs/spikes/m1-payloads.md CHANGELOG.md
git commit -m "M2: add guard G18 for the read-only investigator" -m "The investigator needs git history, so read-only is enforced by an allowlist on its Bash calls; git -c, sort -uo and file -C can write or run code and are denied."
```

---

