# shellcheck shell=bash
# Template rendering for the kernel and the subagent kernel. Literal replacement (no regex), so
# values may hold any character: {VERSION}, {MODE} and {AUTOPILOT} take K_VERSION, K_MODE and
# K_AUTOPILOT; {ROOT_PATH} and {ROOT} take K_ROOT, the plugin root, and {KERN} takes K_KERN, its skills
# folder, so a rendered line names kern files by absolute path; a line that is exactly {SETTINGS} or
# {VOICE} is replaced by K_SETTINGS or K_VOICE. One pass, left to right: a value put in is never read
# again for a placeholder, so a root that holds the text {ROOT} renders exactly.

# render_template FILE
render_template() {
  K_VERSION="${K_VERSION-}" K_ROOT="${K_ROOT-}" K_KERN="${K_KERN-}" K_MODE="${K_MODE-}" \
    K_AUTOPILOT="${K_AUTOPILOT-}" K_VOICE="${K_VOICE-}" K_SETTINGS="${K_SETTINGS-}" \
    env LC_ALL=C awk '
    BEGIN {
      n = split("VERSION MODE AUTOPILOT ROOT_PATH KERN ROOT", name, " ")
      for (i = 1; i <= n; i++) ph[i] = "{" name[i] "}"
      val[1] = ENVIRON["K_VERSION"]; val[2] = ENVIRON["K_MODE"]; val[3] = ENVIRON["K_AUTOPILOT"]
      val[4] = ENVIRON["K_ROOT"]; val[5] = ENVIRON["K_KERN"]; val[6] = ENVIRON["K_ROOT"]
    }
    # fill(s): s with each placeholder replaced by its value, the earliest first. Two placeholders cannot
    # start at one place, since each ends at its first "}".
    function fill(s,   out, i, p, at, k) {
      out = ""
      while (1) {
        at = 0
        for (i = 1; i <= n; i++) if ((p = index(s, ph[i])) > 0 && (at == 0 || p < at)) { at = p; k = i }
        if (at == 0) return out s
        out = out substr(s, 1, at - 1) val[k]
        s = substr(s, at + length(ph[k]))
      }
    }
    $0 == "{SETTINGS}" { if (ENVIRON["K_SETTINGS"] != "") print ENVIRON["K_SETTINGS"]; next }
    $0 == "{VOICE}" { if (ENVIRON["K_VOICE"] != "") print ENVIRON["K_VOICE"]; next }
    { print fill($0) }' "$1"
}

# kern_version: the version in .claude-plugin/plugin.json.
kern_version() {
  KERN_INPUT=$(cat "$KERN_ROOT/.claude-plugin/plugin.json" 2>/dev/null) json_get version || printf 'unknown'
}

# mode_line SID: `kern mode: voice=<v> surface=<s> autopilot=<on|off>`.
mode_line() {
  local v s a
  v=$(state_get "$1" voice 2>/dev/null) || v=$(default_voice)
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

# settings_summary: the Project settings block, at most 600 chars, with one known limit below. Its lines:
# `Main worktree: <path>` only when the session's cwd is not the main worktree root (cwd names it
# otherwise), or that this is not a git repository; the settings files; Overrides; ignored floor keys;
# Set:; unknown keys. Set: lists known keys whose value differs from a literal default (a Default cell that
# is one `value` in kernel/settings.md), policy keys first. `overrides.<job>: off` is no override: kern's
# route stays, and a project skill with the job's name is not matched. Overrides lists the jobs an
# `overrides.<job>` value names first, then the same-name matches. Over 600, Overrides and Set: start at
# their shortest form (the full line when it is shorter) and Unknown at none, and they take the room left
# in that order, so the Unknown list is cut first and an unknown key never cuts an override; a whole entry
# at a time, first-fit, so no character is split. A cut Overrides line ends with `not shown: <job>, ...`,
# naming every job whose entry it cut, so the model knows each job that has a project override; since the
# set values come first, a cut job is a same-name one, whose skill is the job's name, unless a set value
# is too long to fit. The names are kern's own job names, never a settings value, so the mark stays short
# (about 150 chars for every job), and the shortest form is the mark alone. A cut Unknown list ends with
# `and N more` (`N not shown` when no entry fits; it drops its line when that does not fit either), a cut
# Set: with the "more" note. Known limit: the main worktree, settings files and floor lines are never cut,
# so a cwd outside the root with a main path over about 92 chars can pass 600 when every other line is at
# its shortest. The 600 counts the plugin root in the note as {ROOT}, so the entries kept do not depend on
# where kern is installed; the note prints the absolute path.
settings_summary() {
  local out="" f files="" k v job name dir seen="" here root floor="" nl=$'\n' defaults pol="" oth=""
  local ov_items set_items unk_items ov_set="" ov_same="" jobs_set="" jobs_same=""
  local ov_line="" floor_line="" set_line="" unk_line="" ov_full set_full unk_full ov_n set_n unk_n set_cut=""
  local ov_least set_least unk_least part items pre sep sep2 rest e body least n line full room kept tail
  local ov_jobs left names
  local more=" ... (more: bash {ROOT}/scripts/kern-get <key>)"
  local ov_pre="${nl}Overrides (follow the project skill, say so in one line):" set_pre="${nl}Set:" unk_pre="${nl}Unknown keys, ignored:"
  if [ -z "${KERN_MAIN-}" ]; then
    out="Not a git repository: user settings only.$nl"
  else
    here=${CWD:-$PWD}
    if [ "$here" != "$KERN_MAIN" ]; then
      here=$(cd "$here" 2>/dev/null && pwd -P) || here=""
      root=$(cd "$KERN_MAIN" 2>/dev/null && pwd -P) || root=$KERN_MAIN
      [ -n "$here" ] && [ "$here" = "$root" ] || out="Main worktree: $KERN_MAIN$nl"
    fi
  fi
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    f=${f#"${KERN_MAIN:-/nonexistent}"/}
    case "$f" in "$HOME"/*) f="~${f#"$HOME"}" ;; esac
    files="${files:+$files, }$f"
  done <<EOT
$(_settings_files)
EOT
  out="${out}Settings files: ${files:-none; defaults apply}"
  # Unknown keys once each, floor keys left to their own line; `key value` for each literal default.
  unk_items=$(settings_unknown_keys | env LC_ALL=C awk -F '\t' -v floor=" $KERN_FLOOR_KEYS " 'index(floor, " " $2 " ") == 0 && !s[$2]++ { print $2 }')
  [ -z "$unk_items" ] || unk_items="$unk_items$nl"
  defaults=$(sed -n 's/^| `\([^`]*\)` | `\([^`]*\)` |.*/\1 \2/p' "$KERN_ROOT/kernel/settings.md")
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      case " $seen " in *" $k "*) continue ;; esac
      seen="$seen $k"
      case " $KERN_FLOOR_KEYS " in *" $k "*) continue ;; esac
      case "$k" in overrides.*) continue ;; esac
      case "$nl$unk_items" in *"$nl$k$nl"*) continue ;; esac
      v=$(settings_get "$k") || continue
      case "$nl$defaults$nl" in *"$nl$k $v$nl"*) continue ;; esac
      case "$k" in
        *.policy | review.post_policy) pol="$pol$k=$v$nl" ;;
        *) oth="$oth$k=$v$nl" ;;
      esac
    done <<EOT
$(settings_keys "$f")
EOT
  done <<EOT
$(_settings_files)
EOT
  set_items="$pol$oth"
  for dir in "$KERN_ROOT"/skills/*/; do
    job=$(basename "$dir")
    case "$job" in mode | autopilot | help) continue ;; esac
    name=$(settings_get "overrides.$job" '')
    case "$name" in off) continue ;; esac
    if [ -n "$name" ]; then
      ov_set="$ov_set$job -> project skill $name$nl" jobs_set="$jobs_set$job$nl"
    elif [ -n "${KERN_MAIN-}" ]; then
      if [ -f "$KERN_MAIN/.claude/skills/$job/SKILL.md" ] || [ -f "$KERN_MAIN/.claude/commands/$job.md" ]; then
        ov_same="$ov_same$job -> project skill $job$nl" jobs_same="$jobs_same$job$nl"
      fi
    fi
  done
  ov_items="$ov_set$ov_same" ov_jobs="$jobs_set$jobs_same"
  for k in $seen; do
    case " $KERN_FLOOR_KEYS " in *" $k "*) floor="${floor:+$floor, }$k" ;; esac
  done
  [ -z "$floor" ] || floor_line="${nl}Ignored, floor actions have no key: $floor"
  # Each list's full line, its entry count and its shortest form.
  for part in ov set unk; do
    case $part in
      ov) items=$ov_items sep2="; " pre=$ov_pre ;;
      set) items=$set_items sep2="; " pre=$set_pre ;;
      *) items=$unk_items sep2=", " pre=$unk_pre ;;
    esac
    body="" sep=" " rest=$items n=0 least=""
    while [ -n "$rest" ]; do
      body="$body$sep${rest%%"$nl"*}"
      rest=${rest#*"$nl"}
      sep=$sep2
      n=$((n + 1))
    done
    if [ "$n" -gt 0 ]; then
      body="$pre$body"
      case $part in
        set) least="$pre$more" ;;
        ov)
          names=${ov_jobs%"$nl"}
          least="$pre not shown: ${names//"$nl"/, }"
          ;;
        *) least="$pre $n not shown" ;;
      esac
      [ "${#body}" -gt "${#least}" ] || least=$body
    fi
    case $part in
      ov) ov_line=$body ov_full=$body ov_n=$n ov_least=$least ;;
      set) set_line=$body set_full=$body set_n=$n set_least=$least ;;
      *) unk_line=$body unk_full=$body unk_n=$n unk_least=$least ;;
    esac
  done
  if [ $((${#out} + ${#ov_line} + ${#floor_line} + ${#set_line} + ${#unk_line})) -gt 600 ]; then
    ov_line=$ov_least set_line=$set_least unk_line=""
    for part in ov set unk; do
      case $part in
        ov) items=$ov_items sep2="; " pre=$ov_pre full=$ov_full n=$ov_n line=$ov_line least=$ov_least ;;
        set) items=$set_items sep2="; " pre=$set_pre full=$set_full n=$set_n line=$set_line least=$set_least ;;
        *) items=$unk_items sep2=", " pre=$unk_pre full=$unk_full n=$unk_n line=$unk_line least=$unk_least ;;
      esac
      [ "$n" -gt 0 ] || continue
      room=$((600 - ${#out} - ${#ov_line} - ${#floor_line} - ${#set_line} - ${#unk_line} + ${#line}))
      if [ "${#full}" -le "$room" ]; then
        line=$full
      else
        # Unknown takes its shortest form only when it fits. Then keep each entry that still fits with the
        # mark for the rest, in order. left holds the jobs of the Overrides entries not kept yet.
        [ "${#least}" -gt "$room" ] || line=$least
        body=$pre sep=" " rest=$items kept=0 left="$nl$ov_jobs"
        while [ -n "$rest" ]; do
          e=${rest%%"$nl"*}
          rest=${rest#*"$nl"}
          case $part in
            set) tail=$more ;;
            ov)
              job=${e%% -> project skill *}
              names=${left/"$nl$job$nl"/$nl}
              names=${names#"$nl"}
              names=${names%"$nl"}
              tail=""
              [ -z "$names" ] || tail="${sep2}not shown: ${names//"$nl"/, }"
              ;;
            *) tail="${sep2}and $((n - kept - 1)) more" ;;
          esac
          [ $((${#body} + ${#sep} + ${#e} + ${#tail})) -le "$room" ] || continue
          body="$body$sep$e"
          sep=$sep2
          kept=$((kept + 1))
          line="$body$tail"
          [ "$part" != ov ] || left=${left/"$nl$job$nl"/$nl}
        done
      fi
      case $part in
        ov) ov_line=$line ;;
        set)
          set_line=$line
          [ "$line" = "$full" ] || set_cut=1
          ;;
        *) unk_line=$line ;;
      esac
    done
  fi
  [ -z "$set_cut" ] || set_line="${set_line%"$more"}${more%%"{ROOT}"*}$KERN_ROOT${more#*"{ROOT}"}"
  printf '%s\n' "$out$ov_line$floor_line$set_line$unk_line"
}
