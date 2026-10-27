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

# submit PROMPT [PROMPT_ID]: one UserPromptSubmit run of prompt-submit, with prompt_id PROMPT_ID (p1 when
# left out; none when empty); PROMPT is JSON-escaped here.
submit() {
  local esc pid="${2-p1}" extra=""
  esc=$(printf '%s' "$1" | node -e 'process.stdout.write(JSON.stringify(require("fs").readFileSync(0, "utf8")))')
  [ -n "$pid" ] && extra=",\"prompt_id\":\"$pid\""
  bash "$(kern_root)/hooks/prompt-submit" <<<"$(payload UserPromptSubmit "\"prompt\":$esc$extra")" >/dev/null
}
st() { sed -n "s/^$1: //p" "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"; }
# decide CMD [AGENT]: the dispatcher's decision for the Bash command CMD, from a subagent when AGENT is set.
decide() {
  local extra=""
  [ -n "${2-}" ] && extra=",\"agent_type\":\"$2\""
  run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}$extra")"
  decision_of "$output"
}
# expand NAME ARGS PROMPT_ID: one UserPromptExpansion run of prompt-submit for the typed /NAME ARGS.
expand() {
  bash "$(kern_root)/hooks/prompt-submit" <<<"$(payload UserPromptExpansion "\"expansion_type\":\"slash_command\",\"command_name\":\"$1\",\"command_args\":\"$2\",\"command_source\":\"plugin\",\"prompt\":\"/$1 $2\",\"prompt_id\":\"$3\"")" >/dev/null
}
# decide_with CMD FIELDS: as decide, with FIELDS (such as ,"prompt_id":"p1") added to the PreToolUse input.
decide_with() {
  run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}$2")"
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
  [ "$(c 'update the PR')" = "pr-edit" ]
  [ "$(c 'update the PR body')" = "pr-body" ]
  [ "$(c 'edit the pull request description')" = "pr-body" ]
  [ "$(c 'update the PR title')" = "pr-title" ]
  [ "$(c 'update the PR title and update the PR body')" = "pr-title pr-body" ]
  [ "$(c '/kern:commit src/sum.js')" = "commit" ]
  # The pilot's own PR phrase (MA-254): the grammar is closed, so the user types "open draft PR".
  [ -z "$(c 'open draft PR, no split')" ]
  for p in proceed yes 2 "commit?" "don't commit" "commit and push after the tests pass" "looks good, commit and push" \
    "<ci-monitor-event>commit</ci-monitor-event>" "ship it" "update the PR base"; do
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

@test "a prompt whose run stops early (kern off for its cwd) still clears the last prompt's consent" {
  submit "commit"
  [ "$(st consent)" = commit ]
  R2="$BATS_TEST_TMPDIR/other"
  make_repo "$R2"
  mkdir -p "$R2/.claude"
  printf 'kern: off\n' >"$R2/.claude/kern.local.yml"
  CWD="$R2"
  submit "thanks, now look at the other repo's README" p2
  CWD="$R"
  [ -z "$(st consent)" ]
  [ "$(decide "git commit -m 'fix: sum adds'")" = ask ]
}

@test "consent counts only for the prompt that gave it, when the call names its prompt_id" {
  submit "commit" p1
  [ "$(st consent_prompt)" = p1 ]
  [ "$(decide_with "git commit -m 'fix: sum adds'" ',"prompt_id":"p1"')" = allow ]
  [ "$(decide_with "git commit -m 'fix: sum adds'" ',"prompt_id":"p2"')" = ask ]
  # A call with no prompt_id relies on the clear as each prompt's run starts.
  [ "$(decide "git commit -m 'fix: sum adds'")" = allow ]
}

@test "consent with an empty consent_prompt gives none" {
  submit "commit" ""
  [ "$(st consent)" = commit ]
  [ -z "$(st consent_prompt)" ]
  [ "$(decide_with "git commit -m 'fix: sum adds'" ',"prompt_id":"p1"')" = ask ]
  [ "$(decide "git commit -m 'fix: sum adds'")" = ask ]
  # A prompt_id that holds anything but letters, digits and dashes is stored empty.
  submit "commit" 'p1 x'
  [ -z "$(st consent_prompt)" ]
  [ "$(decide_with "git commit -m 'fix: sum adds'" ',"prompt_id":"p1 x"')" = ask ]
}

@test "an expansion with no submit before it clears consent; one that follows its own submit keeps it" {
  # A typed command can fire UserPromptExpansion alone (exec trace of 2026-10-24: /kern:autopilot on).
  submit "commit" p1
  expand kern:finish-branch "" p2
  [ -z "$(st consent)" ]
  [ "$(decide "git commit -m 'fix: sum adds'")" = ask ]
  submit "commit" p3
  expand kern:finish-branch "" ""
  [ -z "$(st consent)" ]
  # A submit and its expansion share a prompt_id, so /kern:commit keeps the consent its submit gave.
  submit "/kern:commit src/sum.js" p4
  expand kern:commit src/sum.js p4
  [ "$(st consent)" = commit ]
  [ "$(decide_with "git commit -m 'fix: sum adds'" ',"prompt_id":"p4"')" = allow ]
}

@test "consent_key is git's blob id of the root; an empty root or a failed hash gives no consent" {
  . "$(kern_root)/hooks/lib/settings.sh"
  . "$(kern_root)/hooks/lib/state.sh"
  local main
  main=$(kern_main_root "$R")
  [ "$(consent_key "$main")" = "$(printf '%s' "$main" | git -C "$main" hash-object --stdin)" ]
  run consent_key ""
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  submit "commit"
  [ "$(st consent_repo)" = "$(consent_key "$main")" ]
  read_fails git '*hash-object*'
  submit "commit" p2
  [ "$(read_failures git)" -ge 1 ]
  [ -z "$(st consent_repo)" ]
  [ "$(decide "git commit -m 'fix: sum adds'")" = ask ]
}

@test "consent typed in one repository allows nothing in another" {
  submit "commit and push"
  [ -n "$(st consent_repo)" ]
  R2="$BATS_TEST_TMPDIR/other"
  make_repo "$R2"
  git -C "$R2" switch -q -c topic
  CWD="$R2"
  [ "$(decide "git commit -m 'fix: sum adds'")" = ask ]
  [ "$(decide "git push -u origin topic")" = ask ]
  submit "commit and push" p2
  [ "$(decide "git commit -m 'fix: sum adds'")" = allow ]
}

@test "a call with an agent_id and no agent_type is a subagent's: G5 asks" {
  submit "commit"
  [ "$(decide "git commit -m 'fix: sum adds'")" = allow ]
  [ "$(decide_with "git commit -m 'fix: sum adds'" ',"agent_id":"a1"')" = ask ]
}

@test "G1: push consent covers the branch's upstream remote, or origin, never a remote Claude added" {
  submit "push"
  [ "$(decide "git push -u origin feat")" = allow ]
  git init -q --bare "$BATS_TEST_TMPDIR/evil.git"
  git -C "$R" remote add evil "$BATS_TEST_TMPDIR/evil.git"
  [ "$(decide "git push -u evil feat")" = ask ]
  # G6 asks there too (the history is on origin already), so G1's own vote is read alone.
  run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push -u evil feat\"}")" g01
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *"kern G1: push feat"* ]] || false
  run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push -u origin feat\"}")" g01
  [ "$(decision_of "$output")" = allow ]
}

@test "G2: each PR edit phrase allows only the options it names; a bare gh pr edit asks" {
  submit "update the PR title"
  [ "$(decide "gh pr edit --title y")" = allow ]
  [ "$(decide "gh pr edit --body-file b.md")" = ask ]
  [ "$(decide "gh pr edit --title y --body-file b.md")" = ask ]
  submit "update the PR description"
  [ "$(decide "gh pr edit --body-file b.md")" = allow ]
  [ "$(decide "gh pr edit --title y")" = ask ]
  submit "update the PR"
  [ "$(decide "gh pr edit --title y --body-file b.md")" = allow ]
  [ "$(decide "gh pr edit --title y")" = allow ]
  [ "$(decide "gh pr edit")" = ask ]
  [ "$(decide "gh pr edit --body-file missing.md")" = ask ]
}

@test "each reply finish-branch's menu asks for is that option's consent; a digit or a size answer is none" {
  # Pilot fix plan 2, Task 2 (MA-254 round 2): the user's "One" gave no consent, and 8 asks followed.
  . "$(kern_root)/hooks/lib/settings.sh"
  . "$(kern_root)/hooks/lib/state.sh"
  c() { printf '%s\n' "$1" | prompt_consent; }
  menu=$(grep '^7\. Show the menu' "$(kern_root)/skills/finish-branch/SKILL.md")
  for r in 'commit' 'commit and push' 'commit, push and open a draft PR' 'keep'; do
    [[ "$menu" == *"\`$r\`"* ]] || { echo "the menu lacks the reply: $r"; return 1; }
  done
  [ "$(c 'commit')" = "commit" ]
  [ "$(c 'commit and push')" = "commit push" ]
  [ "$(c 'commit, push and open a draft PR')" = "commit push pr" ]
  for p in 1 2 3 4 keep One 'one PR' split; do
    [ -z "$(c "$p")" ] || { echo "consent from: $p"; return 1; }
  done
}
