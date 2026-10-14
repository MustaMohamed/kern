#!/usr/bin/env bats
# tests/scripts/brief-check.bats

bats_require_minimum_version 1.5.0

setup() {
  KERN_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
  B="$BATS_TEST_TMPDIR/brief.md"
  printf '%s\n' \
    'GOAL        Make sum() reject strings.' \
    'SCOPE       write src/sum.js and test/sum.test.js only; worktree /w/a; base origin/main' \
    'CONTEXT     src/sum.js:1-10' \
    'ACCEPTANCE  sum("1", 2) throws a TypeError' \
    'VERIFY      bash /k/scripts/wt-check /w/a origin/main' \
    '            npm test -- test/sum.test.js' \
    'TIMEBOX     20 minutes' \
    'FORBIDDEN   commit, push, writes outside SCOPE' \
    'REPORT      status line, files, commands with results, report at /w/a.report.md' \
    'STANDING    the standing orders, pasted' > "$B"
}

@test "a complete brief passes, including a field continued on indented lines" {
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "brief-check: ok" ]
}

@test "a missing field and an empty field are each named" {
  sed -i.bak -e '/^TIMEBOX/d' -e 's/^REPORT .*/REPORT/' "$B"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$B"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "missing: TIMEBOX" ]
  [ "${lines[1]}" = "empty: REPORT" ]
}

@test "VERIFY must start with the entry check" {
  sed -i.bak 's#^VERIFY .*#VERIFY      npm test#' "$B"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$B"
  [ "$status" -eq 1 ]
  [ "$output" = "VERIFY must start with the wt-check entry check" ]
}

@test "a field whose text is on the next indented line counts" {
  sed -i.bak 's/^GOAL .*/GOAL/' "$B"
  sed -i.bak '/^GOAL$/a\
            Make sum() reject strings.
' "$B"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$B"
  [ "$status" -eq 0 ]
}

@test "a label inside a word does not count, and an unreadable file exits 2" {
  printf 'GOALS are set\n' > "$BATS_TEST_TMPDIR/x.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/x.md"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "missing: GOAL" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/none.md"
  [ "$status" -eq 2 ]
}

@test "a field still holding the template placeholder is not filled in" {
  sed 's/^GOAL .*/GOAL        one sentence; the outcome, runnable by someone with no chat access/' "$B" > "$BATS_TEST_TMPDIR/ph.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/ph.md"
  [ "$status" -eq 1 ]
  [ "$output" = "placeholder: GOAL" ]
}
