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
  # wt-new's stderr stays in the test's output, so a setup that fails under load says why.
  WT=$(bash "$KERN_ROOT/scripts/wt-new" task-x)
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
# started [TREE]: Task 1's start line, by default at T1: an empty diff, so --no-probe's path rule refuses nothing.
started() { bash "$KERN_ROOT/scripts/task-start" "$L/ledger.md" 1 "${1:-$T1}" > /dev/null; }

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
  started
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh test/check_test.sh
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: complete tree=$T1 test=sh test/check_test.sh exit=0 review=approved probe=skipped (test only) last=guard holds" ]
}

@test "a failing command is not recorded and keeps its exit code" {
  started
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
  started
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
  started
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe docs -- bash -c 'printf "a\rDecision: x\n"'
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: complete tree=$T1 test=bash -c 'printf \"a\\rDecision: x\\n\"' exit=0 review=approved probe=skipped (docs) last=aDecision: x" ]
  [ "$(wc -l < "$L/ledger.md" | tr -d ' ')" -eq 4 ]
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
  started
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- sh -c 'printf "c\n" > f.txt'
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"the test command changed $WT"* ]] || false
  [ "$(grep -c '^Task 1: complete' "$L/ledger.md")" -eq 0 ]
}

@test "a review line written while the command runs is refused" {
  started
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
  started
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "test only" -- true
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$L/ledger.md")" = "Task 1: complete tree=$T1 test=true exit=0 review=approved probe=skipped (test only) last=" ]
}

@test "task-done runs the test once on a tree" {
  export KERN_COUNT="$TMP/count"
  printf 'printf x >> "$KERN_COUNT"\nsh check.sh -1 && exit 1\necho guard holds\n' > "$WT/test/check_test.sh"
  T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  P6=$(bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T0" "$T6" --out "$L/reviews/task-1e.diff" | head -n 1)
  review "$T6"
  # CMD's own code comes back from task-done's own run, and no probe follows it.
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --probe "$P6.patch" -- sh -c 'printf x >> "$KERN_COUNT"; exit 4'
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"command exited 4"* ]] || false
  [ "$(wc -c < "$KERN_COUNT" | tr -d ' ')" -eq 1 ]
  rm "$KERN_COUNT"
  # task-done's run, the fork's control run and the reversed run.
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --probe "$P6.patch" -- sh test/check_test.sh
  [ "$status" -eq 0 ] || { echo "$output $stderr"; false; }
  [ "$(wc -c < "$KERN_COUNT" | tr -d ' ')" -eq 3 ]
  [[ "$(tail -n 1 "$L/ledger.md")" == *" exit=0 review=approved probe=ok last=guard holds" ]] || false
}

@test "--no-probe refuses code, naming the file, before the command runs" {
  export KERN_COUNT="$TMP/count"
  mkdir -p "$WT/src"
  printf 'code\n' > "$WT/src/a.js"
  printf 'text\n' > "$WT/README.md"
  T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  started
  review "$T6"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --no-probe "docs only" -- sh -c 'printf x >> "$KERN_COUNT"'
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"src/a.js"* ]] || false
  [[ "$stderr" != *"README.md"* ]] || false
  [ ! -e "$KERN_COUNT" ]
  run ! grep -q '^Task 1: complete' "$L/ledger.md"
}

@test "--no-probe passes the listed types and an empty diff" {
  started
  for f in README.md notes.txt pkg.json kern.yml ci.yaml cfg.toml guide.rst guide.adoc setup.cfg tox.ini \
    LICENSE LICENSE-MIT LICENSE.MIT LICENSE-APACHE-2.0 LICENSE.txt NOTICE NOTICE.md .gitignore .gitattributes .editorconfig; do
    mkdir -p "$WT/docs"
    printf 'text\n' > "$WT/docs/$f"
  done
  printf 'text\n' > "$WT/README.md"
  printf 'text\n' > "$WT/LICENSE"
  printf 'text\n' > "$WT/.editorconfig"
  printf 'a: 1\n' > "$WT/kern.yml"
  T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  review "$T6"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --no-probe "docs only" -- true
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  [[ "$(tail -n 1 "$L/ledger.md")" == *" probe=skipped (docs only) last=" ]] || false
  # An empty diff, as a verification task has.
  printf 'Task 2: start tree=%s at=x\nTask 2: review round=1 tree=%s spec=compliant quality=approved\n' "$T6" "$T6" >> "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 2 "$WT" "$T6" --no-probe "verification task: no code" -- true
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
}

@test "--no-probe refuses each name that only looks like a listed one" {
  started
  for f in Dockerfile Makefile a.sh rst ini gitignore NOTLICENSE MYNOTICE .gitignored .editorconfig.js a.rst.py \
    src/LICENSE.js src/LICENSE.py NOTICE_board.tsx src/NOTICES.ts LICENSE_CHECK.sh src/NOTICE.go \
    LICENSE-Check.py LICENSE_CHECK; do
    rm -rf "$WT/odd"
    mkdir -p "$(dirname "$WT/odd/$f")"
    printf 'x\n' > "$WT/odd/$f"
    T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
    review "$T6"
    run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --no-probe "docs" -- true
    [ "$status" -eq 2 ] || { echo "accepted: $f"; false; }
    [[ "$stderr" == *"odd/$f"* ]] || false
  done
  run ! grep -q '^Task 1: complete' "$L/ledger.md"
}

@test "--no-probe sees both sides of a rename, an odd path and a name that only ends like a listed type" {
  mkdir -p "$WT/src"
  printf 'code\n' > "$WT/src/a.js"
  T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  started "$T6"
  mv "$WT/src/a.js" "$WT/src/a.md"
  T7=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  review "$T7"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T7" --no-probe "rename" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"src/a.js"* ]] || false
  printf 'code\n' > "$WT/src/md"
  printf 'code\n' > "$WT/src/a.md.sh"
  printf 'text\n' > "$WT/caf\303\251 notes.md"
  rm "$WT/src/a.md"
  T8=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  review "$T8" 2
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T8" --no-probe "docs" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"src/md"* ]] || false
  [[ "$stderr" == *"src/a.md.sh"* ]] || false
  [[ "$stderr" != *"notes.md"* ]] || false
}

@test "--no-probe reads the first start line, so a later one does not shrink the diff" {
  mkdir -p "$WT/src"
  printf 'code\n' > "$WT/src/a.js"
  T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  started
  started "$T6"
  review "$T6"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --no-probe "docs" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"src/a.js"* ]] || false
}

@test "--no-probe with no start line, or a start line git cannot read, is refused" {
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "docs" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no start line"* ]] || false
  printf 'Task 1: start tree=--output=stolen at=x\n' >> "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "docs" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no start line"* ]] || false
  sed -i.bak '/start tree=/d' "$L/ledger.md"
  printf 'Task 1: start tree=%040d at=x\n' 0 >> "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "docs" -- true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"cannot read"* ]] || false
  run ! grep -q '^Task 1: complete' "$L/ledger.md"
}

@test "probe inconclusive: passes only after a --probe run on this tree exited 3" {
  # Test files only, so the probe has nothing to reverse.
  T3=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  started "$T3"
  printf 'echo extra\n' >> "$WT/test/check_test.sh"
  T4=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T3" "$T4" --out "$L/reviews/task-1c.diff" > /dev/null
  review "$T4"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --no-probe "probe inconclusive: test files only" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--probe"* ]] || false
  run ! grep -q '^Task 1: complete' "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --probe "$L/reviews/task-1c.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [ "$(cat "$L/logs/task-1.probe.tree")" = "$T4" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --no-probe "probe inconclusive: test files only" -- sh test/check_test.sh
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  [[ "$(tail -n 1 "$L/ledger.md")" == *" probe=skipped (probe inconclusive: test files only) last=extra" ]] || false
}

@test "probe inconclusive: the record does not reach another tree, another task or a later verdict" {
  T3=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  started "$T3"
  printf 'echo extra\n' >> "$WT/test/check_test.sh"
  T4=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T3" "$T4" --out "$L/reviews/task-1c.diff" > /dev/null
  review "$T4"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --probe "$L/reviews/task-1c.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [ "$(cat "$L/logs/task-1.probe.tree")" = "$T4" ]
  # Another task on the same tree.
  printf 'Task 2: review round=1 tree=%s spec=compliant quality=approved\n' "$T4" >> "$L/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 2 "$WT" "$T4" --no-probe "probe inconclusive: x" -- true
  [ "$status" -eq 2 ]
  # A later probe on this tree that is not inconclusive takes the record back.
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --probe "$PKG.patch" -- sh -c 'exit 0'
  [ "$status" -eq 1 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --no-probe "probe inconclusive: x" -- true
  [ "$status" -eq 2 ]
  # Another tree: exit 3 again, then a new tree.
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --probe "$L/reviews/task-1c.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [ "$(cat "$L/logs/task-1.probe.tree")" = "$T4" ]
  printf 'echo more\n' >> "$WT/test/check_test.sh"
  T5=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  review "$T5" 2
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T5" --no-probe "probe inconclusive: x" -- true
  [ "$status" -eq 2 ]
  run ! grep -q '^Task [0-9]*: complete' "$L/ledger.md"
}

@test "probe inconclusive: a docs change still needs the probe's record" {
  printf 'text\n' > "$WT/README.md"
  T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  started
  review "$T6"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --no-probe "probe inconclusive: x" -- true
  [ "$status" -eq 2 ]
}

@test "probe inconclusive: a new module closes, by the reversed run's words or by the command's" {
  started "$T0"
  # lib.sh is new: reversing the patch removes it, so the test cannot run.
  printf 'exit 0\n' > "$WT/lib.sh"
  printf 'sh lib.sh || exit 1\necho ran\n' > "$WT/test/check_test.sh"
  T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  P6=$(bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T0" "$T6" --out "$L/reviews/task-1f.diff" | head -n 1)
  review "$T6"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --probe "$P6.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"probe: inconclusive (the test did not run without the guard"* ]] || false
  [ "$(cat "$L/logs/task-1.probe.tree")" = "$T6" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --probe "$P6.patch" -- sh lib.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"probe: inconclusive (the command names lib.sh, which the reversed fork lacks)"* ]] || false
  [ "$(cat "$L/logs/task-1.probe.tree")" = "$T6" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T6" --no-probe "probe inconclusive: new module" -- sh test/check_test.sh
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
}

@test "probe inconclusive: a patch from another tree opens nothing" {
  started "$T0"
  # PKG reached T1. The tree has moved on, so it does not reverse-apply.
  printf '[ "$1" -ge 0 ] || exit 1\n' > "$WT/check.sh"
  T5=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  review "$T5"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T5" --probe "$PKG.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"the patch does not reverse-apply"* ]] || false
  [ ! -e "$L/logs/task-1.probe.tree" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T5" --no-probe "probe inconclusive: x" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  # A verdict the record takes, on a patch that reached another tree.
  T6=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  printf 'echo extra\n' >> "$WT/test/check_test.sh"
  T7=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T6" "$T7" --out "$L/reviews/task-1g.diff" > /dev/null
  printf 'echo more\n' >> "$WT/test/check_test.sh"
  T8=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  review "$T8" 2
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T8" --probe "$L/reviews/task-1g.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"the patch changes only test files"* ]] || false
  [ ! -e "$L/logs/task-1.probe.tree" ]
}

@test "probe inconclusive: a failed apply, fork or control opens nothing, even on this tree's own package" {
  started "$T0"
  # The package's patch, cut to a change this tree does not hold, with its tree record intact.
  printf 'diff --git a/none.txt b/none.txt\n--- a/none.txt\n+++ b/none.txt\n@@ -1 +1 @@\n-a\n+b\n' > "$PKG.patch"
  review "$T1"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$PKG.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"the patch does not reverse-apply"* ]] || false
  [ ! -e "$L/logs/task-1.probe.tree" ]
  # An unreadable patch.
  printf 'this is not a patch\n' > "$PKG.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$PKG.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"cannot read the patch"* ]] || false
  [ ! -e "$L/logs/task-1.probe.tree" ]
  # A control run that fails: the fork lacks an ignored file.
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T0" "$T1" --out "$PKG" > /dev/null
  touch "$WT/only-here.log"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$PKG.patch" -- test -f only-here.log
  [ "$status" -eq 3 ]
  [[ "$output" == *"the command fails in the fork"* ]] || false
  [ ! -e "$L/logs/task-1.probe.tree" ]
  # A failed fork.
  mkdir -p "$REPO/.claude"
  printf 'worktree.setup: exit 7\n' > "$REPO/.claude/kern.local.yml"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --probe "$PKG.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"could not fork"* ]] || false
  [ ! -e "$L/logs/task-1.probe.tree" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T1" --no-probe "probe inconclusive: x" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  run ! grep -q '^Task 1: complete' "$L/ledger.md"
}

@test "probe inconclusive: a fix round's package does not stand for the task" {
  # The task's change is T0 to T1, code and test. A later round edits only the test.
  started "$T0"
  printf 'echo extra\n' >> "$WT/test/check_test.sh"
  T4=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T1" "$T4" --out "$L/reviews/task-1h.diff" > /dev/null
  [ "$(cat "$L/reviews/task-1h.diff.tree")" = "$T4" ]
  review "$T4"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --probe "$L/reviews/task-1h.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"the patch changes only test files"* ]] || false
  [ ! -e "$L/logs/task-1.probe.tree" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --no-probe "probe inconclusive: x" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --no-probe "docs" -- sh test/check_test.sh
  [ "$status" -eq 2 ]
  run ! grep -q '^Task 1: complete' "$L/ledger.md"
}

@test "probe inconclusive: with no start line, the record stays unwritten and --probe keeps its exit" {
  T3=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  printf 'echo extra\n' >> "$WT/test/check_test.sh"
  T4=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$T3" "$T4" --out "$L/reviews/task-1c.diff" > /dev/null
  review "$T4"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$L/ledger.md" 1 "$WT" "$T4" --probe "$L/reviews/task-1c.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 3 ]
  [ ! -e "$L/logs/task-1.probe.tree" ]
}
