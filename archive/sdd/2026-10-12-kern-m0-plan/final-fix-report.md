# kern M0 final-fix report

## 1. check-version Unreleased vs base (c8a2ffe)
Changed: scripts/check-version.mjs (checkUnreleased 3rd arg baseChangelog; --pr reads `git show <base>:CHANGELOG.md`, missing file = empty; bare --pr exits 2 with usage), tests/versions.test.mjs.
RED (node --test tests/versions.test.mjs): `not ok 4 - a stale Unreleased bullet already in the base fails`, `not ok 8 - --pr compares HEAD changelog against the base ref`; pass 11, fail 2.
GREEN: pass 13, fail 0.

## 2. fetch-upstream atomic replace (5f8fd00)
Changed: scripts/fetch-upstream (clone/copy into "$dir.new", swap on success, remove only .new on failure, cp/mkdir failures caught), tests/scripts/fetch-upstream.bats (two new tests; existing [[ ]] line already ends `|| false`).
RED: `not ok 7 a failing re-run keeps the previous good clone` (fatal: cannot change to .../up/addy: No such file or directory); `not ok 8 a failing copy keeps the previous copy` (status was 0, "caveman: copied").
GREEN: bats 1..9, all ok; shellcheck clean.

## 3. Full pins (4196a33)
scripts/fetch-upstream and UPSTREAM.md use 11713c683fe4add4fd403ea880580abbc9e0875f, 49dd158d1076134a641b33efb035946536778336, 1be8e34187e34647bb83adc3a1323b26ae6f6abe; each confirmed equal to `git -C .upstream/<key> rev-parse HEAD`. UPSTREAM.md intro says caveman is copied from the installed plugin cache.

## 4. ci-local Node guard (cc94953)
Guard added after `cd`; header fixed. Verified with node absent from PATH: prints "Node 22 or later is required", exit 2.

## 5. Rule 8 tests (5410865)
New test for scripts/lint-names.txt (name flagged once, `#` line ignored); existing test env change wrapped in try/finally. No RED: rule 8 already implemented that behaviour, so the new test is coverage and passed immediately. node --test tests/lint-rules.test.mjs: pass 15, fail 0.

## 6. CI permissions (92cecaa)
Top-level `permissions: contents: read` in .github/workflows/ci.yml.

## Final scripts/ci-local output (tail)
  ---
  duration_ms: 0.80625
  type: 'test'
  ...
# Subtest: CLI runs when reached through a symlink
ok 44 - CLI runs when reached through a symlink
  ---
  duration_ms: 48.347792
  type: 'test'
  ...
1..44
# tests 44
# suites 0
# pass 44
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 701.533666
lint: clean
versions: agree
rank-1 rate: 100% (baseline 0%)
route-eval: passed
Validating marketplace manifest: /Users/musta/Code/projects/kern/.claude-plugin/marketplace.json

✔ Validation passed
Validating plugin manifest: /Users/musta/Code/projects/kern/.claude-plugin/plugin.json

✔ Validation passed
1..9
ok 1 clones at the pinned commit
ok 2 second run is a no-op
ok 3 missing commit exits 3 and removes the partial clone
ok 4 copy source is copied
ok 5 missing copy source exits 3
ok 6 a failing git source is not swallowed
ok 7 a failing re-run keeps the previous good clone
ok 8 a failing copy keeps the previous copy
ok 9 unknown key exits 2
ci-local: all steps passed
