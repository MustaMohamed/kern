#!/usr/bin/env bats
# G20: status: approved needs the user's own words from their last message.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  R=$(cd "$R" && pwd -P)
  kern_env "$R"
  K="$(kern_root)"
  mkdir -p "$R/.kern/specs" "$CLAUDE_PLUGIN_DATA/sessions"
  SPEC="$R/.kern/specs/export.md"
  printf '%s\n' '---' 'status: draft' 'date: 2026-10-14' 'approved: (set only on an explicit yes)' '---' '## Problem' > "$SPEC"
  touch -t 202001010000 "$SPEC"
}

# say PROMPT: the user's message, through the real prompt-submit hook. PROMPT holds no double quote.
say() {
  printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$CWD" "$1" |
    bash "$K/hooks/prompt-submit" > /dev/null
}

# approve_payload QUOTE [PATH]: an Edit that sets status: approved and replaces the placeholder approved:
# line with one quoting QUOTE.
approve_payload() {
  tool_payload Edit "\"file_path\":\"${2:-$SPEC}\",\"old_string\":\"status: draft\\ndate: 2026-10-14\\napproved: (set only on an explicit yes)\",\"new_string\":\"status: approved\\ndate: 2026-10-14\\napproved: 2026-10-14, \\\"$1\\\"\""
}

# approve QUOTE [PATH]: G20's vote on that Edit.
approve() {
  run_guard "$(approve_payload "$1" "${2-}")" g20
}

GO='/kern:autopilot go MA-254'

# ticket LINE...: the draft with LINE... in its frontmatter, old as in setup.
ticket() {
  printf '%s\n' '---' "$@" 'status: draft' 'date: 2026-10-14' 'approved: (set only on an explicit yes)' '---' '## Problem' > "$SPEC"
  touch -t 202001010000 "$SPEC"
}

# approve_as FIELD: the go's Edit, from a call that carries the JSON field FIELD.
approve_as() {
  local p
  p=$(approve_payload "$GO")
  run_guard "{$1,${p#\{}" g20
}

# write_spec LINE...: a Write of a new spec whose frontmatter holds LINE..., JSON text.
write_spec() {
  local c='---' l
  for l in "$@"; do c="$c\\n$l"; done
  run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/specs/new.md\",\"content\":\"$c\\n---\\n## Problem\\n\"")" g20
}

# state_line LINE: appends LINE to the state; state_get reads the last line of a key.
state_line() {
  printf '%s\n' "$1" >> "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
}

# no_vote: G20 said nothing on the last call.
no_vote() {
  [ "$status" -eq 0 ] && [ -z "$output" ] || { echo "status $status: $output"; return 1; }
}

# deny_autopilot: the project denies autopilot, so a go refuses and a recorded one reads as off.
deny_autopilot() {
  mkdir -p "$R/.claude"
  printf 'autopilot: denied\n' > "$R/.claude/kern.local.yml"
}

# go_refused: the state holds autopilot off and no go.
go_refused() {
  local f="$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  grep -q '^autopilot: off$' "$f" || { cat "$f"; return 1; }
  [ -z "$(sed -n 's/^go: //p' "$f")" ] || { cat "$f"; return 1; }
}

# command_denied: G20 denied the last call's quote as a command.
command_denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [[ "$output" == *'is a command, not an explicit yes'* ]] || { echo "$output"; return 1; }
}

# go_denied: G20 denied the last call as an approval under autopilot with no go for it.
go_denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [[ "$output" == *'only a go approves, for its ticket'* ]] || { echo "$output"; return 1; }
}

@test "a quote of the user's last message approves" {
  say 'Yes, approved.'
  approve 'Yes, approved.'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a quote with other spacing and case still matches the same line" {
  say '  YES,   approved!  '
  approve 'yes, approved'
  [ -z "$output" ]
}

@test "one whole line of a longer message approves; part of a line does not" {
  say 'Looks right to me.\nYes, go with delegate.\nAlso rename the flag later.'
  approve 'Yes, go with delegate.'
  [ -z "$output" ]
  approve 'go with delegate'
  [ "$(decision_of "$output")" = deny ]
}

@test "an invented quote is denied" {
  say 'yes'
  approve 'ship it'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"kern G20: the approved: quote is not a line of the user's last message"* ]] || false
}

@test "sounds good and whatever you think are not a yes" {
  say 'sounds good'
  approve 'sounds good'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'is not an explicit yes'* ]] || false
  say 'Whatever you think.'
  approve 'Whatever you think.'
  [ "$(decision_of "$output")" = deny ]
}

@test "a refusal, a hold or a question is not a yes, though it is a whole line of the user's message" {
  say "No, not yet.\nDon't approve it yet\nCan you change the title?\nsounds good"
  for q in 'No, not yet.' "Don't approve it yet" 'Can you change the title?' 'sounds good'; do
    approve "$q"
    [ "$(decision_of "$output")" = deny ] || { echo "quote: $q: $output"; return 1; }
    [[ "$output" == *'is not an explicit yes'* ]] || { echo "quote: $q: $output"; return 1; }
  done
}

@test "a yes that ends in a question mark is a question, not a yes" {
  # "Yes, go ahead?" holds yes and go ahead and no hold word, so only the final question mark denies it
  # (Opus audit F-G20b: no test pinned that rule). The same line without it approves.
  say 'Yes, go ahead?'
  approve 'Yes, go ahead?'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'"Yes, go ahead?\" is not an explicit yes (it needs a word such as yes, ok or go ahead, no word such as no, not, wait or later, and no final question mark)'* ]] || false
  say 'Yes, go ahead.'
  approve 'Yes, go ahead.'
  [ -z "$output" ]
}

@test "a line that holds an affirmative word and no negation approves" {
  say 'ok good, go\nyes, delegate'
  approve 'ok good, go'
  [ -z "$output" ]
  approve 'yes, delegate'
  [ -z "$output" ]
}

@test "a line with no affirmative word, or with a hold word, is not a yes" {
  say 'Change the title first.\nyes, but wait for the review\nGo ahead later\nlooks great'
  for q in 'Change the title first.' 'yes, but wait for the review' 'Go ahead later' 'looks great'; do
    approve "$q"
    [ "$(decision_of "$output")" = deny ] || { echo "quote: $q: $output"; return 1; }
    [[ "$output" == *'ask the user for an explicit yes, then quote that line'* ]] || { echo "quote: $q: $output"; return 1; }
  done
}

@test "an invented quote's reason says to ask for an explicit yes" {
  say 'yes'
  approve 'ship it'
  [[ "$output" == *"ask the user for an explicit yes, then quote that line"* ]] || false
}

@test "a frontmatter with more than one approved: line, in any case or indentation, is denied" {
  say 'yes'
  for second in 'approved: 2026-10-16, \"I never said this\"' '  approved: 2026-10-16, \"yes\"' 'APPROVED: x'; do
    run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/specs/two.md\",\"content\":\"---\\nstatus: approved\\nApproved: 2026-10-16, \\\"yes\\\"\\n$second\\n---\\n\"")" g20
    [ "$(decision_of "$output")" = deny ] || { echo "second: $second: $output"; return 1; }
    [[ "$output" == *'more than one approved: line'* ]] || { echo "second: $second: $output"; return 1; }
  done
  approved_spec 'yes'
  edit '## Problem' 'approved: 2026-10-16, \"yes\"\n## Problem'
  [ -z "$output" ]
  edit 'status: approved' 'status: approved\napproved: 2026-10-16, \"yes\"'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'more than one approved: line'* ]] || false
}

@test "a quote from an earlier message, or from a wrapped one, is denied" {
  say 'yes'
  say 'yes, and add the CSV header row'
  approve 'yes'
  [ "$(decision_of "$output")" = deny ]
  say '<task-notification>yes</task-notification>'
  approve 'yes, and add the CSV header row'
  [ -z "$output" ]
}

@test "a draft changed after the user's message is denied" {
  say 'yes'
  touch -t 203001010000 "$SPEC"
  approve 'yes'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"changed after the user's last message"* ]] || false
}

@test "a missing approved: quote is denied" {
  say 'yes'
  run_guard "$(tool_payload Edit "\"file_path\":\"$SPEC\",\"old_string\":\"status: draft\",\"new_string\":\"status: approved\"")" g20
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"needs an approved: line"* ]] || false
}

@test "under autopilot even a real quote is denied" {
  say 'yes'
  printf 'autopilot: on\n' >> "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  approve 'yes'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"under autopilot only a go approves, for its ticket; keep status: draft (parked under autopilot) and park the question"* ]] || false
}

@test "under autopilot a go approves its ticket's spec" {
  ticket 'issue: MA-254'
  say "$GO"
  approve "$GO"
  no_vote
}

@test "a go approves in the write that creates a short spec" {
  say "$GO"
  write_spec 'form: short' 'status: approved' 'issue: MA-254' 'approved: 2026-10-31, \"/kern:autopilot go MA-254\"'
  no_vote
}

@test "a go matches other spellings of the issue" {
  ticket 'issue: ma-254'
  say "$GO"
  approve "$GO"
  no_vote
  ticket 'issue: #853'
  say '/kern:autopilot go 853'
  approve '/kern:autopilot go 853'
  no_vote
  ticket 'issue: 853'
  say '/kern:autopilot go #853'
  approve '/kern:autopilot go 853'
  no_vote
}

@test "one pair of matching quotes around the issue is dropped" {
  ticket 'issue: "#853"'
  say '/kern:autopilot go 853'
  approve '/kern:autopilot go 853'
  no_vote
  ticket 'issue: "MA-254"'
  say "$GO"
  approve "$GO"
  no_vote
  ticket "issue: 'ma-254'"
  approve "$GO"
  no_vote
}

@test "a quoted issue still names only its own ticket" {
  say "$GO"
  ticket 'issue: "MA-9"'
  approve "$GO"
  go_denied
  for l in 'issue: "MA-254' "issue: MA-254'" "issue: \"MA-254'" "issue: \"'MA-254'\"" 'issue: ""MA-254""' 'issue: ""'; do
    ticket "$l"
    approve "$GO"
    go_denied || { echo "line: $l"; return 1; }
  done
  ticket 'issue: "MA-254"' 'issue: "MA-9"'
  approve "$GO"
  go_denied
}

@test "a go does not approve another ticket" {
  ticket 'issue: MA-9'
  say "$GO"
  approve "$GO"
  go_denied
  approve '/kern:autopilot go MA-9'
  go_denied
}

@test "a spec with no ticket gets no approval" {
  say "$GO"
  ticket
  approve "$GO"
  go_denied
  for l in 'issue: none' 'issue: (tracker id, or none)' 'issue:'; do
    ticket "$l"
    approve "$GO"
    go_denied
  done
}

@test "only the frontmatter's one issue: line names the ticket" {
  say "$GO"
  ticket
  printf 'issue: MA-254\n' >> "$SPEC"
  touch -t 202001010000 "$SPEC"
  approve "$GO"
  go_denied
  ticket 'issue: MA-254' 'Issue: MA-9'
  approve "$GO"
  go_denied
  ticket 'issue: MA-9' 'issue: MA-254'
  approve "$GO"
  go_denied
}

@test "the quote must be the go line" {
  ticket 'issue: MA-254'
  say "$GO"
  for q in yes '/kern:autopilot go ma-254' '/kern:autopilot go MA-9' '/autopilot go MA-254' 'kern:autopilot go MA-254' \
    '/kern:autopilot go MA-254 now'; do
    approve "$q"
    go_denied || { echo "quote: $q"; return 1; }
  done
  run_guard "$(tool_payload Edit "\"file_path\":\"$SPEC\",\"old_string\":\"status: draft\",\"new_string\":\"status: approved\"")" g20
  go_denied
}

@test "a second approved: line takes the go's approval away" {
  say "$GO"
  write_spec 'status: approved' 'issue: MA-254' 'Approved: (old)' 'approved: 2026-10-31, \"/kern:autopilot go MA-254\"'
  go_denied
}

@test "a subagent cannot use the go" {
  ticket 'issue: MA-254'
  say "$GO"
  approve_as '"agent_type":"kern:implementer"'
  go_denied
  approve_as '"agent_id":"a1"'
  go_denied
  approve_as '"permission_mode":"default"'
  no_vote
}

@test "a go from another repository does not approve" {
  say "$GO"
  R2="$BATS_TEST_TMPDIR/other"
  make_repo "$R2"
  R2=$(cd "$R2" && pwd -P)
  CWD=$R2
  mkdir -p "$R2/.kern/specs"
  SPEC="$R2/.kern/specs/export.md"
  ticket 'issue: MA-254'
  approve "$GO"
  go_denied
}

@test "a replaced go no longer approves" {
  ticket 'issue: MA-1'
  say '/kern:autopilot go MA-1'
  say '/kern:autopilot go MA-2'
  approve '/kern:autopilot go MA-1'
  go_denied
}

@test "a draft written after the go still approves" {
  ticket 'issue: MA-254'
  say "$GO"
  touch -t 203001010000 "$SPEC"
  approve "$GO"
  no_vote
}

@test "under autopilot with no go nothing approves" {
  ticket 'issue: MA-254'
  say '/kern:autopilot on'
  approve "$GO"
  go_denied
}

@test "a cleared go or go_repo is no go" {
  ticket 'issue: MA-254'
  say "$GO"
  state_line 'go_repo: '
  approve "$GO"
  go_denied
  say "$GO"
  state_line 'go: '
  approve "$GO"
  go_denied
}

@test "a failed read is no go" {
  ticket 'issue: MA-254'
  say "$GO"
  read_fails awk 'k=go'
  approve "$GO"
  go_denied
  [ "$(read_failures awk)" -ge 1 ]
  read_fails awk 'k=go' 0
  read_fails awk 'k=go_repo'
  approve "$GO"
  go_denied
  [ "$(read_failures awk)" -ge 2 ]
  read_fails awk 'k=go_repo' 0
  read_fails git '*hash-object*'
  approve "$GO"
  go_denied
  [ "$(read_failures git)" -ge 1 ]
  read_fails git '*hash-object*' 0
  read_fails awk '*toupper*'
  approve "$GO"
  go_denied
  [ "$(read_failures awk)" -ge 3 ]
  read_fails awk '*toupper*' 0
  approve "$GO"
  no_vote
}

@test "a go refused by a denied project is not a yes" {
  ticket 'issue: MA-254'
  deny_autopilot
  say "$GO"
  go_refused
  approve "$GO"
  command_denied
}

@test "a go refused for a skill conflict is not a yes" {
  ticket 'issue: MA-254'
  mkdir -p "$R/.claude/skills/commit"
  printf 'x\n' > "$R/.claude/skills/commit/SKILL.md"
  say "$GO"
  go_refused
  approve "$GO"
  command_denied
}

@test "a go line on another ticket's spec is not a yes with autopilot off" {
  ticket 'issue: MA-9'
  deny_autopilot
  say '/kern:autopilot go MA-1'
  go_refused
  approve '/kern:autopilot go MA-1'
  command_denied
}

@test "a recorded go whose project then denies autopilot is not a yes" {
  ticket 'issue: MA-254'
  say "$GO"
  deny_autopilot
  approve "$GO"
  command_denied
}

@test "a go line pasted into a longer message is not a yes" {
  ticket 'issue: MA-254'
  say "Please run this\n$GO"
  go_refused
  approve "$GO"
  command_denied
}

@test "a quote's case and blanks do not hide an autopilot command" {
  ticket 'issue: MA-254'
  deny_autopilot
  say "$GO"
  for q in ' /kern:autopilot go MA-254' '/KERN:AUTOPILOT GO MA-254' '  /Kern:Autopilot   go ma-254'; do
    approve "$q"
    command_denied || { echo "quote: [$q]"; return 1; }
  done
  say '/autopilot go MA-254'
  for q in '/autopilot go MA-254' ' /AUTOPILOT go MA-254'; do
    approve "$q"
    command_denied || { echo "quote: [$q]"; return 1; }
  done
}

@test "an autopilot line is not a yes, whatever follows" {
  ticket 'issue: MA-254'
  for q in '/kern:autopilot ok' '/autopilot yes' '/kern:autopilot go ahead'; do
    say "$q"
    go_refused
    approve "$q"
    command_denied || { echo "quote: [$q]"; return 1; }
  done
}

@test "the one-line command envelope of a go is not a yes" {
  ticket 'issue: MA-254'
  E='<command-name>/kern:autopilot</command-name><command-args>go MA-254</command-args>'
  say "$E"
  go_refused
  approve "$E"
  command_denied
  deny_autopilot
  say "$E"
  go_refused
  approve "$E"
  command_denied
}

@test "no line of the three-line command envelope of a go is a yes" {
  ticket 'issue: MA-254'
  E='<command-message>kern:autopilot</command-message>\n<command-name>/kern:autopilot</command-name>\n<command-args>go MA-254</command-args>'
  for setting in allowed denied; do
    [ "$setting" = allowed ] || deny_autopilot
    say "$E"
    go_refused
    for q in '<command-args>go MA-254</command-args>' ' <COMMAND-ARGS>go ma-254</COMMAND-ARGS>' \
      '<command-name>/kern:autopilot</command-name>' '<command-message>kern:autopilot</command-message>'; do
      approve "$q"
      command_denied || { echo "$setting: quote: [$q]"; return 1; }
    done
  done
}

@test "a yes that only names the command still approves" {
  ticket 'issue: MA-254'
  say 'Yes, then run /kern:autopilot go MA-1'
  approve 'Yes, then run /kern:autopilot go MA-1'
  no_vote
}

@test "a shell write of the go quote stays denied" {
  ticket 'issue: MA-254'
  say "$GO"
  run_guard "$(tool_payload Bash "\"command\":\"sed -i '' 's|^approved:.*|approved: 2026-10-31, \\\"$GO\\\"|' $SPEC\"")" g20
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'set or change an approval with the Edit or Write tool'* ]] || false
}

@test "other files and draft edits get no G20 vote" {
  say 'no'
  # notes.md exists and holds the old_string, so the Edit is judged; it has no frontmatter.
  printf '%s\n' '# notes' 'status: draft' 'date: 2026-10-14' 'approved: (set only on an explicit yes)' > "$R/notes.md"
  approve 'no' "$R/notes.md"
  [ -z "$output" ]
  run_guard "$(tool_payload Edit "\"file_path\":\"$SPEC\",\"old_string\":\"## Problem\",\"new_string\":\"## Problem\\nstatus: draft\"")" g20
  [ -z "$output" ]
}

@test "a Bash write of approved into a spec is denied; a read is not" {
  run_guard "$(bash_payload "sed -i '' s/draft/approved/ .kern/specs/export.md")" g20
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(bash_payload "grep -n approved .kern/specs/export.md")" g20
  [ -z "$output" ]
}

@test "a Write of a new plan with a real quote approves" {
  mkdir -p "$R/.kern/plans"
  say 'yes, inline'
  run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/plans/p.md\",\"content\":\"---\\nstatus: approved\\napproved: 2026-10-14, \\\"yes, inline\\\"\\n---\\n\"")" g20
  [ -z "$output" ]
}

# edit OLD NEW [REPLACE_ALL] [PATH]: an Edit of the spec (or PATH). OLD and NEW hold no double quote.
edit() {
  run_guard "$(tool_payload Edit "\"file_path\":\"${4:-$SPEC}\",\"old_string\":\"$1\",\"new_string\":\"$2\",\"replace_all\":${3:-false}")" g20
}

# approved_spec QUOTE: makes the spec approved with QUOTE, older than the user's message.
approved_spec() {
  printf '%s\n' '---' 'status: approved' 'date: 2026-10-14' "approved: 2026-10-14, \"$1\"" '---' '## Problem' > "$SPEC"
  touch -t 202001010000 "$SPEC"
}

@test "an Edit of draft to approved is checked though new_string has no status line" {
  say 'yes'
  edit 'draft' 'approved'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"needs an approved: line"* ]] || false
}

@test "an Edit that changes the approved: line of an approved file is checked" {
  approved_spec 'yes'
  say 'yes'
  edit 'approved: 2026-10-14, \"yes\"' 'approved: 2026-10-14, \"ship it\"'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"not a line of the user's last message"* ]] || false
}

@test "replace_all is honoured when the edit is applied" {
  printf '%s\n' '---' 'title: draft notes' 'status: draft' 'approved: (set only on an explicit yes)' '---' > "$SPEC"
  touch -t 202001010000 "$SPEC"
  say 'yes'
  edit 'draft' 'approved' false
  [ -z "$output" ]
  edit 'draft' 'approved' true
  [ "$(decision_of "$output")" = deny ]
}

@test "an approved file edited below its frontmatter gets no vote" {
  approved_spec 'yes'
  edit '## Problem' '## Problem\nSums print bare.'
  [ -z "$output" ]
}

@test "a Markdown file outside the work dir is checked too" {
  mkdir -p "$R/docs/plans"
  say 'yes'
  run_guard "$(tool_payload Write "\"file_path\":\"$R/docs/plans/p.md\",\"content\":\"---\nstatus: approved\napproved: 2026-10-14, \\\"ship it\\\"\n---\n\"")" g20
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(tool_payload Write "\"file_path\":\"$R/docs/notes.md\",\"content\":\"# notes\\napproved by nobody\\n\"")" g20
  [ -z "$output" ]
}

@test "gawk -i inplace, and cp or mv of an approved file onto a spec, are denied" {
  run_guard "$(bash_payload "gawk -i inplace '{ sub(/draft/, \\\"approved\\\") } 1' .kern/specs/export.md")" g20
  [ "$(decision_of "$output")" = deny ]
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "yes"' '---' > "$BATS_TEST_TMPDIR/x.md"
  run_guard "$(bash_payload "cp $BATS_TEST_TMPDIR/x.md .kern/specs/export.md")" g20
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(bash_payload "mv $BATS_TEST_TMPDIR/x.md .kern/specs/export.md")" g20
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(bash_payload "cp README.md notes.md")" g20
  [ -z "$output" ]
}

@test "prompt_hashes folds case, blanks and a final . or !, one hash per line" {
  . "$K/hooks/lib/state.sh"
  [ "$(printf '  YES,   approved!  \n\nsecond line\n' | prompt_hashes)" = "$(printf 'yes, approved\nsecond line\n' | prompt_hashes)" ]
  [ "$(printf 'one\ntwo\n' | prompt_hashes | wc -w | tr -d ' ')" -eq 2 ]
}

@test "the dispatcher lists g20 among the guards it expects" {
  grep -q '^KERN_GUARD_IDS=".* g20[ "]' "$K/hooks/pre-tool-use"
}

@test "a contraction or cannot holds the approval, with a straight or curly apostrophe" {
  say "Looks ok, but I can't sign off yet\nWe can't ship this yet\nI cannot approve it\nok, but it isn’t ready\nok, but I won’t sign\nyes it doesnt work"
  for q in "Looks ok, but I can't sign off yet" "We can't ship this yet" 'I cannot approve it' 'ok, but it isn’t ready' 'ok, but I won’t sign' 'yes it doesnt work'; do
    approve "$q"
    [ "$(decision_of "$output")" = deny ] || { echo "quote: $q: $output"; return 1; }
    [[ "$output" == *'is not an explicit yes'* ]] || { echo "quote: $q: $output"; return 1; }
  done
  say 'yes, delegate\nok good, go'
  approve 'yes, delegate'
  [ -z "$output" ]
  approve 'ok good, go'
  [ -z "$output" ]
}

# sh_cmd COMMAND: G20 on a Bash COMMAND, which may hold any character.
sh_cmd() {
  . "$K/hooks/lib/json.sh"
  run_guard "$(tool_payload Bash "\"command\":\"$(printf '%s' "$1" | json_escape)\"")" g20
}

# denied: G20 denied the last call.
denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "expected deny: $output"; return 1; }
}

# working_dirs [WORK]: makes WORK/ledgers/x, WORK/reviews and WORK/tmp, WORK being .kern by default.
working_dirs() {
  mkdir -p "$R/${1:-.kern}/ledgers/x" "$R/${1:-.kern}/reviews" "$R/${1:-.kern}/tmp" "$R/.kern/plans"
}

# INVENTED: JSON text of a file that sets status: approved with a quote the user never gave.
INVENTED='---\nstatus: approved\napproved: 2026-10-14, \"ship it\"\n---\n'

# write_to PATH: a Write of the invented approval to PATH.
write_to() {
  run_guard "$(tool_payload Write "\"file_path\":\"$1\",\"content\":\"$INVENTED\"")" g20
}

@test "a ledger append that holds approved gets no vote" {
  working_dirs
  sh_cmd "printf '%s\n' 'Decision: size approved as one PR' >> .kern/ledgers/x/ledger.md"
  no_vote
}

@test "a here-doc that holds approved into a review note gets no vote" {
  working_dirs
  sh_cmd "cat > .kern/reviews/task-3.md <<'EOF'
Task quality: approved
EOF"
  no_vote
}

@test "a working file written beside a read of an approved spec gets no vote" {
  working_dirs
  approved_spec 'yes'
  sh_cmd "printf 'x\n' > .kern/reviews/p.proofs.md; bash proof-check .kern/specs/export.md .kern/reviews/p.proofs.md"
  no_vote
}

@test "a shell write that holds approved into a spec or plan is denied" {
  working_dirs
  sh_cmd "printf 'status: approved\n' > .kern/specs/x.md"
  denied
  sh_cmd "printf 'status: approved\n' > .kern/plans/x.md"
  denied
}

@test "a shell write to WORK/tmp gets no vote" {
  working_dirs
  sh_cmd "printf 'notes\n' > .kern/tmp/p.md"
  no_vote
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  no_vote
  printf '%s\n' '---' 'status: approved' '---' > "$R/.kern/tmp/p.md"
  sh_cmd "printf 'notes\n' >> .kern/tmp/p.md"
  no_vote
}

@test "a Write or Edit of a working file that holds only the word gets no vote" {
  working_dirs
  for f in ledgers/x/ledger.md reviews/task-3.md tmp/p.md; do
    run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/$f\",\"content\":\"Task quality: approved\\n\"")" g20
    no_vote
  done
  cp "$SPEC" "$R/.kern/tmp/draft.md"
  edit '## Problem' '## Problem\nThe size was approved.' false "$R/.kern/tmp/draft.md"
  no_vote
}

@test "a Write or Edit that approves a working file, spec or plan is denied" {
  working_dirs
  for f in ledgers/x/ledger.md reviews/task-3.md tmp/p.md plans/x.md; do
    write_to "$R/.kern/$f"
    denied
  done
  cp "$SPEC" "$R/.kern/tmp/draft.md"
  edit 'status: draft' 'status: approved' false "$R/.kern/tmp/draft.md"
  denied
  edit 'status: draft' 'status: approved'
  denied
}

@test "a shell redirect that approves a working file is denied" {
  working_dirs
  for f in .kern/ledgers/x/ledger.md .kern/reviews/p.md .kern/tmp/p.md; do
    sh_cmd "echo 'status: approved' > $f"
    denied
    sh_cmd "echo 'status: \"approved\"' >> $f"
    denied
    sh_cmd "echo \"'Status' : 'Approved'\" >> $f"
    denied
    sh_cmd "echo 'status:approved' >> $f"
    denied
  done
}

@test "a here-doc that approves a working file is denied" {
  working_dirs
  sh_cmd "cat > .kern/tmp/p.md <<'EOF'
---
status: approved
approved: 2026-10-14, yes
---
EOF"
  denied
}

@test "a printf that carries an approval in one word is denied" {
  working_dirs
  sh_cmd "printf '---\nstatus: approved\napproved: 2026-10-14\n---\n' > .kern/tmp/p.md"
  denied
  sh_cmd "printf 'status:\tapproved\n' > .kern/tmp/p.md"
  denied
}

@test "an approval written after a cd into a working directory is denied" {
  working_dirs
  sh_cmd "cd .kern/tmp && printf 'status: approved\n' > p.md"
  denied
}

@test "an approval written through a symlinked working name is denied" {
  working_dirs
  printf 'x\n' > "$R/.kern/reviews/real.md"
  ln -s ../reviews/real.md "$R/.kern/tmp/link.md"
  ln -s ../reviews "$R/.kern/tmp/dir"
  sh_cmd "printf 'status: approved\n' >> .kern/tmp/link.md"
  denied
  sh_cmd "printf 'status: approved\n' > .kern/tmp/dir/x.md"
  denied
  write_to "$R/.kern/tmp/link.md"
  denied
}

@test "when the check for an approval cannot run, a working file is judged" {
  working_dirs
  read_fails grep '*status*'
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  denied
}

@test "a name beside a working directory is not a working file" {
  working_dirs
  mkdir -p "$R/.kern/tmp2" "$R/.kern/specs/tmp"
  for f in .kern/tmp2/p.md .kern/specs/tmp/p.md .kern/tmp.md tmp/p.md; do
    mkdir -p "$R/${f%/*}"
    sh_cmd "printf 'approved\n' > $f"
    denied
    write_to "$R/$f"
    denied
  done
}

@test "a symlink under WORK/tmp that points out is judged as the file it reaches" {
  working_dirs
  ln -s ../specs/export.md "$R/.kern/tmp/link.md"
  sh_cmd "printf 'approved\n' >> .kern/tmp/link.md"
  denied
  write_to "$R/.kern/tmp/link.md"
  denied
  ln -s ../specs/export.md "$R/.kern/tmp/link.txt"
  write_to "$R/.kern/tmp/link.txt"
  denied
  ln -s ../specs "$R/.kern/tmp/dir"
  sh_cmd "printf 'approved\n' > .kern/tmp/dir/x.md"
  denied
  write_to "$R/.kern/tmp/dir/x.md"
  denied
}

@test "a symlink that keeps inside the working directories is a working file" {
  working_dirs
  printf 'x\n' > "$R/.kern/reviews/real.md"
  ln -s ../reviews/real.md "$R/.kern/tmp/link.md"
  sh_cmd "printf 'approved\n' >> .kern/tmp/link.md"
  no_vote
}

@test "a spec that is a symlink into WORK/tmp is judged as a spec" {
  working_dirs
  printf 'x\n' > "$R/.kern/tmp/p.md"
  ln -s ../tmp/p.md "$R/.kern/plans/x.md"
  sh_cmd "printf 'approved\n' >> .kern/plans/x.md"
  denied
  write_to "$R/.kern/plans/x.md"
  denied
}

@test ".. in a path is read as the file system reads it" {
  working_dirs
  sh_cmd "printf 'approved\n' > .kern/tmp/../specs/x.md"
  denied
  write_to "$R/.kern/tmp/../specs/x.md"
  denied
  sh_cmd "cd .kern/tmp && printf 'approved\n' > ../specs/x.md"
  denied
  sh_cmd "printf 'approved\n' > .kern/specs/../tmp/p.md"
  no_vote
  # .. after a symlink leaves the directory the symlink reaches.
  mkdir -p "$R/.kern/specs/sub"
  ln -s ../specs/sub "$R/.kern/tmp/dir"
  sh_cmd "printf 'approved\n' > .kern/tmp/dir/../x.md"
  denied
}

@test "a directory that does not exist yet is not a working directory" {
  working_dirs
  sh_cmd "mkdir -p .kern/tmp/new && printf 'approved\n' > .kern/tmp/new/x.md"
  denied
}

@test "a copy from a working file into a spec or plan is denied" {
  working_dirs
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "yes"' '---' > "$R/.kern/tmp/p.md"
  for c in 'cp .kern/tmp/p.md .kern/plans/x.md' 'mv .kern/tmp/p.md .kern/specs/x.md' \
    'cat .kern/tmp/p.md > .kern/plans/x.md' 'tee .kern/plans/x.md < .kern/tmp/p.md' \
    'ln -s ../tmp/p.md .kern/plans/x.md' 'ln .kern/tmp/p.md .kern/plans/x.md'; do
    sh_cmd "$c"
    denied
    [[ "$output" == *'status: approved line'* ]] || { echo "$c: $output"; return 1; }
  done
}

@test "a working path built at run time stays judged" {
  working_dirs
  approved_spec 'yes'
  sh_cmd 'printf approved > .kern/tmp/$X.md'
  denied
  sh_cmd 'cat .kern/specs/export.md > .kern/tmp/$X.md'
  denied
}

@test "work_dir in the settings names the working directories" {
  working_dirs .work
  mkdir -p "$R/.claude"
  printf 'work_dir: .work\n' > "$R/.claude/kern.local.yml"
  sh_cmd "printf 'approved\n' > .work/tmp/p.md"
  no_vote
  write_to "$R/.work/reviews/p.md"
  denied
  mkdir -p "$R/.kern/tmp"
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  denied
  write_to "$R/.kern/tmp/p.md"
  denied
}

@test "a work_dir kern-dir refuses, or settings that cannot be read, name no working directory" {
  mkdir -p "$R/.claude" "$R/tmp"
  printf 'work_dir: .\n' > "$R/.claude/kern.local.yml"
  sh_cmd "printf 'approved\n' > tmp/p.md"
  denied
  working_dirs
  printf 'work_dir: .kern\n' > "$R/.claude/kern.local.yml"
  read_fails awk "$R/.claude/kern.local.yml"
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  denied
}

@test "a work dir that is a symlink holds its working files where it lands" {
  mkdir -p "$BATS_TEST_TMPDIR/real/tmp" "$BATS_TEST_TMPDIR/real/specs"
  rm -rf "$R/.kern"
  ln -s "$BATS_TEST_TMPDIR/real" "$R/.kern"
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  no_vote
  sh_cmd "printf 'approved\n' > .kern/specs/x.md"
  denied
}

@test "WORK/tmp that is a symlink to the specs holds no working files" {
  rm -rf "$R/.kern/tmp"
  ln -s specs "$R/.kern/tmp"
  sh_cmd "printf 'approved\n' > .kern/tmp/x.md"
  denied
}

@test "WORK is the main worktree's: a linked worktree's own .kern/tmp is judged" {
  working_dirs
  git -C "$R" worktree add -q "$BATS_TEST_TMPDIR/wt" -b t 2> /dev/null
  W=$(cd "$BATS_TEST_TMPDIR/wt" && pwd -P)
  mkdir -p "$W/.kern/tmp"
  export CWD="$W"
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  denied
  sh_cmd "printf 'approved\n' > $R/.kern/tmp/p.md"
  no_vote
}

@test "a working directory named in another case is the same directory on a case-blind file system" {
  working_dirs
  [ -d "$R/.kern/TMP" ] || skip 'the file system tells case apart'
  sh_cmd "printf 'approved\n' > .kern/TMP/p.md"
  no_vote
}
