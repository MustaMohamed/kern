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

@test "with settings.sh missing, session-start exits 0 and prints nothing" {
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  rm "$BATS_TEST_TMPDIR/k/hooks/lib/settings.sh"
  out=$(bash "$BATS_TEST_TMPDIR/k/hooks/session-start" 2>/dev/null <<<"$(payload SessionStart '"source":"startup"')")
  [ -z "$out" ]
}
