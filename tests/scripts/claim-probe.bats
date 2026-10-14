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
