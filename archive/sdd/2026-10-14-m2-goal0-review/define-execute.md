# Goal-0 review: define, plan, execute-plan, parallel-work (part 1)

All four BELOW. Gates still prose where code could enforce; no head-to-head measure.

| Category | Strongest source | Verdict | Biggest gap |
|---|---|---|---|
| define | SP brainstorming HARD-GATE + red flags (brainstorming:38-108); pocock grilling (grilling:6-30) | BELOW | Approval prose only; red-flag table dropped; spec has no constraints section for plan to copy |
| plan | SP writing-plans, pstack check-plan.mjs, addy planning | BELOW | No planning head-to-head eval; file-overlap ordering and Interfaces consistency not checked in code |
| execute-plan | SP SDD + scripts | BELOW | task-done writes review=approved without a review; wave tasks skip review and completion |
| parallel-work | pstack orchestrate, swarm; SP dispatching-parallel-agents | BELOW (small) | Drain status words do not match the implementer contract; brief completeness prose |
| Tasks 1-4, 8 | SP scripts and prompts | MEETS; EXCEEDS on commit-free snapshots and forks | Ledger identity check dropped |

define (Task 13):
- Red flags dropped: SP brainstorming:98-108, addy spec-driven:225-246. Task 13 SKILL.md (plan:2852-2885) has none; gap 7 covers only prove-it, implement, diagnose. Fix: `## Red flags` table (<=6 rows); define in lint rule 9's discipline list; raise the 6,500-byte cap by ~1 KB.
- Approval only claimed (plan:2863-2864). Fix (new small task): UserPromptSubmit records prompt hashes in session state (G16-protected); PreToolUse on Write/Edit under WORK/specs or WORK/plans setting status: approved denies unless the approved: quote is verbatim from a user prompt received after the draft and not on the non-yes list; always denies under autopilot. Tests: invented quote denied, "sounds good" denied, real "yes" passes.
- Contract hole: plan step 9 copies Global Constraints from the spec (plan:3086), but the spec template headings (plan:2821) have none. addy Boundaries Always/Ask first/Never (spec-driven:138-142). Fix: `## Constraints` in the spec template and its test.
- Test seams weaker (plan:2947); pocock to-spec:15-17 highest existing seam, fewest seams, check with user. Fix: one template line.
- Real lead: G18 enforces read-only investigators in code. Size fine (6.5 KB + 4 refs, routed).
- Measurement: hand-ticked define.acceptance.md + one behavioural row case.

plan (Task 14):
- No head-to-head; goal 0 names planning. Proposed evals/h2h/plan/: one fixture repo, 3 approved specs with seeded traps (two tasks in one migrations dir; a persisted field with a second writer in another module; an interface consumed before produced; an acceptance criterion with no test seam; a slice over scope_threshold; a 2-file change that should get no plan). Arms: (truncated)

# part 2: plan (rest), execute-plan

plan (Task 14), continued:
- Head-to-head: arms kern plan vs SP writing-plans, same pinned model, other plugin disabled, on the gap-13 runner. Scoring: deterministic first (plan-check + a grep per trap); LLM grader only for semantic traps, arm labels hidden (pstack poteto-mode/playbooks/eval.md:5-25); count traps caught and false alarms (invented constraints, spurious ordering). Task 23 acceptance: kern >= SP traps, no more false alarms; ask before running (F21). define cases on the same runner: bounded-sounding ask with no existing flow must be classed architectural; "whatever you think" must not approve; a repo-answerable fact must not be asked (pocock grilling:28).
- Ordering and Interfaces prose only (plan:3084, 3088; execute-plan 3465-3466). Fix: plan-check also checks Blocked-by edges for tasks sharing a Files path or shared_services entry; each Consumes appears in an earlier Produces; every acceptance number is covered; no cycles; writes overlap pairs and waves as TSV that execute-plan steps 3-4 read (SDD:170-178 into code).
- Prototype before writing (pstack multi-phase-plan:6); step 4 (plan:3081) has no route for a question reading cannot settle. Fix: route to a define spike in a wt-new worktree.
- Prefactor and wide refactors (pocock to-tickets:23, :40); plan:3084 applies expand/contract only to stored shapes. Fix: one clause in step 7 and the task template.
- Red flags optional for plan (addy planning-and-task-breakdown:219-236).
- Lead only claimed until plan-check ships the graph checks.

execute-plan (Task 16; scripts Task 4; agents Task 8):
- Review stamp unconditional: task-done appends review=approved (plan:1119; contract plan:907); review line appended by hand (plan:3519); TREE never re-snapshotted, so "a verdict holds for that tree-after id only" (plan:3460) only claimed. SP task-done records test result and last output line (executing-plans/scripts/task-done:48-50). Fix in Task 4: `task-review LEDGER N TREE ROUND SPEC QUALITY` writes the review line; task-done takes WT, re-snapshots with wt-snap, exits 2 writing nothing unless the snapshot equals TREE and task N's last review line has tree=TREE spec=compliant quality=approved. Tests: no review refused; older-tree review refused; worktree edited after review refused. Keep SP's last test-output line as evidence.
- Wave path has no controls (plan:3466, 3476): no per-task review (step 8) or task-done (step 10); wave tasks never get "Task N: complete" and resume re-dispatches them. SP forbids parallel implementers (SDD:282). Fix: each wave task runs steps 6-10 in its own fork before step 11 applies it; acceptance: a 2-task wave yields 2 review packages and 2 complete lines.
- Deferred minor findings lost (ledger format plan:3510-3525; step 13 plan:3478). SDD:361-364 records "Task N: minor (deferred): ..."; SDD:455 feeds the final reviewer. Fix: add the line and feed step 12.
- Final fix pass (plan:3477) unowned, no re-review. SDD:459-470: one fix subagent, one scoped re-review. Fix: copy.
- Ledger identity (plan:3464): slug collisions. SDD:141-147, sdd-workspace:6-9. Fix in Task 4: `ledger-open PLAN DIR` creates the header or exits 2 when it names another plan; exits 2 without status: approved and approved: (step 1 gate in code for all modes); --summary greps Decision, parked and minor lines (SDD:473-482).
- Out-of-Files edits prose (plan:3473). Fix: `wt-diff --allow <Files paths>` exits 4 and lists extras.
- Main-checkout check prose (plan:3463, 3478). Optional: fold into ledger-open record and --summary compare.
- Batching (SDD:223-232): model table assumes it (plan:3548), no step says when. Fix: one line in step 6.
- Rationalization table (SDD:489-500): add one; execute-plan in lint rule 9's discipline list.
- Real leads: commit-free per-task review via wt-snap/wt-diff tested in no-commit-review.bats; per-task review in inline mode too.
- Size 9.5 KB, largest skill, close to a union. Moving steps 3, 4, the out-of-Files check and 13 into scripts shrinks and enforces them.
- Measurement: no-commit-review.bats runs no model; SP real-model SDD run is M6 (row 31). Fix: one seeded head-to-head vs SP SDD: a 3-task plan whose worker edits a file outside Files and writes a test that passes before the change; score faults caught and false stops.

# part 3: parallel-work, Tasks 1-4 and 8, goals 3/4, missing list

parallel-work (Task 15) BELOW (small):
- Status words: drain expects PASS/ISSUES/BLOCKED (plan:3295, pstack swarm:34); kern:implementer returns DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT (plan:1728, 1896). Fix: map per worker type in step 6, with an acceptance test line.
- Brief completeness prose (plan:3292; pstack orchestrate:56). Fix: `brief-check FILE` in Task 4: 9 labels GOAL..STANDING present and non-empty, VERIFY starts with wt-check; step 3 runs it before each spawn.
- Silent death: no handling (plan:3293). SDD:235-245, pstack orchestrate:95-96. Fix: on TIMEBOX expiry, read-only check (report file? wt-snap changed?), record a gap, never resume.
- Pilot unit first (pstack orchestrate:62) optional at parallel.max 3.
- Race judge and graft homed at M5 (gap 29).
- Real leads: forks carry uncommitted, deleted and binary state; wt-check in code; wt-apply exits 3 on conflict, destination unchanged.
- Measurement: checklist only. Fix: head-to-head vs SP dispatching-parallel-agents: 3 disjoint tasks + 1 overlapping on db/migrations; score serialization, conflicts caught at integration, green final suite, no shared-tree writes.
- Size 5 KB + 2 refs, fine.

Tasks 1-4, 8: MEETS; EXCEEDS on commit-free snapshots and forks (fresh origin/<base>, info/exclude, tree snapshots with untracked/deleted/binary, tested with spaces). Task 4 weaker than SP in three places (fixes under execute-plan): task-done stamps an unseen review (plan:1119); complete line drops SP's last test-output line (task-done:48-50); no ledger identity (sdd-workspace:6-9, 58-79). Task 4 needs task-review, ledger-open, brief-check. Task 8: out-of-Files rule prose (plan:1884) -> wt-diff --allow; SP implementer-prompt:68-69 DONE_WITH_CONCERNS on file growth, optional line; task-reviewer has no shell (real read-only).

Goals 3/4: no conflicts. Path skills no standing cost; commits only under autopilot (plan:3475); network reads only; teardown and --force ask; adherence and head-to-head runs ask first (F21); red-flag tables raise per-skill byte caps only.

Missing from the pending update pass:
1 planning head-to-head (seeded specs, kern plan vs SP writing-plans, deterministic + blind grader, acceptance in Task 23); seeded cases for define, execute-plan, parallel-work on the gap-13 runner.
2 task-review script; task-done requires a matching approved review line and re-snapshots.
3 wave tasks reviewed and closed (steps 6-10) in their forks before integration.
4 ledger-open: identity, approval gate in code, --summary.
5 plan-check graph checks + TSV for execute-plan steps 3-4.
6 approval quotes checked against real user prompts (hook + session state), denied under autopilot.
7 spec template ## Constraints (always / ask first / never), copied into Global Constraints.
8 red-flag tables for define (SP brainstorming:98-108) and execute-plan (SDD:489-500), extending gap 7 and lint rule 9.
9 deferred-minor ledger line fed to the final review; final fix pass with an owner and a scoped re-review.
10 parallel-work status mapping, brief-check, TIMEBOX liveness rule.
11 wt-diff --allow.
12 prose: spike route for unknowns; prefactor and wide-refactor slicing; highest-seam rule; batching line in step 6.
