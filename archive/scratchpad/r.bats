load /Users/musta/Code/projects/kern/tests/helpers/common
@test x { R="$BATS_TEST_TMPDIR/repo"; make_repo "$R"; R=$(cd "$R" && pwd -P); W="$R/.claude/worktrees/fx"; git -C "$R" worktree add -q -b feat/x "$W" main; kern_env "$W"; set_autopilot on
 run_guard "$(bash_payload "git push --force-with-lease origin feat/x")"; echo "$output" >&3; }
