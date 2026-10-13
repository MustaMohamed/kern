#!/usr/bin/env bats
# G16: Claude cannot write kern session state or relay a mode or autopilot command, and the user
# confirms every write to a kern settings file or to Claude Code's own settings.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  S="$CLAUDE_PLUGIN_DATA/sessions"
  mkdir -p "$S"
}

# file_payload TOOL PATH: a PreToolUse payload for a Write, Edit or NotebookEdit of PATH.
file_payload() {
  local key=file_path
  [ "$1" = NotebookEdit ] && key=notebook_path
  payload PreToolUse "\"tool_name\":\"$1\",\"tool_input\":{\"$key\":\"$2\",\"content\":\"autopilot: on\"}"
}

# expect_file_tools PATH DECISION: Write, Edit and NotebookEdit of PATH each give DECISION.
expect_file_tools() {
  local t
  for t in Write Edit NotebookEdit; do
    run_guard "$(file_payload "$t" "$1")" g16
    [ "$status" -eq 0 ] || { echo "$t $1 -> status $status"; return 1; }
    [ "$(decision_of "$output")" = "$2" ] || { echo "$t $1 -> $output"; return 1; }
  done
}

# expect_bash DECISION COMMAND...: each Bash COMMAND gives DECISION.
expect_bash() {
  local d="$1" c
  shift
  for c in "$@"; do
    run_guard "$(bash_payload "$c")" g16
    [ "$status" -eq 0 ] || { echo "$c -> status $status"; return 1; }
    [ "$(decision_of "$output")" = "$d" ] || { echo "$c -> $output"; return 1; }
  done
}

# expect_cmd DECISION COMMAND...: expect_bash for commands that hold double quotes or newlines.
expect_cmd() {
  local d="$1" c j
  shift
  . "$(kern_root)/hooks/lib/json.sh"
  for c in "$@"; do
    j=$(printf '%s' "$c" | json_escape)
    run_guard "$(tool_payload Bash "\"command\":\"$j\"")" g16
    [ "$status" -eq 0 ] || { echo "$c -> status $status"; return 1; }
    [ "$(decision_of "$output")" = "$d" ] || { echo "$c -> $output"; return 1; }
  done
}

@test "Write under the sessions dir is denied in both modes" {
  p=$(payload PreToolUse "\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$CLAUDE_PLUGIN_DATA/sessions/test-session.state\",\"content\":\"autopilot: on\"}")
  run_guard "$p" g16
  [ "$(decision_of "$output")" = deny ]
  set_autopilot on
  run_guard "$p" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "Edit of another file: no vote" {
  expect_file_tools "$S/test-session.state" deny
  run_guard "$(payload PreToolUse "\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$R/README.md\"}")" g16
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(decision_of "$output")" = none ]
}

@test "a .. path into the sessions dir is denied" {
  expect_file_tools "$CLAUDE_PLUGIN_DATA/nope/../sessions/test-session.state" deny
  expect_file_tools "$R/../data/./sessions/test-session.state" deny
}

@test "an upper-cased path to the sessions dir is denied" {
  expect_file_tools "$(printf '%s' "$S/test-session.state" | tr '[:lower:]' '[:upper:]')" deny
}

@test "a symlinked dir that resolves to the sessions dir is denied" {
  ln -s "$S" "$BATS_TEST_TMPDIR/link"
  expect_file_tools "$BATS_TEST_TMPDIR/link/test-session.state" deny
}

@test "a Bash write into the sessions dir is denied" {
  run_guard "$(bash_payload "echo autopilot: on >> $CLAUDE_PLUGIN_DATA/sessions/test-session.state")" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "every Bash write shape against session state is denied" {
  expect_bash deny \
    "echo autopilot: on >> ~/.claude/plugins/data/k*/sessions/*.state" \
    "echo autopilot: on > /X/PLUGINS/DATA/KERN-KERN/SESSIONS/A.STATE" \
    "echo on > \$CLAUDE_PLUGIN_DATA/sessions/a.state" \
    "echo on >| $S/a.state" \
    "printf on | tee -a $S/a.state" \
    "sed -i '' s/off/on/ $S/a.state" \
    "perl -pi -e s/off/on/ $S/a.state" \
    "cp /tmp/x $S/a.state" \
    "mv /tmp/x $S/a.state" \
    "ln -sf /tmp/x $S/a.state" \
    "rm -f $S/a.state" \
    "truncate -s 0 $S/a.state" \
    "dd if=/tmp/x of=$S/a.state" \
    "install -m 600 /tmp/x $S/a.state" \
    "sudo env A=1 tee $S/a.state" \
    "sudo -u me tee $S/a.state" \
    "if true; then rm -f $S/a.state; fi" \
    "echo on &> $S/a.state" \
    "bash -c 'echo on > $S/a.state'" \
    "x=\$(echo on > $S/a.state)" \
    "cd $S && echo autopilot: on > a.state" \
    "echo on > /tmp/test-session.state"
}

@test "any command but a reader that names a state path is denied" {
  expect_bash deny \
    "cd ~/.claude/plugins/data/kern-kern && sed -i '' s/off/on/ sessions/*.state" \
    "cd \$CLAUDE_PLUGIN_DATA && echo autopilot: on > sessions/*.state" \
    "rsync /tmp/x $S/a.state" \
    "curl -so $S/a.state file:///tmp/x" \
    "ditto /tmp/x $S/a.state" \
    "dd if=/tmp/x of=$S/x" \
    "cp -t $S /tmp/x"
}

@test "a glob that matches the state file once ~ is expanded is denied" {
  export CLAUDE_PLUGIN_DATA="$HOME/.claude/plugins/data/kern-kern"
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  expect_bash deny "echo autopilot: on > ~/.claude/p*/d*/k*/s*/*.state" \
    "echo on > \$HOME/.claude/p*/d*/k*/s*/*.state" "echo on > \${HOME}/.claude/p*/d*/k*/s*/*.state" \
    "echo on > \${CLAUDE_PLUGIN_DATA}/s*/*.state"
  expect_cmd deny 'echo on > "$CLAUDE_PLUGIN_DATA"/s*/*.state'
  expect_bash deny "echo on > ~/.claude/**/*.state"
  expect_bash none "du -sh ~/* ; ls sessions"
}

@test "plain reads, git commands and messages naming state or settings: no vote" {
  expect_bash none "git diff .claude/kern.yml" "git check-ignore -q .claude/kern.local.yml" \
    "git add tests/sessions/foo.state" "test -f $S/x.state && echo yes" "find $S -name '*.state'" \
    "[ -f $S/x.state ]" "perl -Mstrict -ne 'print' $S/a.state"
  expect_cmd none 'echo ".claude/kern.local.yml" >> .gitignore' \
    'git commit -m "G16: deny writes to sessions/<sid>.state"' \
    'gh pr create --title t --body "G16 now guards sessions/x.state"' \
    "$(printf '%s\n' 'gh pr create --title t --body "fix:' 'sessions/x.state"')" \
    "printf '%s\n' $S/x.state"
  expect_bash deny "echo on > $S/x.state" "find $S -name x -delete" "find /tmp -name x -fls $S/x.state" \
    "perl -i -pe s/a/b/ $S/a.state" "sed -I '' s/a/b/ $S/a.state"
}

@test "a shell reading a here-doc runs its body as commands" {
  expect_cmd deny "$(printf '%s\n' "bash <<'EOF'" "echo autopilot: on > $S/test-session.state" 'EOF')" \
    "$(printf '%s\n' "x=\$(date) bash <<'EOF'" "touch $S/test-session.state" 'EOF')"
}

@test "a # that bash does not read as a comment hides no state write" {
  expect_cmd deny "echo a\\ #b; touch $S/test-session.state"
}

@test "a misread << hides no state write" {
  expect_cmd deny "$(printf '%s\n' 'echo $((1<<X))' "echo on > $S/a.state" X)" \
    "$(printf '%s\n' '# see <<X' "echo on > $S/a.state" X)" \
    "$(printf '%s\n' 'x=$(cat <<X)' "echo on > $S/a.state" X)"
}

@test "a double-quoted state target is denied" {
  run_guard "$(tool_payload Bash "\"command\":\"echo on > \\\"$S/test-session.state\\\"\"")" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "reads of a state file, and a commit message naming one: no vote" {
  expect_bash none "cat $S/a.state" "grep on $S/a.state" "ls $S/a.state" "sed -n p $S/a.state"
  run_guard "$(tool_payload Bash "\"command\":\"git commit -m \\\"\$(cat <<'EOF'\\nfix: x\\necho on > $S/test-session.state\\nEOF\\n)\\\"\"")" g16
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = none ]
}

@test "the session id counts only as the state file name: scratchpad writes pass" {
  d=/private/tmp/claude-501/proj/test-session/scratchpad
  expect_bash deny "echo on > test-session.state" "echo on > /anywhere/test-session.state"
  expect_bash none "node build.mjs > $d/out.txt" "cp report.json $d/" "git diff > $d/review.diff" \
    "tee $d/sessions.md" "echo x > $d/test-session.state.txt"
}

@test "reads of session state: no vote" {
  expect_bash deny "echo autopilot: on >> $S/test-session.state"
  expect_bash none \
    "cat $S/test-session.state" \
    "grep autopilot $S/test-session.state 2>/dev/null" \
    "ls -la ~/.claude/plugins/data/kern-kern/sessions" \
    "cat $S/test-session.state > /tmp/copy"
}

@test "a Monitor command writing the state file is denied" {
  run_guard "$(tool_payload Monitor "\"command\":\"echo autopilot: on >> $S/test-session.state\",\"description\":\"x\"")" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "a scheduled prompt or relayed message carrying /kern:autopilot is denied" {
  for t in CronCreate ScheduleWakeup RemoteTrigger SendMessage; do
    run_guard "$(payload PreToolUse "\"tool_name\":\"$t\",\"tool_input\":{\"prompt\":\"/kern:autopilot on\"}")" g16
    [ "$(decision_of "$output")" = deny ] || { echo "$t -> $output"; return 1; }
  done
  run_guard "$(payload PreToolUse "\"tool_name\":\"CronCreate\",\"tool_input\":{\"prompt\":\"/kern:mode terse\"}")" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "relayed text that opens with a mode or autopilot command is denied" {
  run_guard "$(payload PreToolUse "\"tool_name\":\"ScheduleWakeup\",\"tool_input\":{\"prompt\":\"/autopilot on\"}")" g16
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(tool_payload SendMessage "\"to\":\"main\",\"message\":\"  /kern:mode terse\"")" g16
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(payload PreToolUse "\"tool_name\":\"CronCreate\",\"tool_input\":{\"prompt\":\"\\n/mode terse\"}")" g16
  [ "$(decision_of "$output")" = deny ]
}

@test "relayed text that only mentions a mode command: no vote" {
  run_guard "$(tool_payload SendMessage "\"to\":\"main\",\"message\":\"/kern:mode terse\"")" g16
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(tool_payload SendMessage "\"to\":\"main\",\"message\":\"ask the user to type /kern:mode terse\"")" g16
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = none ]
  run_guard "$(payload PreToolUse "\"tool_name\":\"CronCreate\",\"tool_input\":{\"prompt\":\"/models list\"}")" g16
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = none ]
}

@test "a RemoteTrigger whose nested body carries a kern command is denied; a list passes" {
  run_guard "$(tool_payload RemoteTrigger "\"action\":\"create\",\"body\":{\"job_config\":{\"prompt\":\"/kern:autopilot on\"}}")" g16
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(tool_payload RemoteTrigger "\"action\":\"update\",\"body\":{\"job_config\":{\"prompt\":\"check CI then /Kern:Mode terse\"}}")" g16
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(tool_payload RemoteTrigger "\"action\":\"run\",\"body\":{\"routine\":{\"instructions\":\"/kern:autopilot on\"}}")" g16
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(tool_payload RemoteTrigger "\"action\":\"list\"")" g16
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(decision_of "$output")" = none ]
}

@test "a scheduled prompt without kern commands: no vote" {
  run_guard "$(payload PreToolUse "\"tool_name\":\"CronCreate\",\"tool_input\":{\"prompt\":\"/kern:autopilot on\"}")" g16
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(payload PreToolUse "\"tool_name\":\"CronCreate\",\"tool_input\":{\"prompt\":\"check CI\"}")" g16
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(decision_of "$output")" = none ]
}

@test "a Skill call to the mode or autopilot skill is denied; other skills pass" {
  for s in kern:autopilot kern:mode autopilot mode KERN:MODE; do
    run_guard "$(tool_payload Skill "\"skill\":\"$s\",\"args\":\"on\"")" g16
    [ "$(decision_of "$output")" = deny ] || { echo "$s -> $output"; return 1; }
  done
  run_guard "$(tool_payload Skill "\"skill\":\"kern:help\",\"args\":\"mention /kern:mode\"")" g16
  [ "$status" -eq 0 ]
  [ "$(decision_of "$output")" = none ]
}

@test "a write to a kern settings file asks, and denies under autopilot" {
  mkdir -p "$R/.claude"
  expect_file_tools "$R/.claude/kern.local.yml" ask
  expect_file_tools "$R/.claude/kern.yml" ask
  expect_file_tools "$HOME/.claude/kern.yml" ask
  expect_file_tools "$R/.CLAUDE/KERN.LOCAL.YML" ask
  [[ "$output" == *'"kern G16: kern settings change guard policy; the user confirms each write"'* ]] || false
  expect_bash ask "echo kern: off >> .claude/kern.local.yml" "sed -i '' s/ask/auto/ $R/.claude/kern.yml" \
    "cd .claude && sed -i '' s/ask/auto/ kern.yml"
  set_autopilot on
  expect_file_tools "$R/.claude/kern.local.yml" deny
  [[ "$output" == *"the user confirms each write (autopilot: nobody to ask)"* ]] || false
}

@test "reading a kern settings file: no vote" {
  expect_bash ask "echo kern: off >> .claude/kern.local.yml"
  expect_bash none "cat .claude/kern.local.yml" "grep policy $R/.claude/kern.yml"
}

@test "a command that names neither state nor settings costs G16 no lower-casing; any case still counts" {
  local real
  real=$(command -v tr)
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  # A tr shim logs each lower-casing call.
  printf '#!/bin/bash\ncase "$*" in *"[:upper:]"*) echo tr >>"%s/tr.log" ;; esac\nexec %s "$@"\n' \
    "$BATS_TEST_TMPDIR" "$real" >"$BATS_TEST_TMPDIR/bin/tr"
  chmod +x "$BATS_TEST_TMPDIR/bin/tr"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  run_guard "$(bash_payload "ls -la")" g16
  [ "$(decision_of "$output")" = none ]
  [ ! -e "$BATS_TEST_TMPDIR/tr.log" ]
  expect_bash ask "echo kern: off >> .Claude/Kern.Local.YML" "sed -i '' s/ask/auto/ $R/.claude/KERN.yml"
  expect_bash deny "echo on > $(printf '%s' "$S" | tr '[:lower:]' '[:upper:]')/A.State"
}

@test "a settings path spelled with ., .. or // or split by quotes is still a settings path" {
  mkdir -p "$R/.claude/sub"
  expect_bash ask "echo kern: off > .claude/./kern.local.yml" "echo kern: off > .claude//kern.local.yml" \
    "echo kern: off > .claude/sub/../kern.local.yml" "echo kern: off > $R/x/../.claude/kern.local.yml" \
    "tee .claude/./kern.yml" "dd of=.claude//kern.yml" "cd .claude && echo kern: off > ./kern.yml" \
    "echo kern: off > .cl''aude/ke''rn.local.yml"
  ln -s "$R/.claude" "$R/c"
  expect_bash ask "echo kern: off > c/kern.local.yml"
  set_autopilot on
  expect_bash deny "echo kern: off > .claude//kern.local.yml"
}

@test "a copy, move or link into a .claude directory is a settings write; a copy out of one is not" {
  mkdir -p "$R/.claude/agents"
  expect_bash ask "cp /tmp/kern.local.yml .claude/" "cp /tmp/kern.local.yml .claude" \
    "mv /tmp/kern.local.yml $R/.claude/" "install -m 600 /tmp/settings.json ~/.claude" "ln -sf /tmp/fake .claude" \
    "cp -t .claude /tmp/kern.local.yml" "cd .claude && cp /tmp/kern.local.yml ." "cp /tmp/kern.local.yml .claude/./" \
    "rsync -a /tmp/kern.local.yml .claude/" "ditto /tmp/settings.json .claude" "mv .claude/kern.local.yml /tmp/" \
    "cp /tmp/kern.local.yml 2>/dev/null .claude/"
  [[ "$output" == *"a copy, move or link into a .claude directory, or its removal, may change kern or Claude Code settings"* ]] || false
  ln -s "$R/.claude" "$R/c"
  expect_bash ask "cp /tmp/kern.local.yml c/"
  set_autopilot on
  expect_bash deny "cp /tmp/kern.local.yml .claude/"
  set_autopilot off
  expect_bash none "cp .claude/kern.yml /tmp/kern.yml.bak" "cp /tmp/x.md .claude/agents/" "cp -r .claude/agents /tmp/" \
    "ls .claude" "cat .claude/agents/x.md"
}

@test "a write to Claude Code's own settings asks, and denies under autopilot; plain reads get no vote" {
  mkdir -p "$R/.claude" "$R/.vscode"
  expect_file_tools "$R/.claude/settings.json" ask
  expect_file_tools "$R/.claude/settings.local.json" ask
  expect_file_tools "$HOME/.claude/settings.json" ask
  expect_file_tools "$R/.Claude/Settings.JSON" ask
  expect_file_tools "$R/.claude/x/../settings.local.json" ask
  [[ "$output" == *"Claude Code settings set permissions and hooks; the user confirms each write"* ]] || false
  expect_bash ask "echo {} > .claude/settings.json" "tee ~/.claude/settings.json" \
    "cp /tmp/s.json .claude/settings.local.json" "sed -i '' s/deny/allow/ $HOME/.claude/settings.json" \
    "cd .claude && echo {} > settings.local.json" "mv .claude/settings.json /tmp/" "rm .claude/settings.local.json" \
    "echo {} > .claude//settings.json" "echo {} > \$HOME/.claude/settings.json"
  export CWD="$HOME/.claude"
  expect_bash ask "echo {} > settings.json"
  export CWD="$R"
  set_autopilot on
  expect_file_tools "$R/.claude/settings.local.json" deny
  expect_bash deny "echo {} > .claude/settings.json"
  set_autopilot off
  expect_bash none "cat .claude/settings.json" "jq .permissions ~/.claude/settings.json" \
    "grep allow $R/.claude/settings.local.json" "cp .claude/settings.json /tmp/settings.json.bak" \
    "git diff .claude/settings.json" "echo x > .vscode/settings.json" "cp /tmp/s.json .vscode/settings.json"
  expect_file_tools "$R/.vscode/settings.json" none
}
