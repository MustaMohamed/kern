# Source coverage

kern's design (section 1) promises the strongest mechanism per category from its five sources. This file holds that promise to account. Every mechanism in a source has one of four verdicts:

- **Equal or better:** kern has built or specified a mechanism at least as strong.
- **Planned:** the source is stronger today, and a named milestone ports it.
- **Gap:** the source is stronger and has a home below. A gap without a home is not allowed.
- **Rejected:** kern does not take it, for a stated goal, non-goal or decision.

The audit of 2026-10-17 re-measured 274 mechanisms against kern 0.3.0 (eee601d) and these source versions: superpowers 7.0.0, pstack 0.15.25, addy 0.6.13, pocock 1.3.1 (unchanged), caveman 4.0.1 and the unchanged local files. The per-mechanism tables, with file and line evidence, are in `docs/research/coverage-2026-10-17/`. The 2026-10-14 audit of 216 mechanisms against kern 0.2.0 is in `docs/research/coverage-2026-10-14/`, and it set gaps 1 to 34.

"Moved" counts rows whose verdict changed since the 2026-10-17 audit. A row the M2 re-audit split counts once: as Planned while any part of it is planned, otherwise as Equal or better, even with a Rejected part (AD41).

| Source | Mechanisms | Equal or better | Planned | Gap | Rejected | Moved |
|---|---|---|---|---|---|---|
| pstack 0.15.25 | 72 | 31 | 29 | 1 | 11 | 4 |
| superpowers 7.0.0 | 57 | 37 | 7 | 2 | 11 | 11 |
| addy 0.6.13 | 49 | 23 | 17 | 0 | 9 | 3 |
| pocock 1.3.1 | 37 | 14 | 16 | 0 | 7 | 1 |
| caveman 4.0.1 | 54 | 30 | 6 | 0 | 18 | 2 |
| local | 5 | 3 | 2 | 0 | 0 | 0 |

The counts are as of the M2 re-audit (2026-10-23): 21 rows moved to Equal or better, 16 from Gap and 5 from Planned, as M2b closed its gaps and built its planned rows. The three gaps left (40, 44 and 53) are homed in M3, M6 and M5, and the eight rows the re-audit found a source still beat count at their Task 17 fixes.

## Rule

1. A milestone row in section 14 names the source mechanisms it ports. A mechanism detailed only in `docs/research/merge-*.md` is not planned until a row names it.
2. Before a milestone closes, its ported mechanisms are checked against this file. A mechanism dropped from a milestone moves to another milestone or to Rejected, with the reason.
3. A new source version, or a new source, gets an audit before kern ports from it.
4. At each milestone close, the milestone's rows are re-audited, counting only built and tested work. The milestone closes with none of its rows left where a source is stronger.

## Gaps and their homes

| # | Gap | Source | Home | Size |
|---|---|---|---|---|
| 1 | PreToolUse fails closed when a hook library cannot load | caveman | 0.2.1 (shipped) | S |
| 2 | Natural-language switch phrases, with a corpus run against the real hook | caveman | 0.2.1 (shipped) | S |
| 3 | No voice reminder on scheduled prompts | caveman | 0.2.1 (shipped) | S |
| 4 | Remove old session state files | caveman | 0.2.1 (shipped) | S |
| 5 | `plan-check`: lint generated plans and specs | pstack | M2a (shipped in 0.3.0) | S |
| 6 | `wt-audit`: find worktrees left by earlier sessions | pstack | M2a (shipped in 0.3.0) | S |
| 7 | Rationalization and red-flag tables in prove-it, implement and diagnose; lint rule 9 requires them in discipline skills | superpowers, addy | M2a (shipped in 0.3.0) | S |
| 8 | floor-scan catches a lowered bar (coverage threshold, `strict` off, a lint rule off, a CI step removed or made non-blocking), with `ratchet.<metric>` keys | addy | M2a (shipped in 0.3.0) | M |
| 9 | Contract-drift lint: every token a skill reads has a producer in `docs/plans/contract.md` | addy | M2a (shipped in 0.3.0) | S |
| 10 | Adherence grader passes only when the route is read with at most one other tool call before it (the user's rule of 2026-10-18, M2b Task 16a); a multi-turn case | superpowers | M2b (shipped 0.4.0) | S |
| 11 | `references/defense-in-depth.md` for diagnose | superpowers | M2a (shipped in 0.3.0) | S |
| 12 | CI install smoke test and a macOS job | addy | M2a (shipped in 0.3.0) | S |
| 13 | On-demand behavioural eval runner and pressure tests for discipline skills | addy, superpowers | M2b (shipped 0.4.0) | M |
| 14 | unslop's main AI tells in the normal voice and in subagent returns | local | M2a (shipped in 0.3.0) | S |
| 15 | Candor line in the kernel: no is an acceptable answer | pstack | M2a (shipped in 0.3.0) | S |
| 16 | Terse rules: existing comments are payload; code in chat is the changed lines plus context | caveman | M2a (shipped in 0.3.0) | S |
| 17 | PR body with a smallest-useful-view summary and a screenshot tier | pocock | M2a (shipped in 0.3.0) | S |
| 18 | Hook git calls run with `core.fsmonitor` and `core.hooksPath` disabled | caveman | M2a (shipped in 0.3.0) | S |
| 19 | SubagentStart tests: normal voice, `kern: off`, a bad session id | caveman | M2a (shipped in 0.3.0) | S |
| 20 | Autopilot stop enforced by a Stop hook: a recorded predicate or a turn cap | pstack | M3 | M |
| 21 | Stop-time nudge when edits have no proof since the last change | pstack | M3 | S |
| 22 | `pr-state`: one merge-readiness verdict over conflicts, threads, checks and the review gate | pstack | M3 | M |
| 23 | Multi-PR delivery from a plan as a verified stack the user lands | pstack | M3 | M |
| 24 | Tree-identity check before pushing a content-preserving rewrite | pstack | M3 | S |
| 25 | decision-log moves from M6 to M3, with formula escaping | pstack | M3 | M |
| 26 | Local `rm` guard: deletes inside the worktree and scratch directories pass, others ask | kern | M3 | M |
| 27 | Principles reference for architect, refactor, implement and self-review | pstack | M5 | M |
| 28 | verify-app create and maintain modes, writing a project verification skill on an explicit yes | pstack | M5 | M |
| 29 | Race mode adds a read-only judge on a declared rubric, then grafts by hand | pstack | M5 | S |
| 30 | CLI-for-agents design reference | pstack | M5 | S |
| 31 | Observability reference for implement, plan and ship-check | addy | M5 | S |
| 32 | Redaction before project evidence enters the kern repo; lint rule 8 reads a proprietary-terms list | superpowers | M6 | S |
| 33 | Voice evals with a no-prompt arm and a concise-prompt control, fidelity checks and token stats | caveman | M6 | M |
| 34 | Repeated tool sequences across sessions as a retro signal | caveman | M6 | M |
| 35 | define has no builder check: nothing asks what a builder would still need, sorts the answers into the user's questions and kern's own calls, or lists those calls at handover | superpowers 7.0.0 | M2b (shipped 0.4.0) | S |
| 36 | define never asks which of platform, language, libraries and medium the user owns, never states its defaults as its own calls, and offers no skip of the interview | superpowers 7.0.0 | M2b (shipped 0.4.0) | S |
| 37 | define sizes the work before it understands the intent, and names the class in process words | superpowers 7.0.0 | M2b (shipped 0.4.0) | S |
| 38 | define's interview and spec have no anti-goals and no prior art | superpowers 7.0.0 | M2b (shipped 0.4.0) | S |
| 39 | plan asks for full code in each step and has no proportion check against the spec | superpowers 6.4.2 | M2b (shipped 0.4.0) | S |
| 40 | Hooks do not survive an empty or broken PATH, and the misleading "kern did not load" message hides the real cause | superpowers 7.0.0 | M3, with the M1 parser deferrals | S |
| 41 | The M2b behaviour grader keeps blank evidence instead of treating it as an invalid run | addy 0.6.13 | M2b (shipped 0.4.0) | S |
| 42 | No `task-done.bats` case covers a passing command that prints nothing | superpowers 7.0.0 | M2b (shipped 0.4.0) | S |
| 43 | plan-check reads fences by flipping on any line that starts with three backticks or tildes, so a spec quoting Markdown fails it | pstack 0.15.25 | M2b (shipped 0.4.0) | S |
| 44 | No step names the expert's method for a task, loosens an overspecified ask, or works outside define (`/sharpen`) | pstack 0.15.25 | M6, beside plain | S |
| 45 | recall chat holds the 0.15.17 ketchup text, not the 0.15.25 rules (short, checked numbers, no invented action items) | pstack 0.15.25 | M2b (shipped 0.4.0) | S |
| 46 | No dispatch passes per-subagent `effort`, and model-selection has no effort column | pstack 0.15.25 | M2b (shipped 0.4.0) | S |
| 47 | diagnose step 9 does not propose the cheap always-on signal that would have shown the cause | pstack 0.15.25 | M2b (shipped 0.4.0) | S |
| 48 | The M2b head-to-head has no pstack arm, and its pins named the old superpowers, pstack and addy. The pins moved with the 2026-10-17 audit; the arm remains | pstack 0.15.25, superpowers 7.0.0, addy 0.6.13 | M2b (shipped 0.4.0) | S |
| 49 | self-review's Standards axis has no baseline of labelled code smells when a repo documents no standards | pocock | M2b (shipped 0.4.0) | S |
| 50 | Terse mode lacks four clauses: an explicit reply-language instruction wins, quoted text never switches the language, one term per thing, a pronoun only with an obvious referent | caveman 4.0.1 | M2b (shipped 0.4.0) | S |
| 51 | A headless session (`sdk-*` entrypoint) starts in the terse voice when the user default is terse, which reaches exec-eval and M2b runs | caveman 4.0.1 | M2b (shipped 0.4.0) | S |
| 52 | define has no fast path: a task the user calls quick and clear still gets a design and a quoted approval. User decision 2026-10-17: such a task skips design and spec approval; commits, pushes and every other floor stay gated. The skills spec C1 gate and D-4's wording change with it | superpowers 7.0.0 | M2b (shipped 0.4.0) | S |
| 53 | No skill shapes a non-software idea (a talk, a business, a renovation). User decision 2026-10-17: a separate skill, not part of define, which stays software-only (D-2) | superpowers 7.0.0 | M5, with the other Define-group skills, or earlier if wanted | M |
| 54 | autopilot's own commit text and the PR body finish-branch writes do not apply `commit.attribution`, so an autopilot commit can carry the trailer G5 then denies, and a PR body can carry the Claude Code footer the default `none` forbids. Reported by the 0.3.0 eval-fix implementer; the commit skill's step 5 covers only its own path | kern | M2b (shipped 0.4.0) | S |

Gap 54 comes from kern's own 0.3.0 eval fixes, not from a source audit, so the counts table above does not count it.

Gaps 35 to 38 all edit define, whose `SKILL.md` is 6,499 bytes against a 6,500-byte cap. The new text goes into references or replaces step text, so together they are closer to M than four S items. Gap 39 meets the same cap in plan.

The goal-0 review of the M2 plan (2026-10-14) found further source mechanisms the plan ported weaker or dropped, such as define's red flags, debugging redirection signals, forensics proof rules, "where grep stops", the "Declined to judge" list, recall's source lines and caveman-style eval isolation. Its reports are in `docs/research/m2-goal0-review-2026-10-14/`, and each item is homed in M2a or M2b in the M2 plans.

## M2a rows a source still beats (2026-10-17)

Rule 4 closed M2a with none left against the sources it audited. The sources have since moved, and the re-audit found these rows where a source is stronger now. M2b closed each one in built and tested code; the task numbers are those of `docs/plans/2026-10-14-kern-m2b-plan.md`, and each gap's row is in the M2 re-audit below.

- define: gaps 35, 36, 37 and 38 (superpowers 7.0.0), and the user's gap 52: closed by Task 11 (51eb0f8), with the Task 16 fixes f9170b2 (a waiver takes the fast path; the spec review is its own step), ff764f9 (the gating reviews run in the foreground) and e3a1a6c (the `Building:` line is said right after the route is read).
- plan: gap 39 (superpowers 6.4.2): closed by Task 12 (2ed8a0d), measured by the Task 16q planning head-to-head (plan PASS).
- task-done: gap 42, a built behaviour with no test: closed by Task 14 (597afe4), which adds the `task-done.bats` case.
- plan-check: gap 43, fence parsing (pstack 0.15.25): closed by Task 14 (597afe4). Task 17a moved the reader into `scripts/lib/fence.awk`, which task-brief shares (015efe1).
- recall chat: gap 45, the ketchup rules (pstack 0.15.25): closed by Task 13 (628fd7d).
- execute-plan model selection: gap 46, subagent effort (pstack 0.15.25): closed by Task 13 (628fd7d), then fa3cba7, which names an effort in each execute-plan and parallel-work dispatch step.
- diagnose: gap 47, the always-on signal (pstack 0.15.25): closed by Task 13 (628fd7d).
- self-review: gap 49, the smell baseline (pocock code-review): closed by Task 13 (628fd7d). Task 17a P10 made a smell a `nit`, by the user's "Smells are nits" (b0a1907).

## Decided by the user (2026-10-17)

Both rows are in the superpowers table of `docs/research/coverage-2026-10-17/sp-addy.md`, which keeps the audit's proposed rejections as evidence. The user decided otherwise, and the counts above take both decisions: row 36 is gap 52, which M2b closed, and row 49 is gap 53, still a gap.

- Row 36, a quick and clear task is done at once with no design and no approval. Decision: "let a task I call quick and clear skip design and approval". Now gap 52.
- Row 49, brainstorming for any domain. Decision: a separate skill covers non-software ideas, and define stays software-only. Now gap 53.

## M2 re-audit

Re-audited at the close of M2 (release 0.4.0) against built and tested code only. Pinned by: the test or eval file that fails if the mechanism regresses.

| Mechanism | Source | Verdict | Pinned by |
|---|---|---|---|
| BV diagnose: debugging redirection signals: the user saying "stop guessing", "is that not happening?" or "will it show us...?", or sounding stuck, sends diagnose back to its loop | superpowers 7.0.0 | Equal or better | `tests/skills/diagnose.test.mjs` ("stop guessing") |
| BV self-review: where grep stops: read a called library's source at its pinned version, work out when things run, follow what a symbol search misses | pstack 0.15.25 | Equal or better | `tests/skills/self-review.test.mjs` (## Where grep stops; step 6 says to look where grep stops) |
| BV self-review: doubt theater: two or more cycles with substantive findings and none actionable means validating, not doubting; stop and tell the user | addy 0.6.13 | Equal or better | `tests/skills/self-review.test.mjs` (## Doubt theater) |
| BV diagnose: forensics proof rules: a frame with no source mapping is not yet a diagnosis; without a paired capture the finding is the strongest hypothesis; every forensics command is on G18's allowlist | pstack 0.15.25 | Equal or better | `tests/skills/diagnose.test.mjs` (## Proof rules), `tests/hooks/g18-parity.bats` |
| BV self-review: Declined to judge: the reviewer lists each behaviour it set aside as outside the spec, with the reason; under execute-plan the executor rules on each line and reports it | superpowers 7.0.0 | Equal or better | `tests/agents.test.mjs` (task-reviewer's "Declined to judge:" line), `tests/skills/self-review.test.mjs`, `tests/skills/execute-plan.test.mjs` (steps 8 and 12 rule on each Declined line as a Decision: ledger line, a finding or a question for the user; step 13 reports it) |
| P1: ask-matt router and phase boundaries: kern's router fires itself before the first tool call; kernel/context.md at a phase end | pocock 1.3.1 | Equal or better | `tests/kernel.test.mjs`, `tests/route-eval-rows.test.mjs`, `tests/adherence.test.mjs`, `evals/snapshots/adherence-routed-sonnet-5-5-2026-10-23.json` (every row case passes, row-context 3/3; multi-diagnose 0/3, a known limit) |
| P3: grilling, grill-me, loop-me: facts go to investigators, one question with a guess, numbered decision rounds with a recommended answer, a dependent question waits a round, restate | pocock 1.3.1 | Equal or better | `tests/skills/define.test.mjs` (define sections, define pins its approval rules) |
| P4: to-spec: test seams confirmed with the user, testing decisions, spec template, approval quote; a tracker post stays a draft | pocock 1.3.1 | Equal or better | `tests/skills/define.test.mjs` (define references), `tests/scripts/plan-check.bats`, `tests/hooks/g20.bats` |
| P5: to-tickets: tracer bullets, blocking edges checked in code, prefactor first, expand-contract for wide refactors | pocock 1.3.1 | Equal or better | `tests/skills/plan.test.mjs`, `tests/scripts/plan-check.bats`, `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan PASS: kern 0.73 score, 0.08 false alarms; pocock 0.63, 0.08) |
| P6: implement: test first at agreed seams, typecheck and focused tests while working, full suite at the end; no commit by default (D-4) | pocock 1.3.1 | Equal or better | `tests/skills/implement.test.mjs`, `tests/scripts/claim-probe.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-implement-test-after 3/3) |
| P7: implement-spec: frontier of ready tasks, background implementers per worktree, serial integration, final review with one fix subagent; review per task enforced by scripts | pocock 1.3.1 | Equal or better | `tests/skills/execute-plan.test.mjs`, `tests/skills/parallel-work.test.mjs`, `tests/scripts/task-done.bats`, `tests/scripts/ledger.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (workflow-execute-plan-ledger 3/3, workflow-parallel-two-modules 3/3) |
| P8: tdd: seams, mock only at boundaries, no tautological tests; probe proves fail-then-pass | pocock 1.3.1 | Equal or better | `tests/skills/implement.test.mjs` (implement references), `tests/scripts/claim-probe.bats`, `tests/scripts/task-done.bats` |
| P9: diagnosing-bugs and the hitl template: a red-capable loop first, minimise, 3 to 5 ranked hypotheses, regression test at a correct seam, the original scenario re-run | pocock 1.3.1 | Equal or better | `tests/skills/diagnose.test.mjs`, `tests/scripts/hitl-loop.bats`, `tests/scripts/loop-rate.bats`, `tests/scripts/find-polluter.bats`, `tests/scripts/claim-probe.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-diagnose-obvious-fix 2/3, pressure-diagnose-sunk-cost 3/3) |
| P10: code-review: Standards and Spec axes, spec lines quoted, a Fowler smell baseline | pocock 1.3.1 | Equal or better | `tests/skills/self-review.test.mjs` (self-review references; a smell never blocks), `tests/agents.test.mjs` (task-reviewer whole-branch) |
| P11: pr: smallest useful view, before and after with screenshots first, merge danger | pocock 1.3.1 | Equal or better | `tests/skills/finish-branch.test.mjs` (PR body template) |
| L2: unslop applied to chat replies and subagent returns | local | Equal or better | `tests/voice.test.mjs`, `tests/hooks/session-start.bats` (the Reply section carries the candor line and the AI-tell line), `tests/hooks/subagent-start.bats` (subagent returns skip preamble, praise and closing offers) |
| L3: recall: scope said back, kern's working files first, transcripts mined by read-only subagents, live state checked before a tag, one tag per thread | local | Equal or better | `tests/skills/recall.test.mjs`, `tests/scripts/recall-sessions.bats` |
| C2: two terse rules: existing comments are payload; code in chat is the changed lines plus context | caveman 4.0.1 | Equal or better | `tests/voice.test.mjs`, `tests/skills-control.test.mjs` |
| C9a: a headless session (sdk-* entrypoint) starts without the terse voice unless the user opts in | caveman 4.0.1 | Equal or better | `tests/hooks/state.bats` (default_voice), `tests/hooks/session-start.bats` (a headless session starts in the normal voice), `tests/hooks/subagent-start.bats` (a headless session's subagent) |
| C14: SubagentStart carries the mode, off does not leak, a bad session id falls back | caveman 4.0.1 | Equal or better | `tests/hooks/subagent-start.bats` |
| C18: voice evals (no-prompt arm, "Answer concisely." control, skill arm, fidelity regex, isolation, snapshot, reminder test) and benchmarks | caveman 4.0.1 | Planned: M6 | none for the voice arms (coverage gap 33, M6); the isolation half M2a built: `tests/exec-eval.test.mjs` (the isolation flags keep user settings, MCP servers and saved sessions out) |
| C20: caveman-commit | caveman 4.0.1 | Rejected: voice decision, design spec section 6.4: commits and other persisted text follow unslop, never terse | none |
| C21: caveman-review: one line per finding with location, severity, problem and fix | caveman 4.0.1 | Equal or better | `tests/agents.test.mjs` (task-reviewer verdict lines), `tests/skills/self-review.test.mjs` |
| C24: caveman-explore, cavecrew-investigator: a read-only locator; read-only enforced in code | caveman 4.0.1 | Equal or better | `tests/agents.test.mjs` (investigator ... no file writes), `tests/hooks/g18.bats`, `tests/hooks/g18-parity.bats` |
| C25: cavecrew skill, builder, reviewer | caveman 4.0.1 | Equal or better | `tests/agents.test.mjs`, `tests/scripts/wt-snap-diff.bats` (wt-diff --allow exits 4 on a path outside the task), `tests/scripts/task-done.bats` |
| C27: investigate-first, surgical-patch | caveman 4.0.1 | Equal or better | `tests/skills/diagnose.test.mjs`, `tests/skills/implement.test.mjs`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-diagnose-obvious-fix 2/3, pressure-diagnose-sunk-cost 3/3) |
| C28: lean-build | caveman 4.0.1 | Equal or better | `tests/skills/define.test.mjs`, `tests/skills/implement.test.mjs` |
| C29: verify-and-stop | caveman 4.0.1 | Equal or better | `tests/skills/prove-it.test.mjs`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (prove-it-1 3/3, prove-it-2 2/3, pressure-prove-it-deadline 3/3, pressure-prove-it-subagent 3/3) |
| C31: migration: readers and writers mapped, forward and rollback paths, expand, migrate, verify, contract, destructive steps authorized apart; the rollback path at each stage, each migrate batch safe to rerun with its partial failure shown, the old and the new path tested at each stage | caveman 4.0.1 | Equal or better | `tests/skills/define.test.mjs` (define references: the spec template's Rollout section names the rollback path, reruns and both paths per stage) |
| C33: hardened git calls (gitsafe) | caveman 4.0.1 | Equal or better | `tests/hooks/git-hardening.bats` |
| P2: Questions a command could answer get a prototype, not a question | pstack 0.15.25 | Equal or better | `tests/skills/define.test.mjs` ("Never ask the user a fact the repo can answer", "wt-new <slug> --detach"), `tests/skills/plan.test.mjs` ("gets a spike first"), `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan gate PASS; archive-invoices and scope-split grade a product question raised, not chosen) |
| P3: Evidence label on each claim; verify-this verdicts, inconclusive is a fail | pstack 0.15.25 (cursor-team-kit verify-this) | Equal or better | `tests/skills/prove-it.test.mjs` (step 7 labels, step 4 inconclusive is a fail), `tests/scripts/claim-probe.bats` (a probe that cannot decide is inconclusive, never ok), `tests/kernel.test.mjs` ("Inconclusive is not a pass."), `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (prove-it-1 3/3, prove-it-2 2/3, pressure-prove-it-deadline 3/3) |
| P4: "No is an acceptable answer" (candor) | pstack 0.15.25 | Equal or better | `tests/hooks/session-start.bats` ("the Reply section carries the candor line and the AI-tell line"), `tests/voice.test.mjs` |
| P5: You own subagent output; a fresh subagent per round | pstack 0.15.25 | Equal or better | `tests/skills/execute-plan.test.mjs` (step 9: round 2 resumes, round 3 is a fresh implementer one tier up, no fourth round), `tests/skills/prove-it.test.mjs` ("a subagent's diff is read before its test runs"), `tests/scripts/task-done.bats`, `tests/hooks/subagent-start.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-prove-it-subagent 3/3) |
| P7: check-plan lints plan structure | pstack 0.15.25 | Equal or better | `tests/scripts/plan-check.bats` (28 tests: structure, task graph, waves, Consumes after Produces, acceptance coverage, placeholders, fences) |
| P8: Multi-phase plan: per-PR proof, base-and-head regression lane, checkpoints | pstack 0.15.25 | Equal or better | `tests/skills/plan.test.mjs` ("the base-and-head regression check as plan-template.md says", the template's base named by branch), `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan gate PASS: kern 0.73, pstack arm 0.61) |
| P14: Delegation contract: brief fields, refuse to spawn on a missing field, standing orders, liveness by side effects, gap accounting | pstack 0.15.25 | Equal or better | `tests/scripts/brief-check.bats` (12 tests), `tests/skills/parallel-work.test.mjs`, `tests/hooks/subagent-start.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (workflow-parallel-two-modules 3/3) |
| P17: Session pickup, recall, weekly-review, what-did-i-get-done | pstack 0.15.25 | Equal or better | `tests/skills/recall.test.mjs`, `tests/scripts/recall-sessions.bats` (40 tests), `tests/scripts/wt-audit.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (recall-2 3/3, recall-3 3/3, recall-4 2/3; recall-1 and recall-5 are known limits) |
| P18: Cross-session worktree audit | pstack 0.15.25 | Equal or better | `tests/scripts/wt-audit.bats` (9 tests, incl. the read-only test and the unknown bucket) |
| P19: Bug fix, runtime and trace forensics, tdd | pstack 0.15.25 | Equal or better | `tests/skills/diagnose.test.mjs`, `tests/hooks/g18-parity.bats`, `tests/scripts/loop-rate.bats`, `tests/scripts/claim-probe.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-diagnose-sunk-cost 3/3, pressure-diagnose-obvious-fix 2/3) |
| P27: PR body sections; review-and-ship; new-branch-and-pr | pstack 0.15.25 (with cursor-team-kit) | Equal or better | `tests/skills/finish-branch.test.mjs` ("PR body template"), `tests/exec-eval.test.mjs`, `tests/hooks/ship-commands.bats`, `evals/snapshots/exec-2026-10-22.json` (6/6, finish-autopilot-draft and finish-pr-at-head included) |
| P30: Swarm | pstack 0.15.25 | Equal or better | `tests/skills/parallel-work.test.mjs`, `tests/scripts/brief-check.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (workflow-parallel-two-modules 3/3) |
| P32: Blast radius: 5-level proof ladder | pstack 0.15.25 | Equal or better | `tests/skills/self-review.test.mjs` (blast-radius.md: the five levels, "reported as unproven", the writer sweep, "## Where grep stops"; step 6 opens it) |
| P33: figure-it-out | pstack 0.15.25 | Equal or better | `tests/skills/define.test.mjs` (step 6 sizes after the restate), `tests/skills/plan.test.mjs`, `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan gate PASS) |
| P38: deslop | pstack 0.15.25 (cursor-team-kit) | Equal or better | `tests/scripts/floor-scan.bats` (23 tests), `tests/seeded-diffs.test.mjs` ("floor-scan and claim-check find every seeded move and no decoy") |
| P41: setup-pstack: model per role, budget | pstack 0.15.25 | Equal or better | `tests/skills/execute-plan.test.mjs` ("every dispatch passes a model and an effort": the model-selection table and the five model.<role>.effort settings rows) |
| P44: Advisor consult with a stronger model | pstack 0.15.25 (advisor) | Equal or better | `tests/skills/self-review.test.mjs` (doubt-cycle.md: "Never the claim, never your reasoning"), `tests/skills/execute-plan.test.mjs` (step 12 final review on model.final_review), `tests/agents.test.mjs` |
| P60: /in-your-own-words: play back the user's goals and the problem before work | pstack 0.15.25 | Equal or better | `tests/skills/define.test.mjs` (step 5 restates; interview.md keeps Hypothesis and confidence, Want versus should-want, Restate and confirm) |
| P65: Four principles restated as reasoning: fix at the first place the system went wrong; test the premise directly; a test fails when behaviour breaks and survives an internals change (idempotency stays with P6) | pstack 0.15.25 | Equal or better | `tests/skills/diagnose.test.mjs`, `tests/skills/implement.test.mjs` (test-design.md sections, "probe --mutate"), `tests/scripts/claim-probe.bats` (the three --mutate tests) |
| P68: Claude Code install path: a generated tree, a name-mapping adapter, a CI check that the tree is current, manifest versions that agree | pstack 0.15.25 | Equal or better | `tests/ci-local.test.mjs` (the install job runs on every push; the checks job's commands, claude plugin validate --strict among them), `tests/versions.test.mjs`, `.github/workflows/ci.yml` |
| P69: Loosening a gate needs a verifier's proof and a countersign; a disabled or soft-failed check always comes out | pstack 0.15.25 | Equal or better | `tests/skills/self-review.test.mjs` (the author never clears its own bar-lowered hit: it is reverted, or waits for the user's typed yes; under autopilot it is reverted and parked), `tests/skills/finish-branch.test.mjs` (the PR body's Merge danger names each kept one), `tests/scripts/floor-scan.bats` (the bar-lowered class) |
| SP2: 1% rule, announce, one todo per item | superpowers 7.0.0 | Equal or better | `tests/kernel.test.mjs` (on a match the route is read before any other tool call; each new task reads its route again), `tests/adherence.test.mjs`, `tests/hooks/prompt-submit.bats` (the routing reminder on every later prompt), `evals/snapshots/adherence-routed-sonnet-5-5-2026-10-23.json` (the 18 single-task cases pass; multi-diagnose 0 of 3, a known limit) |
| SP3: Rationalization and red-flag tables, pressure-tested | superpowers 7.0.0 | Equal or better | `tests/lint-rules.test.mjs` (rule 9: a discipline skill needs a Red flags table of 2 to 6 rows), `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (6 of 7 pressure cases pass) |
| SP4: Hard gate before building; spike stays throwaway | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (the standing gate on every path and the detached spike worktree), `tests/hooks/g20.bats` (27 tests), `tests/hooks/g20-probes.bats` (55 tests) |
| SP8: writing-plans with a plan reviewer | superpowers 7.0.0 | Equal or better | `tests/skills/plan.test.mjs` (one fresh general-purpose subagent on model.reviewer; only the user's word skips the plan review; the review runs in the foreground), `tests/scripts/plan-check.bats`, `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan PASS) |
| SP9: SDD controller, three prompts, model per role (the executor ruling on Declined to judge lines is the BV Declined to judge row) | superpowers 7.0.0 | Equal or better | `tests/skills/execute-plan.test.mjs`, `tests/agents.test.mjs`, `tests/scripts/no-commit-review.bats`, `tests/scripts/ledger.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (workflow-execute-plan-ledger 3 of 3) |
| SP11: task-brief, review package, sdd-workspace | superpowers 7.0.0 | Equal or better | `tests/scripts/task-brief.bats`, `tests/scripts/brief-check.bats`, `tests/scripts/wt-snap-diff.bats`, `tests/scripts/kern-dir.bats` |
| SP12: Ledger written only when the test passes | superpowers 7.0.0 | Equal or better | `tests/scripts/task-done.bats` (a failing command is not recorded; no review, an older tree or an edited worktree is refused; --probe refuses a task whose test passes without the change) |
| SP13: TDD iron law, writing-good-tests | superpowers 7.0.0 | Equal or better | `tests/skills/implement.test.mjs`, `tests/scripts/claim-probe.bats` (the three mutate tests), `tests/scripts/task-done.bats` (the probe tests), `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-implement-test-after 3 of 3) |
| SP15: 4-phase debugging, 3-fix stop, tracing, find-polluter with test | superpowers 7.0.0 | Equal or better | `tests/skills/diagnose.test.mjs`, `tests/scripts/find-polluter.bats`, `tests/scripts/loop-rate.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-diagnose-obvious-fix 2 of 3, pressure-diagnose-sunk-cost 3 of 3) |
| SP16: Defense-in-depth layers | superpowers 7.0.0 | Equal or better | `tests/skills/diagnose.test.mjs` (diagnose references: defense-in-depth.md with its Prove each layer section) |
| SP17: Pressure scenarios; RED/GREEN/PRESSURE runs | superpowers 7.0.0 | Equal or better | `tests/behave.test.mjs`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (6 of 7 pressure cases pass) |
| SP18: verification-before-completion | superpowers 7.0.0 | Equal or better | `tests/skills/prove-it.test.mjs`, `tests/scripts/claim-probe.bats`, `tests/scripts/claim-check.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (prove-it-1, prove-it-2, pressure-prove-it-deadline and pressure-prove-it-subagent pass) |
| SP19: Requesting review with a Declined to judge list, through self-review (the executor ruling on each Declined to judge line is the BV Declined to judge row) | superpowers 7.0.0 | Equal or better | `tests/skills/self-review.test.mjs` (the Declined to judge list in step 9 and in the report), `tests/agents.test.mjs` (task-reviewer's Declined to judge line), `tests/seeded-diffs.test.mjs` |
| SP21: Worktrees: native, .worktrees/, consent, baseline tests | superpowers 7.0.0 | Equal or better | `tests/scripts/wt-new.bats` (28 tests, wt-check among them), `tests/skills/implement.test.mjs` (implement proposes wt-new) |
| SP22: Finish menu, discard only on a typed word | superpowers 7.0.0 | Equal or better | `tests/skills/finish-branch.test.mjs` (only the typed word discard deletes work; the discard reference), `tests/hooks/ship-commands.bats`, `tests/exec-eval.test.mjs`, `evals/snapshots/exec-2026-10-22.json` (finish-menu-first and the other five cases pass) |
| SP24: Parallel dispatch per failure domain | superpowers 7.0.0 | Equal or better | `tests/skills/parallel-work.test.mjs`, `tests/scripts/brief-check.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (workflow-parallel-two-modules 3 of 3) |
| SP30: Explicit-request test: fails when any non-todo tool runs before the skill; multi-turn | superpowers 7.0.0 | Equal or better | `tests/adherence.test.mjs` (one project call may come before the route and a second fails the run; a multi-turn case needs the route read again for the second task) |
| SP31: End-to-end SDD run with a real model | superpowers 7.0.0 | Equal or better | `tests/behave.test.mjs`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (workflow-execute-plan-ledger 3 of 3) |
| SP36: Opening check: a quick, clear task is done at once, with no design and no approval | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (the fast path is step 1; an explicit approval waiver takes it; commits, pushes and every other ask stay gated), `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (workflow-define-fast-path-stored-data 2 of 3, the stored-data carve-out) |
| SP38: Draw out the want before proposing: an open question, menus only when stuck, "just guess" gets a concrete proposal | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (interview.md pins: the user gave up on the interview, two rounds without rising confidence) |
| SP40: Offer recon of the project, the user's files or the web; the user decides | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (never ask the user a fact the repo can answer; offer to look on the web, the user decides) |
| SP41: Think wide privately; show the comparison only when it helps | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (structure only: the line itself has no assertion) |
| SP43: Size the work after understanding it, in plain words; the user can override; step up if it grows; several projects one at a time | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (step 6 sizes, after the restate, in plain words, and the user may override; the map is approved before any module spec) |
| SP44: Builder check: a fresh subagent reads the design as its builder; the agent sorts its questions into answered, minor and the user's; handover lists the calls made | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (the spec reviewer is its own step and an approved design does not skip it; the spec-review.md and handover.md pins) |
| SP45: Written design: intent, goals, non-goals, anti-goals, constraints, the how they decided, what is left to the builder | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (define references: the spec-template sections, Anti-goals, Prior art, kern's call, what is left to the builder), `tests/scripts/plan-check.bats` (a spec needs its sections) |
| SP47: Visual companion offered whenever seeing helps: screens, layouts, flows, options that look different, diagrams | superpowers 7.0.0 | Planned: M4 | none yet: design spec section 14, row M4 (visual: page server, auto thresholds). define step 7 offers a page only for three or more options (skills/define/SKILL.md:21) |
| SP50: Plan steps record decisions, not code; a proportion check against the spec | superpowers 6.4.2 | Equal or better | `tests/skills/plan.test.mjs` (test-first steps that record decisions, not code; self-review for proportion), `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan PASS; rename-small kern 0.97, superpowers 0.57) |
| SP53: task-done records a task whose passing test prints nothing, with a test | superpowers 7.0.0 | Equal or better | `tests/scripts/task-done.bats` (a passing command that prints nothing is recorded, with an empty last field) |
| SP54: Skill body free of `$1` and `$ARGUMENTS`, which Claude Code replaces with argument words | superpowers 7.0.0 | Equal or better | `tests/skills-control.test.mjs` (no argument placeholder in any skills/*/SKILL.md body, fenced blocks included) |
| SP55: Debugging example reports only whether a secret is set | superpowers 7.0.0 | Equal or better | `tests/skills/diagnose.test.mjs` (root-cause-tracing.md shows a secret only as set or unset, never its value; diagnose says Redact secrets) |
| AD2: interview-me, spec-driven, /spec stops the turn | addy 0.6.13 | Equal or better | `tests/skills/define.test.mjs`, `tests/hooks/g20.bats` (an approval needs a whole-line quote of the user's yes) |
| AD4: planning-and-task-breakdown, /plan | addy 0.6.13 | Equal or better | `tests/skills/plan.test.mjs`, `tests/scripts/plan-check.bats`, `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan category PASS) |
| AD6: incremental-implementation, NOTICED BUT NOT TOUCHING, /build auto | addy 0.6.13 | Equal or better | `tests/skills/implement.test.mjs` (the NOTICED BUT NOT TOUCHING list), `tests/scripts/wt-snap-diff.bats` (an out-of-Files path exits 4), `tests/skills/execute-plan.test.mjs`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-implement-test-after 3/3, workflow-execute-plan-ledger 3/3) |
| AD8: TDD skill: red first, the prove-it pattern for a bug | addy 0.6.13 | Equal or better | `tests/skills/implement.test.mjs`, `tests/scripts/task-done.bats` (--probe), `tests/scripts/claim-probe.bats` (--mutate), `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-implement-test-after 3/3) |
| AD8: test-engineer agent, testing-patterns and stack references, /test | addy 0.6.13 | Planned: M5 | design spec section 9, agents line (test-engineer, M5); section 14, M5 row (specialists and stack references); skills spec X22 |
| AD9: debugging-and-error-recovery | addy 0.6.13 | Equal or better | `tests/skills/diagnose.test.mjs`, `tests/scripts/loop-rate.bats`, `tests/scripts/find-polluter.bats`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (pressure-diagnose-sunk-cost 3/3, pressure-diagnose-obvious-fix 2/3) |
| AD11: five-axis review (correctness, readability, architecture), change sizing, /review | addy 0.6.13 | Equal or better | `tests/skills/self-review.test.mjs`, `tests/seeded-diffs.test.mjs`, `tests/skills/finish-branch.test.mjs` (size gate), `evals/snapshots/exec-2026-10-22.json` (finish-split-nine-files) |
| AD11: security axis and the code-reviewer agent | addy 0.6.13 | Planned: M3 | design spec section 14, M3 row (pr-review lanes, security references); section 10.1, lanes B and D; section 9, agents line |
| AD11: performance axis | addy 0.6.13 | Planned: M5 | design spec section 9 (perf skill and perf-auditor agent, M5); section 14, M5 row (specialists) |
| AD11: dependency-upgrade discipline: before adding a dependency, check whether the stack covers it, its size, upkeep, known vulnerabilities and licence; an upgrade is reviewed like code: its changelog read, one dependency per change, the suite green before and after | addy 0.6.13 | Equal or better | `tests/skills/self-review.test.mjs` (blast-radius.md checks a manifest or lockfile change) |
| AD12: doubt pass in a fresh context | addy 0.6.13 | Equal or better | `tests/skills/self-review.test.mjs` ("self-review references": the doubt-cycle.md pins, Doubt theater included) |
| AD24: git-workflow-and-versioning: atomic commits, messages, branches, pre-commit hygiene, change summaries | addy 0.6.13 | Equal or better | `tests/skills/commit.test.mjs`, `tests/skills/finish-branch.test.mjs`, `tests/hooks/g01-git.bats`, `tests/hooks/g05-g06-commit.bats`, `tests/hooks/ship-commands.bats`, `evals/snapshots/exec-2026-10-22.json` (6 of 6 cases) |
| AD24: release and versioning: semantic versioning for anything with consumers, an annotated tag as the version's source of truth, a changelog written for humans | addy 0.6.13 | Equal or better | `tests/skills/finish-branch.test.mjs` (references/release.md: the project's own tooling first, the bump the user confirms, the changelog, git tag -a, the tag push asked) |
| AD28: floor guard with reference test | addy 0.6.13 | Equal or better | `tests/scripts/floor-scan.bats`, `tests/seeded-diffs.test.mjs` |
| AD29: bar-moved checks and ratchet (gap 8) | addy 0.6.13 | Equal or better | `tests/scripts/floor-scan.bats` (the bar-lowered and ratchet tests), `tests/seeded-diffs.test.mjs` (s08 to s10) |
| AD34: artifact-path pipeline validator (gap 9) | addy 0.6.13 | Equal or better | `tests/lint-rules.test.mjs` (the rule 16 tests) |
| AD38: an eval run with and without the plugin (the head-to-head no-plugin control arm) | addy 0.6.13 | Equal or better | `tests/h2h.test.mjs` ("the arms are kern, the three upstream plugins and a no-plugin control"), `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan PASS, control arm included) |
| AD38: claude plugin eval cases and the manifest's experimental.evals | addy 0.6.13 | Planned: M6 | design spec section 9 (skill-eval, M6); section 14, M6 row |
| AD40: CI install smoke test (gap 12) | addy 0.6.13 | Equal or better | `.github/workflows/ci.yml` (install job), `tests/ci-local.test.mjs` (the install job exists and runs on every push) |
| AD41: CI macOS leg: bats under /bin/bash 3.2 and BSD awk (gap 12) | addy 0.6.13 | Equal or better | `.github/workflows/ci.yml` (macos job), `tests/ci-local.test.mjs` ("the macOS job runs only ci-local commands, with the bats files in parallel as on Ubuntu") |
| AD41: the macOS leg runs on every push and PR | addy 0.6.13 | Rejected: user decision 2026-10-22 (Task 17a, P15): macOS runs on demand and weekly, Ubuntu on every push | `tests/ci-local.test.mjs` pins the weekly and on-demand triggers |
| AD47: the stays-quiet half: a question, an opt-out or kern off loads no route | addy 0.6.13 | Equal or better | `tests/adherence.test.mjs`, `evals/snapshots/adherence-routed-sonnet-5-5-2026-10-23.json` (five negative cases, 3/3 each) |
| AD47: the fires half: pasted code reaches a test-first skill with no mention of tests; a pasted bug routes to diagnose, and tests for existing code route to implement | addy 0.6.13 | Equal or better | `tests/skills/implement.test.mjs` (tests on existing code: the RED is probe --mutate of the covered line), `evals/cases/row-implement.json`, `evals/cases/row-diagnose.json` (pasted-code positives), `evals/snapshots/adherence-routed-sonnet-5-5-2026-10-23.json` (pasted-diagnose and tests-implement 3/3, each reading its route first) |
| AD48: review severity labels aligned across skill and agent; review runs in the main session | addy 0.6.13 | Equal or better | `tests/skills/self-review.test.mjs` (the review.taxonomy default; the spec lane's Critical and Important count), `tests/hooks/g02-g04-gh.bats` (G3 taxonomy label) |
| SP30: adherence grader passes only when the route is read with at most one other tool call before it, the user's rule of 2026-10-18; a multi-turn case (gap 10) | superpowers 7.0.0 | Equal or better | `tests/adherence.test.mjs` (one project call may come before the route, a second fails the run; a multi-turn case needs the route read again for the second task), `evals/snapshots/adherence-routed-sonnet-5-5-2026-10-23.json` (18/19), `evals/snapshots/adherence-routed-haiku-5-5-2026-10-23.json` (19/19, multi-diagnose 3/3) |
| SP17, AD37: on-demand behavioural eval runner and pressure tests for discipline skills (gap 13) | addy 0.6.13, superpowers 7.0.0 | Equal or better | `tests/behave.test.mjs` (every discipline skill has a pressure case with at least two pressures), `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (6 of 7 pressure cases pass), `tests/behave-fixtures.test.mjs` |
| SP44 (N1): define builder check: the spec reviewer reads the spec as its builder; define sorts its questions into answered, minor and the user's, and lists its own calls at handover (gap 35) | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (the spec reviewer is its own step, and an approved design does not skip it; define pins its approval rules: spec-review.md and handover.md) |
| SP37, SP46 (N2): define asks which build choices the user owns, states its defaults as its own calls, and offers once to skip the interview (gap 36) | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (interview.md pins: skip offer, build choices, a default they never heard) |
| SP43 (N3): define sizes the work after the restate, in plain words, and the user may override (gap 37) | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (step 6 sizes, after the restate) |
| SP39 (N4): anti-goals and prior art in define's restate and spec (gap 38) | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (interview and spec-template pins) |
| SP50 (N5): plan steps record decisions, not code, with a proportion check against the spec, measured by the planning head-to-head (gap 39) | superpowers 6.4.2 | Equal or better | `tests/skills/plan.test.mjs`, `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan PASS; rename-small kern 0.97, superpowers 0.57) |
| AD46 (N7): the behaviour grader treats a verdict with blank evidence as an invalid run, said apart from bad JSON (gap 41) | addy 0.6.13 | Equal or better | `tests/behave.test.mjs` (a verdict with blank evidence is an invalid run, said apart from bad JSON) |
| SP53 (N8): a task-done.bats case covers a passing command that prints nothing (gap 42) | superpowers 7.0.0 | Equal or better | `tests/scripts/task-done.bats` (a passing command that prints nothing is recorded, with an empty last field) |
| PS59: plan-check reads code fences as CommonMark does, so a spec quoting Markdown passes (gap 43) | pstack 0.15.25 | Equal or better | `tests/scripts/plan-check.bats` (three fence tests and the unclosed-fence error), `tests/scripts/task-brief.bats` (shares scripts/lib/fence.awk) |
| PS62: recall chat holds the 0.15.25 ketchup rules: under 150 words, checked numbers, no invented action items; an autopilot execute-plan report ends with it (gap 45) | pstack 0.15.25 | Equal or better | `tests/skills/recall.test.mjs` (chat reference keeps the ketchup rules), `tests/skills/execute-plan.test.mjs`, `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (recall-3, recall chat, 3/3) |
| PS64: every dispatch passes its role's effort, and model-selection has an effort column (gap 46) | pstack 0.15.25 | Equal or better | `tests/skills/execute-plan.test.mjs` (every dispatch passes a model and an effort), `tests/skills/parallel-work.test.mjs` |
| PS66: diagnose step 9 proposes the cheap always-on signal that would have shown the cause (gap 47) | pstack 0.15.25 | Equal or better | `tests/skills/diagnose.test.mjs` |
| PS process: the head-to-head has a pstack arm, and its pins name superpowers 7.0.0, pstack 0.15.25 and addy 0.6.13 (gap 48) | pstack 0.15.25, superpowers 7.0.0, addy 0.6.13 | Equal or better | `tests/h2h.test.mjs` (the arms are kern, the three upstream plugins and a no-plugin control), `evals/snapshots/h2h-sonnet-5-5-plan-2026-10-23-16q.json` (plan PASS; arms at bb92a77, 182f2ce, 49dd158) |
| P10 (G1): self-review's Standards axis has a baseline of labelled code smells when a repo documents no standards (gap 49) | pocock 1.3.1 | Equal or better | `tests/skills/self-review.test.mjs` (self-review references; a smell is a nit) |
| C1a (G2): terse clauses: an explicit reply-language instruction wins, quoted text never switches the language, one term per thing, a pronoun only with an obvious referent (gap 50) | caveman 4.0.1 | Equal or better | `tests/voice.test.mjs` (terse keeps the reply language and its terms fixed) |
| C9a (G3): a headless session (sdk-* entrypoint) starts in the normal voice unless mode.voice.headless opts in (gap 51) | caveman 4.0.1 | Equal or better | `tests/hooks/state.bats` (default_voice), `tests/hooks/session-start.bats` (three headless tests), `tests/hooks/subagent-start.bats` (a headless session's subagent) |
| SP36: define fast path: a task the user calls quick and clear, or an explicit approval waiver, skips design and spec approval; commits, pushes and every other floor stay gated (gap 52) | superpowers 7.0.0 | Equal or better | `tests/skills/define.test.mjs` (an explicit approval waiver takes the fast path), `evals/snapshots/behave-sonnet-5-5-2026-10-22.json` (workflow-define-fast-path-stored-data 2/3) |
| 0.3.0 eval-fix report: autopilot's own commit text and finish-branch's PR body follow commit.attribution (gap 54) | kern | Equal or better | `tests/skills-control.test.mjs`, `tests/skills/finish-branch.test.mjs`, `tests/exec-eval.test.mjs`, `tests/hooks/g02-g04-gh.bats`, `tests/hooks/g05-g06-commit.bats`, `evals/snapshots/exec-2026-10-22.json` (6/6, finish-autopilot-draft included) |

Row ids are those of the 2026-10-17 audit in `docs/research/coverage-2026-10-17/`: P is pocock, or pstack where the source says pstack (also written PS), SP superpowers, AD addy, L local, C caveman, N and G that audit's new gaps, and BV the goal-0 review's `docs/research/m2-goal0-review-2026-10-14/build-verify.md`. The five drops come first and the M2b gaps last; a gap row repeats the ids of the audit rows it closed.

The list command printed 117 candidate rows. These five are not M2 work and keep their 2026-10-17 verdicts:

- pocock P16, research (a background agent, primary sources, a cited Markdown file): its counterpart is explain, an M5 skill (design spec section 9 and the section 14 M5 row). The M2a investigator answers repo questions only and writes no file. Planned (M5).
- caveman C35, host version drift probe: its counterpart is the design spec's section 11.1 tier 2 check, run nightly in M6. M2 only records `claude --version` in each snapshot and compares nothing. Planned (M6). Rule 1: the section 14 M6 row names the version comparison (added at the M2 close).
- pstack P6, principles corpus (24 leaves): kern has none built; its home is M5 (gap 27). The three 0.15.25 leaves that M2 skills already match are judged in P65. Planned (M5).
- pstack P25, eval blinding: its counterpart is skill-eval (M6). M2b built the blinding only for kern's own head-to-head and pilot runs (`scripts/lib/h2h.mjs`). The user-facing eval playbook stays Planned (M6).
- pstack P31, review lanes (interrogate, thermos, dyl-review): its counterpart is the pr-review lanes (M3). self-review, the M2 part, reviews one's own diff and is judged in P32 and P44. Planned (M3).

## Accepted limits

- Spending and permission changes outside the Claude Code settings files stay kernel text ("ask first"). No command reliably signals spending.
- Windows: hooks are bash and POSIX tools (section 8.4 rule 1) and kern is personal (D-2). Revisit if a Windows machine is added. The 2026-10-17 audit adds superpowers' `run-hook.cmd` and caveman's hook stdin watchdog, config encodings (BOM, UTF-16LE) and hidden console windows to this limit.

## Rejected

| Reason | Mechanisms |
|---|---|
| Goal 3, D1, D2 or the merge floor | Merge prep and landing in pstack's autopilot (the user merges), caveman Auto, warm cache, modules hub, proxy 4.0 additions and Blocks telemetry, commits by default, merge-locally, auto-merge and push loops, PRs opened ready, tracker and chat writes without asking, continual-learning writing AGENTS.md, Slack automations, scheduled chief-of-staff runs, setup-pre-commit, network-calling cache hooks, a statusline nudge that writes settings, telemetry, `/constraints`, wizard secret writes |
| Non-goals: other tools, non-Claude models, team distribution | Antigravity manifest, Hermes skill descriptions, caveman's `dist/caveman.skill`, a check that no text tells anyone to npx the unscoped `caveman` package (kern ships no npm package), Cursor, Codex, Gemini and Copilot manifests and builds; cross-vendor reviewers; issue workflows; third-party integrations; caveman cloud, proxy and MCP servers |
| Goal 4, standing cost | Extra compatibility agents, MCP servers, automate-me, teaching |
| D3, D5, D6, D10 | simplify-ignore, "rulings, not stalls", safe fallbacks, "delete means delete" |
| Voice decisions (section 6.2, 6.4, D-5) | Switch phrases matched anywhere in the prompt (a phrase switches only alone on the first line), ultracave, megacave, caveman-commit, caveman-compress |
| Skill format (skills spec A7: numbered steps) | Graphviz flowcharts, persuasion wording |
