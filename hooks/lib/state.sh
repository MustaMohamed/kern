# shellcheck shell=bash
# kern session state: one flat `key: value` file per session, written only by kern hooks.
# Needs settings.sh. Guard G16 denies tool writes under state_dir.

state_dir() {
  printf '%s/sessions\n' "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}"
}

# _state_path SID: sets _KERN_STATE_PATH to the session's state file, in state_dir. It uses no command
# substitution: one whose pipe cannot be made (a full fd table) gives status 0 and no output, which no
# || sees. Exit 2 for an id outside [A-Za-z0-9_-].
_state_path() {
  # The letters are listed: a range such as A-Z follows the locale's collation in bash 3.2, and a
  # `local LC_ALL=C` undone at return crashes bash 5.3 now and then inside $( ) (see state_get).
  case "$1" in
    '' | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-]*) return 2 ;;
  esac
  _KERN_STATE_PATH="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}/sessions/$1.state"
}

# state_file SID: path of the session's state file. Exit 2 for an id outside [A-Za-z0-9_-].
state_file() {
  _state_path "$1" || return 2
  printf '%s\n' "$_KERN_STATE_PATH"
}

# state_get SID KEY: prints the value. Exit 1 unset, 2 bad id or unsafe file.
# This library makes no locale change bash must undo. Homebrew bash 5.3.15 on macOS (2026-10-21)
# segfaults now and then, about one run in 16, when a subshell undoes one: a `local LC_ALL=C` at return,
# or the temporary LC_ALL of a command that more commands follow. It does so only while neither LANG nor
# LC_ALL is set, as for a hook a GUI app or an `env -i` runner starts; LC_CTYPE alone does not prevent
# it. The old state_file's `local LC_ALL=C` ran inside `$(state_file)`, so state_get failed that way and
# prompt-submit reset the state (Task 16l). `env LC_ALL=C cmd` sets the locale in cmd's environment only.
state_get() {
  local f
  _state_path "$1" || return 2
  f=$_KERN_STATE_PATH
  [ -L "${f%/*}" ] && return 2
  [ -L "$f" ] && return 2
  [ -f "$f" ] || return 1
  env LC_ALL=C awk -v k="$2" 'index($0, k ": ") == 1 { v = substr($0, length(k) + 3); found = 1 }
    END { if (found) { print v; exit 0 } exit 1 }' "$f"
}

# state_set SID KEY=VALUE...: atomic update (temp file in the same dir, then mv), mode 0600.
state_set() {
  _state_put 0 "$@"
}

# _state_put FRESH SID KEY=VALUE...: FRESH=1 starts from empty content, ignoring any old file. Keys are
# checked against the letters listed: bash 3.2 matches [a-z] by the caller's collation, which in
# en_US.UTF-8 takes upper-case letters too. The old lines but those of the keys set go straight from awk
# into the temp file, so a read that fails shows in awk's status, never as an empty read; it is tried
# once more. When it fails again nothing is written, since the keys not read
# would be lost, autopilot among them. The keys set follow, a key set twice taking its last value. Exit 2
# when nothing was written.
_state_put() {
  local fresh="$1" sid="$2" f dir tmp kv k v later keys="" keep
  shift 2
  _state_path "$sid" || return 2
  f=$_KERN_STATE_PATH
  dir=${f%/*}
  (umask 077 && mkdir -p "$dir") || return 2
  [ -L "$dir" ] && return 2
  [ -L "$f" ] && return 2
  for kv in "$@"; do
    k=${kv%%=*}
    v=${kv#*=}
    case "$k" in '' | *[!abcdefghijklmnopqrstuvwxyz_]*) return 2 ;; esac
    case "$v" in *"
"*) return 2 ;; esac
    keys="$keys $k"
  done
  tmp=$(umask 077 && mktemp "$dir/.state.XXXXXX") || return 2
  [ -n "$tmp" ] || return 2
  # shellcheck disable=SC2016 # awk text
  keep='BEGIN { n = split(keys, a, " "); for (i = 1; i <= n; i++) drop[a[i] ": "] = 1 }
    $0 == "" { next }
    { for (p in drop) if (index($0, p) == 1) next; print }'
  if [ "$fresh" = 0 ] && [ -f "$f" ]; then
    env LC_ALL=C awk -v keys="$keys" "$keep" "$f" >"$tmp" ||
      env LC_ALL=C awk -v keys="$keys" "$keep" "$f" >"$tmp" || { rm -f "$tmp"; return 2; }
  fi
  for kv in "$@"; do
    shift
    k=${kv%%=*}
    later=0
    for v in "$@"; do [ "${v%%=*}" = "$k" ] && later=1; done
    [ "$later" = 1 ] && continue
    printf '%s: %s\n' "$k" "${kv#*=}" >>"$tmp" || { rm -f "$tmp"; return 2; }
  done
  mv -f "$tmp" "$f" || { rm -f "$tmp"; return 2; }
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
# them), or a failed write. A failed read's error goes to stderr. Neither the path nor the read is a
# command substitution, whose failed pipe would read as no file.
state_ensure() {
  local f
  _state_path "$1" || return 2
  f=$_KERN_STATE_PATH
  [ -L "${f%/*}" ] && return 2
  [ -L "$f" ] && return 2
  if [ -e "$f" ]; then
    state_get "$1" voice >/dev/null || state_get "$1" voice >/dev/null || return 1
    return 0
  fi
  state_reset "$1"
}

# autopilot_denied_by: prints the first settings file (in precedence order) that says `autopilot: denied`.
# A layer kern cannot read may say it, so it counts as denying, named with its cause: a file that exists
# but could not be read, a list of layers that could not be made, or a repository whose .git git cannot
# open and kern cannot follow (_settings_files exit 2). Each reads after "autopilot denied by". Exit 1
# when no layer denies.
autopilot_denied_by() {
  local f files rc
  files=$(_settings_files)
  rc=$?
  # _settings_files always names the user's file, so no output means the list could not be made.
  if [ -z "$files" ]; then
    printf 'the settings files, which kern could not list (retry)\n'
    return 0
  fi
  if [ "$rc" != 0 ]; then
    # shellcheck disable=SC2016 # the backticks are text
    printf 'the project'"'"'s .claude settings, which kern cannot read: git cannot open this repository (run `git status` to see why)\n'
    return 0
  fi
  # Walked with parameter expansion: a here-document needs a file that may not open.
  files="$files"$'\n'
  while [ -n "$files" ]; do
    f=${files%%$'\n'*}
    files=${files#*$'\n'}
    [ -n "$f" ] && [ -f "$f" ] || continue
    _settings_read "$f" autopilot
    case $? in
      0) [ "$_KERN_SV" = denied ] || continue ;;
      1) continue ;;
      *)
        printf '%s, which could not be read\n' "$f"
        return 0
        ;;
    esac
    printf '%s\n' "$f"
    return 0
  done
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
# A line over 20,000 characters is skipped before any other work on it: macOS awk folds blanks in time
# quadratic in the line's length, and one 3 MB pasted line took prompt-submit past its 10 s timeout. No
# approved: line is that long.
prompt_hashes() {
  env LC_ALL=C awk '
    BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i }
    {
      if (length($0) > 20000) next
      s = tolower($0); gsub(/[ \t\r]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); sub(/[.!]+$/, "", s)
      if (s == "" || length(s) > 500 || ++n > 20) next
      h = 5381
      for (i = 1; i <= length(s); i++) h = (h * 33 + ord[substr(s, i, 1)]) % 4294967296
      out = out (out == "" ? "" : " ") sprintf("%.0f", h)
    }
    END { print out }'
}
