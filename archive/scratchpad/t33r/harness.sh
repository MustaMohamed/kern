# shellcheck shell=bash
# Differential harness: runs base (770a9f8) and head (bb74e68) hooks on the same payload.
# Usage: . harness.sh; setup_env; cmp_cmd "CMD" [SNAPSHOT]
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
BASE=$T33/base
HEAD=$T33/head
BASH_BIN=${BASH_BIN:-/bin/bash}

setup_env() {
  W=$(mktemp -d "$T33/w.XXXXXX")
  BATS_TEST_TMPDIR=$W
  # shellcheck disable=SC1091
  . "$HEAD/tests/helpers/common.bash"
  R="$W/repo"
  make_repo "$R" >/dev/null 2>&1
  git -C "$R" worktree add -q -b feat "$W/wt" >/dev/null 2>&1
  export HOME="$W/home"
  export CLAUDE_PLUGIN_DATA="$W/data"
  mkdir -p "$HOME/.claude/shell-snapshots" "$CLAUDE_PLUGIN_DATA"
  unset CLAUDE_CODE_ENTRYPOINT
  export CWD="$R"
}

# json_str S: S as a JSON string body (escapes \ " and control chars).
json_str() {
  printf '%s' "$1" | /usr/bin/python3 -I -c 'import json,sys; s=sys.stdin.read(); print(json.dumps(s)[1:-1], end="")'
}

payload_of() {
  printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$CWD" "$(json_str "$1")"
}

dec() { printf '%s' "$1" | sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p'; }
why() { printf '%s' "$1" | sed -n 's/.*"permissionDecisionReason":"\(.*\)"}}.*/\1/p' | cut -c1-160; }
rank() { case "$1" in deny) echo 3 ;; ask) echo 2 ;; "") echo 1 ;; allow) echo 0 ;; *) echo 9 ;; esac; }

autopilot() {
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  printf 'voice: normal\nsurface: auto\nautopilot: %s\nsince: 2026-10-12T00:00:00Z\n' "$1" \
    >"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
}

# cmp_cmd CMD SNAP: prints one line: verdict base head; LOOSER when head ranks below base.
cmp_cmd() {
  local c="$1" snap="${2-}" p b h rb rh tag
  p=$(payload_of "$c")
  b=$(env -u KERN_SHELL_SNAPSHOT KERN_GUARDS= "$BASH_BIN" "$BASE/hooks/pre-tool-use" <<<"$p" 2>&1)
  [ "${COLD-}" = 1 ] && rm -f "$CLAUDE_PLUGIN_DATA/sessions/aliases.cache"
  h=$(env KERN_SHELL_SNAPSHOT="$snap" KERN_GUARDS= "$BASH_BIN" "$HEAD/hooks/pre-tool-use" <<<"$p" 2>&1)
  rb=$(rank "$(dec "$b")"); rh=$(rank "$(dec "$h")")
  tag=same
  [ "$rh" -lt "$rb" ] && tag=LOOSER
  [ "$rh" -gt "$rb" ] && tag=tighter
  [ "$rb" = 9 ] || [ "$rh" = 9 ] && tag=ERROR
  [ -z "$(dec "$b")" ] && [ -n "$b" ] && tag="ERROR-base"
  [ -z "$(dec "$h")" ] && [ -n "$h" ] && tag="ERROR-head"
  printf '%-8s base=%-5s head=%-5s | %s\n' "$tag" "$(dec "$b")" "$(dec "$h")" "$c"
  if [ "$tag" = LOOSER ] || [ "${VERBOSE-}" = 1 ]; then
    printf '         base: %s\n         head: %s\n' "$(why "$b")" "$(why "$h")"
  fi
}

# cmp2 CMD [SNAP]: like cmp_cmd, but base and head both read SNAP (or no snapshot).
cmp2() {
  local c="$1" snap="${2:-/nonexistent}" p b h rb rh tag
  p=$(payload_of "$c")
  b=$(env KERN_SHELL_SNAPSHOT="$snap" KERN_GUARDS= "$BASH_BIN" "$BASE/hooks/pre-tool-use" <<<"$p" 2>&1)
  h=$(env KERN_SHELL_SNAPSHOT="$snap" KERN_GUARDS= "$BASH_BIN" "$HEAD/hooks/pre-tool-use" <<<"$p" 2>&1)
  rb=$(rank "$(dec "$b")"); rh=$(rank "$(dec "$h")")
  tag=same
  [ "$rh" -lt "$rb" ] && tag=LOOSER
  [ "$rh" -gt "$rb" ] && tag=tighter
  { [ "$rb" = 9 ] || [ "$rh" = 9 ]; } && tag=ERROR
  printf '%-8s base=%-5s head=%-5s | %s\n' "$tag" "$(dec "$b")" "$(dec "$h")" "$c"
  if [ "$tag" != same ] || [ "${VERBOSE-}" = 1 ]; then
    printf '         base: %s\n         head: %s\n' "$(why "$b")" "$(why "$h")"
  fi
}
