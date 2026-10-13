#!/usr/bin/env bats
# hooks/lib/settings.sh and scripts/kern-get: layering, comments, quotes, worktrees, policies.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  mkdir -p "$R/.claude"
  RP=$(cd "$R" && pwd -P)
  export KERN_ROOT
  KERN_ROOT="$(kern_root)"
  # shellcheck source=hooks/lib/settings.sh
  . "$KERN_ROOT/hooks/lib/settings.sh"
}

@test "local beats shared beats user; default when unset; 3 with no default" {
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  printf 'push.policy: deny\nbase_branch: develop\n' >"$R/.claude/kern.yml"
  printf 'base_branch: trunk\nmode.voice: terse\n' >"$HOME/.claude/kern.yml"
  [ "$(settings_get push.policy)" = auto ]
  [ "$(settings_get base_branch)" = develop ]
  [ "$(settings_get mode.voice)" = terse ]
  [ "$(settings_get nope dflt)" = dflt ]
  run settings_get nope
  [ "$status" -eq 3 ]
  [ "$(settings_source base_branch)" = "$RP/.claude/kern.yml" ]
  [ "$(settings_source nope)" = default ]
}

@test "the four list keys add up across layers, brackets dropped per layer; other keys take the highest" {
  printf 'protected_targets: db.internal\nnever_commit: [*.pem]\ndeploy.envs:\nbase_branch: develop\n' \
    >"$R/.claude/kern.local.yml"
  printf 'branch.protected: release\ndeploy.envs: staging\n' >"$R/.claude/kern.yml"
  printf 'protected_targets: v1-host\nnever_commit: .env, *.key\nbranch.protected: [prod]\ndeploy.envs: production\nbase_branch: trunk\n' \
    >"$HOME/.claude/kern.yml"
  [ "$(settings_get protected_targets)" = "db.internal, v1-host" ]
  [ "$(settings_get never_commit)" = "*.pem, .env, *.key" ]
  [ "$(settings_get branch.protected)" = "release, prod" ]
  [ "$(settings_get deploy.envs)" = "staging, production" ]
  [ "$(settings_get base_branch)" = develop ]
  [ "$(settings_source protected_targets)" = "$RP/.claude/kern.local.yml, $HOME/.claude/kern.yml" ]
  [ "$(settings_source base_branch)" = "$RP/.claude/kern.local.yml" ]
  rm "$HOME/.claude/kern.yml" "$R/.claude/kern.yml"
  [ "$(settings_get never_commit)" = "*.pem" ]
  [ "$(settings_get branch.protected dflt)" = dflt ]
}

@test "a union drops repeated values, keeping each at its first place" {
  printf 'deploy.envs: qa, production\nnever_commit: *.pem,, *.pem\n' >"$R/.claude/kern.local.yml"
  printf 'deploy.envs: [production , uat, qa]\nnever_commit: .env\n' >"$HOME/.claude/kern.yml"
  [ "$(settings_get deploy.envs)" = "qa, production, uat" ]
  [ "$(settings_get never_commit)" = "*.pem, .env" ]
  printf 'deploy.envs: production\n' >"$HOME/.claude/kern.yml"
  [ "$(settings_get deploy.envs)" = "qa, production" ]
}

@test "a project protected_targets cannot drop the user's: G13 still denies a write to the user's host" {
  printf 'protected_targets: db.internal\n' >"$R/.claude/kern.local.yml"
  printf 'protected_targets: v1-host\n' >"$HOME/.claude/kern.yml"
  run_guard "$(bash_payload "ssh v1-host 'rm -f /data/x'")" g13
  [ "$(decision_of "$output")" = deny ]
}

@test "comments, quotes, colons and hashes inside values" {
  cat >"$R/.claude/kern.local.yml" <<'YML'
# comment line
commit.convention: "^CDS-[0-9]+: "   # keeps the trailing space
review.taxonomy: 'Bug,Suggestion # not a comment,Nit'
deploy.proof: http://host/x#frag
YML
  [ "$(settings_get commit.convention)" = '^CDS-[0-9]+: ' ]
  [ "$(settings_get review.taxonomy)" = 'Bug,Suggestion # not a comment,Nit' ]
  [ "$(settings_get deploy.proof)" = 'http://host/x#frag' ]
}

@test "CRLF settings files read the same" {
  printf 'push.policy: auto\r\n' >"$R/.claude/kern.local.yml"
  [ "$(settings_get push.policy)" = auto ]
}

@test "a linked worktree reads the main checkout's untracked settings" {
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  cd "$BATS_TEST_TMPDIR/wt"
  run bash "$KERN_ROOT/scripts/kern-get" push.policy
  [ "$status" -eq 0 ]
  [ "$output" = "auto	$RP/.claude/kern.local.yml" ]
}

@test "kern-get prints value and source; exit 3 when unset" {
  cd "$R"
  run bash "$KERN_ROOT/scripts/kern-get" work_dir .kern
  [ "$output" = ".kern	default" ]
  run bash "$KERN_ROOT/scripts/kern-get" nope
  [ "$status" -eq 3 ]
}

@test "policy_for maps values; draft-after-approval and junk read as ask" {
  printf 'pr.policy: draft-after-approval\npush.policy: auto\ncommit.policy: banana\nreview.post_policy: deny\n' >"$R/.claude/kern.local.yml"
  [ "$(policy_for pr)" = ask ]
  [ "$(policy_for push)" = auto ]
  [ "$(policy_for commit)" = ask ]
  [ "$(policy_for review.post)" = deny ]
  [ "$(policy_for tracker)" = ask ]
}

@test "unknown keys are listed; families such as overrides.<job> are known" {
  printf 'overrides.commit: commit\nfoo.bar: 1\npush.policy: ask\n' >"$R/.claude/kern.local.yml"
  run settings_unknown_keys
  [ "$output" = "$RP/.claude/kern.local.yml	foo.bar" ]
}

@test "kern: off disables; list_has trims" {
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  run kern_enabled
  [ "$status" -eq 1 ]
  list_has "a, b ,c" b
  run list_has "a,b" z
  [ "$status" -eq 1 ]
}

@test "list_has keeps items that start or end with t, in branch.protected and deploy.envs" {
  list_has "feat, test" feat
  list_has "feat, test" test
  list_has "$(printf 'feat\t, test')" feat
  run list_has "feat, test" fea
  [ "$status" -eq 1 ]
  run list_has "feat, test" es
  [ "$status" -eq 1 ]
  # shellcheck source=hooks/lib/gitctx.sh
  . "$KERN_ROOT/hooks/lib/gitctx.sh"
  printf 'branch.protected: feat, test\n' >"$R/.claude/kern.local.yml"
  branch_protected feat
  branch_protected test
  printf 'deploy.envs: test, feat\n' >"$R/.claude/kern.local.yml"
  branch_protected feat
  branch_protected test
  run branch_protected fea
  [ "$status" -eq 1 ]
}

@test "list_has reads a YAML flow list in brackets" {
  list_has "[feat]" feat
  list_has "[ feat, test ]" test
  run list_has "[feat]" "[feat]"
  [ "$status" -eq 1 ]
  # shellcheck source=hooks/lib/gitctx.sh
  . "$KERN_ROOT/hooks/lib/gitctx.sh"
  printf 'branch.protected: [feat]\n' >"$R/.claude/kern.local.yml"
  branch_protected feat
}

@test "policy_for never loosens floor actions: merge and deploy read as ask" {
  printf 'merge.policy: auto\ndeploy.policy: auto\npush.policy: auto\n' >"$R/.claude/kern.local.yml"
  [ "$(policy_for merge)" = ask ]
  [ "$(policy_for deploy)" = ask ]
  [ "$(policy_for push)" = auto ]
}
