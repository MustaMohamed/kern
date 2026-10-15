#!/usr/bin/env bats
# tests/scripts/hitl-loop.bats

setup() {
  KERN_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
}

@test "closed stdin exits 1 with a message" {
  run bash "$KERN_ROOT/skills/diagnose/scripts/hitl-loop.template.sh" < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"hitl-loop: input closed"* ]] || false
}

@test "answers print as KEY=VALUE with CR removed" {
  run bash -c "printf '\\ny\\nboom\\r\\n' | bash '$KERN_ROOT/skills/diagnose/scripts/hitl-loop.template.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ERRORED=y"* ]] || false
  [[ "$output" == *"ERROR_MSG=boom"* ]] || false
}
