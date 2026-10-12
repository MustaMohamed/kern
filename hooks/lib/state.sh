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

# _state_put FRESH SID KEY=VALUE...: FRESH=1 starts from empty content, ignoring any old file.
_state_put() {
  local fresh="$1" sid="$2" f dir tmp kv k v content
  shift 2
  f=$(state_file "$sid") || return 2
  dir=$(dirname "$f")
  (umask 077 && mkdir -p "$dir") || return 2
  [ -L "$dir" ] && return 2
  [ -L "$f" ] && return 2
  content=""
  [ "$fresh" = 0 ] && [ -f "$f" ] && content=$(LC_ALL=C cat "$f")
  for kv in "$@"; do
    k=${kv%%=*}
    v=${kv#*=}
    case "$k" in '' | *[!a-z_]*) return 2 ;; esac
    case "$v" in *"
"*) return 2 ;; esac
    content=$(printf '%s\n' "$content" | LC_ALL=C awk -v k="$k" 'index($0, k ": ") != 1 && $0 != ""')
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

# state_reset SID: defaults from settings, autopilot off.
state_reset() {
  local voice surface
  voice=$(settings_get mode.voice normal)
  surface=$(settings_get mode.surface auto)
  case "$voice" in normal | terse) ;; *) voice=normal ;; esac
  case "$surface" in chat | auto | html) ;; *) surface=auto ;; esac
  _state_put 1 "$1" "voice=$voice" "surface=$surface" "autopilot=off" "since=$(now_iso)"
}

# autopilot_on SID: exit 0 only when no existing settings layer says `autopilot: denied` and the state says on.
autopilot_on() {
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    [ "$(_settings_lookup "$f" autopilot)" = denied ] && return 1
  done <<EOT
$(_settings_files)
EOT
  [ "$(state_get "$1" autopilot 2>/dev/null)" = on ]
}
