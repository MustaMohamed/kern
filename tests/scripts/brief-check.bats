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

crlf() { awk '{ printf "%s\r\n", $0 }' "$1" > "$2"; }

@test "a complete CRLF brief still passes" {
  crlf "$B" "$BATS_TEST_TMPDIR/crlf.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/crlf.md"
  [ "$status" -eq 0 ]
  [ "$output" = "brief-check: ok" ]
}

@test "a CRLF brief with an empty field reports it" {
  sed 's/^GOAL .*/GOAL   /' "$B" > "$BATS_TEST_TMPDIR/e.md"
  crlf "$BATS_TEST_TMPDIR/e.md" "$BATS_TEST_TMPDIR/crlf.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/crlf.md"
  [ "$status" -eq 1 ]
  [ "$output" = "empty: GOAL" ]
}

@test "a CRLF brief with a placeholder field reports it" {
  sed 's/^GOAL .*/GOAL        one sentence; the outcome, runnable by someone with no chat access/' "$B" > "$BATS_TEST_TMPDIR/p.md"
  crlf "$BATS_TEST_TMPDIR/p.md" "$BATS_TEST_TMPDIR/crlf.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/crlf.md"
  [ "$status" -eq 1 ]
  [ "$output" = "placeholder: GOAL" ]
}

@test "VERIFY: a lookalike, a later mention or a bare wt-check is refused" {
  for v in 'wt-checkout /w/a origin/main' 'npm test; echo wt-check' 'wt-check' 'wt-check /w/a'; do
    sed "s#^VERIFY .*#VERIFY      $v#" "$B" > "$BATS_TEST_TMPDIR/v.md"
    run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/v.md"
    [ "$status" -eq 1 ]
    [ "$output" = "VERIFY must start with the wt-check entry check" ]
  done
}

@test "VERIFY: the plugin-root and bare forms with worktree and base pass" {
  for v in 'bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-check /w/a origin/main' '/k/scripts/wt-check /w/a origin/main' 'wt-check /w/a origin/main'; do
    sed "s#^VERIFY .*#VERIFY      $v#" "$B" > "$BATS_TEST_TMPDIR/v.md"
    run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/v.md"
    [ "$status" -eq 0 ]
  done
}

@test "every placeholder is caught, bare or with words appended" {
  declare -a PH=(
    "GOAL|one sentence; the outcome, runnable by someone with no chat access"
    "SCOPE|paths this worker may write; paths it may not; its worktree path and base ref"
    "CONTEXT|file pointers; upstream reports pasted in full when this unit depends on them"
    "ACCEPTANCE|checkable criteria, one per line"
    "VERIFY|exact commands, starting with wt-check <wt> <base-ref>, then the focused baseline"
    "TIMEBOX|rough cap; on expiry return partial findings and stop"
    "REPORT|status line, files, commands run with results, deviations, report file path"
    "STANDING|the standing orders below, pasted verbatim"
  )
  local p f t suffix
  for p in "${PH[@]}"; do
    f=${p%%|*}; t=${p#*|}
    for suffix in "" " TODO"; do
      sed "s|^$f .*|$f        $t$suffix|" "$B" > "$BATS_TEST_TMPDIR/ph.md"
      run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/ph.md"
      [ "$status" -eq 1 ]
      [ "${lines[0]}" = "placeholder: $f" ]
    done
  done
}
