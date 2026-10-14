#!/usr/bin/env bats
# tests/scripts/ledger.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  PLAN="$TMP/plan.md"
  # One printf argument per line keeps the fixture's headings and fences out of column 0 of this plan,
  # so task extractors reading the plan itself are not confused.
  printf '%s\n' \
    '# Example plan' \
    '' \
    '## Global Constraints' \
    '' \
    '- Node 22.' \
    '' \
    '## Review Focus' \
    '' \
    '1. Empty input.' \
    '' \
    '### Task 1: First' \
    '' \
    'Do the first thing.' \
    '' \
    '```markdown' \
    '### Task 9: not a real task' \
    '```' \
    '' \
    'Still task 1.' \
    '' \
    '### Task 2: Second' \
    '' \
    'Do the second thing.' \
    '' \
    '## Self-review' \
    '' \
    'Not part of any task.' > "$PLAN"
  LEDGER_DIR="$TMP/ledger"
  mkdir -p "$LEDGER_DIR"
  LEDGER="$LEDGER_DIR/ledger.md"
  printf '# kern ledger: %s\n' "$PLAN" > "$LEDGER"
  TREE=$(printf '%040d' 0 | tr 0 a)
}

# approved_plan FILE [STATUS] [APPROVED]: a plan file with frontmatter.
approved_plan() {
  printf '%s\n' '---' "status: ${2-approved}" 'spec: none' "approved: ${3-2026-10-14, \"yes, go with delegate\"}" 'execution: delegate' 'commits: ask' '---' '' '### Task 1: One' > "$1"
}

@test "task-brief extracts one task plus the global constraints" {
  run bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 2 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$LEDGER_DIR/briefs/task-2.md" ]
  grep -q '^- Node 22\.$' "$output"
  grep -q '^### Task 2: Second$' "$output"
  [ "$(grep -c 'Task 1' "$output")" -eq 0 ]
  [ "$(grep -c 'Not part of any task' "$output")" -eq 0 ]
  [ "$(grep -c 'Empty input' "$output")" -eq 0 ]
}

@test "a Task heading inside a fence is ignored" {
  run bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 1 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  grep -q '^Still task 1\.$' "$output"
  grep -q '^### Task 9: not a real task$' "$output"
  run bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 9 "$LEDGER_DIR"
  [ "$status" -eq 2 ]
}

@test "a missing task exits 2 and writes nothing" {
  run bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 3 "$LEDGER_DIR"
  [ "$status" -eq 2 ]
  [ ! -e "$LEDGER_DIR/briefs/task-3.md" ]
}

@test "task-start appends a start line" {
  run bash "$KERN_ROOT/scripts/task-start" "$LEDGER" 1 "$TREE"
  [ "$status" -eq 0 ]
  [[ "$output" == "Task 1: start tree=$TREE at="* ]] || false
  [ "$(tail -n 1 "$LEDGER")" = "$output" ]
}

@test "task-start refuses a missing ledger and a short tree id" {
  run bash "$KERN_ROOT/scripts/task-start" "$TMP/none.md" 1 "$TREE"
  [ "$status" -eq 2 ]
  run bash "$KERN_ROOT/scripts/task-start" "$LEDGER" 1 abc123
  [ "$status" -eq 2 ]
}

@test "ledger-open creates the ledger with its identity and the main checkout's state" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/Big Plan.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/Big Plan.md"
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.kern/ledgers/big-plan" ]
  [ "$(head -n 1 "$output/ledger.md")" = "# kern ledger: $TMP/Big Plan.md" ]
  grep -q "^Main: $REPO branch=main status=[0-9a-f]\{40\}$" "$output/ledger.md"
  for d in briefs reports reviews logs; do [ -d "$output/$d" ]; done
  [ -z "$(git status --porcelain)" ]
}

@test "ledger-open reuses its own ledger and refuses another plan's" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"; approved_plan "$TMP/b.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" 2> /dev/null)
  printf 'Task 1: start tree=x\n' >> "$dir/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l"
  [ "$status" -eq 0 ]
  grep -q '^Task 1: start' "$TMP/l/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/b.md" "$TMP/l"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"belongs to another plan ($TMP/a.md)"* ]] || false
}

@test "ledger-open refuses a plan that is not approved, or approved without the user's words" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/d.md" draft
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/d.md" "$TMP/l"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"status: draft"* ]] || false
  approved_plan "$TMP/n.md" approved "2026-10-14"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/n.md" "$TMP/l"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"quoted words"* ]] || false
  [ ! -e "$TMP/l/ledger.md" ]
}

@test "ledger-open --summary lists decisions, parked and deferred lines and checks the main checkout" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" 2> /dev/null)
  printf '%s\n' 'Decision: one; why: x; cost if wrong: y' 'Task 1: review round=1 tree=t spec=compliant quality=approved' \
    'Task 1: minor (deferred): rename a helper' 'parked: q; default: d; why: w' >> "$dir/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$dir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'Decision: one; why: x; cost if wrong: y' ]
  [ "${lines[1]}" = 'Task 1: minor (deferred): rename a helper' ]
  [ "${lines[2]}" = 'parked: q; default: d; why: w' ]
  [ "${lines[3]}" = 'main: unchanged' ]
  printf 'x\n' > "$REPO/stray.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$dir"
  [ "$status" -eq 1 ]
  [[ "${lines[3]}" == 'main: changed; '* ]] || false
}
