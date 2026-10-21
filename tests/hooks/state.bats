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

@test "an upper-case or non-ASCII key is refused under a UTF-8 locale too" {
  # bash 3.2 matches a [a-z] range by the locale's collation, where V sorts among the lower-case letters.
  export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  run state_set s1 "Voice=terse"
  [ "$status" -eq 2 ]
  run state_set s1 "VOICE=terse"
  [ "$status" -eq 2 ]
  run state_set s1 "$(printf 'voic\303\251')=terse"
  [ "$status" -eq 2 ]
  run state_file "s$(printf '\303\251')1"
  [ "$status" -eq 2 ]
  run state_set s1 voice=terse
  [ "$status" -eq 0 ]
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

@test "default_voice: a headless session takes mode.voice.headless, normal by default; others take mode.voice" {
  mkdir -p "$R/.claude"
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  for e in sdk-cli sdk-ts sdk-py; do
    [ "$(CLAUDE_CODE_ENTRYPOINT=$e default_voice)" = normal ] || { echo "$e"; return 1; }
  done
  for e in cli claude-desktop claude-vscode ""; do
    [ "$(CLAUDE_CODE_ENTRYPOINT=$e default_voice)" = terse ] || { echo "'$e'"; return 1; }
  done
  printf 'mode.voice: terse\nmode.voice.headless: terse\n' >"$R/.claude/kern.local.yml"
  [ "$(CLAUDE_CODE_ENTRYPOINT=sdk-cli default_voice)" = terse ]
  printf 'mode.voice.headless: loud\n' >"$R/.claude/kern.local.yml"
  [ "$(CLAUDE_CODE_ENTRYPOINT=sdk-cli default_voice)" = normal ]
  export CLAUDE_CODE_ENTRYPOINT=sdk-cli
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  state_reset s1
  [ "$(state_get s1 voice)" = normal ]
}

# A read of the state file that fails, as one does when a fork or exec is refused under load, must never
# reset a state that exists (exec traces of 2026-10-21: autopilot turned off mid-session).
@test "state_ensure writes the default state only when the session has no state file" {
  run state_ensure s1
  [ "$status" -eq 0 ]
  [ "$(state_get s1 autopilot)" = off ]
  [ "$(state_get s1 voice)" = normal ]
  state_set s1 autopilot=on voice=terse
  run state_ensure s1
  [ "$status" -eq 0 ]
  [ "$(state_get s1 autopilot)" = on ]
  [ "$(state_get s1 voice)" = terse ]
  # A file kern did not write whole (no voice line) is still the session's state, and stays.
  printf 'autopilot: on\n' >"$(state_file s1)"
  run state_ensure s1
  [ "$status" -eq 1 ]
  [ "$(sed -n p "$(state_file s1)")" = "autopilot: on" ]
}

@test "state_ensure tries a read that fails once more, and leaves a file it cannot read as it is" {
  state_reset s1
  state_set s1 autopilot=on since=2026-10-12T00:00:00Z
  f=$(state_file s1)
  before=$(sed -n p "$f")
  read_fails awk "$f" 1
  run state_ensure s1
  [ "$status" -eq 0 ]
  [ "$(read_failures awk)" -eq 1 ]
  read_fails awk "$f"
  run state_ensure s1
  [ "$status" -eq 1 ]
  [ "$(read_failures awk)" -eq 3 ]
  [ "$(sed -n p "$f")" = "$before" ]
  run autopilot_on s1
  [ "$status" -ne 0 ]
  read_fails awk "$f" 0
  autopilot_on s1
}

@test "state_ensure leaves a bad id, a symlinked state file and a symlinked state dir alone" {
  run state_ensure "../x"
  [ "$status" -eq 2 ]
  mkdir -p "$(state_dir)" "$BATS_TEST_TMPDIR/elsewhere"
  printf 'autopilot: on\n' >"$BATS_TEST_TMPDIR/target"
  ln -s "$BATS_TEST_TMPDIR/target" "$(state_file s1)"
  run state_ensure s1
  [ "$status" -eq 2 ]
  [ "$(sed -n p "$BATS_TEST_TMPDIR/target")" = "autopilot: on" ]
  rm -rf "$(state_dir)"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$(state_dir)"
  run state_ensure s2
  [ "$status" -eq 2 ]
  [ ! -e "$BATS_TEST_TMPDIR/elsewhere/s2.state" ]
}
