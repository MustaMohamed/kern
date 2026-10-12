#!/usr/bin/env bats
# hooks/session-start: kernel rendering, mode reset rules, settings summary.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  mkdir -p "$R/.claude"
  K="$(kern_root)"
}

start() { run bash "$K/hooks/session-start" <<<"$(payload SessionStart "\"source\":\"$1\"")"; }

@test "startup prints the kernel with every placeholder filled" {
  start startup
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "# kern "* ]] || false
  [[ "$output" == *"kern mode: voice=normal surface=auto autopilot=off"* ]] || false
  [[ "$output" == *"kern at $K."* ]] || false
  [[ "$output" == *"Read {KERN}/technical-writing/SKILL.md"* ]] || false
  [ "$(printf '%s' "$output" | grep -o "$K" | wc -l | tr -d ' ')" -eq 1 ]
  for ph in VERSION ROOT_PATH MODE AUTOPILOT SETTINGS; do
    [[ "$output" != *"{$ph}"* ]] || { echo "unfilled {$ph}"; return 1; }
  done
}

@test "the rendered kernel stays under 4,000 characters with no settings" {
  start startup
  # Measure with a typical installed root (50 characters) so the checkout path does not matter.
  norm=${output//"$K"/\/Users\/someone\/.claude\/plugins\/cache\/kern\/kern\/0.1.0}
  [ "${#norm}" -le 4000 ]
}

@test "startup and clear reset the mode; compact and resume keep it" {
  start startup
  set_autopilot on
  start compact
  [[ "$output" == *"autopilot=on"* ]] || false
  [[ "$output" == *"Autopilot: ON since"* ]] || false
  start resume
  [[ "$output" == *"autopilot=on"* ]] || false
  start clear
  [[ "$output" == *"autopilot=off"* ]] || false
  set_autopilot on
  start startup
  [[ "$output" == *"autopilot=off"* ]] || false
}

@test "terse from settings appends the terse rules" {
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  start startup
  [[ "$output" == *"voice=terse"* ]] || false
  [[ "$output" == *"# kern terse voice"* ]] || false
}

@test "the summary lists set keys, overrides, routes, floor keys and unknown keys" {
  mkdir -p "$R/.claude/skills/technical-writing"
  printf -- '---\nname: technical-writing\n---\n' >"$R/.claude/skills/technical-writing/SKILL.md"
  printf 'push.policy: auto\nmerge.policy: auto\nroute.define: off\nfoo.bar: 1\n' >"$R/.claude/kern.local.yml"
  start startup
  [[ "$output" == *"Settings files: .claude/kern.local.yml"* ]] || false
  [[ "$output" == *"push.policy=auto"* ]] || false
  [[ "$output" == *"technical-writing -> project skill technical-writing"* ]] || false
  [[ "$output" == *"Routes: define -> off"* ]] || false
  [[ "$output" == *"Ignored, floor actions have no key: merge.policy"* ]] || false
  [[ "$output" == *"Unknown keys, ignored: foo.bar"* ]] || false
}

@test "kern: off prints nothing" {
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  start startup
  [ -z "$output" ]
}

@test "outside a git repository the kernel still renders from user settings" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  export CWD="$BATS_TEST_TMPDIR/plain"
  start startup
  [[ "$output" == *"Not a git repository"* ]] || false
}
