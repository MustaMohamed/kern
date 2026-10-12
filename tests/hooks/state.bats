#!/usr/bin/env bats
# hooks/lib/state.sh: atomic writes, permissions, ids, symlinks, autopilot.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  export KERN_ROOT
  KERN_ROOT="$(kern_root)"
  for lib in settings state; do
    # shellcheck source=/dev/null
    . "$KERN_ROOT/hooks/lib/$lib.sh"
  done
}

@test "state_reset writes defaults with mode 0600" {
  state_reset s1
  [ "$(state_get s1 voice)" = normal ]
  [ "$(state_get s1 surface)" = auto ]
  [ "$(state_get s1 autopilot)" = off ]
  [ "$(ls -l "$(state_file s1)" | cut -c1-10)" = "-rw-------" ]
}

@test "state_reset takes mode.voice and mode.surface from settings and rejects junk" {
  mkdir -p "$R/.claude"
  printf 'mode.voice: terse\nmode.surface: banana\n' >"$R/.claude/kern.local.yml"
  state_reset s1
  [ "$(state_get s1 voice)" = terse ]
  [ "$(state_get s1 surface)" = auto ]
}

@test "state_set updates one key and keeps the others" {
  state_reset s1
  state_set s1 voice=terse
  [ "$(state_get s1 voice)" = terse ]
  [ "$(state_get s1 surface)" = auto ]
  [ "$(grep -c '^voice: ' "$(state_file s1)")" -eq 1 ]
}

@test "bad session ids, bad keys, newlines and symlinks are refused" {
  run state_file "../x"
  [ "$status" -eq 2 ]
  run state_set s1 "Voice=terse"
  [ "$status" -eq 2 ]
  run state_set s1 "voice=a
autopilot: on"
  [ "$status" -eq 2 ]
  mkdir -p "$(state_dir)"
  ln -s /etc/hosts "$(state_dir)/s2.state"
  run state_set s2 voice=terse
  [ "$status" -eq 2 ]
}

@test "autopilot_on needs the state and no denied setting" {
  state_reset s1
  run autopilot_on s1
  [ "$status" -eq 1 ]
  state_set s1 autopilot=on
  autopilot_on s1
  printf 'autopilot: denied\n' >"$HOME/.claude/kern.yml"
  run autopilot_on s1
  [ "$status" -eq 1 ]
}

@test "autopilot_on is off when any layer denies, even under a higher allowed layer" {
  state_reset s1
  state_set s1 autopilot=on
  mkdir -p "$R/.claude"
  printf 'autopilot: allowed\n' >"$R/.claude/kern.local.yml"
  printf 'autopilot: denied\n' >"$HOME/.claude/kern.yml"
  run autopilot_on s1
  [ "$status" -ne 0 ]
}

@test "a symlinked sessions dir is refused on read" {
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  printf 'autopilot: on\n' >"$BATS_TEST_TMPDIR/elsewhere/s1.state"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$(state_dir)"
  run state_get s1 autopilot
  [ "$status" -eq 2 ]
  run autopilot_on s1
  [ "$status" -ne 0 ]
}

@test "state_reset discards a garbled old file under a UTF-8 locale" {
  mkdir -p "$(state_dir)"
  printf 'voice: normal\n\377\377\nautopilot: on\n' >"$(state_file s1)"
  export LANG=en_US.UTF-8 LC_ALL=
  run state_reset s1
  [ "$status" -eq 0 ]
  run autopilot_on s1
  [ "$status" -ne 0 ]
  [ "$(state_get s1 autopilot)" = off ]
}

@test "session ids are ASCII-only whatever the locale" {
  export LANG=en_US.UTF-8 LC_ALL=
  run state_file "é"
  [ "$status" -eq 2 ]
}

@test "autopilot_denied_by names the denying layer, even under a higher allowed layer" {
  mkdir -p "$R/.claude"
  printf 'autopilot: allowed\n' >"$R/.claude/kern.yml"
  printf 'autopilot: denied\n' >"$HOME/.claude/kern.yml"
  run autopilot_denied_by
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.claude/kern.yml" ]
}

@test "autopilot_denied_by exits 1 when no layer denies" {
  mkdir -p "$R/.claude"
  printf 'autopilot: allowed\n' >"$R/.claude/kern.yml"
  run autopilot_denied_by
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
