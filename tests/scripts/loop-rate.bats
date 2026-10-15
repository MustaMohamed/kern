#!/usr/bin/env bats
# tests/scripts/loop-rate.bats

setup() {
  KERN_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
  cd "$BATS_TEST_TMPDIR"
  # Red on every second run: a counter file the loop command bumps.
  printf 'n=$(cat count 2>/dev/null || echo 0); n=$((n + 1)); echo $n > count; [ $((n %% 2)) -eq 1 ]\n' > flaky.sh
}

@test "a steady command is 0 red, with a median in seconds" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/loop-rate.sh" 3 -- true
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^loop-rate:\ 0/3\ red,\ median\ [0-9.]+s$ ]] || false
}

@test "a flaky command reports its red count" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/loop-rate.sh" 5 -- sh flaky.sh
  [ "$status" -eq 0 ]
  [[ "$output" == "loop-rate: 2/5 red, median "* ]] || false
}

@test "a bad N or a missing -- exits 2" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/loop-rate.sh" 0 -- true
  [ "$status" -eq 2 ]
  run bash "$KERN_ROOT/skills/diagnose/scripts/loop-rate.sh" 3 true
  [ "$status" -eq 2 ]
}

@test "a command that cannot run exits 2, not N/N red" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/loop-rate.sh" 2 -- sh -c 'exit 127'
  [ "$status" -eq 2 ]
  [[ "$output" == *"loop-rate: the command could not run (exit 127)"* ]] || false
  [[ "$output" != *"red, median"* ]] || false
}

@test "a leading-zero N is read as decimal" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/loop-rate.sh" 003 -- true
  [ "$status" -eq 0 ]
  [[ "$output" == "loop-rate: 0/3 red, median "* ]] || false
}

@test "a ten-digit N is rejected" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/loop-rate.sh" 1000000000 -- true
  [ "$status" -eq 2 ]
}

@test "a missing command exits 2" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/loop-rate.sh" 2 -- no-such-runner-xyz
  [ "$status" -eq 2 ]
}
