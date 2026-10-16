#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"; make_repo "$R"; R=$(cd "$R" && pwd -P); kern_env "$R"; K="$(kern_root)"
  mkdir -p "$R/.kern/plans" "$CLAUDE_PLUGIN_DATA/sessions"
  PLAN="$R/.kern/plans/export.md"
  sed -n '/^---$/,$p' "$K/skills/plan/references/plan-template.md" | sed -e '/^### Task 1:/,$d' > "$PLAN"
  touch -t 202001010000 "$PLAN"
  APPROVED_PH=$(sed -n 's/^approved: //p' "$PLAN")
}
say() { printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$CWD" "$1" | bash "$K/hooks/prompt-submit" > /dev/null; }
# One Edit that sets status, approved and execution together, as plan step 12 says.
edit_approve() {
  local old new
  old="status: draft\\nspec: WORK/specs/<slug>.md\\nissue: (tracker id, or none)\\nbase: <base branch>; promotion: <branch chain, or none>\\napproved: $APPROVED_PH\\nexecution:"
  new="status: approved\\nspec: WORK/specs/<slug>.md\\nissue: (tracker id, or none)\\nbase: <base branch>; promotion: <branch chain, or none>\\napproved: 2026-10-15, \\\"$1\\\"\\nexecution: $2"
  run_guard "$(tool_payload Edit "\"file_path\":\"$PLAN\",\"old_string\":\"$old\",\"new_string\":\"$new\"")" g20
}

@test "plan: one Edit with approved and execution passes when the quote is in the prompt" {
  say 'Yes, go with delegate.'
  edit_approve 'Yes, go with delegate.' delegate
  echo "out=[$output]"; [ -z "$output" ]
}
@test "plan: quote not in the prompt is denied" {
  say 'Yes, go with delegate.'
  edit_approve 'ship it' step
  echo "out=[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "plan: autopilot denies" {
  say 'Yes, go with delegate.'
  set_autopilot on
  edit_approve 'Yes, go with delegate.' delegate
  echo "out=[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "plan: draft touched after the yes is denied" {
  say 'Yes, go with delegate.'
  sleep 1.1; touch "$PLAN"
  edit_approve 'Yes, go with delegate.' delegate
  echo "out=[$output]"; [ "$(decision_of "$output")" = deny ]
}
