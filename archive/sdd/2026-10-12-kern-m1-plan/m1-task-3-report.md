# M1 Task 3 report

Status: DONE. Transcribed brief exactly; no deviations.

TDD: RED `tests/run-bats tests/hooks/settings.bats` -> all 8 not ok, "hooks/lib/settings.sh: No such file or directory". GREEN after adding files (`chmod +x scripts/kern-get`): 8 ok, 0 not ok.
Full set: `tests/run-bats tests/hooks/*.bats` all ok (17 total); `node --test tests/*.test.mjs` 44 pass, 0 fail; `node scripts/lint-skills.mjs` clean.

Files: hooks/lib/settings.sh, kernel/settings.md, scripts/kern-get (executable), tests/hooks/settings.bats.

Concern (minor): `shellcheck hooks/lib/settings.sh` reports SC2016 (info) at the sed line in settings_known_keys (backticks in single quotes, intended). CI shellcheck covers only scripts/fetch-upstream and scripts/ci-local, so no CI impact; not suppressed since brief code is verbatim.

## Fix round 1
Change: `policy_for` now reads settings only for commit, push, pr, tracker, review.post; any other action prints `ask` without reading settings (floor actions cannot loosen).
Test first: added "policy_for never loosens floor actions" (merge.policy/deploy.policy auto, push.policy auto). RED: failed at `policy_for merge`. GREEN: `tests/run-bats tests/hooks/settings.bats` 9 ok, 0 not ok.
