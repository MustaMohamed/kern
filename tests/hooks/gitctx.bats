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

@test "git is seen behind wrapper options, env -S, shell options, timeout and nice" {
  for c in 'exec -a x git push origin main' 'sudo -p x git push' 'sudo -C 3 git push' \
    'env -P /usr/bin git push' 'env -S "git push origin main"' \
    'bash -o pipefail -c "git push origin main"' 'bash -cx "git push"' \
    'timeout 30 git push' 'timeout -s KILL 30 git push' 'timeout --signal KILL 30 git push' \
    'timeout --kill-after 5 30 git push' 'nice -n 5 git push' 'nice -5 git push' \
    '"/bin/bash" -c "git push"' '/usr/bin/env bash -c "git push"'; do
    finds "$c" push
  done
}

@test "a leading redirection is not the command name" {
  for c in '2>/dev/null git push --force' '> /dev/null git push' '2>/dev/null bash -c "git push"'; do
    finds "$c" push
  done
}

@test "a << inside quotes in \$( ) hides nothing" {
  finds 'echo "$(grep -c '"'<<'"' f)"; git push --force' push
  finds "$(printf '%s\n' 'echo "$(echo '"'<<X'"')"' 'git push --force' 'X')" push
}

@test "a shell reading a here-doc runs its body: the body stays as records" {
  finds "$(printf '%s\n' "bash <<'EOF'" 'git push --force origin main' 'EOF')" push
  finds "$(printf '%s\n' 'x=$(sudo -u me sh -s <<EOF' 'git push --force' 'EOF' ')')" push
}

@test "a shell here-doc after a closed \$( ) keeps its body" {
  finds "$(printf '%s\n' "x=\$(date) bash <<'EOF'" 'git push --force' 'EOF')" push
  finds "$(printf '%s\n' "x=\"\$(date)\" bash <<'EOF'" 'git push --force' 'EOF')" push
}

@test "a << inside a top-level (( )) is not a here-doc" {
  finds "$(printf '%s\n' 'y=1; (( y = 1 << X ))' 'git push --force' 'X')" push
}

@test "a # after an escaped separator is not a comment; after a line continuation it is" {
  for c in 'echo a\ #b; git push --force' 'echo a\;#b; git push --force' 'echo a\|#b; git push --force' \
    'echo a\&#b; git push --force' 'echo a\(#b; git push --force' "$(printf 'echo a\\\t#b; git push --force')"; do
    finds "$c" push
  done
  finds "$(printf '%s\n' 'echo a \' "#it's" 'git push --force')" push
  run git_words 'echo a\\ #b; git push --force'
  [ "$output" = 'echo a\\ #b; git push --force' ]
}

@test "a here-string is not a here-doc" {
  run git_words "$(printf '%s\n' 'cat <<< EOF' 'git push --force' 'EOF')"
  [ "${lines[0]}" = "cat <<< EOF" ]
  [ "${lines[1]}" = "git push --force" ]
  [ "${lines[2]}" = EOF ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "the commit form with a here-doc message gives one git segment, and the message is data" {
  # printf, not a here-doc inside $( ): bash 3.2 misparses the apostrophe there.
  cmd=$(printf '%s\n' 'git commit -m "$(cat <<'"'EOF'" 'docs: x (git push --force is blocked)' \
    'echo on > /x/sessions/a.state; git reset --hard' "it's (unbalanced" 'EOF' ')"')
  run git_words "$cmd"
  [ "$(git_sub "${lines[0]}" | cut -f2)" = commit ]
  [ "${lines[1]}" = "cat <<'EOF'" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "here-doc bodies are skipped, and the commands after them are still seen" {
  run git_words "$(printf '%s\n' 'cat > /tmp/f <<-EOF' '	git push --force' '	EOF' 'git status')"
  [ "${lines[0]}" = "cat > /tmp/f <<-EOF" ]
  [ "${lines[1]}" = "git status" ]
  [ "${#lines[@]}" -eq 2 ]
  finds "$(printf '%s\n' 'x=$(cat <<"A" <<B' 'a )' 'A' 'b (' 'B' 'git push --force)')" push
  finds "$(printf '%s\n' 'cat <<EOF' 'no end' 'git push')" push
}

@test "a quoted multi-line argument stays in its record" {
  run git_words "$(printf '%s\n' 'git commit -m "a' 'git push --force"' 'git status')"
  [ "${#lines[@]}" -eq 2 ]
  [ "$(git_sub "${lines[0]}" | cut -f2)" = commit ]
  [ "${lines[1]}" = "git status" ]
  finds "$(printf '%s\n' "bash -c 'git status" "git push --force'")" push
}

@test "a 1,000-line here-doc runs through git_words in under a second" {
  local TIMEFORMAT=%R t
  body=$(awk 'BEGIN { for (i = 1; i <= 1000; i++) printf "line %d: echo x > /tmp/y; (git push --force)\n", i }')
  cmd="git commit -m \"\$(cat <<'EOF'
$body
EOF
)\""
  t=$( { time git_words "$cmd" >"$BATS_TEST_TMPDIR/out" 2>/dev/null || true; } 2>&1)
  awk -v t="$t" 'BEGIN { exit !(t < 1) }' || { echo "took $t s"; return 1; }
  [ "$(wc -l <"$BATS_TEST_TMPDIR/out")" -eq 2 ]
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

@test "current_branch reads HEAD by symbolic-ref, past a tag of the same name" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" tag main
  run current_branch "$R"
  [ "$status" -eq 0 ]
  [ "$output" = main ]
  git -C "$R" switch -q --detach
  run current_branch "$R"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
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

# words_are STR WORD...: _shell_words prints exactly the WORDs for STR.
words_are() {
  local str="$1"
  shift
  run _shell_words "$str"
  [ "$output" = "$(printf '%s\n' "$@")" ] || { echo "$str -> $output"; return 1; }
}

@test "_shell_words: a word that starts with an unquoted # is a comment to the newline" {
  words_are 'git status # note' git status
  words_are 'git clean -fd # -n' git clean -fd
  words_are "$(printf 'a # b\nc')" a c
  run _cmd_words 'git status # note'
  [ "$output" = "$(printf 'git\nstatus')" ]
}

@test "_shell_words: a # inside a word, quoted or escaped is kept" {
  words_are 'echo a#b' echo 'a#b'
  words_are 'echo ${#x}' echo '${#x}'
  words_are 'echo $#' echo '$#'
  words_are "echo '#x'" echo '#x'
  words_are 'echo "#x"' echo '#x'
  words_are 'echo \#x' echo '#x'
  words_are 'git log --format=%h#%s' git log '--format=%h#%s'
}

@test "_shell_words splits a redirection from the word before it" {
  [ "$(_shell_words 'a main>/dev/null 2>&1 b&>c d<<EOF e2>f' | paste -sd ' ' -)" = \
    "a main >/dev/null 2>&1 b &>c d <<EOF e2 >f" ]
}

@test "push_targets: a redirection glued to the branch, and @" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  for rest in 'origin main>/dev/null' 'origin main&>/dev/null' 'origin @'; do
    run push_targets "$R" "$rest"
    [ "$output" = main ] || { echo "$rest -> $output"; return 1; }
  done
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

@test "git is seen behind wrapper long options that take a value" {
  for c in 'env --chdir sub git push origin main' 'env --unset X git push' \
    'env --split-string "git push origin main"' 'sudo --user root git push' \
    'sudo --chdir /tmp git push' 'nice --adjustment 5 git push'; do
    finds "$c" push
  done
}

@test "git is seen after an append assignment, an attached env -S line, and a wrapper or shell in another case" {
  for c in 'X+=1 git push' 'GIT_DIR+=/x/.git git push' 'env --split-string="git push origin main"' \
    "env -S'git push origin main'" 'ENV git push' 'Env --chdir=sub git push' 'SUDO -u me git push' \
    '/usr/bin/NoHup git push' 'TIMEOUT 5 git push' 'sudo --chroot /x git push' \
    'BASH -c "git push"' 'ENV bash -c "git push"' 'Sh -c "git push"' 'env -iS "git push origin main"' \
    "env -0vS'git push origin main'" 'env -uS git push'; do
    finds "$c" push
  done
  finds "$(printf '%s\n' "BASH <<'EOF'" 'git push --force origin main' 'EOF')" push
}
