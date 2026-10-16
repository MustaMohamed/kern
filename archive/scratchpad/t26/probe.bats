#!/usr/bin/env bats
# The exact commands commit and finish-branch prescribe, run through kern's guards under autopilot from
# a linked worktree, with a gh stub. A skill command a guard would deny cannot run unattended.

load /Users/musta/Code/projects/kern/tests/helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  R=$(cd "$R" && pwd -P)
  W="$R/.claude/worktrees/fx"
  git -C "$R" worktree add -q -b feat/x "$W" main
  kern_env "$W"
  set_autopilot on
  mkdir -p "$R/.kern/tmp" "$R/.git/info"
  printf '/.kern/\n/.claude/worktrees/\n' >>"$R/.git/info/exclude"
  printf 'feat: add x\n\nWhy it matters.\n' >"$R/.kern/tmp/commit-msg"
  printf '## Why\n\nx\n' >"$R/.kern/tmp/pr-body.md"
  printf 'x\n' >"$W/x.txt"
  git -C "$W" add x.txt
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat >"$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/gh.log"
case "$1 $2" in "pr list") [ -n "${GH_STATES-}" ] && printf '%s\n' "$GH_STATES" ;; esac
exit 0
GH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

decide() { run_guard "$(bash_payload "$1")"; echo "rc=$status out=$(decision_of "$output")"; }
@test "probe" {
  for ap in on off; do
    set_autopilot $ap
    echo "== autopilot $ap" >&3
    for c in \
      "git -C $W status --porcelain" \
      "git -C $W rev-parse --show-toplevel" \
      "git -C $W diff --staged --stat" \
      "git -C $W rev-parse HEAD^{tree}" \
      "git -C $W log --format=%s -30" \
      "git -C $W rev-parse --abbrev-ref HEAD" \
      "git -C $W add -- x.txt" \
      "git -C $W add -A" \
      "git -C $W commit -F $R/.kern/tmp/commit-msg" \
      "bash /Users/musta/Code/projects/kern/scripts/kern-dir tmp" \
      "gh pr list --head feat/x --state all --json number,state,headRefOid,url" \
      "gh pr list --head feat/x --state all --json number,state,headRefOid,url 2>&1" \
      "git remote get-url origin" \
      "git fetch origin main" \
      "git push -u origin feat/x" \
      "gh pr create --draft --title 'feat: it'\\''s x' --base main --body-file $R/.kern/tmp/pr-body.md" \
      "gh pr create --draft --title 'feat: add x' --base main --body-file $R/.kern/tmp/pr-body.md" ; do
      echo "$(decide "$c")  <= $c" >&3
    done
  done
}
