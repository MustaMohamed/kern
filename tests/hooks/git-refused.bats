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
