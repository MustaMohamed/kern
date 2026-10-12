# shellcheck shell=bash
# G16 mode state: Claude cannot write kern's session state or schedule a prompt that switches it,
# and the user confirms every write to a kern settings file.

_G16_STATE_FILE="kern session state is written only by kern hooks; ask the user to type /kern:mode or /kern:autopilot"
_G16_STATE_CMD="commands may not write kern session state"
_G16_SETTINGS="kern settings change guard policy; the user confirms each write"

guard_g16() {
  case "$TOOL" in
    Write | Edit | NotebookEdit) _g16_file ;;
    Bash) _g16_bash ;;
    CronCreate | ScheduleWakeup | RemoteTrigger | SendMessage) _g16_relay ;;
    Skill) _g16_skill ;;
  esac
}

# _g16_lower STR: STR in lower case (bash 3.2 has no ${var,,}).
_g16_lower() {
  printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]'
}

# _g16_norm PATH: absolute PATH with `.`, `..` and repeated slashes resolved as text, so a `..`
# through a directory that does not exist yet is still seen.
_g16_norm() {
  printf '%s\n' "$1" | LC_ALL=C awk -F/ '{
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

# _g16_file: a Write, Edit or NotebookEdit target, compared in lower case as written, with `..`
# resolved, and through its physical parent dir, so a case variant or a symlinked dir is seen.
_g16_file() {
  local p norm real="" sd rsd="" c
  p=$(ti_get file_path) || p=$(ti_get notebook_path) || return 0
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
  for c in "$p" "$norm" "$real"; do
    case "$(_g16_lower "$c")" in
      */.claude/kern.yml | */.claude/kern.local.yml) vote ask G16 "$_G16_SETTINGS"; return 0 ;;
    esac
  done
}

# _g16_names STR: exit 0 when the lower-cased STR mentions session state or a settings file at all.
_g16_names() {
  case "$1" in
    *"$_G16_SD"* | *plugins/data/*sessions* | *claude_plugin_data*sessions* | *.claude/kern.yml* | *.claude/kern.local.yml*) return 0 ;;
  esac
  [ -n "$_G16_SID" ] || return 1
  case "$1" in *"$_G16_SID".state*) return 0 ;; esac
  return 1
}

# _g16_kind WORD: sets _G16_K to `state` when WORD names session state (the sessions dir, any
# plugins/data/*/sessions path, $CLAUDE_PLUGIN_DATA/sessions, or the state file name <sid>.state),
# `settings` when it names a kern settings file, else empty. The bare session id is not enough:
# Claude Code's scratchpad and task paths contain it.
_g16_kind() {
  _G16_K=""
  case "$1" in
    *"$_G16_SD"* | *plugins/data/*sessions* | *claude_plugin_data*sessions*) _G16_K=state; return 0 ;;
    *.claude/kern.yml | *.claude/kern.local.yml) _G16_K=settings; return 0 ;;
  esac
  [ -n "$_G16_SID" ] || return 0
  case "$1" in "$_G16_SID".state | */"$_G16_SID".state) _G16_K=state ;; esac
}

# _g16_redirects STR: the target word of each `>` or `>>` outside quotes, one per line.
_g16_redirects() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
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
        while (i < n && index(" \t", substr(buf, i + 1, 1))) i++
        w = ""; wq = ""
        for (j = i + 1; j <= n; j++) {
          d = substr(buf, j, 1)
          if (wq != "") { if (d == wq) wq = ""; else w = w d; continue }
          if (d == "\\") { j++; w = w substr(buf, j, 1); continue }
          if (d == sq || d == "\"") { wq = d; continue }
          if (index(" \t;&|<>()`", d)) break
          w = w d
        }
        if (w != "") print w
        i = j - 1
      }
    }'
}

# _g16_bash: write shapes (a redirect, tee, sed -i, perl -i, cp, mv, ln, rm, truncate, dd, install)
# against session state are denied, and against a settings file ask; reads pass. Every simple
# command is checked, including the bodies of bash -c, eval, $( ) and backticks, and after a cd
# into the sessions dir every later write counts as a write to it.
_g16_bash() {
  local cmd seg words w t head inplace seg_k is_write state=0 settings=0 in_sd=0
  cmd=$(ti_get command) || return 0
  cmd=$(_g16_lower "$cmd")
  _G16_SD=$(_g16_lower "$(state_dir)")
  _G16_SID=$(_g16_lower "${SID-}")
  _g16_names "$cmd" || return 0
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    # The command name comes first, after the assignments, keywords and wrappers _cmd_words skips.
    words=$(_cmd_words "$seg")
    head=""
    inplace=0
    seg_k=""
    while IFS= read -r w; do
      if [ -z "$head" ]; then
        head=${w##*/}
        continue
      fi
      case "$w" in --in-place*) inplace=1 ;; --*) ;; -*i*) inplace=1 ;; esac
      _g16_kind "$w"
      case "$_G16_K" in
        state) seg_k=state ;;
        settings) [ "$seg_k" = state ] || seg_k=settings ;;
      esac
    done <<WORDS
$words
WORDS
    is_write=0
    case "$head" in
      tee | cp | mv | ln | rm | truncate | dd | install) is_write=1 ;;
      sed | perl) is_write=$inplace ;;
      cd | pushd) [ "$seg_k" = state ] && in_sd=1 ;;
    esac
    if [ "$is_write" = 1 ]; then
      [ "$in_sd" = 1 ] && seg_k=state
      case "$seg_k" in state) state=1 ;; settings) settings=1 ;; esac
    fi
    case "$seg" in *">"*) ;; *) continue ;; esac
    while IFS= read -r t; do
      case "$t" in '' | /dev/null | /dev/stdout | /dev/stderr | [0-9]) continue ;; esac
      if [ "$in_sd" = 1 ]; then state=1; continue; fi
      _g16_kind "$t"
      case "$_G16_K" in state) state=1 ;; settings) settings=1 ;; esac
    done <<REDIRECTS
$(_g16_redirects "$seg")
REDIRECTS
  done <<SEGMENTS
$(git_words "$cmd")
SEGMENTS
  [ "$state" = 1 ] && vote deny G16 "$_G16_STATE_CMD"
  [ "$settings" = 1 ] && vote ask G16 "$_G16_SETTINGS"
  return 0
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
