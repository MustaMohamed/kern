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

@test "bun runs scripts.test through bun run, not bun's own test runner" {
  # Task 17a P10, D6: `bun test` runs bun's built-in runner and ignores scripts.test.
  printf '{"name":"x","scripts":{"test":"vitest run","lint":"eslint ."}}' >package.json
  for lock in bun.lock bun.lockb; do
    rm -f bun.lock bun.lockb
    touch "$lock"
    run bash "$K/kern-detect" test.full
    [ "$output" = "bun run test	package.json scripts.test" ] || { echo "$lock: $output"; false; }
    run bash "$K/kern-detect" test.focused
    [ "${output%%	*}" = "bun run test -- {file}" ] || { echo "$lock: $output"; false; }
    run bash "$K/kern-detect" lint
    [ "${output%%	*}" = "bun run lint" ] || { echo "$lock: $output"; false; }
  done
}

@test "yarn runs scripts.test with yarn test" {
  printf '{"name":"x","scripts":{"test":"jest","lint":"eslint ."}}' >package.json
  touch yarn.lock
  run bash "$K/kern-detect" test.full
  [ "$output" = "yarn test	package.json scripts.test" ]
  run bash "$K/kern-detect" test.focused
  [ "${output%%	*}" = "yarn test -- {file}" ]
  run bash "$K/kern-detect" lint
  [ "${output%%	*}" = "yarn run lint" ]
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

@test "the npm init placeholder test script is not a test runner" {
  printf '{"scripts":{"test":"echo \\"Error: no test specified\\" && exit 1"}}' >package.json
  run bash "$K/kern-detect" test.full
  [ "$status" -eq 3 ]
  [[ "$output" == *"no test specified"* ]] || false
  run bash "$K/kern-detect" test.focused
  [ "$status" -eq 3 ]
  [[ "$output" == *"no test specified"* ]] || false
}

@test "more than one scripts object in package.json is ambiguous" {
  printf '{"scripts":{"test":"jest","lint":"x"},"nested":{"scripts":{"test":"y"}}}' >package.json
  for k in test.full test.focused typecheck lint build; do
    run bash "$K/kern-detect" "$k"
    [ "$status" -eq 3 ] || { echo "$k: $status"; false; }
    [[ "$output" == *"ambiguous: more than one scripts object in package.json"* ]] || false
  done
}

@test "test.focused evidence does not claim a path argument works" {
  printf '{"scripts":{"test":"jest"}}' >package.json
  run bash "$K/kern-detect" test.focused
  [ "$status" -eq 0 ]
  [[ "$output" == *"(path argument not verified)"* ]] || false
}
