### Task 13: G13 protected targets, G14 tracker and chat writes, G15 deploy and publish

**Files:**
- Create: `hooks/guards/g13-protected.sh`, `hooks/guards/g14-tracker.sh`, `hooks/guards/g15-deploy.sh`
- Test: `tests/hooks/g13-g15.bats`

**Interfaces:**
- Consumes: `git_words`, `cmd_head`, `gh_sub`, `git_sub`, `push_targets`, `list_has`, `policy_for tracker`, `settings_get protected_targets|mcp.write_servers|deploy.envs`.
- Produces: `guard_g13`, `guard_g14`, `guard_g15`. G13 (inactive until `protected_targets` is set): `scp` or `rsync` whose destination names a target, `sftp` write verbs, write commands over `ssh` to a target, and mutating SQL in the command or in a `-f`/`--file`/`<` SQL file are denied in both modes. G14: MCP tools on tracker servers (built-in list plus `mcp.write_servers`) whose action has a write verb follow `tracker.policy`; chat servers always ask (messaging people is a floor action); `gh issue` and `gh label` writes follow `tracker.policy`; all are denied under autopilot. G15: workflow runs, releases, package publishes, infrastructure applies and deploy commands (`KERN_G15_RE`), and pushes to a `deploy.envs` branch, ask, deny under autopilot; no policy key loosens them.

- [ ] **Step 1: Write the failing test**

`tests/hooks/g13-g15.bats`:
```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run-bats tests/hooks/g13-g15.bats`
Expected: FAIL; vote cases get `none`.

- [ ] **Step 3: Write `hooks/guards/g13-protected.sh`**

```bash
# shellcheck shell=bash
# G13 protected targets: no copies to, and no mutating SQL against, anything in protected_targets.
# Reading (SELECT, scp from the target, sftp get) stays allowed.

guard_g13() {
  [ "$TOOL" = Bash ] || return 0
  local list cmd seg rest target
  list=$(settings_get protected_targets '')
  [ -n "$list" ] || return 0
  cmd=$(ti_get command) || return 0
  rest="$list,"
  while [ -n "$rest" ]; do
    target=${rest%%,*}
    rest=${rest#*,}
    target=$(printf '%s' "$target" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$target" ] || continue
    case "$cmd" in *"$target"*) ;; *) continue ;; esac
    while IFS= read -r seg; do
      _g13_segment "$seg" "$target"
    done <<EOT
$(git_words "$cmd")
EOT
    _g13_sql "$cmd" "$target"
  done
}

_g13_segment() {
  local seg="$1" target="$2" head last
  head=$(cmd_head "$seg")
  case "${head%% *}" in
    scp | rsync)
      last=$(_shell_words "$seg" | tail -n 1)
      case "$last" in *"$target"*) vote deny G13 "copy to protected target $target" ;; esac
      ;;
    sftp)
      printf '%s\n' "$seg" | grep -Eiq '(^|[^a-z])(put|rm|rename|mkdir|rmdir|chmod)[[:space:]]' &&
        vote deny G13 "sftp write to protected target $target"
      ;;
    ssh)
      case "$seg" in *"$target"*) ;; *) return 0 ;; esac
      _shell_words "$seg" | paste -sd ' ' - | grep -Eq '(^|[[:space:];])(rm|mv|cp|del|copy|move|rename|mkdir|rmdir|touch|tee|chmod|chown|systemctl|service|kill)([[:space:];]|$)|>' &&
        vote deny G13 "write command over ssh to protected target $target"
      ;;
  esac
}

# _g13_sql CMD TARGET: mutating SQL in the command, or in a file it feeds with -f, --file or <.
_g13_sql() {
  local cmd="$1" target="$2" text f
  text="$cmd"
  for f in $(printf '%s\n' "$cmd" | grep -Eo '(-f|--file=?|<)[[:space:]]*[^[:space:];|&]+\.sql' | sed -E 's/^(-f|--file=?|<)[[:space:]]*//'); do
    case "$f" in /*) ;; *) f="$CWD/$f" ;; esac
    [ -f "$f" ] && text="$text
$(cat "$f")"
  done
  printf '%s\n' "$text" | grep -Eiq '(^|[^a-z_])(insert[[:space:]]+into|update[[:space:]]+[a-z_."`]+[[:space:]]+set|delete[[:space:]]+from|drop[[:space:]]+(table|database|schema|index|view)|alter[[:space:]]+(table|database|schema)|truncate|create[[:space:]]+(table|database|schema|index)|grant[[:space:]]|revoke[[:space:]]|lock[[:space:]]+tables|set[[:space:]]+global|kill[[:space:]]+[0-9])' &&
    vote deny G13 "mutating SQL against protected target $target"
  return 0
}
```

- [ ] **Step 4: Write `hooks/guards/g14-tracker.sh`**

```bash
# shellcheck shell=bash
# G14 tracker and chat writes: MCP write tools on tracker or chat servers, and gh issue writes.
# Chat messages are a floor action (messaging people): tracker.policy never makes them auto.

KERN_G14_TRACKERS="linear jira atlassian asana github gitlab notion monday clickup todoist trello shortcut height zendesk"
KERN_G14_CHAT="slack gmail discord teams intercom front mail telegram whatsapp"
KERN_G14_VERBS="create save update delete remove comment post send merge transition move assign archive edit write add set upload submit resolve share invite publish label close reopen mark reply"

guard_g14() {
  case "$TOOL" in
    mcp__*) _g14_mcp ;;
    Bash) _g14_gh ;;
  esac
}

_g14_has_word() {
  local w
  for w in $2; do
    case "$1" in *"$w"*) return 0 ;; esac
  done
  return 1
}

_g14_mcp() {
  local server action kind="" extra
  server=$(printf '%s' "${TOOL#mcp__}" | sed 's/__.*//' | tr '[:upper:]' '[:lower:]')
  action=$(printf '%s' "${TOOL##*__}" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
  _g14_has_word "$server" "$KERN_G14_CHAT" && kind=chat
  [ -z "$kind" ] && _g14_has_word "$server" "$KERN_G14_TRACKERS" && kind=tracker
  extra=$(settings_get mcp.write_servers '' | tr '[:upper:]' '[:lower:]' | tr ',' ' ')
  [ -z "$kind" ] && [ -n "$extra" ] && _g14_has_word "$server" "$extra" && kind=tracker
  [ -n "$kind" ] || return 0
  _g14_is_write "$action" || return 0
  _g14_decide "$kind" "$TOOL"
}

# _g14_is_write ACTION: any `_`-separated word of ACTION is a write verb.
_g14_is_write() {
  local part
  for part in $(printf '%s' "$1" | tr '_' ' '); do
    case " $KERN_G14_VERBS " in *" $part "*) return 0 ;; esac
  done
  return 1
}

_g14_decide() {
  if [ "$AUTOPILOT" = 1 ]; then
    vote deny G14 "$2 under autopilot: tracker and chat writes stay human"
    return 0
  fi
  if [ "$1" = chat ]; then
    vote ask G14 "$2 sends a message to people"
    return 0
  fi
  case "$(policy_for tracker)" in
    auto) vote allow G14 "tracker.policy auto: $2" ;;
    deny) vote deny G14 "tracker.policy deny" ;;
    *) vote ask G14 "$2 writes to the tracker" ;;
  esac
}

_g14_gh() {
  local cmd seg
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    case "$(gh_sub "$seg")" in
      "issue create" | "issue comment" | "issue edit" | "issue close" | "issue reopen" | "issue delete" | "issue transfer" | "issue lock" | "label create" | "label edit" | "label delete")
        _g14_decide tracker "gh $(gh_sub "$seg")"
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}
```

- [ ] **Step 5: Write `hooks/guards/g15-deploy.sh`**

```bash
# shellcheck shell=bash
# G15 deploy and publish: workflow runs, releases, package publishes, infra applies, deploy-branch pushes.

KERN_G15_RE='^(gh (workflow run|release (create|upload|edit|delete))|(npm|pnpm|yarn( npm)?|bun) publish|cargo publish|twine upload|gem push|poetry publish|docker (push|buildx build .*--push)|(terraform|tofu) (apply|destroy|import)|pulumi (up|destroy)|cdk (deploy|destroy)|kubectl (apply|create|delete|replace|patch|rollout|scale|set|edit|annotate|label)|helm (install|upgrade|uninstall|rollback)|(serverless|sls) (deploy|remove)|vercel( .*)? (--prod|deploy)|fly (deploy|apps destroy)|firebase deploy|eb deploy|aws (ecs update-service|lambda update-function-code|cloudformation (deploy|create-stack|update-stack|delete-stack)|s3 (sync|cp|rm|mv) .*s3://))'

guard_g15() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg words parsed dir rest sub t envs
  cmd=$(ti_get command) || return 0
  envs=$(settings_get deploy.envs '')
  while IFS= read -r seg; do
    words=$(_shell_words "$seg" | awk '!s && /^[A-Za-z_][A-Za-z0-9_]*=/ { next } !s && /^(command|exec|time|nohup|sudo|npx)$/ { next } { s = 1; print }' | paste -sd ' ' -)
    if printf '%s\n' "$words" | grep -Eq -- "$KERN_G15_RE"; then
      _g15_vote "$(printf '%s' "$words" | cut -c1-60)"
      continue
    fi
    [ -n "$envs" ] || continue
    parsed=$(git_sub "$seg") || continue
    dir=${parsed%%	*}
    rest=${parsed#*	}
    sub=${rest%%	*}
    rest=${rest#*	}
    [ "$sub" = push ] || continue
    while IFS= read -r t; do
      [ -n "$t" ] && list_has "$envs" "$t" && _g15_vote "push to deploy branch $t"
    done <<EOT
$(push_targets "$dir" "$rest")
EOT
  done <<EOT
$(git_words "$cmd")
EOT
}

_g15_vote() {
  vote ask G15 "deploy or publish: $1"
  [ "$AUTOPILOT" = 1 ] && vote deny G15 "deploy or publish under autopilot: $1"
  return 0
}
```

- [ ] **Step 6: Run every hook test**

Run: `tests/run-bats tests/hooks tests/scripts`
Expected: every file passes; payload tests may skip.

- [ ] **Step 7: Time one Bash call through all guards**

Run: `P='{"session_id":"t","cwd":"'"$PWD"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm test && git status"}}'; time (printf '%s' "$P" | bash hooks/pre-tool-use)`
Expected: `real` under 1 s and no output (no guard votes).

- [ ] **Step 8: Commit**

```bash
git add -- hooks/guards/g13-protected.sh hooks/guards/g14-tracker.sh hooks/guards/g15-deploy.sh tests/hooks/g13-g15.bats
git commit -m "M1: add G13, G14 and G15 for protected targets, trackers and deploys" -m "Writes to read-only systems, tracker and chat writes, and deploys are outward actions the user approves; G13 had no milestone in the spec."
```

---

