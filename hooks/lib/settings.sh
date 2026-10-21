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

# _settings_walk_root DIR: sets _KERN_WALK_ROOT to the main worktree root found from the .git at or above
# DIR without running git, for a repository git refuses (dubious ownership, git unable to run). A .git
# directory holding a HEAD: its parent. A .git file: its `gitdir:` directory must hold a HEAD; with a
# commondir file there (a linked worktree) the root is the parent of the common dir, or the common dir
# itself for a bare repository; without one (a submodule) it is the directory holding the .git file.
# Exit 1 when no .git is at or above DIR, 2 when the nearest one is broken (a .git directory with no HEAD,
# a .git file whose gitdir is gone, anything else named .git).
_settings_walk_root() {
  local d="$1" line gd cdir common
  case "$d" in /*) ;; *) return 1 ;; esac
  while [ -n "$d" ]; do
    if [ -d "$d/.git" ]; then
      [ -f "$d/.git/HEAD" ] || return 2
      _KERN_WALK_ROOT=$d
      return 0
    fi
    if [ -f "$d/.git" ]; then
      line=""
      IFS= read -r line <"$d/.git" || [ -n "$line" ] || return 2
      case "$line" in 'gitdir: '?*) gd=${line#gitdir: } ;; *) return 2 ;; esac
      case "$gd" in /*) ;; *) gd="$d/$gd" ;; esac
      [ -f "$gd/HEAD" ] || return 2
      if [ -f "$gd/commondir" ]; then
        cdir=""
        IFS= read -r cdir <"$gd/commondir" || [ -n "$cdir" ] || return 2
        case "$cdir" in /*) ;; *) cdir="$gd/$cdir" ;; esac
        common=$(cd "$cdir" 2>/dev/null && pwd -P) && [ -n "$common" ] || return 2
        case "$common" in */.git) _KERN_WALK_ROOT=${common%/.git} ;; *) _KERN_WALK_ROOT=$common ;; esac
      else
        _KERN_WALK_ROOT=$d
      fi
      return 0
    fi
    [ -e "$d/.git" ] && return 2
    d=${d%/*}
  done
  return 1
}

# _settings_files: the settings files in precedence order, one per line (existing or not). When git finds
# no main worktree root, the .git at or above the directory gives it (_settings_walk_root). Exit 2 when
# that .git is broken too: the project layers are unknown, and only the user's file prints.
_settings_files() {
  local main="${KERN_MAIN-}" rc=0
  if [ -z "$main" ]; then main=$(kern_main_root "${CWD:-$PWD}" 2>/dev/null) || main=""; fi
  if [ -z "$main" ]; then
    _settings_walk_root "${CWD:-$PWD}"
    rc=$?
    [ "$rc" != 0 ] || main=$_KERN_WALK_ROOT
  fi
  if [ -n "$main" ]; then
    printf '%s\n' "$main/.claude/kern.local.yml" "$main/.claude/kern.yml"
  fi
  printf '%s\n' "$HOME/.claude/kern.yml"
  [ "$rc" != 2 ] || return 2
  return 0
}

# _settings_lookup FILE KEY: prints the value of KEY in FILE (last occurrence wins). Exit 1 absent.
_settings_lookup() {
  env LC_ALL=C awk -v key="$2" -v sq="'" '
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
# file loosens only while it is the user's own untracked file: see _settings_local_ok. Exit 1 when the
# value applies, 2 when git cannot tell whether the local file is the user's own, 3 when another user owns
# it: its loosening value then counts as unread, as a layer that could not be read does, and
# settings_unread_why names the cause.
_settings_ignored() {
  case "$1" in "$HOME/.claude/kern.yml") return 1 ;; esac
  case "$2" in
    kern) [ "$3" = off ] || return 1 ;;
    *.policy | review.post_policy) [ "$3" = auto ] || return 1 ;;
    rebase.push) [ "$3" = autopilot ] || return 1 ;;
    *) return 1 ;;
  esac
  case "$1" in
    */kern.local.yml)
      _settings_local_ok "${1%/.claude/kern.local.yml}"
      case $? in
        0) return 1 ;;
        1) return 0 ;;
        3) return 3 ;;
        *) return 2 ;;
      esac
      ;;
    *) return 0 ;;
  esac
}

# _settings_local_ok MAIN: exit 0 when MAIN/.claude/kern.local.yml is the user's own untracked file. A
# clone can ship it under another shape, so all of these must hold: the file is a regular file, not a
# symlink, owned by the user; .claude is a real directory (no symlink, no .git inside, no gitlink in the
# index) whose physical path is MAIN's own .claude; and git does not track the file, matched in any
# case. One git call, made only for a loosening value. Exit 1 when one of these fails, 3 when the file is
# owned by another user (a container that runs as root on the user's checkout, for one), and 2 when git
# cannot answer: a repository git refuses (dubious ownership) or a git that cannot run (the xcrun shim
# exits 1 without the developer tools) proves nothing. A failed git ends its output with the line `git
# failed`, which no ls-files -s line can be (each starts with a mode), so awk's status alone tells its
# exit 1 from awk's "tracked". PIPESTATUS is not read: under a DEBUG trap, as bats sets, bash 3.2 loses it.
_settings_local_ok() {
  local main="$1" d="$1/.claude" pm pd
  [ -f "$d/kern.local.yml" ] && [ ! -L "$d/kern.local.yml" ] || return 1
  [ -d "$d" ] && [ ! -L "$d" ] && [ ! -e "$d/.git" ] && [ ! -L "$d/.git" ] || return 1
  pm=$(cd "$main" 2>/dev/null && pwd -P) && pd=$(cd "$d" 2>/dev/null && pwd -P) || return 1
  [ "$pd" = "$pm/.claude" ] || return 1
  [ -O "$d/kern.local.yml" ] || return 3
  { git -C "$main" ls-files -s -- ':(icase).claude' 2>/dev/null || printf '\ngit failed\n'; } | env LC_ALL=C awk -F '\t' '
    $0 == "git failed" { gf = 1; next }
    { p = tolower($2); m = substr($1, 1, 6) }
    m == "160000" && p == ".claude" { bad = 1 }
    p == ".claude/kern.local.yml" { bad = 1 }
    END { exit gf ? 2 : bad }'
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) return 2 ;;
  esac
}

# _settings_read FILE KEY: sets _KERN_SV to KEY's value in FILE. Exit 0 found, 1 FILE does not set KEY,
# 2 FILE could not be read: awk failed, or its command substitution came back without the status line it
# always ends with, as one whose pipe cannot be made (a full fd table) does, with status 0 and no output.
# A read that fails is tried once more.
_settings_read() {
  local out _
  for _ in 1 2; do
    out=$(_settings_lookup "$1" "$2"; printf '\n%s' "$?")
    case "$out" in
      *$'\n'0)
        out=${out%$'\n'0}
        _KERN_SV=${out%$'\n'}
        return 0
        ;;
      *$'\n'1) return 1 ;;
    esac
  done
  return 2
}

# settings_get KEY [DEFAULT]: prints the resolved value. Exit 0 found or defaulted, 3 unset. A key in
# _KERN_UNION_KEYS joins the items of every layer that sets it, highest first, with ", ": one pair of
# brackets around each layer's value ([a, b]) is dropped, items are trimmed, and an empty or repeated
# item is dropped, so each item keeps its first place.
# Exit 4 when a layer that could set KEY could not be read, or the list of layers could not be made: it
# may hold a stricter value, so a guard must not take the result as the whole answer, and
# settings_unread_why says why. The layers that read still count, the user's own file always among them.
# A policy key then prints deny when a layer that reads says deny, else unknown; rebase.push prints ask;
# any other key, kern included, prints what the readable layers and DEFAULT give, so the user's kern: off
# holds.
settings_get() {
  local f v out="" found=0 rest item seen=$'\n' files unread=0 strict=""
  case "$1" in
    *.policy | review.post_policy) strict=policy ;;
    rebase.push) strict=ask ;;
  esac
  # _settings_files always names the user's file, so no output means the list could not be made; exit 2
  # means the project layers are unknown. The list is walked with parameter expansion: a here-document
  # needs a file that may not open.
  if ! files=$(_settings_files) || [ -z "$files" ]; then
    unread=1
  fi
  files="$files"$'\n'
  while [ -n "$files" ]; do
    f=${files%%$'\n'*}
    files=${files#*$'\n'}
    [ -n "$f" ] && [ -f "$f" ] || continue
    _settings_read "$f" "$1"
    case $? in
      0) v=$_KERN_SV ;;
      1) continue ;;
      *)
        unread=1
        continue
        ;;
    esac
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
        _settings_ignored "$f" "$1" "$v"
        case $? in
          0) continue ;;
          2 | 3)
            unread=1
            continue
            ;;
        esac
        if [ "$unread" = 1 ]; then
          case "$strict" in
            policy) [ "$v" = deny ] || v=unknown ;;
            ask) v=ask ;;
          esac
          printf '%s\n' "$v"
          return 4
        fi
        printf '%s\n' "$v"
        return 0
        ;;
    esac
  done
  if [ "$found" = 1 ]; then
    printf '%s\n' "$out"
  elif [ "$unread" = 1 ] && [ "$strict" = policy ]; then
    printf 'unknown\n'
  elif [ "$unread" = 1 ] && [ "$strict" = ask ]; then
    printf 'ask\n'
  elif [ $# -ge 2 ]; then
    printf '%s\n' "$2"
  elif [ "$unread" = 0 ]; then
    return 3
  fi
  [ "$unread" = 0 ] || return 4
  return 0
}

# settings_unread_why KEY: why KEY read with exit 4 from settings_get, as a phrase for a reason: git
# cannot open the repository (_settings_files exit 2), a settings file that cannot be read, a
# kern.local.yml whose loosening value git cannot vouch for (_settings_ignored exit 2) or that another user
# owns (exit 3), or a read that failed for a moment (worth a retry).
settings_unread_why() {
  local files f rc
  files=$(_settings_files)
  rc=$?
  if [ "$rc" = 2 ]; then
    # shellcheck disable=SC2016 # the backticks are text
    printf 'git cannot open this repository, so kern cannot read its .claude settings (run `git status` to see why)\n'
    return 0
  fi
  files="$files"$'\n'
  while [ -n "$files" ]; do
    f=${files%%$'\n'*}
    files=${files#*$'\n'}
    [ -n "$f" ] && [ -f "$f" ] || continue
    _settings_read "$f" "$1"
    case $? in
      0)
        _settings_ignored "$f" "$1" "$_KERN_SV"
        case $? in
          2)
            # shellcheck disable=SC2016 # the backticks are text
            printf 'git cannot tell whether %s is your own untracked file (run `git status` to see why)\n' "$f"
            return 0
            ;;
          3)
            printf '%s is owned by another user, so kern does not take it as your own file\n' "$f"
            return 0
            ;;
        esac
        ;;
      2)
        printf '%s could not be read\n' "$f"
        return 0
        ;;
    esac
  done
  printf 'a kern settings file could not be read (retry)\n'
}

# settings_source KEY: prints the file that sets KEY, or `default`. Exit 0 always. A key in
# _KERN_UNION_KEYS prints every file that sets it, joined with ", ".
settings_source() {
  local f v out=""
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    v=$(_settings_lookup "$f" "$1") || continue
    case "$_KERN_UNION_KEYS" in *" $1 "*) out="${out:+$out, }$f"; continue ;; esac
    _settings_ignored "$f" "$1" "$v"
    [ $? = 1 ] || continue
    printf '%s\n' "$f"
    return 0
  done <<EOT
$(_settings_files)
EOT
  printf '%s\n' "${out:-default}"
}

# settings_keys FILE: every key set in FILE, one per line.
settings_keys() {
  env LC_ALL=C awk '
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
# A policy that could not be resolved reads as unknown: a settings layer that could not be read
# (exit 4 from settings_get; deny still prints when a layer that reads says deny), or a command substitution
# that came back without its status line, as one whose pipe cannot be made does. A guard asks on unknown,
# naming the cause (settings_unread_why), and on no output at all, the caller's own substitution failing.
policy_for() {
  local key v
  case "$1" in
    review.post) key=review.post_policy ;;
    commit|push|pr|tracker) key="$1.policy" ;;
    *) printf 'ask\n'; return 0 ;;
  esac
  v=$(settings_get "$key" ask; printf '\n%s' "$?")
  case "$v" in
    *$'\n'0)
      v=${v%$'\n'0}
      v=${v%$'\n'}
      ;;
    *$'\n'4)
      v=${v%$'\n'4}
      v=${v%$'\n'}
      [ "$v" = deny ] || v=unknown
      printf '%s\n' "$v"
      return 0
      ;;
    *) printf 'unknown\n'; return 0 ;;
  esac
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
