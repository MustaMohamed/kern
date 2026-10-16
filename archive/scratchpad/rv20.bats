#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/common
setup() {
  R="$BATS_TEST_TMPDIR/repo"; make_repo "$R"; R=$(cd "$R" && pwd -P); kern_env "$R"; K="$(kern_root)"
  mkdir -p "$R/.kern/plans" "$CLAUDE_PLUGIN_DATA/sessions"
  PLAN="$R/.kern/plans/export.md"
  sed -n '/^---$/,$p' "$K/skills/plan/references/plan-template.md" | sed -e '/^### Task 1:/,$d' > "$PLAN"
  touch -t 202001010000 "$PLAN"
  APH=$(sed -n 's/^approved: //p' "$PLAN")
}
say() { printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$CWD" "$1" | bash "$K/hooks/prompt-submit" > /dev/null; }
ed() { # quote exec
  local old new
  old="status: draft\\nspec: WORK/specs/<slug>.md\\nissue: (tracker id, or none)\\nbase: <base branch>; promotion: <branch chain, or none>\\napproved: $APH\\nexecution:"
  new="status: approved\\nspec: WORK/specs/<slug>.md\\nissue: (tracker id, or none)\\nbase: <base branch>; promotion: <branch chain, or none>\\napproved: 2026-10-15, \\\"$1\\\"\\nexecution: $2"
  run_guard "$(tool_payload Edit "\"file_path\":\"$PLAN\",\"old_string\":\"$old\",\"new_string\":\"$new\"")" g20
}
revise() { sleep 1.1; printf '\nrevised\n' >> "$PLAN"; }
@test "feedback, revise, yes" {
  say 'Change task 2 to use X.'
  revise
  say 'Yes, delegate.'
  sleep 1.1  # yes after revise
  say 'Yes, delegate.'
  ed 'Yes, delegate.' delegate; echo "[$output]"; [ -z "$output" ]
}
@test "revise AFTER yes denied" {
  say 'Yes, delegate.'; revise
  ed 'Yes, delegate.' delegate; echo "[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "yes with other text on same line (quote partial) denied" {
  say 'Yes, delegate. Also rename Task 2.'
  ed 'Yes, delegate.' delegate; echo "[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "yes with other text same line, whole line quoted passes" {
  say 'Yes, delegate. Also rename Task 2.'
  ed 'Yes, delegate. Also rename Task 2.' delegate; echo "[$output]"; [ -z "$output" ]
}
@test "multiline msg, yes on one line passes" {
  say 'Looks right.\nYes, inline.\nThanks'
  ed 'Yes, inline.' inline; echo "[$output]"; [ -z "$output" ]
}
@test "sounds good denied" {
  say 'sounds good'
  ed 'sounds good' step; echo "[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "next msg after yes (unrelated) then edit quoting earlier yes" {
  say 'Yes, delegate.'; sleep 1.1; say 'one more thing'
  ed 'Yes, delegate.' delegate; echo "[$output]" >&3
}
@test "split edits: status first then approved" {
  say 'Yes, delegate.'
  run_guard "$(tool_payload Edit "\"file_path\":\"$PLAN\",\"old_string\":\"status: draft\",\"new_string\":\"status: approved\"")" g20; echo "[$output]"; [ "$(decision_of "$output")" = deny ]
}
@test "execution invalid value passes G20 (plan-check catches)" {
  say 'Yes, bogus.'
  ed 'Yes, bogus.' bogus; echo "[$output]" >&3
}
