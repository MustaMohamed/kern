#!/usr/bin/env bats
# tests/run-bats --jobs N: each .bats file runs as its own bats process, N at a time; the run fails when any
# file fails, and every file's TAP output is printed whole.

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
