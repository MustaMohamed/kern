#!/usr/bin/env bats
# G5 commit checks and G6 secret scan.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c CDS-2465/replace-minio
  mkdir -p "$R/.claude"
  printf 'commit.convention: "^CDS-[0-9]+: "\n' >"$R/.claude/kern.local.yml"
  kern_env "$R"
}

g() { run_guard "$(bash_payload "$1")" "$2"; }

@test "G5: a passing -F message asks interactively and is allowed under autopilot" {
  printf 'CDS-2465: swap MinIO for Floci\n\nWhy.\n' >"$R/msg.txt"
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = allow ]
}

@test "G5: a subject off convention is denied in both modes" {
  printf 'swap MinIO\n' >"$R/msg.txt"
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"commit.convention"* ]] || false
  set_autopilot on
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = deny ]
}

@test "G5: a missing ticket id from the branch is denied" {
  printf 'commit.convention: ".*"\n' >"$R/.claude/kern.local.yml"
  g "git commit -m 'swap MinIO'" g05
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"CDS-2465"* ]] || false
}

@test "G5: an AI attribution trailer is denied unless commit.attribution allows it" {
  printf 'CDS-2465: swap\n\nClaude-Session: https://claude.ai/code/session_x\n' >"$R/msg.txt"
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = deny ]
  printf 'commit.convention: "^CDS-[0-9]+: "\ncommit.attribution: allowed\n' >"$R/.claude/kern.local.yml"
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = ask ]
}

@test "G5: a message built by command substitution cannot be checked: ask, deny under autopilot" {
  g "git commit -m \$(cat m.txt)" g05
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g "git commit -m \$(cat m.txt)" g05
  [ "$(decision_of "$output")" = deny ]
}

@test "G5: commit.policy auto allows a passing commit; deny denies it" {
  printf 'commit.convention: "^CDS-[0-9]+: "\ncommit.policy: auto\n' >"$R/.claude/kern.local.yml"
  g "git commit -m 'CDS-2465: swap'" g05
  [ "$(decision_of "$output")" = allow ]
  printf 'commit.policy: deny\n' >"$R/.claude/kern.local.yml"
  g "git commit -m 'CDS-2465: swap'" g05
  [ "$(decision_of "$output")" = deny ]
}

@test "G5: git add -A and commit -a ask, denied under autopilot; git add -- path: no vote" {
  g "git add -A" g05
  [ "$(decision_of "$output")" = ask ]
  g "git add ." g05
  [ "$(decision_of "$output")" = ask ]
  g "git add -- src/a.ts" g05
  [ "$(decision_of "$output")" = none ]
  set_autopilot on
  g "git add -A" g05
  [ "$(decision_of "$output")" = deny ]
  g "git commit -am 'CDS-2465: x'" g05
  [ "$(decision_of "$output")" = deny ]
}

@test "G6: a staged private key is denied without printing it" {
  printf -- '-----BEGIN RSA PRIVATE KEY-----\nMIIEsecret\n' >"$R/id_rsa"
  git -C "$R" add id_rsa
  g "git commit -m 'CDS-2465: key'" g06
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"id_rsa:1 private-key"* ]] || false
  [[ "$output" != *"MIIEsecret"* ]] || false
}

@test "G6: a clean staged change: no vote" {
  printf 'hello\n' >"$R/a.txt"
  git -C "$R" add a.txt
  g "git commit -m 'CDS-2465: a'" g06
  [ "$(decision_of "$output")" = none ]
}

@test "G6: never_commit paths are denied" {
  printf 'never_commit: *.db, .env*\n' >"$R/.claude/kern.local.yml"
  printf 'x\n' >"$R/data.db"
  git -C "$R" add data.db
  g "git commit -m 'CDS-2465: db'" g06
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"data.db"* ]] || false
}

@test "G6: a push scans the outgoing commits" {
  printf 'token = "ghp_abcdefghijklmnopqrstuvwxyz0123"\n' >"$R/cfg.txt"
  git -C "$R" add cfg.txt
  git -C "$R" commit -q -m "CDS-2465: cfg"
  g "git push -u origin CDS-2465/replace-minio" g06
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"cfg.txt:1 github-token"* ]] || false
}
