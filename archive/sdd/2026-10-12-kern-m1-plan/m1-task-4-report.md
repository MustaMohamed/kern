# M1 Task 4 report

Status: DONE. Scripts and tests transcribed exactly from the brief; no deviations.

TDD: RED with both bats files (1..12, all `not ok`, scripts missing). GREEN after creating the scripts (`tests/run-bats tests/scripts/kern-dir.bats tests/scripts/kern-detect.bats`: 12 ok, 0 not ok). Full hooks + scripts bats run: 0 `not ok`.

Real-repo check (cds-app-rewrite, read-only; its git status unchanged):
base_branch main; branch.pattern {id}-{slug} (25 of 30); commit.convention ID: (24 of 30); test.full npm test; typecheck npm run type-check; lint npm run lint; build npm run build; tracker github; pr.template .github/pull_request_template.md.

shellcheck: only SC1091 info (sourced libs not followed without -x); no warnings.
Files: scripts/kern-root, scripts/kern-dir, scripts/kern-detect, tests/scripts/kern-dir.bats, tests/scripts/kern-detect.bats.

## Fix round 1
Added 5 tests first (RED: tests 6, 7, 15, 16, 17 failed), then fixed (GREEN: 17 tests, 0 failures; `shellcheck -x` clean).
- kern-dir: newline added before the exclude line when the file lacks a trailing one; work_dir `.`, `./`, `.git*`, `:*` and SUB starting with `:` exit 2 with a work_dir message.
- kern-detect: placeholder "no test specified" gives exit 3 for test.full/test.focused; more than one `"scripts"` in package.json gives exit 3 "ambiguous: more than one scripts object in package.json" for test.full, test.focused, typecheck, lint, build; test.focused npm evidence now "(path argument not verified)".
Command: tests/run-bats tests/scripts/kern-dir.bats tests/scripts/kern-detect.bats
