### Task 10: G1 git safety

**Files:**
- Create: `hooks/guards/g01-git.sh`
- Test: `tests/hooks/g01-git.bats`

**Interfaces:**
- Consumes: the dispatcher and helpers from Task 9; `policy_for push`, `settings_get rebase.push`.
- Produces: `guard_g01`. Rules (design 8.3, G1): in the main checkout `switch`, `checkout`, `reset --hard|--merge|--keep`, `stash` (not `list` or `show`), `clean` (not `-n`), `rebase` and `bisect` ask, deny under autopilot; plain force push (`--force`, `-f`, `+refspec`, `--mirror`) is denied in both modes; `--force-with-lease` asks on an own branch and is denied on a branch with another author's commits; under autopilot it is allowed only with `rebase.push: autopilot` and only on own branches; a push to a protected branch asks (deny under autopilot); any other push follows `push.policy`, and under autopilot only the current branch may be pushed; `git merge` and `gh pr merge` ask, deny under autopilot; `git branch -D` and `git worktree remove --force` ask, deny under autopilot.

- [ ] **Step 1: Write the failing test**

`tests/hooks/g01-git.bats`:
```bash
#!/usr/bin/env bats
# G1 git safety, interactive and autopilot.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt" >/dev/null 2>&1
  kern_env "$R"
}

g1() { run_guard "$(bash_payload "$1")" g01; }

@test "status in the main checkout: no vote" {
  g1 "git status"
  [ "$(decision_of "$output")" = none ]
}

@test "switch in the main checkout asks, denied under autopilot" {
  g1 "git switch feat"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g1 "git switch feat"
  [ "$(decision_of "$output")" = deny ]
}

@test "reset --hard, stash and clean in the main checkout ask" {
  for c in "git reset --hard HEAD" "git stash" "git clean -fd" "git checkout -b x" "git rebase main"; do
    g1 "$c"
    [ "$(decision_of "$output")" = ask ] || { echo "$c -> $output"; return 1; }
  done
}

@test "the same commands in a linked worktree: no vote" {
  for c in "git -C $BATS_TEST_TMPDIR/wt reset --hard HEAD" "git -C $BATS_TEST_TMPDIR/wt stash" "git -C $BATS_TEST_TMPDIR/wt switch -c y"; do
    g1 "$c"
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
}

@test "a chained or substituted main-checkout command is still seen" {
  g1 "cd /tmp && git -C $R stash"
  [ "$(decision_of "$output")" = ask ]
  g1 "echo \$(git -C $R reset --hard)"
  [ "$(decision_of "$output")" = ask ]
  g1 "bash -c 'git -C $R switch feat'"
  [ "$(decision_of "$output")" = ask ]
}

@test "stash list and clean -n are read-only: no vote" {
  g1 "git stash list"
  [ "$(decision_of "$output")" = none ]
  g1 "git clean -n"
  [ "$(decision_of "$output")" = none ]
}

@test "plain force push is denied in both modes" {
  for c in "git push --force origin feat" "git push -f origin feat" "git push origin +feat" "git push -fu origin feat"; do
    g1 "$c"
    [ "$(decision_of "$output")" = deny ] || { echo "$c -> $output"; return 1; }
  done
  set_autopilot on
  g1 "git push --force origin feat"
  [ "$(decision_of "$output")" = deny ]
}

@test "push of a feature branch asks; push.policy auto allows; deny denies" {
  g1 "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  [ "$(decision_of "$output")" = ask ]
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  g1 "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  [ "$(decision_of "$output")" = allow ]
  printf 'push.policy: deny\n' >"$R/.claude/kern.local.yml"
  g1 "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  [ "$(decision_of "$output")" = deny ]
}

@test "push to the base branch asks even with push.policy auto, and is denied under autopilot" {
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  g1 "git push origin main"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g1 "git push origin main"
  [ "$(decision_of "$output")" = deny ]
}

@test "autopilot allows a push of the current non-protected branch only" {
  set_autopilot on
  g1 "git -C $BATS_TEST_TMPDIR/wt push -u origin feat"
  [ "$(decision_of "$output")" = allow ]
  g1 "git -C $BATS_TEST_TMPDIR/wt push origin other"
  [ "$(decision_of "$output")" = deny ]
}

@test "force-with-lease: own branch asks; a branch with another author is denied" {
  W="$BATS_TEST_TMPDIR/wt"
  printf 'a\n' >"$W/a.txt"; git -C "$W" add a.txt; git -C "$W" commit -q -m a
  g1 "git -C $W push --force-with-lease origin feat"
  [ "$(decision_of "$output")" = ask ]
  printf 'b\n' >"$W/b.txt"; git -C "$W" add b.txt
  git -C "$W" -c user.email=other@example.com commit -q -m b
  g1 "git -C $W push --force-with-lease origin feat"
  [ "$(decision_of "$output")" = deny ]
}

@test "force-with-lease under autopilot needs rebase.push: autopilot" {
  W="$BATS_TEST_TMPDIR/wt"
  printf 'a\n' >"$W/a.txt"; git -C "$W" add a.txt; git -C "$W" commit -q -m a
  set_autopilot on
  g1 "git -C $W push --force-with-lease origin feat"
  [ "$(decision_of "$output")" = deny ]
  mkdir -p "$R/.claude"; printf 'rebase.push: autopilot\n' >"$R/.claude/kern.local.yml"
  g1 "git -C $W push --force-with-lease origin feat"
  [ "$(decision_of "$output")" = allow ]
}

@test "merge asks; gh pr merge asks; both denied under autopilot" {
  g1 "git -C $BATS_TEST_TMPDIR/wt merge main"
  [ "$(decision_of "$output")" = ask ]
  g1 "gh pr merge 12 --squash"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g1 "gh pr merge 12 --squash"
  [ "$(decision_of "$output")" = deny ]
}

@test "worktree remove --force and branch -D ask" {
  g1 "git worktree remove --force $BATS_TEST_TMPDIR/wt"
  [ "$(decision_of "$output")" = ask ]
  g1 "git branch -D feat"
  [ "$(decision_of "$output")" = ask ]
}

@test "kern: off disables the guard" {
  mkdir -p "$R/.claude"; printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  g1 "git push --force origin feat"
  [ "$(decision_of "$output")" = none ]
}

@test "unparseable input asks, and the reason names it" {
  run_guard 'not json' g01
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *"not parseable"* ]] || false
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run-bats tests/hooks/g01-git.bats`
Expected: FAIL; every case that expects `ask`, `deny` or `allow` gets `none` (no guard file yet). Cases that expect no vote pass.

- [ ] **Step 3: Write `hooks/guards/g01-git.sh`**

```bash
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `tests/run-bats tests/hooks/g01-git.bats`
Expected: `16 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add -- hooks/guards/g01-git.sh tests/hooks/g01-git.bats
git commit -m "M1: add G1 git safety" -m "Shared-checkout state changes, force pushes and merges are the actions most likely to destroy someone else's work."
```

---

