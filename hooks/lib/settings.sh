# shellcheck shell=bash
# kern settings: layered flat `key: value` files resolved from the main worktree root.
# Needs KERN_ROOT (plugin root). Uses KERN_MAIN when set, else resolves it from CWD (or PWD).

# kern_main_root [dir]: the main worktree root (first `worktree` line of the porcelain list).
kern_main_root() {
  local dir="${1:-${CWD:-$PWD}}" line
  line=$(git -C "$dir" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -n 1)
  [ -n "$line" ] || return 2
  printf '%s\n' "$line"
}

# _settings_files: the settings files in precedence order, one per line (existing or not).
_settings_files() {
  local main="${KERN_MAIN-}"
  if [ -z "$main" ]; then main=$(kern_main_root "${CWD:-$PWD}" 2>/dev/null) || main=""; fi
  if [ -n "$main" ]; then
    printf '%s\n' "$main/.claude/kern.local.yml" "$main/.claude/kern.yml"
  fi
  printf '%s\n' "$HOME/.claude/kern.yml"
}

# _settings_lookup FILE KEY: prints the value of KEY in FILE (last occurrence wins). Exit 1 absent.
_settings_lookup() {
  LC_ALL=C awk -v key="$2" -v sq="'" '
    {
      line = $0
      sub(/\r$/, "", line)
      if (line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/) next
      p = index(line, ":")
      if (p == 0) next
      k = substr(line, 1, p - 1)
      gsub(/^[ \t]+|[ \t]+$/, "", k)
      if (k != key) next
      v = substr(line, p + 1)
      out = ""; q = ""; m = length(v)
      for (i = 1; i <= m; i++) {
        c = substr(v, i, 1)
        if (q == "" && (c == "\"" || c == sq)) q = c
        else if (q != "" && c == q) q = ""
        else if (q == "" && c == "#" && (i == 1 || substr(v, i - 1, 1) ~ /[ \t]/)) break
        out = out c
      }
      gsub(/^[ \t]+|[ \t]+$/, "", out)
      f = substr(out, 1, 1); l = substr(out, length(out), 1)
      if (length(out) >= 2 && f == l && (f == "\"" || f == sq)) out = substr(out, 2, length(out) - 2)
      val = out; found = 1
    }
    END { if (found) { print val; exit 0 } exit 1 }' "$1"
}

# The list keys whose layers add up, so a project file cannot drop an entry a lower file sets.
_KERN_UNION_KEYS=" protected_targets never_commit branch.protected deploy.envs "

# _settings_ignored FILE KEY VALUE: exit 0 when the layer FILE must not set KEY to VALUE. The committed
# project file cannot turn kern off, cannot loosen a *.policy key to auto or rebase.push to autopilot:
# it may only tighten. Such a value reads as unset, so a lower layer or the default applies. The local
# file loosens only while it is the user's own untracked file: see _settings_local_ok.
_settings_ignored() {
  case "$1" in "$HOME/.claude/kern.yml") return 1 ;; esac
  case "$2" in
    kern) [ "$3" = off ] || return 1 ;;
    *.policy | review.post_policy) [ "$3" = auto ] || return 1 ;;
    rebase.push) [ "$3" = autopilot ] || return 1 ;;
    *) return 1 ;;
  esac
  case "$1" in
    */kern.local.yml) ! _settings_local_ok "${1%/.claude/kern.local.yml}" ;;
    *) return 0 ;;
  esac
}

# _settings_local_ok MAIN: exit 0 when MAIN/.claude/kern.local.yml is the user's own untracked file. A
# clone can ship it under another shape, so all of these must hold: the file is a regular file, not a
# symlink; .claude is a real directory (no symlink, no .git inside, no gitlink in the index) whose
# physical path is MAIN's own .claude; and git does not track the file, matched in any case. One git
# call, made only for a loosening value.
_settings_local_ok() {
  local main="$1" d="$1/.claude" pm pd
  [ -f "$d/kern.local.yml" ] && [ ! -L "$d/kern.local.yml" ] || return 1
  [ -d "$d" ] && [ ! -L "$d" ] && [ ! -e "$d/.git" ] && [ ! -L "$d/.git" ] || return 1
  pm=$(cd "$main" 2>/dev/null && pwd -P) && pd=$(cd "$d" 2>/dev/null && pwd -P) || return 1
  [ "$pd" = "$pm/.claude" ] || return 1
  git -C "$main" ls-files -s -- ':(icase).claude' 2>/dev/null | LC_ALL=C awk -F '\t' '
    { p = tolower($2); m = substr($1, 1, 6) }
    m == "160000" && p == ".claude" { bad = 1 }
    p == ".claude/kern.local.yml" { bad = 1 }
    END { exit bad }'
}

# settings_get KEY [DEFAULT]: prints the resolved value. Exit 0 found or defaulted, 3 unset. A key in
# _KERN_UNION_KEYS joins the items of every layer that sets it, highest first, with ", ": one pair of
# brackets around each layer's value ([a, b]) is dropped, items are trimmed, and an empty or repeated
# item is dropped, so each item keeps its first place.
settings_get() {
  local f v out="" found=0 rest item seen=$'\n'
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    v=$(_settings_lookup "$f" "$1") || continue
    case "$_KERN_UNION_KEYS" in
      *" $1 "*)
        found=1
        case "$v" in "["*"]") v=${v#\[}; v=${v%\]} ;; esac
        rest="$v,"
        while [ -n "$rest" ]; do
          item=${rest%%,*}
          rest=${rest#*,}
          item=${item#"${item%%[![:space:]]*}"}
          item=${item%"${item##*[![:space:]]}"}
          [ -n "$item" ] || continue
          case "$seen" in *$'\n'"$item"$'\n'*) continue ;; esac
          seen="$seen$item"$'\n'
          out="${out:+$out, }$item"
        done
        ;;
      *)
        _settings_ignored "$f" "$1" "$v" && continue
        printf '%s\n' "$v"
        return 0
        ;;
    esac
  done <<EOT
$(_settings_files)
EOT
  if [ "$found" = 1 ]; then
    printf '%s\n' "$out"
    return 0
  fi
  if [ $# -ge 2 ]; then
    printf '%s\n' "$2"
    return 0
  fi
  return 3
}

# settings_source KEY: prints the file that sets KEY, or `default`. Exit 0 always. A key in
# _KERN_UNION_KEYS prints every file that sets it, joined with ", ".
settings_source() {
  local f v out=""
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    v=$(_settings_lookup "$f" "$1") || continue
    case "$_KERN_UNION_KEYS" in *" $1 "*) out="${out:+$out, }$f"; continue ;; esac
    _settings_ignored "$f" "$1" "$v" && continue
    printf '%s\n' "$f"
    return 0
  done <<EOT
$(_settings_files)
EOT
  printf '%s\n' "${out:-default}"
}

# settings_keys FILE: every key set in FILE, one per line.
settings_keys() {
  LC_ALL=C awk '
    { line = $0; sub(/\r$/, "", line) }
    line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/ { next }
    { p = index(line, ":"); if (p == 0) next
      k = substr(line, 1, p - 1); gsub(/^[ \t]+|[ \t]+$/, "", k); print k }' "$1" | sort -u
}

# settings_known_keys: the key column of kernel/settings.md, one per line. A `<...>` part is a wildcard.
settings_known_keys() {
  sed -n 's/^| `\([^`]*\)` |.*/\1/p' "$KERN_ROOT/kernel/settings.md"
}

# settings_unknown_keys: `file<TAB>key` for every key that kernel/settings.md does not list.
settings_unknown_keys() {
  local f k known pat ok
  known=$(settings_known_keys)
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      ok=1
      while IFS= read -r pat; do
        case "$pat" in
          *'<'*'>'*) case "$k" in "${pat%%<*}"?*) ok=0 ;; esac ;;
          *) [ "$k" = "$pat" ] && ok=0 ;;
        esac
        [ "$ok" = 0 ] && break
      done <<EOT
$known
EOT
      [ "$ok" = 1 ] && printf '%s\t%s\n' "$f" "$k"
    done <<EOT
$(settings_keys "$f")
EOT
  done <<EOT
$(_settings_files)
EOT
}

# policy_for ACTION: ask|auto|deny for commit, push, pr, tracker or review.post; any other action reads as ask.
policy_for() {
  local key v
  case "$1" in
    review.post) key=review.post_policy ;;
    commit|push|pr|tracker) key="$1.policy" ;;
    *) printf 'ask\n'; return 0 ;;
  esac
  v=$(settings_get "$key" ask)
  case "$v" in
    auto|deny) printf '%s\n' "$v" ;;
    *) printf 'ask\n' ;;
  esac
}

# kern_enabled: exit 0 unless the resolved `kern` key is `off`.
kern_enabled() {
  [ "$(settings_get kern on)" != off ]
}

# list_has LIST ITEM: exit 0 when the comma-separated LIST contains ITEM (whitespace trimmed). One
# pair of brackets around the whole LIST is dropped, so a YAML flow list [a, b] reads as a, b.
list_has() {
  local list="$1" rest item
  list=${list#"${list%%[![:space:]]*}"}
  list=${list%"${list##*[![:space:]]}"}
  case "$list" in "["*"]") list=${list#\[}; list=${list%\]} ;; esac
  rest="$list,"
  while [ -n "$rest" ]; do
    item=${rest%%,*}; rest=${rest#*,}
    # Trimmed in bash: BSD sed reads [ \t] as space, backslash or t, so it cut feat to fea.
    item=${item#"${item%%[![:space:]]*}"}
    item=${item%"${item##*[![:space:]]}"}
    [ -n "$item" ] && [ "$item" = "$2" ] && return 0
  done
  return 1
}
