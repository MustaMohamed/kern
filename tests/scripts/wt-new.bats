#!/usr/bin/env bats
# tests/scripts/wt-new.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
}

@test "wt-new creates a branch worktree off origin/main" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-a
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.claude/worktrees/feat-a" ]
  [ "$(git -C "$output" rev-parse --abbrev-ref HEAD)" = "kern/feat-a" ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse origin/main)" ]
  run git -C "$REPO/.claude/worktrees/feat-a" rev-parse --abbrev-ref '@{upstream}'
  [ "$status" -ne 0 ]
}

@test "wt-new fetches before branching" {
  git clone --quiet "$REPO.origin" "$TMP/other"
  git -C "$TMP/other" -c user.email=o@example.com -c user.name=O commit --quiet --allow-empty -m newer
  git -C "$TMP/other" push --quiet origin main
  newer=$(git -C "$TMP/other" rev-parse HEAD)
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-b
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$newer" ]
}

@test "wt-new keeps the main checkout status clean" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-c
  [ "$status" -eq 0 ]
  [ -z "$(git -C "$REPO" status --porcelain)" ]
  grep -qxF '/.claude/worktrees/' "$REPO/.git/info/exclude"
}

@test "wt-new --detach --base SHA makes a detached worktree at that commit" {
  first=$(git rev-parse HEAD)
  git commit --quiet --allow-empty -m second
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" bisect-1 --detach --base "$first"
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$first" ]
  [ "$(git -C "$output" rev-parse --abbrev-ref HEAD)" = "HEAD" ]
}

@test "wt-new copies files named in .worktreeinclude" {
  printf 'secret.log\n' > .worktreeinclude
  git add .worktreeinclude && git commit --quiet -m include && git push --quiet origin main
  printf 'token\n' > secret.log
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-d
  [ "$status" -eq 0 ]
  [ "$(cat "$output/secret.log")" = "token" ]
}

@test "wt-new runs worktree.setup and writes the marker" {
  mkdir -p .claude
  printf 'worktree.setup: touch setup-ran\n' > .claude/kern.local.yml
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-e
  [ "$status" -eq 0 ]
  [ -f "$output/setup-ran" ]
  gitdir=$(git -C "$output" rev-parse --path-format=absolute --git-dir)
  grep -q '^setup: touch setup-ran$' "$gitdir/kern-setup-done"
}

@test "a failing worktree.setup exits 2" {
  mkdir -p .claude
  printf 'worktree.setup: exit 7\n' > .claude/kern.local.yml
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-f
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"worktree.setup failed"* ]] || false
}

@test "an existing branch is refused" {
  git branch kern/feat-g
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-g
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"branch exists"* ]] || false
}

@test "a branch.pattern placeholder wt-new cannot fill asks for --branch" {
  mkdir -p .claude
  printf 'branch.pattern: CDS-{n}/{slug}\n' > .claude/kern.local.yml
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-h
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--branch"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-h --branch CDS-1/feat-h
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse --abbrev-ref HEAD)" = "CDS-1/feat-h" ]
}

@test "a bad slug exits 2" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" '../escape'
  [ "$status" -eq 2 ]
}

@test "a slug with a non-ASCII letter exits 2 under a UTF-8 locale too" {
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" "caf$(printf '\303\251')"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"bad slug"* ]] || false
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$REPO" "caf$(printf '\303\251')"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"bad slug"* ]] || false
}

@test "no origin remote exits 2 with a message" {
  git remote remove origin
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-i --base main
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"git fetch origin main failed"* ]] || false
  [ ! -d "$REPO/.claude/worktrees/feat-i" ]
}

@test "wt-new works when the repo path has a space" {
  SPACED="$TMP/my project"
  make_fixture "$SPACED"
  cd "$SPACED"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-j
  [ "$status" -eq 0 ]
  [ "$output" = "$SPACED/.claude/worktrees/feat-j" ]
}

@test "wt-check passes for a fresh kern worktree" {
  wt=$(bash "$KERN_ROOT/scripts/wt-new" feat-k)
  run bash "$KERN_ROOT/scripts/wt-check" "$wt" origin/main
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "wt-check rejects the main checkout" {
  run bash "$KERN_ROOT/scripts/wt-check" "$REPO" origin/main
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a linked worktree"* ]] || false
}

@test "wt-check rejects a base that is not an ancestor" {
  wt=$(bash "$KERN_ROOT/scripts/wt-new" feat-l)
  git checkout --quiet -b elsewhere
  git commit --quiet --allow-empty -m elsewhere
  run bash "$KERN_ROOT/scripts/wt-check" "$wt" elsewhere
  [ "$status" -eq 1 ]
  [[ "$output" == *"not an ancestor"* ]] || false
}

@test "wt-check rejects a worktree without the setup marker" {
  wt=$(bash "$KERN_ROOT/scripts/wt-new" feat-m)
  rm "$(git -C "$wt" rev-parse --path-format=absolute --git-dir)/kern-setup-done"
  run bash "$KERN_ROOT/scripts/wt-check" "$wt" origin/main
  [ "$status" -eq 1 ]
  [[ "$output" == *"setup marker missing"* ]] || false
}

# wt-new creates a worktree from base_branch, worktree.dir and branch.pattern, so it does not act on one
# a settings file it cannot read may set (Task 16l, fix round 2).
@test "wt-new exits 2 and creates nothing while a settings file that could set its keys cannot be read" {
  load ../helpers/common
  mkdir -p "$REPO/.claude"
  printf 'worktree.dir: ../elsewhere\n' >"$REPO/.claude/kern.local.yml"
  read_fails awk "$REPO/.claude/kern.local.yml"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-u
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"base_branch is unknown"*"kern.local.yml could not be read"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-u --base main
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"worktree.dir may not be the whole answer"* ]] || false
  [ "$(git -C "$REPO" worktree list | wc -l | tr -d ' ')" = 1 ]
  [ ! -e "$REPO/.claude/worktrees" ]
}
