# shellcheck shell=bash
# PreToolUse votes. Each guard calls `vote`; the dispatcher calls `emit_decision` once.
# Needs json.sh. Reads AUTOPILOT (1 under autopilot).

_KERN_VOTE=""
_KERN_R_DENY=""
_KERN_R_ASK=""
_KERN_R_ALLOW=""

# vote allow|ask|deny GUARD REASON: keeps the strictest decision (deny > ask > allow).
vote() {
  local d="$1" line="$2: $3"
  case "$d" in
    deny)
      _KERN_VOTE=deny
      _KERN_R_DENY="${_KERN_R_DENY:+$_KERN_R_DENY; }$line"
      ;;
    allow)
      [ -z "$_KERN_VOTE" ] && _KERN_VOTE=allow
      _KERN_R_ALLOW="${_KERN_R_ALLOW:+$_KERN_R_ALLOW; }$line"
      ;;
    *)
      [ "$_KERN_VOTE" != deny ] && _KERN_VOTE=ask
      _KERN_R_ASK="${_KERN_R_ASK:+$_KERN_R_ASK; }$line"
      ;;
  esac
}

# fail_closed REASON: input could not be parsed; never allow.
fail_closed() {
  vote ask G0 "$1"
}

# KERN_ASK_PREFIX opens every ask reason. Under -p or the SDK, Claude Code turns an ask into a denial and the
# model reads only the reason, so the reason says the user's approval is needed (task-16-diagnosis X5).
# pre-tool-use's no_lib writes the same words without this library.
KERN_ASK_PREFIX='needs user approval: '

# emit_decision: prints the PreToolUse JSON for the strictest vote, or nothing when nobody voted.
emit_decision() {
  local d="$_KERN_VOTE" r p=""
  [ -n "$d" ] || return 0
  case "$d" in
    deny) r="$_KERN_R_DENY" ;;
    ask) r="$_KERN_R_ASK" p="$KERN_ASK_PREFIX" ;;
    *) r="$_KERN_R_ALLOW" ;;
  esac
  if [ "$d" = ask ] && [ "${AUTOPILOT:-0}" = 1 ]; then
    d=deny p=""
    r="$r (autopilot: nobody to ask)"
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' \
    "$d" "$(printf '%skern %s' "$p" "$r" | json_escape)"
}
