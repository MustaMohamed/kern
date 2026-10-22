#!/usr/bin/env bats
# tests/run-bats --jobs N: each .bats file runs as its own bats process, N at a time; the run fails when any
# file fails, and every file's TAP output is printed whole. Also the guards that refuse dead assertions.

setup() {
  RUNNER="$BATS_TEST_DIRNAME/../run-bats"
  D="$BATS_TEST_TMPDIR/suite"
  mkdir -p "$D"
  printf '@test "a passes" { true; }\n' >"$D/a.bats"
  printf '@test "b passes" { true; }\n' >"$D/b.bats"
}

@test "--jobs runs every file and passes when all pass" {
  run bash "$RUNNER" --jobs 2 "$D"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^ok')" -eq 2 ]
  [ "$(printf '%s\n' "$output" | grep -c '^# file ')" -eq 2 ]
}

@test "--jobs fails the run when one file fails, and still prints the other" {
  printf '@test "c fails" { false; }\n' >"$D/c.bats"
  run bash "$RUNNER" --jobs 3 "$D"
  [ "$status" -eq 1 ]
  [ "$(printf '%s\n' "$output" | grep -c '^ok')" -eq 2 ]
  printf '%s\n' "$output" | grep -q '^not ok 1 c fails'
  printf '%s\n' "$output" | grep -q '^# FAILED: .*c.bats'
}

@test "--jobs takes a single file as well as a directory" {
  run bash "$RUNNER" --jobs 2 "$D/a.bats"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^ok')" -eq 1 ]
}

@test "--jobs refuses a count that is not a positive number" {
  run bash "$RUNNER" --jobs 0 "$D"
  [ "$status" -eq 2 ]
  run bash "$RUNNER" --jobs x "$D"
  [ "$status" -eq 2 ]
}

# Each file's bats is nested in this test's bats. On Ubuntu sh is dash, which drops the functions
# bats exports, and a nested bats then fails (audit F2); a dash named sh stands in for Ubuntu here.
@test "--jobs runs each file's bats under bash, so a nested bats works where sh is dash" {
  dash=$(command -v dash || true)
  [ -n "$dash" ] || skip "no dash on this machine"
  mkdir "$BATS_TEST_TMPDIR/sh"
  ln -s "$dash" "$BATS_TEST_TMPDIR/sh/sh"
  run env PATH="$BATS_TEST_TMPDIR/sh:$PATH" bash "$RUNNER" --jobs 2 "$D"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^ok')" -eq 2 ]
}

@test "--jobs marks a failed file whose log holds a fork failure as INFRA, and no other file" {
  printf '@test "c forks" { echo "bash: fork: Resource temporarily unavailable"; false; }\n' >"$D/c.bats"
  printf '@test "d fails" { false; }\n' >"$D/d.bats"
  printf '@test "e passes" { echo "bash: fork: Resource temporarily unavailable"; }\n' >"$D/e.bats"
  run bash "$RUNNER" --jobs 2 "$D"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -qxF "# INFRA: fork failures in $D/c.bats"
  [ "$(printf '%s\n' "$output" | grep -c '^# INFRA:')" -eq 1 ]
  [ "$(printf '%s\n' "$output" | grep -c '^# FAILED:')" -eq 2 ]
}

@test "--jobs with no count runs min(6, cores - 1) files at a time, and at least one" {
  mkdir "$BATS_TEST_TMPDIR/bin"
  for cores in 1:1 2:1 4:3 7:6 16:6; do
    printf '#!/bin/sh\necho %s\n' "${cores%%:*}" >"$BATS_TEST_TMPDIR/bin/getconf"
    chmod +x "$BATS_TEST_TMPDIR/bin/getconf"
    run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash "$RUNNER" --jobs "$D"
    [ "$status" -eq 0 ] || { echo "cores ${cores%%:*}: exit $status"; false; }
    [ "$(printf '%s\n' "$output" | head -n 1)" = "# jobs: ${cores#*:}" ] || { echo "cores ${cores%%:*}: $output"; false; }
    [ "$(printf '%s\n' "$output" | grep -c '^ok')" -eq 2 ]
  done
  run bash "$RUNNER" --jobs "$D/missing.bats"
  [ "$status" -eq 2 ]
}

# A command negated with ! never fails a test unless it is the test's last command: errexit ignores it.
@test "run-bats refuses a mid-test ! command with no || false, and takes a last one or one with || false" {
  k="$BATS_TEST_TMPDIR/k"
  mkdir -p "$k/tests"
  cp "$RUNNER" "$k/tests/run-bats"
  printf '@test "x" {\n  ! false\n  true\n}\n' >"$k/tests/x.bats"
  run bash "$k/tests/run-bats" "$k/tests/x.bats"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$k/tests/x.bats:2:  ! false"* ]] || false
  printf '@test "x" {\n  ! false || false\n  true\n  ! false\n  # the last command\n\n}\n' >"$k/tests/x.bats"
  run bash "$k/tests/run-bats" "$k/tests/x.bats"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok 1 x"* ]] || false
}
