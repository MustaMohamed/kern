#!/usr/bin/env bats
# hooks/lib/settings.sh and scripts/kern-get: layering, comments, quotes, worktrees, policies.

bats_require_minimum_version 1.5.0
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

# git worktree list names the git dir as the main worktree in a submodule and in a --separate-git-dir
# checkout, so kern read its settings from under the git dir and missed the committed ones (audit E3).
@test "kern_main_root is unchanged in a plain repo, its subdirectory, a linked worktree and a bare repo's worktree" {
  [ "$(kern_main_root "$R")" = "$RP" ]
  mkdir -p "$R/a/b"
  [ "$(kern_main_root "$R/a/b")" = "$RP" ]
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  [ "$(kern_main_root "$BATS_TEST_TMPDIR/wt")" = "$RP" ]
  git clone -q --bare "$R" "$BATS_TEST_TMPDIR/b.git"
  git -C "$BATS_TEST_TMPDIR/b.git" worktree add -q "$BATS_TEST_TMPDIR/bwt" main
  [ "$(kern_main_root "$BATS_TEST_TMPDIR/bwt")" = "$(cd "$BATS_TEST_TMPDIR/b.git" && pwd -P)" ]
  run kern_main_root "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "in a submodule, kern-get reads the submodule's committed never_commit and branch.protected" {
  S="$BATS_TEST_TMPDIR/sub"
  git init -q -b main "$S"
  mkdir "$S/.claude"
  printf 'never_commit: secrets/*\nbranch.protected: release\n' >"$S/.claude/kern.yml"
  git -C "$S" add .claude/kern.yml
  git -C "$S" -c user.name=t -c user.email=t@t commit -q -m s
  git -C "$R" -c protocol.file.allow=always submodule add -q "$S" mod
  M=$(cd "$R/mod" && pwd -P)
  mkdir "$R/mod/deep"
  [ "$(kern_main_root "$R/mod/deep")" = "$M" ]
  # A linked worktree of the submodule finds the checkout through the git dir's core.worktree.
  git -C "$R/mod" worktree add -q -b wt "$BATS_TEST_TMPDIR/modwt"
  [ "$(kern_main_root "$BATS_TEST_TMPDIR/modwt")" = "$M" ]
  cd "$R/mod"
  run bash "$KERN_ROOT/scripts/kern-get" never_commit
  [ "$status" -eq 0 ]
  [ "$output" = "secrets/*	$M/.claude/kern.yml" ]
  run bash "$KERN_ROOT/scripts/kern-get" branch.protected
  [ "$status" -eq 0 ]
  [ "$output" = "release	$M/.claude/kern.yml" ]
  # From the linked worktree only core.worktree can name the checkout: an absolute one is taken as it
  # is, and one naming a missing directory leaves no root.
  git --git-dir="$R/.git/modules/mod" config core.worktree "$M"
  [ "$(kern_main_root "$BATS_TEST_TMPDIR/modwt")" = "$M" ]
  git --git-dir="$R/.git/modules/mod" config core.worktree "$BATS_TEST_TMPDIR/gone"
  run kern_main_root "$BATS_TEST_TMPDIR/modwt"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "in a --separate-git-dir checkout, kern-get reads its committed settings; its linked worktree has no main root" {
  W="$BATS_TEST_TMPDIR/sepwt"
  git init -q -b main --separate-git-dir "$BATS_TEST_TMPDIR/sepgit" "$W"
  mkdir "$W/.claude"
  printf 'never_commit: secrets/*\nbranch.protected: release\n' >"$W/.claude/kern.yml"
  git -C "$W" add .claude/kern.yml
  git -C "$W" -c user.name=t -c user.email=t@t commit -q -m s
  WP=$(cd "$W" && pwd -P)
  [ "$(kern_main_root "$W")" = "$WP" ]
  cd "$W"
  run bash "$KERN_ROOT/scripts/kern-get" never_commit
  [ "$status" -eq 0 ]
  [ "$output" = "secrets/*	$WP/.claude/kern.yml" ]
  run bash "$KERN_ROOT/scripts/kern-get" branch.protected
  [ "$status" -eq 0 ]
  [ "$output" = "release	$WP/.claude/kern.yml" ]
  # git records no path for this main checkout, so a linked worktree cannot find it.
  git -C "$W" worktree add -q -b wt "$BATS_TEST_TMPDIR/sepwt2"
  run kern_main_root "$BATS_TEST_TMPDIR/sepwt2"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
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

@test "a committed kern: off is ignored; the local and the user file still turn kern off" {
  printf 'kern: off\n' >"$R/.claude/kern.yml"
  kern_enabled
  [ "$(settings_get kern on)" = on ]
  [ "$(settings_source kern)" = default ]
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  run kern_enabled
  [ "$status" -eq 1 ]
  rm "$R/.claude/kern.local.yml" "$R/.claude/kern.yml"
  printf 'kern: off\n' >"$HOME/.claude/kern.yml"
  run kern_enabled
  [ "$status" -eq 1 ]
}

@test "a committed kern: off does not hide a lower layer's on" {
  printf 'kern: off\n' >"$R/.claude/kern.yml"
  printf 'kern: on\n' >"$HOME/.claude/kern.yml"
  kern_enabled
  [ "$(settings_source kern)" = "$HOME/.claude/kern.yml" ]
}

@test "a committed policy may be ask or deny, never auto: auto reads as unset" {
  printf 'push.policy: auto\ncommit.policy: deny\npr.policy: ask\nreview.post_policy: auto\ntracker.policy: auto\n' \
    >"$R/.claude/kern.yml"
  [ "$(policy_for push)" = ask ]
  [ "$(policy_for commit)" = deny ]
  [ "$(policy_for pr)" = ask ]
  [ "$(policy_for review.post)" = ask ]
  [ "$(policy_for tracker)" = ask ]
  [ "$(settings_source push.policy)" = default ]
  [ "$(settings_source commit.policy)" = "$RP/.claude/kern.yml" ]
}

@test "a committed policy auto falls through to the user file, and local and user auto still work" {
  printf 'push.policy: auto\n' >"$R/.claude/kern.yml"
  printf 'push.policy: deny\n' >"$HOME/.claude/kern.yml"
  [ "$(policy_for push)" = deny ]
  printf 'push.policy: auto\n' >"$HOME/.claude/kern.yml"
  [ "$(policy_for push)" = auto ]
  rm "$HOME/.claude/kern.yml"
  [ "$(policy_for push)" = ask ]
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  [ "$(policy_for push)" = auto ]
}

@test "a committed policy deny beats a user auto, and the user file's protections stay" {
  printf 'push.policy: deny\n' >"$R/.claude/kern.yml"
  printf 'push.policy: auto\nprotected_targets: prod-db\n' >"$HOME/.claude/kern.yml"
  [ "$(policy_for push)" = deny ]
  printf 'kern: off\n' >>"$R/.claude/kern.yml"
  kern_enabled
  [ "$(settings_get protected_targets)" = prod-db ]
}

@test "a committed rebase.push: autopilot reads as unset; the local and user files still set it" {
  printf 'rebase.push: autopilot\n' >"$R/.claude/kern.yml"
  [ "$(settings_get rebase.push ask)" = ask ]
  printf 'rebase.push: autopilot\n' >"$HOME/.claude/kern.yml"
  [ "$(settings_get rebase.push ask)" = autopilot ]
  rm "$HOME/.claude/kern.yml"
  printf 'rebase.push: autopilot\n' >"$R/.claude/kern.local.yml"
  [ "$(settings_get rebase.push ask)" = autopilot ]
  printf 'rebase.push: ask\n' >"$R/.claude/kern.yml"
  rm "$R/.claude/kern.local.yml"
  [ "$(settings_get rebase.push ask)" = ask ]
}

@test "a tracked kern.local.yml gets the committed-file rules: its kern: off cannot disable the user's protection" {
  printf 'protected_targets: v1-host\n' >"$HOME/.claude/kern.yml"
  printf 'kern: off\npush.policy: auto\nrebase.push: autopilot\n' >"$R/.claude/kern.local.yml"
  git -C "$R" add .claude/kern.local.yml
  kern_enabled
  [ "$(policy_for push)" = ask ]
  [ "$(settings_get rebase.push ask)" = ask ]
  run_guard "$(bash_payload "ssh v1-host 'rm -f /data/x'")" g13
  [ "$(decision_of "$output")" = deny ]
}

@test "a tracked kern.local.yml may still tighten: deny and ask count" {
  printf 'push.policy: deny\n' >"$R/.claude/kern.local.yml"
  git -C "$R" add .claude/kern.local.yml
  [ "$(policy_for push)" = deny ]
}

@test "an untracked kern.local.yml still turns kern off and sets auto" {
  printf 'kern: off\npush.policy: auto\n' >"$R/.claude/kern.local.yml"
  run kern_enabled
  [ "$status" -eq 1 ]
  [ "$(policy_for push)" = auto ]
}

@test "a tracked KERN.LOCAL.YML on a case-insensitive file system gets the committed-file rules" {
  printf 'x\n' >"$R/.claude/CaseProbe"
  [ -f "$R/.claude/caseprobe" ] || skip "case-sensitive file system"
  printf 'kern: off\n' >"$R/.claude/KERN.LOCAL.YML"
  git -C "$R" add .claude/KERN.LOCAL.YML
  kern_enabled
  [ "$(settings_source kern)" = default ]
}

@test "a committed symlinked .claude holding kern.local.yml cannot turn kern off or drop protection" {
  printf 'protected_targets: v1-host\n' >"$HOME/.claude/kern.yml"
  mv "$R/.claude" "$R/cfg"
  ln -s cfg "$R/.claude"
  printf 'kern: off\npush.policy: auto\n' >"$R/cfg/kern.local.yml"
  git -C "$R" add .claude cfg
  kern_enabled
  [ "$(policy_for push)" = ask ]
  run_guard "$(bash_payload "ssh v1-host 'rm -f /data/x'")" g13
  [ "$(decision_of "$output")" = deny ]
}

@test "a .claude that is a submodule cannot turn kern off or drop protection" {
  printf 'protected_targets: v1-host\n' >"$HOME/.claude/kern.yml"
  S="$BATS_TEST_TMPDIR/sub"
  git init -q "$S"
  printf 'kern: off\npush.policy: auto\n' >"$S/kern.local.yml"
  git -C "$S" add kern.local.yml
  git -C "$S" -c user.name=t -c user.email=t@t commit -q -m s
  rm -rf "$R/.claude"
  git -C "$R" -c protocol.file.allow=always submodule add -q "$S" .claude
  [ -f "$R/.claude/kern.local.yml" ]
  kern_enabled
  [ "$(policy_for push)" = ask ]
  run_guard "$(bash_payload "ssh v1-host 'rm -f /data/x'")" g13
  [ "$(decision_of "$output")" = deny ]
}

@test "a .claude holding its own .git, or a symlinked kern.local.yml, cannot loosen" {
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  mkdir "$R/.claude/.git"
  kern_enabled
  rmdir "$R/.claude/.git"
  run kern_enabled
  [ "$status" -eq 1 ]
  rm "$R/.claude/kern.local.yml"
  printf 'kern: off\npush.policy: auto\n' >"$BATS_TEST_TMPDIR/elsewhere.yml"
  ln -s "$BATS_TEST_TMPDIR/elsewhere.yml" "$R/.claude/kern.local.yml"
  kern_enabled
  [ "$(policy_for push)" = ask ]
}

@test "a symlinked .claude pointing outside the main worktree cannot loosen" {
  mkdir "$BATS_TEST_TMPDIR/out"
  printf 'kern: off\n' >"$BATS_TEST_TMPDIR/out/kern.local.yml"
  rm -rf "$R/.claude"
  ln -s "$BATS_TEST_TMPDIR/out" "$R/.claude"
  kern_enabled
}

# A settings layer kern cannot read (awk fails, or a command substitution's pipe cannot be made) must not
# loosen a guard: the key reads as its strictest value, or settings_get exits 4 for the caller to fail
# closed (review of 2026-10-21).
# get KEY [DEFAULT]: sets got to settings_get's stdout and rc to its exit code; the stub's stderr is dropped.
get() {
  rc=0
  got=$(settings_get "$@" 2>/dev/null) || rc=$?
}

@test "a layer that cannot be read leaves a policy unknown, rebase.push ask, and the user's kern: off, with exit 4" {
  printf 'commit.policy: auto\nrebase.push: ask\nkern: on\n' >"$R/.claude/kern.local.yml"
  printf 'rebase.push: autopilot\nkern: off\npush.policy: auto\npr.policy: deny\n' >"$HOME/.claude/kern.yml"
  read_fails awk "$RP/.claude/kern.local.yml"
  get commit.policy ask
  [ "$rc" -eq 4 ]
  [ "$got" = unknown ]
  [ "$(policy_for commit 2>/dev/null)" = unknown ]
  # A readable lower layer's auto cannot stand, its deny does.
  [ "$(policy_for push 2>/dev/null)" = unknown ]
  [ "$(policy_for pr 2>/dev/null)" = deny ]
  get rebase.push ask
  [ "$rc" -eq 4 ]
  [ "$got" = ask ]
  # The user's own kern: off holds whatever a layer that cannot be read may say.
  get kern on
  [ "$rc" -eq 4 ]
  [ "$got" = off ]
  run kern_enabled
  [ "$status" -ne 0 ]
  [[ "$(settings_unread_why commit.policy 2>/dev/null)" == "$RP/.claude/kern.local.yml could not be read" ]] || false
  # A layer above the one that cannot be read decides alone.
  read_fails awk "$RP/.claude/kern.local.yml" 0
  read_fails awk "$HOME/.claude/kern.yml"
  get commit.policy ask
  [ "$rc" -eq 0 ]
  [ "$got" = auto ]
}

@test "a list key with a layer that cannot be read exits 4 with the items the other layers give" {
  printf 'never_commit: secrets/*\n' >"$R/.claude/kern.local.yml"
  printf 'never_commit: *.pem\n' >"$HOME/.claude/kern.yml"
  read_fails awk "$RP/.claude/kern.local.yml"
  get never_commit ''
  [ "$rc" -eq 4 ]
  [ "$got" = '*.pem' ]
  # Any other key gives what the readable layers and the default give, with exit 4.
  get base_branch dflt
  [ "$rc" -eq 4 ]
  [ "$got" = dflt ]
}

@test "a policy layer is never lost to a failed command substitution" {
  local n=1 got
  printf 'commit.policy: deny\n' >"$R/.claude/kern.local.yml"
  while [ "$n" -le 40 ]; do
    got=$(pipe_fails "$n" policy_for commit 2>/dev/null)
    # deny, or unknown, which a guard asks on; never ask or auto, which would let a commit through.
    case "$got" in deny | unknown) ;; *) echo "policy read $got when substitution $n failed"; return 1 ;; esac
    [ -e "$BATS_TEST_TMPDIR/pipe-failed" ] || break
    n=$((n + 1))
  done
  [ "$n" -le 40 ]
}

@test "when git cannot list the worktrees, the root comes from the .git, and a broken .git leaves the project layers unread" {
  printf 'commit.policy: auto\n' >"$HOME/.claude/kern.yml"
  printf 'commit.policy: deny\n' >"$R/.claude/kern.local.yml"
  read_fails git worktree
  rc=0
  _settings_files >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ]
  get commit.policy ask
  [ "$rc" -eq 0 ]
  [ "$got" = deny ]
  # A plain directory under a .git file whose gitdir is gone: only the user's file is known.
  mkdir -p "$BATS_TEST_TMPDIR/plain/sub"
  printf 'gitdir: %s/gone/.git\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/plain/.git"
  export CWD="$BATS_TEST_TMPDIR/plain/sub"
  rc=0
  _settings_files >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ]
  get commit.policy ask
  [ "$rc" -eq 4 ]
  [ "$got" = unknown ]
  [[ "$(settings_unread_why commit.policy)" == "git cannot open this repository"* ]] || false
  # Outside any repository the user's layer alone decides, as before.
  export CWD="$BATS_TEST_TMPDIR/norepo"
  mkdir -p "$CWD"
  get commit.policy ask
  [ "$rc" -eq 0 ]
  [ "$got" = auto ]
}

# kern-get feeds skills, which read exit 3 as "take the default" and handle no other failure; the hooks
# decide on settings themselves. So on a settings file that cannot be read it prints the value it has
# and says why on stderr (Task 16l, fix round 2).
@test "kern-get prints what it has, with a warning, when a settings file cannot be read" {
  printf 'work_dir: .kwork\n' >"$HOME/.claude/kern.yml"
  printf 'test.full: make test\n' >"$R/.claude/kern.local.yml"
  read_fails awk "$RP/.claude/kern.local.yml"
  cd "$R"
  run --separate-stderr bash "$KERN_ROOT/scripts/kern-get" work_dir .kern
  [ "$status" -eq 0 ]
  [ "$output" = ".kwork	$HOME/.claude/kern.yml" ]
  [[ "$stderr" == *"kern-get: work_dir may not be the whole answer: $RP/.claude/kern.local.yml could not be read"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/kern-get" commit.policy
  [ "$status" -eq 0 ]
  [ "${output%%	*}" = unknown ]
  # Nothing readable sets the key and there is no default: unset, as a skill expects.
  run --separate-stderr bash "$KERN_ROOT/scripts/kern-get" test.full
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"test.full may not be the whole answer"* ]] || false
}
