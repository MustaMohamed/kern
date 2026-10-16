#!/usr/bin/env bash
# percall.sh FIXTURE_DIR: runs each git call kern's hooks make, exactly as the hook spells it (any -c
# included), against the vector repo vectors.sh built, and prints the markers each one ran. stdout is
# a pipe, as in a hook.
S="$1"
R="$S/repo"
export MARKS="$S/marks"
run() {
  local name="$1"
  shift
  rm -f "$MARKS"/*
  "$@" </dev/null >/dev/null 2>&1
  printf '%-52s %s\n' "$name" "$(ls "$MARKS" | paste -sd' ' -)"
}
G6=(--no-replace-objects -c color.ui=never -c core.fsmonitor=false -c core.quotePath=false -c log.showRoot=true -c i18n.logOutputEncoding=UTF-8)
D6=(--text --no-relative --no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/)
run "worktree list --porcelain" git -C "$R" worktree list --porcelain
run "ls-files -s -- :(icase).claude" git -C "$R" ls-files -s -- ':(icase).claude'
run "rev-parse --show-toplevel" git -C "$R" rev-parse --show-toplevel
run "symbolic-ref -q HEAD" git -C "$R" symbolic-ref -q HEAD
run "symbolic-ref --short refs/remotes/origin/HEAD" git -C "$R" symbolic-ref --short refs/remotes/origin/HEAD
run "remote" git -C "$R" remote
run "config user.email" git -C "$R" config user.email
run "log --no-show-signature --format=%ae" git -C "$R" log --no-show-signature --format=%ae origin/main..feat
run "rev-parse --verify -q refs/remotes/origin/feat" git -C "$R" rev-parse --verify -q refs/remotes/origin/feat
run "config --get-regexp remote push|mirror|..." git -C "$R" config --get-regexp '^remote\..*\.(push|mirror|receivepack|vcs)$'
run "config --get-all remote.origin.url" git -C "$R" config --get-all remote.origin.url
run "remote get-url --push --all origin" git -C "$R" remote get-url --push --all origin
run "G2 -c fsmonitor=false check-ignore -q" git -C "$R" -c core.fsmonitor=false check-ignore -q -- body.md
run "G5 -c fsmonitor=false rev-parse --show-prefix" git -C "$R" -c core.fsmonitor=false rev-parse --show-prefix
run "G5 -c fsmonitor=false log -1 --format=%B" git -C "$R" -c core.fsmonitor=false log -1 --no-show-signature --no-color --format=%B --end-of-options HEAD --
run "kern-detect rev-parse -q --verify origin/main" git -C "$R" rev-parse -q --verify origin/main
run "kern-detect log --format=%s -30" git -C "$R" log --no-show-signature --format=%s -30 origin/main
run "G6 diff --cached" git -C "$R" "${G6[@]}" diff --cached "${D6[@]}" --diff-filter=d
run "G6 config branch.feat.pushRemote" git -C "$R" "${G6[@]}" config branch.feat.pushRemote
run "G6 config --bool remote.origin.mirror" git -C "$R" "${G6[@]}" config --bool remote.origin.mirror
run "G6 rev-parse --verify -q HEAD^{commit}" git -C "$R" "${G6[@]}" rev-parse --verify -q 'HEAD^{commit}'
run "G6 for-each-ref --count=1" git -C "$R" "${G6[@]}" for-each-ref --count=1 --format=x refs/remotes/origin/
run "G6 log -p --cc" git -C "$R" "${G6[@]}" log --no-show-signature -p --cc "${D6[@]}" --format= feat --not --remotes=origin
run "G6 log -z --format=%h%x00%B" git -C "$R" "${G6[@]}" log --no-show-signature -z '--format=%h%x00%B' HEAD --not --remotes=origin
echo "--- the same calls without kern's per-call options, to show what each option stops:"
run "diff --cached (no options)" git -C "$R" diff --cached
run "log -p (no options)" git -C "$R" log -p -1
run "log (no --no-show-signature)" git -C "$R" log -1 --format=%s
run "check-ignore (no -c)" git -C "$R" check-ignore -q -- body.md
run "rev-parse --show-prefix (no -c)" git -C "$R" rev-parse --show-prefix
echo "--- for contrast, calls kern does not make:"
run "status" git -C "$R" status --porcelain
run "diff (worktree)" git -C "$R" diff
run "fetch origin" git -C "$R" fetch -q origin
run "ls-remote origin" git -C "$R" ls-remote origin
