#!/usr/bin/env bats
# tests/scripts/wt-snap-diff.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  WT=$(bash "$KERN_ROOT/scripts/wt-new" snap)
}

index_sum() { cksum < "$(git -C "$WT" rev-parse --path-format=absolute --git-dir)/index"; }

@test "an unchanged worktree snapshots to HEAD's tree" {
  run bash "$KERN_ROOT/scripts/wt-snap" "$WT"
  [ "$status" -eq 0 ]
  [ "$output" = "$(git -C "$WT" rev-parse 'HEAD^{tree}')" ]
}

@test "snapshot includes untracked files and skips ignored ones" {
  printf 'new\n' > "$WT/b.txt"
  mkdir -p "$WT/node_modules/x" && printf 'dep\n' > "$WT/node_modules/x/i.js"
  printf 'noise\n' > "$WT/debug.log"
  tree=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  run git -C "$WT" ls-tree -r --name-only "$tree"
  [[ "$output" == *"b.txt"* ]] || false
  [[ "$output" != *"node_modules"* ]] || false
  [[ "$output" != *"debug.log"* ]] || false
}

@test "snapshot drops a deleted tracked file" {
  rm "$WT/a.txt"
  tree=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  run git -C "$WT" ls-tree -r --name-only "$tree"
  [[ "$output" != *"a.txt"* ]] || false
}

@test "the real index and status are untouched" {
  printf 'new\n' > "$WT/b.txt"
  printf 'changed\n' >> "$WT/a.txt"
  before_sum=$(index_sum)
  before_status=$(git -C "$WT" status --porcelain)
  bash "$KERN_ROOT/scripts/wt-snap" "$WT" > /dev/null
  [ "$(index_sum)" = "$before_sum" ]
  [ "$(git -C "$WT" status --porcelain)" = "$before_status" ]
  [ -z "$(git -C "$WT" diff --cached --name-only)" ]
}

@test "same state gives the same tree; a change gives a new one" {
  printf 'x\n' > "$WT/b.txt"
  t1=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  t2=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  [ "$t1" = "$t2" ]
  printf 'y\n' > "$WT/b.txt"
  t3=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  [ "$t1" != "$t3" ]
}

@test "wt-diff writes a package and a patch and lists changed paths" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  printf 'new\n' > "$WT/b.txt"
  printf 'four\n' >> "$WT/a.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0" --out "$TMP/pkg.diff"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$TMP/pkg.diff" ]
  [ "${lines[1]}" = "$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")" ]
  [ "${lines[2]}" = "a.txt" ]
  [ "${lines[3]}" = "b.txt" ]
  grep -q '^## Files changed$' "$TMP/pkg.diff"
  grep -q '^## Diff$' "$TMP/pkg.diff"
  grep -q '^+new$' "$TMP/pkg.diff"
  grep -q '^diff --git a/b.txt b/b.txt$' "$TMP/pkg.diff.patch"
}

@test "the package ignores diff.dstPrefix and textconv in the user's git config" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  printf 'four\n' >> "$WT/a.txt"
  printf '*.txt diff=num\n' > "$TMP/attributes"
  git -C "$WT" config core.attributesFile "$TMP/attributes"
  git -C "$WT" config diff.num.textconv 'cat -n'
  git -C "$WT" config diff.srcPrefix old/
  git -C "$WT" config diff.dstPrefix new/
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0" --out "$TMP/pkg.diff"
  [ "$status" -eq 0 ]
  grep -q '^diff --git a/a.txt b/a.txt$' "$TMP/pkg.diff"
  grep -q '^--- a/a.txt$' "$TMP/pkg.diff"
  grep -q '^+++ b/a.txt$' "$TMP/pkg.diff"
  grep -q '^+four$' "$TMP/pkg.diff"
  [ "$(grep -c -E 'new/|old/' "$TMP/pkg.diff")" -eq 0 ]
}

@test "a change a textconv driver hides is not an empty diff" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  printf 'four\n' >> "$WT/a.txt"
  printf '*.txt diff=hide\n' > "$TMP/attributes"
  git -C "$WT" config core.attributesFile "$TMP/attributes"
  git -C "$WT" config diff.hide.textconv 'sed -n 1p'
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0" --out "$TMP/pkg.diff"
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "a.txt" ]
  grep -q '^+four$' "$TMP/pkg.diff"
}

@test "wt-diff defaults the package into WORK/reviews" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  printf 'new\n' > "$WT/b.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "$REPO/.kern/reviews/"*".diff" ]] || false
  [ -f "${lines[0]}" ]
}

@test "identical trees exit 3" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0" "$t0" --out "$TMP/x.diff"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"empty diff"* ]] || false
}

@test "a bad tree exits 2" {
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" deadbeefdeadbeef --out "$TMP/x.diff"
  [ "$status" -eq 2 ]
}

@test "wt-snap and wt-diff work under a path with a space" {
  SPACED="$TMP/my project"
  make_fixture "$SPACED"
  cd "$SPACED"
  wt=$(bash "$KERN_ROOT/scripts/wt-new" spaced)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$wt")
  printf 'z\n' > "$wt/c.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$wt" "$t0" --out "$TMP/spaced.diff"
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "c.txt" ]
}

@test "wt-diff --allow passes when every changed path is allowed" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  mkdir -p "$WT/src"
  printf 'new\n' > "$WT/b.txt"
  printf 'x\n' > "$WT/src/c.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0" --out "$TMP/a.diff" --allow b.txt --allow src/
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "wt-diff --allow exits 4, names each extra path and still writes the package" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  printf 'new\n' > "$WT/b.txt"
  printf 'four\n' >> "$WT/a.txt"
  printf 'b.txt\n' > "$TMP/files"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0" --out "$TMP/a.diff" --allow-file "$TMP/files"
  [ "$status" -eq 4 ]
  [ "$stderr" = "wt-diff: outside the allowed paths: a.txt" ]
  [ -f "$TMP/a.diff" ]
  [ -f "$TMP/a.diff.patch" ]
  [ "${lines[0]}" = "$TMP/a.diff" ]
}

@test "an allowed directory needs its trailing slash" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  mkdir -p "$WT/src"
  printf 'x\n' > "$WT/src/c.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0" --out "$TMP/a.diff" --allow src
  [ "$status" -eq 4 ]
  [ "$stderr" = "wt-diff: outside the allowed paths: src/c.txt" ]
}

@test "an allowed entry ending in * covers every path that starts with it" {
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$WT")
  mkdir -p "$WT/src/deep"
  printf 'x\n' > "$WT/src/c.js"
  printf 'y\n' > "$WT/src/deep/d.js"
  printf 'z\n' > "$WT/b.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$WT" "$t0" --out "$TMP/g.diff" --allow 'src/*' --allow 'b*'
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}
