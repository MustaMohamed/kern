# shellcheck shell=bash
# G14 tracker and chat writes: MCP write tools on tracker or chat servers, and gh issue writes.
# Chat messages are a floor action (messaging people): tracker.policy never makes them auto.
# An allow approves the whole call, so tracker.policy auto allows an MCP write only by its exact
# name on its family's closed list, with its arguments proven (_g14_mcp_proven), and a gh write only
# in the shape _g14_proven accepts (the _gh_* helpers are in g02-pr.sh, _GH_COMMENT_* in
# g03-review.sh); any other write asks.

KERN_G14_TRACKERS="linear jira atlassian asana github gitlab notion monday clickup todoist trello shortcut height zendesk"
KERN_G14_CHAT="slack gmail discord teams intercom front mail telegram whatsapp"
KERN_G14_VERBS="create save update delete remove comment post send merge transition move assign archive edit write add set upload submit resolve share invite publish label close reopen mark reply push run rerun retry play fork schedule duplicate restore unshare request dismiss manage star cancel spawn stop convert"
# A tool name whose first word is one of these reads, and never votes (get_workflow_run).
KERN_G14_READS="get list search read fetch query find view show describe count check export"
_G14_ALNUM=abcdefghijklmnopqrstuvwxyz0123456789
# tracker.policy, read once per hook call by _g14_policy.
_G14_POLICY=""

# The MCP tools tracker.policy auto may allow, by exact name, for each family: issue, comment, label
# and project writes only. Code hosting, CI, release, sharing, agent-trigger, attachment and delete
# tools are left out, and the arguments are proven too (_g14_mcp_proven). A family whose tool names
# kern has no source for (jira, atlassian, asana, gitlab, monday, clickup, todoist, trello, shortcut,
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
# ai, linear), the tool's exact name on that family's list, and its arguments proven.
_g14_mcp() {
  local rest name srv words plain kind="" extra ok=0 first=""
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
  for first in ${words//[!$_G14_ALNUM]/ }; do break; done
  case " $KERN_G14_READS " in *" $first "*) return 0 ;; esac
  _g14_has_word "$srv" "$KERN_G14_CHAT" && kind=chat
  [ -z "$kind" ] && _g14_has_word "$srv" "$KERN_G14_TRACKERS" && kind=tracker
  if [ -z "$kind" ]; then
    extra=$(settings_get mcp.write_servers '' | tr '[:upper:]' '[:lower:]' | tr ',' ' ')
    [ -n "$extra" ] && _g14_has_word "$srv" "$extra" && kind=tracker
  fi
  [ -n "$kind" ] || return 0
  _g14_is_write "$words $plain" || return 0
  _G14_WHY="is not on tracker.policy auto's list: the issue, comment, label and project tools of a tracker kern knows"
  if [ "$kind" = tracker ] && [ "$AUTOPILOT" != 1 ] && _g14_policy && [ "$_G14_POLICY" = auto ]; then
    _g14_mcp_proven "$srv" "$name" && ok=1
  fi
  _g14_decide "$kind" "$TOOL" "$ok" "$_G14_WHY"
}

# _g14_is_write WORDS: any word of WORDS, split on every character but a-z and 0-9, is a write verb.
_g14_is_write() {
  local part
  for part in ${1//[!$_G14_ALNUM]/ }; do
    case " $KERN_G14_VERBS " in *" $part "*) return 0 ;; esac
  done
  return 1
}

# _g14_mcp_proven SERVER NAME: the call may be allowed under tracker.policy auto. SERVER (lowercased)
# has exactly one tracker family among its words, split on every character but a-z and 0-9; NAME is
# on that family's list, byte for byte; tool_input holds no \u escape (kern's JSON reader leaves one
# undecoded, so it could hide a key or a value); and the family's argument checks pass. On a
# failure after the list, _G14_WHY says why.
_g14_mcp_proven() {
  local toks=" ${1//[!$_G14_ALNUM]/ } " w fam="" n=0 list hit=1
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
    [ "$w" = "$2" ] && hit=0
  done
  [ "$hit" = 0 ] || return 1
  case "$TOOL_INPUT" in *'\u'*) _G14_WHY="has a \\u escape kern cannot read"; return 1 ;; esac
  case "$fam:$2" in
    github:*) _g14_github_args "$2" ;;
    linear:save_issue) _g14_linear_issue_args ;;
  esac
}

# _g14_once KEY: the text "KEY" appears at most once in tool_input. The JSON reader takes a key's
# first value and a server may take its last, so a key read for a value must not repeat.
_g14_once() {
  case "$TOOL_INPUT" in *"\"$1\""*"\"$1\""*) return 1 ;; esac
}

# _g14_github_args NAME: no assignee or reviewer names copilot, in any case (copilot starts an
# agent); label_write's method is create or update (its delete is a delete); and owner and repo,
# GitHub's name characters only, name the main worktree's origin on github.com, compared in any
# case as GitHub does. Each key read for a value appears once (_g14_once).
_g14_github_args() {
  local k v rc owner repo origin
  case "$TOOL_INPUT" in
    *[Cc][Oo][Pp][Ii][Ll][Oo][Tt]*)
      _G14_WHY="assigns or asks copilot, which starts an agent"
      for k in assignees assignee reviewers reviewer; do
        _g14_once "$k" || return 1
        v=$(KERN_INPUT=$TOOL_INPUT json_get_raw "$k")
        rc=$?
        [ "$rc" = 1 ] && continue
        [ "$rc" = 0 ] || return 1
        case "$v" in *[Cc][Oo][Pp][Ii][Ll][Oo][Tt]*) return 1 ;; esac
      done
      ;;
  esac
  if [ "$1" = label_write ]; then
    _G14_WHY="label_write is allowed only with method create or update"
    _g14_once method || return 1
    case "$(ti_get method && printf x)" in createx | updatex) ;; *) return 1 ;; esac
  fi
  _G14_WHY="names a repo kern cannot match to this repo's origin on github.com"
  _g14_once owner && _g14_once repo || return 1
  # The x keeps a trailing newline, which $( ) would drop, in the value the checks below see.
  owner=$(ti_get owner && printf x) && repo=$(ti_get repo && printf x) || return 1
  owner=${owner%x}
  repo=${repo%x}
  case "$owner" in "" | *[!a-zA-Z0-9._-]*) return 1 ;; esac
  case "$repo" in "" | *[!a-zA-Z0-9._-]*) return 1 ;; esac
  origin=$(_g14_origin) || return 1
  [ "$(printf '%s/%s' "$owner" "$repo" | LC_ALL=C tr '[:upper:]' '[:lower:]')" = "$origin" ]
}

# _g14_origin: OWNER/REPO, lowercased, of the main worktree's origin when its URL names a github.com
# repo: an https, http, ssh or git URL (user, password and port allowed), or the scp form
# (git@github.com:o/r.git). Exit 1 for any other URL, or when git cannot answer.
_g14_origin() {
  local url host path
  [ -n "${KERN_MAIN-}" ] || return 1
  url=$(git -C "$KERN_MAIN" -c core.fsmonitor=false remote get-url origin 2>/dev/null) || return 1
  url=$(printf '%s' "$url" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  case "$url" in
    https://* | http://* | ssh://* | git://* | git+ssh://* | ssh+git://*)
      path=${url#*://}
      host=${path%%/*}
      path=${path#"$host"}
      host=${host##*@}
      host=${host%:*}
      ;;
    *://*) return 1 ;;
    *:*)
      host=${url%%:*}
      path=${url#*:}
      case "$host" in */*) return 1 ;; esac
      host=${host##*@}
      ;;
    *) return 1 ;;
  esac
  [ "$host" = github.com ] || return 1
  while :; do case "$path" in /*) path=${path#/} ;; */) path=${path%/} ;; *) break ;; esac; done
  path=${path%.git}
  case "$path" in ?*/?*) ;; *) return 1 ;; esac
  case "${path#*/}" in */*) return 1 ;; esac
  printf '%s\n' "$path"
}

# _g14_linear_issue_args: save_issue has no delegate key (an agent) and, on an update (an id key),
# no team key (a move to another team). A key counts at any depth.
_g14_linear_issue_args() {
  _G14_WHY="delegates the issue to an agent"
  KERN_INPUT=$TOOL_INPUT json_get_raw delegate >/dev/null
  [ $? = 1 ] || return 1
  _G14_WHY="moves the issue to another team"
  KERN_INPUT=$TOOL_INPUT json_get_raw id >/dev/null
  case $? in
    1) return 0 ;;
    0) ;;
    *) return 1 ;;
  esac
  KERN_INPUT=$TOOL_INPUT json_get_raw team >/dev/null
  [ $? = 1 ]
}

# _g14_policy: sets _G14_POLICY to tracker.policy, read once per hook call.
_g14_policy() {
  [ -n "$_G14_POLICY" ] || _G14_POLICY=$(policy_for tracker)
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
  _g14_policy
  case "$_G14_POLICY" in
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
