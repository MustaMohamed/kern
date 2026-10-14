#!/usr/bin/env bats
# tests/scripts/wt-audit.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  # gh stub: PR states per branch from GH_STATES_<branch with / and - as _>.
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
if [ "$1 $2" = "pr list" ]; then
  while [ $# -gt 0 ]; do [ "$1" = --head ] && b=$2; shift; done
  v="GH_STATES_$(printf '%s' "$b" | tr '/-' '__')"
  [ -n "${!v-}" ] && printf '%s\n' "${!v}"
  exit 0
fi
exit 1
GH
  chmod +x "$TMP/bin/gh"
  export PATH="$TMP/bin:$PATH"
}

line_for() { printf '%s\n' "$output" | grep -F "/.claude/worktrees/$1	"; }

@test "each worktree lands in its bucket with evidence" {
  bash "$KERN_ROOT/scripts/wt-new" empty-one > /dev/null 2>&1
  w=$(bash "$KERN_ROOT/scripts/wt-new" dirty-one 2> /dev/null); printf 'x\n' > "$w/new.txt"
  w=$(bash "$KERN_ROOT/scripts/wt-new" done-one 2> /dev/null); git -C "$w" commit --quiet --allow-empty -m work
  bash "$KERN_ROOT/scripts/wt-new" merged-one > /dev/null 2>&1
  bash "$KERN_ROOT/scripts/wt-new" open-one > /dev/null 2>&1
  export GH_STATES_kern_merged_one=MERGED GH_STATES_kern_open_one=OPEN
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-audit"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 5 ]
  [[ "$(line_for empty-one)" == empty$'\t'*$'\t'kern/empty-one$'\t'"0 uncommitted paths, 0 commits ahead of origin/main" ]] || false
  [[ "$(line_for dirty-one)" == uncommitted$'\t'*"1 uncommitted paths"* ]] || false
  [[ "$(line_for done-one)" == committed$'\t'*"1 commits ahead of origin/main"* ]] || false
  [[ "$(line_for merged-one)" == merged$'\t'*"PR merged"* ]] || false
  [[ "$(line_for open-one)" == open-pr$'\t'*"PR open"* ]] || false
}

@test "a fork is listed as detached; the main checkout is never listed" {
  src=$(bash "$KERN_ROOT/scripts/wt-new" src-one 2> /dev/null)
  bash "$KERN_ROOT/scripts/wt-fork" "$src" fork-one > /dev/null 2>&1
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-audit"
  [[ "$(line_for fork-one)" == empty$'\t'*$'\t(detached)\t'* ]] || false
  [ "$(printf '%s\n' "$output" | grep -c "^[a-z-]*	$REPO	")" -eq 0 ]
}

@test "without gh the buckets come from local state and say so" {
  rm "$TMP/bin/gh"
  bash "$KERN_ROOT/scripts/wt-new" local-one > /dev/null 2>&1
  PATH="$TMP/bin:/usr/bin:/bin" run --separate-stderr bash "$KERN_ROOT/scripts/wt-audit"
  [[ "$(line_for local-one)" == empty$'\t'*"gh unavailable"* ]] || false
}

@test "--days 0 marks every worktree idle" {
  bash "$KERN_ROOT/scripts/wt-new" idle-one > /dev/null 2>&1
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-audit" --days 0
  [[ "$(line_for idle-one)" == *"idle 0d or more" ]] || false
}

@test "wt-audit changes nothing: status, index and worktree list are the same after it runs" {
  w=$(bash "$KERN_ROOT/scripts/wt-new" still-one 2> /dev/null); printf 'x\n' >> "$w/a.txt"
  # A tracked file with unchanged content and a new mtime makes the index stale, so a git call that
  # may refresh it rewrites it. The checksum is taken before any git call: git status refreshes too.
  touch -t 202001010000 "$w/.gitignore"
  idx="$(sed -n 's/^gitdir: //p' "$w/.git")/index"
  sum_before=$(cksum < "$idx")
  bash "$KERN_ROOT/scripts/wt-audit" > /dev/null 2>&1
  [ "$(cksum < "$idx")" = "$sum_before" ]
  before=$(cd "$w" && git status --porcelain; git worktree list)
  bash "$KERN_ROOT/scripts/wt-audit" > /dev/null 2>&1
  [ "$(cd "$w" && git status --porcelain; git worktree list)" = "$before" ]
}

@test "a worktree with thousands of recent files is still listed" {
  w=$(bash "$KERN_ROOT/scripts/wt-new" big-one 2> /dev/null)
  mkdir -p "$w/gen"
  i=0
  while [ $i -lt 3000 ]; do : > "$w/gen/f$i"; i=$((i + 1)); done
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-audit"
  [ "$status" -eq 0 ]
  [[ "$(line_for big-one)" == uncommitted$'\t'* ]] || false
  [[ "$(line_for big-one)" != *idle* ]] || false
}

@test "a bad --days value exits 2" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-audit" --days soon
  [ "$status" -eq 2 ]
}
