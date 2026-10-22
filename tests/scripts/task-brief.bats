#!/usr/bin/env bats
# tests/scripts/task-brief.bats: task-brief reads code fences as plan-check does (audit C-M1). Both load
# scripts/lib/fence.awk, and each fixture here is a plan plan-check passes, so the two can be compared.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  cd "$TMP"
  PLAN="$TMP/plan.md"
  LEDGER_DIR="$TMP/ledger"
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "yes"' '---' '' '## Acceptance criteria' '' '1. Works.' > "$TMP/spec.md"
}

# One printf argument per line keeps the fixtures' headings and fences out of column 0 of this file.

# plan_file LINE...: a plan plan-check passes: its frontmatter and the sections plan-check needs, then
# LINE... A line `@tail N` stands for the Files, Interfaces, Blocked by, Acceptance and Run: lines of
# Task N, whose one file is src/tN.js.
plan_file() {
  local l
  {
    printf '%s\n' '---' 'status: draft' 'spec: spec.md' 'commits: ask' '---' '' '## Global Constraints' '' '- Bash 3.2.' '' \
      '## Review Focus' '' '1. Focus.' '' '## File map' ''
    for l in "$@"; do
      case "$l" in
        '@tail '*)
          printf '%s\n' '' '**Files:**' "- Create: \`src/t${l#@tail }.js\`" '' '**Interfaces:**' '- Consumes: none' '- Produces: none' '' \
            '**Blocked by:** none' '' '**Acceptance:** 1' '' '- [ ] Step 1: Run: `node --test`. Expected: one failure.' ''
          ;;
        *) printf '%s\n' "$l" ;;
      esac
    done
  } > "$PLAN"
}

fx_tilde() {
  plan_file '### Task 1: First' '' '~~~text' '```' '~~~' '' 'Still task 1.' '@tail 1' \
    '### Task 2: Second' '' 'Do the second thing.' '@tail 2'
}
fx_constraints() {
  plan_file '## Global Constraints' '' '- Node 22.' '' '~~~text' '```' '~~~' '' '## Review Focus' '' '1. Empty input.' '' \
    '### Task 1: First' '' 'Do the first thing.' '@tail 1'
}
fx_long() {
  plan_file '### Task 1: First' '' '````markdown' '```' '### Task 2: not a real task' '```' '````' '' 'Still task 1.' '@tail 1' \
    '### Task 2: Second' '' 'Do the second thing.' '@tail 2'
}
fx_infostring() {
  plan_file '### Task 1: First' '' '```x`y' '@tail 1' '### Task 2: Second' '' 'Do the second thing.' '@tail 2'
}
fx_crlf() {
  plan_file '### Task 1: First' '' '   ```' '### Task 9: inside the fence' '```' '@tail 1' \
    '### Task 2: Second' '' 'Do the second thing.' '@tail 2'
  awk '{ printf "%s\r\n", $0 }' "$PLAN" > "$PLAN.crlf"
  mv "$PLAN.crlf" "$PLAN"
}

brief() { run --separate-stderr bash "$KERN_ROOT/scripts/task-brief" "$PLAN" "$1" "$LEDGER_DIR"; }

@test "a ~~~ fence holding a backtick line keeps Task 2 and ends Task 1 at its heading" {
  fx_tilde
  brief 2
  [ "$status" -eq 0 ]
  grep -q '^### Task 2: Second$' "$output"
  grep -q '^Do the second thing\.$' "$output"
  [ "$(grep -c 'Task 1' "$output")" -eq 0 ]
  brief 1
  [ "$status" -eq 0 ]
  grep -q '^Still task 1\.$' "$output"
  [ "$(grep -c 'Do the second thing' "$output")" -eq 0 ]
}

@test "a ~~~ fence holding a backtick line in Global Constraints ends the constraints at the next heading" {
  fx_constraints
  brief 1
  [ "$status" -eq 0 ]
  grep -q '^- Node 22\.$' "$output"
  grep -q '^- Bash 3\.2\.$' "$output"
  [ "$(grep -c 'Empty input' "$output")" -eq 0 ]
  [ "$(grep -c 'Review Focus' "$output")" -eq 0 ]
  [ "$(grep -c '^### Task 1: First$' "$output")" -eq 1 ]
}

@test "a longer backtick fence holds a shorter one and a Task heading" {
  fx_long
  brief 1
  [ "$status" -eq 0 ]
  grep -q '^### Task 2: not a real task$' "$output"
  grep -q '^Still task 1\.$' "$output"
  [ "$(grep -c 'Do the second thing' "$output")" -eq 0 ]
  brief 2
  [ "$status" -eq 0 ]
  [ "$(grep '^### Task ' "$output")" = '### Task 2: Second' ]
}

@test "a backtick line whose info string holds a backtick opens no fence" {
  fx_infostring
  brief 2
  [ "$status" -eq 0 ]
  grep -q '^Do the second thing\.$' "$output"
}

@test "a fence indented up to three spaces opens and closes, and a CRLF closing line closes it" {
  fx_crlf
  brief 9
  [ "$status" -eq 2 ]
  brief 2
  [ "$status" -eq 0 ]
  grep -q '^Do the second thing\.' "$output"
  [ "$(grep -c 'inside the fence' "$output")" -eq 0 ]
}

# Review of P7, Important 1: C-M1 came from two fence readers that drifted apart (gap 43 was fixed in
# plan-check only). One file now holds the rule.
@test "plan-check and task-brief load one fence reader, scripts/lib/fence.awk, and keep no copy of it" {
  grep -q '^function fence_run(' "$KERN_ROOT/scripts/lib/fence.awk"
  grep -q '^function fence_mark(' "$KERN_ROOT/scripts/lib/fence.awk"
  for s in plan-check task-brief; do
    grep -qF '/lib/fence.awk' "$KERN_ROOT/scripts/$s"
    [ "$(grep -c 'function fence_run\|fence_run(' "$KERN_ROOT/scripts/$s")" -eq 0 ]
  done
}

@test "plan-check --graph and task-brief find the same tasks in every fixture, each with its own Files" {
  for fx in fx_tilde fx_constraints fx_long fx_infostring fx_crlf; do
    "$fx"
    run --separate-stderr bash "$KERN_ROOT/scripts/plan-check" --graph "$PLAN"
    [ "$status" -eq 0 ] || { echo "$fx: plan-check exit $status: $output $stderr"; false; }
    pc=$(printf '%s\n' "$output" | awk -F '\t' '$1 == "wave" { print $3 }' | tr ' ' '\n' | sort -n | tr '\n' ' ')
    tb=''
    for n in 1 2 3 4 5 6 7 8 9; do
      bash "$KERN_ROOT/scripts/task-brief" "$PLAN" "$n" "$LEDGER_DIR" > /dev/null 2>&1 || continue
      tb="$tb$n "
      # The brief of Task n holds the one path plan-check lists for n, and no other task's path.
      run --separate-stderr bash "$KERN_ROOT/scripts/plan-check" --files "$PLAN" "$n"
      [ "$status" -eq 0 ] && [ "$output" = "src/t$n.js" ] || { echo "$fx: plan-check --files $n: $output"; false; }
      [ "$(grep -o 'src/t[0-9]*\.js' "$LEDGER_DIR/briefs/task-$n.md")" = "src/t$n.js" ] || { echo "$fx: brief $n"; cat "$LEDGER_DIR/briefs/task-$n.md"; false; }
    done
    [ "$pc" = "$tb" ] || { echo "$fx: plan-check finds [$pc], task-brief finds [$tb]"; false; }
  done
}
