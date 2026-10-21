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

@test "kern-dir refuses an upper-case or non-ASCII name under a UTF-8 locale too" {
  cd "$R"
  for n in Tmp SPECS "caf$(printf '\303\251')"; do
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 run bash "$K/kern-dir" "$n"
    [ "$status" -eq 2 ] || { echo "$n -> $status $output"; return 1; }
  done
  [ ! -e "$R/.kern/Tmp" ]
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

@test "kern-dir adds a newline before its exclude line when the file lacks one" {
  cd "$R"
  printf 'foo' >"$R/.git/info/exclude"
  run bash "$K/kern-dir" specs
  [ "$status" -eq 0 ]
  [ "$(cat "$R/.git/info/exclude")" = "$(printf 'foo\n/.kern/')" ]
  run bash "$K/kern-dir" specs
  [ "$(wc -l <"$R/.git/info/exclude" | tr -d ' ')" -eq 2 ]
  [ "$(grep -cxF '/.kern/' "$R/.git/info/exclude")" -eq 1 ]
}

@test "kern-dir refuses a work_dir of ., .git*, or starting with a colon" {
  cd "$R"
  mkdir -p .claude
  for w in . ./ .git .github ':x'; do
    printf 'work_dir: %s\n' "$w" >.claude/kern.local.yml
    run bash "$K/kern-dir" specs
    [ "$status" -eq 2 ] || { echo "work_dir $w: status $status"; false; }
    [[ "$output" == *work_dir* ]] || false
  done
  rm .claude/kern.local.yml
  run bash "$K/kern-dir" ":specs"
  [ "$status" -eq 2 ]
}

# kern-dir creates the work dir and edits .git/info/exclude, so it does not act on a work_dir a settings
# file it cannot read may set (Task 16l, fix round 2).
@test "kern-dir exits 2 and says why when a settings file that could set work_dir cannot be read" {
  mkdir -p "$R/.claude"
  printf 'work_dir: .kwork\n' >"$R/.claude/kern.local.yml"
  read_fails awk "$(cd "$R" && pwd -P)/.claude/kern.local.yml"
  cd "$R"
  run --separate-stderr bash "$K/kern-dir" tmp
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"kern-dir: work_dir is unknown: "*"kern.local.yml could not be read"* ]] || false
  [ ! -e "$R/.kern" ] && [ ! -e "$R/.kwork" ]
}
