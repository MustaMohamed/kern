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
  [[ "${lines[1]}" == "kern at $K. Here and in kern files read by path, {ROOT} and \${CLAUDE_PLUGIN_ROOT} mean that path; {KERN} means {ROOT}/skills." ]] || false
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
  # kern ships technical-writing from Task 15; until then no kern job matches the project skill.
  if [ -d "$K/skills/technical-writing" ]; then [[ "$output" == *"technical-writing -> project skill technical-writing"* ]] || false; fi
  [[ "$output" == *"Routes: define -> off"* ]] || false
  [[ "$output" == *"Ignored, floor actions have no key: merge.policy"* ]] || false
  [[ "$output" == *"Unknown keys, ignored: foo.bar"* ]] || false
  set_line=$(printf '%s\n' "$output" | grep '^Set: ')
  unknown_line=$(printf '%s\n' "$output" | grep '^Unknown keys, ignored: ')
  [[ "$set_line" == *"push.policy=auto"* ]] || false
  [[ "$set_line" != *"merge.policy"* ]] || false
  [[ "$unknown_line" != *"merge.policy"* ]] || false
  before_set=${output%%"Set: "*}
  [[ "$before_set" == *"Ignored, floor actions have no key: "* ]] || false
}

@test "a long summary keeps every override in full and stays within 600 characters" {
  F="$BATS_TEST_TMPDIR/kern"
  mkdir -p "$F/skills/self-review" "$F/skills/commit"
  cp -R "$K/.claude-plugin" "$K/hooks" "$K/kernel" "$K/modes" "$F/"
  for job in self-review commit; do
    mkdir -p "$R/.claude/skills/$job"
    printf -- '---\nname: %s\n---\n' "$job" >"$R/.claude/skills/$job/SKILL.md"
  done
  cat >"$R/.claude/kern.local.yml" <<'YML'
base_branch: main
branch.pattern: {id}/{slug}
branch.protected: main, qa, uat, production
deploy.envs: qa, uat, production
worktree.setup: ln -s ../node_modules node_modules && cp ../.env .env
shared_services: postgres · minio · localstack · cognito · café
test.full: npm test --prefix cds-api && npm test --prefix cds-web
test.focused: npx jest {file}
typecheck: npx tsc --noEmit -p cds-api && npx tsc --noEmit -p cds-web
lint: npm run lint · é · é · é · é · é · é · é · é · é · é · é · é · é · é
verify.browser: node scripts/cds-session.mjs --env local --probe /dashboard
YML
  run bash "$F/hooks/session-start" <<<"$(payload SessionStart '"source":"startup"')"
  [ "$status" -eq 0 ]
  summary=$(printf '%s\n' "$output" | sed '1,/^## Project settings$/d')
  [[ "$summary" == *"commit -> project skill commit"* ]] || false
  [[ "$summary" == *"self-review -> project skill self-review"* ]] || false
  [[ "$summary" == *"(more: bash {ROOT}/scripts/kern-get <key>)"* ]] || false
  before_set=${summary%%"Set: "*}
  [[ "$before_set" == *"Overrides (follow the project skill, say so in one line): "* ]] || false
  [ "${#summary}" -le 600 ] || { echo "summary is ${#summary} chars"; return 1; }
  printf '%s' "$output" | iconv -f UTF-8 -t UTF-8 >/dev/null
}

@test "kern: off prints nothing" {
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  start startup
  [ -z "$output" ]
}

@test "outside a git repository the kernel still renders from user settings" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  export CWD="$BATS_TEST_TMPDIR/plain"
  printf 'mode.surface: auto\n' >"$HOME/.claude/kern.yml"
  start startup
  [[ "$output" == *"Not a git repository"* ]] || false
  [[ "$output" == *"Settings files: ~/.claude/kern.yml"* ]] || false
}

@test "a lower-layer autopilot deny is named in the kernel" {
  printf 'autopilot: allowed\n' >"$R/.claude/kern.yml"
  printf 'autopilot: denied\n' >"$HOME/.claude/kern.yml"
  start startup
  [[ "$output" == *"denied by $HOME/.claude/kern.yml"* ]] || false
}

@test "a committed loosening value is ignored, so the summary does not list it as set" {
  printf 'kern: off\npush.policy: auto\nrebase.push: autopilot\ncommit.policy: deny\n' >"$R/.claude/kern.yml"
  start startup
  [ "$status" -eq 0 ]
  set_line=$(printf '%s\n' "$output" | grep '^Set: ')
  [[ "$set_line" == *"commit.policy=deny"* ]] || false
  [[ "$set_line" != *"kern="* ]] || false
  [[ "$set_line" != *"push.policy="* ]] || false
  [[ "$set_line" != *"rebase.push="* ]] || false
}

# old FILE...: sets each FILE's mtime to 2020-01-01, well past the 30-day limit.
old() { touch -h -t 202001010000 "$@"; }

@test "state files untouched for 30 days are removed; recent ones and other names stay" {
  S="$CLAUDE_PLUGIN_DATA/sessions"
  mkdir -p "$S/sub"
  for f in gone.state .state.Ab12Cd recent.state notes.txt sub/deep.state; do printf 'voice: normal\n' >"$S/$f"; done
  old "$S/gone.state" "$S/.state.Ab12Cd" "$S/notes.txt" "$S/sub/deep.state"
  start startup
  [ "$status" -eq 0 ]
  [ ! -e "$S/gone.state" ]
  [ ! -e "$S/.state.Ab12Cd" ]
  [ -f "$S/recent.state" ]
  [ -f "$S/notes.txt" ]
  [ -f "$S/sub/deep.state" ]
}

@test "the current session's state file stays however old it is" {
  set_autopilot on
  old "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  start compact
  [ -f "$CLAUDE_PLUGIN_DATA/sessions/test-session.state" ]
  [[ "$output" == *"autopilot=on"* ]] || false
}

@test "a symlink named like a state file stays, and so does its target" {
  S="$CLAUDE_PLUGIN_DATA/sessions"
  mkdir -p "$S"
  printf 'keep\n' >"$BATS_TEST_TMPDIR/target"
  ln -s "$BATS_TEST_TMPDIR/target" "$S/x.state"
  old "$BATS_TEST_TMPDIR/target" "$S/x.state"
  start startup
  [ -L "$S/x.state" ]
  [ -f "$BATS_TEST_TMPDIR/target" ]
}

@test "a symlinked state dir is left alone" {
  mkdir -p "$BATS_TEST_TMPDIR/real"
  printf 'voice: normal\n' >"$BATS_TEST_TMPDIR/real/gone.state"
  old "$BATS_TEST_TMPDIR/real/gone.state"
  ln -s "$BATS_TEST_TMPDIR/real" "$CLAUDE_PLUGIN_DATA/sessions"
  # find does not follow a symlinked start path, so a logging find shows the step was skipped.
  real=$(command -v find)
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho "$*" >>"%s/find.log"\nexec "%s" "$@"\n' "$BATS_TEST_TMPDIR" "$real" >"$BATS_TEST_TMPDIR/bin/find"
  chmod +x "$BATS_TEST_TMPDIR/bin/find"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" start startup
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "# kern "* ]] || false
  [ -f "$BATS_TEST_TMPDIR/real/gone.state" ]
  [ ! -e "$BATS_TEST_TMPDIR/find.log" ]
}

@test "a state dir kern cannot write to does not stop session-start" {
  S="$CLAUDE_PLUGIN_DATA/sessions"
  mkdir -p "$S"
  printf 'voice: normal\n' >"$S/gone.state"
  old "$S/gone.state"
  chmod 555 "$S"
  out=$(bash "$K/hooks/session-start" 2>/dev/null <<<"$(payload SessionStart '"source":"startup"')") || rc=$?
  chmod 755 "$S"
  [ "${rc-0}" -eq 0 ]
  [[ "$out" == "# kern "* ]] || false
  [[ "$out" != *"ermission denied"* ]] || false
}

# start_without LIB [LINE]: runs a copy of session-start whose hooks/lib/LIB is removed, or replaced by
# the real one plus LINE; stdout only, into $out.
start_without() {
  rm -rf "$BATS_TEST_TMPDIR/k"
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$K/kernel" "$K/modes" "$K/.claude-plugin" "$BATS_TEST_TMPDIR/k/"
  rm "$BATS_TEST_TMPDIR/k/hooks/lib/$1"
  [ -z "${2-}" ] || { cat "$K/hooks/lib/$1"; printf '%s\n' "$2"; } >"$BATS_TEST_TMPDIR/k/hooks/lib/$1"
  out=$(bash "$BATS_TEST_TMPDIR/k/hooks/session-start" 2>/dev/null <<<"$(payload SessionStart '"source":"startup"')")
}

@test "a library session-start cannot load gives one line that says so" {
  local lib
  for lib in json.sh settings.sh state.sh; do
    start_without "$lib"
    [ "$out" = "kern did not load: hooks/lib/$lib is missing or broken; guards ask on every call; reinstall kern" ] ||
      { echo "$lib -> $out"; return 1; }
  done
  # PreToolUse does not load render.sh, so the guards still run.
  start_without render.sh
  [ "$out" = "kern did not load: hooks/lib/render.sh is missing or broken; reinstall kern" ] || { echo "$out"; return 1; }
  start_without state.sh "unset -f state_reset"
  [ "$out" = "kern did not load: hooks/lib/state.sh is missing or broken; guards ask on every call; reinstall kern" ] ||
    { echo "$out"; return 1; }
}

@test "with POSIXLY_CORRECT set, a missing library still gives the one line" {
  rm -rf "$BATS_TEST_TMPDIR/k"
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/"
  rm "$BATS_TEST_TMPDIR/k/hooks/lib/state.sh"
  out=$(POSIXLY_CORRECT=1 bash "$BATS_TEST_TMPDIR/k/hooks/session-start" 2>/dev/null <<<"$(payload SessionStart '"source":"startup"')") ||
    { echo "status $?"; return 1; }
  [ "$out" = "kern did not load: hooks/lib/state.sh is missing or broken; guards ask on every call; reinstall kern" ] ||
    { echo "$out"; return 1; }
}

@test "session-start checks every function each library it loads defines" {
  need_lists_match session-start
}

@test "the Reply section carries the candor line and the AI-tell line" {
  start startup
  [[ "$output" == *"No is an acceptable answer: say when a scope, proposal or plan is weak, and why."* ]] || false
  [[ "$output" == *"in either voice skip the main AI tells"* ]] || false
}
