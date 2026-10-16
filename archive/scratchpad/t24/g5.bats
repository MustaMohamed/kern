#!/usr/bin/env bats
load /Users/musta/Code/projects/kern/tests/helpers/common
setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c CDS-2465/feat
  mkdir -p "$R/.claude"
  printf 'commit.convention: "^CDS-[0-9]+: "\n' >"$R/.claude/kern.local.yml"
  kern_env "$R"
  W="$BATS_TEST_TMPDIR/wt"
  git -C "$R" worktree add -q -b CDS-2466/plan "$W"
  mkdir -p "$R/.kern/tmp"; printf '/.kern/\n' >> "$R/.git/info/exclude"
  printf 'CDS-2466: do thing\n\nwhy\n' > "$R/.kern/tmp/commit-msg"
  export KERN_MAIN="$R"
}
dec() { run_guard "$(printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" "$2")" "${GUARDS-g05}"; decision_of "$output"; printf '%s\n' "$output" | head -c 400 >&2; }
@test "main checkout commit" { set_autopilot on; run dec "$R" "git -C $R commit -F $R/.kern/tmp/commit-msg"; echo "MAIN autopilot: $output" >&3; }
@test "wt commit from main cwd" { set_autopilot on; run dec "$R" "git -C $W commit -F $R/.kern/tmp/commit-msg"; echo "WT-from-main autopilot: $output" >&3; }
@test "wt commit from wt cwd" { set_autopilot on; run dec "$W" "git -C $W commit -F $R/.kern/tmp/commit-msg"; echo "WT-from-wt autopilot: $output" >&3; }
@test "wt commit autopilot off" { set_autopilot off; run dec "$R" "git -C $W commit -F $R/.kern/tmp/commit-msg"; echo "WT autopilot-off: $output" >&3; }
@test "wt add" { set_autopilot on; touch $W/a.txt; run dec "$R" "git -C $W add -- a.txt b.txt"; echo "WT add: $output" >&3; }
@test "wt commit wt branch protected" { set_autopilot on; git -C $W switch -q -c main2 2>/dev/null; run dec "$R" "git -C $W commit -F $R/.kern/tmp/commit-msg"; echo "wt other branch: $output" >&3; }
@test "main on main protected" { set_autopilot on; git -C $R switch -q main; run dec "$R" "git -C $R commit -F $R/.kern/tmp/commit-msg"; echo "MAIN on main: $output" >&3; }
@test "detached wt" { set_autopilot on; git -C $W switch -q --detach; run dec "$R" "git -C $W commit -F $R/.kern/tmp/commit-msg"; echo "WT detached: $output" >&3; }

@test "main ok msg" { set_autopilot on; printf 'CDS-2465: do\n\nwhy\n' > $R/.kern/tmp/m2; run dec "$R" "git -C $R commit -F $R/.kern/tmp/m2"; echo "MAIN ok: $output" >&3; }
@test "main cwd no -C" { set_autopilot on; printf 'CDS-2465: do\n\nwhy\n' > $R/.kern/tmp/m2; run dec "$R" "git commit -F $R/.kern/tmp/m2"; echo "MAIN noC: $output" >&3; }
@test "wt add full guards" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W add -- a.txt b.txt"; echo "WT add all guards: $output" >&3; }
@test "wt status full guards" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W status --porcelain"; echo "WT status all guards: $output" >&3; }
@test "wt commit full guards" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W commit -F $R/.kern/tmp/commit-msg"; echo "WT commit all guards: $output" >&3; }
@test "wt revparse tree full" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W rev-parse HEAD^{tree}"; echo "WT revparse tree: $output" >&3; }
@test "c hole" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W -c core.fsmonitor=evil status --porcelain"; echo "HOLE status -c: $output" >&3; }
@test "c hole diff" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W diff --output=/tmp/x HEAD"; echo "HOLE diff output: $output" >&3; }
@test "rename add all guards auto" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W add -- old.txt new.txt"; echo "RENAME add (autopilot on, all guards): $output" >&3; }
@test "rename add g05 only auto" { set_autopilot on; run dec "$R" "git -C $W add -- old.txt new.txt"; echo "RENAME add g05 only: $output" >&3; }
@test "rename add off" { set_autopilot off; GUARDS="" run dec "$W" "git -C $W add -- old.txt new.txt"; echo "RENAME add autopilot off cwd wt: $output" >&3; }
@test "dir add" { set_autopilot on; mkdir -p $W/src; GUARDS="" run dec "$R" "git -C $W add -- src/"; echo "ADD dir src/: $output" >&3; }
@test "wide add" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W add -- ."; echo "ADD dot: $output" >&3; }
@test "commit with -F after fix" { set_autopilot on; GUARDS="" run dec "$R" "git -C $W commit -F $R/.kern/tmp/commit-msg"; echo "COMMIT all guards: $output" >&3; }
