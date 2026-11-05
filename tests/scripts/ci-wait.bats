#!/usr/bin/env bats
# tests/scripts/ci-wait.bats: scripts/ci-wait reads a PR's checks with hooks/lib/ci.sh's ci_read until they settle
# (M3 part 2 project 2, Task 3). gh is a stub (helpers/common.bash fake_gh); KERN_CI_INTERVAL, KERN_CI_SETTLE and
# KERN_CI_MINUTE shorten the clock.

bats_require_minimum_version 1.5.0
load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  fake_gh
  unset FAKE_GH_CHECKS FAKE_GH_CHECKS_FILE FAKE_GH_RC FAKE_GH_STDERR FAKE_GH_STDERR_FIRST GH_DEBUG
  export FAKE_GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export KERN_CI_INTERVAL=1
  unset KERN_CI_SETTLE KERN_CI_MINUTE
  W="$(kern_root)/scripts/ci-wait"
  mkdir -p "$R/.claude"
}

# reads: how many times the stub answered `gh pr checks`.
reads() {
  [ -f "$FAKE_GH_LOG" ] || { echo 0; return 0; }
  wc -l <"$FAKE_GH_LOG" | tr -d ' '
}

@test "all checks pass: clear" {
  export FAKE_GH_CHECKS='[{"bucket":"pass","name":"build"},{"bucket":"pass","name":"lint"},{"bucket":"skipping","name":"deploy"}]'
  cd "$BATS_TEST_TMPDIR"
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[0]}" = "check: build: pass" ]
  [ "${lines[1]}" = "check: lint: pass" ]
  [ "${lines[2]}" = "check: deploy: skipping" ]
  [ "${lines[3]}" = "ci: clear" ]
  # One read, run in the worktree it names, not in the caller's directory.
  [ "$(cat "$FAKE_GH_LOG")" = "$(cd "$R" && pwd -P)" ]
}

@test "a failed or cancelled check is red and wins over pending" {
  export FAKE_GH_CHECKS='[{"bucket":"fail","name":"lint"},{"bucket":"cancel","name":"e2e"},{"bucket":"pending","name":"build"}]'
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 1 ]
  [ "${lines[2]}" = "check: build: pending" ]
  [ "${lines[3]}" = "ci: red lint, e2e" ]
  [ "$(reads)" -eq 1 ]
}

@test "an advisory check never gates" {
  export FAKE_GH_CHECKS='[{"bucket":"pass","name":"build"},{"bucket":"fail","name":"sonar"}]'
  printf 'ci.advisory: sonar\n' >"$R/.claude/kern.local.yml"
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 0 ]
  [ "$output" = "check: build: pass"$'\n'"ci: clear" ]
  # The names match exactly and in case: Sonar is not sonar.
  printf 'ci.advisory: Sonar, son\n' >"$R/.claude/kern.local.yml"
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 1 ]
  [ "${lines[2]}" = "ci: red sonar" ]
}

@test "no checks after the settle time: none" {
  export FAKE_GH_CHECKS='[]' KERN_CI_SETTLE=1
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 0 ]
  [ "$output" = "ci: none" ]
  [ "$(reads)" -ge 2 ]
  # gh's own words for a PR with no checks read the same.
  unset FAKE_GH_CHECKS
  export FAKE_GH_RC=1 FAKE_GH_STDERR="no checks reported on the 'feat/x' branch"
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 0 ]
  [ "$output" = "ci: none" ]
}

@test "checks that register late are waited on" {
  export FAKE_GH_CHECKS_FILE="$BATS_TEST_TMPDIR/checks" KERN_CI_SETTLE=5
  printf '%s\n' '[]' '[{"bucket":"pending","name":"build"}]' '[{"bucket":"pass","name":"build"}]' >"$FAKE_GH_CHECKS_FILE"
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 0 ]
  [ "$output" = "check: build: pass"$'\n'"ci: clear" ]
  [[ "$output" != *"ci: none"* ]] || false
  [ "$(reads)" -eq 3 ]
  # Unset, the settle time is 2 minutes: a first read with no checks does not stand (Review Focus 2).
  unset KERN_CI_SETTLE
  rm -f "$FAKE_GH_CHECKS_FILE.n" "$FAKE_GH_LOG"
  printf '%s\n' '[]' '[{"bucket":"pass","name":"build"}]' >"$FAKE_GH_CHECKS_FILE"
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 0 ]
  [ "$output" = "check: build: pass"$'\n'"ci: clear" ]
  [ "$(reads)" -eq 2 ]
}

@test "pending past the limit times out" {
  export FAKE_GH_CHECKS='[{"bucket":"pass","name":"lint"},{"bucket":"pending","name":"build"}]' KERN_CI_MINUTE=2
  run --separate-stderr bash "$W" "$R" --minutes 1
  [ "$status" -eq 3 ]
  [ "$output" = "check: lint: pass"$'\n'"check: build: pending"$'\n'"ci: pending build (timeout 1m)" ]
  [ "$(reads)" -ge 2 ]
  # gh's exit code 8 for pending checks still carries a read.
  FAKE_GH_RC=8 run --separate-stderr bash "$W" "$R" --minutes 1
  [ "$status" -eq 3 ]
  [ "${lines[2]}" = "ci: pending build (timeout 1m)" ]
  # With no flag ci.wait_minutes sets the limit; the flag wins over it.
  printf 'ci.wait_minutes: 1\n' >"$R/.claude/kern.local.yml"
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 3 ]
  [ "${lines[2]}" = "ci: pending build (timeout 1m)" ]
  printf 'ci.wait_minutes: 900\n' >"$R/.claude/kern.local.yml"
  run --separate-stderr bash "$W" "$R" --minutes 1
  [ "$status" -eq 3 ]
  [ "${lines[2]}" = "ci: pending build (timeout 1m)" ]
}

@test "gh failing is exit 2" {
  # GH_DEBUG goes empty for gh, so its debug log does not come first in the cause.
  export FAKE_GH_RC=1 FAKE_GH_STDERR='HTTP 502: Bad Gateway' GH_DEBUG=api
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"gh pr checks exited 1"*": HTTP 502: Bad Gateway"* ]] || false
  [[ "$stderr" != *"git remote"* ]] || false
  # JSON that is not whole is no read either, whatever gh's exit code.
  unset FAKE_GH_STDERR GH_DEBUG
  export FAKE_GH_RC=0
  for json in '[{"bucket":"pass","name":"bu' '[{"bucket":"pass","name":"build"}] more' '[{"bucket":"pass","name":"build"]}' '[ nope ]'; do
    FAKE_GH_CHECKS=$json run --separate-stderr bash "$W" "$R"
    [ "$status" -eq 2 ] || { echo "status $status for $json"; return 1; }
    [ -z "$output" ]
  done
}

@test "gh's debug log is no array: a red read stays red" {
  # Review fix round 1: with GH_DEBUG on, gh logs `[git remote -v]` on stderr before the JSON, and a reader
  # that took that line for an empty array read a red PR as `ci: none`.
  export FAKE_GH_STDERR='[git remote -v]' FAKE_GH_STDERR_FIRST=1
  export FAKE_GH_CHECKS='[{"bucket":"fail","name":"lint"},{"bucket":"pass","name":"build"}]'
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 1 ]
  [ "$output" = "check: lint: fail"$'\n'"check: build: pass"$'\n'"ci: red lint" ]
  # On stdout too, a bracketed line that is no array start is passed over.
  export FAKE_GH_CHECKS=$'[git remote -v]\n[{"bucket":"fail","name":"lint"}]'
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 1 ]
  [ "${lines[1]}" = "ci: red lint" ]
}

@test "a whole JSON array is the read whatever gh's exit code" {
  # Review fix round 1: gh may exit 1 on a failed check with --json; the array still reads red.
  export FAKE_GH_RC=1 FAKE_GH_CHECKS='[{"bucket":"fail","name":"lint"}]'
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 1 ]
  [ "$output" = "check: lint: fail"$'\n'"ci: red lint" ]
  [ -z "$stderr" ]
}

@test "a bad minutes value is a usage error" {
  export FAKE_GH_CHECKS='[{"bucket":"pass","name":"build"}]'
  run --separate-stderr bash "$W" "$R" --minutes 0
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$W" "$R" --minutes x
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$W" "$R" --minutes 601
  [ "$status" -eq 2 ]
  printf 'ci.wait_minutes: 900\n' >"$R/.claude/kern.local.yml"
  run --separate-stderr bash "$W" "$R"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"ci.wait_minutes"*"900"* ]] || false
  run --separate-stderr bash "$W"
  [ "$status" -eq 2 ]
  # A usage error reads no checks.
  [ "$(reads)" -eq 0 ]
}
