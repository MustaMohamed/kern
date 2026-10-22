#!/usr/bin/env bats
# G1 and G3 in a submodule: a submodule takes its superproject's answer to "is this the main checkout".
# Git gives each superproject worktree its own submodule git dir, so a submodule in a linked worktree is
# its own main worktree to git, though kern's agent works there as in any linked worktree (P2 review).

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  W="$BATS_TEST_TMPDIR/wt"
  S="$BATS_TEST_TMPDIR/sub"
  make_repo "$R"
  git init -q -b main "$S"
  git -C "$S" -c user.name=t -c user.email=t@t commit -q --allow-empty -m s
  git -C "$R" -c protocol.file.allow=always submodule add -q "$S" mod
  git -C "$R" commit -q -m "add mod"
  git -C "$R" worktree add -q -b feat "$W" >/dev/null 2>&1
  git -C "$W" -c protocol.file.allow=always submodule update -q --init
  kern_env "$R"
}

# expect DECISION CMD...: G1 gives DECISION for every CMD.
expect() {
  local want="$1" c
  shift
  for c in "$@"; do
    run_guard "$(bash_payload "$c")" g01
    [ "$(decision_of "$output")" = "$want" ] || { echo "$c -> $output"; return 1; }
  done
}

# fix_review: G3's decision for code-review --fix through the Skill tool, from CWD.
fix_review() {
  run_guard "$(payload PreToolUse '"tool_name":"Skill","tool_input":{"skill":"code-review","args":"main...feat --fix"}')" g03
  decision_of "$output"
}

@test "in the main checkout's submodule, G1 asks, and denies under autopilot" {
  expect ask "git -C $R/mod switch -c y" "git -C $R/mod reset --hard HEAD" "git -C $R/mod checkout -b x"
  export CWD="$R/mod"
  expect ask "git switch -c q"
  set_autopilot on
  expect deny "git switch -c q"
  export CWD="$R"
  expect deny "git -C $R/mod switch -c y" "git -C $R/mod reset --hard HEAD" "git -C $R/mod checkout -b x"
}

@test "in a linked worktree's submodule, G1 gives no vote, under autopilot too" {
  [ -f "$W/mod/.git" ]
  expect none "git -C $W/mod switch -c y" "git -C $W/mod reset --hard HEAD" "git -C $W/mod checkout -b x"
  export CWD="$W/mod"
  expect none "git switch -c q"
  set_autopilot on
  expect none "git switch -c q"
  export CWD="$W"
  expect none "git -C $W/mod switch -c y" "git -C $W/mod reset --hard HEAD" "git -C $W/mod checkout -b x"
}

@test "G3's code-review --fix asks in the main checkout and its submodule, not in a linked worktree or its submodule" {
  [ "$(fix_review)" = ask ]
  export CWD="$R/mod"
  [ "$(fix_review)" = ask ]
  export CWD="$W"
  [ "$(fix_review)" = none ]
  export CWD="$W/mod"
  [ "$(fix_review)" = none ]
}
