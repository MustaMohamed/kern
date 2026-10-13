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

# expect DECISION CMD...: G1 gives DECISION for every CMD.
expect() {
  local want="$1" c
  shift
  for c in "$@"; do
    g1 "$c"
    [ "$(decision_of "$output")" = "$want" ] || { echo "$c -> $output"; return 1; }
  done
}

# settings LINE...: the project's local kern settings, one LINE per key.
settings() {
  mkdir -p "$R/.claude"
  printf '%s\n' "$@" >"$R/.claude/kern.local.yml"
}

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

@test "autopilot denies main-checkout operations, merges and discards" {
  set_autopilot on
  expect deny "git reset --hard HEAD" "git stash" "git clean -fd" "git pull" \
    "git -C $BATS_TEST_TMPDIR/wt merge main" "git branch -D feat" \
    "git worktree remove --force $BATS_TEST_TMPDIR/wt" "gh pr merge 12 --squash"
}

@test "pull in the main checkout asks; in a linked worktree: no vote" {
  expect ask "git pull" "git pull --rebase origin main"
  expect none "git -C $BATS_TEST_TMPDIR/wt pull"
}

@test "abbreviated long options and short clusters are read as git reads them" {
  expect ask "git reset --har HEAD" "git branch -d -f feat" "git branch -df feat" \
    "git branch --force -d feat" "git branch -qD feat" \
    "git worktree remove --for $BATS_TEST_TMPDIR/wt"
  expect none "git clean -fdn" "git clean --dry -fd" "git branch -d feat" "git reset --soft HEAD"
  expect deny "git push --mirr origin"
  set_autopilot on
  expect deny "git -C $BATS_TEST_TMPDIR/wt push --force-w origin feat"
}

@test "a remote delete asks whatever push.policy says, and is denied under autopilot" {
  W="$BATS_TEST_TMPDIR/wt"
  settings 'push.policy: auto'
  set -- "git -C $W push origin :feat" "git -C $W push -d origin feat" \
    "git -C $W push -du origin feat" "git -C $W push --del origin feat" \
    "git -C $W push --delete origin feat"
  expect ask "$@"
  set_autopilot on
  expect deny "$@"
}

@test "push.policy deny denies under autopilot too" {
  settings 'push.policy: deny'
  set_autopilot on
  expect deny "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
}

@test "autopilot allows a push only in the plain shape" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  expect allow "git -C $W push -u origin feat" "git -C $W push origin HEAD" \
    "git -C $W push -q origin feat:feat" "git -C $W push origin feat >/dev/null 2>&1"
  expect deny \
    "git -C $W push -u origin feat && rm -rf /tmp/nothing-here" \
    "git -C $W push -u origin feat # \$(true)" \
    "git -C $W push -u origin feat >$BATS_TEST_TMPDIR/out" \
    "env GIT_TRACE=1 git -C $W push origin feat" \
    "git -C $W -c remote.origin.push=+refs/heads/feat:refs/heads/main push origin" \
    "git -C $W -c push.default=upstream push" \
    "git -C $W push" \
    "git -C $W push origin" \
    "git -C $W push --receive-pack=evil origin feat" \
    "git -C $W push --exec=evil origin feat" \
    "git -C $W push --repo=origin origin feat" \
    "git -C $W push $R.origin feat" \
    "git -C $W push https://example.invalid/x.git feat" \
    "git -C $W push --tags" \
    "git -C $W push origin --tags" \
    "git -C $W push --follow-tags origin feat" \
    "git -C $W push --tag origin feat" \
    "git -C $W push origin feat:other" \
    "git -C $W push origin HEAD~1:feat"
}

@test "push.policy auto allows only the plain shape" {
  W="$BATS_TEST_TMPDIR/wt"
  settings 'push.policy: auto'
  expect allow "git -C $W push -u origin feat"
  expect ask "git -C $W push -u origin feat && rm -rf /tmp/nothing-here" \
    "git -C $W push origin feat:other" "git -C $W push --tags"
}

@test "remote.<name>.push or mirror config makes a push unproven" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  git -C "$W" config remote.origin.push refs/heads/feat:refs/heads/main
  expect deny "git -C $W push origin feat"
  git -C "$W" config --unset remote.origin.push
  git -C "$W" config remote.origin.mirror true
  expect deny "git -C $W push origin feat"
}

@test "autopilot lease: current branch only, bare option, no other flags" {
  W="$BATS_TEST_TMPDIR/wt"
  git -C "$R" branch other2
  settings 'rebase.push: autopilot'
  set_autopilot on
  expect allow "git -C $W push --force-with-lease origin feat" \
    "git -C $W push --force-with-lease --force-if-includes origin feat"
  expect deny "git -C $W push --force-with-lease origin other2" \
    "git -C $W push --force-with-lease origin HEAD:someone-else" \
    "git -C $W push --force-with-lease=feat:0123456 origin feat" \
    "git -C $W push --force-with-lease -o ci.skip origin feat"
}

@test "--force-if-includes follows the lease rules" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  expect deny "git -C $W push --force-if-includes origin feat"
  settings 'rebase.push: autopilot'
  expect allow "git -C $W push --force-if-includes origin feat"
}

@test "lease: another author's commit on the remote branch only is denied" {
  W="$BATS_TEST_TMPDIR/wt"
  O="$BATS_TEST_TMPDIR/o2"
  git -C "$W" push -q origin feat
  git clone -q "$R.origin" "$O"
  git -C "$O" switch -q feat
  printf 'x\n' >"$O/x.txt"; git -C "$O" add x.txt
  git -C "$O" -c user.email=other@example.com -c user.name=other commit -q -m x
  git -C "$O" push -q origin feat
  git -C "$W" fetch -q origin
  printf 'b\n' >"$W/b.txt"; git -C "$W" add b.txt; git -C "$W" commit -q -m b
  expect deny "git -C $W push --force-with-lease origin feat" "git -C $W push --force-if-includes origin feat"
  settings 'rebase.push: autopilot'
  set_autopilot on
  expect deny "git -C $W push --force-with-lease origin feat" \
    "git -C $W push --force-with-lease --force-if-includes origin feat"
}

@test "lease to a remote that git remote does not list is denied" {
  expect deny "git -C $BATS_TEST_TMPDIR/wt push --force-with-lease $R.origin feat"
}

@test "after cd, --git-dir or GIT_DIR the directory is unknown" {
  export CWD="$BATS_TEST_TMPDIR/wt"
  expect ask "cd $R && git reset --hard HEAD" "cd $R && git stash" "pushd $R && git switch main" \
    "GIT_DIR=$R/.git git reset --hard" "git --git-dir $R/.git --work-tree $R reset --hard" \
    "git --git-dir=$R/.git stash" "cd $R && git push origin"
  set_autopilot on
  expect deny "cd $R && git push origin feat" "cd $R && git stash" \
    "git --git-dir=$R/.git push origin feat"
}

@test "gh pr merge with -R or --repo asks, and is denied under autopilot" {
  expect ask "gh -R o/r pr merge 12 --squash" "gh pr merge --repo o/r 12" "gh --repo=o/r pr merge 12"
  set_autopilot on
  expect deny "gh -R o/r pr merge 12 --squash"
}

@test "--no-verify skips the pre-push hook, so the push is never allowed" {
  W="$BATS_TEST_TMPDIR/wt"
  settings 'push.policy: auto'
  expect ask "git -C $W push --no-verify origin feat" "git -C $W push -u --no-verify origin feat"
  set_autopilot on
  expect deny "git -C $W push --no-verify origin feat" "git -C $W push -u --no-verify origin feat"
}

@test "an allowed push may pipe into tail, head, grep or cat with options only" {
  W="$BATS_TEST_TMPDIR/wt"
  P="git -C $W push -u origin feat"
  set_autopilot on
  expect allow "$P 2>&1 | tail -5" "$P | tail -n 5" "$P 2>&1 | head -n 20" "$P | head -3" \
    "$P 2>&1 | grep -i error" "$P 2>&1 | grep -e rejected -e error" "$P | cat -n" \
    "$P 2>&1 | grep -v hint | tail -n 5" "$P 2>&1 | tail -5 >/dev/null"
  expect deny "$P | tail -5 /etc/passwd" "$P | cat $HOME/.ssh/id_rsa" "$P | grep -r error" \
    "$P | grep error notes.txt" "$P | grep -e error notes.txt" "$P | grep -f patterns" \
    "$P | tail -5 >$BATS_TEST_TMPDIR/out" "$P | tee $BATS_TEST_TMPDIR/out" "$P | sh" \
    "$P | xargs echo" "$P | env tail -5" "$P | tail -- -5" "tail -5 /etc/hosts; $P" \
    "$P | bash -c 'tail -5'"
  settings 'push.policy: auto'
  set_autopilot off
  expect allow "$P 2>&1 | tail -5"
  expect ask "$P | tee $BATS_TEST_TMPDIR/out"
}

@test "--dry-run is a safe push option" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  expect allow "git -C $W push -n origin feat" "git -C $W push --dry-run -u origin feat"
}

@test "an unknown push shape names the fix in its reason" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  g1 "git -C $W push"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"name the remote and branch: git push -u origin feat"* ]] || false
  g1 "git -C $W push origin feat:other"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'kern allows only `git push [-u] <remote> <current-branch>` unattended'* ]] || false
  set_autopilot off
  settings 'push.policy: auto'
  g1 "git -C $W push"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *"name the remote and branch: git push -u origin feat"* ]] || false
  g1 "git -C $W push origin feat:other"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'kern allows only `git push [-u] <remote> <current-branch>` unattended'* ]] || false
}

@test "a tag named like the current branch does not hide it" {
  git -C "$R" tag main
  set_autopilot on
  expect deny "git -C $R push origin HEAD" "git -C $R push -u origin @" "git push origin HEAD"
  settings 'rebase.push: autopilot'
  expect deny "git -C $R push --force-with-lease origin HEAD"
  set_autopilot off
  settings 'push.policy: auto'
  expect ask "git -C $R push origin HEAD"
}

@test "a tag named like a branch.protected branch does not hide it" {
  W="$BATS_TEST_TMPDIR/wt"
  settings 'branch.protected: feat'
  set_autopilot on
  expect deny "git -C $W push origin HEAD"
  git -C "$R" tag feat
  expect deny "git -C $W push origin HEAD" "git -C $W push -u origin @"
}

@test "shell expansion in a push record is never allowed" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  git -C "$W" switch -q -c 'main$X'
  expect deny "git -C $W push origin main\$X"
  git -C "$W" switch -q -c '{x,main}'
  expect deny "git -C $W push origin {x,main}"
  git -C "$W" switch -q -c '$main'
  expect deny "git -C $W push origin \$'main'"
  # Branch g passes the name check, so only the record check refuses the $ in the -C dir.
  git -C "$R" worktree add -q -b g "$BATS_TEST_TMPDIR/w\$X" >/dev/null 2>&1
  expect deny "git -C $BATS_TEST_TMPDIR/w\$X push origin g"
}

@test "a branch or remote name outside the safe characters is never allowed" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  expect allow "git -C $W push origin feat"
  git -C "$W" switch -q -c 'fe!at'
  expect deny "git -C $W push origin fe!at"
  git -C "$W" switch -q feat
  git -C "$R" remote add 'o!x' "$R.origin"
  expect deny "git -C $W push o!x feat"
}

@test "a glob or ~ in a push record is never allowed" {
  T="$BATS_TEST_TMPDIR"
  git clone -q "$R.origin" "$T/x1"
  git -C "$T/x1" switch -q -c feat2
  git -C "$T/x1" config remote.origin.pushurl "$T/elsewhere.git"
  git clone -q "$R.origin" "$T/x[1]"
  git -C "$T/x[1]" switch -q -c feat2
  git -C "$R" worktree add -q -b t2 "$R/~" >/dev/null 2>&1
  set_autopilot on
  expect deny "git -C $T/x[1] push origin feat2" "git -C ~ push origin t2"
}

@test "shell expansion or a glob in a filter is never allowed" {
  P="git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  set_autopilot on
  expect deny "$P | grep -e *" "$P | grep {x,-r}" "$P | grep \$X" "$P | head -n ?" "$P | grep -e [a]"
}

@test "remote and url config that redirects a push makes it unproven" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  expect allow "git -C $W push origin feat"
  git -C "$W" config remote.origin.receivepack git-receive-pack
  expect deny "git -C $W push origin feat"
  git -C "$W" config --unset remote.origin.receivepack
  git -C "$W" config remote.origin.vcs evil
  expect deny "git -C $W push origin feat"
  git -C "$W" config --unset remote.origin.vcs
  git -C "$W" config remote.origin.pushurl "$BATS_TEST_TMPDIR/elsewhere"
  expect deny "git -C $W push origin feat"
  git -C "$W" config --unset remote.origin.pushurl
  git -C "$W" config "url.$BATS_TEST_TMPDIR/else2.pushInsteadOf" "$R.origin"
  expect deny "git -C $W push origin feat"
  git -C "$W" config --remove-section "url.$BATS_TEST_TMPDIR/else2"
  expect allow "git -C $W push origin feat"
}

@test "lease: a missing origin/<base> counts as not own" {
  settings 'rebase.push: autopilot' 'base_branch: nosuch'
  set_autopilot on
  expect deny "git -C $BATS_TEST_TMPDIR/wt push --force-with-lease origin feat"
}

@test "lease: the source of src:dst is what gets checked" {
  git -C "$R" branch other main
  git -C "$R" switch -q other
  printf 'x\n' >"$R/x"; git -C "$R" add x
  git -C "$R" -c user.email=other@example.com commit -q -m x
  git -C "$R" switch -q main
  expect deny "git -C $BATS_TEST_TMPDIR/wt push --force-with-lease origin other:feat"
}

@test "git and gh are matched case-insensitively" {
  expect deny "GIT push --force origin main"
  expect ask "Git -C $BATS_TEST_TMPDIR/wt push origin :feat" "GH pr merge 12 --squash" "GIT stash" \
    "/usr/bin/GIT reset --hard HEAD"
  set_autopilot on
  expect deny "GH pr merge 12 --squash" "Git stash"
}

@test "an explicit lease value under autopilot names the bare option" {
  settings 'rebase.push: autopilot'
  set_autopilot on
  g1 "git -C $BATS_TEST_TMPDIR/wt push --force-with-lease=feat:0123456 origin feat"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"--force-with-lease=<ref>:<expect> under autopilot; use the bare option"* ]] || false
}

@test "a push URL rewritten for this remote is unproven; an unrelated rewrite is not" {
  W="$BATS_TEST_TMPDIR/wt"
  set_autopilot on
  git config --global url.git@github.com:.pushInsteadOf https://github.com/
  expect allow "git -C $W push origin feat"
  git -C "$W" config "url.$BATS_TEST_TMPDIR/else.git.insteadOf" "$R.origin"
  expect deny "git -C $W push origin feat"
}

@test "a detached HEAD names itself in the reason" {
  W="$BATS_TEST_TMPDIR/wt"
  git -C "$W" switch -q --detach
  for c in "git -C $W push" "git -C $W push origin HEAD" "git -C $W push --force-with-lease origin HEAD"; do
    g1 "$c"
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
    [[ "$output" == *"HEAD is detached; check out a branch first"* ]] || { echo "$c -> $output"; return 1; }
  done
  settings 'rebase.push: autopilot'
  set_autopilot on
  for c in "git -C $W push" "git -C $W push origin HEAD" "git -C $W push --force-with-lease"; do
    g1 "$c"
    [ "$(decision_of "$output")" = deny ] || { echo "$c -> $output"; return 1; }
    [[ "$output" == *"HEAD is detached; check out a branch first"* ]] || { echo "$c -> $output"; return 1; }
  done
}

@test "a trailing comment does not hide a command" {
  set -- "git clean -fd # -n" "git clean -fdx # --dry-run" "git merge main # --abort"
  expect ask "$@"
  set_autopilot on
  expect deny "$@"
}

# g1q CMD: g1 for a command that may hold double quotes or backslashes.
g1q() { g1 "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }

@test "git behind a command kern cannot read asks, and is denied under autopilot" {
  local c
  for c in "env --ch sub git push --force origin main" "env -iC sub git push --force origin main"; do
    g1q "$c"
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
    [[ "$output" == *"git inside sub cannot be checked; run git directly"* ]] || false
  done
  set_autopilot on
  for c in "env --ch sub git push --force origin main" "env -iC sub git push --force origin main" \
    "caffeinate -i git push --force origin main" "stdbuf -oL git commit -m x" \
    "echo main | xargs git push --force origin" 'find . -maxdepth 0 -exec git push --force origin main \;' \
    "caffeinate g''it push --force origin main" "caffeinate git -C x -c a=b --no-pager push origin feat" \
    "builtin command git push --force origin main"; do
    g1q "$c"
    [ "$(decision_of "$output")" = deny ] || { echo "$c -> $output"; return 1; }
    [[ "$output" == *"git inside "*" under autopilot"* ]] || { echo "$c -> $output"; return 1; }
  done
}

@test "a word git that runs no git command, or a read-only one, gets no vote" {
  local c mode
  for mode in off on; do
    set_autopilot "$mode"
    for c in "brew install git" "which git" "apt-get install git curl" "man git" 'grep -rn "git push" docs' \
      'echo "git push"' "xargs git status" "git status" "caffeinate git --no-pager log -1" "brew install git gh"; do
      g1q "$c"
      [ "$(decision_of "$output")" = none ] || { echo "$mode: $c -> $output"; return 1; }
    done
  done
}

@test "echo git push asks: a word git before one of git's commands that writes is not read further" {
  g1 "echo git push"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *"git inside echo cannot be checked"* ]] || false
  set_autopilot on
  g1 "echo git push"
  [ "$(decision_of "$output")" = deny ]
}

@test "an append assignment or a wrapper in another case does not hide git from G1's own checks" {
  local c mode
  for mode in off on; do
    set_autopilot "$mode"
    for c in "X+=1 git push --force origin main" "ENV git push --force origin main" \
      "Env --chdir=sub git push --force origin main" 'BASH -c "git push --force origin main"' \
      'ENV bash -c "git push --force origin main"' "env -iS 'git push --force origin main'"; do
      g1q "$c"
      [ "$(decision_of "$output")" = deny ] || { echo "$mode: $c -> $output"; return 1; }
      [[ "$output" == *"plain force push"* ]] || { echo "$mode: $c -> $output"; return 1; }
      [[ "$output" != *"cannot be checked"* ]] || { echo "$mode: $c -> $output"; return 1; }
    done
  done
  set_autopilot off
  expect ask "GIT_DIR+=$R/.git git reset --hard"
  [[ "$output" == *"after cd, --git-dir or --work-tree"* ]] || false
}

@test "git behind a command with -c or --config-env among its options asks, whatever word follows" {
  local c cmds=(
    "caffeinate git -c alias.p=push p --force origin main"
    "caffeinate git -c help.autocorrect=immediate psuh --force origin main"
    "caffeinate git --config-env=help.autocorrect=V psuh --force origin main"
    "caffeinate git -c include.path=/tmp/a.cfg p --force origin main"
  )
  g1 "caffeinate git -c alias.p=push p --force origin main"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *"git inside caffeinate cannot be checked; run git directly"* ]] || false
  g1 "caffeinate git -c color.ui=never log -1"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  for c in "${cmds[@]}" "caffeinate git -c ALIAS.p=push p" "caffeinate git --no-pager --config-env Alias.p=V p" \
    "xargs git -c alias.s=status s" "caffeinate git -c color.ui=never log -1"; do
    g1q "$c"
    [ "$(decision_of "$output")" = deny ] || { echo "$c -> $output"; return 1; }
  done
  for c in "caffeinate git --no-pager log -1" "echo GIT_CONFIG_COUNT=1" "GIT_CONFIG_COUNT=0 git status"; do
    g1q "$c"
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
}

@test "a hidden git with no word after it gets no vote, and GIT_CONFIG in the text changes nothing" {
  local c
  set_autopilot on
  for c in "echo \$GIT_CONFIG_GLOBAL; which git" "env | grep GIT_CONFIG; git --version; type git" \
    "grep -rn GIT_CONFIG hooks | grep -v git" "GIT_CONFIG_NOSYSTEM=1 git log | grep git" \
    "git commit -m 'CDS-2465: read GIT_CONFIG_COUNT' | grep git" "caffeinate git -c color.ui=never" \
    "git commit -m 'CDS-2465: set GIT_CONFIG_COUNT=1' | xargs git log -1"; do
    g1q "$c"
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
  run_guard "$(bash_payload "git -C $BATS_TEST_TMPDIR/wt commit -m 'CDS-2465: read GIT_CONFIG_COUNT' | grep git")" g01,g05
  [ "$(decision_of "$output")" = allow ] || { echo "$output"; return 1; }
}
