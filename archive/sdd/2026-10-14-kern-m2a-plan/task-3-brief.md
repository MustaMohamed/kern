### Task 3: Forks and serial integration

**Files:**
- Create: `scripts/wt-fork`, `scripts/wt-apply`
- Test: `tests/scripts/wt-fork-apply.bats`

**Interfaces:**
- Consumes: `wt-snap`, `wt-common.sh` (Tasks 1 and 2).
- Produces:
  - `wt-fork SRC_WT SLUG`: detached worktree at SRC_WT's HEAD with SRC_WT's uncommitted state applied as a `git diff-tree -p --binary --full-index` patch; prints the fork path; exit 0, 3 when the state cannot be applied, 2 when `worktree.setup` fails (in both cases the fork is removed, the setup log printed first) or on other errors. Settings come from MAIN through `KERN_MAIN`, wherever it is run from. Invariant: `wt-snap <fork>` equals `wt-snap <src>` at fork time, whatever the user's diff config.
  - `wt-apply PATCH DST_WT`: `git apply --check`, then `git apply`; prints `applied`; exit 0, 3 on a conflict (DST unchanged), 2 on a usage error.

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bats
# tests/scripts/wt-fork-apply.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  SRC=$(bash "$KERN_ROOT/scripts/wt-new" plan)
}

@test "fork carries modified and untracked files and snapshots to the same tree" {
  printf 'edited\n' >> "$SRC/a.txt"
  printf 'new\n' > "$SRC/b.txt"
  src_tree=$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-1
  [ "$status" -eq 0 ]
  fork=$output
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")" = "$src_tree" ]
  [ "$(git -C "$fork" rev-parse HEAD)" = "$(git -C "$SRC" rev-parse HEAD)" ]
  [ "$(git -C "$fork" rev-parse --abbrev-ref HEAD)" = "HEAD" ]
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")" = "$src_tree" ]
}

@test "fork carries a deletion and a binary file" {
  rm "$SRC/a.txt"
  printf '\000\001\002binary' > "$SRC/blob.bin"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-2
  [ "$status" -eq 0 ]
  fork=$output
  [ ! -e "$fork/a.txt" ]
  cmp -s "$SRC/blob.bin" "$fork/blob.bin"
}

@test "a fork passes wt-check" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-3 2> /dev/null)
  run bash "$KERN_ROOT/scripts/wt-check" "$fork" origin/main
  [ "$status" -eq 0 ]
}

@test "an existing fork path exits 2" {
  bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-4 > /dev/null 2>&1
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-4
  [ "$status" -eq 2 ]
}

@test "wt-apply applies a worker's patch into the plan worktree" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-5 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'from worker\n' > "$fork/w.txt"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/w.diff" | head -n 1)
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 0 ]
  [ "$output" = "applied" ]
  [ "$(cat "$SRC/w.txt")" = "from worker" ]
}

@test "wt-apply applies a binary patch" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-6 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf '\000\377bin' > "$fork/img.bin"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/b.diff" | head -n 1)
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 0 ]
  cmp -s "$fork/img.bin" "$SRC/img.bin"
}

@test "a conflicting patch exits 3 and leaves the destination unchanged" {
  fork=$(bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-7 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'one\nTWO-worker\nthree\n' > "$fork/a.txt"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/c.diff" | head -n 1)
  printf 'one\nTWO-other\nthree\n' > "$SRC/a.txt"
  before=$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 3 ]
  [[ "$output" == *"a.txt"* ]] || false
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")" = "$before" ]
}

@test "a missing patch file exits 2" {
  run bash "$KERN_ROOT/scripts/wt-apply" "$TMP/none.patch" "$SRC"
  [ "$status" -eq 2 ]
}

@test "a fork made from another directory reads worktree.setup from the main checkout" {
  mkdir -p .claude
  printf 'worktree.setup: touch setup-ran\n' > .claude/kern.local.yml
  cd "$TMP"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-8
  [ "$status" -eq 0 ]
  [ -f "$output/setup-ran" ]
}

@test "a failing worktree.setup removes the fork" {
  mkdir -p .claude
  printf 'worktree.setup: echo setup broke; exit 7\n' > .claude/kern.local.yml
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-9
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"setup broke"* ]] || false
  [[ "$stderr" == *"fork removed"* ]] || false
  [ ! -e "$REPO/.claude/worktrees/task-9" ]
  ! git worktree list | grep -q task-9
}

@test "diff.noprefix in the user's git config changes neither forks nor patches" {
  git config --global diff.noprefix true
  printf 'edited\n' >> "$SRC/a.txt"
  printf 'new\n' > "$SRC/b.txt"
  src_tree=$(bash "$KERN_ROOT/scripts/wt-snap" "$SRC")
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-fork" "$SRC" task-10
  [ "$status" -eq 0 ]
  fork=$output
  [ "$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")" = "$src_tree" ]
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$fork")
  printf 'from worker\n' > "$fork/w.txt"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$fork" "$t0" --out "$TMP/np.diff" | head -n 1)
  run bash "$KERN_ROOT/scripts/wt-apply" "$pkg.patch" "$SRC"
  [ "$status" -eq 0 ]
  [ "$(cat "$SRC/w.txt")" = "from worker" ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/wt-fork-apply.bats`
Expected: every test fails with `No such file or directory` for `scripts/wt-fork` or `scripts/wt-apply`.

- [ ] **Step 3: Write `scripts/wt-fork`**

```bash
#!/usr/bin/env bash
# Detached worktree at SRC_WT's HEAD with SRC_WT's uncommitted state (tracked and untracked) applied.
# Usage: wt-fork SRC_WT SLUG    Prints the fork path. Exit 3 when the state cannot be applied, 2 when
# worktree.setup fails; either way the fork is removed. The state moves as a diff-tree patch, which
# ignores diff.noprefix, textconv and external diff drivers in the user's config.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=/dev/null
. "$here/../hooks/lib/settings.sh"
# shellcheck source=/dev/null
. "$here/lib/wt-common.sh"

[ $# -eq 2 ] || { echo "usage: wt-fork SRC_WT SLUG" >&2; exit 2; }
src=$(cd "$1" 2> /dev/null && pwd -P) || { echo "wt-fork: no such directory: $1" >&2; exit 2; }
slug=$2
case "$slug" in ''|.*|*[!A-Za-z0-9._-]*) echo "wt-fork: bad slug: $slug" >&2; exit 2 ;; esac
MAIN=$(kern_main_root "$src") || { echo "wt-fork: not a git repository: $src" >&2; exit 2; }
# settings_get reads KERN_MAIN, so worktree.dir and worktree.setup come from MAIN, not the caller's cwd.
export KERN_MAIN="$MAIN"
head=$(git -C "$src" rev-parse --verify --quiet HEAD) || { echo "wt-fork: $src has no commits" >&2; exit 2; }
tree=$(bash "$here/wt-snap" "$src")

dir=$(wt_dir)
path="$dir/$slug"
wt_path_free "$path" || exit 2
mkdir -p "$dir"
wt_exclude_dir "$dir"

patch=$(mktemp "${TMPDIR:-/tmp}/kern-fork.XXXXXX")
trap 'rm -f "$patch"' EXIT
git -C "$src" diff-tree -r -p --binary --full-index "$head" "$tree" > "$patch"
git -C "$MAIN" worktree add --quiet --detach "$path" "$head" >&2
path=$(cd "$path" && pwd -P)
if [ -s "$patch" ] && ! git -C "$path" apply --binary "$patch" >&2; then
  git -C "$MAIN" worktree remove --force "$path" > /dev/null 2>&1 || true
  echo "wt-fork: could not apply the uncommitted state of $src; fork removed" >&2
  exit 3
fi
wt_include "$path"
if ! wt_setup "$path"; then
  log="$(git -C "$path" rev-parse --path-format=absolute --git-dir)/kern-setup.log"
  tail -n 20 "$log" >&2 2> /dev/null || true
  git -C "$MAIN" worktree remove --force "$path" > /dev/null 2>&1 || true
  echo "wt-fork: worktree.setup failed in the fork (its log is above); fork removed" >&2
  exit 2
fi
printf '%s\n' "$path"
```

The `worktree remove --force` here only removes the fork this run just created; it holds no other work.

- [ ] **Step 4: Write `scripts/wt-apply`**

```bash
#!/usr/bin/env bash
# Apply a binary-safe patch (wt-diff's <package>.patch) into a worktree, all or nothing.
# Usage: wt-apply PATCH DST_WT    Prints "applied". Exit 3 on conflict, with DST_WT unchanged.
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: wt-apply PATCH DST_WT" >&2; exit 2; }
patch=$1 dst=$2
[ -f "$patch" ] || { echo "wt-apply: no such patch: $patch" >&2; exit 2; }
git -C "$dst" rev-parse --git-dir > /dev/null 2>&1 || { echo "wt-apply: not a git worktree: $dst" >&2; exit 2; }
patch=$(cd "$(dirname "$patch")" && pwd -P)/$(basename "$patch")
if ! out=$(git -C "$dst" apply --check --binary "$patch" 2>&1); then
  echo "wt-apply: conflict, nothing applied:"
  printf '%s\n' "$out"
  exit 3
fi
git -C "$dst" apply --binary "$patch"
echo applied
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `chmod +x scripts/wt-fork scripts/wt-apply && tests/run-bats tests/scripts/wt-fork-apply.bats && shellcheck scripts/wt-fork scripts/wt-apply`
Expected: `11 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 6: Commit**

```bash
git add -- scripts/wt-fork scripts/wt-apply tests/scripts/wt-fork-apply.bats
git commit -m "M2: add wt-fork and wt-apply" -m "Wave workers need a copy of earlier uncommitted work, and their results must come back one patch at a time with conflicts stopping the run."
```

- [ ] **Step 7: Checkpoint**

Run: `scripts/ci-local`
Expected: last line `ci-local: all steps passed`. Stop and fix anything red before Task 4.

---

