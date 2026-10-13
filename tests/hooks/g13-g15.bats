#!/usr/bin/env bats
# G13 protected targets, G14 tracker and chat writes, G15 deploy and publish.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  mkdir -p "$R/.claude"
  kern_env "$R"
}

g() { run_guard "$(bash_payload "$1")" "$2"; }
mcp() { run_guard "$(payload PreToolUse "\"tool_name\":\"$1\",\"tool_input\":{}")" g14; }
# mcpi TOOL FIELDS: G14 on an MCP call whose tool_input holds FIELDS (passed without braces).
mcpi() { run_guard "$(tool_payload "$1" "$2")" g14; }

@test "G13: inactive until protected_targets is set" {
  g "scp a.txt v1-host:/data/" g13
  [ "$(decision_of "$output")" = none ]
}

@test "G13: a copy to the target is denied; a copy from it is not" {
  printf 'protected_targets: v1-host, prod-db.internal\n' >"$R/.claude/kern.local.yml"
  g "scp a.txt v1-host:/data/" g13
  [ "$(decision_of "$output")" = deny ]
  g "scp v1-host:/data/a.txt ." g13
  [ "$(decision_of "$output")" = none ]
}

@test "G13: mutating SQL against the target is denied; SELECT is not" {
  printf 'protected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  g "psql -h prod-db.internal -c 'UPDATE users SET a=1'" g13
  [ "$(decision_of "$output")" = deny ]
  g "psql -h prod-db.internal -c 'SELECT count(*) FROM users'" g13
  [ "$(decision_of "$output")" = none ]
  printf 'DELETE FROM users;\n' >"$R/fix.sql"
  g "psql -h prod-db.internal -f fix.sql" g13
  [ "$(decision_of "$output")" = deny ]
}

@test "G13: a write over ssh to the target is denied in both modes" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g "ssh v1-host 'rm -f /data/x'" g13
  [ "$(decision_of "$output")" = deny ]
  set_autopilot on
  g "ssh v1-host 'rm -f /data/x'" g13
  [ "$(decision_of "$output")" = deny ]
}

@test "G14: a tracker write asks, a read does not vote, autopilot denies" {
  mcp mcp__claude_ai_Linear__save_issue
  [ "$(decision_of "$output")" = ask ]
  mcp mcp__claude_ai_Linear__get_issue
  [ "$(decision_of "$output")" = none ]
  set_autopilot on
  mcp mcp__claude_ai_Linear__save_comment
  [ "$(decision_of "$output")" = deny ]
}

@test "G14: tracker.policy auto allows tracker writes but never chat messages" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  mcp mcp__claude_ai_Linear__save_issue
  [ "$(decision_of "$output")" = allow ]
  mcp mcp__claude_ai_Slack__send_message
  [ "$(decision_of "$output")" = ask ]
}

@test "G14: mcp.write_servers adds a server; gh issue writes ask" {
  printf 'mcp.write_servers: youtrack\n' >"$R/.claude/kern.local.yml"
  mcp mcp__youtrack__update_issue
  [ "$(decision_of "$output")" = ask ]
  g "gh issue comment 5 --body-file c.md" g14
  [ "$(decision_of "$output")" = ask ]
  g "gh issue view 5" g14
  [ "$(decision_of "$output")" = none ]
}

@test "G15: deploys and publishes ask, denied under autopilot" {
  for c in "gh workflow run deploy.yml --ref main" "npm publish" "terraform apply -auto-approve" "kubectl rollout restart deploy/api" "helm upgrade api ./chart" "aws ecs update-service --cluster c --service s"; do
    g "$c" g15
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
  set_autopilot on
  g "npm publish" g15
  [ "$(decision_of "$output")" = deny ]
}

@test "G15: read-only infra commands do not vote" {
  for c in "terraform plan" "kubectl get pods" "gh workflow list" "npm test"; do
    g "$c" g15
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
}

@test "G15: a push to a deploy.envs branch asks" {
  printf 'deploy.envs: production, uat\n' >"$R/.claude/kern.local.yml"
  g "git push origin HEAD:production" g15
  [ "$(decision_of "$output")" = ask ]
  g "git push origin feat" g15
  [ "$(decision_of "$output")" = none ]
}

@test "G14: tracker.policy auto allows a gh issue or label write only in a proven shape" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  printf 'Body\n' >"$R/c.md"
  for c in "gh issue comment 5 --body-file c.md" "gh issue close 5 --reason completed | tail -n 1" "gh label create bug --color ff0000 >/dev/null"; do
    g "$c" g14
    [ "$(decision_of "$output")" = allow ] || { echo "$c -> $output"; return 1; }
  done
  for c in "gh issue comment 5 --body-file c.md && rm -rf x" "rm -rf x; gh issue close 5" "gh issue create -R o/r --title x" "gh --repo=o/r issue close 5" "GH_REPO=o/r gh issue close 5" "export GH_REPO=o/r; gh issue close 5" "cd /tmp && gh issue close 5" "gh issue close 5 > out.txt" "gh issue edit 5 --title \$(id)" "gh issue comment 5 --body-file /etc/hosts" "gh issue comment https://github.com/o/r/issues/1 --body-file c.md" "gh issue create --title x --web" "gh issue transfer 5 o/r"; do
    g "$c" g14
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
  set_autopilot on
  g "gh issue comment 5 --body-file c.md" g14
  [ "$(decision_of "$output")" = deny ]
}

@test "G15: a push from a detached HEAD asks when deploy.envs is set, denied under autopilot" {
  git -C "$R" switch -q --detach
  g "git push" g15
  [ "$(decision_of "$output")" = none ]
  printf 'deploy.envs: production\n' >"$R/.claude/kern.local.yml"
  for c in "git push" "git push origin" "git push origin HEAD"; do
    g "$c" g15
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
  set_autopilot on
  g "git push" g15
  [ "$(decision_of "$output")" = deny ]
}

@test "G15: a push of every branch or a pattern asks when deploy.envs is set, denied under autopilot" {
  g "git push --all origin" g15
  [ "$(decision_of "$output")" = none ]
  printf 'deploy.envs: production\n' >"$R/.claude/kern.local.yml"
  for c in "git push --all origin" "git push --branches origin" "git push --mirror origin" "git push origin refs/heads/*:refs/heads/*"; do
    g "$c" g15
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
  set_autopilot on
  g "git push --all origin" g15
  [ "$(decision_of "$output")" = deny ]
}

@test "G14: tracker.policy auto allows only a family's listed tools, the family matched as a server token" {
  printf 'tracker.policy: auto\nmcp.write_servers: youtrack\n' >"$R/.claude/kern.local.yml"
  for t in mcp__claude_ai_Linear__save_comment mcp__plugin_engineering_linear__save_issue mcp__claude_ai_Notion__notion-create-comment; do
    mcp "$t"
    [ "$(decision_of "$output")" = allow ] || { echo "$t -> $output"; return 1; }
  done
  for t in mcp__github__merge_pull_request mcp__claude_ai_Linear__merge_diff mcp__claude_ai_Linear__delete_comment mcp__gitlab__delete_issue mcp__claude_ai_Linear__share_issue mcp__github__create_gist mcp__github__assign_copilot_to_issue mcp__github__create_or_update_file mcp__gitlab__create_issue mcp__atlassian__jira_create_issue mcp__youtrack__update_issue mcp__mylinearish__save_issue mcp__claude_ai_Linear__SAVE_ISSUE mcp__github__x__create_issue; do
    mcp "$t"
    [ "$(decision_of "$output")" = ask ] || { echo "$t -> $output"; return 1; }
  done
}

@test "G14: camelCase names and push, run, retry, play, fork, schedule, duplicate, restore and unshare are writes" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  for t in mcp__claude_ai_Atlassian__createJiraIssue mcp__claude_ai_Atlassian__addCommentToJiraIssue mcp__github__push_files mcp__github__run_workflow mcp__github__rerun_failed_jobs mcp__gitlab__retry_pipeline mcp__gitlab__play_pipeline_job mcp__github__fork_repository mcp__claude_ai_Slack__slack_schedule_message mcp__claude_ai_Notion__notion-duplicate-page mcp__claude_ai_Notion__notion-restore-pages mcp__claude_ai_Linear__unshare_issue mcp__github__reOpen_issue; do
    mcp "$t"
    [ "$(decision_of "$output")" = ask ] || { echo "$t -> $output"; return 1; }
  done
  mcp mcp__claude_ai_Atlassian__getJiraIssue
  [ "$(decision_of "$output")" = none ]
  set_autopilot on
  mcp mcp__claude_ai_Atlassian__createJiraIssue
  [ "$(decision_of "$output")" = deny ]
}

@test "G14: gh issue new is create; deletes, develop, pin, unpin, unlock and label clone ask under tracker.policy auto" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  printf 'Body\n' >"$R/c.md"
  g "gh issue new --title x --body-file c.md" g14
  [ "$(decision_of "$output")" = allow ]
  for c in "gh issue new -R o/r --title x" "gh issue delete 5 --yes" "gh label delete bug --yes" "gh issue develop 5 --checkout" "gh issue pin 5" "gh issue unpin 5" "gh issue unlock 5" "gh label clone o/r --force"; do
    g "$c" g14
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
  set_autopilot on
  g "gh issue pin 5" g14
  [ "$(decision_of "$output")" = deny ]
}

@test "G14: a gh write still votes when gh is in another case, a path or split by quotes" {
  for c in "GH issue close 5" "/usr/bin/gh issue close 5" "g''h issue close 5"; do
    g "$c" g14
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
}

@test "G14: every github MCP write asks under tracker.policy auto, whatever its arguments" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  git -C "$R" remote set-url origin https://github.com/o/r.git
  for c in 'mcp__github__add_issue_comment|"owner":"o","repo":"r","issue_number":1,"body":"hi"' \
    'mcp__github__add_issue_comment|"owner":"torvalds","repo":"linux","issue_number":1,"body":"hi"' \
    'mcp__github__label_write|"method":"delete","owner":"o","repo":"r","name":"bug"' \
    'mcp__github__issue_write|"method":"create","owner":"o","repo":"r","title":"x","assignees":["copilot-swe-agent"]' \
    'mcp__claude_ai_GitHub__create_issue|"owner":"o","repo":"r","title":"x"'; do
    mcpi "${c%%|*}" "${c#*|}"
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
  set_autopilot on
  mcpi mcp__github__add_issue_comment '"owner":"o","repo":"r","issue_number":1,"body":"hi"'
  [ "$(decision_of "$output")" = deny ]
}

@test "G14: Linear save_issue asks under auto when it sets a delegate, an assignee, or a team on an update" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  for f in '"team":"Eng","title":"x"' '"id":"LIN-1","title":"y"'; do
    mcpi mcp__claude_ai_Linear__save_issue "$f"
    [ "$(decision_of "$output")" = allow ] || { echo "$f -> $output"; return 1; }
  done
  mcpi mcp__claude_ai_Linear__save_comment '"issueId":"LIN-1","body":"x"'
  [ "$(decision_of "$output")" = allow ]
  for f in '"id":"LIN-1","delegate":"Copilot"' '"id":"LIN-1","delegate":null' '"id":"LIN-1","assignee":"me"' '"team":"Eng","title":"x","assignee":"alice"' '"id":"LIN-1","team":"Other"' '"\u0064elegate":"Copilot","title":"x"'; do
    mcpi mcp__claude_ai_Linear__save_issue "$f"
    [ "$(decision_of "$output")" = ask ] || { echo "$f -> $output"; return 1; }
  done
}

@test "G14: an action whose first word is a read verb never votes" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  for ap in off on; do
    set_autopilot "$ap"
    for t in mcp__github__get_workflow_run mcp__github__download_workflow_run_artifact mcp__github__list_workflow_run_artifacts mcp__github__get_pull_request mcp__github__pull_request_read mcp__claude_ai_Atlassian__getJiraIssue; do
      mcp "$t"
      [ "$(decision_of "$output")" = none ] || { echo "$ap $t -> $output"; return 1; }
    done
  done
}

@test "G14: copilot, dismiss, manage, star, unstar, cancel, spawn, stop and convert are writes" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  for t in mcp__github__request_copilot_review mcp__github__dismiss_notification mcp__github__manage_notification_subscription mcp__github__star_repository mcp__github__unstar_repository mcp__gitlab__cancel_pipeline mcp__claude_ai_Notion__notion-spawn-session mcp__claude_ai_Notion__notion-stop-session mcp__claude_ai_Notion__notion-convert-page-to-skill; do
    mcp "$t"
    [ "$(decision_of "$output")" = ask ] || { echo "$t -> $output"; return 1; }
  done
  set_autopilot on
  mcp mcp__github__request_copilot_review
  [ "$(decision_of "$output")" = deny ]
}
