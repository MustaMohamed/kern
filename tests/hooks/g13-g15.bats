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
# gx CMD: G13 on CMD, which may hold double quotes, backslashes and newlines.
gx() {
  local esc
  esc=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }')
  run_guard "$(bash_payload "$esc")" g13
}
# g13_all DECISION CMD...: G13 decides DECISION on every CMD.
g13_all() {
  local want="$1" c
  shift
  for c in "$@"; do
    gx "$c"
    [ "$(decision_of "$output")" = "$want" ] || { echo "$c -> $output"; return 1; }
  done
}

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

@test "G13: an ssh remote command off the read list is denied, Windows and PowerShell included" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "ssh v1-host 'DEL C:\data\x'" "ssh v1-host 'ren C:\data\x y'" "ssh v1-host 'perl app2020arcp.pl'" \
    "ssh v1-host 'sed -i s/a/b/ /data/x'" "ssh v1-host 'net stop mysql'" "ssh v1-host 'taskkill /im perl.exe'" \
    "ssh v1-host 'powershell -c Remove-Item C:\data\x'" "ssh v1-host 'powershell -c Set-Content C:\data\x hi'" \
    "ssh v1-host 'powershell -NoProfile -Command \"Get-Item C:\x | Remove-Item\"'" \
    "ssh v1-host 'powershell -Command (Get-Item C:\x).Delete()'" "ssh v1-host 'powershell -EncodedCommand ZABpAHIA'" \
    "ssh v1-host 'cmd /c \"dir C:\data && del C:\data\x\"'" "ssh v1-host 'dir C:\data & del C:\data\x'" \
    "ssh v1-host 'ls /data; rm -f /data/x'" "ssh v1-host 'cat /data/x > /data/y'" "ssh v1-host 'ls \$(rm -f /data/x)'" \
    "ssh v1-host 'find /data -name x -delete'" "ssh v1-host 'find /data -exec rm {} +'" "ssh v1-host 'date -s 2020-01-01'" \
    "ssh v1-host 'hostname newname'" "ssh v1-host 'ls -la | xargs rm'"
  set_autopilot on
  g13_all deny "ssh v1-host 'DEL C:\data\x'"
}

@test "G13: ssh to a target names it in any case, as user@host, a URL, a jump or a HostName option" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "ssh admin@v1-host 'rm -f /data/x'" "ssh ssh://admin@v1-host:22 'rm -f /data/x'" \
    "ssh -p 22 V1-HOST 'rm -f /data/x'" "ssh v1-host -t 'rm -f /data/x'" "ssh -o RemoteCommand='rm -f /data/x' v1-host" \
    "ssh -J v1-host localhost 'rm -f /data/x'" "ssh -o HostName=v1-host alias 'rm -f /data/x'" \
    "ssh -o ProxyCommand='ssh v1-host rm -f /data/x' other ls"
}

@test "G13: ssh to a target with no remote command, a shell, or input on stdin is denied" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "ssh v1-host" "ssh -t v1-host bash" "ssh v1-host bash < fix.sh" "ssh v1-host 'bash -s' < fix.sh" \
    "ssh v1-host < fix.sh" "cat fix.sh | ssh v1-host bash" "cat fix.sh | ssh v1-host 'cat /data/x'" \
    "ssh v1-host cat <<< 'rm -f /data/x'" "ssh v1-host cmd" "ssh v1-host 'cmd /k'" "ssh v1-host powershell" \
    "ssh v1-host 'powershell -Command -'" "ssh v1-host 'pwsh fix.ps1'" "ssh -s v1-host sftp"
  g13_all deny "ssh v1-host <<'EOF'
rm -f /data/x
EOF"
}

@test "G13: an ssh behind a path, another case, quotes or a wrapper is still read" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "/usr/bin/ssh v1-host 'rm -f /data/x'" "SSH v1-host 'rm -f /data/x'" "s''sh v1-host 'rm -f /data/x'" \
    "caffeinate ssh v1-host 'rm -f /data/x'" "sudo -u admin ssh v1-host 'rm -f /data/x'" \
    "sshpass -p x ssh v1-host 'rm -f /data/x'" "bash -c \"ssh v1-host 'rm -f /data/x'\"" \
    "env -S 'ssh v1-host rm -f /data/x'" "ls && ssh v1-host 'rm -f /data/x' | tail -n 1"
}

@test "G13: ssh reads, tunnels and other hosts get no vote" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all none "ssh v1-host ls 2>/dev/null" "ssh v1-host 'dir C:\data' 2>&1" "ssh v1-host 'cat /data/x' > local.txt" \
    "ssh v1-host 'ls /data/rm-backups'" "ssh v1-host 'ls -la /data | grep x | wc -l'" "ssh v1-host 'type C:\data\x.txt'" \
    "ssh v1-host 'findstr /i error C:\logs\app.log'" "ssh v1-host 'cmd /c dir C:\data'" \
    "ssh v1-host 'powershell -NoProfile -Command \"Get-ChildItem C:\data | Measure-Object\"'" \
    "ssh v1-host 'Get-Content C:\logs\a.log -Tail 20'" "ssh v1-host 'find /data -name x 2>/dev/null'" \
    "ssh v1-host 'hostname; whoami; ver'" "ssh v1-host 'gci C:\data | sls error'" "ssh v1-host 'date +%F'" \
    "ssh -n v1-host ls < fix.sh" "ssh -N -L 3307:localhost:3306 v1-host" "ssh -fN -L 3307:127.0.0.1:3306 admin@v1-host" \
    "ssh -O exit v1-host" "ssh other-host 'rm -f /tmp/x'" "ssh v1-host-2 'rm -f /tmp/x'" \
    "git commit -m 'ssh v1-host is read-only'" "grep -rn 'ssh v1-host' docs"
}

@test "G13: SQL to a target is SELECT, SHOW, DESCRIBE, EXPLAIN or WITH with no write, lock, file or wait" {
  printf 'protected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  g13_all deny "psql -h prod-db.internal -c 'UPDATE users2 SET a=1'" "psql -h prod-db.internal -c 'UPDATE users u SET a=1'" \
    "psql -h prod-db.internal -c 'UPDATE ONLY users SET a=1'" "psql -h prod-db.internal -c 'UPDATE/**/users/**/SET a=1'" \
    "mysql -h prod-db.internal -e 'INSERT users VALUES (1)'" "mysql -h prod-db.internal -e 'REPLACE INTO users VALUES (1)'" \
    "psql -h prod-db.internal -c 'MERGE INTO users USING x ON true WHEN MATCHED THEN DELETE'" \
    "psql -h prod-db.internal -c \"COPY users FROM '/tmp/x.csv'\"" "psql -h prod-db.internal -c 'DROP FUNCTION f()'" \
    "psql -h prod-db.internal -c 'CREATE OR REPLACE VIEW v AS SELECT 1'" "mysql -h prod-db.internal -e 'RENAME TABLE a TO b'" \
    "psql -h prod-db.internal -c 'CALL purge()'" "psql -h prod-db.internal -c 'VACUUM FULL users'" \
    "mysql -h prod-db.internal -e 'KILL QUERY 5'" "mysql -h prod-db.internal -e 'SET PERSIST max_connections=1'" \
    "psql -h prod-db.internal -c 'SELECT pg_terminate_backend(5)'" "psql -h prod-db.internal -c \"SELECT nextval('s')\"" \
    "mysql -h prod-db.internal -e \"SELECT * FROM users INTO OUTFILE '/tmp/x'\"" \
    "mysql -h prod-db.internal -e 'SELECT * FROM users FOR UPDATE'" "psql -h prod-db.internal -c 'SELECT * FROM users FOR SHARE'" \
    "mysql -h prod-db.internal -e 'SELECT * FROM users LOCK IN SHARE MODE'" "mysql -h prod-db.internal -e 'SELECT SLEEP(100)'" \
    "mysql -h prod-db.internal -e 'SELECT BENCHMARK(1000000, MD5(1))'" \
    "psql -h prod-db.internal -c 'WITH d AS (DELETE FROM users RETURNING *) SELECT * FROM d'" \
    "mysql -h prod-db.internal -e 'SELECT 1; DELETE FROM users'" "mysql -h prod-db.internal -e 'SELECT 1 /*!50000 ; DELETE FROM users */'" \
    "mysql -h prod-db.internal -e \"SELECT 'a\\'; DELETE FROM users; -- '\"" \
    "psql -h prod-db.internal -c \"SELECT E'x\\'', 'y\\'; DELETE FROM users; --'\"" \
    "mysql -h prod-db.internal -e 'SELECT 1' --init-command='DELETE FROM users'" \
    "mysql -h prod-db.internal -e 'SELECT 1\\! rm -rf /tmp/x'" "sqlcmd -S prod-db.internal -Q 'SELECT 1 DELETE FROM users'"
}

@test "G13: LOCK TABLES and GET_LOCK against a target are denied in both modes" {
  printf 'protected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  for ap in off on; do
    set_autopilot "$ap"
    g13_all deny "mysql -h prod-db.internal -e 'LOCK TABLES users READ'" "psql -h prod-db.internal -c 'LOCK TABLE users'" \
      "mysql -h prod-db.internal -e \"SELECT GET_LOCK('x', 10)\"" "mysql -h prod-db.internal -e 'UNLOCK TABLES'"
  done
}

@test "G13: SQL reads against a target, and SQL words outside a client, get no vote" {
  printf 'protected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  printf 'SELECT id FROM users;\n-- never DELETE here\nSHOW TABLES;\n' >"$R/read.sql"
  g13_all none "mysql -h prod-db.internal -e 'SHOW GRANTS'" "mysql -h prod-db.internal -e 'SHOW CREATE TABLE users'" \
    "mysql -h prod-db.internal -Nse 'SELECT id FROM users LIMIT 1'" "psql -h prod-db.internal -Atc 'SELECT 1'" \
    "psql -h prod-db.internal -c \"SELECT 'update x set' FROM t\"" \
    "psql -h prod-db.internal -c 'SELECT * FROM users WHERE note = \$\$truncate\$\$'" \
    "mysql -h prod-db.internal -e 'SELECT REPLACE(name, \"a\", \"b\") FROM users; DESCRIBE users; EXPLAIN SELECT 1'" \
    "mysql -h prod-db.internal -e 'SELECT 1 -- DELETE FROM users'" "mysql -h prod-db.internal -e 'SELECT * FROM t\\G'" \
    "psql -h prod-db.internal -c 'WITH x AS (SELECT 1) SELECT * FROM x'" "psql -h prod-db.internal -f read.sql" \
    "mysql -h prod-db.internal < read.sql" "psql -h prod-db.internal -l" "pg_dump -h prod-db.internal -f out.sql appdb" \
    "mysql -h other-db -e 'DELETE FROM users'" "git commit -m 'docs: never DELETE FROM users on prod-db.internal'" \
    "grep -rn 'DROP TABLE' docs/prod-db.internal.md"
}

@test "G13: SQL input G13 cannot read is denied: files of any name, pipes, here-docs, run-time text, none at all" {
  printf 'protected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  printf 'DELETE FROM users;\n' >"$R/fix.txt"
  printf 'DELETE FROM users;\n' >"$R/fix"
  printf 'DELETE FROM users;\n' >"$R/fix.psql"
  printf 'DELETE FROM users;\n' >"$HOME/fix.sql"
  g13_all deny "mysql -h prod-db.internal < fix.txt" "mysql -h prod-db.internal < fix" "mysql -h prod-db.internal <fix.txt" \
    "cat fix.txt | mysql -h prod-db.internal" "psql -h prod-db.internal -f ~/fix.sql" "psql -h prod-db.internal -f fix.psql" \
    "psql -h prod-db.internal -f missing.sql" "mysql -h prod-db.internal <<< 'SELECT 1'" \
    "psql -h prod-db.internal -c \"\$(cat fix.txt)\"" "mysql -h prod-db.internal -e \"SELECT \$(cat fix.txt)\"" \
    "mysql -h prod-db.internal" "caffeinate psql -h prod-db.internal -c 'UPDATE users SET a=1'" \
    "PSQL -h prod-db.internal -c 'UPDATE users SET a=1'" "/usr/bin/mysql -h prod-db.internal -e 'DELETE FROM users'" \
    "PGHOST=prod-db.internal psql -c 'DELETE FROM users'" "mysqladmin -h prod-db.internal shutdown" \
    "pg_restore -h prod-db.internal -d app dump.bin"
  g13_all deny "psql -h prod-db.internal <<'EOF'
DELETE FROM users;
EOF"
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "ssh v1-host \"ls \$(cat names.txt)\""
}

@test "G13: a host:port entry protects a database behind an SSH tunnel" {
  printf 'protected_targets: 127.0.0.1:3307\n' >"$R/.claude/kern.local.yml"
  g13_all deny "mysql -h 127.0.0.1 -P 3307 -e 'DELETE FROM users'" "mysql -h127.0.0.1 -P3307 -e 'DELETE FROM users'" \
    "mysql --host=localhost --port=3307 -e 'DELETE FROM users'" "mysql --host 127.0.0.1 --port 3307 -e 'LOCK TABLES users READ'" \
    "mysql -P 3307 -e 'DELETE FROM users'" "MYSQL_TCP_PORT=3307 mysql -h 127.0.0.1 -e 'DELETE FROM users'" \
    "psql postgresql://u@localhost:3307/app -c 'DELETE FROM users'" \
    "psql 'host=127.0.0.1 port=3307 dbname=app' -c 'DELETE FROM users'"
  g13_all none "mysql -h 127.0.0.1 -P 3306 -e 'DELETE FROM users'" "mysql -h 127.0.0.1 -e 'DELETE FROM users'" \
    "mysql -h 127.0.0.1 -P 3307 -e 'SELECT 1'" "psql -h localhost -p 5432 -c 'DELETE FROM users'"
}

@test "G13: mysqldump of a target needs --single-transaction and no lock option; pg_dump reads" {
  printf 'protected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  g13_all deny "mysqldump -h prod-db.internal app" "mysqldump -h prod-db.internal --single-transaction --lock-tables app" \
    "mysqldump -h prod-db.internal --single-transaction -x app" "mysqldump -h prod-db.internal --single-transaction --master-data=2 app" \
    "mysqldump -h prod-db.internal --single-transaction=0 app"
  g13_all none "mysqldump -h prod-db.internal --single-transaction app > dump.sql" "pg_dump -h prod-db.internal app"
}

@test "G13: sqlite3 votes only when its file is a target" {
  printf 'protected_targets: /srv/prod.db\n' >"$R/.claude/kern.local.yml"
  g13_all deny "sqlite3 /srv/prod.db 'DELETE FROM t'" "sqlite3 /srv/prod.db '.import x.csv t'"
  g13_all none "sqlite3 /srv/prod.db 'SELECT count(*) FROM t'" "sqlite3 dev.db 'DELETE FROM t'"
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
  [[ "$output" == *"mcp__claude_ai_GitHub__create_issue always asks: github MCP writes can name any repo; use gh issue or gh label for a checked write"* ]] || false
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

@test "G14: Linear save_project asks under auto: it moves projects between teams and sets a lead" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  for f in '"id":"P-1","setTeams":["Other"]' '"id":"P-1","addTeams":["Secret"],"leadTeam":"Secret"' '"id":"P-1","removeTeams":["Eng"]' '"id":"P-1","lead":"alice"'; do
    mcpi mcp__claude_ai_Linear__save_project "$f"
    [ "$(decision_of "$output")" = ask ] || { echo "$f -> $output"; return 1; }
  done
}

@test "G14: a read-first name with a strong write verb after it still votes" {
  printf 'tracker.policy: auto\n' >"$R/.claude/kern.local.yml"
  for t in mcp__github__get_or_create_issue mcp__claude_ai_Linear__list_and_close_issues; do
    mcp "$t"
    [ "$(decision_of "$output")" = ask ] || { echo "$t -> $output"; return 1; }
  done
  set_autopilot on
  for t in mcp__github__get_or_create_issue mcp__claude_ai_Linear__list_and_close_issues; do
    mcp "$t"
    [ "$(decision_of "$output")" = deny ] || { echo "$t -> $output"; return 1; }
  done
  for t in mcp__github__get_workflow_run mcp__github__pull_request_read mcp__gitlab__get_merge_request mcp__github__download_workflow_run_artifact; do
    mcp "$t"
    [ "$(decision_of "$output")" = none ] || { echo "$t -> $output"; return 1; }
  done
}
