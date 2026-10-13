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
