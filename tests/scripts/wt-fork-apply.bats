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

@test "a failed include removes the fork" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  printf 'secret.log\n' > .worktreeinclude
  git add .worktreeinclude && git commit --quiet -m include
  printf 'token\n' > secret.log
  chmod 000 secret.log
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-9
  chmod 600 secret.log
  [ "$status" -eq 2 ]
  [ -z "$output" ]
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

@test "wt-fork --share-setup links the closed list, runs no setup and writes the marker" {
  mkdir -p .claude
  printf 'worktree.setup: printf x >> %s/setups\n' "$TMP" > .claude/kern.local.yml
  mkdir -p "$SRC/node_modules/pkg" "$SRC/.venv" "$SRC/dist"
  printf 'lib\n' > "$SRC/node_modules/pkg/index.js"
  printf 'out\n' > "$SRC/dist/app.js"
  printf '.venv/\ndist/\n' >> "$(git -C "$SRC" rev-parse --git-path info/exclude)"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-20 --share-setup
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  fork=$output
  [ ! -e "$TMP/setups" ]
  [ "$(cd "$fork/node_modules" && pwd -P)" = "$(cd "$SRC/node_modules" && pwd -P)" ]
  [ "$(cd "$fork/.venv" && pwd -P)" = "$(cd "$SRC/.venv" && pwd -P)" ]
  [ ! -e "$fork/dist" ]
  [ "$(cat "$(git -C "$fork" rev-parse --path-format=absolute --git-dir)/kern-setup-done")" = "setup: shared" ]
  bash "$KERN_ROOT/scripts/wt-check" "$fork" origin/main
  # Removing the fork removes the links, never what they point at.
  git worktree remove --force "$fork"
  [ -f "$SRC/node_modules/pkg/index.js" ]
}

@test "--share-setup with nothing to share runs worktree.setup" {
  mkdir -p .claude
  printf 'worktree.setup: printf x >> %s/setups\n' "$TMP" > .claude/kern.local.yml
  mkdir -p "$SRC/dist"
  printf 'out\n' > "$SRC/dist/app.js"
  printf 'dist/\n' >> "$(git -C "$SRC" rev-parse --git-path info/exclude)"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-21 --share-setup
  [ "$status" -eq 0 ]
  fork=$output
  [ "$(wc -c < "$TMP/setups" | tr -d ' ')" -eq 1 ]
  [ ! -e "$fork/dist" ]
  [ "$(cat "$(git -C "$fork" rev-parse --path-format=absolute --git-dir)/kern-setup-done")" = "setup: printf x >> $TMP/setups" ]
}

@test "--share-setup links only what is git-ignored, and a fork's own path stays" {
  mkdir -p .claude
  printf 'worktree.setup: printf x >> %s/setups\n' "$TMP" > .claude/kern.local.yml
  # vendor is not ignored, so it moves with the state as a real directory; an empty .venv does not move at all.
  mkdir -p "$SRC/vendor" "$SRC/node_modules" "$SRC/.venv"
  printf 'dep\n' > "$SRC/vendor/dep.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-22 --share-setup
  [ "$status" -eq 0 ]
  fork=$output
  [ ! -L "$fork/vendor" ]
  [ "$(cat "$fork/vendor/dep.txt")" = dep ]
  [ ! -e "$fork/.venv" ]
  [ -L "$fork/node_modules" ]
  [ ! -e "$TMP/setups" ]
}

@test "without --share-setup a fork links nothing, and any other third argument exits 2" {
  mkdir -p "$SRC/node_modules"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-23
  [ "$status" -eq 0 ]
  [ ! -e "$output/node_modules" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-24 --share
  [ "$status" -eq 2 ]
  [ ! -e "$REPO/.claude/worktrees/task-24" ]
}

@test "wt-diff writes TO_TREE to <package>.tree, and wt-apply --tree needs it to match" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-25 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'from worker\n' > "$fork/w.txt"
  out=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/t.diff")
  pkg=$(printf '%s\n' "$out" | sed -n 1p)
  to=$(printf '%s\n' "$out" | sed -n 2p)
  [ "$(cat "$pkg.tree")" = "$to" ]
  before=$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")
  # Another tree.
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC" --tree "$t0"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$t0"* ]] || false
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")" = "$before" ]
  # No record of the tree.
  mv "$pkg.tree" "$TMP/kept"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC" --tree "$to"
  [ "$status" -eq 2 ]
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")" = "$before" ]
  mv "$TMP/kept" "$pkg.tree"
  # A matching tree.
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC" --tree "$to"
  [ "$status" -eq 0 ]
  [ "$output" = "applied" ]
  [ "$(cat "$SRC/w.txt")" = "from worker" ]
}

@test "wt-apply refuses --tree with no value and any other extra argument" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-26 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'from worker\n' > "$fork/w.txt"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/u.diff" | head -n 1)
  for args in "--tree" "--tree $t0 extra" "--to $t0"; do
    run --separate-stderr bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC" $args
    [ "$status" -eq 2 ] || { echo "accepted: $args"; false; }
  done
  [ ! -e "$SRC/w.txt" ]
}

@test "--share-setup leaves it to setup when a link resolves into SRC outside its directory" {
  mkdir -p .claude
  printf 'worktree.setup: printf x >> %s/setups\n' "$TMP" > .claude/kern.local.yml
  printf '.venv/\n' >> "$(git -C "$SRC" rev-parse --git-path info/exclude)"
  mkdir -p "$SRC/packages/p" "$SRC/.venv" "$SRC/node_modules/@scope"
  printf 'code\n' > "$SRC/packages/p/index.js"
  # A scoped workspace link, two levels down.
  ln -s ../../packages/p "$SRC/node_modules/@scope/p"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-27 --share-setup
  [ "$status" -eq 0 ]
  fork=$output
  [ ! -e "$fork/node_modules" ]
  # Nothing is linked, or setup would write through a link: .venv stays out too.
  [ ! -e "$fork/.venv" ]
  [ "$(wc -c < "$TMP/setups" | tr -d ' ')" -eq 1 ]
  [ "$(cat "$(git -C "$fork" rev-parse --path-format=absolute --git-dir)/kern-setup-done")" = "setup: printf x >> $TMP/setups" ]
  # A link to SRC itself, and a link to a file.
  rm "$SRC/node_modules/@scope/p"
  ln -s .. "$SRC/node_modules/self"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-28 --share-setup
  [ "$status" -eq 0 ]
  [ ! -e "$output/node_modules" ]
  rm "$SRC/node_modules/self"
  ln -s ../packages/p/index.js "$SRC/node_modules/entry.js"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-29 --share-setup
  [ "$status" -eq 0 ]
  [ ! -e "$output/node_modules" ]
}

@test "--share-setup links nothing when a later directory is the one that is not sealed" {
  mkdir -p .claude
  printf 'worktree.setup: printf x >> %s/setups\n' "$TMP" > .claude/kern.local.yml
  printf '.venv/\n' >> "$(git -C "$SRC" rev-parse --git-path info/exclude)"
  mkdir -p "$SRC/node_modules/tool" "$SRC/.venv" "$SRC/packages/p"
  printf 'code\n' > "$SRC/packages/p/index.py"
  ln -s ../packages/p "$SRC/.venv/p"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-32 --share-setup
  [ "$status" -eq 0 ]
  fork=$output
  # node_modules comes first in the list and is clean: setup would write through its link.
  [ ! -e "$fork/node_modules" ]
  [ ! -e "$fork/.venv" ]
  [ "$(wc -c < "$TMP/setups" | tr -d ' ')" -eq 1 ]
}

@test "a .worktreeinclude entry below a shared directory does not copy through the link" {
  mkdir -p "$REPO/node_modules/pkg" "$SRC/node_modules/pkg"
  printf 'main\n' > "$REPO/node_modules/pkg/extra.txt"
  printf 'top\n' > "$REPO/top.log"
  printf 'node_modules/pkg/extra.txt\ntop.log\n' > "$REPO/.worktreeinclude"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-33 --share-setup
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  fork=$output
  [ -L "$fork/node_modules" ]
  [ ! -e "$SRC/node_modules/pkg/extra.txt" ]
  # An entry outside the link still copies, and so does this one on a fork with its own directory.
  [ "$(cat "$fork/top.log")" = top ]
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-34
  [ "$status" -eq 0 ]
  [ "$(cat "$output/node_modules/pkg/extra.txt")" = main ]
}

@test "--share-setup still links a directory whose links stay inside it or leave SRC" {
  mkdir -p .claude
  printf 'worktree.setup: printf x >> %s/setups\n' "$TMP" > .claude/kern.local.yml
  mkdir -p "$SRC/node_modules/.bin" "$SRC/node_modules/tool" "$TMP/store/dep"
  printf 'cli\n' > "$SRC/node_modules/tool/cli.js"
  ln -s ../tool/cli.js "$SRC/node_modules/.bin/tool"
  ln -s tool "$SRC/node_modules/alias"
  ln -s "$TMP/store/dep" "$SRC/node_modules/dep"
  ln -s "$TMP/missing" "$SRC/node_modules/dangling"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-30 --share-setup
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  [ -L "$output/node_modules" ]
  [ ! -e "$TMP/setups" ]
  # A link past the scan's depth stays shared: the exposure the contract row names.
  mkdir -p "$SRC/node_modules/a/b/c"
  ln -s "$SRC" "$SRC/node_modules/a/b/c/deep"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-31 --share-setup
  [ "$status" -eq 0 ]
  [ -L "$output/node_modules" ]
}
