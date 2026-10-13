# shellcheck shell=bash
# G13 protected targets: no copies to, and no mutating SQL against, anything in protected_targets.
# Reading (SELECT, scp from the target, sftp get) stays allowed.

guard_g13() {
  [ "$TOOL" = Bash ] || return 0
  local list cmd seg rest target
  list=$(settings_get protected_targets '')
  [ -n "$list" ] || return 0
  cmd=$(ti_get command) || return 0
  rest="$list,"
  while [ -n "$rest" ]; do
    target=${rest%%,*}
    rest=${rest#*,}
    target=$(printf '%s' "$target" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$target" ] || continue
    case "$cmd" in *"$target"*) ;; *) continue ;; esac
    while IFS= read -r seg; do
      _g13_segment "$seg" "$target"
    done <<EOT
$(git_words "$cmd")
EOT
    _g13_sql "$cmd" "$target"
  done
}

_g13_segment() {
  local seg="$1" target="$2" head last
  head=$(cmd_head "$seg")
  case "${head%% *}" in
    scp | rsync)
      last=$(_shell_words "$seg" | tail -n 1)
      case "$last" in *"$target"*) vote deny G13 "copy to protected target $target" ;; esac
      ;;
    sftp)
      printf '%s\n' "$seg" | grep -Eiq '(^|[^a-z])(put|rm|rename|mkdir|rmdir|chmod)[[:space:]]' &&
        vote deny G13 "sftp write to protected target $target"
      ;;
    ssh)
      case "$seg" in *"$target"*) ;; *) return 0 ;; esac
      _shell_words "$seg" | paste -sd ' ' - | grep -Eq '(^|[[:space:];])(rm|mv|cp|del|copy|move|rename|mkdir|rmdir|touch|tee|chmod|chown|systemctl|service|kill)([[:space:];]|$)|>' &&
        vote deny G13 "write command over ssh to protected target $target"
      ;;
  esac
}

# _g13_sql CMD TARGET: mutating SQL in the command, or in a file it feeds with -f, --file or <.
_g13_sql() {
  local cmd="$1" target="$2" text f
  text="$cmd"
  for f in $(printf '%s\n' "$cmd" | grep -Eo '(-f|--file=?|<)[[:space:]]*[^[:space:];|&]+\.sql' | sed -E 's/^(-f|--file=?|<)[[:space:]]*//'); do
    case "$f" in /*) ;; *) f="$CWD/$f" ;; esac
    [ -f "$f" ] && text="$text
$(cat "$f")"
  done
  printf '%s\n' "$text" | grep -Eiq '(^|[^a-z_])(insert[[:space:]]+into|update[[:space:]]+[a-z_."`]+[[:space:]]+set|delete[[:space:]]+from|drop[[:space:]]+(table|database|schema|index|view)|alter[[:space:]]+(table|database|schema)|truncate|create[[:space:]]+(table|database|schema|index)|grant[[:space:]]|revoke[[:space:]]|lock[[:space:]]+tables|set[[:space:]]+global|kill[[:space:]]+[0-9])' &&
    vote deny G13 "mutating SQL against protected target $target"
  return 0
}
