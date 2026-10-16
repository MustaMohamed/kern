# Task 21 report: parallel-work

Status: DONE_WITH_CONCERNS. Commit 7c04891 (base 48bc39d), only the brief's paths.

RED: Step 1 test failed 4 of 5 with `skills/parallel-work/SKILL.md exists` (the filled-brief test passes, brief-check already exists).
GREEN: parallel-work 5/5; full suite 119/119; `lint: clean`; route-eval passed; `claude plugin validate .` passed.
Mutation: on a scratch copy, removing each of 31 pinned strings failed the test (31/31, 0 survivors).
brief-check: unfilled template prints 8 `placeholder:` lines (all but FORBIDDEN) plus `VERIFY must start with the wt-check entry check`; filled sample prints `brief-check: ok`.
Dry walk (scratch repo with bare origin): wt-new, wt-check ok, wt-snap, kern-dir tmp/reviews, wt-diff --out --allow (exit 0; exit 4 on an outside path; exit 3 on empty), wt-apply `applied` then exit 3 on re-apply, wt-fork carried the state, wt-audit buckets, main branch unchanged. All matched the skill's text.

## Deviations
1. Brief test expected only 8 placeholder lines. brief-check also prints the VERIFY line, since a placeholder cannot start with wt-check. Test expects both.
2. SKILL.md is 6229 bytes against the brief's 5000 cap; test cap is 6400. The drain mapping, exit handling, `--allow`, unknown rule and autopilot did not fit in 5000. Not dropped.
3. Investigator mapping: its contract has no NEEDS_CONTEXT. Mapped to its real return: BLOCKED is no answer or a named command it needs run.
4. Patch path: `--out F` writes `F` and `F.patch`, so apply `<worker>.diff.patch`, not `<package>.patch`.
5. Outputs: brief said `WORK/ledgers/parallel-<slug>/`; step 6 says the caller's ledger `reviews/`, else `kern-dir reviews`. Outputs now says `WORK/reviews/`.
6. `--force` at teardown applies to any writer worktree with integrated work (wt-new ones are dirty too, audit shows `uncommitted`), not only forks.
7. Added: `--allow` per SCOPE path in step 6 (exit 4 stops); exit handling for each script; readers get a dispatch prompt, no brief (brief-check requires wt-check); brief file written under `kern-dir tmp`; base ref per creator; `test.full` via kern-get/kern-detect.
8. Test pinned beyond brief: drain mapping, VERIFY at wt-check, brief-check before spawn, `--out` and patch path, `unknown` never torn down, each stop and autopilot line.

## Concerns
- Lint rule 9 does not list parallel-work as discipline, so no Red flags section was added (none required).
- wt-new/wt-fork print a `worktree.setup is unset` line on stderr when unset; harmless.
- The `Stops` list names step 3 for a worktree that will not build; brief-check failure itself is a fix-and-rerun, not a stop.

## Fix round 1
- Teardown rules moved to references/worktrees.md (SKILL.md step 8 points there). `--force` needs the recorded integrated tree (wt-diff line 2, kept in the table's evidence column) to equal `wt-snap <wt>`; ignored files named from `git status --ignored --porcelain`; differing or missing tree means no `--force`; the integration worktree and fork sources are never proposed; wt-audit is filtered to this run's paths; G1 asks on `--force` and autopilot denies it.
- Directory scope: step 6 and the template's SCOPE line say a directory ends in `/`, a prefix in `*`. The template note is an indented continuation, because brief-check's placeholder text for SCOPE is fixed.
- Minor 3 to 9 applied: absolute root in worker input, silent reader re-asked once then BLOCKED, no `Status:` line is BLOCKED, empty or "none" could-not-trace is PASS, autopilot parks only the failing unit, unnamed script exits stop that unit, and the three pins added.
- Sizes: SKILL.md 6390/6400, worktrees.md 2005/2200, template 1532/1800. Caps unchanged. To fit, I shortened prose (Stops list reasons, an Outputs phrase, small wording); no behaviour dropped.
- Mutation: 54 pins each fail when removed (0 survivors). Suite 120/120, lint clean, route-eval passed, validate passed, no long dashes or curly quotes.
- Dry walk: `--allow src/` accepts `src/s.txt`, `--allow src` reports it outside. An integrated worker's `wt-snap` equals the recorded tree (force allowed). A worker that wrote after its package differs (no force).

## Fix round 2
`--force` is now one list of five preconditions in references/worktrees.md (applied printed, tree equals wt-snap, recorded path and not integration or fork source, ignored files named, user yes), with plain remove or keep-and-report otherwise. SKILL.md step 6 records the tree only after `applied`; step 7 and 8 reference it. The merged-PR line is pinned. Mutations (remove each condition, the fallback, plain to --force on the merged line) all fail the test. Dry walk: a conflicted worker's wt-diff tree equals its wt-snap, but it has no recorded tree, so no --force. SKILL.md 6396/6400, worktrees.md 2179/2200.
