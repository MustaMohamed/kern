# Replacing superpowers 6.4.1: skill-by-skill map to pstack, pocock and addy

Read-only research. Nothing from the candidate repos was installed or executed.

Path prefixes used in citations:

- `sp:` = `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/`
- `ps:` = `scratchpad/repos/cursor/plugins/pstack/`
- `mp:` = `scratchpad/repos/pocock/skills/`
- `ad:` = `scratchpad/repos/addy/agent-skills/`

Ratings:

- **FULL**: same discipline, equal or stronger.
- **PARTIAL**: exists, but weaker, narrower or a different philosophy. The note says what is lost.
- **NONE**: no skill whose purpose matches. Incidental fragments are named in the note.

Project-rule conflicts come from the prior audits (`audit-pstack.md`, `audit-pocock.md`, `audit-addy.md`) and are flagged with ⚠.

---

## 1. Matrix

| superpowers skill | pstack | pocock | addy |
|---|---|---|---|
| brainstorming | **PARTIAL** `architect`, `prototype` playbook. Design-first exists, but the human approval gate is gone: "No human checkpoint" (`ps:skills/architect/SKILL.md:43`). ⚠ anti-asking (`poteto-mode:20`). | **PARTIAL** `grilling` / `grill-with-docs` + `to-spec`. Interview is stronger (frontier batches, recommended answers), but there is no approaches/trade-offs step, and `to-spec` publishes without a user review of the spec. | **FULL** `interview-me` + `spec-driven-development`. Gated SPECIFY→PLAN→TASKS→IMPLEMENT with "STOP YOUR TURN IMMEDIATELY". Small changes get no approval gate. |
| writing-plans | **PARTIAL** `multi-phase-plan` playbook. Rigorous, with a plan validator, but per-PR rather than bite-sized TDD steps, with no exact code. ⚠ ready PRs, 10 swarm lanes per PR. | **PARTIAL** `to-spec` + `to-tickets`. Tracer-bullet tickets with blocking edges and an approval loop, but "Do NOT include specific file paths or code snippets". Linear is unsupported. | **PARTIAL** `planning-and-task-breakdown`. Acceptance criteria and verification per task, but no no-placeholder rule, no interfaces block, no spec-coverage self-review. ⚠ creates Linear items. |
| executing-plans | **PARTIAL** `autonomous-run` playbook / `figure-it-out` Phase C. Has a predicate loop and a decision trail, but no final fresh reviewer. ⚠ "Do not park reversible work for the human". | **PARTIAL** `implement`, 6 lines. TDD at seams, full suite at the end, then `code-review`. No ledger. ⚠ "Commit your work to the current branch". The review can see an empty diff. | **PARTIAL** `incremental-implementation` + `/build auto`. Single approval, then per-task RED→GREEN→commit. It stops on ambiguity and risk. No final fresh-context review and no rulings list. ⚠ commits per task. |
| subagent-driven-development | **PARTIAL** Feature step 4 + `autopilot-full` / `orchestrate`. Delegated implementers, and a swarm verdict from non-authors. No per-task spec+quality review and no 5-round breaker. ⚠ owners merge their own PRs. | **PARTIAL** `implement-spec`. Implementer subagents in worktrees, one `code-review` at the end. No per-task review, no stop condition, parallel collisions. ⚠ PR/ticket actions. | **NONE**. No per-task implementer dispatch exists. `orchestration-patterns.md` covers review fan-out only. |
| dispatching-parallel-agents | **FULL** `swarm` + `principle-separate-before-serializing-shared-state`. Needs a rewrite of the Cursor `Task` cloud parameters. | **PARTIAL**. Embedded only: the `implement-spec` frontier and `code-review`'s two subagents. No independence check, and its docs admit collisions. | **PARTIAL** `references/orchestration-patterns.md` pattern 3. A reference, not a skill, with review personas as its only example. |
| test-driven-development | **PARTIAL** `tdd`. Bug fixes only, opt-in ("Use only when the user explicitly asks…"), and "prefer no new test over a bad test". | **PARTIAL** `tdd`. Seams are confirmed with the user first. There is no explicit run-and-watch-it-fail step, and refactor is excluded from the loop. | **FULL** `test-driven-development`. RED must fail, Prove-It pattern, red flags. Minor gap: no delete-code-written-first law. ⚠ DevTools MCP section. |
| systematic-debugging | **FULL** `bug-fix` playbook + `principle-fix-root-causes` + `principle-attack-the-premise`. Two failed fixes trigger a premise census. ⚠ "instrument until it fires" against the V1 read-only rule. | **FULL** `diagnosing-bugs`. Needs a red-capable loop, minimises the repro, ranks 3–5 falsifiable hypotheses, and has a cleanup checklist. ⚠ hand-rolled Playwright. | **PARTIAL** `debugging-and-error-recovery`. No "3+ failed fixes → question architecture" escalation. ⚠ safe fallbacks, `git bisect` in the shared tree. |
| verification-before-completion | **FULL** `principle-prove-it-works` + the evidence-label rule + "Inconclusive is not a pass" + verdicts from a non-author. Reachable only through the router. | **NONE**. Fragments only: the `diagnosing-bugs` Phase 6 checklist and the `pr` Evidence section. | **PARTIAL** using-agent-skills behaviour #6 + `references/definition-of-done.md`. A checklist, not a claim gate, and no rule to distrust agent success reports. |
| requesting-code-review | **FULL** `interrogate` + the Shipping rule that a verdict must come from an agent that did not write the code. ⚠ The multi-model premise collapses to Opus/Sonnet. Fan-out runs every round. | **FULL** `code-review`. Standards and Spec axes in parallel subagents, quoting the spec line per finding. ⚠ Bare-name collision with the built-in `code-review`. Report format ≠ inline Bug/Suggestion/Nit. | **FULL** `code-review-and-quality` + `/review` + `code-reviewer` agent + `doubt-driven-development`, which passes "ARTIFACT + CONTRACT only". ⚠ three severity taxonomies, `/ship` fan-out. |
| receiving-code-review | **PARTIAL** `babysit` step 8 + `references/bugbot-triage.md`. Verifies each claim against the code with fix / dismiss / ask. Scoped to bot and PR threads. No clarify-all-first rule and no YAGNI grep. | **NONE**. | **NONE**. Fragment only: the generic "Push Back When Warranted" (`using-agent-skills:75-84`). |
| using-git-worktrees | **PARTIAL** `opening-a-pr` Worktree paragraph + `worktree-cleanup`. No isolation detection, no native-tool preference, no gitignore check, no baseline tests. ⚠ `reset --hard`, `--force` / `rm -rf`. | **PARTIAL** `implement-spec` steps 4 and 9. Implementers verify their base and reset onto it. Its docs say tests that read gitignored fixtures skip silently in worktrees. | **PARTIAL** `git-workflow-and-versioning` worktree snippet. ⚠ "delete the worktree — nothing is lost". |
| finishing-a-development-branch | **PARTIAL** `opening-a-pr` / `babysit` / `shipping`. "Babysitting never authorizes merging" is good, but every playbook ends by opening a ready PR, with no options menu. ⚠ Conventional Commits titles, never draft. | **NONE**. `pr` only shapes the PR body. `implement` commits with no integration choice. | **PARTIAL** `/ship` + `shipping-and-launch`. A GO/NO-GO verdict with a rollback plan, but no integration-options menu and no confirmation before a discard. ⚠ auto-merge in `ci-cd`. |
| writing-skills | **PARTIAL** `authoring-a-skill` + `eval` playbook (blinded judge) + `correct`. Testing is optional ("Skip if subjective"), with no RED-baseline-first law. Depends on Cursor's `create-skill`. | **PARTIAL** `writing-for-agents`. A style reference with no test loop; its docs say "There is no automated eval". | **PARTIAL** `docs/skill-anatomy.md` + the eval harness (`CONTRIBUTING.md:44`). The test tooling is strong, but it is contributor tooling for addy's own repo, not an invocable skill. |
| using-superpowers | **PARTIAL** `poteto-mode`. A real router with verbatim playbook steps, but `disable-model-invocation: true` and Cursor `mode: true`. No precedence clause. ⚠ "Just do it" autonomy. | **PARTIAL** `ask-matt`. A human-facing map that cannot fire skills (`disable-model-invocation: true`). No enforcement. | **PARTIAL** `using-agent-skills`. A model-invocable flowchart with an opt-in hook that is not wired. "Check for an applicable skill" is far weaker than the 1% rule. No precedence clause. |
| diagnosing-superpowers | **PARTIAL** `show-me-your-work` (audits the decision log against the transcript) + `reflect`. Purpose is self-audit and skill edits, not post-mortem of a failed session. Cursor transcript paths. | **PARTIAL** `retro`. Reads session logs and suggests environment changes. No path:line evidence rule. ⚠ "CLAUDE.md… incredibly sparingly". | **NONE**. No retro or learning loop. |

**Counts**

| Candidate | FULL | PARTIAL | NONE |
|---|---|---|---|
| pstack | 4 | 11 | 0 |
| pocock | 2 | 10 | 3 |
| addy | 3 | 9 | 3 |

pstack has no NONE, but most of its PARTIALs are partial because of conflicts. Its equivalents remove the human gate rather than weaken it.

---

## 2. Per-skill detail with citations

### brainstorming

superpowers holds a hard gate. Before any implementation action, the human must approve the design (`sp:skills/brainstorming/SKILL.md:38-56`). The gate is scaled across spike, bounded and architectural paths (`:58-88`), and even a bounded change gets an in-chat design and an explicit yes (`:122-127`).

- **pstack, PARTIAL.**
  - `architect` grounds the problem, sketches via `arena` and requires two candidates (`ps:skills/architect/SKILL.md:21-37`). But it says "Default: proceed directly to implementation with the synthesized design. No human checkpoint." (`:43`).
  - The router reclassifies most questions as "not the human's to answer" (`ps:skills/poteto-mode/SKILL.md:20`).
  - `principle-never-block-on-the-human` reinforces this.
  - `prototype` (`playbooks/prototype.md:3-12`) replaces asking with experiments.
  - Lost: the approval gate and intent discovery. ⚠ This conflicts with the Escalate tier.
- **pocock, PARTIAL.**
  - `grilling` asks the whole frontier per round with a recommended answer (`mp:skills/productivity/grilling/SKILL.md:8`). Facts are the agent's job (`:28`). "Do not act on it until the user confirms" (`:30`).
  - `to-spec` does "NOT interview" (`mp:skills/engineering/to-spec/SKILL.md:7`). It checks only the test seams with the user (`:17`), then publishes and labels `ready-for-agent` (`:19`).
  - Lost: proposing 2–3 approaches, user review of the written spec, and one-question-at-a-time. Batching is a deliberate philosophy difference.
- **addy, FULL.**
  - `spec-driven-development` has a human review at every phase (`ad:skills/spec-driven-development/SKILL.md:22-32`) and "STOP YOUR TURN IMMEDIATELY" after the spec (`:173-174`).
  - `interview-me` uses one question at a time with a confidence number (`ad:skills/interview-me/SKILL.md:40-53`).
  - Gap: the skill is "NOT to use" for small unambiguous changes (`spec-driven…:20`). The only light-path control is router behaviour #1, "Correct me now or I'll proceed" (`ad:skills/using-agent-skills/SKILL.md:49-58`), which is weaker than superpowers' bounded-path approval.
  - ⚠ `SPEC.md` and `tasks/` at the repo root are not gitignored here.

### writing-plans

superpowers requires exact files, Interfaces blocks, full code per step, "No Placeholders", a self-review against the spec, and a Review Focus section (`sp:skills/writing-plans/SKILL.md:94-165`).

- **pstack, PARTIAL.**
  - `multi-phase-plan` is a per-PR evidence checklist validated by `scripts/check-plan.mjs` (`ps:skills/poteto-mode/playbooks/multi-phase-plan.md:6-10`).
  - It hands back and stops: "Execution starts on the operator's explicit go" (`:11`).
  - It skips the plan when the change is 1–2 files (`:5`), and it contains no exact code.
  - ⚠ It mandates 10 live swarm lanes per PR and "Open the PR ready, never draft" (`:13`, `:57`).
- **pocock, PARTIAL.**
  - `to-tickets` builds vertical slices with blocking edges and iterates "until the user approves the breakdown" (`mp:skills/engineering/to-tickets/SKILL.md:27-56`).
  - It rules out file paths and code (`:105`; `to-spec:55`), which is the opposite of superpowers.
  - ⚠ Linear is out of scope by policy.
- **addy, PARTIAL.**
  - The task template has acceptance criteria, verification, files and scope (`ad:skills/planning-and-task-breakdown/SKILL.md:79-103`), plus checkpoints (`:106`).
  - It never overwrites another session's plan (`:153`).
  - ⚠ "create one tracker item per task" when CLAUDE.md names Linear (`:162`).

### executing-plans

superpowers: a ledger that survives compaction, TDD per step, a completion contract, one fresh whole-branch reviewer, a "Rulings I made" list, and four stop conditions (`sp:skills/executing-plans/SKILL.md:27-43,115-142,207-232,234-298`).

- **pstack, PARTIAL.** `autonomous-run` sets a checkable predicate (`playbooks/autonomous-run.md:5`), checkpoints each iteration via `show-me-your-work` (`:10`), and "never relax the predicate" (`:11`). ⚠ "Do not park reversible work for the human or use `AskQuestion`… Put out-of-band fixes in their own PR" (`:9`).
- **pocock, PARTIAL.**
  - `mp:skills/engineering/implement/SKILL.md:11-17` is the whole skill.
  - Its own docs record that `code-review` runs before the commit and can see nothing (`mp:docs/engineering/implement.md:63-65`, per the prior audit).
  - ⚠ `:17` commits to the current branch, which is `main` in the shared tree.
- **addy, PARTIAL.**
  - `/build auto` requires a spec, checks for a clean baseline, has a single approval, then runs per-task RED→GREEN→regression→build→commit (`ad:.claude/commands/build.md:31-35`).
  - It stops on ambiguity and risk (`:36-40`) and resumes from the task file (`:41`). That stop rule fits the CDS gate better than superpowers' "rulings, not stalls".
  - Lost: the final fresh-context review and the rulings list.
  - ⚠ one commit per task (`:35`).

### subagent-driven-development

superpowers dispatches a fresh implementer per task, never in parallel (`sp:skills/subagent-driven-development/SKILL.md:282`). Two verdicts are required, spec compliance and quality (`:310-314`). The fix loop runs up to 5 rounds and escalates to a stronger model at rounds 4–5 (`:372-386`). The breaker adjudicates with a ledgered ruling (`:411-429`), and a final review runs on the most capable model (`:445-469`).

- **pstack, PARTIAL.**
  - Delegated implementers: Feature step 4 (`playbooks/feature.md:12`).
  - "You own every subagent's work. Review the diff" (`poteto-mode/SKILL.md:97`), and fresh subagents per fix round (`:99`).
  - `autopilot-full` swarm-verifies every round before merge (`playbooks/autopilot-full.md:8`), and the patch-id rule applies (`playbooks/shipping.md:9`).
  - Lost: the per-task spec-vs-quality split and the round cap.
  - ⚠ Owners "run in true parallel" (`autopilot-full.md:7`) and "The owner merges" (`:9`).
- **pocock, PARTIAL.**
  - Implementers each work in a worktree, a merger subagent integrates, and one `code-review` runs at the end (`mp:skills/engineering/implement-spec/SKILL.md:27-36`).
  - Its docs record no stop condition and roughly four hours for five tickets (`docs/engineering/implement-spec.md:48`), and parallel collisions (`:56`).
  - ⚠ Draft PR / mark ready / close tickets (`:25`, `:38`).
- **addy, NONE.**
  - `references/orchestration-patterns.md` endorses direct invocation, review fan-out, sequential slash commands and research isolation (`:9-113`). No pattern dispatches an implementer per task.
  - `doubt-driven-development` reviews decisions, not task diffs.

### dispatching-parallel-agents

- **pstack, FULL.**
  - `swarm` frames, fans out, aggregates and reports, with PASS / ISSUES / BLOCKED evidence and a rule that a gap is not a pass (`ps:skills/swarm/SKILL.md:20-46`).
  - The shared-state principle and the Feature throughput checkpoint (`feature.md:7-11`) cover the independence check.
  - Rewrite needed: `environment: "cloud"`, `cloud_base_branch` and the Grok defaults (`:25-32`).
- **pocock, PARTIAL.** "Implementer subagents should be run in the background where possible for maximum concurrency" (`implement-spec:17`). There is no independence test; the docs concede collisions.
- **addy, PARTIAL.** Pattern 3 has a "Use when… genuinely independent" checklist (`ad:references/orchestration-patterns.md:48-74`) and a parallel-spawn note (`:168`). It is a reference doc, and its only worked example is the `/ship` personas.

### test-driven-development

superpowers' Iron Law: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST". Code written first is deleted (`sp:…/test-driven-development/SKILL.md:31-45`). Verify RED is mandatory and must fail for the right reason (`:113-128`), and the run covers the full suite, not one file (`:185-193`).

- **pstack, PARTIAL.** Scoped to bug fixes and explicitly opt-in (`ps:skills/tdd/SKILL.md:3`). "skip adding a new test" when impractical (`:11`), and "Prefer no new test over a bad test" (`:26`). `principle-test-behavior-not-implementation` adds the "would still pass if every import returned `undefined`" check (`poteto-mode:69`).
- **pocock, PARTIAL.** "Red before green" (`mp:skills/engineering/tdd/SKILL.md:36`). Seams must be confirmed with the user before any test (`:22`). "Refactoring is not part of the loop" (`:38`). There is no explicit run-and-watch-it-fail step.
- **addy, FULL.** "Write the test first. It must fail." (`ad:skills/test-driven-development/SKILL.md:51`). Prove-It for bugs (`:96-117`). Red flags include "Tests that pass on the first run" (`:375-385`). ⚠ The DevTools MCP section (`:312-341`) conflicts with the `cds-session.mjs` harness.

### systematic-debugging

superpowers: no fix without root-cause investigation, four phases, one hypothesis at a time, and after 3 failed fixes stop and discuss architecture with the human (`sp:…/systematic-debugging/SKILL.md:16-20,191-212`).

- **pstack, FULL.**
  - Runtime evidence for every shipped line, and hypotheses refuted by evidence get reverted (`playbooks/bug-fix.md:5`). Binary-search the cause (`:8`).
  - Two failed fixes on one premise trigger a premise write-down and census (`ps:skills/principle-attack-the-premise/SKILL.md:9-21`).
  - ⚠ "synthesize the trigger… or instrument until it fires" (`bug-fix.md:7`) runs against the V1 read-only rule.
- **pocock, FULL.**
  - Phase 1 is complete only with a red-capable command already run (`mp:skills/engineering/diagnosing-bugs/SKILL.md:59-66`).
  - Minimise until every element is load-bearing (`:78-86`). 3–5 falsifiable ranked hypotheses, shown to the user (`:90-98`). Tagged debug logs and a cleanup checklist (`:110,132-138`).
  - It has no explicit 3-failed-fixes rule. The missing-seam finding (`:120`) partly substitutes.
  - ⚠ Playwright (`:29`).
- **addy, PARTIAL.**
  - Stop-the-line (`ad:skills/debugging-and-error-recovery/SKILL.md:21-34`), reproduce → localize → reduce → fix → guard, and untrusted error output (`:272-279`).
  - Missing: the architecture escalation after repeated failures.
  - ⚠ `git bisect` in the shared tree (`:101-108`) and "safe fallbacks" (`:214-238`).

### verification-before-completion

superpowers: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE" (`sp:…/verification-before-completion/SKILL.md:16-20`). The gate function is `:24-36`. "Agent completed → VCS diff shows changes" (`:47`). Wording that implies success is a red flag (`:52-59`).

- **pstack, FULL.**
  - `principle-prove-it-works` (`ps:skills/principle-prove-it-works/SKILL.md:9-20`).
  - "Every claim carries its evidence or its label… Measured, inferred, or guess" (`poteto-mode:111`).
  - "'Inconclusive' or wrong-surface is not a pass" (`bug-fix.md:10`). "CI green is not a verdict" (`shipping.md:7`).
  - The leaf carries `disable-model-invocation: true`, so it fires only when the router reads it.
- **pocock, NONE.** Fragments: the `diagnosing-bugs` Phase 6 "Required before declaring done" (`:132-138`) and `pr` Evidence (`mp:skills/engineering/pr/SKILL.md:158-164`). Neither is a general claim gate.
- **addy, PARTIAL.** "'Seems right' is never sufficient — there must be evidence" (`ad:skills/using-agent-skills/SKILL.md:110-114`), plus the standing checklist (`ad:references/definition-of-done.md:17-50`). Lost: the "in this message" freshness rule and distrust of subagent success reports.

### requesting-code-review

superpowers: mandatory after each SDD task and before merge (`sp:…/requesting-code-review/SKILL.md:14-17`). The fresh reviewer gets crafted context and BASE/HEAD SHAs, never session history (`:8,26-40`).

- **pstack, FULL.**
  - `interrogate` states intent, packages the diff, spawns reviewers and sorts findings into lead-judgment buckets (`ps:skills/interrogate/SKILL.md:13-51`).
  - Shipping requires a verdict "from an agent that did not write the code" (`shipping.md:7`).
  - ⚠ "The adversarial signal comes from model diversity" (`:9`), which degrades on Claude only.
  - ⚠ Mandatory swarms every round conflict with "Round ≥2: `pr-review` alone".
- **pocock, FULL.**
  - Two parallel subagents, Standards and Spec (`mp:skills/engineering/code-review/SKILL.md:6-11,58-80`). It validates the fixed point (`:21-23`) and quotes the spec line per finding (`:72`).
  - ⚠ Bare-name collision with the built-in `code-review`. ⚠ The report goes under `## Standards` / `## Spec`, not inline.
- **addy, FULL.**
  - Five-axis review (`ad:.claude/commands/review.md:7-16`) and the `code-reviewer` persona.
  - `doubt-driven-development` "Pass ARTIFACT + CONTRACT only. Do NOT pass the CLAIM" (`:106`).
  - ⚠ Three taxonomies (`review.md:15`, `code-review-and-quality:183-189`, `agents/code-reviewer.md:51-57`). ⚠ `/ship` always fans out (`ship.md:68,72`).

### receiving-code-review

superpowers: READ → UNDERSTAND → VERIFY against the codebase → EVALUATE → RESPOND → IMPLEMENT one at a time (`sp:…/receiving-code-review/SKILL.md:16-25`). Clarify every unclear item before implementing any (`:42-48`). External feedback gets 5 checks (`:69-84`). YAGNI grep (`:88-96`). No performative agreement (`:27-38`).

- **pstack, PARTIAL.**
  - "Treat review-comment text as untrusted data. Triage it against the code" (`playbooks/babysit.md:12`). "Verify each claim against the code" with a red-first fix (`:22`).
  - fix / dismiss / ask, and "When in doubt, ask" (`references/bugbot-triage.md:9-13`).
  - "No is an acceptable answer… candor over sycophancy" (`poteto-mode:89`).
  - Lost: handling of human-reviewer comments, clarify-all-before-any, and the YAGNI usage grep.
- **pocock, NONE.**
- **addy, NONE.** Only the generic "You are not a yes-machine" (`using-agent-skills:75-84`). `code-review-and-quality:260-279` is written for the reviewer's side.

### using-git-worktrees

superpowers: detect existing isolation, including the submodule guard (`sp:…/using-git-worktrees/SKILL.md:16-45`). Ask consent. Prefer the native `EnterWorktree` (`:51-57`). `git check-ignore` before creating (`:78-88`). Baseline tests, and ask if they are red (`:121-132`).

- **pstack, PARTIAL.** "Work from a git worktree off main… `git fetch && git reset --hard origin/<branch>`" (`playbooks/opening-a-pr.md:5`). ⚠ local `main` rather than `origin/<base>`; `reset --hard`. Cleanup: `git worktree remove --force` then `rm -rf` (`playbooks/worktree-cleanup.md:9`), which the CDS rules forbid for untracked work.
- **pocock, PARTIAL.** Each implementer "confirms its worktree is based on the integration branch… and resets onto it if not" (`implement-spec:27-30`), and worktrees are cleaned up (`:40`). Nothing on gitignore, baselines or `node_modules`.
- **addy, PARTIAL.** `git worktree add ../project-feature-a …` (`ad:skills/git-workflow-and-versioning/SKILL.md:147-171`). ⚠ "If one experiment fails, delete the worktree — nothing is lost" (`:170`).

### finishing-a-development-branch

superpowers: verify tests, then present exactly 3 options and wait (`sp:…/finishing-a-development-branch/SKILL.md:53-82`). Discard requires the typed word `discard` (`:132-146`). Never `--force` a worktree removal on its own initiative (`:177-198`). Never force-push (`:225`).

- **pstack, PARTIAL.**
  - Good: "Babysitting never authorizes merging. Only an explicit request to merge… does" (`playbooks/babysit.md:23`; also `:18`).
  - ⚠ "Opening a PR. Invoked at the end of every other playbook" (`poteto-mode:147`). "Open every PR ready, never as a draft" (`opening-a-pr.md:30`). Conventional Commits (`:11`). "Commit liberally" (`:7`).
- **pocock, NONE.** `pr` writes a body (`mp:skills/engineering/pr/SKILL.md`). ⚠ `implement:17` commits. `implement-spec:38` marks the PR ready or closes tickets.
- **addy, PARTIAL.** `/ship` returns GO/NO-GO with a mandatory rollback plan, and a Critical finding means NO-GO unless the user accepts the risk (`ad:.claude/commands/ship.md:39-71`). No integration menu. ⚠ `ci-cd-and-automation:307` auto-merge.

### writing-skills

superpowers: "NO SKILL WITHOUT A FAILING TEST FIRST". The baseline is a pressure scenario run without the skill (`sp:…/writing-skills/SKILL.md:30-45,376-379`).

- **pstack, PARTIAL.**
  - `authoring-a-skill` delegates to Cursor's `create-skill`, and testing is "Test cases if structural. Skip if subjective." (`playbooks/authoring-a-skill.md:5-7`).
  - `eval` is a strong blinded-judge protocol (`playbooks/eval.md:5-23`), but it needs multiple model families and Cursor transcripts.
  - `correct` requires "Prove each new check fails on a real past mistake" (`skills/correct/SKILL.md:26`).
- **pocock, PARTIAL.** `writing-for-agents` resolves disputes by "running the document, not by debate" (`mp:skills/productivity/writing-for-agents/SKILL.md:81`). Its docs say "There is no automated eval" (`mp:docs/productivity/writing-for-agents.md:47`, per the prior audit).
- **addy, PARTIAL.** Required skill sections (`ad:docs/skill-anatomy.md:44-105`), an eval case file per skill (`ad:CONTRIBUTING.md:44`), and a behavioural runner. All of it is built for contributing to addy's repo, not exposed as an invocable skill.

### using-superpowers / diagnosing-superpowers

See section 3 for the routers.

For diagnosing-superpowers (path:line or no finding, read-only, approval gates: `sp:skills/diagnosing-superpowers/SKILL.md:15-17,86-109`):

- **pstack, PARTIAL.** `show-me-your-work` audits the log against the transcript (`ps:skills/show-me-your-work/SKILL.md:55-60`). `reflect` waits for approval (`:47`). ⚠ It files backlog items "without waiting" (`:49`).
- **pocock, PARTIAL.** `retro` reads session logs (`mp:skills/engineering/retro/SKILL.md:13`). ⚠ "CLAUDE.md/AGENTS.md… should be used incredibly sparingly" (`:41`).
- **addy, NONE.**

---

## 3. Router and enforcement as the sole framework

### Baseline: what superpowers does today

- `sp:hooks/hooks.json` registers a SessionStart hook with matcher `startup|clear|compact`.
- `sp:hooks/session-start` wraps `using-superpowers/SKILL.md` (3,192 B, about 0.85k tokens) in `<EXTREMELY_IMPORTANT>` and emits it as `hookSpecificOutput.additionalContext`.
- Enforcement text: "If you think there is even a 1% chance a skill might apply… you ABSOLUTELY MUST invoke the skill" (`sp:skills/using-superpowers/SKILL.md:11`).
- Precedence: "User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, etc, direct requests) take precedence over skills, which in turn override default behavior." (`:65`).
- Subagents are told to ignore the skill (`:6-8`).

### pstack: `poteto-mode`

Verdict: there is a real router, but it cannot be invoked by the model on Claude Code, and injecting it would inject its autonomy rules into every session. Making it the sole router means a fork that rewrites Autonomy, Subagents and Opening a PR first.

- **Not model-invocable.** `poteto-mode` sets `disable-model-invocation: true` (`ps:skills/poteto-mode/SKILL.md:4`), so on Claude Code only a human-typed `/poteto-mode` loads it.
- **The sticky behaviour is Cursor-only.** `mode: true`, `icon`, `color` and `reminder` (`:5-8`) are Cursor custom-mode fields. README: "it stays in context every turn… plain enter attaches it to one message only" (`ps:README.md:91`). Claude Code has no equivalent and ignores these fields.
- **No Claude Code manifest.** pstack ships only `.cursor-plugin/plugin.json`, so it must be copied in by hand or given a marketplace entry first.
- **What it would take on Claude Code.**
  - **(a) SessionStart hook** that cats the 19,341 B router (about 4.8k tokens, versus 0.85k for superpowers) on startup, clear and compact. That puts these lines in every session:
    - "Just do it. Use any MCP tool. Reversible work and external actions (team chat, ticket updates…) proceed without asking" (`:83`).
    - "Opening a PR. Invoked at the end of every other playbook" (`:147`).
    - The Grok/Opus `Task` defaults (`:95`).
    - Each one conflicts with the gate, so the injected file has to be a rewritten fork.
  - **(b) A CLAUDE.md or `.claude/rules` pointer** ("for nontrivial work, Read `<path>/poteto-mode/SKILL.md` first"). This is cheaper per session but is advisory. It also edits a team-shared, always-loaded file, and the plugin cache path changes with each version.
  - **(c) Drop `disable-model-invocation` on the router only**, and rewrite its description, which today only triggers on "poteto" or "/poteto-mode" (`:3`).
  - The leaves can keep their flag. The router reaches playbooks and principles by Read path ("open its full steps at `playbooks/<title>.md`", `:121`; "Read the leaf skill in full", `:40`). But prose like "the **how** skill" invites a Skill-tool call, which the flag blocks.
- **Enforcement strength when loaded.** It is strong: "Open a todolist whose first items are the matched playbook's steps, copied in verbatim… A step you choose not to do stays in the list with a one-line `skip: <reason>`" (`:121`).
- **Precedence clause.** None found. A grep for precedence, override, CLAUDE.md, AGENTS.md and "user instruction" across pstack finds nothing at router level. The nearest lines:
  - "Gates the operator named and the Always-pause list in Autonomy still need the operator" (`:20`).
  - "Session overrides: 'Don't stop' / 'going to bed'… → keep going" (`:87`). This override runs toward more autonomy, not toward repo rules.

### pocock: `ask-matt`

Verdict: confirmed human-dispatched by design. There is no router to inject, no hook, and nothing forces skill use. Only the 11 model-invoked skills fire, through Claude Code's native description matching.

- "User-invoked: reachable only by the human typing its name… no other skill can [fire it]" (`mp:.agents/invocation.md:5,8`). A user-invoked precondition must be phrased as "tell the user to run `/setup-matt-pocock-skills`" (`:22`).
- `ask-matt` itself is `disable-model-invocation: true` (`mp:skills/engineering/ask-matt/SKILL.md:4`). It is a map ("the summaries here are for orientation only", `:11`). Its main flow is a list of slash commands for the human to type (`:19-34`).
- README positions the set against process-owning frameworks: "Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control… These skills are designed to be small, easy to adapt, and composable." (`mp:README.md:17-19`).
- The chain `to-spec → to-tickets → implement` is all user-invoked, so no step can call the next.
- Model-invoked skills: tdd, diagnosing-bugs, code-review, grilling, domain-modeling, codebase-design, prototype, research, pr, wizard, writing-for-agents. They fire only on description match, with nothing like the 1% rule.
- `setup-matt-pocock-skills` adds an `## Agent skills` block to CLAUDE.md, but it holds only tracker, labels and domain-doc pointers (`mp:skills/engineering/setup-matt-pocock-skills/SKILL.md:76-101`). It contains no routing rule.
- Precedence clause: none at framework level. The only one is scoped to code-review standards: "The repo overrides. A documented repo standard always wins" (`mp:skills/engineering/code-review/SKILL.md:40`).
- To get superpowers-style enforcement you would have to write your own router, which is the thing pocock declines to be.

### addy: `using-agent-skills`

Verdict: the only candidate with an injectable router and a ready SessionStart script. It is about 3× superpowers' size, unwired by default, and its enforcement language is mild. With superpowers removed, wiring it is the closest like-for-like swap.

- **Model-invocable.** There is no `disable-model-invocation` flag. The description reads "Use when starting a session, or when you need to decide which skill… applies" (`ad:skills/using-agent-skills/SKILL.md:3`). Without a hook, Claude Code may or may not load it at session start; that is nondeterministic.
- **The hook exists but is not wired.** `ad:hooks/session-start.sh` (1,675 B):
  - Its own header says it is "Not wired by the plugin: hosts that already route skills from their descriptions (Claude Code, Codex CLI) would run a second router on top of the native one" (`:5-8`).
  - It needs `jq`. Without it, it emits a jq-missing notice instead (`:18-21`).
  - It injects the literal preface "agent-skills loaded. Use the skill discovery flowchart to find the right skill for your task." plus the full `using-agent-skills/SKILL.md` (10,446 B). That totals about 10.5 KB, about 2.6k tokens per startup, as `hookSpecificOutput.additionalContext` (`:23-30`).
  - It is confirmed unregistered in `ad:CONTRIBUTING.md:93` and `ad:docs/getting-started.md:45-47`: "do not also paste `using-agent-skills` into an always-on system prompt or rules file. That creates two routers".
- **Wiring it on Claude Code.** Add a SessionStart entry to `.claude/settings.json` or `~/.claude/settings.json` that runs the script.
  - `${CLAUDE_PLUGIN_ROOT}` is only set for a plugin's own hooks, so the command must name the versioned cache path or a vendored copy.
  - Use matcher `startup|clear|compact` to match superpowers.
  - Addy's warning against two routers (`ad:docs/comparison.md:119`) stops applying once superpowers is gone.
- **Enforcement strength.**
  - "Check for an applicable skill before starting work" (`:133`) and "Skills are workflows, not suggestions. Follow the steps in order" (`:135`).
  - This is far weaker than the 1% rule and its red-flags table. There is no "before any response including clarifying questions".
  - Its six "Core Operating Behaviors… non-negotiable" (`:45-114`) are good fits: surface assumptions, stop on confusion, push back, simplicity, scope discipline, verify.
- **Precedence clause.** None. Nearest lines:
  - "Accept the human's decision if they override with full information" (`:82`).
  - "Commit the completed task only when the user or repository workflow authorizes it" (`ad:skills/context-engineering/SKILL.md:133`).
  - `/ship`'s "your own `code-reviewer`… in `.claude/agents/`… take precedence over this plugin's versions" (`ad:.claude/commands/ship.md:26`) covers personas only.
  - A one-line precedence statement would have to be added to the injected text.

---

## 4. What is lost per candidate if superpowers is removed

Each list names superpowers disciplines that have no equivalent in that candidate, plus the most damaging PARTIAL gaps. The first three are the top losses.

### pstack

1. **The human approval gate before implementation** (`sp:brainstorming:38-56`). pstack inverts it with "No human checkpoint" (`architect:43`), anti-asking (`poteto-mode:20`) and never-block-on-the-human.
2. **The integration decision belongs to the human, and cleanup is safe** (`sp:finishing…:53-82,132-198`). pstack opens a ready PR at the end of every playbook (`poteto-mode:147`, `opening-a-pr.md:30`), and worktree cleanup uses `--force` / `rm -rf` (`worktree-cleanup.md:9`).
3. **TDD Iron Law for features and refactors** (`sp:test-driven-development:31-45`). pstack's `tdd` is bug-only and opt-in (`tdd:3,11`).
4. The user-and-CLAUDE.md-over-skills precedence clause (`sp:using-superpowers:65`).
5. The per-task spec+quality review with the 5-round breaker and no parallel implementers (`sp:subagent-driven-development:282,310-314,411-429`). pstack runs owners in parallel and lets them self-merge.
6. Clarify-all-before-implementing and YAGNI grep for human review feedback (`sp:receiving-code-review:42-48,88-96`).
7. Worktree setup safety: detect isolation, prefer the native tool, `git check-ignore`, baseline tests (`sp:using-git-worktrees:16-132`).

### pocock

1. **Evidence before completion claims** (`sp:verification-before-completion:16-59`). There is no general gate. "Agent said success → check the VCS diff" is gone, while `implement-spec` trusts implementer reports.
2. **Verify review feedback before implementing it** (`sp:receiving-code-review`, whole skill). Nothing covers it.
3. **Finishing a branch: present options, wait, never `--force`** (`sp:finishing…`). Instead `implement` commits to the current branch and `implement-spec` marks PRs ready or closes tickets.
4. Per-task two-stage review and a bounded fix loop. `implement-spec` reviews once at the end, and its docs admit no stop condition.
5. "Watch it fail for the right reason" (`sp:tdd:113-128`). pocock's `tdd` only says to write it first.
6. Worktree safety checks; gitignored-fixture tests skip silently in its worktrees.
7. Any router enforcement at all (human dispatch by design), and RED-first skill testing.

### addy

1. **Fresh implementer per task with two-stage review per task** (`sp:subagent-driven-development`). There is no counterpart; `/build auto` executes inline.
2. **Verify review feedback before implementing it** (`sp:receiving-code-review`). Only the generic anti-sycophancy line exists.
3. **After 3 failed fixes, stop and question the architecture with the human** (`sp:systematic-debugging:191-212`). It is absent, and the "safe fallbacks" section pushes the other way.
4. Session diagnosis and retro (`sp:diagnosing-superpowers`). There is no learning loop.
5. The fresh-evidence-in-this-message rule and distrust of subagent success reports (`sp:verification-before-completion:20,47,100-104`).
6. The final fresh-context whole-branch review and the "Rulings I made" list in inline execution (`sp:executing-plans:234-298`).
7. Worktree safety checks. Addy's snippet says deleting a worktree loses nothing.
