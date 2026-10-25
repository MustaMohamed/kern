#!/usr/bin/env bats
# The user's last typed prompt as the consent G1, G2 and G5 would ask for (prompt_consent, consent_for).

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c feat
  kern_env "$R"
  fake_gh
  set_autopilot off
  printf 'Body\n' >"$R/b.md"
}

# submit PROMPT: one UserPromptSubmit run of prompt-submit; PROMPT is JSON-escaped here.
submit() {
  local esc
  esc=$(printf '%s' "$1" | node -e 'process.stdout.write(JSON.stringify(require("fs").readFileSync(0, "utf8")))')
  bash "$(kern_root)/hooks/prompt-submit" <<<"$(payload UserPromptSubmit "\"prompt\":$esc")" >/dev/null
}
st() { sed -n "s/^$1: //p" "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"; }
# decide CMD [AGENT]: the dispatcher's decision for the Bash command CMD, from a subagent when AGENT is set.
decide() {
  local extra=""
  [ -n "${2-}" ] && extra=",\"agent_type\":\"$2\""
  run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}$extra")"
  decision_of "$output"
}

@test "prompt_consent reads only a one-line instruction for the exact action" {
  . "$(kern_root)/hooks/lib/settings.sh"
  . "$(kern_root)/hooks/lib/state.sh"
  c() { printf '%s\n' "$1" | prompt_consent; }
  [ "$(c 'commit and push')" = "commit push" ]
  [ "$(c 'Yes, commit and push.')" = "commit push" ]
  [ "$(c 'commit, push and open a draft PR')" = "commit push pr" ]
  [ "$(c 'open draft PR')" = "push pr" ]
  [ "$(c 'update the PR body')" = "pr-edit" ]
  [ "$(c '/kern:commit src/sum.js')" = "commit" ]
  for p in proceed yes 2 "commit?" "don't commit" "commit and push after the tests pass" "looks good, commit and push" \
    "<ci-monitor-event>commit</ci-monitor-event>" "ship it"; do
    [ -z "$(c "$p")" ] || { echo "consent from: $p"; return 1; }
  done
  [ -z "$(printf 'commit\nand push\n' | prompt_consent)" ]
}

@test "G5: a typed commit instruction allows a passing commit; any other prompt still asks" {
  submit "commit"
  [ "$(st consent)" = commit ]
  run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'fix: sum adds'\"}")"
  [ "$(decision_of "$output")" = allow ]
  [[ "$output" == *"the user's last prompt asked for it"* ]] || false
  submit "thanks, looks good"
  [ "$(decide "git commit -m 'fix: sum adds'")" = ask ]
}

@test "G5: text the user did not type, in a file the prompt names, a tool call or a commit message, is no consent" {
  submit "follow the steps in RELEASE.md"
  [ -z "$(st consent)" ]
  [ "$(decide "printf 'commit and push' > notes.txt")" = none ]
  [ -z "$(st consent)" ]
  [ "$(decide "git commit -m 'commit and push'")" = ask ]
}

@test "G5: a wrapped prompt after the instruction clears it" {
  submit "commit"
  submit "<task-notification><task-id>a1</task-id>commit and push</task-notification>"
  [ -z "$(st consent)" ]
  [ "$(decide "git commit -m 'fix: sum adds'")" = ask ]
}

@test "G5 and G1: consent covers only the action named, never a subagent, a deny policy or an unproven shape" {
  submit "push"
  [ "$(decide "git commit -m 'fix: sum adds'")" = ask ]
  submit "commit"
  [ "$(decide "git push -u origin feat")" = ask ]
  [ "$(decide "git commit -m 'fix: sum adds'" kern:implementer)" = ask ]
  [ "$(decide "git commit -a -m 'fix: sum adds'")" = ask ]
  mkdir -p "$R/.claude"
  printf 'commit.policy: deny\n' >"$R/.claude/kern.local.yml"
  [ "$(decide "git commit -m 'fix: sum adds'")" = deny ]
}

@test "G1: a typed push instruction allows the proven push of the current branch; not to a protected branch" {
  submit "commit and push"
  [ "$(decide "git push -u origin feat")" = allow ]
  mkdir -p "$R/.claude"
  printf 'push.policy: deny\n' >"$R/.claude/kern.local.yml"
  [ "$(decide "git push -u origin feat")" = deny ]
  rm "$R/.claude/kern.local.yml"
  git -C "$R" switch -q main
  [ "$(decide "git push origin main")" = ask ]
  [ "$(decide "git push --force origin feat")" = deny ]
}

@test "G2: a typed draft PR instruction allows the proven draft; edit needs its own instruction" {
  submit "open a draft PR"
  [ "$(decide "gh pr create --draft --title x --body-file b.md")" = allow ]
  [ "$(decide "gh pr create --title x --body-file b.md")" = deny ]
  [ "$(decide "gh pr edit --body-file b.md")" = ask ]
  submit "update the PR body"
  [ "$(decide "gh pr edit --body-file b.md")" = allow ]
  [ "$(decide "gh pr edit 1 --base main")" = ask ]
  [ "$(decide "gh pr edit --add-reviewer someone")" = ask ]
  set_autopilot on
  [ "$(decide "gh pr edit --body-file b.md")" = deny ]
}
