#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  mkdir -p "$R/.claude/worktrees"
  git -C "$R" worktree add -q -b kern/plan "$R/.claude/worktrees/plan"
  W="$R/.claude/worktrees/plan"
  echo x > "$W/f.txt"; git -C "$W" add f.txt; git -C "$W" commit -qm "M2: f"
  kern_env "$W"
  fake_gh
  mkdir -p "$R/.kern/tmp"; printf 'Body\n' >"$R/.kern/tmp/pr-body.md"
}

show() {
  run_guard "$(bash_payload "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')")"
  printf '%-5s | %s\n' "$(decision_of "$output")" "$1" >&3
}

@test "flow from a linked worktree" {
  show "cd $W"
  show "git push -u origin kern/plan"
  show "gh pr create --draft --title 'M2: f' --base main --body-file $R/.kern/tmp/pr-body.md"
  show "git rebase origin/main"
  show "git switch -c kern/x"
  show "git worktree remove $W"
  show "git branch -D kern/plan"
  printf 'push.policy: deny\npr.policy: deny\n' > "$R/.claude/kern.local.yml"
  show "git push -u origin kern/plan"
  show "gh pr create --draft --title 'M2: f' --base main --body-file $R/.kern/tmp/pr-body.md"
  rm "$R/.claude/kern.local.yml"
  set_autopilot on
  show "git push -u origin kern/plan"
  show "gh pr create --draft --title 'M2: f' --base main --body-file $R/.kern/tmp/pr-body.md"
  show "gh pr ready 1"
  show "git branch -D kern/plan"
  export FAKE_GH_STATES=MERGED
  show "gh pr create --draft --title 'M2: f' --base main --body-file $R/.kern/tmp/pr-body.md"
  export FAKE_GH_STATES= FAKE_GH_RC=4
  show "gh pr create --draft --title 'M2: f' --base main --body-file $R/.kern/tmp/pr-body.md"
}
