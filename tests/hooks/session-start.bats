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
  [[ "${lines[1]}" == "In kern files read by path, \${CLAUDE_PLUGIN_ROOT} means $K." ]] || false
  # Every row names its route by absolute path: a model read {KERN}/... literally and gave up on kern.
  [[ "$output" == *"| Read $K/skills/technical-writing/SKILL.md |"* ]] || false
  [[ "$output" == *"| Read $K/skills/diagnose/SKILL.md |"* ]] || false
  [[ "$output" == *"| Read $K/kernel/context.md |"* ]] || false
  [[ "$output" == *"Scripts: bash $K/scripts/<name>."* ]] || false
  for ph in VERSION ROOT_PATH ROOT KERN MODE AUTOPILOT SETTINGS; do
    [[ "$output" != *"{$ph}"* ]] || { echo "unfilled {$ph}"; return 1; }
  done
}

# The rule 7 target for the rendered kernel, measured after Task 16d put every route row in the kernel and
# Task 16g added the Precedence skip line, the parallel-work row and the "in parallel" clause, and Task 16i the
# skip line in the Routing opt-out clause.
TARGET=5756

@test "the rendered kernel stays within the rule 7 target with no settings" {
  start startup
  # Measure with a typical installed root (52 characters) so the checkout path does not matter.
  norm=${output//"$K"/\/Users\/someone\/.claude\/plugins\/cache\/kern\/kern\/0.1.0}
  [ "${#norm}" -le "$TARGET" ] || { echo "${#norm} characters"; return 1; }
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

# ap_on: the user types /kern:autopilot on in session test-session, through the real prompt hook.
ap_on() {
  run bash "$K/hooks/prompt-submit" <<<"$(payload UserPromptExpansion '"expansion_type":"slash_command","command_name":"kern:autopilot","command_args":"on","command_source":"plugin","prompt":"/kern:autopilot on"')"
}

@test "a second startup for the same session id turns autopilot off" {
  # Fail closed: a startup for an id that has state may be a reused id, whose old grant must not carry
  # over. Known limit: a repeated SessionStart(startup) in one session also turns autopilot off.
  start startup
  ap_on
  [ "$(sed -n 's/^autopilot: //p' "$CLAUDE_PLUGIN_DATA/sessions/test-session.state")" = on ]
  start startup
  [[ "$output" == *"autopilot=off"* ]] || false
  [ "$(sed -n 's/^autopilot: //p' "$CLAUDE_PLUGIN_DATA/sessions/test-session.state")" = off ]
}

@test "terse from settings appends the terse rules" {
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  start startup
  [[ "$output" == *"voice=terse"* ]] || false
  [[ "$output" == *"# kern terse voice"* ]] || false
}

@test "the summary lists set keys, overrides, floor keys and unknown keys; route.<name> is an unknown key" {
  mkdir -p "$R/.claude/skills/technical-writing"
  printf -- '---\nname: technical-writing\n---\n' >"$R/.claude/skills/technical-writing/SKILL.md"
  printf 'push.policy: auto\nmerge.policy: auto\nroute.define: off\nfoo.bar: 1\n' >"$R/.claude/kern.local.yml"
  start startup
  [[ "$output" == *"Settings files: .claude/kern.local.yml"* ]] || false
  [[ "$output" == *"push.policy=auto"* ]] || false
  # kern ships technical-writing from Task 15; until then no kern job matches the project skill.
  if [ -d "$K/skills/technical-writing" ]; then [[ "$output" == *"technical-writing -> project skill technical-writing"* ]] || false; fi
  # route.<name> had no reader (audit B8): overrides.<job> names a project skill for a job.
  [[ "$output" != *"Routes:"* ]] || false
  [[ "$output" == *"Ignored, floor actions have no key: merge.policy"* ]] || false
  set_line=$(printf '%s\n' "$output" | grep '^Set: ')
  unknown_line=$(printf '%s\n' "$output" | grep '^Unknown keys, ignored: ')
  [ "$set_line" = "Set: push.policy=auto" ] || { echo "$set_line"; return 1; }
  [[ "$unknown_line" == *"foo.bar"* ]] || false
  [[ "$unknown_line" == *"route.define"* ]] || false
  [[ "$unknown_line" != *"merge.policy"* ]] || false
  before_set=${output%%"Set: "*}
  [[ "$before_set" == *"Ignored, floor actions have no key: "* ]] || false
}

# summary: the lines after the Project settings heading, the plugin root read as {ROOT}, into $summary.
summary() {
  summary=$(printf '%s\n' "$output" | sed '1,/^## Project settings$/d')
  summary=${summary//"$K"/\{ROOT\}}
}

# has_line LINE: $output holds LINE as a whole line.
has_line() { printf '%s\n' "$output" | grep -qxF -- "$1"; }

@test "overrides.<job>: off is no override: kern's route stays and a project skill of that name is not matched" {
  # Audit B1: off rendered as "diagnose -> project skill off", and a same-name project skill still overrode.
  printf 'overrides.diagnose: off\n' >"$R/.claude/kern.local.yml"
  start startup
  [ "$status" -eq 0 ]
  [[ "$output" != *"project skill off"* ]] || false
  [[ "$output" != *"Overrides ("* ]] || false
  [[ "$output" != *"overrides.diagnose"* ]] || false
  for job in diagnose commit; do
    mkdir -p "$R/.claude/skills/$job"
    printf -- '---\nname: %s\n---\n' "$job" >"$R/.claude/skills/$job/SKILL.md"
  done
  start startup
  [[ "$output" != *"diagnose -> project skill"* ]] || false
  has_line "Overrides (follow the project skill, say so in one line): commit -> project skill commit"
  # Without off, the same-name project skill overrides kern's route, in the line neg-project-skill reads.
  rm "$R/.claude/kern.local.yml"
  start startup
  has_line "Overrides (follow the project skill, say so in one line): commit -> project skill commit; diagnose -> project skill diagnose"
}

@test "Set: holds known keys whose value differs from a literal default, policy keys first" {
  # Audit B6: a typo such as push.polcy read as an auto push policy, and default values were listed.
  printf 'push.polcy: auto\nfoo.bar: 1\nscope_threshold: 4\nautopilot: allowed\nmode.voice: normal\nparallel.max: 5\nbase_branch: develop\ntracker.policy: deny\n' >"$R/.claude/kern.local.yml"
  start startup
  set_line=$(printf '%s\n' "$output" | grep '^Set: ')
  [ "$set_line" = "Set: tracker.policy=deny; base_branch=develop; parallel.max=5" ] || { echo "$set_line"; return 1; }
  unknown_line=$(printf '%s\n' "$output" | grep '^Unknown keys, ignored: ')
  [[ "$unknown_line" == *"push.polcy"* ]] || false
  [[ "$unknown_line" == *"foo.bar"* ]] || false
}

@test "25 routes and 60 unknown keys keep the block within 600, the Unknown list cut first and push.policy=deny kept" {
  # Audit B7: this committed file rendered 1,069 chars, and its Set: line lost push.policy=deny.
  {
    printf 'test.full: npm test\npush.policy: deny\n'
    i=1
    while [ "$i" -le 25 ]; do printf 'route.r%s: my-project-route-%s\n' "$i" "$i"; i=$((i + 1)); done
    i=1
    while [ "$i" -le 60 ]; do printf 'unknown.key%s: %s\n' "$i" "$i"; i=$((i + 1)); done
  } >"$R/.claude/kern.yml"
  start startup
  [ "$status" -eq 0 ]
  summary
  [ "${#summary}" -le 600 ] || { echo "summary is ${#summary} chars"; return 1; }
  [[ "$summary" == *$'\n'"Set: push.policy=deny; test.full=npm test"$'\n'* ]] || { echo "$summary"; return 1; }
  unknown_line=$(printf '%s\n' "$summary" | grep '^Unknown keys, ignored: ')
  [[ "$unknown_line" =~ ^Unknown\ keys,\ ignored:\ .+,\ and\ ([0-9]+)\ more$ ]] || { echo "$unknown_line"; return 1; }
  shown=$(printf '%s\n' "${unknown_line#Unknown keys, ignored: }" | tr ',' '\n' | grep -c -v ' more$')
  [ $((shown + BASH_REMATCH[1])) -eq 85 ] || { echo "$shown shown, ${BASH_REMATCH[1]} more"; return 1; }
}

@test "a cut Set: keeps the policy keys, and a huge override value still keeps the block within 600" {
  long=$(printf '%0400d' 0)
  printf 'test.full: %s\nlint: %s\nwork_dir: .w\ntracker.policy: deny\noverrides.commit: %s%s\n' "$long" "$long" "$long" "$long" >"$R/.claude/kern.local.yml"
  mkdir -p "$R/.claude/skills/diagnose"
  printf -- '---\nname: diagnose\n---\n' >"$R/.claude/skills/diagnose/SKILL.md"
  start startup
  [ "$status" -eq 0 ]
  summary
  [ "${#summary}" -le 600 ] || { echo "summary is ${#summary} chars"; return 1; }
  [[ "$summary" == *$'\n'"Overrides (follow the project skill, say so in one line): diagnose -> project skill diagnose; and 1 more"$'\n'* ]] ||
    { echo "$summary"; return 1; }
  [[ "$summary" == *$'\n'"Set: tracker.policy=deny; work_dir=.w ... (more: bash {ROOT}/scripts/kern-get <key>)"* ]] || { echo "$summary"; return 1; }
  # With no entry that fits, the line still says the job has an override.
  rm -r "$R/.claude/skills/diagnose"
  start startup
  has_line "Overrides (follow the project skill, say so in one line): 1 not shown"
}

@test "unknown keys never cut an override, and a short Set: line holds no more room than it needs" {
  # Twelve same-name project skills fill 523 chars of Overrides; with Set: and an unknown key the block is
  # 617. Only the Unknown list may give way, here as a whole line: no shortest form of it fits.
  for job in commit define diagnose execute-plan finish-branch implement parallel-work plan prove-it recall self-review technical-writing; do
    mkdir -p "$R/.claude/skills/$job"
    printf -- '---\nname: %s\n---\n' "$job" >"$R/.claude/skills/$job/SKILL.md"
  done
  printf 'base_branch: develop\nfoo.bar: 1\n' >"$R/.claude/kern.local.yml"
  start startup
  summary
  [ "${#summary}" -le 600 ] || { echo "summary is ${#summary} chars"; return 1; }
  has_line "Overrides (follow the project skill, say so in one line): commit -> project skill commit; define -> project skill define; diagnose -> project skill diagnose; execute-plan -> project skill execute-plan; finish-branch -> project skill finish-branch; implement -> project skill implement; parallel-work -> project skill parallel-work; plan -> project skill plan; prove-it -> project skill prove-it; recall -> project skill recall; self-review -> project skill self-review; technical-writing -> project skill technical-writing"
  has_line "Set: base_branch=develop"
  [[ "$summary" != *"Unknown keys"* ]] || { echo "$summary"; return 1; }
}

@test "Main worktree names the main root only when the session's cwd is elsewhere" {
  RP=$(cd "$R" && pwd -P)
  start startup
  [[ "$output" != *"Main worktree:"* ]] || false
  summary
  [ "$summary" = "Settings files: none; defaults apply" ] || { echo "$summary"; return 1; }
  ln -s "$R" "$BATS_TEST_TMPDIR/link"
  export CWD="$BATS_TEST_TMPDIR/link"
  start startup
  [[ "$output" != *"Main worktree:"* ]] || false
  mkdir -p "$R/sub"
  export CWD="$R/sub"
  start startup
  [[ "$output" == *$'\n'"## Project settings"$'\n'"Main worktree: $RP"$'\n'* ]] || false
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  export CWD="$BATS_TEST_TMPDIR/wt"
  start startup
  [[ "$output" == *$'\n'"Main worktree: $RP"$'\n'"Settings files: none; defaults apply"* ]] || false
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
  [[ "$summary" == *"(more: bash $F/scripts/kern-get <key>)"* ]] || false
  before_set=${summary%%"Set: "*}
  [[ "$before_set" == *"Overrides (follow the project skill, say so in one line): "* ]] || false
  # The 600 counts the plugin root as {ROOT}, so the entries kept do not depend on the install path.
  summary=${summary//"$F"/\{ROOT\}}
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

# fake_git_version OUTPUT RC: puts a git first on PATH that answers `git version` with OUTPUT and exit
# code RC and hands every other call to the real git.
fake_git_version() {
  mkdir -p "$BATS_TEST_TMPDIR/gitbin"
  printf '#!/bin/sh\nif [ "$1" = version ]; then printf "%%s" "%s"; exit %s; fi\nexec "%s" "$@"\n' \
    "$1" "$2" "$(command -v git)" >"$BATS_TEST_TMPDIR/gitbin/git"
  chmod +x "$BATS_TEST_TMPDIR/gitbin/git"
  export PATH="$BATS_TEST_TMPDIR/gitbin:$PATH"
}

@test "git older than 2.31, or a git version that cannot be read, gets one line saying the hardening may not apply" {
  local v rc n norm
  for v in "git version 2.30.9|0|is older than 2.31" "|1|failed or printed no version" \
    "git version 2.54.0|3|failed or printed no version" "not a version|0|failed or printed no version" \
    "git version x.31|0|failed or printed no version"; do
    fake_git_version "${v%%|*}" "$(printf '%s' "$v" | cut -d'|' -f2)"
    start startup
    [ "$status" -eq 0 ]
    n=$(printf '%s\n' "$output" | grep -c "GIT_CONFIG_\* hardening" || true)
    [ "$n" -eq 1 ] || { echo "$v: $n hardening lines"; return 1; }
    [[ "$output" == *"${v##*|}"*"a repository's fsmonitor program"*"on kern's index reads"* ]] || { echo "$v: $output"; return 1; }
    [[ "${lines[0]}" == "# kern "* ]] || false
    [[ "$output" == *"## Project settings"* ]] || false
    norm=${output//"$K"/\/Users\/someone\/.claude\/plugins\/cache\/kern\/kern\/0.1.0}
    [ "${#norm}" -le "$TARGET" ] || { echo "$v: ${#norm} characters"; return 1; }
    PATH=${PATH#"$BATS_TEST_TMPDIR/gitbin:"}
  done
  fake_git_version "git version 2.30.9" 0
  start startup
  [[ "$output" == *"kern: git 2.30 is older than 2.31, so git ignores kern's GIT_CONFIG_* hardening"* ]] || false
}

@test "git 2.31 or later gets no git line" {
  local v
  for v in "git version 2.31.0" "git version 2.54" "git version 2.54.0 (Apple Git-157)" "git version 3.0.1"; do
    fake_git_version "$v" 0
    start startup
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Project settings"* ]] || false
    [[ "$output" != *"GIT_CONFIG_"* ]] || { echo "$v warned"; return 1; }
    PATH=${PATH#"$BATS_TEST_TMPDIR/gitbin:"}
  done
}

@test "a headless session starts in the normal voice, and the user can still switch to terse" {
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  export CLAUDE_CODE_ENTRYPOINT=sdk-cli
  start startup
  [[ "$output" == *"kern mode: voice=normal surface=auto autopilot=off"* ]] || false
  [[ "$output" != *"# kern terse voice"* ]] || false
  run bash "$K/hooks/prompt-submit" <<<"$(payload UserPromptExpansion '"expansion_type":"slash_command","command_name":"kern:mode","command_args":"terse","command_source":"plugin","prompt":"/kern:mode terse"')"
  [[ "$output" == *"voice=terse"* ]] || false
  run bash "$K/hooks/prompt-submit" <<<"$(payload UserPromptExpansion '"expansion_type":"slash_command","command_name":"kern:mode","command_args":"default","command_source":"plugin","prompt":"/kern:mode default"')"
  [[ "$output" == *"voice=normal"* ]] || false
}

@test "mode.voice.headless: terse makes a headless session terse; an interactive one keeps mode.voice" {
  printf 'mode.voice: normal\nmode.voice.headless: terse\n' >"$R/.claude/kern.local.yml"
  export CLAUDE_CODE_ENTRYPOINT=sdk-cli
  start startup
  [[ "$output" == *"# kern terse voice"* ]] || false
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  export CLAUDE_CODE_ENTRYPOINT=cli
  start startup
  [[ "$output" == *"kern mode: voice=terse"* ]] || false
}

@test "a headless session whose state cannot be read still starts in the normal voice" {
  printf 'mode.voice: terse\n' >"$R/.claude/kern.local.yml"
  export CLAUDE_CODE_ENTRYPOINT=sdk-cli
  run bash "$K/hooks/session-start" <<<"$(payload SessionStart '"source":"startup"' | sed 's/"session_id": *"[^"]*"/"session_id":"..\/x"/')"
  [[ "$output" == *"voice=normal"* ]] || false
  [[ "$output" != *"# kern terse voice"* ]] || false
}

# CLAUDE_ENV_FILE: Claude Code 2.1.302 names a file in its session-env folder for a SessionStart hook and
# runs what the hook appends there ahead of each Bash tool command. It makes the folder, not the file.
env_line() { printf "export CLAUDE_PLUGIN_ROOT='%s'\n" "$1"; }

@test "CLAUDE_ENV_FILE gets one line exporting the plugin root, and nothing else" {
  start startup
  plain=$output
  mkdir -p "$BATS_TEST_TMPDIR/session-env/s1"
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/session-env/s1/sessionstart-hook-0.sh"
  start startup
  [ "$status" -eq 0 ]
  env_line "$K" | cmp - "$CLAUDE_ENV_FILE"
  [ "$output" = "$plain" ] || { echo "the kernel output changed"; return 1; }
  printf 'export A=1\n' >"$CLAUDE_ENV_FILE"
  start startup
  { printf 'export A=1\n'; env_line "$K"; } | cmp - "$CLAUDE_ENV_FILE"
}

@test "the CLAUDE_ENV_FILE line is quoted for the shell, so a root with a quote, a space or a dollar sign survives" {
  F="$BATS_TEST_TMPDIR/it's a \$kern \`x\`"
  mkdir -p "$F"
  cp -R "$K/.claude-plugin" "$K/hooks" "$K/kernel" "$K/modes" "$K/skills" "$F/"
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/env.sh"
  : >"$CLAUDE_ENV_FILE"
  run bash "$F/hooks/session-start" <<<"$(payload SessionStart '"source":"startup"')"
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_ENV_FILE")" = "export CLAUDE_PLUGIN_ROOT='$BATS_TEST_TMPDIR/it'\\''s a \$kern \`x\`'" ] || { cat "$CLAUDE_ENV_FILE"; return 1; }
  [ "$(env -i bash -c '. "$1"; printf %s "$CLAUDE_PLUGIN_ROOT"' _ "$CLAUDE_ENV_FILE")" = "$F" ]
}

@test "CLAUDE_ENV_FILE is left alone when it is not a writable file, or kern is off" {
  mkdir -p "$BATS_TEST_TMPDIR/dir"
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/dir"
  start startup
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "# kern "* ]] || false
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/dir")" ]
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/missing/env.sh"
  start startup
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/missing" ]
  printf 'export A=1\n' >"$BATS_TEST_TMPDIR/ro.sh"
  chmod 444 "$BATS_TEST_TMPDIR/ro.sh"
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/ro.sh"
  start startup
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/ro.sh")" = "export A=1" ]
  ln -s "$BATS_TEST_TMPDIR/nowhere.sh" "$BATS_TEST_TMPDIR/link.sh"
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/link.sh"
  start startup
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/nowhere.sh" ]
  : >"$BATS_TEST_TMPDIR/off.sh"
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/off.sh"
  start startup
  [ ! -s "$BATS_TEST_TMPDIR/off.sh" ]
}

# Claude Code always names an absolute path in its own session-env folder, never a symlink (Task 16d review).
@test "a relative CLAUDE_ENV_FILE is left alone" {
  mkdir -p "$BATS_TEST_TMPDIR/rel"
  cd "$BATS_TEST_TMPDIR/rel"
  export CLAUDE_ENV_FILE=env.sh
  start startup
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/rel/env.sh" ]
}

@test "a CLAUDE_ENV_FILE that is a symlink is left alone, even to a writable file" {
  : >"$BATS_TEST_TMPDIR/target.sh"
  ln -s "$BATS_TEST_TMPDIR/target.sh" "$BATS_TEST_TMPDIR/link.sh"
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/link.sh"
  start startup
  [ "$status" -eq 0 ]
  [ ! -s "$BATS_TEST_TMPDIR/target.sh" ]
}

@test "a CLAUDE_ENV_FILE that cannot be opened prints nothing" {
  start startup
  plain=$output
  mkdir -p "$BATS_TEST_TMPDIR/s"
  # The folder is writable and the path does not exist, but a trailing slash makes the open fail.
  export CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/s/env.sh/"
  start startup
  [ "$status" -eq 0 ]
  [ "$output" = "$plain" ] || { echo "output changed: $output" | head -3; return 1; }
}

@test "a plugin root that holds placeholder text or shell characters renders exactly" {
  # The render is one pass: a value it puts in is never read for a placeholder.
  F="$BATS_TEST_TMPDIR/k{ROOT}x{KERN}y{VERSION}&a\\b|c \$(d)
e"
  mkdir -p "$F"
  cp -R "$K/.claude-plugin" "$K/hooks" "$K/kernel" "$K/modes" "$K/skills" "$F/"
  run bash "$F/hooks/session-start" <<<"$(payload SessionStart '"source":"startup"')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"In kern files read by path, \${CLAUDE_PLUGIN_ROOT} means $F."$'\n'* ]] || false
  [[ "$output" == *$'\n'"| New behaviour and no agreed spec | Read $F/skills/define/SKILL.md |"$'\n'* ]] || false
  [[ "$output" == *$'\n'"| Phase ends, or context is filling | Read $F/kernel/context.md |"$'\n'* ]] || false
  [[ "$output" == *$'\n'"Scripts: bash $F/scripts/<name>. "* ]] || false
  run bash "$F/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a","agent_type":"Explore"')"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(0, "utf8")).hookSpecificOutput.additionalContext)' | grep -c '^In kern files read by path')" -eq 1 ]
  [[ "$(printf '%s' "$output" | node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(0, "utf8")).hookSpecificOutput.additionalContext)')" == *"\${CLAUDE_PLUGIN_ROOT} means $F."* ]] || false
}

# A read of the state file that fails, as one does when a fork or exec is refused under load, must not
# reset a state that exists (exec traces of 2026-10-21: autopilot turned off mid-session).
@test "compact and resume keep an existing state when reading it fails" {
  S="$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  for src in compact resume; do
    set_autopilot on
    read_fails awk "$S"
    start "$src"
    [ "$status" -eq 0 ]
    [ "$(sed -n 's/^autopilot: //p' "$S")" = on ] || { echo "$src"; return 1; }
    [ "$(sed -n 's/^since: //p' "$S")" = 2026-10-12T00:00:00Z ]
    # A read that fails never reads as autopilot on.
    [[ "$output" == *"autopilot=off"* ]] || false
    read_fails awk "$S" 0
    start "$src"
    [[ "$output" == *"autopilot=on"* ]] || false
  done
}

@test "compact and resume give a session with no state file the default state" {
  S="$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  for src in compact resume; do
    rm -f "$S"
    start "$src"
    [ "$status" -eq 0 ]
    [ "$(sed -n 's/^voice: //p' "$S")" = normal ] || { echo "$src"; return 1; }
    [ "$(sed -n 's/^autopilot: //p' "$S")" = off ]
    [ -n "$(sed -n 's/^since: //p' "$S")" ]
    [[ "$output" == *"autopilot=off"* ]] || false
  done
}
