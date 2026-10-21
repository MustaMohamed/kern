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
# reset or shrink a state that exists (exec traces of 2026-10-21: autopilot turned off mid-session).
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

@test "state_set writes nothing when the read of the existing state fails twice" {
  state_reset s1
  state_set s1 autopilot=on since=2026-10-12T00:00:00Z
  f=$(state_file s1)
  before=$(sed -n p "$f")
  # The awk that copies the old lines but those of the keys set into the new file.
  read_fails awk 'keys=*'
  run state_set s1 prompt_hashes=1
  [ "$status" -eq 2 ]
  [ "$(read_failures awk)" -eq 2 ]
  [ "$(sed -n p "$f")" = "$before" ]
  [ -z "$(find "$(state_dir)" -name '.state.*')" ]
  # A read that fails once is tried again, and the write keeps every key.
  read_fails awk 'keys=*' 1
  state_set s1 prompt_hashes=2
  [ "$(state_get s1 prompt_hashes)" = 2 ]
  [ "$(state_get s1 autopilot)" = on ]
  [ "$(state_get s1 since)" = 2026-10-12T00:00:00Z ]
}

@test "state_set exits 2 and leaves no temp file when the rename fails" {
  state_reset s1
  f=$(state_file s1)
  before=$(sed -n p "$f")
  read_fails mv "$f"
  run state_set s1 voice=terse
  [ "$status" -eq 2 ]
  [ "$(sed -n p "$f")" = "$before" ]
  [ -z "$(find "$(state_dir)" -name '.state.*')" ]
}

@test "state_set keeps the last value of a key set twice, after the keys it keeps" {
  state_reset s1
  state_set s1 autopilot=on voice=terse autopilot=off
  [ "$(state_get s1 autopilot)" = off ]
  [ "$(grep -c '^autopilot: ' "$(state_file s1)")" -eq 1 ]
  [ "$(sed -n '$p' "$(state_file s1)")" = "autopilot: off" ]
  [ "$(sed -n 1p "$(state_file s1)")" = "surface: auto" ]
}

# A command substitution whose pipe cannot be made, as when the fd table is full, gives status 0 and no
# output, so no || sees it (review of 2026-10-21). Each substitution in turn is made to fail that way.
ON_STATE='voice: terse
surface: html
autopilot: on
since: 2026-10-12T00:00:00Z'

@test "state_ensure never resets an existing state when a command substitution's pipe fails" {
  local n=1 f
  # The old code, given an empty path, wrote its temp file in the current directory.
  cd "$BATS_TEST_TMPDIR"
  mkdir -p "$(state_dir)"
  f=$(state_file s1)
  while [ "$n" -le 40 ]; do
    printf '%s\n' "$ON_STATE" >"$f"
    (pipe_fails "$n" state_ensure s1) 2>/dev/null || true
    [ -e "$BATS_TEST_TMPDIR/pipe-failed" ] || break
    [ "$(sed -n p "$f")" = "$ON_STATE" ] || { echo "reset when substitution $n failed:"; sed -n p "$f"; return 1; }
    n=$((n + 1))
  done
  [ "$n" -le 40 ]
}

@test "state_set never shrinks the state when a command substitution's pipe fails" {
  local n=1 f got
  # The old code, given an empty path, wrote its temp file in the current directory.
  cd "$BATS_TEST_TMPDIR"
  mkdir -p "$(state_dir)"
  f=$(state_file s1)
  while [ "$n" -le 40 ]; do
    printf '%s\n' "$ON_STATE" >"$f"
    (pipe_fails "$n" state_set s1 prompt_hashes=123) 2>/dev/null || true
    [ -e "$BATS_TEST_TMPDIR/pipe-failed" ] || break
    got=$(grep -v '^prompt_hashes: 123$' "$f" || true)
    [ "$got" = "$ON_STATE" ] || { echo "shrunk when substitution $n failed:"; sed -n p "$f"; return 1; }
    [ -z "$(find "$(state_dir)" -name '.state.*')" ] || { echo "temp file left at $n"; return 1; }
    n=$((n + 1))
  done
  [ "$n" -le 40 ]
}

# A settings layer kern cannot read may hold `autopilot: denied`, so it counts as denying (review of
# 2026-10-21: a failed read of a denying layer let autopilot read on).
@test "a settings layer that cannot be read denies autopilot, whatever it says" {
  state_reset s1
  state_set s1 autopilot=on
  printf 'autopilot: denied\n' >"$HOME/.claude/kern.yml"
  read_fails awk "$HOME/.claude/kern.yml"
  run autopilot_on s1
  [ "$status" -ne 0 ]
  [ "$(autopilot_denied_by 2>/dev/null)" = "$HOME/.claude/kern.yml, which could not be read" ]
  printf 'autopilot: allowed\n' >"$HOME/.claude/kern.yml"
  run autopilot_on s1
  [ "$status" -ne 0 ]
  read_fails awk "$HOME/.claude/kern.yml" 0
  autopilot_on s1
  # A project layer too.
  mkdir -p "$R/.claude"
  printf 'mode.voice: terse\n' >"$R/.claude/kern.yml"
  read_fails awk "$(cd "$R" && pwd -P)/.claude/kern.yml"
  run autopilot_on s1
  [ "$status" -ne 0 ]
}

@test "a denying layer keeps autopilot off when a command substitution's pipe fails" {
  local n=1
  state_reset s1
  state_set s1 autopilot=on
  printf 'autopilot: denied\n' >"$HOME/.claude/kern.yml"
  while [ "$n" -le 40 ]; do
    if (pipe_fails "$n" autopilot_on s1) 2>/dev/null; then
      echo "autopilot read on when substitution $n failed"
      return 1
    fi
    [ -e "$BATS_TEST_TMPDIR/pipe-failed" ] || break
    n=$((n + 1))
  done
  [ "$n" -le 40 ]
}

@test "autopilot stays on when git cannot list the worktrees, and is denied under a broken .git" {
  state_reset s1
  state_set s1 autopilot=on
  autopilot_on s1
  read_fails git worktree
  autopilot_on s1 2>/dev/null
  # A plain directory under a .git file whose gitdir is gone: the project layers are unknown.
  mkdir -p "$BATS_TEST_TMPDIR/plain/sub"
  printf 'gitdir: %s/gone/.git\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/plain/.git"
  export CWD="$BATS_TEST_TMPDIR/plain/sub"
  run autopilot_on s1
  [ "$status" -ne 0 ]
  [[ "$(autopilot_denied_by 2>/dev/null)" == "the project's .claude settings, which kern cannot read: git cannot open this repository"* ]] || false
  # Outside any repository the user's layer alone decides, as before.
  export CWD="$BATS_TEST_TMPDIR/norepo"
  mkdir -p "$CWD"
  autopilot_on s1 2>/dev/null
}

# bash 5.3 (5.3.15 on macOS, measured 2026-10-21) segfaults now and then (about 6% of runs) when a subshell
# undoes a locale change: a `local LC_ALL=C` going out of scope, or the temporary `LC_ALL=C` of a
# command that more commands follow. The old state_file's `local LC_ALL=C`, run inside `$(state_file)`,
# made state_get fail that way, which reset the session state mid-run (Task 16l). The state and settings
# libraries make no such change; `env LC_ALL=C cmd` changes only cmd's environment.
@test "the state and settings libraries make no locale change that bash must undo" {
  run grep -nE 'local[[:space:]]+(LC_[A-Z]+|LANG)=|(^|[;&|({[:space:]])(LC_[A-Z]+|LANG)=[^[:space:]]*[[:space:]]+[a-z]' \
    "$KERN_ROOT/hooks/lib/state.sh" "$KERN_ROOT/hooks/lib/settings.sh"
  # Comment lines aside, `env LC_ALL=C awk` lines match the second form through "env "; only those may.
  [ -z "$(printf '%s\n' "$output" | grep -v ':[0-9]*:[[:space:]]*#' | grep -v 'env LC_ALL=C ')" ] || { echo "$output"; return 1; }
}

@test "state_file and a settings read survive many fresh bash 5.3 runs" {
  local b found=""
  for b in /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash /bin/bash; do
    [ -x "$b" ] || continue
    case "$("$b" -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"')" in 5.[3-9] | [6-9].*) found=$b; break ;; esac
  done
  [ -n "$found" ] || skip "no bash 5.3 or later here"
  # The crash comes only with neither LANG nor LC_ALL set, and LC_CTYPE alone does not stop it, so the
  # caller's locale goes. They are unset here, not with env -u: env's unsetenv changes the environment's
  # layout, and with it the crash rate, down to none in some runs.
  unset LANG LC_ALL LC_CTYPE
  mkdir -p "$R/.claude"
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  cat >"$BATS_TEST_TMPDIR/once.sh" <<'EOS'
. "$KERN_ROOT/hooks/lib/settings.sh"
. "$KERN_ROOT/hooks/lib/state.sh"
f=$(state_file s1) || exit 1
[ "$f" = "$CLAUDE_PLUGIN_DATA/sessions/s1.state" ] || exit 2
_settings_read "$1" kern || exit 3
[ "$_KERN_SV" = off ] || exit 4
EOS
  local i=0 bad=0
  while [ "$i" -lt 300 ]; do
    i=$((i + 1))
    "$found" "$BATS_TEST_TMPDIR/once.sh" "$R/.claude/kern.local.yml" 2>/dev/null || bad=$((bad + 1))
  done
  [ "$bad" -eq 0 ] || { echo "$found failed $bad of 300 runs"; return 1; }
}
