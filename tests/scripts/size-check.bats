#!/usr/bin/env bats
# tests/scripts/size-check.bats: size-check sizes the plan worktree from the ledger's Worktree: base tree against
# pr.max_lines and scope_threshold, and task-done runs it after each task closed in the plan worktree (pilot fix
# plan 2's test round: in 2 of 3 size-breach runs execute-plan went on to Task 2 at 17 lines over a limit of 10).

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  WT=$(bash "$KERN_ROOT/scripts/wt-new" size-x)
  T0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  L="$TMP/ledger"
  mkdir -p "$L" "$REPO/.claude"
  printf '# kern ledger: plan.md\nWorktree: %s branch=kern/size-x base-tree=%s\n' "$WT" "$T0" > "$L/ledger.md"
}

write_lines() { local i; for i in $(seq 1 "$2"); do printf 'line %s\n' "$i"; done > "$1"; }

@test "size-check counts from the base tree, untracked files included, and stages nothing" {
  printf 'pr.max_lines: 10\n' > "$REPO/.claude/kern.local.yml"
  write_lines "$WT/b.txt" 3
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "size: lines: 3 (git diff --shortstat), -w: 3, files: 1; pr.max_lines: 10 ("*"); scope_threshold: 4 (default)" ]] || false
  [ "${lines[1]}" = "size: within the limits" ]
  [ "$(git -C "$WT" status --porcelain)" = "?? b.txt" ]
}

@test "size-check over pr.max_lines with no size Decision: line exits 4 and says to stop before the next task" {
  printf 'pr.max_lines: 10\n' > "$REPO/.claude/kern.local.yml"
  write_lines "$WT/b.txt" 17
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 4 ]
  [[ "${lines[0]}" == "size: lines: 17 (git diff --shortstat), -w: 17, files: 1; pr.max_lines: 10 ("*"kern.local.yml); scope_threshold: 4 (default)" ]] || false
  [ "${lines[1]}" = "size: over pr.max_lines: stop for execute-plan step 10's size decision before the next task" ]
}

@test "size-check over scope_threshold, and over both" {
  for f in b c d e f; do write_lines "$WT/$f.txt" 1; done
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 4 ]
  [ "${lines[1]}" = "size: over scope_threshold: stop for execute-plan step 10's size decision before the next task" ]
  printf 'pr.max_lines: 2\n' > "$REPO/.claude/kern.local.yml"
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 4 ]
  [ "${lines[1]}" = "size: over pr.max_lines and scope_threshold: stop for execute-plan step 10's size decision before the next task" ]
}

@test "a size Decision: line in the ledger settles it: exit 0 and the line" {
  printf 'pr.max_lines: 10\n' > "$REPO/.claude/kern.local.yml"
  write_lines "$WT/b.txt" 17
  printf 'Decision: size: one PR, "one PR", lines: 17 (git diff --shortstat), -w 17; why: the user chose; cost if wrong: a big review\n' >> "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = 'size: decided: Decision: size: one PR, "one PR", lines: 17 (git diff --shortstat), -w 17; why: the user chose; cost if wrong: a big review' ]
}

@test "a re-indented file counts every moved line, and -w gives the count without them" {
  printf '  one\n  two\n  three\n' > "$WT/a.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "size: lines: 6 (git diff --shortstat), -w: 0, files: 1; pr.max_lines: 300 (default);"* ]] || false
}

@test "with pr.size_command set the line count is step 10's to take; files are still judged" {
  printf 'pr.max_lines: 10\npr.size_command: echo 1\n' > "$REPO/.claude/kern.local.yml"
  write_lines "$WT/b.txt" 17
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "size: pr.size_command is set: step 10 counts the lines with it" ]
  [ "${lines[2]}" = "size: within the limits" ]
}

@test "size-check refuses a ledger with no Worktree: line or a bad base tree" {
  printf '# kern ledger: plan.md\n' > "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 2 ]
  [ "$stderr" = "size-check: the ledger has no Worktree: line, so there is no plan worktree to size" ]
  printf 'Worktree: %s branch=kern/size-x base-tree=abc\n' "$WT" >> "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/size-check" "$L/ledger.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == "size-check: the Worktree: line's base-tree is not a full object id: abc" ]] || false
}

@test "task-done sizes the plan worktree after a task closed there, and still exits 0 over a limit" {
  printf 'pr.max_lines: 10\n' > "$REPO/.claude/kern.local.yml"
  write_lines "$WT/b.txt" 17
  T1=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$T1" 1 compliant approved > /dev/null
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "docs only" -- true
  [ "$status" -eq 0 ]
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 1 ]
  [[ "${lines[${#lines[@]}-2]}" == "size: lines: 17 (git diff --shortstat), -w: 17, files: 1;"* ]] || false
  [ "${lines[${#lines[@]}-1]}" = "size: over pr.max_lines: stop for execute-plan step 10's size decision before the next task" ]
}

@test "task-done in a wave task's fork does not size: step 10 sizes after step 11" {
  FK=$(bash "$KERN_ROOT/scripts/wt-fork" "$WT" size-x-task-1)
  write_lines "$FK/b.txt" 17
  T1=$(bash "$KERN_ROOT/scripts/wt-snap" "$FK")
  bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$T1" 1 compliant approved > /dev/null
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$FK" "$T1" --no-probe "docs only" -- true
  [ "$status" -eq 0 ]
  [[ "$output" != *"size: "* ]] || false
}
