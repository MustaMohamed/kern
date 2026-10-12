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

# settings_get KEY [DEFAULT]: prints the resolved value. Exit 0 found or defaulted, 3 unset.
settings_get() {
  local f v
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if v=$(_settings_lookup "$f" "$1"); then
      printf '%s\n' "$v"
      return 0
    fi
  done <<EOT
$(_settings_files)
EOT
  if [ $# -ge 2 ]; then
    printf '%s\n' "$2"
    return 0
  fi
  return 3
}

# settings_source KEY: prints the file that sets KEY, or `default`. Exit 0 always.
settings_source() {
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if _settings_lookup "$f" "$1" >/dev/null; then
      printf '%s\n' "$f"
      return 0
    fi
  done <<EOT
$(_settings_files)
EOT
  printf 'default\n'
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
