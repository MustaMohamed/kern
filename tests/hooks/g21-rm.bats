#!/usr/bin/env bats
# G21 local deletes: a target inside this worktree or a scratch directory gets no vote; any other, or one
# kern cannot resolve, asks, and autopilot turns the ask into a denial.

load ../helpers/common

setup() {
  # /var/tmp is on no scratch list, on macOS or on Linux, so a path beside the repo is outside. TMPDIR sits
  # there too: on Linux bats' own directory is under /tmp, where a TMPDIR is only a child of the /tmp root.
  BASE=$(cd "$(mktemp -d /var/tmp/kern-g21.XXXXXX)" && pwd -P)
  R="$BASE/repo"
  make_repo "$R"
  kern_env "$R"
  export TMPDIR="$BASE/scratch"
  mkdir -p "$TMPDIR" "$R/src" "$BASE/other"
}

teardown() { rm -rf "$BASE" "${ROOT-}"; }

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

@test "the reason after a cd says to open the call with it" {
  expect ask 'cd .. && rm a'
  [[ "$output" == *'open the call with cd <absolute worktree path> &&'* ]] || false
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

@test "a worktree nested in the main checkout owns its paths, as at the default worktree.dir" {
  W="$R/.claude/worktrees/plan"
  mkdir -p "$R/.claude/worktrees"
  git -C "$R" worktree add -q "$W" -b kern/plan
  git -C "$R" worktree add -q "$R/.claude/worktrees/two" -b kern/two
  mkdir -p "$W/src"
  export CWD="$W"
  expect none 'rm src/gen.ts' "rm $W/src/gen.ts" 'rm -rf build'
  set_autopilot on
  expect none 'rm src/gen.ts'
  set_autopilot off
  refused "rm $R/README.md" "rm $R/.claude/worktrees/two/a" 'rm ../two/a' 'rm -rf .git' "rm -rf $W"
}

@test "a link or a move in the same command leaves every target to its own call" {
  refused 'ln -s ../../other src/l; rm src/l/a' 'ln -s ../other src/l && rm -rf src/l/' \
    'mv ../other src/o && rm -rf src/o' 'rm src/o/a; mv ../other src/o' 'gln -s ../other src/l; rm src/l/a'
  expect ask 'ln -s ../other src/l; rm src/l/a'
  [[ "$output" == *'run the link or move as its own call'* ]] || false
}

@test "cd is read as the shell runs it, not as the text reads" {
  refused 'for i in 1 2; do rm a; cd ..; done' 'f() { rm a; }; cd ..; f' "trap 'rm a' EXIT; cd .." \
    'CDPATH=.. cd other && rm a' 'chdir .. && rm a'
  ln -s "$R/src" "$BASE/other/l"
  refused 'cd ../other/l/.. && rm a' 'cd +1 && rm a'
  mkdir -p "$R/src/lib"
  ln -s "$R/src/lib" "$BASE/other/m"
  export CWD="$R/src"
  refused 'cd ../../other/m; cd ..; rm a'
  export CWD="$R/src/lib"
  refused 'for i in 1 2 3 4; do cd ..; done; rm a' 'f() { cd ..; }; f; f; f; f; rm a'
  export CWD="$R"
  export CDPATH=..
  refused 'cd src && rm a'
}

@test "a find cannot be reworded past G21" {
  refused 'printf ../other | xargs -I X find X -delete' 'printf ../other | xargs -J % find % -delete' \
    'parallel -I X find X -delete ::: ../other' "ssh host 'find build -delete'" 'printf x | xargs find' \
    'find ../other $x' 'find ../other "$x"' 'find ../other -$x' 'find ../other $(printf %s -delete)' \
    "find ../other -\$'delete'" "find ../other -dele\$'te'" 'find $x' 'find "$@"' 'find . -name $x' \
    'find . -name "$@"'
  expect none 'find "$d" -name x' 'find . -name "$x"' 'find ../other -name x' 'find ../other -type f'
}

@test "a find with a built word gets its own reason, and the same vote" {
  refused 'find . -name $x'
  set_autopilot off
  expect ask 'find ../other $x'
  [[ "$output" == *'kern G21: find with a word built at run time, which may be any primary, so kern cannot tell it from a delete; write the word literally'* ]] || false
  [[ "$output" != *'delete outside this worktree'* ]] || false
}

@test "the worktree top and WORK/tmp cannot be planted" {
  git -C "$R" config core.worktree "$BASE"
  refused 'rm src/a' 'rm ../other/a'
  git -C "$R" config --unset core.worktree
  git -C "$R" worktree add -q "$BASE/wt" -b feat
  export CWD="$BASE/wt"
  mkdir -p "$R/.kern"
  ln -s "$BASE/other" "$R/.kern/tmp"
  refused "rm $R/.kern/tmp/a"
  rm "$R/.kern/tmp"
  rmdir "$R/.kern"
  ln -s "$BASE/other" "$R/.kern"
  mkdir -p "$BASE/other/tmp"
  refused "rm $R/.kern/tmp/a"
}

@test "a worktree spelled in another case is still that worktree" {
  git -C "$R" worktree add -q "$R/src/wt" -b feat
  refused 'rm -rf src/WT' 'rm -rf SRC/wt' 'rm SRC/WT/a'
  git -C "$R" worktree add -q "$TMPDIR/wts" -b feat2
  refused 'rm -rf "$TMPDIR/WTS"'
}

@test "the read list holds no word that runs a command" {
  refused 'rg --pre rm x ../other' 'rg --pre=rm x ../other' "man -P 'rm ../other/a' ls" \
    "man --pager='rm ../other/a' ls" "man -H'rm ../other/a' ls" "git grep -Orm x" \
    "git grep --open-files-in-pager=rm x"
  expect none 'git grep rm ../other' 'git log --grep rm -- ../other'
}

@test "TMPDIR set by a built name counts as set" {
  refused 'x=TMP; export "${x}DIR=/etc"; rm "$TMPDIR/x"' 'export $(printf TMP)DIR=/etc; rm "$TMPDIR/x"' \
    'read -r "$(echo TMP)DIR" <<< /etc; rm "$TMPDIR/x"'
}

@test "a command in one word, a directory option and the GNU names reach G21" {
  refused "sudo -s 'rm ../other/a'" "flock /tmp/l -c 'rm ../other/a'" "tmux new -d 'rm ../other/a'" \
    "nix-shell --run 'rm ../other/a'" "nix-shell --run='rm ../other/a'" "flock /tmp/l -c 'true; rm ../other/a'" \
    'git --work-tree=../other rm a' 'git --git-dir=../other/.git rm a' 'GIT_WORK_TREE=../other git rm a' \
    'export GIT_WORK_TREE=../other; git rm a' 'unshare --wd=../other rm a' 'setsid --wd ../other rm a' \
    'nsenter --wd=../other rm a' 'grm ../other/a' 'grmdir ../other' 'gunlink ../a' 'gshred ../other/a' \
    'gfind ../other -delete'
  expect none "git commit -m 'rm ../x'" "gh pr create --draft --title 'rm ../x'"
}

@test "a zsh qualifier or group and a dot glob are unresolved" {
  refused 'rm -rf src/lib(:a:h:h:h)' 'rm -rf (src/lib)(:a:h:h)' 'rm -rf (../other)' 'find src/.* -delete' \
    'rm -rf src/.?' 'rm -rf src/..*' "zsh -c 'rm -rf src/lib(:a:h:h:h)'" "eval 'rm -rf (src/lib)(:a:h:h)'" \
    "tmux new -d 'rm -rf src/lib(:a:h:h:h)'" 'echo "$(rm -rf src/lib(:a:h:h:h))"'
  expect none 'rm "a(b)"' 'rm "src/(group)/a"' '(cd src && rm a)' 'f() { rm a; }; f' 'x=(1 2); rm a' \
    'rm a # see (b)' "git commit -m 'rm (old) files'" "bash -c 'rm \"a(b)\"'" "grep -n 'rm (' src/a"
}

@test "under a go the worktree is the go's repository" {
  other="$BASE/repo2"
  make_repo "$other"
  mkdir -p "$other/src"
  set_autopilot on
  printf 'go: MA-254\ngo_repo: %s\n' "$(go_key "$R")" >>"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  expect none 'rm -rf src'
  export CWD="$other"
  expect deny 'rm -rf src'
}

@test "the reason names the route" {
  expect ask 'rm ../other/a'
  [[ "$output" == *'name each target as a literal path inside the worktree, not its top, or in a scratch directory'* ]] || false
  expect ask 'rm "$tmp"'
  [[ "$output" == *'run mktemp as its own call'* ]] || false
}

@test "a scratch path beside the main checkout is outside, unless that directory is the scratch root" {
  N="$TMPDIR/evals/repo"
  make_repo "$N"
  mkdir -p "$TMPDIR/evals/other"
  export CWD="$N"
  refused 'rm ../other/a' 'rm -rf ../other'
  expect none 'rm /tmp/kern-x' 'rm "$TMPDIR/x"'
  N="$TMPDIR/repo"
  make_repo "$N"
  export CWD="$N"
  expect none 'rm "$TMPDIR/x"'
  # A scratch root that lies under another one is still a root.
  ROOT=$(mktemp -d /tmp/kern-g21.XXXXXX)
  export TMPDIR="$ROOT"
  N="$ROOT/repo"
  make_repo "$N"
  export CWD="$N"
  expect none 'rm "$TMPDIR/x"'
}

@test "a worktree inside WORK/tmp stays outside" {
  git -C "$R" worktree add -q "$BASE/wt" -b feat
  mkdir -p "$R/.kern/tmp"
  git -C "$R" worktree add -q "$R/.kern/tmp/fork" -b fork
  export CWD="$BASE/wt"
  refused "rm -rf $R/.kern/tmp/fork" "rm $R/.kern/tmp/fork/a"
  expect none "rm $R/.kern/tmp/x"
}

@test "a glob directly at a scratch root asks" {
  refused 'rm -rf /tmp/*' 'rm -rf /private/tmp/*' 'rm -rf "$TMPDIR"/*'
  git -C "$R" worktree add -q "$BASE/wt" -b feat
  export CWD="$BASE/wt"
  refused "rm -rf $R/.kern/tmp/*"
  expect none 'rm -rf /tmp/kern-x/*'
}

# go_key DIR: what prompt-submit records as go_repo for a main checkout at DIR.
go_key() { printf '%s' "$1" | git -C "$R" hash-object --stdin; }

# open_setup: a session at the main checkout, under autopilot, with a linked worktree W at the default
# worktree.dir beside a sibling S.
open_setup() {
  W="$R/.claude/worktrees/plan"
  S="$R/.claude/worktrees/two"
  mkdir -p "$R/.claude/worktrees"
  git -C "$R" worktree add -q "$W" -b kern/plan
  git -C "$R" worktree add -q "$S" -b kern/two
  mkdir -p "$W/src" "$W/build"
  set_autopilot on
}

@test "a call that opens with cd into a linked worktree reads that directory as its cwd" {
  open_setup
  expect none "cd $W && rm src/gen.ts" "cd $W && rm -rf build" "cd $W && git rm src/gen.ts" \
    "cd \"$W\" && rm src/gen.ts" "cd '$W' && rm src/gen.ts" "cd $W/src && rm gen.ts" \
    "cd $W && for i in 1 2; do rm src/gen.ts; done"
}

@test "after an opening cd every other path votes as in that worktree" {
  open_setup
  expect deny "cd $W && rm $R/README.md" "cd $W && rm $S/a" "cd $W && rm -rf $W" "cd $W && rm -rf .git"
}

@test "only a plain opening cd to a literal absolute path in a linked worktree counts" {
  open_setup
  mkdir -p "$W/\$x"
  make_repo "$BASE/elsewhere"
  expect deny "cd $W; rm src/gen.ts" "cd $W || rm src/gen.ts" 'cd .claude/worktrees/plan && rm src/gen.ts' \
    "cd ${W#/} && rm $W/src/gen.ts" 'cd $W && rm src/gen.ts' "cd $W/\$x && rm $W/src/gen.ts" \
    "cd $W/../plan && rm src/gen.ts" "cd $W/../plan && rm $W/src/gen.ts" "cd $BASE/other && rm src/gen.ts" \
    "cd $BASE/elsewhere && rm a" "cd $R && rm $W/src/gen.ts"
  # The main checkout is no match from a worktree either: the relative reading stays.
  export CWD="$W"
  expect deny "cd $R && rm src/gen.ts"
}

@test "the reason names the opening cd for a target in a listed worktree" {
  open_setup
  local route='open the call with cd <absolute worktree path> &&'
  expect deny "rm $W/src/gen.ts"
  [[ "$output" == *"$route"* ]] || false
  expect deny "git -C $W rm src/gen.ts"
  [[ "$output" == *"$route"* ]] || false
  expect deny 'rm .claude/worktrees/plan/src/gen.ts'
  [[ "$output" == *"$route"* ]] || false
  expect deny 'rm ../other/a'
  [[ "$output" != *"$route"* ]] || false
  [[ "$output" != *'as its own call'* ]] || false
  # A session in a worktree gets no route: not to the main checkout, and not to a sibling.
  export CWD="$W"
  expect deny "rm $R/README.md"
  [[ "$output" != *"$route"* ]] || false
  expect deny "rm $S/a"
  [[ "$output" != *"$route"* ]] || false
  expect deny 'cd .. && rm a'
  [[ "$output" != *"$route"* ]] || false
}

@test "a lone & leaves an opening cd to the union reading, a redirection does not" {
  open_setup
  expect deny "cd $W && rm src/gen.ts & rm README.md"
  expect none "cd $W && rm src/gen.ts 2>&1" "cd $W && rm src/gen.ts &>/dev/null"
}

@test "a quoted & is no lone &" {
  open_setup
  expect none "cd $W && rm \"a&b\""
}

@test "a quoted name after a redirect keeps the lone & after it" {
  open_setup
  expect deny "cd $W && rm src/gen.ts 2>\"f\"& rm README.md"
}

@test "an empty quoted pair between two & is no &&" {
  open_setup
  expect deny "cd $W && rm src/gen.ts &\"\"& rm README.md"
}

@test "|& is a pipe, not a lone &" {
  open_setup
  expect none "cd $W && rm x |& cat"
}

@test "<& is no lone &" {
  open_setup
  expect none "cd $W && rm x <&0"
}

@test "a piped delete is judged" {
  refused 'printf x | xargs rm'
}

@test "an opening cd into a worktree nested in a worktree" {
  open_setup
  I="$W/inner"
  git -C "$R" worktree add -q "$I" -b kern/inner
  expect none "cd $I && rm src/gen.ts"
  expect deny "cd $W && rm -rf inner" "cd $W && rm inner/a"
}

@test "the worktrees come from the payload's cwd, past a repository inside the worktree" {
  open_setup
  make_repo "$W/sub"
  git -C "$R" worktree add -q "$W/sub/inner" -b kern/inner
  expect deny "cd $W/sub && rm -rf inner"
}

@test "a nested repository's linked worktree is protected" {
  open_setup
  N="$W/nested"
  make_repo "$N"
  git -C "$N" worktree add -q "$N/lt" -b lt
  refused "cd $N && rm -rf lt" "cd $N && rm -rf $N/lt"
}

@test "an opening cd under a go is that repository's or names no top" {
  open_setup
  printf 'go: MA-254\ngo_repo: %s\n' "$(go_key "$R")" >>"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  expect none "cd $W && rm src/gen.ts"
  set_autopilot on
  printf 'go: MA-254\ngo_repo: %s\n' "$(go_key "$BASE/other")" >>"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  expect deny "cd $W && rm src/gen.ts"
}

@test "an opening cd reads core.worktree where it lands" {
  open_setup
  git -C "$R" config extensions.worktreeConfig true
  git -C "$W" config --worktree core.worktree "$BASE"
  expect deny "cd $W && rm $BASE/other/a"
}

@test "G21 reads only Bash" {
  run_guard "$(tool_payload Write '"file_path":"../rm","content":"x"')" g21
  [ "$(decision_of "$output")" = none ]
}
