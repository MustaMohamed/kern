# tests/helpers/wt.bash
# Fixture repos for the worktree and check-script tests. Each test gets its own HOME,
# so no user setting or global git config leaks in.
KERN_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)

wt_test_env() {
  TMP=$(cd "$BATS_TEST_TMPDIR" && pwd -P)
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_NOSYSTEM=1
  export CLAUDE_PLUGIN_DATA="$TMP/plugin-data"
}

# make_fixture DIR: a repo on main with one commit, a bare origin at DIR.origin,
# main pushed and refs/remotes/origin/HEAD set. .gitignore ignores node_modules/ and *.log.
make_fixture() {
  local dir=$1
  git init --quiet --bare --initial-branch=main "$dir.origin"
  git init --quiet --initial-branch=main "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name Test
  git -C "$dir" config commit.gpgsign false
  printf 'node_modules/\n*.log\n' > "$dir/.gitignore"
  printf 'one\ntwo\nthree\n' > "$dir/a.txt"
  git -C "$dir" add .gitignore a.txt
  git -C "$dir" commit --quiet -m init
  git -C "$dir" remote add origin "$dir.origin"
  git -C "$dir" push --quiet origin main
  git -C "$dir" remote set-head origin main
}
