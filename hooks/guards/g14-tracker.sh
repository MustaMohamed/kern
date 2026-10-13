# shellcheck shell=bash
# G14 tracker and chat writes: MCP write tools on tracker or chat servers, and gh issue writes.
# Chat messages are a floor action (messaging people): tracker.policy never makes them auto.
# An allow approves the whole Bash call, so tracker.policy auto allows a gh write only in the shape
# _g14_proven accepts (the _gh_* helpers are in g02-pr.sh, _GH_COMMENT_* in g03-review.sh); any
# other gh write asks.

KERN_G14_TRACKERS="linear jira atlassian asana github gitlab notion monday clickup todoist trello shortcut height zendesk"
KERN_G14_CHAT="slack gmail discord teams intercom front mail telegram whatsapp"
KERN_G14_VERBS="create save update delete remove comment post send merge transition move assign archive edit write add set upload submit resolve share invite publish label close reopen mark reply"

# gh option tables for _gh_opts (gh 2.100.0 `--help`), and the options an allowed write may carry.
# Left out of the safe sets: options that read a local file (attach, recover, a body file outside
# _gh_file_ok), take the body from elsewhere or inline (template, body: G4 asks for a file), open an
# editor or a browser, name another repo (repo, and the number-or-URL links), or assign (@copilot
# starts an agent).
_GH_ISSUE_CREATE_OPTS="assignee/a/v attach/-/v blocked-by/-/v blocking/-/v body/b/v body-file/F/v \
editor/e/b label/l/v milestone/m/v parent/-/v project/p/v recover/-/v template/T/v title/t/v type/-/v \
web/w/b repo/R/v help/h/b"
_GH_ISSUE_EDIT_OPTS="add-assignee/-/v add-blocked-by/-/v add-blocking/-/v add-label/-/v add-project/-/v \
add-sub-issue/-/v attach/-/v body/b/v body-file/F/v milestone/m/v parent/-/v remove-assignee/-/v \
remove-blocked-by/-/v remove-blocking/-/v remove-label/-/v remove-milestone/-/b remove-parent/-/b \
remove-project/-/v remove-sub-issue/-/v remove-type/-/b title/t/v type/-/v repo/R/v help/h/b"
_GH_ISSUE_CLOSE_OPTS="comment/c/v duplicate-of/-/v reason/r/v repo/R/v help/h/b"
_GH_ISSUE_REOPEN_OPTS="comment/c/v repo/R/v help/h/b"
_GH_ISSUE_LOCK_OPTS="reason/r/v repo/R/v help/h/b"
_GH_YES_OPTS="yes/-/b repo/R/v help/h/b"
_GH_REPO_OPTS="repo/R/v help/h/b"
_GH_LABEL_CREATE_OPTS="color/c/v description/d/v force/f/b repo/R/v help/h/b"
_GH_LABEL_EDIT_OPTS="color/c/v description/d/v name/n/v repo/R/v help/h/b"

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

# _g14_decide KIND WHAT [PROVEN]: tracker.policy auto allows only when PROVEN is 1 (the default: an
# MCP tool's shape is its name).
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
    auto)
      if [ "${3:-1}" = 1 ]; then
        vote allow G14 "tracker.policy auto: $2"
      else
        vote ask G14 "$2 in a shape kern cannot check; tracker.policy auto allows only \`gh issue|label <verb>\` alone, in this repo, with literal words and any --body-file in the repo"
      fi
      ;;
    deny) vote deny G14 "tracker.policy deny" ;;
    *) vote ask G14 "$2 writes to the tracker" ;;
  esac
}

_g14_gh() {
  local cmd sub i=0
  cmd=$(ti_get command) || return 0
  _gh_load "$cmd"
  while [ "$i" -lt "${#_GH_RECS[@]}" ]; do
    sub=$(gh_sub "${_GH_RECS[$i]}")
    case "$sub" in
      "issue create" | "issue comment" | "issue edit" | "issue close" | "issue reopen" | "issue delete" | "issue transfer" | "issue lock" | "label create" | "label edit" | "label delete")
        if _g14_proven "$i" "$sub"; then
          _g14_decide tracker "gh $sub" 1
        else
          _g14_decide tracker "gh $sub" 0
        fi
        ;;
    esac
    i=$((i + 1))
  done
}

# _g14_proven IDX SUB: the gh record at IDX in _GH_RECS, a SUB write, may be allowed as the whole
# Bash call: _gh_proven, only SUB's safe options (none names a repo, so -R and --repo fail here), its
# arguments (none for issue create, one label name for a label verb, else one issue number: a URL
# may name another repo), and a --body-file that passes _gh_file_ok.
_g14_proven() {
  local opts safe toks pos file
  case "$2" in
    "issue create") opts=$_GH_ISSUE_CREATE_OPTS; safe="title body-file label milestone project type" ;;
    "issue comment") opts=$_GH_COMMENT_OPTS; safe=$_GH_COMMENT_SAFE ;;
    "issue edit")
      opts=$_GH_ISSUE_EDIT_OPTS
      safe="title body-file add-label remove-label milestone remove-milestone add-project remove-project type remove-type remove-assignee"
      ;;
    "issue close") opts=$_GH_ISSUE_CLOSE_OPTS; safe="reason" ;;
    "issue reopen") opts=$_GH_ISSUE_REOPEN_OPTS; safe="" ;;
    "issue delete" | "label delete") opts=$_GH_YES_OPTS; safe="yes" ;;
    "issue transfer") opts=$_GH_REPO_OPTS; safe="" ;;
    "issue lock") opts=$_GH_ISSUE_LOCK_OPTS; safe="reason" ;;
    "label create") opts=$_GH_LABEL_CREATE_OPTS; safe="color description force" ;;
    "label edit") opts=$_GH_LABEL_EDIT_OPTS; safe="color description name" ;;
    *) return 1 ;;
  esac
  toks=$(_gh_args "${_GH_RECS[$1]}" 2 | _gh_opts "$opts")
  _gh_proven "$1" "$toks" && _gh_only "$toks" "$safe" || return 1
  pos=$(_gh_pos "$toks")
  case "$2" in
    "issue create") [ -z "$pos" ] || return 1 ;;
    "label "*) [ -n "$pos" ] && [ "$(printf '%s\n' "$pos" | wc -l)" -eq 1 ] || return 1 ;;
    *) case "$pos" in "" | *[!0-9]*) return 1 ;; esac ;;
  esac
  file=$(_gh_last "$toks" body-file) || file=""
  [ -z "$file" ] || _gh_file_ok "$file"
}
