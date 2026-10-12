# shellcheck shell=bash
# G1 git safety: main-checkout state changes, push, force push, merge. Design spec 8.3.

guard_g01() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg parsed dir sub rest
  cmd=$(ti_get command) || { fail_closed "Bash call without a command"; return 0; }
  while IFS= read -r seg; do
    case "$(cmd_head "$seg")" in
      "gh pr") case " $seg " in *" merge "*) _g01_merge "gh pr merge" ;; esac ;;
      "gh api") case "$seg" in *"/merge"*) _g01_merge "gh api merge endpoint" ;; esac ;;
    esac
    parsed=$(git_sub "$seg") || continue
    dir=${parsed%%	*}
    rest=${parsed#*	}
    sub=${rest%%	*}
    rest=${rest#*	}
    _g01_git "$dir" "$sub" "$rest"
  done <<EOT
$(git_words "$cmd")
EOT
}

_g01_merge() {
  vote ask G1 "$1 merges a PR; merge always needs the user's word"
  [ "$AUTOPILOT" = 1 ] && vote deny G1 "$1 under autopilot: merge stays human"
}

# _g01_main_op DIR WHAT: ask in the main checkout (deny under autopilot); nothing elsewhere.
_g01_main_op() {
  in_main_checkout "$1" || return 0
  if [ "$AUTOPILOT" = 1 ]; then
    vote deny G1 "git $2 in the main checkout (D3); use a kern worktree"
  else
    vote ask G1 "git $2 in the main checkout changes shared state (D3)"
  fi
}

_g01_git() {
  local dir="$1" sub="$2" rest="$3"
  case "$sub" in
    switch | rebase | bisect) _g01_main_op "$dir" "$sub" ;;
    checkout)
      case " $rest " in
        *" -b "* | *" -B "* | *" --orphan "*) _g01_main_op "$dir" "checkout -b" ;;
        *) _g01_main_op "$dir" checkout ;;
      esac
      ;;
    reset) case " $rest " in *" --hard "* | *" --merge "* | *" --keep "*) _g01_main_op "$dir" "reset $rest" ;; esac ;;
    stash) case "$rest" in list* | show*) ;; *) _g01_main_op "$dir" stash ;; esac ;;
    clean) case " $rest " in *" -n "* | *" --dry-run "*) ;; *) _g01_main_op "$dir" clean ;; esac ;;
    merge)
      case " $rest " in *" --abort "*) return 0 ;; esac
      vote ask G1 "git merge"
      [ "$AUTOPILOT" = 1 ] && vote deny G1 "git merge under autopilot"
      ;;
    branch)
      case " $rest " in
        *" -D "* | *" --delete --force "* | *" -d --force "*) _g01_destructive "git branch -D" ;;
      esac
      ;;
    worktree)
      case " $rest " in
        " remove "*) case " $rest " in *" --force "* | *" -f "*) _g01_destructive "git worktree remove --force" ;; esac ;;
      esac
      ;;
    push) _g01_push "$dir" "$rest" ;;
  esac
}

_g01_destructive() {
  vote ask G1 "$1 discards work"
  [ "$AUTOPILOT" = 1 ] && vote deny G1 "$1 under autopilot"
}

# _g01_own_branch DIR BRANCH: every commit on BRANCH not on the base was authored by user.email.
_g01_own_branch() {
  local me base authors
  me=$(git -C "$1" config user.email 2>/dev/null) || return 1
  base=$(base_branch_name) || return 1
  authors=$(git -C "$1" log --format=%ae "origin/$base..$2" 2>/dev/null | sort -u) || return 1
  [ -z "$authors" ] || [ "$authors" = "$me" ]
}

_g01_push() {
  local dir="$1" rest="$2" force=none t cur targets policy
  case " $rest " in
    *" --force-with-lease"* | *" --force-if-includes"*) force=lease ;;
  esac
  case " $rest " in
    *" --force "* | *" -f "* | *" --mirror "*) force=hard ;;
  esac
  while IFS= read -r t; do
    case "$t" in
      +*) force=hard ;;
      --*) ;;
      -*f*) force=hard ;;
    esac
  done <<EOT
$(_shell_words "$rest")
EOT
  targets=$(push_targets "$dir" "$rest")
  if [ "$force" = hard ]; then
    vote deny G1 "plain force push; use --force-with-lease on your own branch"
    return 0
  fi
  cur=$(current_branch "$dir")
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    case " $rest " in *" --delete "* | *" -d "*) _g01_destructive "git push --delete $t"; continue ;; esac
    if branch_protected "$t"; then
      vote ask G1 "push to protected branch $t"
      [ "$AUTOPILOT" = 1 ] && vote deny G1 "push to protected branch $t under autopilot"
      continue
    fi
    if [ "$force" = lease ]; then
      if [ "$AUTOPILOT" = 1 ]; then
        if [ "$(settings_get rebase.push ask)" = autopilot ] && _g01_own_branch "$dir" "$t"; then
          vote allow G1 "lease push of own branch $t (rebase.push: autopilot)"
        else
          vote deny G1 "lease push of $t needs rebase.push: autopilot and only your own commits"
        fi
      else
        if _g01_own_branch "$dir" "$t"; then
          vote ask G1 "force-with-lease push of $t"
        else
          vote deny G1 "$t has commits by other authors; it is shared and never force-pushed"
        fi
      fi
      continue
    fi
    if [ "$AUTOPILOT" = 1 ]; then
      if [ "$t" = "$cur" ]; then
        vote allow G1 "autopilot push of the current branch $t"
      else
        vote deny G1 "autopilot pushes only the current branch ($cur), not $t"
      fi
      continue
    fi
    policy=$(policy_for push)
    case "$policy" in
      auto) vote allow G1 "push.policy auto: push $t" ;;
      deny) vote deny G1 "push.policy deny" ;;
      *) vote ask G1 "push $t" ;;
    esac
  done <<EOT
$targets
EOT
}
