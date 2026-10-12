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
