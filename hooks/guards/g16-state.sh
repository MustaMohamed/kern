# shellcheck shell=bash
# G16 mode state: Claude cannot write kern's session state or schedule a prompt that switches it,
# and the user confirms every write to a kern settings file or to Claude Code's own settings, every
# Write, Edit or NotebookEdit whose target resolves under kern's hooks/ directory, and every command
# that names kern's hook code (a hook entry file, a .sh file under hooks/lib/ or hooks/guards/) or a
# state function, which could forge the user's prompt or turn a guard off.
# Accepted limits: a path held in a variable or built at run time; a hooks directory reached without
# naming it (find -exec, cd into a glob); interpreter code that builds a hook path; a script written
# to disk and then run by name; and any other spelling of a hook path than the ones _g16_hooks reads
# (any case, line continuations, the APFS folds of s and k, quotes, backslashes, globs and braces).

_G16_STATE_FILE="kern session state is written only by kern hooks; ask the user to type /kern:mode or /kern:autopilot"
_G16_STATE_CMD="commands may not write kern session state"
_G16_SETTINGS="kern settings change guard policy; the user confirms each write"
_G16_CC="Claude Code settings set permissions and hooks; the user confirms each write"
_G16_TAB=$'\t'
_G16_INTO="a command other than a read names a .claude directory, where kern and Claude Code settings live; the user confirms each write"
_G16_HOOKS="the command names kern's hook code or a state function, and running a hook or calling state_set could forge the user's prompt or the session state; read hook files with the Read or Grep tool"
_G16_HOOK_FILE="the target is kern's own hook code, under its hooks directory, which every guard and the approval check rely on; the user confirms each write"
_G16_HOOK_NAMES="prompt-submit session-start subagent-start pre-tool-use"
# U+017F (long s) and U+212A (Kelvin sign), in UTF-8: APFS folds them to s and k in a file name.
_G16_LONG_S=$'\305\277'
_G16_KELVIN=$'\342\204\252'
# _G16_HOOK_AWK: reads the command text, lower-cased. Prints `hit` when a line names a hook after
# hooks/ (or hooks// or hooks/./), a .sh file under hooks/lib/ or hooks/guards/, or a state function as
# a word; a hook
# counts only when the character after it cannot go on a file name, so pre-tool-use.bats does not.
# Otherwise prints `ctx` when a line names a hooks directory (else `-`), then each word, split at
# blanks, CR, ; | & < > ) and =.
# shellcheck disable=SC2016 # awk text
_G16_HOOK_AWK='
BEGIN {
  a = "abcdefghijklmnopqrstuvwxyz0123456789"
  e = "([^" a "._-]|$)"
  hit = "hooks/(/|[.]/)*(prompt-submit|session-start|subagent-start|pre-tool-use)" e "|hooks/lib/[^/ \t\r;|&<>()]*[.]sh"
  hit = hit "|hooks/guards/[^/ \t\r;|&<>()]*[.]sh"
  hit = hit "|(^|[^" a "_])(state_set|_state_put|state_reset|state_ensure)([^" a "_]|$)"
  dir = "(^|[^" a "._-])hooks" e
}
{ $0 = tolower($0) }
$0 ~ hit { print "hit"; found = 1; exit }
$0 ~ dir { ctx = 1 }
{ n = split($0, w, /[ \t\r;|&<>)=]+/); for (i = 1; i <= n; i++) if (w[i] != "") words = words w[i] "\n" }
END { if (!found) printf "%s\n%s", (ctx ? "ctx" : "-"), words }'

guard_g16() {
  case "$TOOL" in
    Write | Edit | NotebookEdit) _g16_file ;;
    Bash)
      _g16_bash
      _g16_hooks
      ;;
    CronCreate | ScheduleWakeup | RemoteTrigger | SendMessage) _g16_relay ;;
    Skill) _g16_skill ;;
  esac
}

# _g16_fold STR: sets _G16_F to STR with the long s and the Kelvin sign read as s and k, as APFS folds
# them in a file name, so .claude/<long s>ettings.json is read as Claude Code's settings.
_g16_fold() {
  _G16_F=${1//$_G16_LONG_S/s}
  _G16_F=${_G16_F//$_G16_KELVIN/k}
}

# _g16_lower STR: STR in lower case (bash 3.2 has no ${var,,}).
_g16_lower() {
  printf '%s' "$1" | env LC_ALL=C tr '[:upper:]' '[:lower:]'
}

# _g16_norm PATH: absolute PATH with `.`, `..` and repeated slashes resolved as text, so a `..`
# through a directory that does not exist yet is still seen.
_g16_norm() {
  printf '%s\n' "$1" | env LC_ALL=C awk -F/ '{
    n = 0
    for (i = 1; i <= NF; i++) {
      if ($i == "" || $i == ".") continue
      if ($i == "..") { if (n) n--; continue }
      s[++n] = $i
    }
    out = ""
    for (i = 1; i <= n; i++) out = out "/" s[i]
    print (out == "" ? "/" : out)
  }'
}

# _g16_phys PATH: prints absolute PATH with its deepest existing directory resolved physically (cd -P,
# so a symlinked directory and a `..` after one are followed) and the rest as text; exit 1 when even
# / cannot be entered.
_g16_phys() {
  local d="${1%/*}" rest="${1##*/}" r
  [ -n "$d" ] || d=/
  while [ ! -d "$d" ]; do
    rest="${d##*/}/$rest"
    d=${d%/*}
    [ -n "$d" ] || d=/
  done
  r=$(cd -P "$d" 2>/dev/null && pwd -P) || return 1
  printf '%s\n' "${r%/}/$rest"
}

# _g16_hookfile PATH: exit 0 when absolute PATH resolves under kern's hooks/ directory, compared in lower
# case (APFS opens HOOKS/ as hooks/): as text with `..` resolved, through its physical directory, and
# through a symlink at its end, followed up to 8 links. kern's root is read as written and physically.
_g16_hookfile() {
  local p c l i=0 kr="" kp="" cands
  kr=$(_g16_lower "$(_g16_norm "$KERN_ROOT/hooks")")
  kp=$(cd -P "$KERN_ROOT/hooks" 2>/dev/null && pwd -P) && kp=$(_g16_lower "$kp")
  p=$(_g16_norm "$1")
  cands=$p
  p=$(_g16_phys "$p") && cands="$cands
$p"
  while [ "$i" -lt 8 ] && [ -L "$p" ] && l=$(readlink "$p"); do
    case "$l" in /*) ;; *) l="${p%/*}/$l" ;; esac
    p=$(_g16_phys "$l") || break
    cands="$cands
$p
$(_g16_norm "$p")"
    i=$((i + 1))
  done
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    c=$(_g16_lower "$c")
    case "$c" in "$kr"/*) return 0 ;; esac
    if [ -n "$kp" ]; then
      case "$c" in "$kp"/*) return 0 ;; esac
    fi
  done <<EOF
$cands
EOF
  return 1
}

# _g16_file: a Write, Edit or NotebookEdit target, compared in lower case as written, with `..`
# resolved, and through its physical parent dir, so a case variant or a symlinked dir is seen.
_g16_file() {
  local p norm real="" sd rsd="" c
  p=$(ti_get file_path) || p=$(ti_get notebook_path) || return 0
  _g16_fold "$p"
  p=$_G16_F
  case "$p" in /*) ;; *) p="${CWD:-$PWD}/$p" ;; esac
  norm=$(_g16_norm "$p")
  real=$(cd "$(dirname "$norm")" 2>/dev/null && pwd -P) && real="$real/${norm##*/}"
  sd=$(_g16_lower "$(state_dir)")
  rsd=$(cd "$(state_dir)" 2>/dev/null && pwd -P) && rsd=$(_g16_lower "$rsd")
  for c in "$p" "$norm" "$real"; do
    [ -n "$c" ] || continue
    c=$(_g16_lower "$c")
    case "$c" in
      "$sd"/* | */plugins/data/kern*/sessions/*) vote deny G16 "$_G16_STATE_FILE"; return 0 ;;
    esac
    if [ -n "$rsd" ]; then
      case "$c" in "$rsd"/*) vote deny G16 "$_G16_STATE_FILE"; return 0 ;; esac
    fi
  done
  if _g16_hookfile "$norm"; then
    vote ask G16 "$_G16_HOOK_FILE"
    return 0
  fi
  for c in "$p" "$norm" "$real"; do
    case "$(_g16_lower "$c")" in
      */.claude/kern.yml | */.claude/kern.local.yml) vote ask G16 "$_G16_SETTINGS"; return 0 ;;
      */.claude/settings.json | */.claude/settings.local.json) vote ask G16 "$_G16_CC"; return 0 ;;
    esac
  done
}

# _g16_tidy WORD: sets _G16_T to WORD with empty and `.` parts dropped and each `..` taking the part
# before it, as text, as _g16_norm does for a Write path; a leading / stays, a relative WORD stays
# relative (its leading `..` kept), and a WORD with nothing left is `.`.
_g16_tidy() {
  local rest="$1/" s out=() n=0 i=0 j="" lead=""
  case "$1" in /*) lead=/ ;; esac
  while [ -n "$rest" ]; do
    s=${rest%%/*}
    rest=${rest#*/}
    case "$s" in
      "" | .) ;;
      ..)
        if [ "$n" -gt 0 ] && [ "${out[$((n - 1))]}" != .. ]; then
          n=$((n - 1))
        elif [ -z "$lead" ]; then
          out[n]=..
          n=$((n + 1))
        fi
        ;;
      *)
        out[n]=$s
        n=$((n + 1))
        ;;
    esac
  done
  while [ "$i" -lt "$n" ]; do
    j="$j${j:+/}${out[$i]}"
    i=$((i + 1))
  done
  _G16_T="$lead$j"
  [ -n "$_G16_T" ] || _G16_T=.
}

# _g16_kind WORD: sets _G16_K to `state` when the lower-cased WORD names session state, `settings`
# when it names a kern settings file, `cc` when it names Claude Code's own settings, else empty. As
# _g16_file reads a Write path, WORD is read as written (_g16_name), then with `.`, `..` and `//`
# resolved as text (_g16_tidy), then through its physical directory (_g16_real).
_g16_kind() {
  _g16_name "$1"
  [ -z "$_G16_K" ] || return 0
  _G16_T=$1
  case "$1" in
    . | .. | ./* | ../* | */. | */.. | *//* | */./* | */../*)
      _g16_tidy "$1"
      _g16_name "$_G16_T"
      [ -z "$_G16_K" ] || return 0
      ;;
  esac
  _g16_real "$_G16_T"
}

# _g16_real WORD: for a WORD whose last part is a kern or Claude Code settings file name, sets _G16_K
# when the file's directory is a .claude directory: a bare name after a cd into one earlier in the
# command (_G16_INCC), or a directory that resolves to one, from CWD, through symlinks. A directory
# that would expand is not read.
_g16_real() {
  local d
  case "${1##*/}" in
    kern.yml | kern.local.yml) _G16_K=settings ;;
    settings.json | settings.local.json) _G16_K=cc ;;
    *) return 0 ;;
  esac
  case "$1" in */*) d=${1%/*} ;; *) d=. ;; esac
  [ -n "$d" ] || d=/
  [ "$d" = . ] && [ "$_G16_INCC" = 1 ] && return 0
  if _g16_physical "$d"; then return 0; fi
  _G16_K=""
}

# _g16_physical DIR: exit 0 when DIR, from CWD, resolves through symlinks to a directory named .claude
# in any case. A DIR that would expand is not read.
_g16_physical() {
  local d="$1"
  case "$d" in "" | *'$'* | *'`'* | '~'* | *'*'* | *'?'* | *'['*) return 1 ;; esac
  case "$d" in /*) ;; *) d="${CWD:-$PWD}/$d" ;; esac
  d=$(cd "$d" 2>/dev/null && pwd -P) || return 1
  case "$d" in */.[Cc][Ll][Aa][Uu][Dd][Ee]) return 0 ;; esac
  return 1
}

# _g16_pathy WORD: exit 0 unless WORD holds a blank or a newline and does not start as a path does
# (/, ~, ./, ../ or $). Read only for the value of a message option (_g16_bash): a sentence in a
# commit message or a PR title that ends in a settings path is not a path. A redirect target, a copy
# destination or any other operand is a path whatever it holds.
_g16_pathy() {
  case "$1" in
    *[[:blank:]]* | *"$_GW_NL"*)
      case "$1" in /* | '~'* | ./* | ../* | '$'*) ;; *) return 1 ;; esac
      ;;
  esac
  return 0
}

# _g16_claude WORD: exit 0 when the lower-cased WORD, read by _g16_tidy, names a .claude directory:
# `.claude`, a path ending in /.claude, or `.` after a cd into one earlier in the command.
_g16_claude() {
  _g16_tidy "$1"
  case "$_G16_T" in
    .claude | */.claude) return 0 ;;
    .) [ "$_G16_INCC" = 1 ] ;;
    *) return 1 ;;
  esac
}

# _g16_into WORD: _g16_claude, or WORD resolves to a .claude directory (_g16_physical).
_g16_into() {
  [ -n "$1" ] || return 1
  _g16_claude "$1" || _g16_physical "$1"
}

# _g16_name WORD: _g16_kind's reading of WORD as written. State: a word holding the sessions dir path (so
# of=<dir>/x counts); a word with no blank that holds `sessions` and ends in `.state` (a sentence
# in a message is not a path); the state file name <sid>.state, bare or after a slash; or an
# absolute glob that, once a leading ~, $HOME or $CLAUDE_PLUGIN_DATA is expanded, matches this
# session's state file and, unless it holds **, is as deep as it (a path glob's * does not cross
# a /). The bare session id is not enough: Claude Code's scratchpad and task paths contain it.
# Settings: a word ending in .claude/kern.yml or .claude/kern.local.yml, or exactly kern.yml or
# kern.local.yml. Claude Code's settings: a word ending in .claude/settings.json or
# .claude/settings.local.json.
_g16_name() {
  local e p a b slash='[!/]'
  _G16_K=""
  case "$1" in *"$_G16_SD"*) _G16_K=state; return 0 ;; esac
  case "$1" in
    *[[:blank:]]* | *"$_GW_NL"*) ;;
    *sessions*.state) _G16_K=state; return 0 ;;
  esac
  case "$1" in
    *.claude/kern.yml | *.claude/kern.local.yml | kern.yml | kern.local.yml) _G16_K=settings; return 0 ;;
    *.claude/settings.json | *.claude/settings.local.json) _G16_K=cc; return 0 ;;
  esac
  if [ -n "$_G16_SID" ]; then
    case "$1" in "$_G16_SID".state | */"$_G16_SID".state) _G16_K=state; return 0 ;; esac
  fi
  # shellcheck disable=SC2016 # the literal words Claude wrote, lower-cased
  case "$1" in
    '~'/*) e="$_G16_HOME${1#'~'}" ;;
    '$home'/*) e="$_G16_HOME${1#'$home'}" ;;
    '${home}'/*) e="$_G16_HOME${1#'${home}'}" ;;
    '$claude_plugin_data'/*) e="$_G16_DATA${1#'$claude_plugin_data'}" ;;
    '${claude_plugin_data}'/*) e="$_G16_DATA${1#'${claude_plugin_data}'}" ;;
    *) e="$1" ;;
  esac
  case "$e" in
    *"$_G16_SD"*) _G16_K=state; return 0 ;;
    /*[*?[]*) ;;
    *) return 0 ;;
  esac
  p="$_G16_SD/$_G16_SID.state"
  a=${e//$slash/}
  b=${p//$slash/}
  case "$e" in *'**'*) ;; *) [ "${#a}" = "${#b}" ] || return 0 ;; esac
  # shellcheck disable=SC2254 # the word is matched as the glob it is
  case "$p" in $e) _G16_K=state ;; esac
}

# _g16_gitread RECORD WORDS: exit 0 when the lower-cased git RECORD, whose words are WORDS, only
# reads: status, log, show, blame, grep, ls-files, ls-tree, cat-file, rev-parse, describe, shortlog,
# for-each-ref, check-ignore, diff, reflog show, branch --list or -l, and config --get (or --get-*),
# with no --output or --output-directory (in any unique prefix) anywhere, and no -o on diff, log,
# archive or format-patch, where it writes a file (elsewhere it reads: ls-files --others, grep
# --only-matching). Any other git, mv and rm among them, may write what it names.
_g16_gitread() {
  local s rest w n od=output-directory
  s=$(git_sub "$1") || return 1
  s=${s#*"$_G16_TAB"}
  rest=${s#*"$_G16_TAB"}
  s=${s%%"$_G16_TAB"*}
  while IFS= read -r w; do
    case "$w" in
      -o*) case "$s" in diff | log | archive | format-patch) return 1 ;; esac ;;
      --ou*)
        n=${w%%=*}
        case "$od" in "${n#--}"*) return 1 ;; esac
        ;;
    esac
  done <<EOT
$2
EOT
  case "$s" in
    status | log | show | blame | grep | ls-files | ls-tree | cat-file | rev-parse | describe | shortlog | \
      for-each-ref | check-ignore | diff) return 0 ;;
    reflog) case "$rest" in show | "show "*) return 0 ;; esac ;;
    branch) case " $rest " in *" --list "* | *" -l "*) return 0 ;; esac ;;
    config) case " $rest " in *" --get "* | *" --get-"*) return 0 ;; esac ;;
  esac
  return 1
}

# _g16_redirects STR: the target word of each `>` or `>>` outside quotes, one per line.
_g16_redirects() {
  printf '%s' "$1" | env LC_ALL=C awk -v sq="'" '
    { buf = buf (NR > 1 ? " " : "") $0 }
    END {
      n = length(buf); q = ""
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; continue }
        if (c == "\\") { i++; continue }
        if (q == "\"") { if (c == "\"") q = ""; continue }
        if (c == sq || c == "\"") { q = c; continue }
        if (c != ">") continue
        while (i < n && index(">|&", substr(buf, i + 1, 1))) i++
        while (i < n && index(" \t\037", substr(buf, i + 1, 1))) i++
        w = ""; wq = ""
        for (j = i + 1; j <= n; j++) {
          d = substr(buf, j, 1)
          if (wq != "") { if (d == wq) wq = ""; else w = w d; continue }
          if (d == "\\") { j++; w = w substr(buf, j, 1); continue }
          if (d == sq || d == "\"") { wq = d; continue }
          if (index(" \t\037;&|<>()`", d)) break
          w = w d
        }
        if (w != "") print w
        i = j - 1
      }
    }'
}

# _g16_bash: a command that names session state is denied unless its head only reads (cat head
# tail less more grep egrep fgrep rg ls stat wc file diff cmp jq echo printf test [ git, find with
# no action that writes or runs, and sed or perl without -i). Settings follow the same model and ask:
# a head that is not a reader, and names a kern settings file, Claude Code's own settings or a
# .claude directory (as an operand or an option's value, or through a symlink as the last operand).
# For this check vim and vi read, and git reads only through the subcommands _g16_gitread lists. A
# redirect into state or a settings file counts
# whatever the head. Every simple command is checked, including the bodies of bash -c, eval, $( ) and
# backticks; here-doc bodies are data unless a shell reads them. After a cd into the sessions dir,
# every later non-reading command and redirect counts as a write to it, until a cd to a known target
# outside it; after a cd into a .claude directory, `.` and a bare settings.json or settings.local.json
# are in it, until a cd to a known target. A cd whose target kern cannot know keeps both, and takes
# back each one held earlier in the command, as popd does. A variable that holds a path is not read
# (accepted limit).
_g16_bash() {
  local cmd t seg words w head inplace seg_s seg_k last nop dd skip anydir reads creads msg m sd_f cc_f
  local state=0 settings=0 cc=0 into=0 in_sd=0 dk=1 sd_seen=0 cc_seen=0 cdir mixed
  cmd=$(ti_get command) || return 0
  _g16_fold "$cmd"
  cmd=$_G16_F
  # Only a command whose text could name state, a settings file or a .claude directory, in any case,
  # is lower-cased and parsed. Quotes and backslashes are taken out first, in one tr pass and only
  # when the text holds one, so ke''rn.yml is still seen. The sessions dir ends in sessions, so its
  # path needs no pattern of its own.
  t=$cmd
  case "$t" in *[\"\'\\]*) t=$(printf '%s' "$t" | env LC_ALL=C tr -d "\"'\\\\") ;; esac
  case "$t" in
    *[Ss][Ee][Ss][Ss][Ii][Oo][Nn][Ss]* | *.[Ss][Tt][Aa][Tt][Ee]* | *[Kk][Ee][Rr][Nn].[Yy][Mm][Ll]* | \
      *[Kk][Ee][Rr][Nn].[Ll][Oo][Cc][Aa][Ll].[Yy][Mm][Ll]* | *[Ss][Ee][Tt][Tt][Ii][Nn][Gg][Ss]*.[Jj][Ss][Oo][Nn]* | \
      *.[Cc][Ll][Aa][Uu][Dd][Ee]*) ;;
    *) return 0 ;;
  esac
  # mixed: the command, quotes taken out, holds cd, pushd or popd in another case. An upper-case CD runs
  # /usr/bin/cd on macOS, which never moves the shell; once the text is lower-cased it would read as a
  # plain cd, so no cd in such a command is plain.
  mixed=0
  case "$t" in
    *[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*)
      if printf '%s' "$t" | env LC_ALL=C awk '
        { n = split($0, w, /[^A-Za-z]+/); for (i = 1; i <= n; i++) if (w[i] != tolower(w[i]) && tolower(w[i]) ~ /^(cd|pushd|popd)$/) f = 1 }
        END { exit !f }'; then
        mixed=1
      fi
      ;;
  esac
  cmd=$(_g16_lower "$cmd")
  _G16_SD=$(_g16_lower "$(state_dir)")
  _G16_SID=$(_g16_lower "${SID-}")
  _G16_HOME=$(_g16_lower "${HOME-}")
  _G16_DATA=${_G16_SD%/sessions}
  _G16_INCC=0
  # cdir: the directory while dk is 1, lower-cased text with . and .. resolved as text.
  cdir=$(_g16_lower "${CWD:-$PWD}")
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    # The command name comes first, after the assignments, keywords and wrappers _cmd_words skips.
    words=$(_cmd_words "$seg")
    head=""
    inplace=0
    seg_s=0
    seg_k=""
    last=""
    nop=0
    dd=0
    skip=0
    anydir=0
    msg=0
    while IFS= read -r w; do
      if [ -z "$head" ]; then
        head=${w##*/}
        continue
      fi
      case "$w" in
        --in-place*) inplace=1 ;;
        --* | -m*) ;;
        -*i*) inplace=1 ;;
      esac
      # M is 1 for a message option's value that reads as a sentence (_g16_pathy): --message,
      # --title, --body, --subject, --notes, --comment or --trailer; -m of git, hg, jj or svn (git's
      # -am too); gh's -t, -b, -n and -c. The value is attached or the next word. It is still read for
      # state, never for settings or .claude.
      m=0
      if [ "$msg" = 1 ]; then
        msg=0
        _g16_pathy "$w" || m=1
      else
        case "$w" in
          --message=* | --title=* | --body=* | --subject=* | --notes=* | --comment=* | --trailer=*)
            _g16_pathy "${w#*=}" || m=1
            ;;
          --message | --title | --body | --subject | --notes | --comment | --trailer) msg=1 ;;
        esac
        case "$head:$w" in
          git:-m | git:-[!-]*m | hg:-m | jj:-m | svn:-m | gh:-t | gh:-b | gh:-n | gh:-c) msg=1 ;;
          git:-m?* | hg:-m?* | jj:-m?* | svn:-m?* | gh:-[tbnc]?*) _g16_pathy "${w#-?}" || m=1 ;;
        esac
      fi
      _g16_kind "$w"
      case "$_G16_K" in state) seg_s=1 ;; settings | cc) [ "$m" = 1 ] || seg_k="$seg_k $_G16_K" ;; esac
      [ "$m" = 0 ] || continue
      # A .claude directory among the operands and the option values (-C.claude, --directory=.claude,
      # -xC.claude); not a redirection or the target of one that stands alone.
      if [ "$skip" = 1 ]; then
        skip=0
        continue
      fi
      t=${w#"${w%%[!0-9]*}"}
      case "$t" in
        '<'* | '>'* | '&>'*)
          case "$t" in *[!\<\>\&\|]*) ;; *) skip=1 ;; esac
          continue
          ;;
      esac
      case "$dd:$w" in
        0:--) dd=1; continue ;;
        0:--*=*) t=${w#*=} ;;
        0:--*) continue ;;
        0:-*)
          t=${w#-}
          t=${t#"${t%%[!a-z]*}"}
          ;;
        *)
          t=$w
          last=$w
          nop=$((nop + 1))
          ;;
      esac
      [ -n "$t" ] && _g16_claude "$t" && anydir=1
    done <<WORDS
$words
WORDS
    reads=0
    case "$head" in
      cat | head | tail | less | more | grep | egrep | fgrep | rg | ls | stat | wc | file | diff | cmp | jq | \
        echo | printf | test | '[' | git | '') reads=1 ;;
      find) word_has "$words" -delete -exec -execdir -ok -okdir -fls -fprint -fprint0 -fprintf || reads=1 ;;
      sed | perl) [ "$inplace" = 1 ] || reads=1 ;;
      cd | pushd)
        reads=1
        # dk: 1 while kern knows the directory. A target is known when it is one operand that
        # expands to nothing else: an absolute path, ~ or ~/path, or a relative path from a known
        # directory. A cd to anything else (no operand, -, ~-, +N, two operands, ~user, a $, a glob)
        # may stay where it is or go back to any directory this command was in, so it keeps both
        # readings, takes back each one held earlier in the command (sd_seen, cc_seen), and leaves
        # the directory unknown.
        case "$nop:$last" in
          1:*[\$\`*?[\{^#]* | 1:*"$_GW_NL"* | 1:- | 1:+* | 1:=*) dk=0 ;;
          1:/* | 1:'~' | 1:'~'/*) dk=1 ;;
          1:'~'*) dk=0 ;;
          1:*) ;;
          *) dk=0 ;;
        esac
        # sd_f and cc_f: the readings after a move to a known target. A relative target may stay under
        # the sessions dir. The directory is followed as text, so a relative cd that comes back to a
        # .claude directory (cd agents && cd ..) is in it again.
        sd_f=$seg_s
        cc_f=0
        if [ "$dk" = 1 ]; then
          case "$last" in
            /*) t=$last ;;
            '~'*) t="$_G16_HOME${last#'~'}" ;;
            *) t="$cdir/$last"; [ "$in_sd" = 0 ] || sd_f=1 ;;
          esac
          _g16_tidy "$t"
          t=$_G16_T
          case "$t" in */.claude) cc_f=1 ;; esac
        fi
        if [ "$cc_f" = 0 ] && _g16_into "$last"; then cc_f=1; fi
        # Only a plain cd is followed (cmd_plain); any other keeps both readings and adds the target's.
        if [ "$dk" = 1 ] && [ "$mixed" = 0 ] && cmd_plain "$seg"; then
          cdir=$t
          in_sd=$sd_f
          _G16_INCC=$cc_f
        else
          dk=0
          [ "$sd_f" = 0 ] && [ "$sd_seen" = 0 ] || in_sd=1
          [ "$cc_f" = 0 ] && [ "$cc_seen" = 0 ] || _G16_INCC=1
        fi
        [ "$in_sd" = 0 ] || sd_seen=1
        [ "$_G16_INCC" = 0 ] || cc_seen=1
        ;;
      # popd goes back to a directory of the stack, as a cd to an unknown target does. It stays a
      # command that does not read, as before.
      popd)
        dk=0
        [ "$sd_seen" = 0 ] || in_sd=1
        [ "$cc_seen" = 0 ] || _G16_INCC=1
        ;;
    esac
    if [ "$reads" = 0 ] && { [ "$seg_s" = 1 ] || [ "$in_sd" = 1 ]; }; then state=1; fi
    creads=$reads
    case "$head" in
      vim | vi) creads=1 ;;
      git)
        if [ -n "$seg_k" ] || [ "$anydir" = 1 ]; then
          _g16_gitread "$seg" "$words" || creads=0
        fi
        ;;
    esac
    if [ "$creads" = 0 ]; then
      case " $seg_k " in *" settings "*) settings=1 ;; esac
      case " $seg_k " in *" cc "*) cc=1 ;; esac
      if [ "$anydir" = 1 ] || { [ -n "$last" ] && _g16_physical "$last"; }; then into=1; fi
    fi
    case "$seg" in *">"*) ;; *) continue ;; esac
    while IFS= read -r t; do
      case "$t" in '' | /dev/null | /dev/stdout | /dev/stderr | [0-9]) continue ;; esac
      if [ "$in_sd" = 1 ]; then state=1; continue; fi
      _g16_kind "$t"
      case "$_G16_K" in state) state=1 ;; settings) settings=1 ;; cc) cc=1 ;; esac
    done <<REDIRECTS
$(_g16_redirects "$seg")
REDIRECTS
  done <<SEGMENTS
$(git_words "$cmd")
SEGMENTS
  [ "$state" = 1 ] && vote deny G16 "$_G16_STATE_CMD"
  [ "$settings" = 1 ] && vote ask G16 "$_G16_SETTINGS"
  [ "$cc" = 1 ] && vote ask G16 "$_G16_CC"
  [ "$into" = 1 ] && vote ask G16 "$_G16_INTO"
  return 0
}

# _g16_glob NAMES WORD: exit 0 when WORD, a word or a part of a path, could expand to one of NAMES:
# a glob (* ? [) that matches one, or a brace expansion, a zsh group (a ( not after $) or a zsh extended
# glob (^, or # after a character), which are not matched here and always count.
_g16_glob() {
  local n
  case "$2" in
    '('* | *[!\$]'('* | *'^'* | ?*'#'* | *'{'*,*'}'* | *'{'*..*'}'*) return 0 ;;
    *[\*\?\[]*) ;;
    *) return 1 ;;
  esac
  for n in $1; do
    # shellcheck disable=SC2254 # the word is matched as the pattern it is
    case "$n" in $2) return 0 ;; esac
  done
  return 1
}

# _g16_hooks: a command that names kern's hook code or a state function asks, and is denied under
# autopilot. Running prompt-submit with a made-up prompt rewrites the user's last message and can turn
# autopilot on, and state_set writes any key; a command that reads can run code too (git -c
# core.fsmonitor=..., rg --pre, xargs sh -c), so no command is let through on the name it starts with.
# The match is on the command text, in any case, with the APFS folds of s and k read as s and k and
# quotes and backslashes taken out, so wrappers, -c strings, git config values and xargs are all
# covered. The vote is the strongest over every reading of the text (see _g16_hooks); _g16_hooks_read
# matches one reading and counts:
# - in the text (_G16_HOOK_AWK): a hook after hooks/, a .sh file under hooks/lib/, or state_set,
#   _state_put, state_reset or state_ensure; a hook name elsewhere (a branch m2/session-start, a URL) is not hook code;
# - in a word inside a hooks directory: a last part that names a hook or a hooks/lib file, holds a
#   glob that could match one (_g16_glob), or holds a $, a backtick or a { (a variable, command
#   output, or the {} of find -exec and xargs). Every word is inside one when the text names a hooks
#   directory (cd hooks, git log hooks/) or the session's directory is one; a single word is when a
#   part of its own directory holds a glob that could match hooks ($K/h*/lib/state.sh);
# - a word with a brace group that holds a / and a , or .. (hoo{ks/prompt-sub,x}mit), which can join
#   the parts on both sides of a slash. The command is never expanded to decide.
# Reading a hook file stays possible with the Read and Grep tools. Not seen (accepted limits): a hooks
# directory reached without naming it (find $K -name prompt-submit, a glob for the directory in one
# word and the hook in another), a name built at run time ($'\x..' escapes, xargs with no {}),
# interpreter code that builds a hook path, a script written to disk and then run by name, and any
# other spelling-level evasion beyond the forms above.
_g16_hooks() {
  local cmd t hit=0 failed=0 nl=$'\n'
  local -a readings
  cmd=$(ti_get command) || return 0
  _g16_fold "$cmd"
  # Each reading is one way the shell may read the text, and every reading is matched. A step that
  # normalises the text adds a reading and never changes the text another reading sees, so it cannot
  # drop a vote; a future normalisation is one more reading here.
  # Reading 1: the folded text, otherwise as written.
  readings=("$_G16_F")
  # Reading 2: bash's line continuation. An escaped backslash (\\) is dropped first, then a backslash
  # before a newline joins the lines; a backslash before CR LF does not, as in bash.
  case "$_G16_F" in
    *\\"$nl"*)
      t=${_G16_F//\\\\/}
      readings[1]=${t//\\$nl/}
      ;;
  esac
  for t in "${readings[@]}"; do
    _g16_hooks_read "$t"
    case $? in
      0) hit=1 ;;
      2) failed=1 ;;
    esac
  done
  if [ "$hit" = 1 ]; then
    vote ask G16 "$_G16_HOOKS"
  elif [ "$failed" = 1 ]; then
    fail_closed "G16 could not read the command for kern's hook code"
  fi
  return 0
}

# _g16_hooks_read TEXT: exit 0 when one reading of a command, TEXT, names kern's hook code or a state
# function (see _g16_hooks), 1 when it does not, 2 when awk could not read it.
_g16_hooks_read() {
  local t r w d c last names f ctx=0 inside hit=0
  # $'...' and $"..." read as plain quotes; then quotes and backslashes are taken out, in one tr pass
  # and only when the text holds one.
  t=${1//\$\'/}
  t=${t//\$\"/}
  case "$t" in *[\"\'\\]*) t=$(printf '%s' "$t" | env LC_ALL=C tr -d "\"'\\\\") ;; esac
  case "$CWD" in */[Hh][Oo][Oo][Kk][Ss] | */[Hh][Oo][Oo][Kk][Ss]/*) ctx=1 ;; esac
  # Only text that could count is read; any case still counts.
  if [ "$ctx" = 0 ]; then
    case "$t" in
      *[Hh][Oo][Oo][Kk][Ss]* | *[Ss][Tt][Aa][Tt][Ee]_[Ss][Ee][Tt]* | *_[Ss][Tt][Aa][Tt][Ee]_[Pp][Uu][Tt]* | \
        *[Ss][Tt][Aa][Tt][Ee]_[Rr][Ee][Ss][Ee][Tt]* | *[Ss][Tt][Aa][Tt][Ee]_[Ee][Nn][Ss][Uu][Rr][Ee]* | \
        *[\*\?\[\{\(^#]*/*) ;;
      *) return 1 ;;
    esac
  fi
  r=$(printf '%s\n' "$t" | env LC_ALL=C awk "$_G16_HOOK_AWK") || return 2
  names=$_G16_HOOK_NAMES
  for f in "$KERN_ROOT"/hooks/lib/*.sh "$KERN_ROOT"/hooks/guards/*.sh; do
    [ -e "$f" ] && names="$names ${f##*/}"
  done
  {
    IFS= read -r w
    case "$w" in
      hit) hit=1 ;;
      ctx) ctx=1 ;;
    esac
    while [ "$hit" = 0 ] && IFS= read -r w; do
      w=${w#"${w%%[!(]*}"}
      case "$w" in
        *'{'*/*'}'*)
          case "$w" in *'{'*,*'}'* | *'{'*..*'}'*) hit=1; continue ;; esac
          ;;
      esac
      inside=$ctx
      case "$inside:$w" in
        0:*/*)
          d=${w%/*}/
          while [ -n "$d" ]; do
            c=${d%%/*}
            d=${d#*/}
            if _g16_glob hooks "$c"; then
              inside=1
              break
            fi
          done
          ;;
      esac
      [ "$inside" = 1 ] || continue
      last=${w##*/}
      case "$last" in *[\{\$\`]*) hit=1 ;; esac
      case "$w" in *'{'*,*'}'* | *'{'*..*'}'*) hit=1 ;; esac
      case " $names " in *" $last "*) hit=1 ;; esac
      _g16_glob "$names" "$last" && hit=1
    done
  } <<EOT
$r
EOT
  [ "$hit" = 1 ]
}

# _g16_relay: a scheduled or relayed prompt whose text, after leading whitespace, opens with a mode
# or autopilot command. A mention later in the text passes. RemoteTrigger keeps its routine prompt
# inside a nested body and a remote run starts its own session with it, so any mention there counts.
_g16_relay() {
  local k t
  if [ "$TOOL" = RemoteTrigger ]; then
    case "$(_g16_lower "$TOOL_INPUT")" in
      */kern:autopilot* | */kern:mode*) vote deny G16 "$TOOL may not carry /kern:autopilot or /kern:mode; only the user types them" ;;
    esac
    return 0
  fi
  for k in prompt message; do
    t=$(ti_get "$k") || continue
    t=$(_g16_lower "$t")
    t="${t#"${t%%[![:space:]]*}"}"
    case "${t%%[[:space:]]*}" in
      /kern:autopilot | /kern:mode | /autopilot | /mode)
        vote deny G16 "$TOOL may not carry /kern:autopilot or /kern:mode; only the user types them"
        return 0
        ;;
    esac
  done
}

# _g16_skill: a Skill call to the mode or autopilot skill.
_g16_skill() {
  local s
  s=$(ti_get skill) || return 0
  s=$(_g16_lower "$s")
  case "${s#/}" in
    kern:autopilot | kern:mode | autopilot | mode)
      vote deny G16 "Skill may not run kern:autopilot or kern:mode; only the user types them"
      ;;
  esac
}
