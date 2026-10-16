#!/usr/bin/env bats
# tests/scripts/wt-fork-apply.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  SRC=$(bash "$KERN_ROOT/scripts/wt-new" plan)
}

@test "fork carries modified and untracked files and snapshots to the same tree" {
  printf 'edited\n' >> "$SRC/a.txt"
  printf 'new\n' > "$SRC/b.txt"
  src_tree=$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-1
  [ "$status" -eq 0 ]
  fork=$output
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")" = "$src_tree" ]
  [ "$(git -C "$fork" rev-parse HEAD)" = "$(git -C "$SRC" rev-parse HEAD)" ]
  [ "$(git -C "$fork" rev-parse --abbrev-ref HEAD)" = "HEAD" ]
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")" = "$src_tree" ]
}

@test "fork carries a deletion and a binary file" {
  rm "$SRC/a.txt"
  printf '\000\001\002binary' > "$SRC/blob.bin"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-2
  [ "$status" -eq 0 ]
  fork=$output
  [ ! -e "$fork/a.txt" ]
  cmp -s "$SRC/blob.bin" "$fork/blob.bin"
}

@test "a fork passes wt-check" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-3 2> /dev/null)
  run bash "$KERN_ROOT/scripts/wt-check" "$fork" origin/main
  [ "$status" -eq 0 ]
}

@test "an existing fork path exits 2" {
  bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-4 > /dev/null 2>&1
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-4
  [ "$status" -eq 2 ]
}

@test "wt-apply applies a worker's patch into the plan worktree" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-5 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'from worker\n' > "$fork/w.txt"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/w.diff" | head -n 1)
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 0 ]
  [ "$output" = "applied" ]
  [ "$(cat "$SRC/w.txt")" = "from worker" ]
}

@test "wt-apply applies a binary patch" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-6 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf '\000\377bin' > "$fork/img.bin"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/b.diff" | head -n 1)
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 0 ]
  cmp -s "$fork/img.bin" "$SRC/img.bin"
}

@test "a conflicting patch exits 3 and leaves the destination unchanged" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-7 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'one\nTWO-worker\nthree\n' > "$fork/a.txt"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/c.diff" | head -n 1)
  printf 'one\nTWO-other\nthree\n' > "$SRC/a.txt"
  before=$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 3 ]
  [[ "$output" == *"a.txt"* ]] || false
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")" = "$before" ]
}

@test "a missing patch file exits 2" {
  run bash "$KERN_ROOT/scripts/wt-apply" "$TMP/none.patch" "$SRC"
  [ "$status" -eq 2 ]
}

@test "a fork made from another directory reads worktree.setup from the main checkout" {
  mkdir -p .claude
  printf 'worktree.setup: touch setup-ran\n' > .claude/kern.local.yml
  cd "$TMP"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-8
  [ "$status" -eq 0 ]
  [ -f "$output/setup-ran" ]
}

@test "a failing worktree.setup removes the fork" {
  mkdir -p .claude
  printf 'worktree.setup: echo setup broke; exit 7\n' > .claude/kern.local.yml
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-9
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"setup broke"* ]] || false
  [[ "$stderr" == *"fork removed"* ]] || false
  [ ! -e "$REPO/.claude/worktrees/task-9" ]
  ! git worktree list | grep -q task-9
}

@test "diff.noprefix in the user's git config changes neither forks nor patches" {
  git config --global diff.noprefix true
  printf 'edited\n' >> "$SRC/a.txt"
  printf 'new\n' > "$SRC/b.txt"
  src_tree=$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-10
  [ "$status" -eq 0 ]
  fork=$output
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")" = "$src_tree" ]
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'from worker\n' > "$fork/w.txt"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/np.diff" | head -n 1)
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 0 ]
  [ "$(cat "$SRC/w.txt")" = "from worker" ]
}

@test "apply.whitespace in the user's git config changes neither forks nor applies" {
  printf '[apply]\n\twhitespace = fix\n' > "$TMP/gitconfig"
  export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
  printf 'a  \nb\t\n' > "$SRC/ws.txt"
  printf 'one  \ntwo\nthree\n' > "$SRC/a.txt"
  src_tree=$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-11
  [ "$status" -eq 0 ]
  fork=$output
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")" = "$src_tree" ]
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'worker  \n' > "$fork/w.txt"
  printf 'one  \ntwo  \nthree\n' > "$fork/a.txt"
  t1=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/ws.diff" | head -n 1)
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 0 ]
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")" = "$t1" ]
  printf '[apply]\n\twhitespace = error\n' > "$TMP/gitconfig"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-12
  [ "$status" -eq 0 ]
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$output")" = "$t1" ]
}

@test "a state the fork cannot take exits 3 and removes the fork" {
  printf 'new\n' > "$SRC/b.txt"
  # A post-checkout hook writes b.txt into the new fork, so the patch that adds it cannot apply.
  hooks=$(git rev-parse --git-common-dir)/hooks
  mkdir -p "$hooks"
  printf '#!/bin/sh\nprintf other > b.txt\n' > "$hooks/post-checkout"
  chmod +x "$hooks/post-checkout"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-13
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"could not apply the uncommitted state"* ]] || false
  [[ "$stderr" == *"fork removed"* ]] || false
  [ ! -e "$REPO/.claude/worktrees/task-13" ]
  ! git worktree list | grep -q task-13
}
