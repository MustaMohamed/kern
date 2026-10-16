DONE_WITH_CONCERNS

Commit: a9ee546 (main, base 84f79ed)

## Bytes (cap)
- skills/self-review/SKILL.md: 6391 (6400 lead ruling; plan 5500)
- references/blast-radius.md: 1872 (2600)
- references/doubt-cycle.md: 2153 (2400)
- references/claim-checks.md: 1590 (1700)

## Tests
Failing first (SKILL.md absent): `# pass 0 / # fail 5`, each `skills/self-review/SKILL.md exists` (or the references/acceptance file).
After: `node --test tests/skills/self-review.test.mjs` pass 5, fail 0.

## Gates
- `node --test 'tests/**/*.test.mjs'`: tests 132, pass 132, fail 0
- `node scripts/lint-skills.mjs`: lint: clean
- `node scripts/route-eval.mjs`: route-eval: passed (rank-1 rate 66%, baseline 0%)
- `claude plugin validate .`: Validation passed

## Mutations
73 removal mutations on a scratch copy (every needle pinned by assertContains, all occurrences removed): 73 caught, 0 missed. Three pins occur twice in their file (`Declined to judge`, `unproven`, `actionable`), so removing one occurrence passes; the other formerly doubled pins were made unique.

## Deviations from the plan's draft
1. Test: SKILL.md cap 6400; added pins for exits, order, dispatches, autopilot wording, rebase commands; a text-hygiene test (no long dashes or curly quotes).
2. Step 1 now resolves `<base>`, handles failed fetch (ask; autopilot parks, goes on with last fetched ref, report says "base not refreshed", `ready` withheld), failed merge-base (stop), wt-diff exit 2 and 3, and names `<package>` / `<package>.patch` / changed paths as wt-diff's output.
3. Step 2: kern-get/kern-detect resolution, floor-scan/claim-check exits, red verify or test counts as a failed check.
4. Step 3: also skips when the Skill call errors.
5. Step 4: spec location, tracker/PR-body spec saved under `kern-dir tmp`, absolute paths, the task-reviewer inputs mapped (Constraints as Global Constraints, no report), explicit line that the spec's acceptance lines stand in for the plan's acceptance lines and Review Focus, model named.
6. Step 5: reads review.rules files not in context (the draft said "already in context", untrue for CONTRIBUTING.md).
7. Step 6: stated trigger (callers outside the directory, or gating on a property).
8. Step 7: names the sources of `<package>.patch` (step 1) and `<test>` (step 2); exits 1, 3, 2 each have an action.
9. Step 8: `kern:investigator` on `model.reviewer`, one question, artifact and contract paths as scope, never the claim. Details (saving files, 40-line budget, reconcile) live in doubt-cycle.md to fit the cap.
10. Step 9: verdicts tested in order split, fix first, rebase first, ready, each with a checkable trigger. `rebase first`: `git -C <wt> rev-parse origin/<base>` differs from the merge base and `git -C <wt> diff --name-only <merge-base> origin/<base>` names a path the package also changed. No `$(`. `split` is defined from scope_threshold and earlier-round fixes.
11. Inputs table: dropped the Use column and the `base_branch`, `lessons`, `scope_threshold` rows to fit the cap; those keys and defaults are named in steps 1, 9 and 10 (scope_threshold's "4 files" default is no longer stated in the skill).
12. Stops: execute-plan wording for autopilot signals and typed approvals; parks use the `parked:` format with a default per stop; a missing base, failed merge-base, wt-diff exit 2 or 3 end the run.
13. Acceptance file: four extra checks (failed fetch, rebase first, empty diff, inconclusive probe).
14. Reference caps all kept. No rule cut for the cap; text was tightened and the reconcile detail moved into the reference.

## Concerns
- SKILL.md is 9 bytes under your 6400 ruling; the spec's cap row should become 6,400.
- The `rebase first` and `split` triggers are my definitions; confirm.

## NOTICED BUT NOT TOUCHING
- agents/investigator.md description names only define, plan and diagnose; self-review dispatches it for the doubt cycle (your ruling). Not edited.
- The kernel routed row "Review requested on your own diff, no PR yet" was not checked against kernel text or route-eval fixtures; map row copies the brief.
- task-reviewer `whole-branch` mode text still says "plan's acceptance lines and Review Focus"; the dispatch compensates.
- `probe --mutate` inverts the first operator on a line; the skill says one conditional per line only via the probe header, not restated here.

## Fix round 1

Commit: 60153a9. Rulings I1 to I5 and M1 to M9 applied.

Bytes: SKILL.md 6995 (cap 7000); blast-radius 1927/2600; doubt-cycle 2308/2400; claim-checks 1684/1700; new rounds.md 1173/1400 (my cap).
Mutations: 107 removal mutations (every assertContains needle, all occurrences removed): 107 caught, 0 missed, no needle left occurring twice.
Gates: suite 132 pass 0 fail; lint clean; route-eval passed; plugin validate passed.

Deviation: the package-naming and round mechanics (slug, reviews dir, N, previous tree, since package) did not fit 7,000, so they live in a new `references/rounds.md`, which SKILL.md step 1 names. The verdict and every trigger stay in SKILL.md. Drop the file if you prefer a larger SKILL.md cap (about 7,700 would hold it inline).

Checked: a package's first line ends `..<12-hex tree>` and `git rev-parse <that>^{tree}` resolves it; `wt-diff <wt> <that tree> --out ...-since.diff` produces the since package.

Applied: I1 scope_threshold row, kern-get exit 3 takes the table default; I2 probe exit 2 or 3 and unrun checks give fix first, lane skips do not change the verdict; I3 failed fetch asks or parks, then rebase first with "base not refreshed"; no origin remote uses local base; I4 split via numbered packages and a since package; I5 evaluation order and the rebase need reported when fix first wins; M1 to M5, M7, M8 in SKILL.md and references; M9 pins for each definition and the order sentence. Acceptance file updated.
