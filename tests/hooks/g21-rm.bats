#!/usr/bin/env bats
# G21 local deletes: a target inside this worktree or a scratch directory gets no vote; any other, or one
# kern cannot resolve, asks, and autopilot turns the ask into a denial.

load ../helpers/common

setup() {
  # /var/tmp is on no scratch list, on macOS or on Linux, so a path beside the repo is outside.
  BASE=$(cd "$(mktemp -d /var/tmp/kern-g21.XXXXXX)" && pwd -P)
  R="$BASE/repo"
  make_repo "$R"
  kern_env "$R"
  export TMPDIR="$BATS_TEST_TMPDIR/scratch"
  mkdir -p "$TMPDIR" "$R/src" "$BASE/other"
}

teardown() { rm -rf "$BASE"; }

# expect WANT CMD...: G21 alone decides WANT on each CMD, which may hold double quotes and backslashes.
expect() {
  local want="$1" c esc
  shift
  for c in "$@"; do
    esc=$(printf '%s' "$c" | sed 's/\\/\\\\/g; s/"/\\"/g')
    run_guard "$(bash_payload "$esc")" g21
    [ "$(decision_of "$output")" = "$want" ] || { printf 'want %s for: %s\ngot: %s\n' "$want" "$c" "$output"; return 1; }
  done
}

# refused CMD...: each CMD asks, and autopilot denies it.
refused() {
  set_autopilot off
  expect ask "$@"
  set_autopilot on
  expect deny "$@"
  set_autopilot off
}

@test "g21 rows: a target inside the worktree or a scratch directory gets no vote" {
  expect none 'rm src/a.ts' 'rm -rf build' 'rm "$TMPDIR/x"'
}

@test "g21 rows: any other target asks, and autopilot denies it" {
  refused 'rm ../other/a' 'rm ~/a' 'rm .git/config' 'rm "$x"' 'unlink ../a' 'find ../other -delete' \
    'printf a | xargs rm'
}

@test "G21 names the target in its reason" {
  expect ask 'rm -f src/a ../other/a'
  [[ "$output" == *'"needs user approval: kern G21: '*'../other/a'* ]] || false
}

@test "G21 judges rm, rmdir, unlink, shred and find -delete, and no other command" {
  expect none 'rmdir build' 'unlink src/a' 'shred -u src/a' 'find build -name x -delete' 'ls ../other' \
    'cat ../other/a' 'mv ../other/a src/'
  refused 'rmdir ../other' 'shred -u ../other/a'
}

@test "any word may name the tool, in any case and by any path" {
  refused 'sudo rm ../other/a' '/bin/rm ../other/a' 'RM ../other/a' 'nice -n 5 rm ../other/a' \
    'caffeinate rm ../other/a' "bash -c 'rm ../other/a'" "caffeinate sh -c 'rm ../other/a'" \
    'if true; then rm ../other/a; fi' 'watch rm ../other/a'
  expect none 'sudo rm src/a' '/bin/rm src/a' 'git rm src/a'
}

@test "find -exec and xargs hide nothing" {
  refused 'find ../other -exec rm {} +' 'find ../other -name x -exec rm {} \;' 'find . -type f | xargs rm -f' \
    'xargs rm src/a' 'xargs -I{} rm {}' 'find -L build -delete' "find build -exec sh -c 'rm \"\$1\"' _ {} \\;"
  expect none 'find build -name x -exec rm {} +'
}

@test "a command that only reads may name rm" {
  expect none 'grep -rn rm ../other' 'echo rm ../other/a' 'which rm' 'ls | grep rm'
}

@test "a remote delete cannot be resolved" {
  refused "ssh host 'rm a'"
}

@test "redirections and options are not targets" {
  expect none 'rm -f src/a 2>/dev/null' 'rm -f src/a > /dev/null' 'rm -rf -- build' 'rm src/a 2>"$HOME/log"'
  refused 'rm -- ../other/a' 'rm -f ../other/a 2>/dev/null'
}

@test "the worktree itself, and .git in any case, are outside" {
  refused 'rm -rf .' "rm -rf $R" 'rm -rf .git' 'rm -rf .GIT' 'rm -rf src/../.git' 'find . -delete' 'rm -rf src/..'
  git -C "$R" init -q src/sub
  refused 'rm -rf src/sub/.git/config'
}

@test "a link that points out of the worktree is outside" {
  ln -s "$BASE/other" "$R/out"
  ln -s ../out "$R/src/hop"
  refused 'rm out' 'rm out/a' 'rm src/hop/a' 'rm -rf out/'
  ln -s src "$R/in"
  expect none 'rm in/a'
}

@test "a target that does not exist yet resolves through the part that does" {
  expect none 'rm build/deep/a' 'rm src/none/../a'
  refused 'rm src/none/../../../other/a'
}

@test "a linked worktree: its top is the worktree, the main checkout and any other worktree are outside" {
  git -C "$R" worktree add -q "$BASE/wt" -b feat
  git -C "$R" worktree add -q "$BASE/wt2" -b feat2
  export CWD="$BASE/wt"
  expect none 'rm src/a' 'rm -rf build'
  refused "rm $R/README.md" "rm $BASE/wt2/README.md" 'rm ../wt2/README.md'
}

@test "a linked worktree inside this one's tree is outside, and so is a directory that holds it" {
  git -C "$R" worktree add -q "$R/src/wt" -b feat
  refused 'rm src/wt/README.md' 'rm -rf src/wt' 'rm -rf src' 'rm -rf src/*'
}

@test "a worktree in a scratch directory keeps its .git, and other worktrees stay outside" {
  W="$TMPDIR/wt"
  git -C "$R" worktree add -q "$W" -b feat
  W=$(cd "$W" && pwd -P)
  export CWD="$W"
  expect none 'rm src/a'
  refused 'rm -rf .git' "rm -rf $W" "rm -rf $R"
  export CWD="$R"
  refused "rm -rf $W"
}

@test "scratch directories: TMPDIR, /tmp, /private/tmp and WORK/tmp; never the directory itself" {
  expect none 'rm -rf /tmp/kern-x' 'rm -rf /private/tmp/kern-x' 'rm "${TMPDIR}/x"' "rm -rf $TMPDIR/x" 'rm .kern/tmp/x'
  refused 'rm -rf /tmp' 'rm -rf /private/tmp/' 'rm -rf "$TMPDIR"' 'rm -rf /tmp/../etc/x'
  git -C "$R" worktree add -q "$BASE/wt" -b feat
  export CWD="$BASE/wt"
  expect none "rm $R/.kern/tmp/x"
  refused "rm $R/.kern/x"
}

@test "work_dir names WORK/tmp, and a work_dir outside the repo names none" {
  mkdir -p "$R/.claude"
  git -C "$R" worktree add -q "$BASE/wt" -b feat
  export CWD="$BASE/wt"
  printf 'work_dir: scratchpad\n' >"$R/.claude/kern.local.yml"
  expect none "rm $R/scratchpad/tmp/x"
  refused "rm $R/.kern/tmp/x"
  printf 'work_dir: ../other\n' >"$R/.claude/kern.local.yml"
  refused "rm $BASE/other/tmp/x"
}

@test "TMPDIR counts only as the hook sees it" {
  refused 'TMPDIR=/etc; rm "$TMPDIR/x"' 'export TMPDIR=/etc; rm "$TMPDIR/x"'
  unset TMPDIR
  refused 'rm "$TMPDIR/x"'
  export TMPDIR=/
  refused 'rm "$TMPDIR/etc/x"' 'rm /etc/x'
}

@test "a variable, a brace list or a command substitution cannot be resolved" {
  refused 'rm "$HOME/a"' 'rm ${x}/a' 'rm $(cat list)' 'rm `cat list`' 'rm {a,b}' 'rm =ls' 'for f in a b; do rm "$f"; done'
}

@test "a glob resolves in its last part only, and not where it may match .git" {
  expect none 'rm build/*.o' 'rm -rf src/*' 'rm src/a?.ts' 'rm *.log'
  refused 'rm *' 'rm -rf .*' 'rm -rf ./*' 'rm .g*' 'rm build/*/x' 'rm -rf build/*/' 'rm ../other/*' 'rm src/[ab]'
}

@test "a cd moves the targets after it, read from every directory it may start from" {
  mkdir -p "$R/src/lib"
  expect none 'cd src && rm a' 'cd src; cd lib && rm a' 'cd /tmp && rm "$TMPDIR/x"'
  refused 'cd .. && rm a' "cd $BASE/other && rm a" 'cd src && rm ../../a' 'cd "$x" && rm a' 'cd - && rm a' \
    'cd && rm a' 'pushd src && rm a' 'popd; rm a' 'builtin cd .. && rm a' '(cd ..; rm a)'
  expect none 'cd "$x" && rm /tmp/kern-x'
}

@test "the reason after a cd says to run the cd alone" {
  expect ask 'cd .. && rm a'
  [[ "$output" == *'run cd <wt> as its own call'* ]] || false
}

@test "a directory option before the tool leaves a relative target unresolved" {
  refused 'env -C ../other rm a' 'sudo -D ../other rm a' 'git -C ../other rm a' 'env --chdir=../other rm a'
  expect none 'env -C ../other rm /tmp/kern-x' 'rm -Rf build'
}

@test "outside a git repository only scratch directories pass" {
  export CWD="$BASE/other"
  expect none 'rm /tmp/kern-x'
  refused 'rm a'
}

@test "every guard together gives the same answers" {
  run_guard "$(bash_payload 'rm -rf build')"
  [ "$(decision_of "$output")" = none ]
  run_guard "$(bash_payload 'rm ../other/a')"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'kern G21: '* ]] || false
  set_autopilot on
  run_guard "$(bash_payload 'rm ../other/a')"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'(autopilot: nobody to ask)'* ]] || false
}

@test "a command G21 cannot read asks" {
  read_fails awk '*G21T*'
  expect ask 'rm src/a'
  [[ "$output" == *'could not read the command'* ]] || false
}

@test "G21 reads only Bash" {
  run_guard "$(tool_payload Write '"file_path":"../rm","content":"x"')" g21
  [ "$(decision_of "$output")" = none ]
}
