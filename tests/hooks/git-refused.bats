#!/usr/bin/env bats
# Repositories git refuses to open (dubious ownership, a stale or empty .git, git unable to run): kern
# finds the project settings from the .git itself, honours the user's own file, and never denies a call
# that is not a git call only because it cannot read a project file (Task 16l, fix round 2).

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  git -C "$R" switch -q -c feat/x
  printf 'y\n' >"$R/f.txt"
  git -C "$R" add f.txt
  printf 'feat: x\n' >"$R/msg.txt"
  mkdir -p "$R/.claude"
  printf 'mode.voice: terse\n' >"$R/.claude/kern.yml"
  K="$(kern_root)"
  # No system file may trust the repository; git 2.35.2 and later then refuse it as owned by another user.
  export GIT_CONFIG_NOSYSTEM=1
}

# refuse: git refuses every repository from here on, as for one owned by another user.
refuse() {
  export GIT_TEST_ASSUME_DIFFERENT_OWNER=1
  run git -C "$R" status
  [ "$status" -ne 0 ]
}

# decide CWD CMD: sets d to the PreToolUse decision on a Bash CMD run in CWD; the output stays in $output.
decide() {
  run bash "$K/hooks/pre-tool-use" <<<"$(printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" "$2")"
  d=$(decision_of "$output")
}

# stale DIR: a plain directory DIR whose .git file names a gitdir that is gone.
stale() {
  mkdir -p "$1/sub"
  printf 'gitdir: %s/gone/.git/worktrees/x\n' "$BATS_TEST_TMPDIR" >"$1/.git"
}

@test "a repository git refuses still reads its project settings, found from its .git directory" {
  printf 'commit.policy: deny\n' >"$R/.claude/kern.local.yml"
  refuse
  export KERN_ROOT="$K"
  . "$K/hooks/lib/settings.sh"
  rc=0
  got=$(settings_get commit.policy ask) || rc=$?
  [ "$rc" -eq 0 ]
  [ "$got" = deny ]
  [ "$(settings_get mode.voice normal)" = terse ]
}

@test "a linked worktree git refuses reads the main repository's settings through its .git file" {
  git -C "$R" worktree add -q -b feat/wt "$BATS_TEST_TMPDIR/wt" main
  printf 'commit.policy: deny\n' >"$R/.claude/kern.local.yml"
  refuse
  export KERN_ROOT="$K" CWD="$BATS_TEST_TMPDIR/wt"
  . "$K/hooks/lib/settings.sh"
  rc=0
  got=$(settings_get commit.policy ask) || rc=$?
  [ "$rc" -eq 0 ]
  [ "$got" = deny ]
}

@test "plain ls, grep and curl get no vote in a repository git refuses" {
  refuse
  for c in "ls ~/.ssh" "grep -rn sqlite src" "curl -s https://example.com"; do
    for ap in off on; do
      set_autopilot "$ap"
      decide "$R" "$c"
      [ "$d" = none ] || { echo "autopilot $ap: $c -> $output"; return 1; }
    done
  done
}

@test "the user's kern: off holds in a repository git refuses" {
  printf 'kern: off\n' >"$HOME/.claude/kern.yml"
  refuse
  set_autopilot off
  decide "$R" "git commit -F msg.txt"
  [ "$d" = none ] || { echo "$output"; return 1; }
  decide "$R" "curl -s https://example.com"
  [ "$d" = none ] || { echo "$output"; return 1; }
}

@test "autopilot turns on in a repository git refuses" {
  refuse
  set_autopilot off
  run bash "$K/hooks/prompt-submit" <<<"$(payload UserPromptExpansion '"expansion_type":"slash_command","command_name":"kern:autopilot","command_args":"on","command_source":"plugin","prompt":"/kern:autopilot on"')"
  [ "$(sed -n 's/^autopilot: //p' "$CLAUDE_PLUGIN_DATA/sessions/test-session.state")" = on ] || { echo "$output"; return 1; }
}

@test "under a stale .git file, a plain curl or ls is never denied, and the user's kern: off holds" {
  stale "$BATS_TEST_TMPDIR/plain"
  P="$BATS_TEST_TMPDIR/plain/sub"
  set_autopilot off
  for c in "curl -s https://example.com" "ls ~/.ssh" "grep -rn sqlite src"; do
    decide "$P" "$c"
    [ "$d" != deny ] || { echo "$c -> $output"; return 1; }
  done
  printf 'kern: off\n' >"$HOME/.claude/kern.yml"
  decide "$P" "curl -s https://example.com"
  [ "$d" = none ] || { echo "$output"; return 1; }
}

# A kern.local.yml loosens only while it is the user's own untracked file, which only git can prove.
# In a repository git refuses, a committed one (a clone's) must not turn kern off; nor may an untracked
# one whose status git cannot tell (re-review 2 of 2026-10-21).
protect() {
  printf 'protected_targets: prod.example.com\n' >"$HOME/.claude/kern.yml"
}

@test "a committed kern.local.yml never turns kern off in a repository git refuses" {
  protect
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  git -C "$R" add -f .claude/kern.local.yml
  git -C "$R" commit -q -m "chore: local settings"
  set_autopilot off
  decide "$R" "ssh prod.example.com"
  [ "$d" = deny ] || { echo "git works: $output"; return 1; }
  refuse
  decide "$R" "ssh prod.example.com"
  [ "$d" = deny ] || { echo "$output"; return 1; }
  decide "$R" "git commit -m 'feat: x'"
  [ "$d" != none ] || { echo "commit: $output"; return 1; }
  decide "$R" "git push origin feat/x"
  [ "$d" != none ] || { echo "push: $output"; return 1; }
}

@test "an untracked kern.local.yml whose status git cannot tell loosens nothing" {
  protect
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  set_autopilot off
  # git works: the user's own untracked file turns kern off.
  decide "$R" "ssh prod.example.com"
  [ "$d" = none ] || { echo "git works: $output"; return 1; }
  refuse
  decide "$R" "ssh prod.example.com"
  [ "$d" = deny ] || { echo "$output"; return 1; }
}

@test "with git unable to run, a kern.local.yml loosens nothing" {
  protect
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  git -C "$R" add -f .claude/kern.local.yml
  git -C "$R" commit -q -m "chore: local settings"
  mkdir -p "$BATS_TEST_TMPDIR/nogit"
  printf '#!/bin/sh\necho "xcrun: error: invalid active developer path" >&2\nexit 1\n' >"$BATS_TEST_TMPDIR/nogit/git"
  chmod +x "$BATS_TEST_TMPDIR/nogit/git"
  set_autopilot off
  PATH="$BATS_TEST_TMPDIR/nogit:$PATH" decide "$R" "ssh prod.example.com"
  [ "$d" = deny ] || { echo "$output"; return 1; }
  PATH="$BATS_TEST_TMPDIR/nogit:$PATH" decide "$R" "git push origin feat/x"
  [ "$d" != none ] || { echo "push: $output"; return 1; }
}

@test "under a stale .git file, a kern.local.yml is not read and kern stays on" {
  protect
  stale "$BATS_TEST_TMPDIR/plain"
  mkdir -p "$BATS_TEST_TMPDIR/plain/.claude"
  printf 'kern: off\n' >"$BATS_TEST_TMPDIR/plain/.claude/kern.local.yml"
  set_autopilot off
  decide "$BATS_TEST_TMPDIR/plain/sub" "ssh prod.example.com"
  [ "$d" = deny ] || { echo "$output"; return 1; }
}

@test "a loosening kern.local.yml git cannot vouch for is named as the cause" {
  printf 'commit.policy: auto\n' >"$R/.claude/kern.local.yml"
  set_autopilot off
  refuse
  decide "$R" "git commit -m 'feat: x'"
  [ "$d" = ask ] || { echo "$output"; return 1; }
  [[ "$output" == *"commit.policy unknown: git cannot tell whether "*"kern.local.yml is your own untracked file (run \`git status\` to see why)"* ]] || false
}

# Making a file another user owns needs root, so this test's copy of _settings_local_ok reads the user's own
# file as another user's: its ownership check is turned around.
@test "a kern.local.yml another user owns loosens nothing and is named as the cause" {
  printf 'commit.policy: auto\nkern: off\n' >"$R/.claude/kern.local.yml"
  export KERN_ROOT="$K"
  . "$K/hooks/lib/settings.sh"
  [ "$(settings_get commit.policy ask)" = auto ]
  eval "$(declare -f _settings_local_ok | sed 's/\[ -O /[ ! -O /')"
  declare -f _settings_local_ok | grep -q '\[ ! -O ' || { echo "no ownership check to turn around"; return 1; }
  rc=0
  got=$(settings_get commit.policy ask) || rc=$?
  [ "$rc" -eq 4 ] && [ "$got" = unknown ] || { echo "exit $rc: $got"; return 1; }
  [ "$(settings_get kern on)" = on ]
  why=$(settings_unread_why commit.policy)
  [[ "$why" == *"/.claude/kern.local.yml is owned by another user, so kern does not take it as your own file" ]] || false
}

@test "a git that exits 1 cannot vouch for a kern.local.yml and is named as the cause" {
  printf 'commit.policy: auto\n' >"$R/.claude/kern.local.yml"
  mkdir -p "$BATS_TEST_TMPDIR/nogit"
  printf '#!/bin/sh\necho "xcrun: error: invalid active developer path" >&2\nexit 1\n' >"$BATS_TEST_TMPDIR/nogit/git"
  chmod +x "$BATS_TEST_TMPDIR/nogit/git"
  export KERN_ROOT="$K"
  . "$K/hooks/lib/settings.sh"
  [ "$(settings_get commit.policy ask)" = auto ]
  PATH="$BATS_TEST_TMPDIR/nogit:$PATH"
  rc=0
  got=$(settings_get commit.policy ask) || rc=$?
  [ "$rc" -eq 4 ] && [ "$got" = unknown ] || { echo "exit $rc: $got"; return 1; }
  why=$(settings_unread_why commit.policy)
  [[ "$why" == "git cannot tell whether "*"/.claude/kern.local.yml is your own untracked file (run \`git status\` to see why)" ]] || false
}
