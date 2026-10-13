# shellcheck shell=bash
# Template rendering for the kernel and the subagent kernel. Literal replacement (no regex), so
# values may hold any character: {VERSION}, {ROOT_PATH}, {MODE} and {AUTOPILOT} take K_VERSION,
# K_ROOT, K_MODE and K_AUTOPILOT, and a line that is exactly {SETTINGS} or {VOICE} is replaced by
# K_SETTINGS or K_VOICE.

# render_template FILE
render_template() {
  K_VERSION="${K_VERSION-}" K_ROOT="${K_ROOT-}" K_KERN="${K_KERN-}" K_MODE="${K_MODE-}" \
    K_AUTOPILOT="${K_AUTOPILOT-}" K_VOICE="${K_VOICE-}" K_SETTINGS="${K_SETTINGS-}" \
    LC_ALL=C awk '
    function rep(s, ph, val,   out, p) {
      out = ""
      while ((p = index(s, ph)) > 0) { out = out substr(s, 1, p - 1) val; s = substr(s, p + length(ph)) }
      return out s
    }
    $0 == "{SETTINGS}" { if (ENVIRON["K_SETTINGS"] != "") print ENVIRON["K_SETTINGS"]; next }
    $0 == "{VOICE}" { if (ENVIRON["K_VOICE"] != "") print ENVIRON["K_VOICE"]; next }
    {
      s = $0
      s = rep(s, "{VERSION}", ENVIRON["K_VERSION"])
      s = rep(s, "{ROOT_PATH}", ENVIRON["K_ROOT"])
      s = rep(s, "{MODE}", ENVIRON["K_MODE"])
      s = rep(s, "{AUTOPILOT}", ENVIRON["K_AUTOPILOT"])
      print s
    }' "$1"
}

# kern_version: the version in .claude-plugin/plugin.json.
kern_version() {
  KERN_INPUT=$(cat "$KERN_ROOT/.claude-plugin/plugin.json" 2>/dev/null) json_get version || printf 'unknown'
}

# mode_line SID: `kern mode: voice=<v> surface=<s> autopilot=<on|off>`.
mode_line() {
  local v s a
  v=$(state_get "$1" voice 2>/dev/null) || v=$(settings_get mode.voice normal)
  s=$(state_get "$1" surface 2>/dev/null) || s=$(settings_get mode.surface auto)
  if autopilot_on "$1"; then a=on; else a=off; fi
  printf 'kern mode: voice=%s surface=%s autopilot=%s\n' "$v" "$s" "$a"
}

# autopilot_text SID: `off`, `ON since <iso>`, or `off (denied by <file>)`.
autopilot_text() {
  local denier
  if denier=$(autopilot_denied_by); then
    printf 'off (denied by %s)\n' "$denier"
  elif autopilot_on "$1"; then
    printf 'ON since %s\n' "$(state_get "$1" since 2>/dev/null || printf 'this session')"
  else
    printf 'off\n'
  fi
}

KERN_FLOOR_KEYS="merge.policy deploy.policy production.policy force_push.policy delete.policy message.policy messaging.policy"

# settings_summary: the Project settings block, at most 600 chars. Overrides and ignored floor keys come
# before Set:, and only Set: is shortened to fit, a whole `key=value` entry at a time, so no other line
# is cut and no character is split.
settings_summary() {
  local out="" f files="" k v job name dir seen="" line sets="" unknown floor tail="" room sep e
  local more=" ... (more: bash {ROOT}/scripts/kern-get <key>)"
  if [ -z "${KERN_MAIN-}" ]; then
    out="Not a git repository: user settings only."
  else
    out="Main worktree: $KERN_MAIN"
  fi
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    f=${f#"${KERN_MAIN:-/nonexistent}"/}
    case "$f" in "$HOME"/*) f="~${f#"$HOME"}" ;; esac
    files="${files:+$files, }$f"
  done <<EOT
$(_settings_files)
EOT
  out="$out
Settings files: ${files:-none; defaults apply}"
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      case " $seen " in *" $k "*) continue ;; esac
      seen="$seen $k"
      case " $KERN_FLOOR_KEYS " in *" $k "*) continue ;; esac
      case "$k" in overrides.* | route.*) continue ;; esac
      v=$(settings_get "$k")
      sets="$sets$k=$v
"
    done <<EOT
$(settings_keys "$f")
EOT
  done <<EOT
$(_settings_files)
EOT
  line=""
  for dir in "$KERN_ROOT"/skills/*/; do
    job=$(basename "$dir")
    case "$job" in mode | autopilot | help | hello) continue ;; esac
    name=$(settings_get "overrides.$job" '')
    if [ -z "$name" ] && [ -n "${KERN_MAIN-}" ]; then
      if [ -f "$KERN_MAIN/.claude/skills/$job/SKILL.md" ] || [ -f "$KERN_MAIN/.claude/commands/$job.md" ]; then
        name="$job"
      fi
    fi
    [ -n "$name" ] && line="${line:+$line; }$job -> project skill $name"
  done
  [ -n "$line" ] && out="$out
Overrides (follow the project skill, say so in one line): $line"
  floor=""
  for k in $seen; do
    case " $KERN_FLOOR_KEYS " in *" $k "*) floor="${floor:+$floor, }$k" ;; esac
  done
  [ -n "$floor" ] && out="$out
Ignored, floor actions have no key: $floor"
  line=""
  for k in $seen; do
    case "$k" in route.*) line="${line:+$line; }${k#route.} -> $(settings_get "$k")" ;; esac
  done
  [ -n "$line" ] && tail="$tail
Routes: $line"
  unknown=$(settings_unknown_keys | awk -F '\t' '{ print $2 }' | grep -v -x -F -e merge.policy -e deploy.policy -e production.policy -e force_push.policy -e delete.policy -e message.policy -e messaging.policy | paste -sd ',' - | sed 's/,/, /g')
  [ -n "$unknown" ] && tail="$tail
Unknown keys, ignored: $unknown"
  if [ -n "$sets" ]; then
    # Full Set: line first; if the block is over 600, keep the entries that fit and mark the rest.
    line="
Set:"
    sep=" "
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      line="$line$sep$e"
      sep="; "
    done <<EOT
$sets
EOT
    if [ $((${#out} + ${#line} + ${#tail})) -gt 600 ]; then
      room=$((600 - ${#out} - ${#tail} - ${#more}))
      line="
Set:"
      sep=" "
      while IFS= read -r e; do
        [ -n "$e" ] || continue
        [ $((${#line} + ${#sep} + ${#e})) -le "$room" ] || break
        line="$line$sep$e"
        sep="; "
      done <<EOT
$sets
EOT
      line="$line$more"
    fi
    out="$out$line"
  fi
  printf '%s\n' "$out$tail"
}
