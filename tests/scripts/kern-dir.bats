#!/usr/bin/env bats
# scripts/kern-dir and scripts/kern-root.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)/scripts"
}

@test "kern-root prints the main root and the common dir from a linked worktree" {
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  cd "$BATS_TEST_TMPDIR/wt"
  run bash "$K/kern-root"
  [ "${lines[0]}" = "$(cd "$R" && pwd -P)" ]
  [ "$(cd "${lines[1]}" && pwd -P)" = "$(cd "$R/.git" && pwd -P)" ]
}

@test "kern-root outside a repo exits 2" {
  cd "$BATS_TEST_TMPDIR"
  run bash "$K/kern-root" "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
}

@test "kern-dir creates WORK/sub at the main root and adds the exclude line once" {
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  cd "$BATS_TEST_TMPDIR/wt"
  run bash "$K/kern-dir" specs
  [ "$status" -eq 0 ]
  [ -d "$R/.kern/specs" ]
  run bash "$K/kern-dir" plans
  [ "$(grep -cxF '/.kern/' "$R/.git/info/exclude")" -eq 1 ]
  [ -z "$(git -C "$R" status --porcelain)" ]
}

@test "kern-dir creates a nested folder such as ledgers/<slug>" {
  cd "$R"
  run bash "$K/kern-dir" ledgers/plan-a
  [ "$status" -eq 0 ]
  [ -d "$R/.kern/ledgers/plan-a" ]
  run bash "$K/kern-dir" ledgers//x
  [ "$status" -eq 2 ]
}

@test "kern-dir refuses a work dir with tracked files and a bad name" {
  mkdir -p "$R/.kern"; printf 'x\n' >"$R/.kern/t.md"
  git -C "$R" add .kern/t.md; git -C "$R" commit -q -m t
  cd "$R"
  run bash "$K/kern-dir" specs
  [ "$status" -eq 2 ]
  run bash "$K/kern-dir" "../x"
  [ "$status" -eq 2 ]
}
