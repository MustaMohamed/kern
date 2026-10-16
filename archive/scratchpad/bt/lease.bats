#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  mkdir -p "$R/.claude/worktrees"
  git -C "$R" worktree add -q -b kern/plan "$R/.claude/worktrees/plan"
  W="$R/.claude/worktrees/plan"
  echo x > "$W/f.txt"; git -C "$W" add f.txt; git -C "$W" commit -qm "M2: f"
  git -C "$W" push -q -u origin kern/plan
  # base moves; rebase the published branch
  echo y > "$R/g.txt"; git -C "$R" add g.txt; git -C "$R" commit -qm base2; git -C "$R" push -q origin main
  git -C "$W" fetch -q origin main
  git -C "$W" rebase -q origin/main
  kern_env "$W"
  fake_gh
}

show() {
  run_guard "$(bash_payload "$1")"
  printf '%-5s | %s | %s\n' "$(decision_of "$output")" "$1" "$(printf '%s' "$output" | sed -n 's/.*Reason":"\([^"]*\)".*/\1/p' | cut -c1-90)" >&3
}

@test "lease push after own rebase" {
  run git -C "$W" push origin kern/plan
  printf 'plain push after rebase: rc=%s %s\n' "$status" "$(printf '%s' "$output" | grep -m1 rejected)" >&3
  show "git push --force-with-lease origin kern/plan"
  set_autopilot on
  show "git push --force-with-lease origin kern/plan"
  set_autopilot off
  git -C "$W" -c user.email=other@x commit -q --allow-empty -m other
  git -C "$W" push -q --force-with-lease origin kern/plan
  git -C "$W" fetch -q origin
  show "git push --force-with-lease origin kern/plan"
  show "git push --force origin kern/plan"
}
