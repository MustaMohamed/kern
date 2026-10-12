#!/usr/bin/env bats
# G1 git safety, interactive and autopilot.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt" >/dev/null 2>&1
  kern_env "$R"
}

g1() { run_guard "$(bash_payload "$1")" g01; }

@test "status in the main checkout: no vote" {
  g1 "git status"
  [ "$(decision_of "$output")" = none ]
}

@test "switch in the main checkout asks, denied under autopilot" {
  g1 "git switch feat"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g1 "git switch feat"
  [ "$(decision_of "$output")" = deny ]
}

@test "reset --hard, stash and clean in the main checkout ask" {
  for c in "git reset --hard HEAD" "git stash" "git clean -fd" "git checkout -b x" "git rebase main"; do
    g1 "$c"
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
}

@test "the same commands in a linked worktree: no vote" {
  for c in "git -C $BATS_TEST_TMPDIR/wt reset --hard HEAD" "git -C $BATS_TEST_TMPDIR/wt stash" "git -C $BATS_TEST_TMPDIR/wt switch -c y"; do
    g1 "$c"
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
}

@test "a chained or substituted main-checkout command is still seen" {
  g1 "cd /tmp && git -C $R stash"
  [ "$(decision_of "$output")" = ask ]
  g1 "echo \$(git -C $R reset --hard)"
  [ "$(decision_of "$output")" = ask ]
  g1 "bash -c 'git -C $R switch feat'"
  [ "$(decision_of "$output")" = ask ]
}

@test "stash list and clean -n are read-only: no vote" {
  g1 "git stash list"
  [ "$(decision_of "$output")" = none ]
  g1 "git clean -n"
  [ "$(decision_of "$output")" = none ]
}

@test "plain force push is denied in both modes" {
  for c in "git push --force origin feat" "git push -f origin feat" "git push origin +feat" "git push -fu origin feat"; do
    g1 "$c"
    [ "$(decision_of "$output")" = deny ] || { echo "$c -> $output"; return 1; }
  done
  set_autopilot on
  g1 "git push --force origin feat"
  [ "$(decision_of "$output")" = deny ]
}

@test "push of a feature branch asks; push.policy auto allows; deny denies" {
  g1 "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  [ "$(decision_of "$output")" = ask ]
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  g1 "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  [ "$(decision_of "$output")" = allow ]
  printf 'push.policy: deny\n' >"$R/.claude/kern.local.yml"
  g1 "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  [ "$(decision_of "$output")" = deny ]
}

@test "push to the base branch asks even with push.policy auto, and is denied under autopilot" {
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  g1 "git push origin main"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g1 "git push origin main"
  [ "$(decision_of "$output")" = deny ]
}

@test "autopilot allows a push of the current non-protected branch only" {
  set_autopilot on
  g1 "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  [ "$(decision_of "$output")" = allow ]
  g1 "git -C $BATS_TEST_TMPDIR/wt push origin other"
  [ "$(decision_of "$output")" = deny ]
}

@test "force-with-lease: own branch asks; a branch with another author is denied" {
  W="$BATS_TEST_TMPDIR/wt"
  printf 'a\n' >"$W/a.txt"; git -C "$W" add a.txt; git -C "$W" commit -q -m a
  g1 "git -C $W push --force-with-lease origin feat"
  [ "$(decision_of "$output")" = ask ]
  printf 'b\n' >"$W/b.txt"; git -C "$W" add b.txt
  git -C "$W" -c user.email=other@example.com commit -q -m b
  g1 "git -C $W push --force-with-lease origin feat"
  [ "$(decision_of "$output")" = deny ]
}

@test "force-with-lease under autopilot needs rebase.push: autopilot" {
  W="$BATS_TEST_TMPDIR/wt"
  printf 'a\n' >"$W/a.txt"; git -C "$W" add a.txt; git -C "$W" commit -q -m a
  set_autopilot on
  g1 "git -C $W push --force-with-lease origin feat"
  [ "$(decision_of "$output")" = deny ]
  mkdir -p "$R/.claude"; printf 'rebase.push: autopilot\n' >"$R/.claude/kern.local.yml"
  g1 "git -C $W push --force-with-lease origin feat"
  [ "$(decision_of "$output")" = allow ]
}

@test "merge asks; gh pr merge asks; both denied under autopilot" {
  g1 "git -C $BATS_TEST_TMPDIR/wt merge main"
  [ "$(decision_of "$output")" = ask ]
  g1 "gh pr merge 12 --squash"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g1 "gh pr merge 12 --squash"
  [ "$(decision_of "$output")" = deny ]
}

@test "worktree remove --force and branch -D ask" {
  g1 "git worktree remove --force $BATS_TEST_TMPDIR/wt"
  [ "$(decision_of "$output")" = ask ]
  g1 "git branch -D feat"
  [ "$(decision_of "$output")" = ask ]
}

@test "kern: off disables the guard" {
  mkdir -p "$R/.claude"; printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  g1 "git push --force origin feat"
  [ "$(decision_of "$output")" = none ]
}

@test "unparseable input asks, and the reason names it" {
  run_guard 'not json' g01
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *"not parseable"* ]] || false
}
