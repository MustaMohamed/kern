#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c feat
  kern_env "$R"
  fake_gh
  mkdir -p "$R/.kern/tmp"
  printf 'Body\n' >"$R/.kern/tmp/pr-body.md"
}

show() {
  run_guard "$(bash_payload "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')")"
  printf '%s | %s\n' "$(decision_of "$output")" "$1" >&3
}

@test "titles" {
  B="--base main --body-file $R/.kern/tmp/pr-body.md"
  show "gh pr create --draft --title 'M2: plain' $B"
  show "gh pr create --draft --title \"M2: plain\" $B"
  show "gh pr create --draft --title 'M2: cost \$5' $B"
  show "gh pr create --draft --title \"M2: cost \$5\" $B"
  show "gh pr create --draft --title 'M2: use \`x\`' $B"
  show "gh pr create --draft --title 'M2: a \$(b)' $B"
  show "gh pr create --draft --title 'M2: it'\\''s' $B"
  show "gh pr create --draft --title 'M2: say \"hi\"' $B"
  set_autopilot on
  show "gh pr create --draft --title 'M2: plain' $B"
  show "gh pr create --draft --title 'M2: it'\\''s' $B"
  show "gh pr create --draft --title 'M2: cost \$5' $B"
  show "gh pr create --draft --title 'M2: use \`x\`' $B"
  show "gh pr create --draft --title 'M2: plain' --base main --body-file .kern/tmp/pr-body.md"
}
