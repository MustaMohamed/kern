# shellcheck shell=bash
# G14 tracker and chat writes: MCP write tools on tracker or chat servers, and gh issue writes.
# Chat messages are a floor action (messaging people): tracker.policy never makes them auto.
# An allow approves the whole call, so tracker.policy auto allows an MCP write only by its exact
# name on its family's closed list (_g14_listed), and a gh write only in the shape _g14_proven
# accepts (the _gh_* helpers are in g02-pr.sh, _GH_COMMENT_* in g03-review.sh); any other write asks.

KERN_G14_TRACKERS="linear jira atlassian asana github gitlab notion monday clickup todoist trello shortcut height zendesk"
KERN_G14_CHAT="slack gmail discord teams intercom front mail telegram whatsapp"
KERN_G14_VERBS="create save update delete remove comment post send merge transition move assign archive edit write add set upload submit resolve share invite publish label close reopen mark reply push run rerun retry play fork schedule duplicate restore unshare"
_G14_ALNUM=abcdefghijklmnopqrstuvwxyz0123456789

# The MCP tools tracker.policy auto may allow, by exact name, for each family: issue, comment, label
# and project writes only. Code hosting, CI, release, sharing, agent-trigger, attachment and delete
# tools are left out; the allow reads the name, not the arguments. A family whose tool names kern
# has no source for (jira, atlassian, asana, gitlab, monday, clickup, todoist, trello, shortcut,
# height, zendesk, and mcp.write_servers) has no list, so its writes ask.
# github: github-mcp-server's issue tools, as listed in the M1 Task 13 review.
_G14_GITHUB="create_issue update_issue add_issue_comment issue_write sub_issue_write label_write"
# linear: the claude.ai Linear connector's tool names (create_issue_label is the deprecated form of
# save_issue_label).
_G14_LINEAR="save_issue save_comment create_issue_label save_issue_label save_project save_milestone"
# notion: the claude.ai Notion connector's tool names. Its page tools can delete content, share or
# mark a page as a skill, so only the comment is listed.
_G14_NOTION="notion-create-comment"

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
_GH_REPO_OPTS="repo/R/v help/h/b"
_GH_LABEL_CREATE_OPTS="color/c/v description/d/v force/f/b repo/R/v help/h/b"
_GH_LABEL_EDIT_OPTS="color/c/v description/d/v name/n/v repo/R/v help/h/b"

guard_g14() {
  case "$TOOL" in
    mcp__*) _g14_mcp ;;
    Bash) _g14_gh ;;
  esac
}

# _g14_has_word STR WORDS: one of the space-separated WORDS appears anywhere in STR.
_g14_has_word() {
  local w
  for w in $2; do
    case "$1" in *"$w"*) return 0 ;; esac
  done
  return 1
}

# A server is a tracker or chat server when it holds one of their words anywhere, so a write on it
# votes; an allow needs the family as a whole word of the server name (claude_ai_Linear is claude,
# ai, linear) and the tool's exact name on that family's list.
_g14_mcp() {
  local rest name srv words plain kind="" extra ok=0
  rest=${TOOL#mcp__}
  name=${rest#*__}
  # Lowercased: the server, the tool name with camelCase split (createJiraIssue), and the tool name
  # unsplit, so a split never hides a verb (reOpen_issue).
  {
    IFS= read -r srv
    IFS= read -r words
    IFS= read -r plain
  } <<EOT
$(printf '%s\n%s\n%s\n' "${rest%%__*}" "$name" "$name" |
    LC_ALL=C sed '2s/\([a-z0-9]\)\([A-Z]\)/\1 \2/g; 2s/\([A-Z]\)\([A-Z][a-z]\)/\1 \2/g' |
    LC_ALL=C tr '[:upper:]' '[:lower:]')
EOT
  _g14_has_word "$srv" "$KERN_G14_CHAT" && kind=chat
  [ -z "$kind" ] && _g14_has_word "$srv" "$KERN_G14_TRACKERS" && kind=tracker
  if [ -z "$kind" ]; then
    extra=$(settings_get mcp.write_servers '' | tr '[:upper:]' '[:lower:]' | tr ',' ' ')
    [ -n "$extra" ] && _g14_has_word "$srv" "$extra" && kind=tracker
  fi
  [ -n "$kind" ] || return 0
  _g14_is_write "$words $plain" || return 0
  [ "$kind" = tracker ] && _g14_listed "$srv" "$name" && ok=1
  _g14_decide "$kind" "$TOOL" "$ok" "is not on tracker.policy auto's list: the issue, comment, label and project tools of a tracker kern knows"
}

# _g14_is_write WORDS: any word of WORDS, split on every character but a-z and 0-9, is a write verb.
_g14_is_write() {
  local part
  for part in ${1//[!$_G14_ALNUM]/ }; do
    case " $KERN_G14_VERBS " in *" $part "*) return 0 ;; esac
  done
  return 1
}

# _g14_listed SERVER NAME: SERVER (lowercased) has exactly one tracker family among its words, split
# on every character but a-z and 0-9, and NAME is on that family's list, byte for byte.
_g14_listed() {
  local toks=" ${1//[!$_G14_ALNUM]/ } " w fam="" n=0 list
  for w in $KERN_G14_TRACKERS; do
    case "$toks" in *" $w "*) fam=$w; n=$((n + 1)) ;; esac
  done
  [ "$n" = 1 ] || return 1
  case "$fam" in
    github) list=$_G14_GITHUB ;;
    linear) list=$_G14_LINEAR ;;
    notion) list=$_G14_NOTION ;;
    *) return 1 ;;
  esac
  for w in $list; do
    [ "$w" = "$2" ] && return 0
  done
  return 1
}

# _g14_decide KIND WHAT PROVEN [WHY]: tracker.policy auto allows a tracker write only when PROVEN is
# 1; otherwise it asks with "WHAT WHY", WHY saying what auto allows.
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
      if [ "$3" = 1 ]; then
        vote allow G14 "tracker.policy auto: $2"
      else
        vote ask G14 "$2 $4"
      fi
      ;;
    deny) vote deny G14 "tracker.policy deny" ;;
    *) vote ask G14 "$2 writes to the tracker" ;;
  esac
}

# Only a command whose text holds gh, or g and h apart by quotes or a backslash (g''h), is parsed,
# as in _g02_hidden: no other command costs a process past reading it.
_g14_gh() {
  local cmd sub i=0
  cmd=$(ti_get command) || return 0
  case "$cmd" in *[Gg][Hh]* | *[Gg][\"\'\\]*[Hh]*) ;; *) return 0 ;; esac
  _gh_load "$cmd"
  while [ "$i" -lt "${#_GH_RECS[@]}" ]; do
    sub=$(gh_sub "${_GH_RECS[$i]}")
    case "$sub" in
      "issue create" | "issue new" | "issue comment" | "issue edit" | "issue close" | "issue reopen" | "issue transfer" | "issue lock" | "label create" | "label edit")
        if _g14_proven "$i" "$sub"; then
          _g14_decide tracker "gh $sub" 1
        else
          _g14_decide tracker "gh $sub" 0 "in a shape kern cannot check; tracker.policy auto allows only \`gh issue|label <verb>\` alone, in this repo, with literal words and any --body-file in the repo"
        fi
        ;;
      # Deletes always ask, and kern has no proof for the others.
      "issue delete" | "label delete" | "issue develop" | "issue pin" | "issue unpin" | "issue unlock" | "label clone")
        _g14_decide tracker "gh $sub" 0 "always asks: tracker.policy auto does not cover it"
        ;;
    esac
    i=$((i + 1))
  done
}

# _g14_proven IDX SUB: the gh record at IDX in _GH_RECS, a SUB write, may be allowed as the whole
# Bash call: _gh_proven, only SUB's safe options (none names a repo, so -R and --repo fail here), its
# arguments (none for issue create or new, one label name for a label verb, else one issue number: a
# URL may name another repo), and a --body-file that passes _gh_file_ok.
_g14_proven() {
  local opts safe toks pos file
  case "$2" in
    "issue create" | "issue new") opts=$_GH_ISSUE_CREATE_OPTS; safe="title body-file label milestone project type" ;;
    "issue comment") opts=$_GH_COMMENT_OPTS; safe=$_GH_COMMENT_SAFE ;;
    "issue edit")
      opts=$_GH_ISSUE_EDIT_OPTS
      safe="title body-file add-label remove-label milestone remove-milestone add-project remove-project type remove-type remove-assignee"
      ;;
    "issue close") opts=$_GH_ISSUE_CLOSE_OPTS; safe="reason" ;;
    "issue reopen") opts=$_GH_ISSUE_REOPEN_OPTS; safe="" ;;
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
    "issue create" | "issue new") [ -z "$pos" ] || return 1 ;;
    "label "*) [ -n "$pos" ] && [ "$(printf '%s\n' "$pos" | wc -l)" -eq 1 ] || return 1 ;;
    *) case "$pos" in "" | *[!0-9]*) return 1 ;; esac ;;
  esac
  file=$(_gh_last "$toks" body-file) || file=""
  [ -z "$file" ] || _gh_file_ok "$file"
}
