### Task 2: `fetch-upstream`

**Files:**
- Create: `scripts/fetch-upstream`
- Test: `tests/scripts/fetch-upstream.bats`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `bash scripts/fetch-upstream [key...]` fills `.upstream/<key>/` for keys `superpowers pstack pocock addy caveman local` (all when none given). Env overrides for tests: `KERN_UPSTREAM_DIR` (destination), `KERN_UPSTREAM_<KEY>_URL`, `KERN_UPSTREAM_<KEY>_SHA`, `KERN_UPSTREAM_<KEY>_SRC` (copy source), with `<KEY>` upper case. Exit 0 all fetched; 3 a pinned commit or copy source is missing.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats
# tests/scripts/fetch-upstream.bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export KERN_UPSTREAM_DIR="$BATS_TEST_TMPDIR/up"
  REMOTE="$BATS_TEST_TMPDIR/remote"
  git init -q -b main "$REMOTE"
  git -C "$REMOTE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
  SHA1=$(git -C "$REMOTE" rev-parse HEAD)
  git -C "$REMOTE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
  export KERN_UPSTREAM_ADDY_URL="$REMOTE" KERN_UPSTREAM_ADDY_SHA="$SHA1"
}

@test "clones at the pinned commit" {
  run bash "$ROOT/scripts/fetch-upstream" addy
  [ "$status" -eq 0 ]
  [ "$(git -C "$KERN_UPSTREAM_DIR/addy" rev-parse HEAD)" = "$SHA1" ]
}

@test "second run is a no-op" {
  bash "$ROOT/scripts/fetch-upstream" addy
  run bash "$ROOT/scripts/fetch-upstream" addy
  [ "$status" -eq 0 ]
  [[ "$output" == *"addy: already at"* ]] || false
}

@test "missing commit exits 3 and removes the partial clone" {
  export KERN_UPSTREAM_ADDY_SHA=0000000000000000000000000000000000000000
  run bash "$ROOT/scripts/fetch-upstream" addy
  [ "$status" -eq 3 ]
  [ ! -e "$KERN_UPSTREAM_DIR/addy" ]
}

@test "copy source is copied" {
  mkdir -p "$BATS_TEST_TMPDIR/cave"; echo hi > "$BATS_TEST_TMPDIR/cave/NOTICE"
  export KERN_UPSTREAM_CAVEMAN_SRC="$BATS_TEST_TMPDIR/cave"
  run bash "$ROOT/scripts/fetch-upstream" caveman
  [ "$status" -eq 0 ]
  [ "$(cat "$KERN_UPSTREAM_DIR/caveman/NOTICE")" = hi ]
}

@test "missing copy source exits 3" {
  export KERN_UPSTREAM_CAVEMAN_SRC="$BATS_TEST_TMPDIR/nope"
  run bash "$ROOT/scripts/fetch-upstream" caveman
  [ "$status" -eq 3 ]
}

@test "a failing git source is not swallowed" {
  export KERN_UPSTREAM_ADDY_URL="$BATS_TEST_TMPDIR/no-such-remote"
  run bash "$ROOT/scripts/fetch-upstream" addy
  [ "$status" -eq 3 ]
}

@test "unknown key exits 2" {
  run bash "$ROOT/scripts/fetch-upstream" nonsense
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bats tests/scripts/fetch-upstream.bats`
Expected: every test fails with `No such file or directory` for `scripts/fetch-upstream`.

- [ ] **Step 3: Write `scripts/fetch-upstream`**

```bash
#!/usr/bin/env bash
# Fills .upstream/ with the pinned source trees that kern files are ported from. Dev-only; hooks never run it.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
dest="${KERN_UPSTREAM_DIR:-$root/.upstream}"
mkdir -p "$dest"

pin() { # key -> "url sha" for git sources
  case "$1" in
    superpowers) echo "https://github.com/obra/superpowers.git 5bf4e78011075bcfc0dc295f0724994cd123ee71" ;;
    pstack) echo "https://github.com/cursor/plugins.git 11713c6" ;;
    pocock) echo "https://github.com/mattpocock/skills.git 49dd158" ;;
    addy) echo "https://github.com/addyosmani/agent-skills.git 1be8e34" ;;
    *) return 1 ;;
  esac
}

override() { # key suffix default
  local var
  var="KERN_UPSTREAM_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')_$2"
  printf '%s' "${!var:-$3}"
}

clone_at() { # key url sha
  local key=$1 url=$2 sha=$3 dir="$dest/$1"
  if [ -d "$dir/.git" ]; then
    local want
    want=$(git -C "$dir" rev-parse --verify --quiet "$sha^{commit}" || true)
    if [ -n "$want" ] && [ "$(git -C "$dir" rev-parse HEAD)" = "$want" ]; then
      echo "$key: already at $sha"
      return 0
    fi
  fi
  rm -rf "$dir"
  if ! git clone --quiet "$url" "$dir"; then
    rm -rf "$dir"
    echo "$key: clone failed: $url" >&2
    return 3
  fi
  if ! git -C "$dir" checkout --quiet --detach "$sha" 2>/dev/null; then
    rm -rf "$dir"
    echo "$key: commit $sha not found in $url" >&2
    return 3
  fi
  echo "$key: $url @ $sha"
}

copy_from() { # key src...
  local key=$1 dir="$dest/$1"
  shift
  rm -rf "$dir"
  mkdir -p "$dir"
  local src
  for src in "$@"; do
    if [ ! -e "$src" ]; then
      rm -rf "$dir"
      echo "$key: source missing: $src" >&2
      return 3
    fi
    cp -R "$src" "$dir"/
  done
  echo "$key: copied"
}

fetch() {
  local key=$1 url sha
  case "$key" in
    superpowers|pstack|pocock|addy)
      read -r url sha <<<"$(pin "$key")"
      url=$(override "$key" URL "$url")
      sha=$(override "$key" SHA "$sha")
      local rc=0
      clone_at "$key" "$url" "$sha" || rc=$?
      if [ "$rc" -ne 0 ] && [ "$key" = superpowers ] && [ -z "${KERN_UPSTREAM_SUPERPOWERS_URL:-}" ]; then
        echo "superpowers: falling back to the installed cache" >&2
        copy_from superpowers "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/."
        return
      fi
      return "$rc"
      ;;
    caveman)
      local src
      src=$(override caveman SRC "$HOME/.claude/plugins/cache/caveman/caveman/3.2.0")
      copy_from caveman "$src/."
      ;;
    local)
      local src
      src=$(override local SRC "")
      if [ -n "$src" ]; then
        copy_from local "$src/."
      else
        copy_from local "$HOME/.claude/skills/recall" "$HOME/.claude/skills/unslop" "$HOME/.claude/skills/no-comments" "$HOME/.claude/agents/comment-sicko.md"
      fi
      ;;
    *)
      echo "unknown source: $key (use superpowers pstack pocock addy caveman local)" >&2
      exit 2
      ;;
  esac
}

keys=("$@")
[ ${#keys[@]} -gt 0 ] || keys=(superpowers pstack pocock addy caveman local)
status=0
for k in "${keys[@]}"; do
  fetch "$k" || status=$?
done
exit "$status"
```

Note: `copy_from superpowers "$cache/."` copies the directory's contents; `cp -R "$src" "$dir"/` with a trailing `/.` copies contents, and without it copies the named directory into `$dir`, which is what the `local` key wants (`.upstream/local/recall/...`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `chmod +x scripts/fetch-upstream && bats tests/scripts/fetch-upstream.bats && shellcheck scripts/fetch-upstream`
Expected: all 7 tests pass (`1..7` and seven `ok` lines when not on a terminal, `7 tests, 0 failures` on one); shellcheck prints nothing.

- [ ] **Step 5: Fetch the real sources**

Run: `bash scripts/fetch-upstream`
Expected: six lines, one per key, exit 0. `ls .upstream` shows `addy caveman local pocock pstack superpowers`. If superpowers fell back to the cache, record that in Task 3's `UPSTREAM.md` row.

- [ ] **Step 6: Commit**

```bash
git add -- scripts/fetch-upstream tests/scripts/fetch-upstream.bats
git commit -m "M0: fetch pinned upstream sources into .upstream for port tasks"
```

---

