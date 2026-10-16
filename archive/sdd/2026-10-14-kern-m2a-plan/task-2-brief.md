### Task 2: Snapshot trees, review packages and allowed paths

**Files:**
- Create: `scripts/wt-snap`, `scripts/wt-diff`
- Test: `tests/scripts/wt-snap-diff.bats`

**Interfaces:**
- Consumes: `tests/helpers/wt.bash` (Task 1); `scripts/kern-dir SUB` (M1) for the default package location.
- Produces:
  - `wt-snap WT`: prints the tree id of WT's working state (tracked and untracked files, ignore rules applied); exit 0, 2 on error. Touches no ref and not the real index.
  - `wt-diff WT FROM_TREE [TO_TREE] [--out FILE] [--allow PATH]... [--allow-file FILE]`: writes the package and `<package>.patch`; prints the package path, then TO_TREE, then one changed path per line; exit 0, 3 on an empty diff, 2 on error. With `--allow` or `--allow-file` (one path per line), a changed path no entry covers is printed to stderr as `wt-diff: outside the allowed paths: <path>` and the exit is 4; the package is still written. An entry covers the same path, every path under it when it ends in `/`, and every path that starts with it when it ends in `*` (pre-flight 1 #9: plan Files entries such as `tests/skills/implement.*`). Default package path: `WORK/reviews/<from7>..<to7>.diff`. The package's diffs run with `--no-ext-diff --no-color`; the `.patch` comes from plumbing, `git diff-tree -r -p --binary --full-index`, which ignores `diff.noprefix`, textconv and external diff drivers in the user's config (pre-flight 1 #6: with `diff.noprefix=true` a porcelain patch made `wt-fork` exit 3, and a textconv driver put converted text in place of the binary).

- [ ] **Step 1: Write the failing tests**

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/wt-snap-diff.bats`
Expected: every test fails with `No such file or directory` for `scripts/wt-snap`.

- [ ] **Step 3: Write `scripts/wt-snap`**

```bash
#!/usr/bin/env bash
# Print the tree id of a worktree's whole working state: tracked and untracked files, ignore rules applied.
# A temporary index does the work, so no ref and not the real index change.
# Usage: wt-snap WT
set -euo pipefail
[ $# -eq 1 ] || { echo "usage: wt-snap WT" >&2; exit 2; }
wt=$1
git -C "$wt" rev-parse --git-dir > /dev/null 2>&1 || { echo "wt-snap: not a git worktree: $wt" >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kern-snap.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export GIT_INDEX_FILE="$tmp/index"
if git -C "$wt" rev-parse --verify --quiet HEAD > /dev/null; then
  git -C "$wt" read-tree HEAD
else
  git -C "$wt" read-tree --empty
fi
git -C "$wt" add -A
git -C "$wt" write-tree
```

- [ ] **Step 4: Write `scripts/wt-diff`**

```bash
#!/usr/bin/env bash
# Review package between two snapshot trees of a worktree. Also writes <package>.patch (binary-safe) for wt-apply.
# Usage: wt-diff WT FROM_TREE [TO_TREE] [--out FILE] [--allow PATH]... [--allow-file FILE]
# Prints: package path, TO_TREE, then one changed path per line. Exit 3 when the trees are identical.
# With --allow or --allow-file, a changed path that no entry covers is named on stderr and the exit is 4;
# the package is still written. An entry covers the same path, every path under it when it ends in /,
# and every path that starts with it when it ends in * (src/*.js covers src/a.js and src/x/b.js).
# The .patch comes from plumbing (diff-tree), which ignores diff.noprefix, textconv and external diff
# drivers in the user's config, so wt-apply and probe read the same bytes on any machine.
# Adapted from superpowers subagent-driven-development/scripts/review-package (MIT).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
usage() { echo "usage: wt-diff WT FROM_TREE [TO_TREE] [--out FILE] [--allow PATH]... [--allow-file FILE]" >&2; exit 2; }
[ $# -ge 2 ] || usage
wt=$1 from=$2
shift 2
to='' out='' allow='' checked=0
nl='
'
while [ $# -gt 0 ]; do
  case "$1" in
    --out) [ $# -ge 2 ] || usage; out=$2; shift 2 ;;
    --allow) [ $# -ge 2 ] || usage; allow="$allow$2$nl"; checked=1; shift 2 ;;
    --allow-file)
      [ $# -ge 2 ] && [ -r "$2" ] || { echo "wt-diff: cannot read the allow file: ${2-}" >&2; exit 2; }
      allow="$allow$(cat "$2")$nl"; checked=1; shift 2 ;;
    -*) usage ;;
    *) [ -z "$to" ] || usage; to=$1; shift ;;
  esac
done
git -C "$wt" rev-parse --git-dir > /dev/null 2>&1 || { echo "wt-diff: not a git worktree: $wt" >&2; exit 2; }
[ -n "$to" ] || to=$(bash "$here/wt-snap" "$wt")
fromt=$(git -C "$wt" rev-parse --verify --quiet "$from^{tree}") || { echo "wt-diff: not a tree: $from" >&2; exit 2; }
tot=$(git -C "$wt" rev-parse --verify --quiet "$to^{tree}") || { echo "wt-diff: not a tree: $to" >&2; exit 2; }
if git -C "$wt" diff --quiet "$fromt" "$tot"; then
  echo "wt-diff: empty diff ${fromt:0:7}..${tot:0:7}" >&2
  exit 3
fi
if [ -z "$out" ]; then
  rdir=$(cd "$wt" && bash "$here/kern-dir" reviews)
  out="$rdir/${fromt:0:7}..${tot:0:7}.diff"
fi
mkdir -p "$(dirname "$out")"
{
  echo "# Review package: ${fromt:0:12}..${tot:0:12}"
  echo
  echo "## Files changed"
  git -C "$wt" diff --no-ext-diff --no-color --name-status "$fromt" "$tot"
  echo
  echo "## Stat"
  git -C "$wt" diff --no-ext-diff --no-color --stat "$fromt" "$tot"
  echo
  echo "## Diff"
  git -C "$wt" diff --no-ext-diff --no-color -U10 "$fromt" "$tot"
} > "$out"
git -C "$wt" diff-tree -r -p --binary --full-index "$fromt" "$tot" > "$out.patch"
printf '%s\n%s\n' "$out" "$tot"
changed=$(git -C "$wt" diff-tree -r --name-only "$fromt" "$tot")
printf '%s\n' "$changed"
[ "$checked" = 1 ] || exit 0
# ENVIRON, not -v: BSD awk rejects a newline inside a -v value.
outside=$(printf '%s\n' "$changed" | ALLOW="$allow" LC_ALL=C awk '
  BEGIN { n = split(ENVIRON["ALLOW"], a, "\n"); for (i = 1; i <= n; i++) { sub(/^[ \t]+/, "", a[i]); sub(/[ \t]+$/, "", a[i]); if (a[i] != "") ok[++k] = a[i] } }
  $0 == "" { next }
  {
    for (i = 1; i <= k; i++) {
      if ($0 == ok[i]) next
      if (substr(ok[i], length(ok[i])) == "/" && index($0, ok[i]) == 1) next
      if (substr(ok[i], length(ok[i])) == "*" && index($0, substr(ok[i], 1, length(ok[i]) - 1)) == 1) next
    }
    print
  }')
[ -z "$outside" ] && exit 0
printf '%s\n' "$outside" | sed 's/^/wt-diff: outside the allowed paths: /' >&2
exit 4
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `chmod +x scripts/wt-snap scripts/wt-diff && tests/run-bats tests/scripts/wt-snap-diff.bats && shellcheck scripts/wt-snap scripts/wt-diff`
Expected: `14 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 6: Commit**

```bash
git add -- scripts/wt-snap scripts/wt-diff tests/scripts/wt-snap-diff.bats
git commit -m "M2: add wt-snap and wt-diff with an allowed-path check" -m "Per-task review keys on tree ids from a temporary index, so tasks are reviewed without commits; --allow turns the out-of-Files rule into an exit code."
```

---

