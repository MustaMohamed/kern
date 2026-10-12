#!/usr/bin/env bats
# hooks/lib/gitctx.sh: command splitting and git parsing that every guard relies on.

load ../helpers/common

setup() {
  export KERN_ROOT
  KERN_ROOT="$(kern_root)"
  for lib in settings gitctx; do
    # shellcheck source=/dev/null
    . "$KERN_ROOT/hooks/lib/$lib.sh"
  done
  export CWD=/tmp
}

@test "git_words splits chains and keeps quoted separators" {
  run git_words 'cd x && git push origin main; echo "a;b" | grep q || git status'
  [ "${lines[0]}" = "cd x" ]
  [ "${lines[1]}" = "git push origin main" ]
  [ "${lines[2]}" = 'echo "a;b"' ]
  [ "${lines[3]}" = "grep q" ]
  [ "${lines[4]}" = "git status" ]
}

@test "git_words also prints the bodies of bash -c, eval, \$( ) and backticks" {
  run git_words "bash -c 'git stash && git switch main'"
  [[ "$output" == *$'\n'"git stash"$'\n'"git switch main"* ]] || false
  run git_words 'echo $(git push -f) && x=`git reset --hard`'
  [[ "$output" == *$'\n'"git push -f"* ]] || false
  [[ "$output" == *$'\n'"git reset --hard"* ]] || false
}

@test "git_sub reads -C, skips env and global options" {
  run git_sub 'FOO=1 git -C /repo -c a=b --no-pager push -u origin "my branch"'
  [ "$output" = "/repo	push	-u origin my branch" ]
  run git_sub "ls -la"
  [ "$status" -eq 1 ]
}

@test "gh_sub, word_value and word_has" {
  [ "$(gh_sub 'GH_TOKEN=x gh pr create --draft')" = "pr create" ]
  w=$(_shell_words "gh pr create --head feat --title 'a b'")
  [ "$(word_value "$w" --head -H)" = feat ]
  [ "$(word_value "$w" --title)" = "a b" ]
  word_has "$w" --title
  run word_has "$w" --draft
  [ "$status" -eq 1 ]
}

@test "push_targets: refspecs, deletes and the current branch" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c feat
  run push_targets "$R" "origin +HEAD:refs/heads/rel :old"
  [ "${lines[0]}" = rel ]
  [ "${lines[1]}" = old ]
  run push_targets "$R" "-u origin"
  [ "$output" = feat ]
}

@test "with_timeout returns promptly when the command finishes" {
  start=$(date +%s)
  out=$(with_timeout 10 echo done)
  [ "$out" = done ]
  [ $(($(date +%s) - start)) -lt 3 ]
}
