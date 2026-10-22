# shellcheck shell=bash
# shellcheck disable=SC2154  # MAIN is set by the sourcing script
# Shared by wt-new and wt-fork. Sourced, never run. Needs hooks/lib/settings.sh and MAIN.

# wt_dir: the directory kern worktrees live in (worktree.dir, default MAIN/.claude/worktrees). Exit 4, with
# a line on stderr, when a settings file that could set worktree.dir cannot be read: the path it prints is
# what the readable layers and the default give, which a caller that only reads may use and one that
# creates a worktree refuses.
wt_dir() {
  local d rc=0
  d=$(settings_get worktree.dir .claude/worktrees) || rc=$?
  case "$d" in /*) ;; *) d="$MAIN/$d" ;; esac
  printf '%s\n' "$d"
  [ "$rc" = 0 ] && return 0
  printf 'wt: worktree.dir may not be the whole answer: %s\n' "$(settings_unread_why worktree.dir)" >&2
  return 4
}

# wt_path_free PATH: exit 2 when PATH already exists.
wt_path_free() {
  if [ -e "$1" ]; then
    echo "wt: path exists: $1" >&2
    return 2
  fi
}

# wt_exclude_dir DIR: keep a worktree dir inside MAIN out of the main checkout's status.
# DIR must exist. Appends to the common git dir's info/exclude, which applies to every worktree.
wt_exclude_dir() {
  local dir=$1 rel common
  case "$dir" in "$MAIN"/*) rel=${dir#"$MAIN"/} ;; *) return 0 ;; esac
  if git -C "$MAIN" check-ignore -q "$rel" 2>/dev/null; then return 0; fi
  common=$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)
  mkdir -p "$common/info"
  if ! grep -qxF "/$rel/" "$common/info/exclude" 2>/dev/null; then
    printf '/%s/\n' "$rel" >> "$common/info/exclude"
    echo "kern: added /$rel/ to .git/info/exclude" >&2
  fi
}

# wt_include DST: copy untracked files that MAIN/.worktreeinclude names (gitignore syntax) into DST.
# An entry that holds worktree.dir, such as .claude/, is refused: copying it would copy every worktree.
wt_include() {
  local dst=$1 f wtrel
  [ -f "$MAIN/.worktreeinclude" ] || return 0
  wtrel=$(wt_dir 2>/dev/null) || [ $? = 4 ]
  wtrel=${wtrel#"$MAIN"/}
  git -C "$MAIN" ls-files --others --ignored --directory --exclude-from="$MAIN/.worktreeinclude" |
    while IFS= read -r f; do
      f=${f%/}
      case "$f" in "$wtrel"|"$wtrel"/*|.kern|.kern/*) continue ;; esac
      case "$wtrel" in
        "$f"/*)
          echo "wt: .worktreeinclude names $f/, which holds the worktree dir $wtrel; not copied (name the files inside it instead)" >&2
          continue
          ;;
      esac
      [ -e "$dst/$f" ] && continue
      mkdir -p "$dst/$(dirname "$f")"
      cp -R "$MAIN/$f" "$dst/$f"
    done
}

# wt_setup WT: run worktree.setup in WT and write the marker wt-check looks for.
wt_setup() {
  local wt=$1 setup gitdir rc=0
  gitdir=$(git -C "$wt" rev-parse --path-format=absolute --git-dir)
  setup=$(settings_get worktree.setup) || rc=$?
  if [ "$rc" = 4 ]; then
    echo "wt: worktree.setup is unknown, so $wt is not set up: $(settings_unread_why worktree.setup)" >&2
    return 2
  fi
  if [ "$rc" = 0 ]; then
    if ! (cd "$wt" && bash -c "$setup") > "$gitdir/kern-setup.log" 2>&1; then
      echo "wt: worktree.setup failed in $wt (log: $gitdir/kern-setup.log)" >&2
      return 2
    fi
    printf 'setup: %s\n' "$setup" > "$gitdir/kern-setup-done"
  else
    printf 'setup: none (worktree.setup unset)\n' > "$gitdir/kern-setup-done"
    echo "wt: worktree.setup is unset; no setup ran in $wt" >&2
  fi
}
