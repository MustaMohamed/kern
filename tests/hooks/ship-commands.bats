#!/usr/bin/env bats
# The exact commands commit and finish-branch prescribe, run through kern's guards under autopilot from
# a linked worktree, with a gh stub. A skill command a guard would deny cannot run unattended.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  R=$(cd "$R" && pwd -P)
  W="$R/.claude/worktrees/fx"
  git -C "$R" worktree add -q -b feat/x "$W" main
  kern_env "$W"
  set_autopilot on
  mkdir -p "$R/.kern/tmp" "$R/.git/info"
  printf '/.kern/\n/.claude/worktrees/\n' >>"$R/.git/info/exclude"
  printf 'feat: add x\n\nWhy it matters.\n' >"$R/.kern/tmp/commit-msg"
  printf '## Why\n\nx\n' >"$R/.kern/tmp/pr-body.md"
  printf 'x\n' >"$W/x.txt"
  git -C "$W" add x.txt
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat >"$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/gh.log"
case "$1 $2" in "pr list") [ -n "${GH_STATES-}" ] && printf '%s\n' "$GH_STATES" ;; esac
exit 0
GH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

decide() {
  run_guard "$(bash_payload "$1")"
  if [ "$status" -ne 0 ]; then
    echo "crash:$status"
    return 0
  fi
  decision_of "$output"
}

@test "commit: git -C <wt> commit -F with the message file under the main worktree's .kern/tmp is allowed" {
  [ "$(decide "git -C $W commit -F $R/.kern/tmp/commit-msg")" = allow ]
}

@test "commit: a plain git commit -F from inside the worktree is allowed too" {
  [ "$(decide "git commit -F $R/.kern/tmp/commit-msg")" = allow ]
}

@test "commit: a message file outside the main worktree is denied, with and without -C" {
  printf 'feat: add x\n' >"$BATS_TEST_TMPDIR/msg"
  [ "$(decide "git -C $W commit -F $BATS_TEST_TMPDIR/msg")" = deny ]
  [ "$(decide "git commit -F $BATS_TEST_TMPDIR/msg")" = deny ]
}

@test "commit: git -C <wt> add -- <files> gets no kern vote" {
  [ "$(decide "git -C $W add -- x.txt")" = none ]
}

@test "finish-branch: the draft PR command with a single-quoted --title and a body file under .kern/tmp is allowed" {
  [ "$(decide "gh pr create --draft --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md")" = allow ]
}

@test "finish-branch: an open PR for the branch denies a second one" {
  GH_STATES=OPEN
  export GH_STATES
  [ "$(decide "gh pr create --draft --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md")" = deny ]
}

@test "finish-branch: gh pr ready and a non-draft PR are denied" {
  [ "$(decide "gh pr ready 12")" = deny ]
  [ "$(decide "gh pr create --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md")" = deny ]
}

@test "finish-branch: the push of the current branch is allowed; a cd in the same call is not" {
  [ "$(decide "git push -u origin feat/x")" = allow ]
  [ "$(decide "cd $W && gh pr create --draft --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md")" = deny ]
}

@test "finish-branch: under autopilot the lease push is denied, which backs 'autopilot never rebases'" {
  [ "$(decide "git push --force-with-lease origin feat/x")" = deny ]
}
