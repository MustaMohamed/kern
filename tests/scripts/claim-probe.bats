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

@test "a tool only in an ignored directory makes the probe inconclusive, never ok" {
  mkdir -p "$WT/nm"
  printf '#!/bin/sh\nexit 0\n' > "$WT/nm/jest"
  chmod +x "$WT/nm/jest"
  printf 'nm/\n' >> "$(git -C "$WT" rev-parse --git-path info/exclude)"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh -c 'PATH=$PWD/nm:$PATH; jest || exit 1; sh check.sh -1 && exit 1; exit 0'
  [ "$status" -eq 3 ]
  [ "$output" = "probe: inconclusive (the command fails in the fork before any change is reversed; missing ignored files or setup?)" ]
}

@test "--mutate: a tool only in an ignored directory is inconclusive" {
  mkdir -p "$WT/nm"
  printf '#!/bin/sh\nexit 0\n' > "$WT/nm/jest"
  chmod +x "$WT/nm/jest"
  printf 'nm/\n' >> "$(git -C "$WT" rev-parse --git-path info/exclude)"
  printf '[ "$1" != bad ]\n' > "$WT/gate.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate gate.sh:1 "$WT" -- sh -c 'PATH=$PWD/nm:$PATH; jest || exit 1; bash gate.sh bad && exit 1; exit 0'
  [ "$status" -eq 3 ]
  [[ "$output" == "probe: inconclusive (the command fails in the fork before any change is reversed"* ]] || false
}

@test "a patch git cannot read is inconclusive" {
  printf 'this is not a patch\n' > "$TMP/garbage.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/garbage.patch" -- sh test-guard.sh
  [ "$status" -eq 3 ]
  [ "$output" = "probe: inconclusive (cannot read the patch)" ]
}

@test "no probe worktree remains after a non-zero exit" {
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh test-always.sh
  [ "$status" -eq 1 ]
  [ "$(git worktree list | grep -c 'probe-[0-9]')" -eq 0 ]
  mkdir -p "$WT/nm"
  printf '#!/bin/sh\nexit 0\n' > "$WT/nm/jest"
  chmod +x "$WT/nm/jest"
  printf 'nm/\n' >> "$(git -C "$WT" rev-parse --git-path info/exclude)"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh -c 'PATH=$PWD/nm:$PATH; jest || exit 1; exit 0'
  [ "$status" -eq 3 ]
  [ "$(git worktree list | grep -c 'probe-[0-9]')" -eq 0 ]
}

@test "apply.whitespace in the user's git config does not change the reversed fork" {
  printf '[apply]\n\twhitespace = error\n' > "$TMP/gitconfig"
  export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
  # The base line holds trailing blanks, so reversing the patch adds a line with a whitespace error.
  printf 'exit 0  \n' > check.sh
  git add check.sh && git commit --quiet -m blanks && git push --quiet origin main
  wt=$(bash "$KERN_ROOT/scripts/wt-new" probe-ws 2> /dev/null)
  printf '[ "$1" -ge 0 ]\n' > "$wt/check.sh"
  git -C "$wt" diff -- check.sh > "$TMP/ws.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$wt" "$TMP/ws.patch" -- sh test-guard.sh
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "probe: fail-then-pass ok" ]
}

# Audit 2026-10-22, D1: a reversed patch that removes an export the test calls errors on the missing name.
@test "a missing-name error in the reversed run is inconclusive, never ok" {
  printf 'function clamp(x) { return Math.max(0, x); }\nmodule.exports = { clamp };\n' > "$WT/m.js"
  git -C "$WT" add m.js && git -C "$WT" commit --quiet -m m
  printf 'function clamp(x) { return Math.max(0, x); }\nfunction isPositive(x) { return true; }\nmodule.exports = { clamp, isPositive };\n' > "$WT/m.js"
  mkdir -p "$WT/test"
  printf "const assert = require('assert');\nconst { isPositive } = require('../m');\nassert.strictEqual(isPositive(5), true);\n" > "$WT/test/m.test.js"
  git -C "$WT" add -N test/m.test.js
  git -C "$WT" diff -- m.js test > "$TMP/export.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --exclude-tests "$WT" "$TMP/export.patch" -- node test/m.test.js
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  [[ "$output" == "probe: inconclusive (the test did not run without the guard: "*"isPositive is not a function"* ]] || false
}

# Audit 2026-10-22, D1 and F-P2: each marker of a test that did not run, in any case, makes the probe
# inconclusive. Each line matches one marker only.
@test "every did-not-run marker in the reversed run makes the probe inconclusive" {
  printf 'sh check.sh -1 && { printf "%%s\\n" "$1"; exit 1; }\nexit 0\n' > "$WT/test-says.sh"
  for say in 'No tests found, exiting with code 1' 'collected 0 items' 'Ran 0 tests in 0.000s' 'no tests ran in 0.01s' \
    'ReferenceError: isPositive is not defined' "undefined local variable or method 'x' for main (NameError)" \
    "AttributeError: module 'm' has no attribute 'is_positive'" 'error[E0425]: cannot find function `is_positive` in this scope' \
    'error[E0425]: cannot find value `limit` in this scope' 'error[E0412]: cannot find type `Gate` in this scope' \
    'error[E0432]: unresolved import `crate::gate`' 'error: could not compile `gate` (lib test) due to 1 previous error' \
    "undefined method 'positive?' for 5:Integer (NoMethodError)" 'uninitialized constant Gate' \
    "error: cannot find 'isPositive' in scope" "e: Gate.kt:3:5: Unresolved reference 'isPositive'." \
    "gate.c:3:10: error: use of undeclared identifier 'is_positive'" 'open data/in.txt: no such file or directory'; do
    run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh test-says.sh "$say"
    [ "$status" -eq 3 ] || { echo "$say: $status $output"; return 1; }
    [ "$output" = "probe: inconclusive (the test did not run without the guard: $say)" ] || { echo "$output"; return 1; }
  done
}

@test "a plain TypeError is an assertion failure; ok prints the reversed run's last lines" {
  printf 'sh check.sh -1 && { echo "TypeError: expected a non-negative number"; exit 1; }\nexit 0\n' > "$WT/test-type.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh test-type.sh
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "probe: fail-then-pass ok" ]
  [ "$stderr" = "TypeError: expected a non-negative number" ]
}

# Audit 2026-10-22, D2: a comment-only change plus a golden file must not read as proven.
@test "--exclude-tests keeps golden files and test data in the fork" {
  printf 'echo hello\n' > "$WT/gen.sh"
  git -C "$WT" add gen.sh && git -C "$WT" commit --quiet -m gen
  printf '# says hello\necho hello\n' > "$WT/gen.sh"
  mkdir -p "$WT/testdata"
  printf 'hello\n' > "$WT/testdata/gen.golden"
  printf '[ -f testdata/gen.golden ] || { echo "open testdata/gen.golden: no such file or directory"; exit 1; }\n[ "$(sh gen.sh)" = "$(cat testdata/gen.golden)" ]\n' > "$WT/gen_test.sh"
  git -C "$WT" add -N testdata/gen.golden gen_test.sh
  git -C "$WT" diff -- gen.sh testdata gen_test.sh > "$TMP/golden.patch"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --exclude-tests "$WT" "$TMP/golden.patch" -- sh gen_test.sh
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  [ "$output" = "probe: test did not fail with the guard removed" ]
}

@test "is_probe_keep adds test data, fixtures, snapshots and golden files; is_test stays as it was" {
  printf '%s\n' testdata/gen.golden pkg/testdata/in.txt fixtures/a.json src/__fixtures__/b.json __snapshots__/c.js \
    ui/d.snap e.golden test/x.sh src/m.js data/in.txt src/snapshot.js > "$TMP/paths"
  run awk -v print_keep=1 -f "$KERN_ROOT/scripts/lib/test-paths.awk" "$TMP/paths"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' testdata/gen.golden pkg/testdata/in.txt fixtures/a.json src/__fixtures__/b.json __snapshots__/c.js ui/d.snap e.golden test/x.sh)" ]
  run awk -v print_tests=1 -f "$KERN_ROOT/scripts/lib/test-paths.awk" "$TMP/paths"
  [ "$status" -eq 0 ]
  [ "$output" = "test/x.sh" ]
}

# Audit 2026-10-22, C-I2: a command that cds to the worktree runs the worktree, not the reversed fork.
@test "a command or script that names the worktree by its absolute path is inconclusive" {
  printf 'cd %s && sh test-guard.sh\n' "$WT" > "$TMP/abs-run.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- bash "$TMP/abs-run.sh"
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  [ "$output" = "probe: inconclusive ($TMP/abs-run.sh names the worktree by its absolute path, so the fork would run the worktree)" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- sh -c "cd '$WT' && sh test-guard.sh"
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  [ "$output" = "probe: inconclusive (the command names the worktree by its absolute path, so the fork would run the worktree)" ]
  # WT named through a symlink: the script holds that path, not the physical one.
  ln -s "$WT" "$TMP/wt-link"
  printf 'cd %s && sh test-guard.sh\n' "$TMP/wt-link" > "$TMP/link-run.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$TMP/wt-link" "$TMP/guard.patch" -- bash "$TMP/link-run.sh"
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  [ "$(git worktree list | grep -c 'probe-[0-9]')" -eq 0 ]
  printf 'sh test-guard.sh\n' > "$TMP/rel-run.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" "$WT" "$TMP/guard.patch" -- bash "$TMP/rel-run.sh"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "probe: fail-then-pass ok" ]
}

# Audit 2026-10-22, D9: --mutate writes only inside its fork.
@test "--mutate refuses an absolute path or a .. part" {
  mkdir -p "$TMP/outside"
  printf '[ "$1" != bad ]\n' > "$TMP/outside/gate.sh"
  printf '[ "$1" != bad ]\n' > "$WT/gate.sh"
  printf 'bash gate.sh bad && exit 1\nbash gate.sh good || exit 1\nexit 0\n' > "$WT/test-gate.sh"
  [ -f "$WT/../../../../outside/gate.sh" ]
  for m in "$TMP/outside/gate.sh" ../../../../outside/gate.sh ./../../../../outside/gate.sh; do
    run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate "$m:1" "$WT" -- sh test-gate.sh
    [ "$status" -eq 2 ] || { echo "$m: $status $output"; return 1; }
    [ "$stderr" = "probe: --mutate takes a path relative to WT, with no .. part: $m" ]
  done
  [ "$(cat "$TMP/outside/gate.sh")" = '[ "$1" != bad ]' ]
}

@test "--mutate refuses a symlink that leads outside the fork, and follows one that stays inside" {
  mkdir -p "$TMP/outside"
  printf '[ "$1" != bad ]\n' > "$TMP/outside/gate.sh"
  printf '[ "$1" != bad ]\n' > "$WT/gate.sh"
  ln -s "$TMP/outside/gate.sh" "$WT/link.sh"
  ln -s "$TMP/outside" "$WT/ld"
  ln -s gate.sh "$WT/inlink.sh"
  git -C "$WT" add gate.sh link.sh ld inlink.sh && git -C "$WT" commit --quiet -m links
  printf 'bash link.sh bad && exit 1\nbash link.sh good || exit 1\nexit 0\n' > "$WT/test-link.sh"
  printf 'bash gate.sh bad && exit 1\nbash gate.sh good || exit 1\nexit 0\n' > "$WT/test-gate.sh"
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate link.sh:1 "$WT" -- sh test-link.sh
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  [ "$output" = "probe: inconclusive (link.sh resolves through a symlink outside the fork)" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate ld/gate.sh:1 "$WT" -- sh -c 'bash ld/gate.sh bad && exit 1; exit 0'
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  [ "$output" = "probe: inconclusive (ld/gate.sh resolves through a symlink outside the fork)" ]
  [ "$(cat "$TMP/outside/gate.sh")" = '[ "$1" != bad ]' ]
  run --separate-stderr bash "$KERN_ROOT/scripts/probe" --mutate inlink.sh:1 "$WT" -- sh test-gate.sh
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = 'probe: mutation caught ([ "$1" == bad ])' ]
  [ "$(cat "$WT/gate.sh")" = '[ "$1" != bad ]' ]
}
