#!/usr/bin/env bats
# tests/scripts/task-brief.bats: task-brief reads code fences as plan-check does (audit C-M1).

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  PLAN="$TMP/plan.md"
  LEDGER_DIR="$TMP/ledger"
}

# One printf argument per line keeps the fixtures' headings and fences out of column 0 of this file.

@test "a ~~~ fence holding a backtick line keeps Task 2 and ends Task 1 at its heading" {
  printf '%s\n' \
    '### Task 1: First' \
    '' \
    '~~~text' \
    '```' \
    '~~~' \
    '' \
    'Still task 1.' \
    '' \
    '### Task 2: Second' \
    '' \
    'Do the second thing.' > "$PLAN"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 2 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  grep -q '^### Task 2: Second$' "$output"
  grep -q '^Do the second thing\.$' "$output"
  [ "$(grep -c 'Task 1' "$output")" -eq 0 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 1 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  grep -q '^Still task 1\.$' "$output"
  [ "$(grep -c 'Do the second thing' "$output")" -eq 0 ]
}

@test "a ~~~ fence holding a backtick line in Global Constraints ends the constraints at the next heading" {
  printf '%s\n' \
    '## Global Constraints' \
    '' \
    '- Node 22.' \
    '' \
    '~~~text' \
    '```' \
    '~~~' \
    '' \
    '## Review Focus' \
    '' \
    '1. Empty input.' \
    '' \
    '### Task 1: First' \
    '' \
    'Do the first thing.' > "$PLAN"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 1 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  grep -q '^- Node 22\.$' "$output"
  [ "$(grep -c 'Empty input' "$output")" -eq 0 ]
  [ "$(grep -c 'Review Focus' "$output")" -eq 0 ]
  [ "$(grep -c '^### Task 1: First$' "$output")" -eq 1 ]
}

@test "a longer backtick fence holds a shorter one and a Task heading" {
  printf '%s\n' \
    '### Task 1: First' \
    '' \
    '````markdown' \
    '```' \
    '### Task 2: not a real task' \
    '```' \
    '````' \
    '' \
    'Still task 1.' \
    '' \
    '### Task 2: Second' \
    '' \
    'Do the second thing.' > "$PLAN"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 1 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  grep -q '^### Task 2: not a real task$' "$output"
  grep -q '^Still task 1\.$' "$output"
  [ "$(grep -c 'Do the second thing' "$output")" -eq 0 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 2 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  [ "$(head -n 5 "$output" | tail -n 1)" = '### Task 2: Second' ]
  [ "$(grep -c 'not a real task' "$output")" -eq 0 ]
}

@test "a backtick line whose info string holds a backtick opens no fence" {
  printf '%s\n' \
    '### Task 1: First' \
    '' \
    '```x`y' \
    '' \
    '### Task 2: Second' \
    '' \
    'Do the second thing.' > "$PLAN"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 2 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  grep -q '^Do the second thing\.$' "$output"
}

@test "a fence indented up to three spaces opens and closes, and a CRLF closing line closes it" {
  printf '%s\r\n' \
    '### Task 1: First' \
    '' \
    '   ```' \
    '### Task 9: inside the fence' \
    '```' \
    '' \
    '### Task 2: Second' \
    '' \
    'Do the second thing.' > "$PLAN"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 9 "$LEDGER_DIR"
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 2 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  grep -q '^Do the second thing\.' "$output"
  [ "$(grep -c 'inside the fence' "$output")" -eq 0 ]
}
