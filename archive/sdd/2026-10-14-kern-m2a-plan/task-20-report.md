# Task 20 report: plan skill

Status: DONE. SHA 0a11e95 (base 6836d6b, branch main).
RED: 4 failing tests, all `skills/plan/SKILL.md exists` (brief says 3; I added a 4th pinning test).
GREEN: plan.test.mjs 4/4; full suite 113/113; `lint: clean`; route-eval passed; plugin validate passed.
Samples and replay live under the session scratchpad: t20sample (2-task plan), plan-replay.bats (4/4), t20mut (mutations).
plan-check on the sample: exit 0. Same sample with a non-leading Acceptance: exit 1 with 2 problems.
task-brief sample task 1: extracts `## Global Constraints` and `### Task 1`.
G20 replay: approval Edit with `execution:` passes with the quote in the prompt; denied for an unrecorded quote, under autopilot, and for a draft touched after the yes.

Deviations from the brief:
1. plan-review.md output line is `<task number>: problem. fix.`, not `Task N: problem. fix.`; lint rule 16 reads a backticked `Task N:` as a ledger line and has no contract row. No exemption added.
2. Test needle `Round 1 only` capitalised to match the reviewer file.
3. SKILL.md additions to the brief text (6129 of 6500 bytes): kern-get/kern-detect exit 3 asks (tracker, verify commands), gh failure asks, kern-dir plans path with exit 2 asks, wt-new exit 2 asks, absolute `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/...` paths, approval wording per rulings 1 and 2 (typed reply for yes plus step/inline/delegate, never AskUserQuestion), untouched after yes then one Edit with `execution:`, plan-check rerun, autopilot rule copied from define (parked plan keeps `status: draft`, `parked:` lines in the reply).
4. task-template Acceptance line states the leading-list rule and that a value with no leading list is an error.
5. Added 4th test pinning the load-bearing lines. Mutation check on a scratch copy: removing each of the AskUserQuestion rule, untouched-after-yes, plan-check rerun, autopilot signal line, `write the plan with status: draft`, gh and exit-3 asks, and both Acceptance lines made the test fail.

Concerns:
- A parked plan has no section for parked questions; they appear only in the reply (the plan template has no Open questions heading and I did not add one).
- `kernel/routes.md` does not exist yet, so the map row's routed row text is unchecked against it.

## Fix round 1
Commit: M2: plan writes before it checks, routes issue criteria to define and keeps parked questions.
- Step 11 now writes the plan (kern-dir plans, status: draft) then runs plan-check, self-review and the round-1 reviewer; step 12 is the summary and approval stop.
- Step 1: issue acceptance criteria alone route to define (bounded path records an approved short spec); search falls back to slug or title words; `tracker.first` in Inputs.
- plan-template.md has `## Open questions` (spike branch or SHA plus evidence; parked lines). Autopilot parks every stop, including the step 4 spike and the step 7 scope question.
- Steps 7 and 12: vertical, demoable tasks; contract task blocked by every migrate batch; scope over threshold stops to confirm or split; change request and non-yes replies ask again.
- SKILL.md is 6500 of 6500 bytes (tightened wording, one word changed: "type consistency" to "type mismatches"). Cap unchanged.
- Tests: 5 tests, 114/114 full suite; every new pin shown failing on a scratch copy when removed (including a swapped write/check order).

## Fix round 2
Step 7 autopilot default is the split, never a plan over `scope_threshold`; a step 1 stop under autopilot gives the `parked:` line in the reply and creates no plan file. Both pinned and shown failing on removal. Moved: step 10 regression/checkpoint clause, step 11 plan-check coverage list, step 8 checklists clause to plan-template.md.
