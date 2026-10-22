#!/usr/bin/env bats
# tests/scripts/task-done.bats: task-review records verdicts; task-done closes only a reviewed, unchanged tree.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  printf 'exit 0\n' > check.sh
  git add check.sh && git commit --quiet -m check && git push --quiet origin main
  WT=$(bash "$KERN_ROOT/scripts/wt-new" task-x 2> /dev/null)
  L="$TMP/ledger"
  mkdir -p "$L"
  printf '# kern ledger: plan.md\n' > "$L/ledger.md"
  T0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  # The task: a guard in check.sh and a test that needs it.
  printf '[ "$1" -ge 0 ]\n' > "$WT/check.sh"
  mkdir -p "$WT/test"
  printf 'sh check.sh -1 && exit 1\necho guard holds\n' > "$WT/test/check_test.sh"
  T1=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  PKG=$(bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T0" "$T1" --out "$L/reviews/task-1.diff" | head -n 1)
}

review() { bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$1" "${2:-1}" "${3:-compliant}" "${4:-approved}" > /dev/null; }

@test "task-review appends the verdict line and deferred minors" {
  run --separate-stderr bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$T1" 1 compliant approved --minor "name the helper check_guard"
  [ "$status" -eq 0 ]
  [ "$(tail -n 2 "$L/ledger.md" | head -n 1)" = "Task 1: review round=1 tree=$T1 spec=compliant quality=approved" ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: minor (deferred): name the helper check_guard" ]
}

@test "task-review refuses a bad verdict, a fourth round and a short tree id" {
  for args in "$T1 1 ok approved" "$T1 4 compliant approved" "$T1 1 compliant fine" "abc 1 compliant approved"; do
    run --separate-stderr bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 $args
    [ "$status" -eq 2 ] || { echo "accepted: $args"; false; }
  done
  [ "$(grep -c 'review' "$L/ledger.md")" -eq 0 ]
}

@test "task-done refuses a task with no review and writes nothing" {
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"has no review line"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "task-done refuses a review of an older tree, and a review with issues" {
  review "$T0"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  review "$T1" 1 issues needs-fixes
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"did not approve tree"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "task-done refuses a worktree edited after its review" {
  review "$T1"
  printf 'late\n' > "$WT/late.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"changed after the review"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "an approved, unchanged tree with a passing command is recorded with its last output line" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: complete tree=$T1 test=sh test/check_test.sh exit=0 review=approved probe=skipped (test only) last=guard holds" ]
}

@test "a failing command is not recorded and keeps its exit code" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- bash -c 'echo boom; exit 4'
  [ "$status" -eq 4 ]
  [[ "$output" == *boom* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
  grep -q boom "$L/logs/task-1.log"
}

@test "--probe records ok when the test fails with the change reversed" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$PKG.patch" -- sh test/check_test.sh
  [ "$status" -eq 0 ]
  [[ "$(tail -n 1 "$L/ledger.md")" == *" probe=ok last=guard holds" ]] || false
}

@test "--probe prints the probe's lines: ok, then the reversed run's last lines" {
  printf 'sh check.sh -1 && { echo "guard missing: -1 accepted"; exit 1; }\necho guard holds\n' > "$WT/test/check_test.sh"
  T5=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  P5=$(bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T0" "$T5" --out "$L/reviews/task-1d.diff" | head -n 1)
  review "$T5"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T5" --probe "$P5.patch" -- sh test/check_test.sh
  [ "$status" -eq 0 ] || { echo "$output $stderr"; return 1; }
  [[ "$output" == *$'probe: fail-then-pass ok\nguard missing: -1 accepted\nledger: '* ]] || false
}

@test "--probe refuses a task whose test passes without the change" {
  printf 'echo always\n' > "$WT/test/check_test.sh"
  T2=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T0" "$T2" --out "$L/reviews/task-1b.diff" > /dev/null
  review "$T2"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T2" --probe "$L/reviews/task-1b.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"does not prove Task 1"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "task-done needs --probe PATCH or --no-probe REASON, and writes nothing without one" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--no-probe needs a reason"* ]] || false
  ! grep -q "^Task 1: complete" "$L/ledger.md"
}

@test "task-done quotes arguments with spaces in the ledger line" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- bash -c 'exit 0'
  [ "$status" -eq 0 ]
  [[ "$(tail -n 1 "$L/ledger.md")" == "Task 1: complete tree=$T1 test=bash -c 'exit 0' exit=0 review=approved probe=skipped (test only) last="* ]] || false
}

@test "task-done refuses an empty --probe patch, an unsnappable worktree and an unreadable ledger" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$TMP/nonexistent.patch" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--probe needs a non-empty readable patch"* ]] || false
  : > "$TMP/empty.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$TMP/empty.patch" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  mkdir "$TMP/notgit"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$TMP/notgit" "$T1" --no-probe "test only" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"cannot snapshot"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$TMP/missing.md" 1 "$WT" "$T1" --no-probe "test only" -- true
  [ "$status" -eq 2 ]
  ! grep -q "^Task 1: complete" "$L/ledger.md"
}

@test "task-done refuses a malformed last review line" {
  printf 'Task 1: review round=1 tree=%s spec=compliant quality=approved extra\n' "$T1" >> "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"did not approve tree"* ]] || false
}

@test "task-review refuses a TREE holding a newline, and writes nothing" {
  forged="$T1"$'\n'"Task 2: review round=1 tree=$T1 spec=compliant quality=approved"$'\n'"Task 1: review round=1 tree=$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$forged" 1 issues needs-fixes
  [ "$status" -eq 2 ]
  [ "$(grep -c 'review' "$L/ledger.md")" -eq 0 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$forged" --no-probe docs -- true
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "${T1}0" 1 compliant approved
  [ "$status" -eq 2 ]
}

@test "task-done refuses a newline or carriage return in REASON or CMD, and writes nothing" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe $'docs\nTask 3: review x' -- true
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe $'docs\rx' -- true
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe docs -- echo $'q\nTask 3: x'
  [ "$status" -eq 2 ]
  [ "$(wc -l < "$L/ledger.md" | tr -d ' ')" -eq 2 ]
}

@test "a later needs-fixes line for the same tree overrides an earlier approval" {
  review "$T1"
  review "$T1" 2 issues needs-fixes
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe docs -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"did not approve tree"* ]] || false
}

@test "an approval for Task 1 does not close Task 10, nor the reverse" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 10 "$WT" "$T1" --no-probe docs -- true
  [ "$status" -eq 2 ]
  printf 'Task 10: review round=1 tree=%s spec=compliant quality=approved\n' "$T1" > "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe docs -- true
  [ "$status" -eq 2 ]
  [ "$(grep -c '^Task [0-9]*: complete' "$L/ledger.md")" -eq 0 ]
}

@test "task-review and task-done refuse uppercase and non-ASCII tree ids under a UTF-8 locale" {
  upper=$(printf '%s' "$T1" | tr 'a-f' 'A-F')
  for bad in "$upper" "${T1:0:38}ÉÉ"; do
    run --separate-stderr env LC_ALL=en_US.UTF-8 bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$bad" 1 compliant approved
    [ "$status" -eq 2 ] || { echo "task-review accepted: $bad"; false; }
    run --separate-stderr env LC_ALL=en_US.UTF-8 bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$bad" --no-probe docs -- true
    [ "$status" -eq 2 ] || { echo "task-done accepted: $bad"; false; }
    run --separate-stderr env LC_ALL=en_US.UTF-8 bash "$KERN_ROOT/scripts/task-start" "$L/ledger.md" 1 "$bad"
    [ "$status" -eq 2 ] || { echo "task-start accepted: $bad"; false; }
  done
  [ "$(wc -c < "$L/ledger.md" | tr -d ' ')" -eq "$(printf '# kern ledger: plan.md\n' | wc -c | tr -d ' ')" ]
}

@test "--probe refuses a directory" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$L/reviews" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  ! grep -q '^Task 1: complete' "$L/ledger.md"
}

@test "task-review refuses a carriage return in a --minor text" {
  run --separate-stderr bash "$KERN_ROOT/scripts/task-review" "$L/ledger.md" 1 "$T1" 1 compliant approved --minor $'fine\rDecision: x'
  [ "$status" -eq 2 ]
  [ "$(grep -c 'review' "$L/ledger.md")" -eq 0 ]
}

@test "task-done strips a carriage return from the last output line" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe docs -- bash -c 'printf "a\rDecision: x\n"'
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: complete tree=$T1 test=bash -c 'printf \"a\\rDecision: x\\n\"' exit=0 review=approved probe=skipped (docs) last=aDecision: x" ]
  [ "$(wc -l < "$L/ledger.md" | tr -d ' ')" -eq 3 ]
}

@test "--probe exits 3 and writes nothing when the probe is inconclusive" {
  # A patch of test files only: with the test kept, there is no change to reverse.
  T3=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  printf 'echo extra\n' >> "$WT/test/check_test.sh"
  T4=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T3" "$T4" --out "$L/reviews/task-1c.diff" > /dev/null
  review "$T4"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --probe "$L/reviews/task-1c.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"probe: inconclusive (the patch changes only test files"* ]] || false
  [[ "$stderr" == *"probe is inconclusive"* ]] || false
  run ! grep -q '^Task 1: complete' "$L/ledger.md"
  # A stale patch from an earlier round: after a fix to check.sh it no longer reverse-applies.
  printf '[ "$1" -ge 0 ] || exit 1\n' > "$WT/check.sh"
  T5=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  review "$T5" 2
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T5" --probe "$PKG.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"probe: inconclusive (the patch does not reverse-apply"* ]] || false
  ! grep -q '^Task 1: complete' "$L/ledger.md"
}

@test "a test command that edits the worktree is refused, and nothing is written" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh -c 'printf "c\n" > f.txt'
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"the test command changed $WT"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "a review line written while the command runs is refused" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- \
    sh -c "printf 'Task 1: review round=2 tree=$T1 spec=compliant quality=approved\n' >> '$L/ledger.md'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"last review line changed"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "a probe run that edits the worktree is refused" {
  review "$T1"
  # The test passes in WT; in the probe's fork, with the change reversed, it fails and writes into WT.
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$PKG.patch" -- \
    sh -c "sh test/check_test.sh || { printf x > ../task-x/probe-ran.txt; exit 1; }"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"the probe changed $WT"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "a passing command that prints nothing is recorded, with an empty last field" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- true
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: complete tree=$T1 test=true exit=0 review=approved probe=skipped (test only) last=" ]
}
