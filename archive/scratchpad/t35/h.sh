# shellcheck shell=bash
# Differential harness for Task 35: base (3c66863 archive) against a head tree, same payload.
# Usage: . h.sh; setup_env; cmp_cmd CMD [SNAPSHOT]
T35=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35
BASE=${BASE:-$T35/base}
HEAD=${HEAD:-/Users/musta/Code/projects/kern}
BASH_BIN=${BASH_BIN:-/bin/bash}

setup_env() {
  W=$(mktemp -d "$T35/w.XXXXXX")
  BATS_TEST_TMPDIR=$W
  # shellcheck disable=SC1091
  . "$BASE/tests/helpers/common.bash"
  R="$W/repo"
  make_repo "$R" >/dev/null 2>&1
  git -C "$R" worktree add -q -b feat "$W/wt" >/dev/null 2>&1
  export HOME="$W/home"
  export CLAUDE_PLUGIN_DATA="$W/data"
  mkdir -p "$HOME/.claude/shell-snapshots" "$CLAUDE_PLUGIN_DATA/sessions"
  unset CLAUDE_CODE_ENTRYPOINT
  export CWD="$R"
  SD="$CLAUDE_PLUGIN_DATA/sessions"
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\ndeploy.envs: production\nprotected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  for d in "$R" "$W/wt"; do
    mkdir -p "$d/docs/plans" "$d/src"
    printf -- '---\nstatus: draft\n---\n# x\n' >"$d/docs/plans/x.md"
  done
  # feat holds another author's commit, so a lease push of feat is denied interactively.
  git -C "$W/wt" -c user.email=other@example.com -c user.name=Other commit -q --allow-empty -m "other: work"
  git -C "$W/wt" push -q origin feat >/dev/null 2>&1
  # The worktree has an AWS key staged.
  printf 'key = AKIA%s\n' ABCDEFGHIJKLMNOP >"$W/wt/creds.txt"
  git -C "$W/wt" add creds.txt
  echo '{}' >"$HOME/.claude/settings.json"
}

json_str() {
  printf '%s' "$1" | /usr/bin/python3 -I -c 'import json,sys; s=sys.stdin.read(); print(json.dumps(s)[1:-1], end="")'
}

payload_of() {
  printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$CWD" "$(json_str "$1")"
}

dec() { printf '%s' "$1" | sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p'; }
why() { printf '%s' "$1" | sed -n 's/.*"permissionDecisionReason":"\(.*\)"}}.*/\1/p' | cut -c1-220; }
rank() { case "$1" in deny) echo 3 ;; ask) echo 2 ;; "") echo 1 ;; allow) echo 0 ;; *) echo 9 ;; esac; }

autopilot() {
  printf 'voice: normal\nsurface: auto\nautopilot: %s\nsince: 2026-10-12T00:00:00Z\n' "$1" \
    >"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
}

run_tree() { # TREE CMD SNAP
  local p
  p=$(payload_of "$2")
  if [ -n "$3" ]; then
    env KERN_SHELL_SNAPSHOT="$3" KERN_GUARDS= "$BASH_BIN" "$1/hooks/pre-tool-use" <<<"$p" 2>&1
  else
    env -u KERN_SHELL_SNAPSHOT KERN_GUARDS= "$BASH_BIN" "$1/hooks/pre-tool-use" <<<"$p" 2>&1
  fi
}

# cmp_cmd CMD SNAP: one line: tag base head | cmd; reasons on any change.
cmp_cmd() {
  local c="$1" snap="${2-}" b h rb rh tag
  b=$(run_tree "$BASE" "$c" "$snap")
  h=$(run_tree "$HEAD" "$c" "$snap")
  rb=$(rank "$(dec "$b")"); rh=$(rank "$(dec "$h")")
  tag=same
  [ "$rh" -lt "$rb" ] && tag=LOOSER
  [ "$rh" -gt "$rb" ] && tag=tighter
  [ -z "$(dec "$b")" ] && [ -n "$b" ] && tag="ERROR-base"
  [ -z "$(dec "$h")" ] && [ -n "$h" ] && tag="ERROR-head"
  printf '%-10s base=%-5s head=%-5s | %s\n' "$tag" "$(dec "$b")" "$(dec "$h")" "${c//$'\n'/⏎}"
  if [ "$tag" != same ] || [ "${VERBOSE-}" = 1 ]; then
    printf '           base: %s\n           head: %s\n' "$(why "$b")" "$(why "$h")"
  fi
}
