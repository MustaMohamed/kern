#!/usr/bin/env bats
# scripts/kern-get's size defaults. M3 part 2 project 2's paid round 1: the h2h plan row's two false alarms came from
# runs that looped kern-get over scope_threshold and pr.max_lines with one DEFAULT or none, then stated a limit kern-get
# never printed. With no DEFAULT and nothing setting them, both keys now print kernel/settings.md's defaults.

bats_require_minimum_version 1.5.0
load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  mkdir -p "$R/.claude"
  RP=$(cd "$R" && pwd -P)
  K="$(kern_root)"
  cd "$R"
}

kg() { run --separate-stderr bash "$K/scripts/kern-get" "$@"; }

@test "each size key, unset, prints kernel/settings.md's default with the source default" {
  kg scope_threshold
  [ "$status" -eq 0 ]
  [ "$output" = "4	default" ]
  [ -z "$stderr" ]
  kg pr.max_lines
  [ "$status" -eq 0 ]
  [ "$output" = "300	default" ]
  [ -z "$stderr" ]
  # The values are settings.md's rows.
  grep -qF '| `scope_threshold` | `4` |' "$K/kernel/settings.md"
  grep -qF '| `pr.max_lines` | `300` |' "$K/kernel/settings.md"
  # A loop over both keys with no DEFAULT, as the round's runs wrote it, prints each key's own default.
  run bash -c "for k in scope_threshold pr.max_lines; do bash '$K/scripts/kern-get' \$k; done"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '4\tdefault\n300\tdefault')" ]
  # Any other key still exits 3 with no DEFAULT.
  kg base_branch
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

@test "a size key set in a settings file prints the set value and that file" {
  printf 'scope_threshold: 6\n' >"$R/.claude/kern.yml"
  printf 'pr.max_lines: 450\n' >"$HOME/.claude/kern.yml"
  kg scope_threshold
  [ "$status" -eq 0 ]
  [ "$output" = "6	$RP/.claude/kern.yml" ]
  kg pr.max_lines
  [ "$status" -eq 0 ]
  [ "$output" = "450	$HOME/.claude/kern.yml" ]
}

@test "an explicit DEFAULT wins over the built-in one, and a set value over both" {
  kg scope_threshold 7
  [ "$status" -eq 0 ]
  [ "$output" = "7	default" ]
  # The value a looped `kern-get $k 4` gave pr.max_lines in the round: the caller's DEFAULT stands.
  kg pr.max_lines 4
  [ "$status" -eq 0 ]
  [ "$output" = "4	default" ]
  printf 'pr.max_lines: 450\n' >"$R/.claude/kern.local.yml"
  kg pr.max_lines 4
  [ "$output" = "450	$RP/.claude/kern.local.yml" ]
}
