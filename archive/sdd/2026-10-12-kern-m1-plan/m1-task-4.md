### Task 4: Repo facts for skills

**Files:**
- Create: `scripts/kern-root`, `scripts/kern-dir`, `scripts/kern-detect`
- Test: `tests/scripts/kern-dir.bats`, `tests/scripts/kern-detect.bats`

**Interfaces:**
- Consumes: `hooks/lib/settings.sh`, `hooks/lib/json.sh`.
- Produces: `kern-root [DIR]` (line 1 main root, line 2 common git dir; exit 2 not a repo); `kern-dir SUB` (prints `WORK/SUB`, creates it, appends `/<work_dir>/` to `<common>/info/exclude` once; exit 2 for tracked work-dir files or a bad name; SUB is one or more lowercase segments of letters, digits and dashes joined by `/`, such as `ledgers/plan-a`); `kern-detect KEY` for `base_branch`, `branch.pattern`, `commit.convention`, `test.focused`, `test.full`, `typecheck`, `lint`, `build`, `tracker`, `pr.template` (prints `value<TAB>evidence`; exit 3 not detectable with the reason on stderr; exit 2 unknown key). `branch.pattern` values use `{id}` and `{slug}`; `test.focused` uses `{file}`.

- [ ] **Step 1: Write the failing tests**

`tests/scripts/kern-dir.bats`:
```bash
#!/usr/bin/env bats
# scripts/kern-dir and scripts/kern-root.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)/scripts"
}

@test "kern-root prints the main root and the common dir from a linked worktree" {
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  cd "$BATS_TEST_TMPDIR/wt"
  run bash "$K/kern-root"
  [ "${lines[0]}" = "$(cd "$R" && pwd -P)" ]
  [ "$(cd "${lines[1]}" && pwd -P)" = "$(cd "$R/.git" && pwd -P)" ]
}

@test "kern-root outside a repo exits 2" {
  cd "$BATS_TEST_TMPDIR"
  run bash "$K/kern-root" "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
}

@test "kern-dir creates WORK/sub at the main root and adds the exclude line once" {
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  cd "$BATS_TEST_TMPDIR/wt"
  run bash "$K/kern-dir" specs
  [ "$status" -eq 0 ]
  [ -d "$R/.kern/specs" ]
  run bash "$K/kern-dir" plans
  [ "$(grep -cxF '/.kern/' "$R/.git/info/exclude")" -eq 1 ]
  [ -z "$(git -C "$R" status --porcelain)" ]
}

@test "kern-dir creates a nested folder such as ledgers/<slug>" {
  cd "$R"
  run bash "$K/kern-dir" ledgers/plan-a
  [ "$status" -eq 0 ]
  [ -d "$R/.kern/ledgers/plan-a" ]
  run bash "$K/kern-dir" ledgers//x
  [ "$status" -eq 2 ]
}

@test "kern-dir refuses a work dir with tracked files and a bad name" {
  mkdir -p "$R/.kern"; printf 'x\n' >"$R/.kern/t.md"
  git -C "$R" add .kern/t.md; git -C "$R" commit -q -m t
  cd "$R"
  run bash "$K/kern-dir" specs
  [ "$status" -eq 2 ]
  run bash "$K/kern-dir" "../x"
  [ "$status" -eq 2 ]
}
```

`tests/scripts/kern-detect.bats`:
```bash
#!/usr/bin/env bats
# scripts/kern-detect over small fixture repos.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)/scripts"
  cd "$R"
}

@test "base_branch from origin/HEAD" {
  run bash "$K/kern-detect" base_branch
  [ "$output" = "main	refs/remotes/origin/HEAD" ]
}

@test "commit.convention needs 60% of at least 5 subjects" {
  for i in 1 2 3 4 5 6; do git commit -q --allow-empty -m "CDS-1$i: change $i"; done
  git push -q origin main
  run bash "$K/kern-detect" commit.convention
  [ "$status" -eq 0 ]
  [ "${output%%	*}" = '^[A-Z][A-Z0-9]+-[0-9]+: ' ]
}

@test "commit.convention not detectable on mixed subjects exits 3" {
  for s in "fix a" "add b" "x: c" "Update d" "e"; do git commit -q --allow-empty -m "$s"; done
  git push -q origin main
  run bash "$K/kern-detect" commit.convention
  [ "$status" -eq 3 ]
}

@test "test, typecheck and lint from package.json with the lockfile's manager" {
  printf '{"name":"x","scripts":{"test":"jest","lint":"eslint .","type-check":"tsc --noEmit"}}' >package.json
  touch pnpm-lock.yaml
  run bash "$K/kern-detect" test.full
  [ "$output" = "pnpm test	package.json scripts.test" ]
  run bash "$K/kern-detect" test.focused
  [ "${output%%	*}" = "pnpm test -- {file}" ]
  run bash "$K/kern-detect" typecheck
  [ "${output%%	*}" = "pnpm run type-check" ]
  run bash "$K/kern-detect" lint
  [ "${output%%	*}" = "pnpm run lint" ]
}

@test "no runner at all exits 3 and names what it looked for" {
  run bash "$K/kern-detect" test.full
  [ "$status" -eq 3 ]
  [[ "$output" == *"package.json"* ]] || false
}

@test "branch.pattern from remote branch names" {
  for b in CDS-1/a CDS-2/b CDS-3/c CDS-4/d CDS-5/e; do git push -q origin "main:refs/heads/$b"; done
  git fetch -q origin
  run bash "$K/kern-detect" branch.pattern
  [ "${output%%	*}" = '{id}/{slug}' ]
}

@test "pr.template and an unknown key" {
  mkdir -p .github; printf 't\n' >.github/pull_request_template.md
  run bash "$K/kern-detect" pr.template
  [ "${output%%	*}" = .github/pull_request_template.md ]
  run bash "$K/kern-detect" nope
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/kern-dir.bats tests/scripts/kern-detect.bats`
Expected: FAIL; `bash: .../scripts/kern-root: No such file or directory` and the same for `kern-dir` and `kern-detect`.

- [ ] **Step 3: Write `scripts/kern-root`**

```bash
#!/usr/bin/env bash
# Prints the main worktree root (line 1) and the git common dir (line 2).
set -euo pipefail
KERN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KERN_ROOT
# shellcheck source=hooks/lib/settings.sh
. "$KERN_ROOT/hooks/lib/settings.sh"
dir="${1:-$PWD}"
main=$(kern_main_root "$dir") || { echo "kern-root: not a git repository: $dir" >&2; exit 2; }
common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) ||
  common=$(cd "$dir" && cd "$(git rev-parse --git-common-dir)" && pwd)
printf '%s\n%s\n' "$main" "$common"
```

- [ ] **Step 4: Write `scripts/kern-dir`**

```bash
#!/usr/bin/env bash
# Resolves WORK/<sub> under the main worktree root, creates it, and keeps WORK out of git through
# .git/info/exclude. Exit 2 when the work dir holds tracked files.
set -euo pipefail
KERN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KERN_ROOT
# shellcheck source=hooks/lib/settings.sh
. "$KERN_ROOT/hooks/lib/settings.sh"
sub="${1-}"
case "$sub" in
  '' | -* | /* | */ | *//* | */-* | *[!a-z0-9/-]*) echo "kern-dir: name must be lowercase segments of letters, digits and dashes, joined by /" >&2; exit 2 ;;
esac
CWD="$PWD"
KERN_MAIN=$(kern_main_root "$CWD") || { echo "kern-dir: not a git repository" >&2; exit 2; }
export CWD KERN_MAIN
wd=$(settings_get work_dir .kern)
wd=${wd%/}
case "$wd" in
  '' | /* | *..*) echo "kern-dir: work_dir must be a relative path inside the repo, not '$wd'" >&2; exit 2 ;;
esac
if [ -n "$(git -C "$KERN_MAIN" ls-files -- "$wd")" ]; then
  echo "kern-dir: $wd holds tracked files; set work_dir in .claude/kern.local.yml" >&2
  exit 2
fi
common=$(git -C "$KERN_MAIN" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) ||
  common=$(cd "$KERN_MAIN" && cd "$(git rev-parse --git-common-dir)" && pwd)
mkdir -p "$common/info"
if ! grep -qxF "/$wd/" "$common/info/exclude" 2>/dev/null; then
  printf '/%s/\n' "$wd" >>"$common/info/exclude"
  echo "kern: added /$wd/ to .git/info/exclude" >&2
fi
mkdir -p "$KERN_MAIN/$wd/$sub"
printf '%s\n' "$KERN_MAIN/$wd/$sub"
```

- [ ] **Step 5: Write `scripts/kern-detect`**

```bash
#!/usr/bin/env bash
# Detects a settings value from the repo. Prints `value<TAB>evidence`; exit 3 when not detectable.
# Keys: base_branch, branch.pattern, commit.convention, test.focused, test.full, typecheck, lint,
# build, tracker, pr.template.
set -uo pipefail
KERN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KERN_ROOT
# shellcheck source=hooks/lib/json.sh
. "$KERN_ROOT/hooks/lib/json.sh"
# shellcheck source=hooks/lib/settings.sh
. "$KERN_ROOT/hooks/lib/settings.sh"
key="${1-}"
CWD="$PWD"
M=$(kern_main_root "$CWD") || { echo "kern-detect: not a git repository" >&2; exit 2; }
KERN_MAIN="$M"
export CWD KERN_MAIN

out() { printf '%s\t%s\n' "$1" "$2"; exit 0; }
none() { echo "kern-detect: $key not detectable: $1" >&2; exit 3; }

# share COUNT TOTAL: exit 0 when COUNT is at least 60% of TOTAL and TOTAL is at least 5.
share() { [ "$2" -ge 5 ] && [ $(($1 * 100)) -ge $(($2 * 60)) ]; }

base() {
  local b
  b=$(git -C "$M" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || return 1
  printf '%s\n' "${b#origin/}"
}

# pm: the package manager that owns package.json, from its lockfile.
pm() {
  if [ -f "$M/pnpm-lock.yaml" ]; then echo pnpm
  elif [ -f "$M/yarn.lock" ]; then echo yarn
  elif [ -f "$M/bun.lockb" ] || [ -f "$M/bun.lock" ]; then echo bun
  else echo npm
  fi
}

# script NAME: exit 0 and print the run command when package.json has scripts.NAME.
script() {
  local scripts
  [ -f "$M/package.json" ] || return 1
  scripts=$(KERN_INPUT=$(cat "$M/package.json") json_get_raw scripts) || return 1
  KERN_INPUT="$scripts" json_get "$1" >/dev/null || return 1
  if [ "$1" = test ]; then
    printf '%s test\n' "$(pm)"
  else
    printf '%s run %s\n' "$(pm)" "$1"
  fi
}

make_target() {
  [ -f "$M/Makefile" ] && grep -Eq "^$1:" "$M/Makefile"
}

case "$key" in
  base_branch)
    b=$(base) || none "refs/remotes/origin/HEAD is not set (git remote set-head origin --auto)"
    out "$b" "refs/remotes/origin/HEAD"
    ;;
  branch.pattern)
    names=$(git -C "$M" for-each-ref --sort=-committerdate --count=40 --format='%(refname:short)' refs/remotes/origin |
      sed 's#^origin/##' | grep -v -x -e HEAD -e origin -e "$(base 2>/dev/null || echo main)" | head -n 30)
    total=$(printf '%s\n' "$names" | grep -c . || true)
    n=$(printf '%s\n' "$names" | grep -Ec '^[A-Z][A-Z0-9]+-[0-9]+/' || true)
    share "$n" "$total" && out '{id}/{slug}' "$n of $total remote branches match ID/slug"
    n=$(printf '%s\n' "$names" | grep -Ec '^[A-Z][A-Z0-9]+-[0-9]+-' || true)
    share "$n" "$total" && out '{id}-{slug}' "$n of $total remote branches match ID-slug"
    prefix=$(printf '%s\n' "$names" | sed -n 's#^\([a-z]*\)/.*#\1#p' | sort | uniq -c | sort -rn | awk 'NR == 1 { print $1, $2 }')
    if [ -n "$prefix" ] && share "${prefix%% *}" "$total"; then
      out "${prefix#* }/{slug}" "${prefix%% *} of $total remote branches start with ${prefix#* }/"
    fi
    none "no branch shape covers 60% of the last $total remote branches"
    ;;
  commit.convention)
    ref=origin/$(base 2>/dev/null || echo HEAD)
    git -C "$M" rev-parse -q --verify "$ref" >/dev/null || ref=HEAD
    subjects=$(git -C "$M" log --format=%s -30 "$ref" 2>/dev/null)
    total=$(printf '%s\n' "$subjects" | grep -c . || true)
    n=$(printf '%s\n' "$subjects" | grep -Ec '^[A-Z][A-Z0-9]+-[0-9]+: ' || true)
    share "$n" "$total" && out '^[A-Z][A-Z0-9]+-[0-9]+: ' "$n of the last $total subjects start with ID: "
    re='^(feat|fix|chore|docs|refactor|test|perf|build|ci|style|revert)(\([^)]+\))?!?: '
    n=$(printf '%s\n' "$subjects" | grep -Ec "$re" || true)
    share "$n" "$total" && out "$re" "$n of the last $total subjects are Conventional Commits"
    none "no subject shape covers 60% of the last $total commits"
    ;;
  test.full)
    c=$(script test) && out "$c" "package.json scripts.test"
    make_target test && out "make test" "Makefile target test"
    [ -f "$M/pyproject.toml" ] && grep -q 'pytest' "$M/pyproject.toml" && out "pytest" "pyproject.toml mentions pytest"
    [ -f "$M/go.mod" ] && out "go test ./..." "go.mod"
    [ -f "$M/Cargo.toml" ] && out "cargo test" "Cargo.toml"
    none "no package.json scripts.test, Makefile test target, pytest, go.mod or Cargo.toml"
    ;;
  test.focused)
    c=$(script test) && out "$c -- {file}" "package.json scripts.test with a path argument"
    [ -f "$M/pyproject.toml" ] && grep -q 'pytest' "$M/pyproject.toml" && out "pytest {file}" "pyproject.toml mentions pytest"
    [ -f "$M/go.mod" ] && out "go test ./{dir}" "go.mod"
    [ -f "$M/Cargo.toml" ] && out "cargo test {name}" "Cargo.toml"
    none "no focused test runner found"
    ;;
  typecheck)
    for s in typecheck type-check tsc check-types; do
      c=$(script "$s") && out "$c" "package.json scripts.$s"
    done
    make_target typecheck && out "make typecheck" "Makefile target typecheck"
    [ -f "$M/tsconfig.json" ] && out "npx tsc --noEmit" "tsconfig.json at the repo root"
    [ -f "$M/pyproject.toml" ] && grep -q 'mypy' "$M/pyproject.toml" && out "mypy ." "pyproject.toml mentions mypy"
    [ -f "$M/go.mod" ] && out "go vet ./..." "go.mod"
    [ -f "$M/Cargo.toml" ] && out "cargo check" "Cargo.toml"
    none "no typecheck script, tsconfig.json, mypy, go.mod or Cargo.toml"
    ;;
  lint)
    c=$(script lint) && out "$c" "package.json scripts.lint"
    make_target lint && out "make lint" "Makefile target lint"
    [ -f "$M/pyproject.toml" ] && grep -q 'ruff' "$M/pyproject.toml" && out "ruff check ." "pyproject.toml mentions ruff"
    [ -f "$M/Cargo.toml" ] && out "cargo clippy" "Cargo.toml"
    none "no lint script, Makefile target, ruff or Cargo.toml"
    ;;
  build)
    c=$(script build) && out "$c" "package.json scripts.build"
    make_target build && out "make build" "Makefile target build"
    [ -f "$M/go.mod" ] && out "go build ./..." "go.mod"
    [ -f "$M/Cargo.toml" ] && out "cargo build" "Cargo.toml"
    none "no build script, Makefile target, go.mod or Cargo.toml"
    ;;
  tracker)
    url=$(git -C "$M" remote get-url origin 2>/dev/null) || none "no origin remote"
    case "$url" in
      *github.com*) out github "origin is on github.com; a tracker MCP server, if connected, is checked by /kern:help setup" ;;
      *gitlab*) out gitlab "origin is on gitlab" ;;
    esac
    none "origin host is not github or gitlab"
    ;;
  pr.template)
    for p in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md docs/pull_request_template.md pull_request_template.md; do
      [ -f "$M/$p" ] && out "$p" "file exists"
    done
    none "no pull request template"
    ;;
  *)
    echo "usage: kern-detect base_branch|branch.pattern|commit.convention|test.focused|test.full|typecheck|lint|build|tracker|pr.template" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `chmod +x scripts/kern-root scripts/kern-dir scripts/kern-detect && tests/run-bats tests/scripts/kern-dir.bats tests/scripts/kern-detect.bats`
Expected: all 12 tests pass (5 in kern-dir.bats, 7 in kern-detect.bats).

- [ ] **Step 7: Check detection on a real repo, read-only**

Run: `(cd ~/Code/projects/cds/cds-app-rewrite && for k in base_branch branch.pattern commit.convention test.full typecheck lint build tracker pr.template; do printf '%s: ' "$k"; bash ~/Code/projects/kern/scripts/kern-detect "$k" 2>&1; done)`
Expected: one line per key with a value and evidence, for example `commit.convention: ^[A-Z][A-Z0-9]+-[0-9]+: <TAB>24 of the last 30 subjects start with ID: `. The script writes nothing.

- [ ] **Step 8: Commit**

```bash
git add -- scripts/kern-root scripts/kern-dir scripts/kern-detect tests/scripts/kern-dir.bats tests/scripts/kern-detect.bats
git commit -m "M1: add kern-root, kern-dir and kern-detect" -m "Skills resolve the main root, the working directory and project commands the same way the hooks do, and say where each value came from."
```

---

