#!/usr/bin/env bats
# tests/scripts/find-polluter.bats

setup() {
  KERN_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
  cd "$BATS_TEST_TMPDIR"
  mkdir -p t
  printf 'true\n' > t/a.sh
  printf 'touch polluted\n' > t/b.sh
  printf 'true\n' > t/c.sh
}

@test "finds the test file that creates the path" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 't/*.sh' -- sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"polluter: ./t/b.sh creates polluted"* ]] || false
}

@test "reports no polluter when none creates it" {
  rm t/b.sh
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 't/*.sh' -- sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"no polluter found among 2 test files"* ]] || false
}

@test "refuses when the path already exists" {
  touch polluted
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 't/*.sh' -- sh
  [ "$status" -eq 2 ]
}

@test "a test command that cannot run exits 2, not a clean no-polluter" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 't/*.sh' -- sh -c 'exit 127' x
  [ "$status" -eq 2 ]
  [[ "$output" == *"find-polluter: the test command could not run (exit 127) on ./t/a.sh"* ]] || false
  [[ "$output" != *"no polluter found"* ]] || false
}

@test "a runner that fails on every file proves nothing and exits 2" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 't/*.sh' -- sh -c 'exit 1' x
  [ "$status" -eq 2 ]
  [[ "$output" == *"find-polluter: every test run failed (3 of 3); check TEST_CMD"* ]] || false
}

@test "a mix of passing and failing runs still reports no polluter" {
  rm t/b.sh
  printf 'false\n' > t/a.sh
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 't/*.sh' -- sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"no polluter found among 2 test files"* ]] || false
}

@test "a glob that matches nothing exits 2" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 'none/*.sh' -- sh
  [ "$status" -eq 2 ]
  [[ "$output" == *"no test files match"* ]] || false
}

@test "a missing test command exits 2" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 't/*.sh' -- no-such-runner-xyz
  [ "$status" -eq 2 ]
  [[ "$output" == *"test command not found"* ]] || false
}

@test "a test file name with spaces is run and named whole" {
  rm t/*.sh
  mkdir "t d"
  printf 'touch polluted\n' > "t d/x y.sh"
  run bash "$KERN_ROOT/skills/diagnose/scripts/find-polluter.sh" polluted 't d/*.sh' -- sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"polluter: ./t d/x y.sh creates polluted"* ]] || false
}
