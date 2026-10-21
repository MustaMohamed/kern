# shellcheck shell=bash
# kern session state: one flat `key: value` file per session, written only by kern hooks.
# Needs settings.sh. Guard G16 denies tool writes under state_dir.

state_dir() {
  printf '%s/sessions\n' "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}"
}

# state_file SID: path of the session's state file. Exit 2 for an id outside [A-Za-z0-9_-].
state_file() {
  local LC_ALL=C
  case "$1" in
    '' | *[!A-Za-z0-9_-]*) return 2 ;;
  esac
  printf '%s/%s.state\n' "$(state_dir)" "$1"
}

# state_get SID KEY: prints the value. Exit 1 unset, 2 bad id or unsafe file.
state_get() {
  local f
  f=$(state_file "$1") || return 2
  [ -L "$(dirname "$f")" ] && return 2
  [ -L "$f" ] && return 2
  [ -f "$f" ] || return 1
  LC_ALL=C awk -v k="$2" 'index($0, k ": ") == 1 { v = substr($0, length(k) + 3); found = 1 }
    END { if (found) { print v; exit 0 } exit 1 }' "$f"
}

# state_set SID KEY=VALUE...: atomic update (temp file in the same dir, then mv), mode 0600.
state_set() {
  _state_put 0 "$@"
}

# _state_put FRESH SID KEY=VALUE...: FRESH=1 starts from empty content, ignoring any old file. Keys are
# checked in the C locale: bash 3.2 matches [a-z] by the caller's collation, which in en_US.UTF-8 takes
# upper-case letters too.
_state_put() {
  local LC_ALL=C
  local fresh="$1" sid="$2" f dir tmp kv k v content
  shift 2
  f=$(state_file "$sid") || return 2
  dir=$(dirname "$f")
  (umask 077 && mkdir -p "$dir") || return 2
  [ -L "$dir" ] && return 2
  [ -L "$f" ] && return 2
  content=""
  # A read that fails (a fork or exec refused under load) is tried once more. When it fails again, or a
  # key cannot be merged in, nothing is written: the keys not read would be lost, autopilot among them.
  if [ "$fresh" = 0 ] && [ -f "$f" ]; then
    content=$(LC_ALL=C cat "$f") || content=$(LC_ALL=C cat "$f") || return 2
  fi
  for kv in "$@"; do
    k=${kv%%=*}
    v=${kv#*=}
    case "$k" in '' | *[!a-z_]*) return 2 ;; esac
    case "$v" in *"
"*) return 2 ;; esac
    content=$(printf '%s\n' "$content" | LC_ALL=C awk -v k="$k" 'index($0, k ": ") != 1 && $0 != ""') || return 2
    content="$content
$k: $v"
  done
  tmp=$(umask 077 && mktemp "$dir/.state.XXXXXX") || return 2
  printf '%s\n' "$content" | LC_ALL=C sed '/^$/d' >"$tmp" || { rm -f "$tmp"; return 2; }
  mv -f "$tmp" "$f"
}

# now_iso: current UTC time, ISO 8601.
now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# default_voice: the voice a session starts in, normal or terse. A headless session (Claude Code sets
# CLAUDE_CODE_ENTRYPOINT to sdk-cli for claude -p, and sdk-ts or sdk-py for the Agent SDK) is often a
# probe or an eval that parses the reply, so it takes mode.voice.headless, normal by default; any other
# session takes mode.voice. Idea from caveman 4.0.1 src/hooks/caveman-activate.js:256-265 (Apache-2.0).
default_voice() {
  local v
  case "${CLAUDE_CODE_ENTRYPOINT-}" in
    sdk-*) v=$(settings_get mode.voice.headless normal) ;;
    *) v=$(settings_get mode.voice normal) ;;
  esac
  case "$v" in terse) printf 'terse\n' ;; *) printf 'normal\n' ;; esac
}

# state_reset SID: defaults from settings, autopilot off.
state_reset() {
  local voice surface
  voice=$(default_voice)
  surface=$(settings_get mode.surface auto)
  case "$voice" in normal | terse) ;; *) voice=normal ;; esac
  case "$surface" in chat | auto | html) ;; *) surface=auto ;; esac
  _state_put 1 "$1" "voice=$voice" "surface=$surface" "autopilot=off" "since=$(now_iso)"
}

# state_ensure SID: a session with no state file gets the default state (state_reset). A state file that
# exists is never reset: a read of it that fails (a fork or exec refused under load) is tried once more,
# and when that fails too the file is left as it is and each reader fails safe for its own call
# (autopilot_on reads off, so a guard asks). Exit 0 when the state reads or was written, 1 when an existing
# file did not read, 2 for a bad id, a symlinked state file or dir (left alone, as state_get refuses
# them), or a failed write. A failed read's error goes to stderr.
state_ensure() {
  local f
  f=$(state_file "$1") || return 2
  [ -L "${f%/*}" ] && return 2
  [ -L "$f" ] && return 2
  if [ -e "$f" ]; then
    state_get "$1" voice >/dev/null || state_get "$1" voice >/dev/null || return 1
    return 0
  fi
  state_reset "$1"
}

# autopilot_denied_by: prints the first settings file (in precedence order) that says `autopilot: denied`.
# Exit 1 when no layer denies.
autopilot_denied_by() {
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if [ "$(_settings_lookup "$f" autopilot)" = denied ]; then
      printf '%s\n' "$f"
      return 0
    fi
  done <<EOT
$(_settings_files)
EOT
  return 1
}

# autopilot_on SID: exit 0 only when no existing settings layer says `autopilot: denied` and the state says on.
autopilot_on() {
  autopilot_denied_by >/dev/null && return 1
  [ "$(state_get "$1" autopilot 2>/dev/null)" = on ]
}

# prompt_hashes: reads text on stdin and prints, space-separated, one hash per non-blank line of up to
# 500 characters (the first 20 such lines). A line is lowercased, its blanks folded to one space and
# trimmed, and a final run of . and ! dropped, so "Yes, approved!" and "yes,  approved" hash the same.
# G20 hashes an approved: quote the same way and looks for it among the user's last prompt's hashes.
prompt_hashes() {
  LC_ALL=C awk '
    BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i }
    {
      s = tolower($0); gsub(/[ \t\r]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); sub(/[.!]+$/, "", s)
      if (s == "" || length(s) > 500 || ++n > 20) next
      h = 5381
      for (i = 1; i <= length(s); i++) h = (h * 33 + ord[substr(s, i, 1)]) % 4294967296
      out = out (out == "" ? "" : " ") sprintf("%.0f", h)
    }
    END { print out }'
}
