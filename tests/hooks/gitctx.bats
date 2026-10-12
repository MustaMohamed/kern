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

# finds CMD SUB: some simple command that git_words prints for CMD is `git SUB` to git_sub and to cmd_head.
finds() {
  local line t hit=""
  while IFS= read -r line; do
    t=$(git_sub "$line") || continue
    if [ "$(printf '%s\n' "$t" | cut -f2)" = "$2" ] && [ "$(cmd_head "$line")" = "git $2" ]; then hit=1; fi
  done <<EOT
$(git_words "$1")
EOT
  [ -n "$hit" ] || { echo "no git $2 in: $1"; git_words "$1"; return 1; }
}

# finds_gh CMD: some simple command that git_words prints for CMD is `gh pr create` to gh_sub.
finds_gh() {
  local line hit=""
  while IFS= read -r line; do
    if [ "$(gh_sub "$line")" = "pr create" ]; then hit=1; fi
  done <<EOT
$(git_words "$1")
EOT
  [ -n "$hit" ] || { echo "no gh pr create in: $1"; git_words "$1"; return 1; }
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

@test "git and gh are seen behind shells, wrappers, groups and keywords" {
  for c in 'bash -lc "git stash"' 'sh -ec "git stash"' '/bin/bash -c "git stash"' \
    'nohup bash -c "git stash"' 'command git stash' 'exec git stash' 'time git stash' \
    '(git stash)' '{ git stash; }' 'if true; then git stash; fi' '! git stash' \
    'sudo -u me git stash' 'sudo -E git stash'; do
    finds "$c" stash
    finds_gh "${c/git stash/gh pr create}"
  done
  finds 'for b in a; do git push origin $b; done' push
}

@test "a backslash-newline is dropped, not read as a space" {
  finds "git \\
 stash" stash
  run git_words "git sta\\
sh"
  [ "$output" = "git stash" ]
}

@test "quoted parentheses stay inside their word" {
  run git_words 'git commit -m "fix (x)" && (git status)'
  [ "${lines[0]}" = 'git commit -m "fix (x)"' ]
  [ "${lines[1]}" = "git status" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(git_sub "${lines[0]}" | cut -f3)" = "-m fix (x)" ]
}

@test "redirections never split a command" {
  run git_words 'git push origin 2>&1 | tail -3'
  [ "${lines[0]}" = "git push origin 2>&1" ]
  [ "${lines[1]}" = "tail -3" ]
  run git_words 'git push origin &>/dev/null; git fetch >| log'
  [ "${lines[0]}" = "git push origin &>/dev/null" ]
  [ "${lines[1]}" = "git fetch >| log" ]
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

@test "push_targets skips redirections" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  for rest in 'origin 2>&1' 'origin >/dev/null' 'origin > /dev/null' 'origin 2> err.log' \
    'origin &>/dev/null' 'origin </dev/null'; do
    run push_targets "$R" "$rest"
    [ "$output" = main ] || { echo "$rest -> $output"; return 1; }
  done
  run push_targets "$R" "$(git_sub 'git push origin 2>&1' | cut -f3)"
  [ "$output" = main ]
}

@test "push_targets prints * for every-branch pushes, and * is protected" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  for rest in '--all origin' 'origin --mirror' 'origin --branches' \
    'origin refs/heads/*:refs/heads/*' "origin 'feat/*'"; do
    run push_targets "$R" "$rest"
    [ "$output" = '*' ] || { echo "$rest -> $output"; return 1; }
  done
  branch_protected '*'
}

@test "push_targets strips heads/ and reads deletes" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  run push_targets "$R" "origin heads/rel HEAD:heads/x refs/heads/y"
  [ "${lines[0]}" = rel ]
  [ "${lines[1]}" = x ]
  [ "${lines[2]}" = y ]
  for rest in 'origin --delete old' '--delete origin old' 'origin -d old' 'origin :old' \
    'origin :refs/heads/old' 'origin --delete heads/old'; do
    run push_targets "$R" "$rest"
    [ "$output" = old ] || { echo "$rest -> $output"; return 1; }
  done
}

@test "with_timeout returns promptly when the command finishes" {
  start=$(date +%s)
  out=$(with_timeout 10 echo done)
  [ "$out" = done ]
  [ $(($(date +%s) - start)) -lt 3 ]
}

@test "with_timeout stops a slow command and its children" {
  start=$(date +%s)
  rc=0
  out=$(with_timeout 1 sh -c 'echo partial; sleep 6') || rc=$?
  [ "$rc" -ne 0 ]
  [ "$out" = partial ]
  [ $(($(date +%s) - start)) -lt 3 ]
}
