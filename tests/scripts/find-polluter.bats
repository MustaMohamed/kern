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
