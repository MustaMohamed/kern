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
# gx CMD [GUARDS]: G13 (or GUARDS; "" runs them all) on CMD, which may hold double quotes, backslashes
# and newlines.
gx() {
  local esc
  esc=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }')
  run_guard "$(bash_payload "$esc")" "${2-g13}"
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
# g15_all DECISION CMD...: G15 decides DECISION on every CMD.
g15_all() {
  local want="$1" c
  shift
  for c in "$@"; do
    gx "$c" g15
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
    "ssh v1-host 'findstr /i error C:\logs\app.log'" "ssh v1-host 'Get-ChildItem C:\data | Measure-Object'" \
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
  printf 'SELECT id FROM users;\nSHOW TABLES;\n' >"$R/read.sql"
  g13_all none "mysql -h prod-db.internal -e 'SHOW GRANTS'" "mysql -h prod-db.internal -e 'SHOW CREATE TABLE users'" \
    "mysql -h prod-db.internal -Nse 'SELECT id FROM users LIMIT 1'" "psql -h prod-db.internal -Atc 'SELECT 1'" \
    "psql -h prod-db.internal -c \"SELECT 'update x set' FROM t\"" \
    "mysql -h prod-db.internal -e \"SELECT REPLACE(name, 'a', 'b') FROM users; DESCRIBE users; EXPLAIN SELECT 1\"" \
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

@test "G13: scp or rsync to a target is denied by its last positional word, in any case or URL form" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "scp a.txt v1-host:/data/ 2>&1" "scp a.txt v1-host:/data/ >/dev/null" "scp a.txt V1-HOST:/data/" \
    "scp a.txt admin@v1-host:/data/" "scp a.txt scp://admin@v1-host:22/data/" "scp -o HostName=v1-host a.txt alias:/data/" \
    "rsync -av a.txt v1-host:/data/" "rsync -av a.txt v1-host:/data/ --progress" "rsync -av a.txt v1-host:/data/ 2>/dev/null" \
    "rsync -av a.txt v1-host:/data/ --exclude x" "rsync -av a.txt rsync://v1-host/mod/" "rsync -av a.txt v1-host::mod/" \
    "rsync -av -e 'ssh -o HostName=v1-host' a.txt alias:/data/"
}

@test "G13: rsync --remove-source-files, --delete or a remote command touching a target is denied" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "rsync -av --remove-source-files v1-host:/data/x ." "rsync -av --delete empty/ v1-host:/data/ >/dev/null" \
    "rsync -av --delete-after v1-host:/data/ ./mirror/" "rsync -av --rsync-path='sudo rsync' v1-host:/data/ ." \
    "rsync -av -M--remove-source-files v1-host:/data/x ."
}

@test "G13: an scp or rsync behind a path, another case or a wrapper is still read" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "/usr/bin/scp a.txt v1-host:/data/" "SCP a.txt v1-host:/data/" "caffeinate scp a.txt v1-host:/data/" \
    "sshpass -p x scp a.txt v1-host:/data/" "xargs -I{} scp {} v1-host:/data/ < list.txt" "nice -n 5 rsync a.txt v1-host:/data/" \
    "ssh bastion 'scp a.txt v1-host:/data/'" "ssh bastion \"ssh v1-host 'rm -f /data/x'\""
}

@test "G13: copies from a target and to other hosts get no vote" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all none "scp v1-host:/data/a.txt ./backup-v1-host/" "scp admin@v1-host:/data/a.txt ." \
    "rsync -av v1-host:/data/ ./v1-host-mirror/" "rsync -av --progress v1-host:/data/ ./mirror/" \
    "scp a.txt other-host:/data/v1-host/" "rsync -av ./v1-host/ /backup/" "ssh bastion 'scp v1-host:/data/a.txt .'" \
    "ssh a \"ssh b 'ssh c ls'\""
}

@test "G13: sftp to a target runs only read verbs, from a batch file, here-doc, here-string or pipe" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  printf 'put a.txt /data/a.txt\n' >"$R/batch.txt"
  printf 'get /data/a.txt .\nls /data\n-cd /data\nbye\n' >"$R/get.txt"
  g13_all deny "sftp -b batch.txt v1-host" "echo 'put a.txt /data/' | sftp v1-host" "sftp v1-host <<< 'put a.txt /data/'" \
    "sftp v1-host <<< 'reput a.txt /data/a.txt'" "sftp v1-host <<< 'ln /data/a /data/b'" "sftp v1-host <<< 'chown 0 /data/a'" \
    "sftp -b - v1-host <<< '!rm x'" "printf 'get a\nrm b\n' | sftp v1-host" "cat batch.txt | sftp v1-host" "sftp v1-host" \
    "sftp -b missing.txt v1-host" "sftp admin@v1-host:/data/ <<< 'put a'" "sftp -b batch.txt sftp://v1-host" \
    "ls | sftp v1-host" "printf 'get a\n' \"\$(echo 'put b')\" | sftp v1-host"
  g13_all deny "sftp v1-host <<'EOF'
put a.txt /data/
EOF" "cat <<'A' >b.txt
get x
A
sftp v1-host <<'B'
put y
B"
  g13_all none "sftp -b get.txt v1-host" "sftp v1-host <<< 'get /data/a.txt'" "echo 'get /data/a.txt' | sftp v1-host" \
    "printf '%s\n' 'get /data/a' 'bye' | sftp v1-host" "sftp -b batch.txt other-host"
  g13_all none "sftp v1-host <<'EOF'
get /data/a.txt
ls
EOF"
}

@test "G13: sqlite3 votes only when its file is a target" {
  printf 'protected_targets: /srv/prod.db\n' >"$R/.claude/kern.local.yml"
  g13_all deny "sqlite3 /srv/prod.db 'DELETE FROM t'" "sqlite3 /srv/prod.db '.import x.csv t'"
  g13_all none "sqlite3 /srv/prod.db 'SELECT count(*) FROM t'" "sqlite3 dev.db 'DELETE FROM t'"
}

@test "G13: autossh and plink are read as ssh; other network clients naming a target are denied" {
  printf 'protected_targets: v1-host, prod-db.internal, 127.0.0.1:3307, /srv/prod.db\n' >"$R/.claude/kern.local.yml"
  g13_all deny "autossh -M 0 v1-host 'del C:\data\x'" "plink -batch v1-host 'del C:\data\x'" \
    "plink -ssh -P 22 -pw x admin@v1-host del C:\data\x" "plink -m fix.txt v1-host" \
    "mycli -h 127.0.0.1 -P 3307 -e 'DELETE FROM t'" "mycli -P 3307 -e 'DELETE FROM t'" \
    "usql mysql://127.0.0.1:3307/db -c 'DELETE FROM t'" "pgcli -h prod-db.internal" "litecli /srv/prod.db" \
    "curl -T a.txt 'smb://v1-host/c\$/data/a.txt'" "smbclient '//v1-host/c\$' -c 'put a.txt'" \
    "mount_smbfs '//admin@v1-host/c\$' /tmp/v1" "lftp -e 'put a.txt' sftp://v1-host" "ftp v1-host" \
    "wget --post-file=a.txt http://v1-host/x" "mosh v1-host" "nc v1-host 3306" "/usr/bin/NC v1-host 3306" \
    "pwsh -c \"Invoke-Command -HostName v1-host -ScriptBlock { Remove-Item C:\x }\"" \
    "powershell -Command \"Enter-PSSession -ComputerName v1-host\"" "ncat v1-host 3306" "netcat v1-host 3306" \
    "telnet v1-host 3306" "sqsh -S prod-db.internal" "isql prod-db.internal"
  g13_all none "autossh -M 0 v1-host 'dir C:\data'" "plink -batch v1-host dir C:\data" "curl https://example.com/v1-host-docs" \
    "pwsh -c \"Get-ChildItem C:\x\"" "pwsh -c \"Invoke-Command -HostName other -ScriptBlock { ls }\"" "nc -z other-host 22" \
    "mycli -h 127.0.0.1 -P 3306 -e 'DELETE FROM t'"
}

@test "G13: loopback spellings and abbreviated long options still reach a host:port target" {
  printf 'protected_targets: 127.0.0.1:3307, prod-db.internal\n' >"$R/.claude/kern.local.yml"
  g13_all deny "mysql -h 0.0.0.0 -P 3307 -e 'DELETE FROM t'" "mysql -h 0 -P 3307 -e 'DELETE FROM t'" \
    "mysql -h 127.1 -P 3307 -e 'DELETE FROM t'" "mysql -h ::ffff:127.0.0.1 -P 3307 -e 'DELETE FROM t'" \
    "mysql --hos=127.0.0.1 --por=3307 -e 'DELETE FROM t'" "mysql -h 127.0.0.1 --po=3307 -e 'DELETE FROM t'" \
    "mysql --ho 127.0.0.1 --por 3307 -e 'DELETE FROM t'" "psql --hos=127.0.0.1 --por=3307 -c 'DELETE FROM t'" \
    "mysql -h 127.0.0.1 -P 3307 -e 'SELECT 1' --exe='DELETE FROM t'" \
    "mysqldump -h prod-db.internal --single-transaction --lock-t app"
  g13_all none "mysql -h 10.0.0.5 -P 3307 -e 'DELETE FROM t'" "mysql -h 127.0.0.1 --po=3306 -e 'DELETE FROM t'"
}

@test "G13: ssh over a shared connection is judged as if on a target" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "ssh -S ~/.ssh/cm-v1 x 'del C:\data\x'" "ssh -o ControlPath=~/.ssh/cm-%r@%h:%p x 'del C:\data\x'" \
    "ssh -o ControlMaster=auto other 'rm -f /tmp/x'" "ssh -S sock x"
  g13_all none "ssh -S ~/.ssh/cm-v1 x 'dir C:\data'" "ssh -S sock -O exit x" "ssh -S none other 'rm -f /tmp/x'"
  printf 'protected_targets: \n' >"$R/.claude/kern.local.yml"
  g13_all none "ssh -S sock x 'rm -f /tmp/x'"
}

@test "G13: a carriage return splits a remote command; another control character denies" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all deny "ssh v1-host 'dir C:\x"$'\r'"Remove-Item C:\x'" "ssh v1-host 'powershell -c dir C:\x\u000dRemove-Item C:\x'" \
    "ssh v1-host 'dir C:\x\u0007'" "ssh v1-host 'dir C:\x"$'\v'"'"
  g13_all none "ssh v1-host 'dir C:\x'"
}

@test "G13: SQL files are read only for a target, and denied above 1 MB" {
  printf 'protected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  awk 'BEGIN { for (i = 0; i < 30000; i++) print "SELECT id, name FROM users WHERE id = " i ";" }' >"$R/big.sql"
  awk 'BEGIN { for (i = 0; i < 1500; i++) print "SELECT id, name FROM users WHERE note = '\''x;y'\'' AND id = " i ";" }' >"$R/mid.sql"
  g13_all deny "mysql -h prod-db.internal < big.sql" "psql -h prod-db.internal -f big.sql"
  [[ "$output" == *"over 1 MB"* ]] || false
  g13_all none "mysql -h prod-db.internal < mid.sql"
  # A FIFO no one writes blocks whoever opens it to read: a call to another host must not open it.
  mkfifo "$R/pipe.sql"
  (gx "psql -h other-db -f pipe.sql" && decision_of "$output" >"$BATS_TEST_TMPDIR/d") &
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -s "$BATS_TEST_TMPDIR/d" ] && break; sleep 0.25; done
  early=$(cat "$BATS_TEST_TMPDIR/d" 2>/dev/null || true)
  # Opening it read-write for one null command releases a reader that is waiting, if any.
  : 7<>"$R/pipe.sql"
  wait
  [ "$early" = none ]
}

@test "G13: a backslash-newline joins words before G13 reads them" {
  printf 'protected_targets: v1-host, 127.0.0.1:3307\n' >"$R/.claude/kern.local.yml"
  g13_all deny "s\\
sh v1-host 'del C:\x'" "echo x\\\\
ssh v1-host 'del C:\x'"
  g13_all none "ssh v1-host \\
  'dir C:\data'" "mysql -h 127.0.0.1 \\
  -P 3307 \\
  -e 'SELECT 1'"
}

@test "G13: PowerShell formatting, Get- cmdlets and property reads are reads; a method call is not" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all none "ssh v1-host 'Get-ChildItem C:\data | Format-Table Name,CreationTime'" \
    "ssh v1-host 'Get-ChildItem C:\data | ft Name; gci C:\x | fl'" \
    "ssh v1-host 'Get-ChildItem C:\data | Format-List'" "ssh v1-host '(Get-Item C:\x).CreationTime'" \
    "ssh v1-host '(Get-Item C:\x).LastWriteTime'" "ssh v1-host 'Get-Service mysql'"
  g13_all deny "ssh v1-host '(Get-Item C:\x).Delete()'" "ssh v1-host '(Get-Item C:\x).Delete ()'" \
    "ssh v1-host '(Get-Item C:\x).CreationTime.ToString()'" \
    "ssh v1-host '(Get-Item C:\x).IsReadOnly = 1'" "ssh v1-host 'Get-Item C:\x | Remove-Item'"
}

@test "G13: one host:path sftp operand is a get from the target" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  g13_all none "sftp v1-host:/data/x.pdf ./" "sftp admin@v1-host:/data/x.pdf" "sftp sftp://v1-host/data/x.pdf"
  g13_all deny "sftp v1-host:" "sftp v1-host:/data/x.pdf <<< 'put a'" "sftp v1-host"
}

@test "G13: a cmd or powershell wrapper in a remote command to a target denies, in both modes" {
  printf 'protected_targets: v1-host\n' >"$R/.claude/kern.local.yml"
  for ap in off on; do
    set_autopilot "$ap"
    g13_all deny "ssh v1-host 'cmd /c dir C:\data'" "ssh v1-host 'powershell -NoProfile -Command \"Get-ChildItem C:\data\"'" \
      "ssh v1-host 'pwsh -c Get-Content C:\x'" "ssh v1-host 'powershell -EncodedCommand ZABpAHIA'" \
      "ssh v1-host 'dir C:\data & cmd /k'" "ssh v1-host 'C:\Windows\System32\cmd.exe /c type C:\x'"
  done
  [[ "$output" == *"run it yourself with !"* ]] || false
  set_autopilot off
  g13_all none "ssh v1-host 'dir C:\data'" "ssh v1-host 'type C:\x.txt'" "ssh v1-host 'findstr /i error C:\logs\a.log'" \
    "ssh v1-host 'Get-ChildItem C:\data | Measure-Object'"
}

@test "G13: SQL to a target that needs more than plain lexing denies, in both modes" {
  printf 'protected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  for ap in off on; do
    set_autopilot "$ap"
    g13_all deny "mysql -h prod-db.internal -e 'SELECT 1 -- x'" "mysql -h prod-db.internal -e 'SELECT 1 # x'" \
      "mysql -h prod-db.internal -e 'SELECT /* x */ 1'" "mysql -h prod-db.internal -e 'SELECT /*!50000 1 */'" \
      "mysql -h prod-db.internal -e 'SELECT * FROM t\\G'" "psql -h prod-db.internal -c 'SELECT \$\$x\$\$'" \
      "psql -h prod-db.internal -c 'SELECT \$q\$x\$q\$'" "psql -h prod-db.internal -c \"SELECT E'x'\"" \
      "mysql -h prod-db.internal -e \"SELECT 'it''s'\"" "mysql -h prod-db.internal -e 'SELECT \"x\"'" \
      "mysql -h prod-db.internal -e \"SELECT 'x\"" "mysql -h prod-db.internal -e 'SELECT \`a\`\`b\` FROM t'" \
      "mysql -h prod-db.internal -e \"SELECT 'a\\b'\""
  done
  set_autopilot off
  g13_all none "mysql -h prod-db.internal -e \"SELECT * FROM t WHERE name = 'x'\"" "mysql -h prod-db.internal -e 'SHOW GRANTS'" \
    "mysql -h prod-db.internal -e 'SELECT \`id\` FROM \`users\`'" "psql -h prod-db.internal -c \"SELECT 'a--b; c#d /* e'\""
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

@test "G15: git in another case or by path still pushes to a deploy branch" {
  printf 'deploy.envs: production\n' >"$R/.claude/kern.local.yml"
  for c in "GIT push origin feat:production" "/usr/bin/Git push origin HEAD:production" "Git -C . push origin HEAD:production"; do
    g "$c" g15
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
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

@test "G15: a tool behind a wrapper, an assignment, a path or another case asks, denied under autopilot" {
  g15_all ask "timeout 600 terraform apply" "env NODE_ENV=production npm publish" "env npm publish" \
    "sudo -u deploy kubectl apply -f x.yml" "sudo -E npm publish" "nice -n 5 npm publish" "command -p npm publish" \
    "TERRAFORM apply" "Terraform apply -auto-approve" "Npm publish" "KUBECTL apply -f x.yml" \
    "/usr/local/bin/npm publish" "./node_modules/.bin/vercel deploy --prod"
  set_autopilot on
  g15_all deny "timeout 600 terraform apply" "TERRAFORM apply"
}

@test "G15: a deploy verb after global options asks; the verb must be a whole word" {
  g15_all ask "kubectl -n prod apply -f x.yml" "kubectl --context prod delete pod x" "terraform -chdir=infra apply" \
    "helm -n prod upgrade api ./chart" "firebase --project prod deploy" "fly -a app deploy" \
    "aws --profile prod ecs update-service --cluster c --service s" \
    "aws --region us-east-1 lambda update-function-code --function-name f --zip-file fileb://x.zip" \
    "gh -R o/r workflow run deploy.yml" "gh release -R o/r create v1" "npm --prefix pkg publish" "pnpm -r publish" \
    "pnpm --filter x publish" "cargo +nightly publish" "docker buildx build --push -t x ." "terraform plan -out apply"
  g15_all none "terraform plan -out apply.tfplan" "kubectl -n prod get pods" "aws s3 ls s3://bucket" \
    "gh issue create --title 'release create'" "kubectl get pods -l app=label"
}

@test "G15: a runner and its options are stripped" {
  g15_all ask "npx -y vercel deploy" "npx --yes vercel --prod" "npx vercel@latest deploy" "npx -p aws-cdk cdk deploy" \
    "npx aws-cdk deploy" "npx wrangler deploy" "npx netlify deploy --prod" "pnpm dlx vercel deploy --prod" \
    "pnpm exec cdk deploy" "pnpm --filter x exec cdk deploy" "yarn dlx vercel deploy --prod" "bunx vercel deploy --prod" \
    "uvx twine upload dist/x" "uvx --with keyring twine upload dist/x" "npm exec -- vercel deploy --prod" \
    "npm exec -c 'vercel deploy --prod'" "python -m twine upload dist/x" "python3.12 -m twine upload dist/x" \
    "npx changeset publish" "bun x vercel deploy" "uv tool run twine upload dist/x" "uv run twine upload dist/x"
  g15_all none "npx vitest run" "pnpm exec eslint ." "uvx ruff check" "uv run pytest" "npx prettier --write 'npm publish.md'"
  set_autopilot on
  g15_all deny "npx -y vercel deploy" "pnpm dlx vercel deploy --prod"
}

@test "G15: gcloud, helm delete, flyctl, gh run rerun, docker stack, uv, wrangler, netlify, vercel, serverless, firebase and cloudformation ask" {
  g15_all ask "gcloud run deploy api --image x" "gcloud app deploy" "gcloud functions deploy f" "gcloud beta run deploy api" \
    "helm delete api" "helm uninstall api" "flyctl deploy" "gh run rerun 123" "gh release new v1" \
    "docker stack deploy -c x.yml app" "docker stack up -c x.yml app" "docker image push x" "uv publish" \
    "wrangler deploy" "wrangler publish" "netlify deploy --prod" "vercel deploy" "vercel --prod" "serverless deploy" \
    "sls deploy" "firebase deploy" "aws cloudformation deploy --template-file t.yml --stack-name s" \
    "aws cloudformation create-stack --stack-name s" "aws cloudformation update-stack --stack-name s" \
    "aws cloudformation delete-stack --stack-name s" "aws s3 rb s3://bucket --force" "lerna publish"
  set_autopilot on
  g15_all deny "gcloud run deploy api" "gh run rerun 123"
}

@test "G15: ordinary commands do not vote" {
  g15_all none "terraform plan" "kubectl get pods" "helm list" "npm test" "npx vitest" "gcloud config list" \
    "docker build ." "gh run view 123" "echo 'npm publish'" "git commit -m 'npm publish'" "ls -la"
}

@test "G15: quotes, backslashes and a backslash-newline do not hide a tool" {
  g15_all ask "ter''raform apply" 'k"ub"ectl apply -f x.yml' 'terra\form apply' $'terra\\\nform apply' \
    $'npm pub\\\nlish' "bash -c 'n\"p\"m publish'"
}

@test "G15: a tool name as any later word asks; quoted text stays one word" {
  g15_all ask "caffeinate terraform apply" "xargs -n1 npm publish" 'find . -name package.json -execdir npm publish \;' \
    "docker run --rm hashicorp/terraform apply" "nvm exec 20 npm publish" "corepack pnpm publish" \
    "ssh build-host kubectl apply -f x.yml" "echo terraform apply" "man kubectl apply" \
    "docker run --rm hashicorp/terraform:1.9 apply" "docker-compose push"
  g15_all none "git commit -m 'npm publish'" "echo 'terraform apply'" "brew install helm" "npm i -g vercel" \
    "yarn add -D vercel" "which vercel" "pip install twine" "rg 'kubectl apply' docs" "docker run alpine:3 ls" \
    "docker-compose up"
  set_autopilot on
  g15_all deny "caffeinate terraform apply" "xargs -n1 npm publish"
}

@test "G15: a bare vercel with only options asks where vercel runs" {
  g15_all ask "vercel" "vercel --yes" "VERCEL -y" "npx vercel" "pnpm dlx vercel --yes" "./node_modules/.bin/vercel"
  g15_all none "vercel ls" "vercel env pull" "vercel dev" "vercel --version" "vercel --help" "vercel -h" \
    "npm i -g vercel" "brew install vercel-cli"
  set_autopilot on
  g15_all deny "vercel"
}

@test "G15: a command inside one quoted word is split: ssh, a shell's -c, su -c, script -c and watch" {
  g15_all ask "ssh prod 'kubectl apply -f /tmp/x.yml'" "ssh deploy@web1 \"cd /srv/app && npm publish\"" \
    "ssh -i ~/.ssh/k prod 'terraform apply -auto-approve'" "docker exec api sh -c 'npm publish'" \
    "docker run --rm -v \"\$PWD\":/w -w /w hashicorp/terraform:1.9 sh -c 'terraform init && terraform apply -auto-approve'" \
    "caffeinate -i sh -c 'terraform apply'" "su deploy -c 'npm publish'" "watch -n 5 'kubectl rollout restart deploy/api'" \
    "script -q /dev/null -c 'npm publish'" "ssh prod 'bash -c \"npm publish\"'"
  g15_all none "ssh prod 'kubectl get pods'" "ssh prod uptime" "watch -n 5 'kubectl get pods'" \
    "docker exec api sh -c 'npm test'" "su deploy -c 'npm ci'"
  set_autopilot on
  g15_all deny "ssh prod 'kubectl apply -f /tmp/x.yml'" "su deploy -c 'npm publish'"
}

@test "G15: a shell's -c is read in a cluster of any case, and after a plus" {
  g15_all ask "xargs bash -Ec 'kubectl apply -f x.yml'" "docker exec api sh -Cc 'npm publish'" \
    "caffeinate -i bash +c 'terraform apply'"
}

@test "G15: the round-1 table rows ask" {
  g15_all ask "helmfile apply" "helmfile sync" "helmfile destroy" "argocd app sync api" "argocd app create api" \
    "argocd app delete api" "argocd app rollback api 3" "podman push x" "helm push chart.tgz oci://r" "skaffold run" \
    "skaffold deploy" "skaffold delete" "oc apply -f x.yml" "oc -n prod rollout restart deploy/api" "kubectl run x --image=y" \
    "kubectl expose deploy api --port 80" "kubectl drain node1" "kubectl cordon node1" "kubectl taint nodes n k=v:NoSchedule" \
    "terragrunt apply" "terragrunt run-all apply" "terragrunt destroy" "terragrunt import a.b id" "sam deploy" "sam delete" \
    "sst deploy --stage prod" "sst remove" "mvn deploy" "mvn -B -DskipTests deploy" "gradle publish" "./gradlew publish" \
    "dotnet nuget push x.nupkg" "npm unpublish x@1" "npm deprecate x@1 old" "npm dist-tag add x@1 latest" \
    "semantic-release" "npx semantic-release --branches main" "vsce publish" "ovsx publish" "eas update --branch production" \
    "eas submit" "vercel promote https://x" "vercel rollback" "vercel redeploy https://x" "vercel remove app" \
    "firebase hosting:channel:deploy pr-1" "supabase functions deploy f" "supabase db push" "railway up" "railway deploy" \
    "kamal deploy" "kamal rollback v1" "az webapp deploy --src-path x.zip" "az group create -n g -l w" "az vm restart -n x" \
    "az storage blob upload -f x -c c" "az webapp deployment slot swap -s staging" "azd up" "azd deploy" "azd provision" \
    "azd down" "gsutil -m rsync -r dist gs://b" "gsutil cp x.txt gs://b/" "gsutil mv x gs://b/x" "gsutil rm gs://b/x" \
    "gcloud builds submit --tag x" "gcloud deploy releases create r1" "aws s3api put-object --bucket b --key k" \
    "aws s3api delete-object --bucket b --key k" "aws s3api delete-bucket --bucket b" "aws s3api put-bucket-policy --bucket b" \
    "aws lambda publish-version --function-name f" "aws lambda create-function --function-name f" \
    "aws lambda delete-function --function-name f" "aws lambda update-function-configuration --function-name f" \
    "glab release create v1" "glab release upload v1 x" "glab release delete v1" "glab ci run"
  g15_all none "gsutil cp gs://b/x ./x" "gsutil ls gs://b" "az account show" "az login" "eas build" "mvn test" \
    "./gradlew build" "dotnet nuget list source" "glab mr list" "npm i -D semantic-release" "supabase start" "oc get pods" \
    "helmfile diff" "argocd app list" "sam build" "railway logs" "kamal app logs" "podman build -t x ."
}

@test "G15: a read verb first, --dry-run, words after --, rollout reads and s3 downloads do not vote" {
  g15_all none "npm test -- -t publish" "npm publish --dry-run" "cargo publish --dry-run" "docker run --rm alpine echo push" \
    "kubectl rollout status deployment/api" "kubectl rollout history deployment/api" "kubectl apply --dry-run=client -f x.yml" \
    "kubectl apply --dry-run=server -f x.yml" "kubectl create deployment api --image=x --dry-run=client -o yaml" \
    "kubectl create secret generic s --from-literal=a=b --dry-run=client -o yaml" "kubectl describe clusterrole edit" \
    "kubectl config set current-context prod" "helm diff upgrade api ./chart -f values.yaml" \
    "helm upgrade --install api ./chart --dry-run --debug" "helm install api ./chart --dry-run" \
    "aws s3 cp s3://bucket/logs/app.log ./app.log" "aws s3 sync s3://bucket/reports ./reports" \
    "kubectl auth can-i create pods" "semantic-release --dry-run"
  g15_all ask "kubectl rollout undo deploy/api" "kubectl apply --dry-run=none -f x.yml" "kubectl exec api -- npm publish" \
    "docker buildx build --push -t x ." "docker build --push -t x ." "aws s3 cp ./x s3://b/x" \
    "aws s3 sync dist s3://b --delete --profile prod" "aws s3 cp --recursive ./dist s3://b" "aws s3 cp - s3://b/x" \
    "aws s3 cp s3://a/x s3://b/x" "aws s3 mv ./x s3://b/x"
}

@test "G15: a move from a bucket, mvnw, and su --command= or an attached -c ask" {
  g15_all ask "aws s3 mv s3://bucket/x ./x" "gsutil mv gs://b/x ./x" "mvnw deploy" "./mvnw -B deploy" \
    "su --command='npm publish'" "su deploy --command 'npm publish'" "su -c'npm publish' deploy" \
    "script -q -c'npm publish' /dev/null"
  g15_all none "su --command='npm ci'" "./mvnw test" "aws s3 cp s3://bucket/x ./x"
}

@test "G15: the final rider's rows ask; their read forms do not" {
  g15_all ask "flux reconcile kustomization apps --with-source" "eas build --platform all --auto-submit" "eas build -s" \
    "cargo release patch --execute" "cargo yank --version 1.0.0" "func azure functionapp publish myfunc" \
    "gcloud storage cp -r dist gs://bucket" "gcloud storage mv gs://b/x ./x" "gcloud storage rm gs://b/x" \
    "gcloud run services update api --image x" "gcloud run services update-traffic api --to-latest" \
    "gcloud run services delete api" "vercel alias set app-abc.vercel.app example.com" "firebase functions:delete fn" \
    "fly secrets set KEY=v" "fly secrets unset KEY" "fly scale count 3" "npx prisma migrate deploy" "npx convex deploy" \
    "npx release-it --ci" "npx gh-pages -d dist" "npx surge ./dist example.surge.sh" "npx nx release publish" \
    "deno publish" "npx jsr publish" "aws cloudfront create-invalidation --distribution-id E1 --paths '/*'" \
    "aws deploy create-deployment --application-name a --deployment-group-name g" \
    "aws elasticbeanstalk update-environment --environment-name e --version-label v2" "heroku container:release web" \
    "heroku releases:rollback v12" "kubectl -n prod cp ./x pod:/tmp/x" "mix hex.publish" "pod trunk push X.podspec" \
    "dart pub publish" "flutter pub publish --force" "sbt publish" \
    "docker buildx imagetools create -t ghcr.io/o/a:latest ghcr.io/o/a:1.2" "skopeo copy docker://a docker-daemon:b" \
    "cdktf deploy" "cdktf destroy" "lerna version --yes"
  g15_all none "fly status" "gcloud run services list" "prisma migrate status" "heroku logs --tail" \
    "flux get kustomizations" "eas build --platform ios" "gcloud storage ls gs://b" "gcloud storage cp gs://b/x ./x" \
    "vercel alias ls" "deno test" "mix test" "pod install" "flutter pub get" "dart pub get" "sbt compile" \
    "skopeo inspect docker://x" "cdktf synth" "lerna run build" "nx build app" "heroku releases" \
    "flutter pub publish --dry-run" "git checkout gh-pages"
}

@test "G15: a last record that starts with an assignment, a wrapper, ! or a redirect gets no vote under autopilot" {
  local c
  set_autopilot on
  for c in "NODE_ENV=test npm test" "time npm test" "timeout 600 npm test" "sudo npm install -g pnpm" "env CI=1 npm test" \
    "cd web && FOO=1 npm run build" "DEBUG=1 cargo build" "KUBECONFIG=x kubectl get pods" "! grep -q x docs/a.md" \
    "nohup npm run dev > log 2>&1 &"; do
    gx "$c" ""
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
}

@test "G15: a failed judge or a failed parse asks" {
  local real
  real=$(command -v awk)
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/bash\ncase "$*" in *"$KERN_TEST_BREAK"*) exit 2 ;; esac\nexec %s "$@"\n' "$real" >"$BATS_TEST_TMPDIR/bin/awk"
  chmod +x "$BATS_TEST_TMPDIR/bin/awk"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  for b in 'g15_tool(' 'function emit('; do
    KERN_TEST_BREAK=$b
    export KERN_TEST_BREAK
    g "npm publish; ls" g15
    [ "$(decision_of "$output")" = ask ] || { echo "$b -> $output"; return 1; }
    case "$output" in *"could not read the command"*) ;; *) echo "$b -> $output"; return 1 ;; esac
  done
}

@test "G13 and G15: a 10 KB inline PR body passes every guard in under 2 s in a UTF-8 locale" {
  local body="" i=0 line cmd t0 t1
  printf 'protected_targets: v1-host\ndeploy.envs: production\n' >"$R/.claude/kern.local.yml"
  # Inline, as Claude writes it: the double quotes, backticks and dollars inside are escaped.
  line='- Fixed the \`npm publish\` step so it doesn'\''t \"push\" to production'\''s main branch, a naïve \$PATH fix; see docs/release.md (ssh, scp, kubectl apply).'
  while [ "${#body}" -lt 10240 ]; do
    i=$((i + 1))
    body="$body$i. $line
"
  done
  cmd="gh pr create --title 'M1: x' --body \"$body\""
  export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  t0=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  gx "$cmd" ""
  t1=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  [ "$status" = 0 ]
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"G4: "* ]] || false
  [ $((t1 - t0)) -lt 2000 ] || { echo "took $((t1 - t0)) ms"; return 1; }
}

@test "G15: every tool in the table asks for each of its verbs, in any case, and passes the prefilter" {
  local f names paths name path p w ws n=0 cmd="" line want=() names_all=()
  f="$(kern_root)/hooks/guards/g15-deploy.sh"
  while IFS='	' read -r names paths; do
    [ -n "$names" ] || continue
    while IFS= read -r name; do
      names_all+=("$name" "$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')")
      while IFS= read -r path; do
        n=$((n + 1))
        # A path word ending in * stands for any word it starts, and >X for a source then a word
        # that starts with X; the paths ~ and . are the tool alone.
        p=""
        read -r -a ws <<<"$path"
        for w in "${ws[@]}"; do
          case "$w" in
            '~' | .) ;;
            '>'*) p="${p:+$p }./src ${w#>}x" ;;
            *'*') p="${p:+$p }${w%\*}x" ;;
            *) p="${p:+$p }$w" ;;
          esac
        done
        line="$name${p:+ $p}"
        [ $((n % 2)) = 0 ] && line="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')${p:+ $p}"
        want+=("$line")
        cmd="${cmd:+$cmd
}$line"
      done <<EOT
$(printf '%s\n' "$paths" | tr '|' '\n')
EOT
    done <<EOT
$(printf '%s\n' "$names" | tr ',' '\n')
EOT
  done <<EOT
$(sed -n 's/^ *g15_tool("\([^"]*\)", "\([^"]*\)").*/\1	\2/p' "$f")
EOT
  [ "$n" -ge 60 ] || { echo "only $n table entries"; return 1; }
  gx "$cmd" g15
  [ "$(decision_of "$output")" = ask ]
  for line in "${want[@]}"; do
    case "$output" in *"deploy or publish: $line\""* | *"deploy or publish: $line;"*) ;; *) echo "no vote: $line"; return 1 ;; esac
  done
  run bash -c '. "$1"; shift; for w in "$@"; do _g15_named "x $w y" || echo "prefilter misses $w"; done' _ "$f" "${names_all[@]}"
  [ "$status" = 0 ]
  [ -z "$output" ]
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
