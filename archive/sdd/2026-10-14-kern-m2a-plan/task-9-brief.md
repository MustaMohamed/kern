### Task 9: Review lines and task completion

**Files:**
- Create: `scripts/task-review`, `scripts/task-done`
- Test: `tests/scripts/task-done.bats`

**Interfaces:**
- Consumes: `wt-snap`, `wt-diff` (Task 2); `probe --exclude-tests` (Task 6); a ledger from `ledger-open` (Task 8).
- Produces:
  - `task-review LEDGER N TREE ROUND SPEC QUALITY [--minor TEXT]...`: SPEC is `compliant` or `issues`, QUALITY `approved` or `needs-fixes`, ROUND `1`, `2` or `3`. Appends and prints `Task N: review round=<r> tree=<id> spec=<s> quality=<q>`, then one `Task N: minor (deferred): <text>` line per `--minor`. Exit 2 on any malformed argument, writing nothing.
  - `task-done LEDGER N WT TREE (--probe PATCH | --no-probe REASON) -- CMD...`: one of the two is required (pre-flight 1 #14: without it a task closed with `probe=none` and nothing said why); exit 2, writing nothing, when neither is given, REASON is empty, `wt-snap WT` is not TREE, or task N's last review line is not `... tree=TREE spec=compliant quality=approved`. Runs CMD in WT, keeps its output in `<ledger dir>/logs/task-N.log` and prints the last 5 lines; CMD's code when it fails. With `--probe PATCH`, then runs `probe --exclude-tests WT PATCH -- CMD`: exit 1 (writing nothing) when the test passes with the change reversed. On success appends `Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok|inconclusive|skipped (REASON)> last=<last non-blank output line>`.

- [ ] **Step 1: Write the failing tests**

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/task-done.bats`
Expected: every test fails with `No such file or directory` for `scripts/task-review` or `scripts/task-done`.

- [ ] **Step 3: Write `scripts/task-review`**

```bash
#!/usr/bin/env bash
# Record one task review in an execute-plan ledger: the two verdicts for one tree id, and any minor
# findings deferred to the final review.
# Usage: task-review LEDGER N TREE ROUND SPEC QUALITY [--minor TEXT]...
#   SPEC is compliant or issues; QUALITY is approved or needs-fixes; ROUND is 1, 2 or 3.
# Appends and prints: Task N: review round=<r> tree=<id> spec=<s> quality=<q>
# and one "Task N: minor (deferred): <text>" line per --minor. Exit 2 on any malformed argument.
# Deferred-minor line from superpowers subagent-driven-development SKILL.md (MIT).
set -euo pipefail
usage() { echo "usage: task-review LEDGER N TREE ROUND SPEC QUALITY [--minor TEXT]..." >&2; exit 2; }
[ $# -ge 6 ] || usage
ledger=$1 n=$2 tree=$3 round=$4 spec=$5 quality=$6
shift 6
[ -f "$ledger" ] || { echo "task-review: no ledger at $ledger" >&2; exit 2; }
case "$n" in '' | *[!0-9]*) echo "task-review: N must be a number: $n" >&2; exit 2 ;; esac
printf '%s' "$tree" | grep -Eq '^[0-9a-f]{40}([0-9a-f]{24})?$' ||
  { echo "task-review: TREE must be a full object id: $tree" >&2; exit 2; }
case "$round" in 1 | 2 | 3) ;; *) echo "task-review: ROUND is 1, 2 or 3 (D10): $round" >&2; exit 2 ;; esac
case "$spec" in compliant | issues) ;; *) echo "task-review: SPEC is compliant or issues: $spec" >&2; exit 2 ;; esac
case "$quality" in approved | needs-fixes) ;; *) echo "task-review: QUALITY is approved or needs-fixes: $quality" >&2; exit 2 ;; esac
minors=''
nl='
'
while [ $# -gt 0 ]; do
  [ "$1" = --minor ] && [ $# -ge 2 ] && [ -n "$2" ] || usage
  case "$2" in *"$nl"*) echo "task-review: a --minor text is one line" >&2; exit 2 ;; esac
  minors="${minors}Task $n: minor (deferred): $2$nl"
  shift 2
done
line="Task $n: review round=$round tree=$tree spec=$spec quality=$quality"
printf '%s\n%s' "$line" "$minors" >> "$ledger"
printf '%s\n%s' "$line" "$minors"
```

- [ ] **Step 4: Write `scripts/task-done`**

```bash
#!/usr/bin/env bash
# Close a task in an execute-plan ledger. Writes the completion line only when all hold: the worktree
# still snapshots to TREE, the task's last review approved exactly that tree, CMD exits 0 in WT, and
# the test fails once the change (test files excluded) is reversed on a throwaway fork. A task with no
# test to probe (docs, config) names why with --no-probe, and the reason goes into the ledger.
# Usage: task-done LEDGER N WT TREE (--probe PATCH | --no-probe REASON) -- CMD...
# Appends: Task N: complete tree=<id> test=<cmd> exit=0 review=approved probe=<ok|inconclusive|skipped (REASON)> last=<line>
# Exit 2 when a check fails (nothing written); 1 when the probe shows the test passes without the
# change; CMD's own code when it fails.
# Adapted from superpowers executing-plans/scripts/task-done (MIT).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
usage() { echo "usage: task-done LEDGER N WT TREE (--probe PATCH | --no-probe REASON) -- CMD..." >&2; exit 2; }
[ $# -ge 8 ] || usage
ledger=$1 n=$2 wt=$3 tree=$4
shift 4
patch='' skip=''
case "$1" in
  --probe) patch=$2 ;;
  --no-probe) skip=$2; [ -n "$skip" ] || { echo "task-done: --no-probe needs a reason" >&2; exit 2; } ;;
  *) echo "task-done: name --probe PATCH, or --no-probe REASON for a task with no test to probe" >&2; exit 2 ;;
esac
shift 2
[ "$1" = -- ] && [ $# -ge 2 ] || usage
shift
[ -f "$ledger" ] || { echo "task-done: no ledger at $ledger" >&2; exit 2; }
case "$n" in '' | *[!0-9]*) echo "task-done: N must be a number: $n" >&2; exit 2 ;; esac
printf '%s' "$tree" | grep -Eq '^[0-9a-f]{40}([0-9a-f]{24})?$' ||
  { echo "task-done: TREE must be a full object id: $tree" >&2; exit 2; }
wt=$(cd "$wt" 2> /dev/null && pwd -P) || { echo "task-done: no such worktree: $3" >&2; exit 2; }

now=$(bash "$here/wt-snap" "$wt")
if [ "$now" != "$tree" ]; then
  echo "task-done: $wt changed after the review (tree ${tree:0:7}, now ${now:0:7}); review the new tree first" >&2
  exit 2
fi
review=$(grep "^Task $n: review " "$ledger" | tail -n 1 || true)
case "$review" in
  *" tree=$tree spec=compliant quality=approved") ;;
  '') echo "task-done: Task $n has no review line; run the review and record it with task-review" >&2; exit 2 ;;
  *) echo "task-done: Task $n's last review did not approve tree ${tree:0:7}: $review" >&2; exit 2 ;;
esac

logdir="$(dirname "$ledger")/logs"
mkdir -p "$logdir"
log="$logdir/task-$n.log"
cmd=''
for a in "$@"; do
  case "$a" in
    *[[:space:]\"\;\|\&\']*) cmd="$cmd '$a'" ;;
    *) cmd="$cmd $a" ;;
  esac
done
cmd=${cmd# }

rc=0
(cd "$wt" && "$@") > "$log" 2>&1 || rc=$?
tail -n 5 "$log"
if [ "$rc" -ne 0 ]; then
  echo "task-done: command exited $rc; Task $n not recorded (log: $log)" >&2
  exit "$rc"
fi

probe="skipped ($skip)"
if [ -n "$patch" ]; then
  prc=0
  bash "$here/probe" --exclude-tests "$wt" "$patch" -- "$@" > "$logdir/task-$n.probe.log" 2>&1 || prc=$?
  head -n 1 "$logdir/task-$n.probe.log"
  case "$prc" in
    0) probe=ok ;;
    3) probe=inconclusive ;;
    1) echo "task-done: the test passes with the change reversed, so it does not prove Task $n; not recorded" >&2; exit 1 ;;
    *) echo "task-done: probe exited $prc; Task $n not recorded (log: $logdir/task-$n.probe.log)" >&2; exit 2 ;;
  esac
fi
last=$(grep -v '^[[:space:]]*$' "$log" | tail -n 1 || true)
line="Task $n: complete tree=$tree test=$cmd exit=0 review=approved probe=$probe last=$last"
printf '%s\n' "$line" >> "$ledger"
echo "ledger: $line"
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `chmod +x scripts/task-review scripts/task-done && tests/run-bats tests/scripts/task-done.bats && shellcheck scripts/task-review scripts/task-done`
Expected: `11 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 6: Commit**

```bash
git add -- scripts/task-review scripts/task-done tests/scripts/task-done.bats
git commit -m "M2: add task-review; task-done closes only a reviewed, proven tree" -m "The ledger stamped review=approved without a review; now the stamp needs a recorded approval of the same tree, and --probe shows the test fails without the change."
```

---

