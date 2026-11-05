# shellcheck shell=bash
# shellcheck disable=SC2154  # TOOL, CWD, SID and AUTOPILOT are set by hooks/pre-tool-use
# G20 approval: a Markdown file (a spec or plan under the work dir, or the project's own spec system
# under docs/) becomes `status: approved`, or changes the approved: line of an approved file, only on
# the user's own words. The check reads the file as it will be after the Write or Edit, so splitting
# the change over two edits does not get past it. The frontmatter must hold exactly one approved: line,
# in any case or indentation, and it must quote one whole line of the user's last message, verbatim,
# that is not a non-answer such as "sounds good", does not start with /kern:autopilot, /autopilot or
# <command- (a refused go, typed or in its command envelope, is still a line of that message), holds a
# yes word (yes, ok, go ahead, lgtm and the like), holds no negation or hold word (no, not, don't, wait,
# later and the like) and does not end in a question mark. The file must be older than that message.
# prompt-submit records the message's line hashes in the session state. G16 denies a write to that
# state, and asks before (under autopilot denies) a Write or Edit under kern's hooks/ directory and a
# Bash command that names a hook entry file, a .sh file under hooks/lib/ or hooks/guards/, or a state
# function, so the model cannot run prompt-submit to forge the message or edit this guard unseen. A
# shell write that reaches a hook file without naming its path is not seen (G16's accepted limits).
# Under autopilot only a go approves, for its ticket (_g20_go), in place of the checks on the user's
# last message, and a plan under WORK/plans only once its review approves it (_g20_reviewed). G20 never
# votes allow. A file under WORK/ledgers, WORK/reviews or WORK/tmp is a working
# file (_g20_working). A Write or Edit may not leave a line in one that holds both the word status and
# the word approved, in any case (_g20_mixed), and a shell write to one may not hold both anywhere in its
# command (_g20_both), because a printf's \n hides lines. A text editor in a command that holds approved
# and a copy from a file that holds a status: approved line are denied too. A frontmatter approval by
# Write or Edit is judged there as anywhere, and a shell copy from a working file to any other Markdown
# file is judged as a copy from any file is. ledger-open runs only a plan with a Markdown name that is
# not a working file and has no working file as its spec, and G20, ledger-open and plan-check read
# frontmatter with one reader (scripts/lib/frontmatter.awk), so an approval ledger-open accepts passed
# through G20, within the accepted limits below.
#
# Accepted limits:
# - "The user's last message" is the last prompt prompt-submit does not read as wrapped. A prompt
#   Claude Code starts itself that wrapped() misses counts as the user's, and its lines can be quoted.
# - An AskUserQuestion answer is a tool result, not a prompt, so it is not recorded and cannot approve;
#   define and plan ask for the yes as a typed reply.
# - The approval does not bind the content. An approved file whose approved: lines stay the same can be
#   rewritten by Edit or Write, the approval edit itself may change the body, and a new file has no
#   draft to be older than the message, so removing a draft and writing it anew with a real quote passes.
# - A go approves any file whose issue: line names its ticket, and the model writes that line.
# - The model writes a go's plan review record too, so G20 reads that it holds an approve verdict, not that
#   a reviewer wrote it or reviewed this draft. A plan outside WORK/plans, below a folder in it, or
#   reached by a hard link waits for no record. A user's word to skip the review leaves a go's plan with
#   no record, so the go cannot approve it; a user who wants no review turns autopilot off.
# - A subagent call that carries neither agent_type nor agent_id counts as the main session, as for
#   consent_for.
# - The hash is djb2, not a cryptographic hash: a quote built to collide with a line of the message
#   passes. A shell write that hides the path or the word (a script run by name, a word built at run
#   time, a recursive directory copy, git checkout or apply, a hard link) is not seen.
# - A working file's path is read as it stands before the call, so a symlink that the same command puts
#   in place of a working directory is not seen.
# - A shell write to a working file is judged one call at a time, by the call's text, and by the text
#   editors it runs and the files it names in the same simple command, or anywhere in a command that a
#   pipe, a substitution, a group, a subshell, a loop, an if, a case or an exec joins. Not seen there: a
#   status line split across two calls, either two Bash calls or a Write holding one word followed by a
#   shell append holding the other; words on two lines joined by a later shell edit; a word built at run
#   time so the text does not hold both; a file read by a simple command not joined to the write; a
#   source holding both words apart, which copies into a working file with no vote; a recursive copy;
#   and a busybox wrapper applet, as busybox reaches only the commands _g20_cmd reads. ledger-open
#   refuses a working file only while it is under a working directory.
# - A pipe anywhere in a command joins all of it, so a working write beside a pipe that carries nothing
#   to it is judged with it, as it was before working files were exempt. Splitting the call ends that.
# - A repository nested in a working directory has its own work dir, so ledger-open run from inside it
#   does not count the outer one's.
# - The two words are matched as text, so a report, a brief, pr-body.md or a *.proofs.md whose line joins
#   them takes one reword, with a go or without one.
_G20_NOT_YES=" sounds good | whatever you think | whatever | up to you | your call | you decide | i guess | maybe | not sure | looks fine i guess | no | nope | not yet | wait | stop | don't | do not "
# A quote approves only when its words hold one of _G20_YES and none of _G20_HOLD, and it does not end in
# a question mark. "good" and "sounds good" are not a yes.
_G20_YES="yes|y|yep|yeah|ok|okay|sure|go|go ahead|approve|approved|lgtm|ship it|do it|proceed|confirmed|agreed"
_G20_HOLD="no|nope|nah|not|don't|dont|never|wait|stop|hold|later|cancel|can't|cant|won't|wont|isn't|isnt|aren't|arent|shouldn't|shouldnt|wouldn't|wouldnt|couldn't|couldnt|haven't|havent|hasn't|hasnt|didn't|didnt|doesn't|doesnt|cannot"
_G20_ASK_YES="ask the user for an explicit yes, then quote that line verbatim"
# An approved: line, bare or quoted, in any case and indentation (grep -i).
_G20_APPROVED_RE="^[[:space:]]*[\"']?approved[\"']?[[:space:]]*:"
# A right single quote, read as an apostrophe in a non-answer ("don't").
_G20_RSQ=$'\342\200\231'
_G20_USE_TOOL="set or change an approval with the Edit or Write tool, so kern can check the user's quote"
_G20_OVER_WHY="the command may be in more directories than G20 follows (16), after cds it cannot follow for certain, and writes a relative path or a Markdown file; run the cds in a call of their own"

# The frontmatter reader G20 shares with ledger-open and plan-check, so all three agree on where a
# file's frontmatter ends.
_G20_FM_FILE="$KERN_ROOT/scripts/lib/frontmatter.awk"

# A status: approved line, bare or quoted, in any case, with any blanks around the colon and an optional
# comment after it.
_G20_STATUS_RE="^[[:space:]]*[\"']?status[\"']?[[:space:]]*:[[:space:]]*[\"']?approved[\"']?[[:space:]]*(#.*)?\$"

# Why text with both words is denied: a Write or Edit is judged by the line, after "line N of FILE", and a
# shell write by the command's whole text.
_G20_BOTH_LINE="holds both status and approved, which a line of a working file may not, as it can read as an approval; reword that line, and keep a report's Status: line, since execute-plan reads a report with none as BLOCKED"
_G20_BOTH_SHELL="the command holds both status and approved, which a shell write to a working file may not, as it can read as an approval; use the Write tool, which judges each line, and a line holding both stays denied; for a ledger line, reword it or append it in a call of its own"

# _G20_EDIT_AWK: prints the text it reads after replacing ENVIRON G20_OLD with G20_NEW: the first
# match, or every match when G20_ALL is true. Line ends are read as Claude Code's Edit reads them: CRLF
# as LF, and when G20_OLD is not found, curly quotes as straight ones. Exit 4 when G20_OLD is still not
# found.
# shellcheck disable=SC2016 # awk text
_G20_EDIT_AWK='
function straight(s) { gsub("\342\200\230|\342\200\231", "\047", s); gsub("\342\200\234|\342\200\235", "\"", s); return s }
{ sub(/\r$/, ""); t = t $0 "\n" }
END {
  o = ENVIRON["G20_OLD"]
  if (!index(t, o)) { t = straight(t); o = straight(o) }
  if (!index(t, o)) exit 4
  out = ""; r = t
  while ((i = index(r, o)) > 0) {
    out = out substr(r, 1, i - 1) ENVIRON["G20_NEW"]; r = substr(r, i + length(o))
    if (ENVIRON["G20_ALL"] != "true") break
  }
  printf "%s", out r
}'

# _g20_approved FRONTMATTER: exit 0 when a line of FRONTMATTER sets status: approved.
_g20_approved() {
  printf '%s\n' "$1" | env LC_ALL=C grep -Eiq "$_G20_STATUS_RE"
}

# _g20_holds FILE: exit 0 when any line of FILE sets status: approved, in its frontmatter or not. A
# shell edit can turn body lines into frontmatter (sed deleting a ---, tail dropping a first line), so
# for a shell write every line counts.
_g20_holds() {
  [ -f "$1" ] && [ -r "$1" ] && env LC_ALL=C grep -Eiq "$_G20_STATUS_RE" "$1" 2> /dev/null
}

# _g20_lines FRONTMATTER: the value of every approved: line, in order.
_g20_lines() {
  printf '%s\n' "$1" |
    env LC_ALL=C sed -n -E "s/^[[:space:]]*[\"']?[Aa][Pp][Pp][Rr][Oo][Vv][Ee][Dd][\"']?[[:space:]]*:[[:space:]]*//p"
}

# _g20_issues FRONTMATTER: the value of every issue: line, in order, without one pair of matching quotes
# (a bare # opens a YAML comment, so "#853" is the safe spelling).
_g20_issues() {
  printf '%s\n' "$1" |
    env LC_ALL=C sed -n -E "s/^[[:space:]]*[\"']?[Ii][Ss][Ss][Uu][Ee][\"']?[[:space:]]*:[[:space:]]*//p" |
    env LC_ALL=C sed -E "s/^\"(.*)\"\$|^'(.*)'\$/\1\2/"
}

# _g20_go AFTER: exit 0 when the session's go approves the frontmatter AFTER: the call is the main
# session's, the state's go and go_repo are set, go_repo is this repository's key, go_phase is not pr
# (G2 sets it at the go's draft PR, after which the go approves nothing), AFTER's one approved: line
# quotes the go's line, and its one issue: line names the go's ticket. go_ticket takes a single line, so
# no issue: line, or two of them, names none. A read that fails or comes back empty is no go.
# _G20_LIVE holds the go once the call, the state and the repository pass, for the deny's reason, and
# _G20_PAST holds it instead when go_phase is pr.
_g20_go() {
  local go repo key phase quote id
  _G20_LIVE=''
  _G20_PAST=''
  [ -z "${AGENT-}${AGENT_ID-}" ] || return 1
  go=$(state_get "$SID" go 2> /dev/null) || return 1
  [ -n "$go" ] || return 1
  repo=$(state_get "$SID" go_repo 2> /dev/null) || return 1
  key=$(consent_key "${KERN_MAIN-}") || return 1
  [ -n "$key" ] && [ "$repo" = "$key" ] || return 1
  # The go_phase read ends with its status line: a substitution whose pipe could not be made gives status
  # 0 and no output, which must not read as an empty go_phase. Status 1 with no output is a go_phase never
  # written; any other status, or no status line, is no go.
  phase=$(state_get "$SID" go_phase 2> /dev/null; printf '\n%s' "$?")
  case "$phase" in
    pr$'\n\n'0)
      _G20_PAST=$go
      return 1
      ;;
    *$'\n'0 | $'\n'1) ;;
    *) return 1 ;;
  esac
  _G20_LIVE=$go
  [ "$(printf '%s\n' "$1" | env LC_ALL=C grep -Eic "$_G20_APPROVED_RE")" = 1 ] || return 1
  quote=$(_g20_lines "$1" | sed -n 's/^[^"]*"\(.*\)".*$/\1/p')
  [ "$quote" = "/kern:autopilot go $go" ] || return 1
  id=$(go_ticket "$(_g20_issues "$1")") || return 1
  [ "$id" = "$go" ]
}

# _g20_any LIST WORDS: exit 0 when WORDS (blank-padded) holds one of the |-separated words or phrases of
# LIST as whole words.
_g20_any() {
  local rest="$1|" p
  while [ -n "$rest" ]; do
    p=${rest%%|*}
    rest=${rest#*|}
    case "$2" in *" $p "*) return 0 ;; esac
  done
  return 1
}

# _g20_md PATH: exit 0 when PATH names a Markdown file, in any case (a case-insensitive file system
# opens spec.Md as spec.md).
_g20_md() {
  case "$1" in *.[Mm][Dd] | *.[Mm][Aa][Rr][Kk][Dd][Oo][Ww][Nn]) return 0 ;; esac
  return 1
}

# _g20_mdfile PATH: _g20_md, or PATH (absolute) is a symlink that, followed up to 8 links, reaches a
# Markdown name, so a write through notes.txt -> spec.md is seen. A hard link is not (accepted limit).
_g20_mdfile() {
  local p="$1" i=0 l
  _g20_md "$p" && return 0
  while [ "$i" -lt 8 ] && [ -L "$p" ]; do
    l=$(readlink "$p") || return 1
    case "$l" in /*) p=$l ;; *) p="${p%/*}/$l" ;; esac
    _g20_md "$p" && return 0
    i=$((i + 1))
  done
  return 1
}

# _g20_wd: sets _G20_WD to the work_dir setting, relative to the main worktree, as kern-dir reads it.
# Fails when work_dir cannot be read whole or is one kern-dir refuses.
_g20_wd() {
  [ -n "${KERN_MAIN-}" ] || return 1
  _G20_WD=$(settings_get work_dir .kern) || return 1
  _G20_WD=${_G20_WD%/}
  case "$_G20_WD" in '' | . | :* | .git | .git* | /* | *..*) return 1 ;; esac
}

# _g20_work: sets _G20_WORK, once per call, to the real path of the work dir, found as kern-dir finds it
# in the main worktree. Fails when _g20_wd fails or the work dir does not exist.
_g20_work() {
  [ -z "${_G20_WORK-}" ] || return 0
  _g20_wd || return 1
  _G20_WORK=$(cd -P "$KERN_MAIN/$_G20_WD" 2> /dev/null && env pwd -P) && [ -n "$_G20_WORK" ]
}

# _g20_dir DIR: sets _G20_REAL to DIR (absolute, or empty for /) with its nearest part that exists read by
# cd -P and env pwd -P, and the parts after it, which a Write makes, as written. Fails when that read comes
# back empty (a substitution whose pipe could not be made gives status 0 and no output), or when those
# parts hold ., .. or an empty part, which the Write resolves where a string compare cannot.
_g20_dir() {
  local d="$1" t=''
  case "$d" in '' | /*) ;; *) return 1 ;; esac
  while [ -n "$d" ] && [ ! -d "$d" ]; do
    t="/${d##*/}$t"
    d=${d%/*}
  done
  case "$t/" in */./* | */../* | *//*) return 1 ;; esac
  _G20_REAL=$(cd -P "${d:-/}" 2> /dev/null && env pwd -P) && [ -n "$_G20_REAL" ] || return 1
  _G20_REAL="${_G20_REAL%/}$t"
}

# _g20_plan PATH: exit 0, with _G20_SLUG set, when PATH (absolute), or a symlink on the way from it (up
# to 8), names a Markdown file right under WORK/plans, where plan writes its plans; the slug is that name
# without its extension. Each directory is read by _g20_dir, so a plan whose folder a Write makes is seen.
# Exit 1 only when it is no plan. Exit 2 when it cannot tell: the work dir, a directory or a link cannot
# be read (an empty read included), or the links go past 8.
_g20_plan() {
  local p="$1" i=0 w n l
  _G20_SLUG=''
  _g20_wd && _g20_dir "$KERN_MAIN/$_G20_WD/plans" || return 2
  w=$_G20_REAL
  while :; do
    _g20_dir "${p%/*}" || return 2
    p="$_G20_REAL/${p##*/}"
    n=${p#"$w"/}
    if [ "$n" != "$p" ] && [ "${n%/*}" = "$n" ] && _g20_md "$n"; then
      _G20_SLUG=${n%.*}
      return 0
    fi
    [ -L "$p" ] || return 1
    [ "$i" -lt 8 ] || return 2
    l=$(readlink "$p") && [ -n "$l" ] || return 2
    case "$l" in /*) p=$l ;; *) p="${p%/*}/$l" ;; esac
    i=$((i + 1))
  done
}

# _g20_reviewed PATH: called once _g20_go approves PATH. A plan (_g20_plan) approves under a go only after
# its review approves it: denies unless WORK/reviews/plan-<slug>.md, the plan reviewer's reply that plan
# step 11 saves, is a regular file with a line that, its blanks around trimmed, is Verdict: approve, and
# no such line Verdict: revise. A record that cannot be read is no approve, and a plan G20 cannot tell
# (_g20_plan exit 2) fails closed.
_g20_reviewed() {
  local r rc=0
  _g20_plan "$1" || rc=$?
  case "$rc" in
    0) ;;
    1) return 0 ;;
    *)
      fail_closed "G20 could not tell whether ${1##*/} is a plan, which under a go approves only after its review: the work dir or a link on the way cannot be read, or the path holds a ., .. or empty part after a directory that does not exist yet; write the plan to the path kern-dir plans prints"
      return 0
      ;;
  esac
  r="$KERN_MAIN/$_G20_WD/reviews/plan-$_G20_SLUG.md"
  if [ -f "$r" ] && env LC_ALL=C grep -Eq '^[[:space:]]*Verdict: approve[[:space:]]*$' "$r" 2> /dev/null; then
    # Only grep's exit 1, no match, is no revise line, so a read that fails stays no approve.
    env LC_ALL=C grep -Eq '^[[:space:]]*Verdict: revise[[:space:]]*$' "$r" 2> /dev/null
    [ "$?" != 1 ] || return 0
  fi
  vote deny G20 "under a go a plan approves only after its review: $r, where plan step 11 saves the plan reviewer's reply, needs a line Verdict: approve and no line Verdict: revise; keep status: draft"
}

# _g20_working PATH [TAIL]: exit 0 when PATH (absolute), with TAIL after it, is a working file: it and
# each symlink on the way to it, up to 8, lie under WORK/ledgers, WORK/reviews or WORK/tmp, so a symlink
# out, and one in from a spec, stay judged. A directory that does not exist yet is not read, and fails:
# the command may make it a symlink. cd -P reads a link/.. as the file system does, where a plain cd
# drops the link. pwd -P gives the directory's own case from env's pwd; the builtin keeps the case it was
# given on macOS.
_g20_working() {
  local p="$1" t="${2-}" i=0 d l
  _g20_work || return 1
  while :; do
    d=$(cd -P "${p%/*}/" 2> /dev/null && env pwd -P) || return 1
    p="${d%/}/${p##*/}"
    case "$p$t" in
      "$_G20_WORK"/ledgers/* | "$_G20_WORK"/reviews/* | "$_G20_WORK"/tmp/*) ;;
      *) return 1 ;;
    esac
    [ -L "$p" ] || return 0
    [ "$i" -lt 8 ] || return 1
    l=$(readlink "$p") || return 1
    case "$l" in /*) p=$l ;; *) p="$d/$l" ;; esac
    i=$((i + 1))
  done
}

# _g20_both TEXT: exit 0 when TEXT holds both status and approved, anywhere and in any case.
_g20_both() {
  case "$1" in *[Ss][Tt][Aa][Tt][Uu][Ss]*) ;; *) return 1 ;; esac
  case "$1" in *[Aa][Pp][Pp][Rr][Oo][Vv][Ee][Dd]*) return 0 ;; esac
  return 1
}

# _g20_near PATH: _g20_working for a Write or Edit, read from PATH's nearest directory that exists, as such
# a call makes the rest itself and a missing directory is no symlink there.
_g20_near() {
  local p="$1" t=''
  while [ -n "${p%/*}" ] && [ ! -d "${p%/*}" ]; do
    t="/${p##*/}$t"
    p=${p%/*}
  done
  _g20_working "$p" "$t"
}

# _g20_mixed PATH TEXT: denies when PATH is a working file and a line of TEXT, what it holds after the
# call, holds both words, naming the first such line. A body line can become frontmatter by a shell edit
# that names neither word.
_g20_mixed() {
  local l n=0
  _g20_both "$2" && _g20_near "$1" || return 0
  while IFS= read -r l; do
    n=$((n + 1))
    if _g20_both "$l"; then
      vote deny G20 "line $n of $(basename "$1") $_G20_BOTH_LINE"
      return 0
    fi
  done <<< "$2"
}

# _g20_fm NAME: sets _G20_FM to the frontmatter of the text on stdin (NAME's), read by the shared
# reader; an unclosed block counts to its end. Fails closed, and returns 1, when the reader cannot run.
_g20_fm() {
  local rc=0
  _G20_FM=$(env LC_ALL=C awk -v fm_print=1 -f "$_G20_FM_FILE" 2> /dev/null) || rc=$?
  case "$rc" in 0 | 3) return 0 ;; esac
  fail_closed "G20 could not read the frontmatter of $1 to judge an approval"
  return 1
}

guard_g20() {
  case "$TOOL" in
    Write | Edit) _g20_file ;;
    Bash) _g20_bash ;;
  esac
}

_g20_file() {
  local p base text old='' new all post rc before after lines quote norm words trimmed qh hashes sf
  p=$(ti_get file_path) || return 0
  case "$p" in /*) ;; *) p="${CWD:-$PWD}/$p" ;; esac
  _g20_mdfile "$p" || return 0
  base=$(basename "$p")
  before=''
  if [ -f "$p" ] && [ -r "$p" ]; then
    _g20_fm "$base" < "$p" || return 0
    before=$_G20_FM
  fi
  if [ "$TOOL" = Edit ]; then
    old=$(ti_get old_string && printf x) || return 0
    old=${old%x}
  fi
  if [ "$TOOL" = Write ] || [ -z "$old" ]; then
    # An Edit with an empty old_string writes new_string as the whole file. $( ) drops trailing
    # newlines; the x keeps them.
    if [ "$TOOL" = Write ]; then
      text=$(ti_get content && printf x) || return 0
    else
      text=$(ti_get new_string && printf x) || return 0
    fi
    post=${text%x}
    _g20_fm "$base" <<< "$post" || return 0
  else
    new=$(ti_get new_string && printf x) || return 0
    new=${new%x}
    all=$(KERN_INPUT="${TOOL_INPUT-}" json_get_raw replace_all 2> /dev/null) || all=false
    rc=4
    if [ -f "$p" ]; then
      rc=0
      post=$(G20_OLD="$old" G20_NEW="$new" G20_ALL="$all" env LC_ALL=C awk "$_G20_EDIT_AWK" "$p" 2> /dev/null) || rc=$?
    fi
    case "$rc" in
      0) _g20_fm "$base" <<< "$post" || return 0 ;;
      4)
        # G20's model of the Edit found nothing to replace. If Claude Code's own matching differs, an
        # Edit that writes a status or approved: line could approve unseen, so it fails closed.
        if printf '%s\n' "$new" | env LC_ALL=C grep -Eiq "^[[:space:]]*[\"']?(status|approved)[\"']?[[:space:]]*:"; then
          vote deny G20 "old_string is not in $base as G20 reads it, so it cannot judge an Edit that writes a status or approved: line; read the file and edit it again"
          return 0
        fi
        # No exact bytes here, so the whole text counts.
        if _g20_both "$(cat "$p" 2> /dev/null)$new" && _g20_near "$p"; then
          vote deny G20 "old_string is not in $base as G20 reads it, so it cannot tell which line of a working file would hold both status and approved; read the file and edit it again"
        fi
        return 0
        ;;
      *)
        fail_closed "G20 could not read $base to judge the Edit for an approval"
        return 0
        ;;
    esac
  fi
  after=$_G20_FM
  if ! _g20_approved "$after"; then
    _g20_mixed "$p" "$post"
    return 0
  fi
  lines=$(_g20_lines "$after")
  # An approved file whose approved: lines stay the same is not being approved now.
  if _g20_approved "$before" && [ "$(_g20_lines "$before")" = "$lines" ]; then return 0; fi
  if [ "${AUTOPILOT:-0}" = 1 ]; then
    if _g20_go "$after"; then
      _g20_reviewed "$p"
      return 0
    fi
    if [ -n "$_G20_PAST" ]; then
      vote deny G20 "under autopilot only a go approves, for its ticket, and only until its draft PR opens; the draft for $_G20_PAST is open, so keep status: draft (parked under autopilot) and park the question"
    elif [ -n "$_G20_LIVE" ]; then
      vote deny G20 "under autopilot only a go approves, for its ticket; this go wants one line approved: <date>, \"/kern:autopilot go $_G20_LIVE\" and one line issue: \"$_G20_LIVE\"; a file for another ticket keeps status: draft"
    else
      vote deny G20 "under autopilot only a go approves, for its ticket; keep status: draft (parked under autopilot) and park the question"
    fi
    return 0
  fi
  # ledger-open reads the first line that starts exactly with approved:, so G20 judges only a
  # frontmatter where that line is the one it checks.
  if [ "$(printf '%s\n' "$after" | env LC_ALL=C grep -Eic "$_G20_APPROVED_RE")" -gt 1 ]; then
    vote deny G20 "the frontmatter holds more than one approved: line; keep exactly one, so the quote G20 checks is the one ledger-open reads"
    return 0
  fi
  # The quote runs from the first double quote of the first approved: line to its last, so a user's
  # line that holds a double quote can still be quoted whole.
  quote=$(printf '%s\n' "$lines" | head -n 1 | sed -n 's/^[^"]*"\(.*\)".*$/\1/p')
  if [ -z "$quote" ]; then
    vote deny G20 "status: approved needs an approved: line with the date and the user's words in double quotes, in the same edit"
    return 0
  fi
  norm=$(printf '%s\n' "$quote" | env LC_ALL=C tr '[:upper:]' '[:lower:]' |
    sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ $//' -e 's/[.!?,;:]*$//' -e 's/ $//')
  norm=${norm//$_G20_RSQ/\'}
  case "${norm%% *}" in
    /kern:autopilot | /autopilot | '<command-'*)
      vote deny G20 "\"$quote\" is a command, not an explicit yes; $_G20_ASK_YES"
      return 0
      ;;
  esac
  case "$_G20_NOT_YES" in
    *" $norm "*)
      vote deny G20 "\"$quote\" is not an explicit yes; $_G20_ASK_YES"
      return 0
      ;;
  esac
  # words: the quote's words, split at anything but a letter, a digit or an apostrophe, with the
  # apostrophes at a word's ends taken off, padded with blanks.
  words=" $(printf '%s\n' "$norm" | env LC_ALL=C tr -c "[:alnum:]'\n" ' ' |
    sed -e "s/ '*/ /g" -e "s/'* / /g" -e "s/^'*//" -e "s/'*\$//" -e 's/  */ /g') "
  trimmed=${quote%"${quote##*[![:space:]]}"}
  if ! _g20_any "$_G20_YES" "$words" || _g20_any "$_G20_HOLD" "$words" || [ "${trimmed%\?}" != "$trimmed" ]; then
    vote deny G20 "\"$quote\" is not an explicit yes (it needs a word such as yes, ok or go ahead, no word such as no, not, wait or later, and no final question mark); $_G20_ASK_YES"
    return 0
  fi
  # A quote with no hash (blank, or over 500 characters) matches nothing, not an empty record.
  qh=$(printf '%s\n' "$quote" | prompt_hashes)
  hashes=$(state_get "$SID" prompt_hashes 2> /dev/null) || hashes=''
  case " $hashes " in
    *" ${qh:-none} "*) ;;
    *)
      vote deny G20 "the approved: quote is not a line of the user's last message; $_G20_ASK_YES"
      return 0
      ;;
  esac
  # The draft must be older than the state file, which prompt-submit rewrites on each user prompt. bash
  # 3.2 compares whole seconds, so a draft from the same second as the prompt counts as changed after it.
  sf=$(state_file "$SID" 2> /dev/null) || sf=''
  if [ -f "$p" ] && ! { [ -n "$sf" ] && [ "$sf" -nt "$p" ]; }; then
    vote deny G20 "$base changed after the user's last message; set status and approved: in one edit, on a draft unchanged since the user's yes, so ask for the yes again"
  fi
}

# A shell command that writes a Markdown file could set or change an approval without the quote check. A
# working file counts only when the command's text holds both words; _g20_seg1 also judges a
# text editor or a copy in the simple command that writes one. _g20_bash reads each simple command
# (git_words) and denies when one writes a file that counts (a redirect; an operand of sed -i, perl -i,
# awk or gawk -i inplace, ed, ex, vi, vim, tee, truncate or sponge; dd of=; the destination of cp, mv,
# install, ln, rsync, ditto or git mv; the same inside find -exec and xargs) and the command holds the
# word approved, or the file holds a status: approved line now, or the command names another file that
# does (cp, cat, tee or tail from a prepared file); any line counts, not only frontmatter, because a
# shell edit can move body lines into it. A script interpreter running inline code (python -c, node -e,
# a here-doc on stdin) is denied when the command holds both approved and a Markdown name. With approved
# in the command, a destination built at run time (a glob, a variable, find's {}) is denied too. A
# script run by name, or a word built at run time, is not seen (accepted limit).
#
# State for one command: _G20_W is 1 when the command holds approved (quotes and backslashes taken out,
# any case), _G20_M when it names a Markdown file, _G20_S when it holds status too, _G20_JOIN
# when text may pass between its simple commands (_g20_joined).
# _G20_DIRS holds each directory the command may be in, one per line, _G20_SEEN each one it was in, and
# _G20_DIR the one _g20_seg1 judges from; it follows cd. _G20_OVER is 1 once the set is past its cap.
# _G20_REC is the simple command _g20_seg reads. _G20_WRITES is 1 once a simple command writes a
# Markdown file that counts. _G20_SRC holds the command's other file words as absolute paths, an array.
# _G20_WW is 1 once the simple command writes a working file, _G20_ED once it runs a text editor, and
# _G20_COPY holds the file words of the simple commands that write a working file; with _G20_JOIN the
# first two hold for the whole command. _G20_WHY is the deny reason; the first one ends the check.

# _g20_dyn WORD: exit 0 when WORD may name other files at run time: a glob, a $, a backtick or a brace.
_g20_dyn() {
  case "$1" in *'*'* | *'?'* | *'['* | *'$'* | *'`'* | *'{'*) return 0 ;; esac
  return 1
}

# _g20_abs WORD: sets _G20_P to WORD as an absolute path, from _G20_DIR. A relative WORD sets _G20_REL.
_g20_abs() {
  case "$1" in
    /*) _G20_P=$1 ;;
    '~') _G20_P=$HOME ;;
    '~'/*) _G20_P="$HOME${1#'~'}" ;;
    *)
      _G20_P="$_G20_DIR/$1"
      _G20_REL=1
      ;;
  esac
}

# _g20_target WORD: WORD is a file a simple command writes.
# With approved in the command, a write to a destination built at run time is denied whatever its last
# part: zsh's MULTIOS writes a split redirect word ($=x, or with shwordsplit) to each file it names, so
# x/notes.txt can also reach a spec. kern writes review and ledger text with the Write tool or in a call
# of its own (pilot fix plan 2).
_g20_target() {
  local w="$1"
  [ -n "$w" ] && [ -z "$_G20_WHY" ] || return 0
  if _g20_dyn "$w" && [ "$_G20_W" = 1 ]; then
    _G20_WHY="the command holds the word approved and writes $w, which may be a Markdown file; $_G20_USE_TOOL"
    return 0
  fi
  # Past the cap (_g20_seg), a relative write cannot be judged from every directory, nor can a Markdown
  # write's sources.
  if [ "${_G20_OVER:-0}" = 1 ] && ! _g20_dyn "$w"; then
    case "$w" in /* | '~' | '~'/*) ;; *) _G20_WHY=$_G20_OVER_WHY; return 0 ;; esac
  fi
  _g20_abs "$w"
  _g20_md "$w" || _g20_mdfile "$_G20_P" || return 0
  # A command that writes a working file may hold one of the two words, not both. A word built at run
  # time may name any file, so only a literal path is a working file.
  if ! _g20_dyn "$w" && _g20_working "$_G20_P"; then
    if [ "$_G20_S" = 1 ]; then _G20_WHY=$_G20_BOTH_SHELL; else _G20_WW=1; fi
    return 0
  fi
  if [ "${_G20_OVER:-0}" = 1 ]; then
    _G20_WHY=$_G20_OVER_WHY
    return 0
  fi
  _G20_WRITES=1
  if [ "$_G20_W" = 1 ]; then
    _G20_WHY=$_G20_USE_TOOL
    return 0
  fi
  _g20_dyn "$w" && return 0
  if _g20_holds "$_G20_P"; then
    _G20_WHY="$(basename "$_G20_P") holds a status: approved line, and a shell write to it skips the quote check; $_G20_USE_TOOL"
  fi
}

# _g20_inline WORD...: exit 0 when an interpreter given these arguments runs inline code: a -c, -e,
# --eval or similar option, an eval subcommand, a - operand, or no operand at all (a script on
# stdin). A first operand that is a file name is a script run by name.
_g20_inline() {
  local w
  for w in "$@"; do
    case "$w" in -c* | -e* | -E* | -p* | -r* | --eval* | --print* | --command* | -[Cc]ommand* | -[!-]*c | -[!-]*e | eval) return 0 ;; esac
  done
  for w in "$@"; do
    case "$w" in
      -) return 0 ;;
      -*) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

# _g20_ops CODE VALUE REST SOFT LONG LCODE WORD...: reads the options and operands of sed, perl or awk.
# Sets _G20_OPS (count _G20_N) to the operands, _G20_CODE to 1 when an option gave the script or
# program, and _G20_I to 1 when an option cluster holds i or a letter in SOFT, or a word is --in-place.
# In a cluster such as -nE or -pi.bak, a letter in CODE gives the script and a letter in VALUE takes a
# value, each from the rest of the cluster or else the next word; a letter in REST takes the rest of the cluster only; a
# letter in SOFT does the same, and at the end of the cluster takes the next word when it is empty or
# starts with a dot (BSD sed -i ''). LONG lists the long options that take the next word, as " --x ";
# LCODE those of them that give the script, in either form.
_g20_ops() {
  local code="$1" val="$2" rest="$3" soft="$4" long="$5" lcode="$6" w skip=0 k c
  shift 6
  _G20_OPS=()
  _G20_N=0
  _G20_CODE=0
  _G20_I=0
  for w in "$@"; do
    case "$skip" in
      1) skip=0; continue ;;
      s)
        skip=0
        case "$w" in '' | .*) case "$w" in */*) ;; *) continue ;; esac ;; esac
        ;;
    esac
    case "$w" in
      --in-place*) _G20_I=1 ;;
      --*=*) case " $lcode " in *" ${w%%=*} "*) _G20_CODE=1 ;; esac ;;
      --*)
        case " $long " in *" $w "*) skip=1 ;; esac
        case " $lcode " in *" $w "*) _G20_CODE=1 ;; esac
        ;;
      -?*)
        k=1
        while [ "$k" -lt "${#w}" ]; do
          c=${w:$k:1}
          k=$((k + 1))
          [ "$c" = i ] && _G20_I=1
          case "$code$val" in
            *"$c"*)
              case "$code" in *"$c"*) _G20_CODE=1 ;; esac
              [ "$k" -lt "${#w}" ] || skip=1
              break
              ;;
          esac
          case "$rest" in *"$c"*) break ;; esac
          case "$soft" in
            *"$c"*)
              _G20_I=1
              [ "$k" -lt "${#w}" ] || skip=s
              break
              ;;
          esac
        done
        ;;
      '') ;;
      *) _G20_OPS[_G20_N]=$w; _G20_N=$((_G20_N + 1)) ;;
    esac
  done
}

# _g20_copy HEAD WORD...: the arguments of cp, mv, install, ln, rsync or ditto (HEAD). The destination
# is the last operand, or the -t directory; a destination directory receives each source by its own
# name. A relative ln source is read from the link's directory, so it joins _G20_SRC from there too.
_g20_copy() {
  local head="$1" w skip=0 tdir='' ops=() n=0 ns i s dest dir
  shift
  for w in "$@"; do
    case "$skip" in
      1) skip=0; continue ;;
      t) skip=0; tdir=$w; continue ;;
    esac
    case "$w" in
      -t | --target-directory) skip=t ;;
      --target-directory=*) tdir=${w#*=} ;;
      -S | -m | -o | -g | -e | --suffix | --mode | --owner | --group | --rsh | --filter | --exclude | \
        --include | --files-from) skip=1 ;;
      -*) ;;
      *) ops[n]=$w; n=$((n + 1)) ;;
    esac
  done
  [ "$n" -gt 0 ] || return 0
  ns=$n
  if [ -n "$tdir" ]; then
    dest=${tdir%/}/
  elif [ "$n" = 1 ]; then
    dest=./
  else
    ns=$((n - 1))
    dest=${ops[$ns]}
    _g20_abs "$dest"
    [ -d "$_G20_P" ] && dest=${dest%/}/
  fi
  if [ "$head" = ln ]; then
    case "$dest" in */) dir=$dest ;; */*) dir=${dest%/*} ;; *) dir=. ;; esac
    _g20_abs "$dir"
    dir=$_G20_P
    i=0
    while [ "$i" -lt "$ns" ]; do
      case "${ops[$i]}" in /*) ;; *) _G20_SRC+=("$dir/${ops[$i]}") ;; esac
      i=$((i + 1))
    done
  fi
  case "$dest" in
    */)
      i=0
      while [ "$i" -lt "$ns" ]; do
        s=${ops[$i]}
        while [ "${s%/}" != "$s" ]; do s=${s%/}; done
        _g20_target "$dest${s##*/}"
        i=$((i + 1))
      done
      ;;
    *) _g20_target "$dest" ;;
  esac
}

# _g20_cmd WORD...: one simple command, its name first, redirections taken out.
_g20_cmd() {
  local head w skip=0 inplace=0 i n=0 inner=() m=0 dir
  [ "$#" -gt 0 ] && [ -z "$_G20_WHY" ] || return 0
  head=${1##*/}
  case "$head" in *[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) head=$(printf '%s' "$head" | env LC_ALL=C tr '[:upper:]' '[:lower:]') ;; esac
  shift
  case "$head" in
    builtin) case "${1-}" in cd | pushd | popd) _g20_cmd "$@" ;; esac ;;
    cd | pushd)
      # Only a plain cd is followed for certain (cmd_plain); _g20_seg also judges from where it was. A
      # cd that can go back (-, ~-, +N, -N, a target built at run time, more than one operand, a pushd
      # with none) may land in any directory the command was in, or HOME (_G20_BACK).
      _G20_REL=1
      if [ -z "$_G20_PLAIN" ]; then
        _G20_PLAIN=0
        if cmd_plain "$_G20_REC"; then _G20_PLAIN=1; fi
      fi
      [ "$_G20_PLAIN" = 1 ] || _G20_STAY=1
      w=""
      n=0
      skip=0
      for i in "$@"; do
        case "$skip:$i" in
          0:--) skip=1 ;;
          0:- | 0:-[0123456789]*) w=-; n=$((n + 1)) ;;
          0:-*) ;;
          *) w=$i; n=$((n + 1)) ;;
        esac
      done
      case "$n:$w" in
        0:) if [ "$head" = pushd ]; then _G20_BACK=1; else w=$HOME; fi ;;
        1:- | 1:+* | 1:-[0123456789]*) _G20_BACK=1 ;;
        1:'~' | 1:'~'/*) ;;
        1:'~'*) _G20_BACK=1 ;;
        1:*) _g20_dyn "$w" && _G20_BACK=1 ;;
        *) _G20_BACK=1 ;;
      esac
      if [ "$_G20_BACK" = 1 ]; then
        _G20_STAY=1
        _G20_DIR=$HOME
      else
        _g20_abs "$w"
        _G20_DIR=$_G20_P
      fi
      ;;
    popd) _G20_REL=1; _G20_STAY=1; _G20_BACK=1 ;;
    busybox) _g20_cmd "$@" ;;
    sed | gsed | perl)
      _G20_ED=1
      if [ "$head" = perl ]; then
        _g20_ops eE '' iIMm0lxCdD '' '' '' "$@"
      else
        # -I is BSD sed's in-place flag; perl's is an include path.
        _g20_ops ef l '' iI "--expression --file --line-length" "--expression --file" "$@"
      fi
      if [ "$_G20_I" = 0 ]; then
        if [ "$head" = perl ] && [ "$_G20_W$_G20_M" = 11 ] && _g20_inline "$@"; then
          _G20_WHY="perl runs inline code in a command that names a Markdown file and holds the word approved; $_G20_USE_TOOL"
        fi
        return 0
      fi
      # The first operand is the script, unless an option gave it.
      i=$((1 - _G20_CODE))
      while [ "$i" -lt "$_G20_N" ]; do
        _g20_target "${_G20_OPS[$i]}"
        i=$((i + 1))
      done
      ;;
    awk | gawk | mawk | nawk)
      _G20_ED=1
      for w in "$@"; do
        case "$w" in *inplace*) inplace=1 ;; esac
      done
      _g20_ops fE vFil '' '' "--file --exec --assign --field-separator --include --load" "--file --exec" "$@"
      if [ "$inplace" = 1 ]; then
        i=$((1 - _G20_CODE))
        while [ "$i" -lt "$_G20_N" ]; do
          # NAME=value is an assignment, not a file.
          case "${_G20_OPS[$i]%%=*}" in
            "${_G20_OPS[$i]}" | '' | [0123456789]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*)
              _g20_target "${_G20_OPS[$i]}"
              ;;
          esac
          i=$((i + 1))
        done
      elif [ "$_G20_CODE" = 0 ] && [ "$_G20_N" -gt 0 ] && [ "$_G20_W" = 1 ]; then
        # An awk program writes a file itself with print > "x.md".
        case "${_G20_OPS[0]}" in
          *.[Mm][Dd]* | *.[Mm][Aa][Rr][Kk][Dd][Oo][Ww][Nn]*)
            _G20_WHY="an awk program that names a Markdown file, in a command that holds the word approved, could set an approval; $_G20_USE_TOOL"
            ;;
        esac
      fi
      ;;
    ed | ex | vi | vim | nvim | tee | truncate | sponge)
      case "$head" in tee | truncate | sponge) ;; *) _G20_ED=1 ;; esac
      for w in "$@"; do
        if [ "$skip" = 1 ]; then
          skip=0
          continue
        fi
        case "$head:$w" in
          truncate:-s | truncate:-r | truncate:--size | truncate:--reference | ed:-p | \
            [evn]*:-c | [evn]*:-S | [evn]*:--cmd | [evn]*:-u | [evn]*:-U | [evn]*:-i | [evn]*:-T | [evn]*:-w | \
            [evn]*:-W | [evn]*:-t) skip=1 ;;
          *:-* | *:+*) ;;
          *) _g20_target "$w" ;;
        esac
      done
      ;;
    dd)
      for w in "$@"; do
        case "$w" in of=*) _g20_target "${w#of=}" ;; esac
      done
      ;;
    cp | mv | install | ln | rsync | ditto | gcp | gmv | ginstall) _g20_copy "$head" "$@" ;;
    git)
      # git mv moves a file as mv does, from git's -C directory.
      dir=$_G20_DIR
      for w in "$@"; do
        if [ "$m" = 1 ]; then
          inner[n]=$w
          n=$((n + 1))
          continue
        fi
        case "$skip" in
          1) skip=0; continue ;;
          C) skip=0; _g20_abs "$w"; _G20_DIR=$_G20_P; continue ;;
        esac
        case "$w" in
          -C) skip=C ;;
          -c | --config-env | --git-dir | --work-tree | --namespace | --super-prefix | --attr-source) skip=1 ;;
          -*) ;;
          mv) m=1 ;;
          *) break ;;
        esac
      done
      [ "$m" = 0 ] || [ "$n" = 0 ] || _g20_copy mv "${inner[@]}"
      _G20_DIR=$dir
      ;;
    find)
      for w in "$@"; do
        if [ "$m" = 1 ]; then
          case "$w" in
            ';' | +)
              _g20_cmd "${inner[@]}"
              m=0
              n=0
              inner=()
              ;;
            *) inner[n]=$w; n=$((n + 1)) ;;
          esac
        else
          case "$w" in -exec | -execdir | -ok | -okdir) m=1 ;; esac
        fi
      done
      [ "$n" = 0 ] || _g20_cmd "${inner[@]}"
      ;;
    xargs | parallel)
      # The command xargs runs, with {} for the names it appends.
      for w in "$@"; do
        if [ "$m" = 1 ]; then
          inner[n]=$w
          n=$((n + 1))
        elif [ "$skip" = 1 ]; then
          skip=0
        else
          case "$w" in
            -I | -n | -P | -L | -s | -d | -E | -a | -J | -R | -S | -j | --max-args | --max-procs | --delimiter | \
              --arg-file | --replace) skip=1 ;;
            -*) ;;
            *) inner[n]=$w; n=$((n + 1)); m=1 ;;
          esac
        fi
      done
      [ "$n" = 0 ] || _g20_cmd "${inner[@]}" '{}'
      ;;
    python* | pypy* | node | nodejs | bun | deno | ruby | php | lua | osascript | rscript | pwsh | tclsh)
      if [ "$_G20_W$_G20_M" = 11 ] && _g20_inline "$@"; then
        _G20_WHY="$head runs inline code in a command that names a Markdown file and holds the word approved; $_G20_USE_TOOL"
      fi
      ;;
  esac
  return 0
}

# _g20_seg SIMPLE_COMMAND: _g20_seg1 from each directory in _G20_DIRS, the record's words read once. When
# nothing in it depends on the directory (no relative path, no cd: _G20_REL stays 0), the first judgement
# stands for every directory. Otherwise the directories after it are each one's _G20_DIR once the command
# ran, and also each one itself when the command holds a cd G20 does not follow for certain (_G20_STAY,
# cmd_plain), and every directory the command was in (_G20_SEEN) after a cd that can go back
# (_G20_BACK). The set holds at most 16; past that _G20_OVER is set and the rest are not followed, so a
# relative write or a Markdown write is denied (_g20_target), until a plain cd to an absolute target. A
# read, and an absolute write that is not Markdown, are judged as before.
_g20_seg() {
  local d next="" n=0 nl=$'\n' x back=0 first=1 w r t f=0 dirs=()
  _G20_REC=$1
  _G20_PLAIN=""
  # The words do not depend on the directory: the redirect targets (_G20_TGT), the other file words
  # (_G20_SRCW) and the command without its redirections (_G20_CWA).
  _G20_TGT=()
  _G20_SRCW=()
  _G20_CWA=()
  while IFS= read -r w; do
    if [ "$f" = 1 ]; then
      f=0
      _G20_TGT+=("$w")
      continue
    fi
    # r: the word without a leading fd number, to read a redirection.
    r=${w#"${w%%[!0123456789]*}"}
    t=''
    case "$r" in
      '>' | '>>' | '>|' | '&>' | '&>>' | '<>' | '>&') f=1 ;;
      '&>>'*) _G20_TGT+=("${r#'&>>'}") ;;
      '&>'*) _G20_TGT+=("${r#'&>'}") ;;
      '>>'*) _G20_TGT+=("${r#'>>'}") ;;
      '>|'*) _G20_TGT+=("${r#'>|'}") ;;
      '<>'*) _G20_TGT+=("${r#'<>'}") ;;
      '>&'*) case "${r#'>&'}" in *[!0123456789-]*) _G20_TGT+=("${r#'>&'}") ;; esac ;;
      '>'*) _G20_TGT+=("${r#'>'}") ;;
      '<<'*) ;;
      '<'*) t=${r#'<'} ;;
      *) t=${w#if=} ;;
    esac
    case "$t" in '' | -*) ;; *) _g20_dyn "$t" || _G20_SRCW+=("$t") ;; esac
  done <<WORDS
$(_shell_words "$1")
WORDS
  f=0
  while IFS= read -r w; do
    if [ "$f" = 1 ]; then
      f=0
      continue
    fi
    r=${w#"${w%%[!0123456789]*}"}
    case "$r" in
      '>' | '>>' | '>|' | '&>' | '&>>' | '<>' | '>&' | '<' | '<<' | '<<<') f=1 ;;
      '>'* | '&>'* | '<'*) ;;
      *) _G20_CWA+=("$w") ;;
    esac
  done <<WORDS
$(_cmd_words "$1")
WORDS
  while IFS= read -r d; do
    [ -n "$d" ] && dirs+=("$d")
  done <<DIRS
$_G20_DIRS
DIRS
  for d in "${dirs[@]}"; do
    _G20_DIR=$d
    _G20_STAY=0
    _G20_BACK=0
    _G20_REL=0
    _g20_seg1
    [ -z "$_G20_WHY" ] || return 0
    [ "$first" = 0 ] || [ "$_G20_REL" = 1 ] || return 0
    first=0
    for x in "$_G20_DIR" "$d"; do
      case "$nl$next" in
        *"$nl$x$nl"*) ;;
        *) if [ "$n" -lt 16 ]; then next="$next$x$nl"; n=$((n + 1)); else _G20_OVER=1; fi ;;
      esac
      [ "$_G20_STAY" = 1 ] || break
    done
    [ "$_G20_BACK" = 0 ] || back=1
  done
  if [ "$back" = 1 ]; then
    while IFS= read -r x; do
      [ -n "$x" ] || continue
      case "$nl$next" in
        *"$nl$x$nl"*) ;;
        *) if [ "$n" -lt 16 ]; then next="$next$x$nl"; n=$((n + 1)); else _G20_OVER=1; fi ;;
      esac
    done <<SEEN
$_G20_SEEN
SEEN
  fi
  # A plain cd that takes every directory to one (an absolute target) leaves no directory unfollowed.
  if [ "$_G20_OVER" = 1 ] && [ "$_G20_PLAIN" = 1 ] && [ "$back" = 0 ] && [ "$n" = 1 ]; then _G20_OVER=0; fi
  _G20_DIRS=$next
  while IFS= read -r x; do
    [ -n "$x" ] || continue
    case "$nl$_G20_SEEN" in *"$nl$x$nl"*) ;; *) _G20_SEEN="$_G20_SEEN$x$nl" ;; esac
  done <<NEXT
$next
NEXT
}

# _g20_seg1: the record _g20_seg read, from _G20_DIR: its redirect targets, its other file words (into
# _G20_SRC as absolute paths) and its command. A record that writes a working file is denied when it runs
# a text editor and the command holds approved: the edit can set an approval with the word anywhere.
# Otherwise its file words go to _G20_COPY, which _g20_bash reads as it reads a Markdown write's sources.
_g20_seg1() {
  local w n=0
  if [ "$_G20_JOIN" = 0 ]; then
    n=${#_G20_SRC[@]}
    _G20_WW=0
    _G20_ED=0
  fi
  for w in ${_G20_TGT[@]+"${_G20_TGT[@]}"}; do _g20_target "$w"; done
  for w in ${_G20_SRCW[@]+"${_G20_SRCW[@]}"}; do
    _g20_abs "$w"
    _G20_SRC+=("$_G20_P")
  done
  [ ${#_G20_CWA[@]} = 0 ] || _g20_cmd "${_G20_CWA[@]}"
  [ "$_G20_WW" = 1 ] && [ -z "$_G20_WHY" ] || return 0
  if [ "$_G20_ED$_G20_W" = 11 ]; then
    _G20_WHY="a text editor in a command that holds the word approved writes a working file, and could set an approval there; $_G20_USE_TOOL"
    return 0
  fi
  while [ "$n" -lt "${#_G20_SRC[@]}" ]; do
    _G20_COPY+=("${_G20_SRC[$n]}")
    n=$((n + 1))
  done
}

# _g20_joined COMMAND RECORDS: exit 0 when text may pass between COMMAND's simple commands (RECORDS, from
# git_words), so one that writes a working file is judged with the others. _split_words leaves out quoted
# here-doc bodies and keeps quoted words whole, so a | or a ( in those does not count:
# - A substitution, live in a word or in an unquoted body, makes git_words differ from _split_words.
# - A pipe or a paren splits a record only where it is an operator, so replacing them changes the records
#   only there. || joins nothing.
# - A redirect on a group, a subshell, a loop, an if or a case is a record that starts with it, or with
#   the word that closes the compound; exec's lasts for the rest of the command.
# sed and tr make the replacements, since ${var//[...]/} on whole command text is cubic (contract.md).
_g20_joined() {
  local c s rec w
  case "$1" in
    *'|'* | *'('* | *'`'*)
      s=$(_split_words "$1")
      [ "${s%$'\n\t.'}" = "$2" ] || return 0
      c=$(printf '%s' "$1" | env LC_ALL=C sed 's/||/;/g') || return 0
      [ "$(_split_words "$c" | env LC_ALL=C tr '|()' '___')" = "$(_split_words "$(printf '%s' "$c" | env LC_ALL=C tr '|()' '___')")" ] || return 0
      ;;
  esac
  while IFS= read -r rec; do
    w=${rec%%[[:space:]\<\>]*}
    case "$w" in '' | '&' | [0123456789] | [0123456789][0123456789] | 'done' | 'fi' | 'esac' | exec) return 0 ;; esac
  done <<RECORDS
$2
RECORDS
  return 1
}

_g20_bash() {
  local cmd t seg s recs
  cmd=$(ti_get command) || return 0
  t=$cmd
  case "$t" in *[\"\'\\]*) t=$(printf '%s' "$t" | env LC_ALL=C tr -d "\"'\\\\") ;; esac
  _G20_W=0
  _G20_M=0
  case "$t" in *[Aa][Pp][Pp][Rr][Oo][Vv][Ee][Dd]*) _G20_W=1 ;; esac
  case "$t" in *.[Mm][Dd]* | *.[Mm][Aa][Rr][Kk][Dd][Oo][Ww][Nn]*) _G20_M=1 ;; esac
  [ "$_G20_W$_G20_M" != 00 ] || return 0
  _G20_S=0
  if _g20_both "$t"; then _G20_S=1; fi
  recs=$(git_words "$cmd")
  _G20_JOIN=0
  if _g20_joined "$cmd" "$recs"; then _G20_JOIN=1; fi
  _G20_WW=0
  _G20_ED=0
  _G20_COPY=()
  _G20_DIRS=${CWD:-$PWD}
  _G20_SEEN="${CWD:-$PWD}"$'\n'
  _G20_OVER=0
  _G20_WRITES=0
  _G20_SRC=()
  _G20_WHY=''
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    _g20_seg "$seg"
    [ -z "$_G20_WHY" ] || break
  done <<CMD
$recs
CMD
  # A command that writes a Markdown file and also names a file holding a status: approved line, in its
  # frontmatter or not, can copy an approval in (cp, cat, tee or tail from a prepared file). A working
  # file counts only the names in _G20_COPY, so a write beside a read of an approved file stays silent.
  # Each path is read once; past 1024 of them the command is denied, since the rest would go unread.
  [ "$_G20_WRITES" = 0 ] || _G20_COPY=(${_G20_SRC[@]+"${_G20_SRC[@]}"})
  if [ -z "$_G20_WHY" ] && [ "${#_G20_COPY[@]}" -gt 0 ]; then
    s=$(printf '%s\n' "${_G20_COPY[@]}" | env LC_ALL=C awk '!s[$0]++')
    if [ "$(printf '%s\n' "$s" | wc -l)" -gt 1024 ]; then
      _G20_WHY="the command writes a Markdown file and names more files than G20 reads (1024), so one could copy an approval past the quote check; write fewer files per call"
    else
      while IFS= read -r t; do
        if _g20_holds "$t"; then
          _G20_WHY="the command writes a Markdown file and names $(basename "$t"), which holds a status: approved line, so it can copy an approval past the quote check; $_G20_USE_TOOL"
          break
        fi
      done <<SRC
$s
SRC
    fi
  fi
  [ -z "$_G20_WHY" ] || vote deny G20 "$_G20_WHY"
  return 0
}
