# shellcheck shell=bash
# G14 tracker and chat writes: MCP write tools on tracker or chat servers, and gh issue writes.
# Chat messages are a floor action (messaging people): tracker.policy never makes them auto.

KERN_G14_TRACKERS="linear jira atlassian asana github gitlab notion monday clickup todoist trello shortcut height zendesk"
KERN_G14_CHAT="slack gmail discord teams intercom front mail telegram whatsapp"
KERN_G14_VERBS="create save update delete remove comment post send merge transition move assign archive edit write add set upload submit resolve share invite publish label close reopen mark reply"

guard_g14() {
  case "$TOOL" in
    mcp__*) _g14_mcp ;;
    Bash) _g14_gh ;;
  esac
}

_g14_has_word() {
  local w
  for w in $2; do
    case "$1" in *"$w"*) return 0 ;; esac
  done
  return 1
}

_g14_mcp() {
  local server action kind="" extra
  server=$(printf '%s' "${TOOL#mcp__}" | sed 's/__.*//' | tr '[:upper:]' '[:lower:]')
  action=$(printf '%s' "${TOOL##*__}" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
  _g14_has_word "$server" "$KERN_G14_CHAT" && kind=chat
  [ -z "$kind" ] && _g14_has_word "$server" "$KERN_G14_TRACKERS" && kind=tracker
  extra=$(settings_get mcp.write_servers '' | tr '[:upper:]' '[:lower:]' | tr ',' ' ')
  [ -z "$kind" ] && [ -n "$extra" ] && _g14_has_word "$server" "$extra" && kind=tracker
  [ -n "$kind" ] || return 0
  _g14_is_write "$action" || return 0
  _g14_decide "$kind" "$TOOL"
}

# _g14_is_write ACTION: any `_`-separated word of ACTION is a write verb.
_g14_is_write() {
  local part
  for part in $(printf '%s' "$1" | tr '_' ' '); do
    case " $KERN_G14_VERBS " in *" $part "*) return 0 ;; esac
  done
  return 1
}

_g14_decide() {
  if [ "$AUTOPILOT" = 1 ]; then
    vote deny G14 "$2 under autopilot: tracker and chat writes stay human"
    return 0
  fi
  if [ "$1" = chat ]; then
    vote ask G14 "$2 sends a message to people"
    return 0
  fi
  case "$(policy_for tracker)" in
    auto) vote allow G14 "tracker.policy auto: $2" ;;
    deny) vote deny G14 "tracker.policy deny" ;;
    *) vote ask G14 "$2 writes to the tracker" ;;
  esac
}

_g14_gh() {
  local cmd seg
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    case "$(gh_sub "$seg")" in
      "issue create" | "issue comment" | "issue edit" | "issue close" | "issue reopen" | "issue delete" | "issue transfer" | "issue lock" | "label create" | "label edit" | "label delete")
        _g14_decide tracker "gh $(gh_sub "$seg")"
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}
