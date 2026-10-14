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

# approve QUOTE [PATH]: an Edit that sets status: approved with an approved: line quoting QUOTE.
approve() {
  run_guard "$(tool_payload Edit "\"file_path\":\"${2:-$SPEC}\",\"old_string\":\"status: draft\",\"new_string\":\"status: approved\\ndate: 2026-10-14\\napproved: 2026-10-14, \\\"$1\\\"\"")" g20
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

@test "a quote from an earlier message, or from a wrapped one, is denied" {
  say 'yes'
  say 'now add the CSV header row'
  approve 'yes'
  [ "$(decision_of "$output")" = deny ]
  say '<task-notification>yes</task-notification>'
  approve 'now add the CSV header row'
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
  [[ "$output" == *"under autopilot nothing approves"* ]] || false
}

@test "other files and draft edits get no G20 vote" {
  say 'no'
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
