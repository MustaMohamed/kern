#!/usr/bin/env bats
# scripts/skill-conflicts: the same-name skills /kern:help setup lists.

bats_require_minimum_version 1.5.0
load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  S="$(kern_root)/scripts/skill-conflicts"
  tab=$'\t'
  mkdir -p "$R/.claude/skills/commit" "$HOME/.claude/skills/plan"
  printf -- '---\nname: commit\n---\n' >"$R/.claude/skills/commit/SKILL.md"
  printf -- '---\nname: plan\n---\n' >"$HOME/.claude/skills/plan/SKILL.md"
  cd "$R"
}

@test "lists a project and a user same-name skill with their sources" {
  run bash "$S"
  [ "$status" -eq 0 ]
  [ "$output" = "commit${tab}project${tab}commit${tab}"$'\n'"plan${tab}user${tab}plan${tab}" ]
}

@test "shows a pick, and --unpicked hides a skill with overrides.<job>: off" {
  printf 'overrides.commit: off\n' >"$R/.claude/kern.local.yml"
  run bash "$S"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "commit${tab}project${tab}commit${tab}off" ]
  run bash "$S" --unpicked
  [ "$status" -eq 0 ]
  [ "$output" = "plan${tab}user${tab}plan${tab}" ]
}

@test "a linked worktree reads the main worktree's skills and picks" {
  printf 'overrides.commit: my-commit\n' >"$R/.claude/kern.local.yml"
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  cd "$BATS_TEST_TMPDIR/wt"
  run bash "$S"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "commit${tab}project${tab}commit${tab}my-commit" ]
}

@test "outside a repository only user skills are listed" {
  cd "$BATS_TEST_TMPDIR"
  run bash "$S"
  [ "$status" -eq 0 ]
  [ "$output" = "plan${tab}user${tab}plan${tab}" ]
}

@test "a settings file it cannot read leaves the pick empty and the list whole" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  printf 'overrides.commit: off\n' >"$R/.claude/kern.local.yml"
  chmod 000 "$R/.claude/kern.local.yml"
  run --separate-stderr bash "$S"
  [ "$status" -eq 0 ]
  [ "$output" = "commit${tab}project${tab}commit${tab}"$'\n'"plan${tab}user${tab}plan${tab}" ]
}

@test "any other argument is a usage error" {
  run bash "$S" --all
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: skill-conflicts [--unpicked]"* ]] || false
  run bash "$S" --unpicked --unpicked
  [ "$status" -eq 2 ]
}
