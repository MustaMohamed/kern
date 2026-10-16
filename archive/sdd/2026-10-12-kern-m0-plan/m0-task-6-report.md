# Task 6 report
Status: DONE. Brief code transcribed verbatim; no deviations. release.mjs does not import check-version.mjs.
RED: `node --test tests/versions.test.mjs` -> ERR_MODULE_NOT_FOUND scripts/check-version.mjs; pass 0, fail 1.
GREEN: 8 tests, pass 8, fail 0.
Real repo: `node scripts/check-version.mjs` -> `versions: agree`.
Files: scripts/check-version.mjs, scripts/release.mjs, tests/versions.test.mjs.
Concerns: none.

## Fix round 1
Added scripts/lib/is-main.mjs (realpath compare); both CLIs use isMain(import.meta.url); dropped unused `resolve` import.
Test `CLI runs when reached through a symlink` added. RED before fix: `not ok 9`, pass 8 fail 1. GREEN after: pass 9 fail 0.
`node scripts/check-version.mjs` -> `versions: agree`.
