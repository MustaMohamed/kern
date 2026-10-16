#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"; make_repo "$R"; R=$(cd "$R" && pwd -P); kern_env "$R"; K="$(kern_root)"
  mkdir -p "$R/.kern/specs" "$CLAUDE_PLUGIN_DATA/sessions"
  SPEC="$R/.kern/specs/export.md"
  sed -n '/^---$/,$p' "$K/skills/define/references/spec-template.md" | sed 's/^date: YYYY-MM-DD/date: 2026-10-15/' > "$SPEC"
  touch -t 202001010000 "$SPEC"
}
say() { printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$CWD" "$1" | bash "$K/hooks/prompt-submit" > /dev/null; }
OLD='status: draft\nform: full\ndate: 2026-10-15\napproved: (unset until an explicit yes)'
edit_approve() { run_guard "$(tool_payload Edit "\"file_path\":\"$SPEC\",\"old_string\":\"$OLD\",\"new_string\":\"status: approved\\nform: full\\ndate: 2026-10-15\\napproved: 2026-10-15, \\\"$1\\\"\"")" g20; }

@test "architectural: template Edit with quoted yes passes" {
  say 'Yes, approved.'
  edit_approve 'Yes, approved.'
  echo "out=[$output]"; [ -z "$output" ]
}
@test "architectural: quote not in the prompt is denied" {
  say 'Yes, approved.'
  edit_approve 'ship it'
  echo "out=[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "architectural: non-answer denied" {
  say 'sounds good'
  edit_approve 'sounds good'
  echo "out=[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "architectural: draft touched after the yes is denied" {
  say 'Yes, approved.'
  sleep 1.1; touch "$SPEC"
  edit_approve 'Yes, approved.'
  echo "out=[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "architectural: autopilot denies" {
  say 'Yes, approved.'
  set_autopilot on
  edit_approve 'Yes, approved.'
  echo "out=[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "parked draft status is not an approval" {
  say 'Yes, approved.'
  set_autopilot on
  run_guard "$(tool_payload Edit "\"file_path\":\"$SPEC\",\"old_string\":\"status: draft\",\"new_string\":\"status: draft (parked under autopilot)\"")" g20
  echo "out=[$output]"; [ -z "$output" ]
}
@test "bounded: Write of a new short spec with quoted yes passes" {
  say 'Yes, go with the short design.'
  NEW="$R/.kern/specs/csv.md"
  CONTENT='---\nstatus: approved\nform: short\ndate: 2026-10-15\napproved: 2026-10-15, \"Yes, go with the short design.\"\nissue: none\n---\n## Problem\n'
  run_guard "$(tool_payload Write "\"file_path\":\"$NEW\",\"content\":\"$CONTENT\"")" g20
  echo "out=[$output]"; [ -z "$output" ]
}
@test "bounded: Write with an invented quote is denied" {
  say 'Yes, go with the short design.'
  NEW="$R/.kern/specs/csv.md"
  CONTENT='---\nstatus: approved\nform: short\ndate: 2026-10-15\napproved: 2026-10-15, \"approved by me\"\nissue: none\n---\n## Problem\n'
  run_guard "$(tool_payload Write "\"file_path\":\"$NEW\",\"content\":\"$CONTENT\"")" g20
  echo "out=[$output]"; [ "$(decision_of "$output")" = deny ]
}
