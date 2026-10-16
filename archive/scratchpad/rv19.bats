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
@test "multi-line message, quote only yes line" {
  say 'Looks right.\nYes, approved.\nAlso rename it later.'
  edit_approve 'Yes, approved.'
  [ -z "$output" ]
}
@test "yes line with trailing other text, whole line quoted" {
  say 'yes, but add a rollback note'
  edit_approve 'yes, but add a rollback note'
  [ -z "$output" ]
}
@test "yes two messages after draft (middle message untouched file)" {
  say 'what about rollback?'
  say 'ok yes approved'
  edit_approve 'ok yes approved'
  [ -z "$output" ]
}
@test "user quote from an earlier message is denied" {
  say 'yes approved'
  say 'thanks, one more thing'
  edit_approve 'yes approved'
  [ "$(decision_of "$output")" = deny ]
}
@test "revision after feedback then yes in next message passes" {
  say 'change the title'
  sleep 1.1; touch "$SPEC"
  sleep 1.1; say 'yes go'
  edit_approve 'yes go'
  [ -z "$output" ]
}
@test "bounded Write under autopilot denied" {
  say 'Yes, go'
  set_autopilot on
  NEW="$R/.kern/specs/csv.md"
  CONTENT='---\nstatus: approved\nform: short\ndate: 2026-10-15\napproved: 2026-10-15, \"Yes, go\"\nissue: none\n---\n## Problem\n'
  run_guard "$(tool_payload Write "\"file_path\":\"$NEW\",\"content\":\"$CONTENT\"")" g20
  [ "$(decision_of "$output")" = deny ]
}
@test "self approval quoting non-yes line of last message passes (accepted limit)" {
  say 'Please build CSV export'
  edit_approve 'Please build CSV export'
  echo "out=[$output]"; [ -z "$output" ]
}
@test "plan-check after approval edit: G20 silent, file mtime unchanged" {
  say 'Yes, approved.'
  edit_approve 'Yes, approved.'; [ -z "$output" ]
  sed -i '' 's/^status: draft/status: approved/; s/^approved: (unset.*/approved: 2026-10-15, "Yes, approved."/' "$SPEC"
  m1=$(stat -f %m "$SPEC")
  run_guard "$(bash_payload "bash $K/scripts/plan-check $SPEC")" g20
  echo "g20=[$output]"; [ -z "$output" ]
  (cd "$R" && bash "$K/scripts/plan-check" "$SPEC"); echo rc=$?
  [ "$m1" = "$(stat -f %m "$SPEC")" ]
}
