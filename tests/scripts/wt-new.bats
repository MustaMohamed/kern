#!/usr/bin/env bats
# tests/scripts/wt-new.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
}

@test "wt-new creates a branch worktree off origin/main" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-a
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.claude/worktrees/feat-a" ]
  [ "$(git -C "$output" rev-parse --abbrev-ref HEAD)" = "kern/feat-a" ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse origin/main)" ]
  run git -C "$REPO/.claude/worktrees/feat-a" rev-parse --abbrev-ref '@{upstream}'
  [ "$status" -ne 0 ]
}

@test "wt-new fetches before branching" {
  git clone --quiet "$REPO.origin" "$TMP/other"
  git -C "$TMP/other" -c user.email=o@example.com -c user.name=O commit --quiet --allow-empty -m newer
  git -C "$TMP/other" push --quiet origin main
  newer=$(git -C "$TMP/other" rev-parse HEAD)
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-b
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$newer" ]
}

@test "wt-new keeps the main checkout status clean" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-c
  [ "$status" -eq 0 ]
  [ -z "$(git -C "$REPO" status --porcelain)" ]
  grep -qxF '/.claude/worktrees/' "$REPO/.git/info/exclude"
}

@test "wt-new --detach --base SHA makes a detached worktree at that commit" {
  first=$(git rev-parse HEAD)
  git commit --quiet --allow-empty -m second
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" bisect-1 --detach --base "$first"
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$first" ]
  [ "$(git -C "$output" rev-parse --abbrev-ref HEAD)" = "HEAD" ]
}

@test "wt-new copies files named in .worktreeinclude" {
  printf 'secret.log\n' > .worktreeinclude
  git add .worktreeinclude && git commit --quiet -m include && git push --quiet origin main
  printf 'token\n' > secret.log
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-d
  [ "$status" -eq 0 ]
  [ "$(cat "$output/secret.log")" = "token" ]
}

@test "wt-new runs worktree.setup and writes the marker" {
  mkdir -p .claude
  printf 'worktree.setup: touch setup-ran\n' > .claude/kern.local.yml
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-e
  [ "$status" -eq 0 ]
  [ -f "$output/setup-ran" ]
  gitdir=$(git -C "$output" rev-parse --path-format=absolute --git-dir)
  grep -q '^setup: touch setup-ran$' "$gitdir/kern-setup-done"
}

@test "a failing worktree.setup exits 2" {
  mkdir -p .claude
  printf 'worktree.setup: exit 7\n' > .claude/kern.local.yml
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-f
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"worktree.setup failed"* ]] || false
}

@test "an existing branch is refused" {
  git branch kern/feat-g
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-g
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"branch exists"* ]] || false
}

@test "a branch.pattern placeholder wt-new cannot fill asks for --branch" {
  mkdir -p .claude
  printf 'branch.pattern: CDS-{n}/{slug}\n' > .claude/kern.local.yml
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-h
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--branch"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-h --branch CDS-1/feat-h
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse --abbrev-ref HEAD)" = "CDS-1/feat-h" ]
}

@test "a bad slug exits 2" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" '../escape'
  [ "$status" -eq 2 ]
}

@test "a slug with a non-ASCII letter exits 2 under a UTF-8 locale too" {
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" "caf$(printf '\303\251')"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"bad slug"* ]] || false
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$REPO" "caf$(printf '\303\251')"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"bad slug"* ]] || false
}

@test "no origin remote exits 2 with a message" {
  git remote remove origin
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-i --base main
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"git fetch origin main failed"* ]] || false
  [ ! -d "$REPO/.claude/worktrees/feat-i" ]
}

# A fetch failure names git's reason, the first line git prints for it: the last is the advice "and the
# repository exists.", which names none (Task 17a, C-M5).
@test "an unreachable origin or a missing branch exits 2 with git's reason" {
  git remote set-url origin "$TMP/nowhere"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-n --base main
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"git fetch origin main failed"*"does not appear to be a git repository"* ]] || false
  git remote set-url origin "$REPO.origin"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-n --base nosuch
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"git fetch origin nosuch failed"*"couldn't find remote ref"* ]] || false
  [ ! -e "$REPO/.claude/worktrees/feat-n" ]
}

# ssh prints a capitalised "Warning:" line, such as its first-connect host-key notice, before the reason
# (P8 review, Minor 1). The stub stands in for ssh, so nothing leaves the machine.
@test "a failed ssh fetch names the reason, not ssh's Warning line" {
  printf '%s\n' '#!/bin/sh' \
    "echo \"Warning: Permanently added 'github.com' (ED25519) to the list of known hosts.\" >&2" \
    'echo "git@github.com: Permission denied (publickey)." >&2' 'exit 255' > "$TMP/fake-ssh"
  chmod +x "$TMP/fake-ssh"
  git remote set-url origin git@github.invalid:kern/demo.git
  GIT_SSH_COMMAND="$TMP/fake-ssh" run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-ssh --base main
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"git fetch origin main failed (git@github.com: Permission denied (publickey).)"* ]] || false
  [[ "$stderr" != *"Permanently added"* ]] || false
}

# A single-branch clone fetches only its own branch by default, so wt-new names the refspec (C-M5).
@test "wt-new bases on another branch in a single-branch clone" {
  git checkout --quiet -b release
  git commit --quiet --allow-empty -m release
  git push --quiet origin release
  git checkout --quiet main
  git clone --quiet --single-branch -b main "$REPO.origin" "$TMP/single"
  cd "$TMP/single"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-o --detach --base release
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git -C "$REPO" rev-parse release)" ]
}

# X7 keeps the fresh origin base, so a local base with commits origin lacks stops wt-new instead of
# giving a worktree without them (Task 17a, C-I1; the user's decision 6, 2026-10-22).
@test "a local base ahead of origin exits 2 with the count, and a local base behind it does not" {
  git commit --quiet --allow-empty -m two
  git commit --quiet --allow-empty -m three
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-w
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"wt-new: local main is 2 commits ahead of origin/main; push, or pass --base <sha>"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-w --detach --base origin/main
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"local main is 2 commits ahead"* ]] || false
  [ ! -e "$REPO/.claude/worktrees" ]
  git push --quiet origin main
  git reset --quiet --hard HEAD~2
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-w
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse origin/main)" ]
}

# A .worktreeinclude entry such as .claude/ holds worktree.dir, so copying it would copy every worktree,
# their .git files too, into the new one (C-M6).
@test "a .worktreeinclude entry that holds worktree.dir is refused with a message" {
  printf '.claude/\nsecret.log\n' > .worktreeinclude
  git add .worktreeinclude && git commit --quiet -m include && git push --quiet origin main
  printf 'token\n' > secret.log
  mkdir -p .claude
  printf 'note\n' > .claude/notes.txt
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" one
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"wt: .worktreeinclude names .claude/, which holds the worktree dir .claude/worktrees; not copied"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" two
  [ "$status" -eq 0 ]
  [ ! -e "$output/.claude" ]
  [ "$(cat "$output/secret.log")" = "token" ]
}

@test "wt-new works when the repo path has a space" {
  SPACED="$TMP/my project"
  make_fixture "$SPACED"
  cd "$SPACED"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-j
  [ "$status" -eq 0 ]
  [ "$output" = "$SPACED/.claude/worktrees/feat-j" ]
}

@test "wt-check passes for a fresh kern worktree" {
  wt=$(bash "$KERN_ROOT/scripts/wt-new" feat-k)
  run bash "$KERN_ROOT/scripts/wt-check" "$wt" origin/main
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "wt-check rejects the main checkout" {
  run bash "$KERN_ROOT/scripts/wt-check" "$REPO" origin/main
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a linked worktree"* ]] || false
}

@test "wt-check rejects a base that is not an ancestor" {
  wt=$(bash "$KERN_ROOT/scripts/wt-new" feat-l)
  git checkout --quiet -b elsewhere
  git commit --quiet --allow-empty -m elsewhere
  run bash "$KERN_ROOT/scripts/wt-check" "$wt" elsewhere
  [ "$status" -eq 1 ]
  [[ "$output" == *"not an ancestor"* ]] || false
}

@test "wt-check rejects a worktree without the setup marker" {
  wt=$(bash "$KERN_ROOT/scripts/wt-new" feat-m)
  rm "$(git -C "$wt" rev-parse --path-format=absolute --git-dir)/kern-setup-done"
  run bash "$KERN_ROOT/scripts/wt-check" "$wt" origin/main
  [ "$status" -eq 1 ]
  [[ "$output" == *"setup marker missing"* ]] || false
}

# wt-new creates a worktree from base_branch, worktree.dir and branch.pattern, so it does not act on one
# a settings file it cannot read may set (Task 16l, fix round 2).
@test "wt-new exits 2 and creates nothing while a settings file that could set its keys cannot be read" {
  load ../helpers/common
  mkdir -p "$REPO/.claude"
  printf 'worktree.dir: ../elsewhere\n' >"$REPO/.claude/kern.local.yml"
  read_fails awk "$REPO/.claude/kern.local.yml"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-u
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"base_branch is unknown"*"kern.local.yml could not be read"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-u --base main
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"worktree.dir may not be the whole answer"* ]] || false
  [ "$(git -C "$REPO" worktree list | wc -l | tr -d ' ')" = 1 ]
  [ ! -e "$REPO/.claude/worktrees" ]
}

# A plan's header names its base with the source after it, as `base: main (settings); promotion: none`
# (Task 16n), and execute-plan step 5 passes the plan, so the script, not the model, drops the source.
# release_on_origin: a release branch one commit past main on origin, and origin/HEAD pointed at it, so a
# base read from the plan differs from the one detection would give.
release_on_origin() {
  git checkout --quiet -b release
  git commit --quiet --allow-empty -m release
  git push --quiet origin release
  git checkout --quiet main
  git remote set-head origin release
}

@test "wt-new --plan takes a plan with base: main (settings) as main" {
  release_on_origin
  printf -- '---\nstatus: approved\nbase: main (settings); promotion: none\nexecution: inline\n---\n\n# Plan\n' > "$TMP/plan.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-p --plan "$TMP/plan.md"
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse origin/main)" ]
  [ "$(git rev-parse origin/main)" != "$(git rev-parse origin/release)" ]
}

@test "wt-new --plan drops a source that holds a semicolon, and reads the header form without a source" {
  release_on_origin
  git remote set-head origin main
  printf -- '---\nbase: release (current branch; not detected); promotion: none\n---\n' > "$TMP/a.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-q --plan "$TMP/a.md"
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse origin/release)" ]
  printf -- '---\r\nbase: release; promotion: none\r\n---\r\n' > "$TMP/b.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-r --plan "$TMP/b.md"
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse origin/release)" ]
}

@test "wt-new --plan with an unknown base falls back as with no --base, and exits 2 when nothing names one" {
  printf -- '---\nbase: unknown (detached HEAD; not detected); promotion: none\n---\n' > "$TMP/plan.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-s --plan "$TMP/plan.md"
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse origin/main)" ]
  git remote set-head origin --delete
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-t --plan "$TMP/plan.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"base_branch is not set and not detectable"* ]] || false
}

@test "wt-new --plan refuses a missing plan, and --plan with a --base that is not a SHA" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-v --plan "$TMP/none.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no plan at $TMP/none.md"* ]] || false
  printf -- '---\nbase: main (settings)\n---\n' > "$TMP/plan.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-v --plan "$TMP/plan.md" --base main
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--base takes a commit SHA"*"usage"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-v --base main --plan "$TMP/plan.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-v --base "$(git rev-parse HEAD)" --plan "$TMP/none.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no plan at $TMP/none.md"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-v --plan "$TMP/plan.md" --base deadbeef0
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"unknown commit deadbeef0"* ]] || false
  [ ! -e "$REPO/.claude/worktrees/feat-v" ]
}

# The escape the ahead-of-origin stop names, for execute-plan step 5, which passes the plan (C-I1).
@test "wt-new --plan with --base SHA builds on that commit, in either order" {
  git commit --quiet --allow-empty -m local-only
  printf -- '---\nbase: main (settings); promotion: none\n---\n' > "$TMP/plan.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-x --plan "$TMP/plan.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"local main is 1 commits ahead of origin/main"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-x --plan "$TMP/plan.md" --base "$(git rev-parse HEAD)"
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse main)" ]
  [ "$(git -C "$output" rev-parse --abbrev-ref HEAD)" = "kern/feat-x" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" feat-y --base "$(git rev-parse --short HEAD)" --plan "$TMP/plan.md"
  [ "$status" -eq 0 ]
  [ "$(git -C "$output" rev-parse HEAD)" = "$(git rev-parse main)" ]
}
