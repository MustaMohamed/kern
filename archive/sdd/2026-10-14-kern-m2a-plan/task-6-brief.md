### Task 6: Claim checks (G9) and the fail-then-pass probe (G10)

**Files:**
- Create: `scripts/claim-check`, `scripts/probe`
- Test: `tests/scripts/claim-probe.bats`

**Interfaces:**
- Consumes: `wt-fork` (Task 3) for the probe's throwaway copy; `scripts/lib/test-paths.awk` (Task 5); `wt-new` in tests.
- Produces:
  - `claim-check WT DIFF_FILE`: one line per hit, `path:line<TAB>sha-unknown<TAB><id>` for a commit id in an added line that WT's repo does not know, and `path:line<TAB>absolute-claim<TAB><comment>` for an added comment with an absolute word; exit 0 clean, 1 hits, 2 usage.
  - `probe [--exclude-tests] WT PATCH -- CMD...`: CMD must pass in WT; on a throwaway fork with PATCH reversed, CMD must fail. `--exclude-tests` reverses only the patch's non-test files, so a test the patch adds stays in the fork; without it, a patch that touches a test file is inconclusive. A command word that names a path existing in WT must still exist in the reversed fork, else inconclusive. Prints `probe: fail-then-pass ok` (exit 0), `probe: test did not fail with the guard removed` (exit 1) or `probe: inconclusive (<why>)` (exit 3); usage exit 2.
  - `probe --mutate FILE:LINE WT -- CMD...`: CMD must pass in WT; on a fork, the first of `===`, `!==`, `==`, `!=`, `<=`, `>=`, `&&`, `||`, ` < `, ` > `, `true`, `false` on that line is inverted, and CMD must fail. Prints `probe: mutation caught (<mutated line>)` (exit 0), `probe: mutation survived (<mutated line>)` (exit 1) or `probe: inconclusive (no condition to invert on FILE:LINE)` (exit 3). WT is never changed.
  - The probe's fork is always removed. A run that could not exercise the test (a compile error, a missing module, "No such file or directory", zero tests run) is inconclusive, never ok.

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bats
# tests/scripts/claim-probe.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  printf 'exit 0\n' > check.sh
  printf 'sh check.sh -1 && exit 1\nexit 0\n' > test-guard.sh
  printf 'exit 0\n' > test-always.sh
  printf 'exit 1\n' > test-red.sh
  printf "grep -q 'ge 0' check.sh || { echo 'SyntaxError: unexpected token'; exit 1; }\nsh check.sh -1 && exit 1\nexit 0\n" > test-compile.sh
  git add . && git commit --quiet -m base && git push --quiet origin main
  WT=$(bash "$KERN_ROOT/scripts/wt-new" probe-target 2> /dev/null)
  printf '[ "$1" -ge 0 ]\n' > "$WT/check.sh"
  git -C "$WT" diff -- check.sh > "$TMP/guard.patch"
}

@test "claim-check flags unknown commit ids and absolute claims only" {
  real=$(git rev-parse --short=12 HEAD)
  printf "// fixed in %s\n// see deadbee1cafe for details\n// this handler is always called after init\nconst color = '#a1b2c3d4';\nconst id = '123e4567-e89b-12d3-a456-426614174000';\n" "$real" > "$WT/notes.js"
  git -C "$WT" add -N notes.js
  git -C "$WT" diff > "$TMP/c.diff"
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$WT" "$TMP/c.diff"
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = $'notes.js:2\tsha-unknown\tdeadbee1cafe' ]
  [[ "${lines[1]}" == $'notes.js:3\tabsolute-claim\t'* ]] || false
}

@test "claim-check passes a diff with a known commit id" {
  real=$(git rev-parse --short=12 HEAD)
  printf '// fixed in %s\n' "$real" > "$WT/notes.js"
  git -C "$WT" add -N notes.js
  git -C "$WT" diff > "$TMP/c.diff"
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$WT" "$TMP/c.diff"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "probe passes when the test fails without the guard" {
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh test-guard.sh
  [ "$status" -eq 0 ]
  [ "$output" = "probe: fail-then-pass ok" ]
  [ "$(git worktree list | grep -c 'probe-[0-9]')" -eq 0 ]
}

@test "probe reports a test that does not cover the guard" {
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh test-always.sh
  [ "$status" -eq 1 ]
  [ "$output" = "probe: test did not fail with the guard removed" ]
}

@test "probe is inconclusive when the test fails with the guard in place" {
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh test-red.sh
  [ "$status" -eq 3 ]
  [[ "${lines[0]}" == "probe: inconclusive (the command fails with the guard in place)"* ]] || false
}

@test "probe is inconclusive when the patch does not reverse-apply" {
  printf 'diff --git a/none.txt b/none.txt\n--- a/none.txt\n+++ b/none.txt\n@@ -1 +1 @@\n-a\n+b\n' > "$TMP/bad.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/bad.patch" -- sh test-guard.sh
  [ "$status" -eq 3 ]
  [[ "$output" == "probe: inconclusive (the patch does not reverse-apply"* ]] || false
}

@test "probe is inconclusive when the test cannot run without the guard" {
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh test-compile.sh
  [ "$status" -eq 3 ]
  [[ "$output" == "probe: inconclusive (the test did not run without the guard"* ]] || false
}

@test "a patch that also adds the test is inconclusive without --exclude-tests" {
  mkdir -p "$WT/test"
  printf 'sh check.sh -1 && exit 1\nexit 0\n' > "$WT/test/guard_test.sh"
  git -C "$WT" add -N test/guard_test.sh
  git -C "$WT" diff > "$TMP/with-test.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/with-test.patch" -- sh test/guard_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == "probe: inconclusive (the patch changes test files: test/guard_test.sh;"* ]] || false
}

@test "--exclude-tests keeps the new test in the fork and reverses only the guard" {
  mkdir -p "$WT/test"
  printf 'sh check.sh -1 && exit 1\nexit 0\n' > "$WT/test/guard_test.sh"
  git -C "$WT" add -N test/guard_test.sh
  git -C "$WT" diff > "$TMP/with-test.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --exclude-tests "$WT" "$TMP/with-test.patch" -- sh test/guard_test.sh
  [ "$status" -eq 0 ]
  [ "$output" = "probe: fail-then-pass ok" ]
}

@test "--exclude-tests on a patch of tests only is inconclusive" {
  mkdir -p "$WT/test"
  printf 'exit 0\n' > "$WT/test/only_test.sh"
  git -C "$WT" add -N test/only_test.sh
  git -C "$WT" diff -- test > "$TMP/tests-only.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --exclude-tests "$WT" "$TMP/tests-only.patch" -- sh test/only_test.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"changes only test files"* ]] || false
}

@test "a command that names a file the reversed fork lacks is inconclusive, never ok" {
  printf 'sh check.sh -1 && exit 1\nexit 0\n' > "$WT/runner.sh"
  git -C "$WT" add -N runner.sh
  git -C "$WT" diff > "$TMP/adds-runner.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/adds-runner.patch" -- sh runner.sh
  [ "$status" -eq 3 ]
  [ "$output" = "probe: inconclusive (the command names runner.sh, which the reversed fork lacks)" ]
}

@test "--mutate: an inverted condition the test catches is ok" {
  printf '[ "$1" != bad ]\n' > "$WT/gate.sh"
  printf 'bash gate.sh bad && exit 1\nbash gate.sh good || exit 1\nexit 0\n' > "$WT/test-gate.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate gate.sh:1 "$WT" -- sh test-gate.sh
  [ "$status" -eq 0 ]
  [ "$output" = 'probe: mutation caught ([ "$1" == bad ])' ]
  [ "$(cat "$WT/gate.sh")" = '[ "$1" != bad ]' ]
}

@test "--mutate: a test that ignores the condition lets the mutation survive" {
  printf '[ "$1" != bad ]\n' > "$WT/gate.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate gate.sh:1 "$WT" -- sh test-always.sh
  [ "$status" -eq 1 ]
  [[ "$output" == "probe: mutation survived"* ]] || false
}

@test "--mutate on a line with no condition is inconclusive" {
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate a.txt:1 "$WT" -- sh test-always.sh
  [ "$status" -eq 3 ]
  [ "$output" = "probe: inconclusive (no condition to invert on a.txt:1)" ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/claim-probe.bats`
Expected: every test fails; `No such file or directory` for the scripts.

- [ ] **Step 3: Write `scripts/claim-check`**

```bash
#!/usr/bin/env bash
# G9: in a diff's added lines, list commit ids the repo does not know and absolute words in added comments.
# Usage: claim-check WT DIFF_FILE    Output: path:line<TAB>sha-unknown|absolute-claim<TAB>value. Exit 1 on hits.
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: claim-check WT DIFF_FILE" >&2; exit 2; }
wt=$1 diff=$2
git -C "$wt" rev-parse --git-dir > /dev/null 2>&1 || { echo "claim-check: not a git worktree: $wt" >&2; exit 2; }
[ -r "$diff" ] || { echo "claim-check: cannot read $diff" >&2; exit 2; }

candidates() {
  awk '
  /^diff --git / { inhunk = 0; next }
  !inhunk && /^\+\+\+ / { file = substr($0, 5); sub(/^b\//, "", file); next }
  /^@@ / { inhunk = 1; split($0, a, " "); nw = a[3]; sub(/^\+/, "", nw); sub(/,.*/, "", nw); newln = nw + 0; next }
  !inhunk { next }
  /^\+/ {
    t = substr($0, 2)
    if (file !~ /(\.lock|lock\.json|lock\.yaml|\.sum|\.min\.[a-z]+|\.svg|\.snap)$/) {
      s = t; consumed = 0
      while (match(s, /[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]+/)) {
        tok = substr(s, RSTART, RLENGTH)
        pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
        pre2 = (RSTART > 2) ? substr(s, RSTART - 2, 2) : ""
        post = substr(s, RSTART + RLENGTH, 1)
        if (RLENGTH <= 40 && tok ~ /[0-9]/ && tok ~ /[a-f]/ && pre !~ /[A-Za-z0-9#_-]/ && post !~ /[A-Za-z0-9_-]/ && pre2 != "0x")
          print file "\t" newln "\tsha\t" tok
        s = substr(s, RSTART + RLENGTH)
      }
    }
    c = t; sub(/^[ \t]+/, "", c)
    if (c ~ /^(\/\/|#|\/\*|\*|--|<!--|;)/) {
      lc = tolower(c)
      if (lc ~ /(^|[^a-z])(always|never|guaranteed|guarantees|impossible|cannot happen|can.t happen|no other|nothing else|only (caller|writer|place|path|way)|all (callers|writers|paths))([^a-z]|$)/) {
        if (length(c) > 120) c = substr(c, 1, 120)
        print file "\t" newln "\tword\t" c
      }
    }
    newln++
    next
  }
  /^-/ { next }
  { newln++ }
  ' "$diff"
}

hits=0
while IFS=$'\t' read -r p ln kind val; do
  case "$kind" in
    sha)
      if git -C "$wt" cat-file -e "$val^{commit}" 2> /dev/null; then continue; fi
      printf '%s:%s\tsha-unknown\t%s\n' "$p" "$ln" "$val"
      hits=$((hits + 1))
      ;;
    word)
      printf '%s:%s\tabsolute-claim\t%s\n' "$p" "$ln" "$val"
      hits=$((hits + 1))
      ;;
  esac
done < <(candidates)
if [ "$hits" -gt 0 ]; then exit 1; fi
exit 0
```

- [ ] **Step 4: Write `scripts/probe`**

```bash
#!/usr/bin/env bash
# G10, fail-then-pass. Patch mode: CMD passes in WT; on a throwaway fork with PATCH reversed, CMD fails.
# Mutate mode: CMD passes in WT; on a fork with one condition inverted at FILE:LINE, CMD fails.
# Usage: probe [--exclude-tests] WT PATCH -- CMD...
#        probe --mutate FILE:LINE WT -- CMD...
# --exclude-tests reverses only the non-test files of PATCH, so a test the patch adds stays in the fork;
# without it, a PATCH that touches a test file is inconclusive. A command word that names a path in WT
# must still exist in the fork. Exit 0 ok; 1 the test did not fail; 3 inconclusive; 2 usage.
# The fork is always removed.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
usage() { echo "usage: probe [--exclude-tests] WT PATCH -- CMD... | probe --mutate FILE:LINE WT -- CMD..." >&2; exit 2; }
excl=0 mutate='' patch=''
case "${1-}" in
  --exclude-tests) excl=1; shift ;;
  --mutate) [ $# -ge 2 ] || usage; mutate=$2; shift 2 ;;
esac
if [ -n "$mutate" ]; then
  [ $# -ge 3 ] && [ "$2" = -- ] || usage
  wtarg=$1
  shift 2
  mfile=${mutate%:*} mline=${mutate##*:}
  case "$mline" in '' | *[!0-9]*) usage ;; esac
else
  [ $# -ge 4 ] && [ "$3" = -- ] || usage
  wtarg=$1
  [ -s "$2" ] || { echo "probe: inconclusive (empty or missing patch: $2)"; exit 3; }
  patch=$(cd "$(dirname "$2")" && pwd -P)/$(basename "$2")
  shift 3
fi
wt=$(cd "$wtarg" 2> /dev/null && pwd -P) || { echo "probe: no such worktree: $wtarg" >&2; exit 2; }

logs=$(mktemp -d "${TMPDIR:-/tmp}/kern-probe.XXXXXX")
fork=''
cleanup() {
  if [ -n "$fork" ] && [ -d "$fork" ]; then git -C "$wt" worktree remove --force "$fork" > /dev/null 2>&1 || true; fi
  rm -rf "$logs"
}
trap cleanup EXIT

excludes=()
if [ -n "$mutate" ]; then
  [ -f "$wt/$mfile" ] || { echo "probe: inconclusive (no such file in the worktree: $mfile)"; exit 3; }
else
  # Every path the patch touches (both sides of a rename), then the test paths among them.
  git -C "$wt" apply --numstat -z "$patch" 2> /dev/null | tr '\0' '\n' |
    awk 'n > 0 { print; n--; next } /^[0-9-]+\t[0-9-]+\t$/ { n = 2; next } { sub(/^[0-9-]+\t[0-9-]+\t/, ""); if ($0 != "") print }' > "$logs/paths"
  awk -v print_tests=1 -f "$here/lib/test-paths.awk" "$logs/paths" > "$logs/tests"
  if [ -s "$logs/tests" ]; then
    if [ "$excl" = 0 ]; then
      echo "probe: inconclusive (the patch changes test files: $(paste -sd ' ' - < "$logs/tests"); pass --exclude-tests so they stay in the fork)"
      exit 3
    fi
    if [ -z "$(awk 'NR == FNR { t[$0] = 1; next } !($0 in t)' "$logs/tests" "$logs/paths")" ]; then
      echo "probe: inconclusive (the patch changes only test files; there is no change to reverse)"
      exit 3
    fi
    while IFS= read -r p; do
      excludes+=("--exclude=$(printf '%s' "$p" | sed 's/[][*?\\]/\\&/g')")
    done < "$logs/tests"
  fi
fi

if ! (cd "$wt" && "$@") > "$logs/with.log" 2>&1; then
  echo "probe: inconclusive (the command fails with the guard in place)"
  tail -n 5 "$logs/with.log"
  exit 3
fi

slug="probe-$$-$RANDOM"
if ! fork=$(cd "$wt" && bash "$here/wt-fork" "$wt" "$slug" 2> "$logs/fork.err"); then
  fork=''
  echo "probe: inconclusive (could not fork: $(tail -n 1 "$logs/fork.err"))"
  exit 3
fi

if [ -n "$mutate" ]; then
  # Invert the first operator found on the line, in this order; a word must stand alone.
  if ! awk -v ln="$mline" '
    function word(s, w,   i, b, a) {
      i = index(s, w); if (!i) return 0
      b = (i == 1) ? "" : substr(s, i - 1, 1); a = substr(s, i + length(w), 1)
      return (b !~ /[A-Za-z0-9_]/ && a !~ /[A-Za-z0-9_]/) ? i : 0
    }
    NR == ln {
      n = split("===,!==,==,!=,<=,>=,&&,||, < , > ,true,false", op, ",")
      split("!==,===,!=,==,>,<,||,&&, >= , <= ,false,true", to, ",")
      for (k = 1; k <= n; k++) {
        i = (op[k] ~ /^[a-z]+$/) ? word($0, op[k]) : index($0, op[k])
        if (i) { $0 = substr($0, 1, i - 1) to[k] substr($0, i + length(op[k])); done = 1; print > "/dev/stderr"; break }
      }
    }
    { print }
    END { exit done ? 0 : 1 }' "$fork/$mfile" > "$logs/mutated" 2> "$logs/mutated-line"; then
    echo "probe: inconclusive (no condition to invert on $mfile:$mline)"
    exit 3
  fi
  cat "$logs/mutated" > "$fork/$mfile"
else
  if ! git -C "$fork" apply -R --check ${excludes[@]+"${excludes[@]}"} "$patch" 2> "$logs/apply.err"; then
    echo "probe: inconclusive (the patch does not reverse-apply: $(head -n 1 "$logs/apply.err"))"
    exit 3
  fi
  git -C "$fork" apply -R ${excludes[@]+"${excludes[@]}"} "$patch"
  for a in "$@"; do
    case "$a" in -* | */) continue ;; esac
    if [ -e "$wt/$a" ] && [ ! -e "$fork/$a" ]; then
      echo "probe: inconclusive (the command names $a, which the reversed fork lacks)"
      exit 3
    fi
  done
fi

if (cd "$fork" && "$@") > "$logs/without.log" 2>&1; then
  if [ -n "$mutate" ]; then echo "probe: mutation survived ($(cat "$logs/mutated-line"))"; else echo "probe: test did not fail with the guard removed"; fi
  exit 1
fi
blocked='error TS[0-9]+|SyntaxError|Cannot find module|ModuleNotFoundError|ImportError|cannot find symbol|compilation failed|syntax error|undefined: |No such file or directory|No tests found|No test files found|no tests ran|collected 0 items|Ran 0 tests'
if grep -Eq "$blocked" "$logs/without.log"; then
  echo "probe: inconclusive (the test did not run without the guard: $(grep -Em1 "$blocked" "$logs/without.log"))"
  exit 3
fi
if [ -n "$mutate" ]; then echo "probe: mutation caught ($(cat "$logs/mutated-line"))"; else echo "probe: fail-then-pass ok"; fi
```

The `worktree remove --force` only removes the throwaway fork this run created.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `chmod +x scripts/claim-check scripts/probe && tests/run-bats tests/scripts/claim-probe.bats && shellcheck scripts/claim-check scripts/probe`
Expected: `14 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 6: Commit**

```bash
git add -- scripts/claim-check scripts/probe tests/scripts/claim-probe.bats
git commit -m "M2: add claim-check (G9) and probe (G10)" -m "A probe that reverses the test along with the guard reports a pass for a missing file; --exclude-tests keeps the test, and a missing path is inconclusive. --mutate inverts a condition on a fork, never in place."
```

---

