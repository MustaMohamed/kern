# shellcheck shell=bash
# shellcheck disable=SC2154  # TOOL, CWD, SID and AUTOPILOT are set by hooks/pre-tool-use
# G20 approval: a Markdown file (a spec or plan under the work dir, or the project's own spec system
# under docs/) becomes `status: approved`, or changes the approved: line of an approved file, only on
# the user's own words. The check reads the file as it will be after the Write or Edit, so splitting
# the change over two edits does not get past it. The approved: line must quote one whole line of the
# user's last message, verbatim, that is not a non-answer such as "sounds good", and the file must be
# older than that message. prompt-submit records the message's line hashes in the session state, which
# G16 protects, along with kern's hooks themselves, so the model cannot run prompt-submit to forge the
# message. Under autopilot nothing approves. G20 never votes allow. ledger-open runs only a plan with a
# Markdown name, and G20, ledger-open and plan-check read frontmatter with one reader
# (scripts/lib/frontmatter.awk), so every approval ledger-open accepts passed through G20.
#
# Accepted limits:
# - "The user's last message" is the last prompt prompt-submit does not read as wrapped. A prompt
#   Claude Code starts itself that wrapped() misses counts as the user's, and its lines can be quoted.
# - An AskUserQuestion answer is a tool result, not a prompt, so it is not recorded and cannot approve;
#   define and plan ask for the yes as a typed reply.
# - The approval does not bind the content. An approved file whose approved: lines stay the same can be
#   rewritten by Edit or Write, the approval edit itself may change the body, and a new file has no
#   draft to be older than the message, so removing a draft and writing it anew with a real quote passes.
# - The hash is djb2, not a cryptographic hash: a quote built to collide with a line of the message
#   passes. A shell write that hides the path or the word (a script run by name, a word built at run
#   time, a recursive directory copy, git checkout or apply, a hard link) is not seen.
_G20_NOT_YES=" sounds good | whatever you think | whatever | up to you | your call | you decide | i guess | maybe | not sure | looks fine i guess | no | nope | not yet | wait | stop | don't | do not "
# A right single quote, read as an apostrophe in a non-answer ("don't").
_G20_RSQ=$'\342\200\231'
_G20_USE_TOOL="set or change an approval with the Edit or Write tool, so kern can check the user's quote"

# The frontmatter reader G20 shares with ledger-open and plan-check, so all three agree on where a
# file's frontmatter ends.
_G20_FM_FILE="$KERN_ROOT/scripts/lib/frontmatter.awk"

# A status: approved line, bare or quoted, in any case, with any blanks around the colon and an optional
# comment after it.
_G20_STATUS_RE="^[[:space:]]*[\"']?status[\"']?[[:space:]]*:[[:space:]]*[\"']?approved[\"']?[[:space:]]*(#.*)?\$"

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
  printf '%s\n' "$1" | LC_ALL=C grep -Eiq "$_G20_STATUS_RE"
}

# _g20_holds FILE: exit 0 when any line of FILE sets status: approved, in its frontmatter or not. A
# shell edit can turn body lines into frontmatter (sed deleting a ---, tail dropping a first line), so
# for a shell write every line counts.
_g20_holds() {
  [ -f "$1" ] && [ -r "$1" ] && LC_ALL=C grep -Eiq "$_G20_STATUS_RE" "$1" 2> /dev/null
}

# _g20_lines FRONTMATTER: the value of every approved: line, in order.
_g20_lines() {
  printf '%s\n' "$1" |
    LC_ALL=C sed -n -E "s/^[[:space:]]*[\"']?[Aa][Pp][Pp][Rr][Oo][Vv][Ee][Dd][\"']?[[:space:]]*:[[:space:]]*//p"
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

# _g20_fm NAME: sets _G20_FM to the frontmatter of the text on stdin (NAME's), read by the shared
# reader; an unclosed block counts to its end. Fails closed, and returns 1, when the reader cannot run.
_g20_fm() {
  local rc=0
  _G20_FM=$(LC_ALL=C awk -v fm_print=1 -f "$_G20_FM_FILE" 2> /dev/null) || rc=$?
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
  local p base text old='' new all post rc before after lines quote norm qh hashes sf
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
    _g20_fm "$base" <<< "${text%x}" || return 0
  else
    new=$(ti_get new_string && printf x) || return 0
    new=${new%x}
    all=$(KERN_INPUT="${TOOL_INPUT-}" json_get_raw replace_all 2> /dev/null) || all=false
    rc=4
    if [ -f "$p" ]; then
      rc=0
      post=$(G20_OLD="$old" G20_NEW="$new" G20_ALL="$all" LC_ALL=C awk "$_G20_EDIT_AWK" "$p" 2> /dev/null) || rc=$?
    fi
    case "$rc" in
      0) _g20_fm "$base" <<< "$post" || return 0 ;;
      4)
        # G20's model of the Edit found nothing to replace. If Claude Code's own matching differs, an
        # Edit that writes a status or approved: line could approve unseen, so it fails closed.
        if printf '%s\n' "$new" | LC_ALL=C grep -Eiq "^[[:space:]]*[\"']?(status|approved)[\"']?[[:space:]]*:"; then
          vote deny G20 "old_string is not in $base as G20 reads it, so it cannot judge an Edit that writes a status or approved: line; read the file and edit it again"
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
  _g20_approved "$after" || return 0
  lines=$(_g20_lines "$after")
  # An approved file whose approved: lines stay the same is not being approved now.
  if _g20_approved "$before" && [ "$(_g20_lines "$before")" = "$lines" ]; then return 0; fi
  if [ "${AUTOPILOT:-0}" = 1 ]; then
    vote deny G20 "under autopilot nothing approves a spec or plan; keep status: draft (parked under autopilot) and park the question"
    return 0
  fi
  # The quote runs from the first double quote of the first approved: line to its last, so a user's
  # line that holds a double quote can still be quoted whole.
  quote=$(printf '%s\n' "$lines" | head -n 1 | sed -n 's/^[^"]*"\(.*\)".*$/\1/p')
  if [ -z "$quote" ]; then
    vote deny G20 "status: approved needs an approved: line with the date and the user's words in double quotes, in the same edit"
    return 0
  fi
  norm=$(printf '%s\n' "$quote" | LC_ALL=C tr '[:upper:]' '[:lower:]' |
    sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ $//' -e 's/[.!?,;:]*$//' -e 's/ $//')
  norm=${norm//$_G20_RSQ/\'}
  case "$_G20_NOT_YES" in
    *" $norm "*)
      vote deny G20 "\"$quote\" is not an explicit yes; ask the user for one"
      return 0
      ;;
  esac
  # A quote with no hash (blank, or over 500 characters) matches nothing, not an empty record.
  qh=$(printf '%s\n' "$quote" | prompt_hashes)
  hashes=$(state_get "$SID" prompt_hashes 2> /dev/null) || hashes=''
  case " $hashes " in
    *" ${qh:-none} "*) ;;
    *)
      vote deny G20 "the approved: quote is not a line of the user's last message; quote one whole line of it verbatim, or ask for a yes"
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

# A shell command that writes a Markdown file could set or change an approval without the quote
# check. _g20_bash reads each simple command (git_words) and denies when one writes a Markdown file
# (a redirect; an operand of sed -i, perl -i, awk or gawk -i inplace, ed, ex, vi, vim, tee, truncate or
# sponge; dd of=; the destination of cp, mv, install, ln, rsync, ditto or git mv; the same inside
# find -exec and xargs) and the command holds the word approved, or the file holds a status: approved
# line now, or the command names another file that does (cp, cat, tee or tail from a prepared file);
# any line counts, not only frontmatter, because a shell edit can move body lines into it. A
# script interpreter running inline code (python -c, node -e, a here-doc on stdin) is denied when the
# command holds both approved and a Markdown name. With approved in the command, a destination built
# at run time (a glob, a variable, find's {}) is denied too. A script run by name, or a word built at
# run time, is not seen (accepted limit).
#
# State for one command: _G20_W is 1 when the command holds approved (quotes and backslashes taken out,
# any case), _G20_M when it names a Markdown file. _G20_DIR follows cd. _G20_WRITES is 1 once a simple
# command writes a Markdown file. _G20_SRC holds the command's other file words as absolute paths, one
# per line. _G20_WHY is the deny reason; the first one ends the check.

# _g20_dyn WORD: exit 0 when WORD may name other files at run time: a glob, a $, a backtick or a brace.
_g20_dyn() {
  case "$1" in *'*'* | *'?'* | *'['* | *'$'* | *'`'* | *'{'*) return 0 ;; esac
  return 1
}

# _g20_abs WORD: sets _G20_P to WORD as an absolute path, from _G20_DIR.
_g20_abs() {
  case "$1" in
    /*) _G20_P=$1 ;;
    '~') _G20_P=$HOME ;;
    '~'/*) _G20_P="$HOME${1#'~'}" ;;
    *) _G20_P="$_G20_DIR/$1" ;;
  esac
}

# _g20_target WORD: WORD is a file a simple command writes.
_g20_target() {
  local w="$1"
  [ -n "$w" ] && [ -z "$_G20_WHY" ] || return 0
  if _g20_dyn "$w" && [ "$_G20_W" = 1 ]; then
    _G20_WHY="the command holds the word approved and writes $w, which may be a Markdown file; $_G20_USE_TOOL"
    return 0
  fi
  _g20_abs "$w"
  _g20_md "$w" || _g20_mdfile "$_G20_P" || return 0
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
# program, and _G20_I to 1 when an option cluster holds i or a word is --in-place. In a cluster such as
# -nE or -pi.bak, a letter in CODE gives the script and a letter in VALUE takes a value, each from the
# rest of the cluster or else the next word; a letter in REST takes the rest of the cluster only; a
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
      case "${ops[$i]}" in /*) ;; *) _G20_SRC="$_G20_SRC$dir/${ops[$i]}
" ;; esac
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
  case "$head" in *[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) head=$(printf '%s' "$head" | LC_ALL=C tr '[:upper:]' '[:lower:]') ;; esac
  shift
  case "$head" in
    cd | pushd)
      w=$HOME
      for i in "$@"; do
        case "$i" in -*) ;; *) w=$i; break ;; esac
      done
      _g20_dyn "$w" || { _g20_abs "$w"; _G20_DIR=$_G20_P; }
      ;;
    sed | perl)
      if [ "$head" = sed ]; then
        _g20_ops ef l '' i "--expression --file --line-length" "--expression --file" "$@"
      else
        _g20_ops eE '' iIMm0lxCdD '' '' '' "$@"
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
      for w in "$@"; do
        if [ "$skip" = 1 ]; then
          skip=0
          continue
        fi
        case "$head:$w" in
          truncate:-s | truncate:-r | truncate:--size | truncate:--reference | ed:-p | \
            [evn]*:-c | [evn]*:-S | [evn]*:--cmd | [evn]*:-u | [evn]*:-U | [evn]*:-i | [evn]*:-T | [evn]*:-w | \
            [evn]*:-W | [evn]*:-s | [evn]*:-t | [evn]*:-q) skip=1 ;;
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

# _g20_seg SIMPLE_COMMAND: its redirect targets, its file words (into _G20_SRC) and its command.
_g20_seg() {
  local w r s f=0 c=0 cw=()
  while IFS= read -r w; do
    if [ "$f" = 1 ]; then
      f=0
      _g20_target "$w"
      continue
    fi
    # r: the word without a leading fd number, to read a redirection.
    r=${w#"${w%%[!0123456789]*}"}
    s=''
    case "$r" in
      '>' | '>>' | '>|' | '&>' | '&>>' | '<>' | '>&') f=1 ;;
      '&>>'*) _g20_target "${r#'&>>'}" ;;
      '&>'*) _g20_target "${r#'&>'}" ;;
      '>>'*) _g20_target "${r#'>>'}" ;;
      '>|'*) _g20_target "${r#'>|'}" ;;
      '<>'*) _g20_target "${r#'<>'}" ;;
      '>&'*) case "${r#'>&'}" in *[!0123456789-]*) _g20_target "${r#'>&'}" ;; esac ;;
      '>'*) _g20_target "${r#'>'}" ;;
      '<<'*) ;;
      '<'*) s=${r#'<'} ;;
      *) s=${w#if=} ;;
    esac
    case "$s" in '' | -*) ;; *) _g20_dyn "$s" || { _g20_abs "$s"; _G20_SRC="$_G20_SRC$_G20_P
"; } ;; esac
  done <<WORDS
$(_shell_words "$1")
WORDS
  # The command, without its redirections.
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
      *) cw[c]=$w; c=$((c + 1)) ;;
    esac
  done <<WORDS
$(_cmd_words "$1")
WORDS
  [ "$c" = 0 ] || _g20_cmd "${cw[@]}"
}

_g20_bash() {
  local cmd t seg s
  cmd=$(ti_get command) || return 0
  t=$cmd
  case "$t" in *[\"\'\\]*) t=$(printf '%s' "$t" | LC_ALL=C tr -d "\"'\\\\") ;; esac
  _G20_W=0
  _G20_M=0
  case "$t" in *[Aa][Pp][Pp][Rr][Oo][Vv][Ee][Dd]*) _G20_W=1 ;; esac
  case "$t" in *.[Mm][Dd]* | *.[Mm][Aa][Rr][Kk][Dd][Oo][Ww][Nn]*) _G20_M=1 ;; esac
  [ "$_G20_W$_G20_M" != 00 ] || return 0
  _G20_DIR=${CWD:-$PWD}
  _G20_WRITES=0
  _G20_SRC=''
  _G20_WHY=''
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    _g20_seg "$seg"
    [ -z "$_G20_WHY" ] || break
  done <<CMD
$(git_words "$cmd")
CMD
  # A command that writes a Markdown file and also names a file holding a status: approved line, in its
  # frontmatter or not, can copy an approval in (cp, cat, tee or tail from a prepared file).
  if [ -z "$_G20_WHY" ] && [ "$_G20_WRITES" = 1 ]; then
    while IFS= read -r s; do
      if _g20_holds "$s"; then
        _G20_WHY="the command writes a Markdown file and names $(basename "$s"), which holds a status: approved line, so it can copy an approval past the quote check; $_G20_USE_TOOL"
        break
      fi
    done <<SRC
$(printf '%s' "$_G20_SRC" | head -n 64)
SRC
  fi
  [ -z "$_G20_WHY" ] || vote deny G20 "$_G20_WHY"
  return 0
}
