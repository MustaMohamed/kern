# Merge map: build, test and debug cluster

Target: a personal, portable Claude Code plugin used across many projects and stacks. Project rules are inputs the skills read, not content baked into them. Read-only design research; nothing from the four sources was installed or run.

Citation prefixes:

- `SP:` = `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills/`
- `PS:` = `scratchpad/repos/cursor/plugins/pstack/skills/`
- `PB:` = `scratchpad/repos/cursor/plugins/pstack/skills/poteto-mode/playbooks/`
- `PO:` = `scratchpad/repos/pocock/skills/skills/`
- `AD:` = `scratchpad/repos/addy/agent-skills/`
- `EX:` = an example project's rules (`cds-app-rewrite/.claude/rules/`), cited only as evidence that a default or extension point is needed. No merged skill names it.

Invocation column: `auto` = model-invocable (description resident every session). `slash` = `disable-model-invocation: true` or a slash command. `router` = a pstack playbook only `poteto-mode` reads. `agent` = subagent definition. `ref` = supporting file.

---

## 0. Framework defaults and project extension points

### Conservative defaults (D1–D12)

Every merged skill applies these unless the project's own rules loosen one by name. Detection or inference never loosens a default.

| ID | Default | Evidence it is needed |
|---|---|---|
| D1 | No commits unless the user asks. A plan's approval covers commits only if the plan says so. | `AD:.claude/commands/build.md:35` commits per task; `PO:engineering/implement/SKILL.md:17` commits to the current branch |
| D2 | No outward actions (push, PR, tracker writes, deploys, external API writes) without explicit approval. | `PO:engineering/implement-spec/SKILL.md:25,38`; `PB:orchestrate.md:15,65` |
| D3 | The primary working tree is never `checkout`/`switch`/`reset --hard`/`stash`/`bisect`/`clean`-ed. Each writing agent gets its own worktree. | `AD:skills/debugging-and-error-recovery/SKILL.md:101-109`; `SP:using-git-worktrees/SKILL.md:100` |
| D4 | Tasks that touch the same files or the same shared local service run serially. | `PO:engineering/implement-spec/SKILL.md:17` |
| D5 | Judgment calls (spec ambiguity, scope, design, security) are escalated. Only mechanical conflicts get a recorded decision, and every decision is listed at the end. | `SP:subagent-driven-development/SKILL.md:17-31` |
| D6 | No silent fallbacks, in code or in process. An unresolved project input is asked for, not guessed. | `AD:skills/debugging-and-error-recovery/SKILL.md:214-241` |
| D7 | Persisted or cross-deploy shapes change by expand/contract; existing data keeps working at every step. | `PS:principle-outcome-oriented-execution/SKILL.md:14-15` |
| D8 | Production and any project-declared read-only system are read-only. Instrumentation runs locally only. | `PB:bug-fix.md:7` |
| D9 | Work beyond the approved scope pauses for confirmation. The numeric threshold is a project input. | `AD:skills/incremental-implementation/SKILL.md:115-133` |
| D10 | Fix loops cap at 3 rounds, then escalate with a split proposal. | `SP:subagent-driven-development/SKILL.md:411-429` |
| D11 | New behavior ships with tests. TDD is not opt-in. | `PS:tdd/SKILL.md:3,26` |
| D12 | Secrets are never printed; loops read them from env vars. | `PO:engineering/diagnosing-bugs/SKILL.md:12-16` |

### Extension points used by this cluster

| Key | Used by | When unset |
|---|---|---|
| `base_branch` (remote + branch new work starts from) | 1, 2 | Detect `git symbolic-ref refs/remotes/origin/HEAD`, state it, confirm once |
| `test.focused`, `test.full`, `typecheck`, `lint`, `build` | 1, 3, 4, 5, 6 | Detect from manifests, task runners and CI files; state the source |
| `generated_artifacts` (regen command + trigger paths) | 3 | None assumed; mention that none are declared |
| `worktree.setup` (deps, env files, links) and `worktree.teardown_when` | 1, 2 | Ask; never fall back to editing the primary tree |
| `shared_services` (local DBs, ports, queues every worktree shares) | 1, 2, 5 | Treat any task that runs migrations or DB-backed tests as overlapping (D4) |
| `commit.convention`, `commit.consent` | 1, 3 | D1; message style detected from `git log` |
| `scope_threshold` | 1, 3 | Pause at any file outside the approved list |
| `review_rules` (project review checklist to pass as constraints) | 1 | Plan's Global Constraints only |
| `browser_verify` (command to drive a browser, probe and run forms) | 3, 4, 5, 8 | Ask; do not hand-roll browser automation |
| `read_only_systems` and `evidence_agents` | 4, 7 | Production is read-only (D8); no evidence agents |
| `schema_inspect`, `migration_create`, `deploy_path` | 7 | Ask before writing any migration |
| `ui_rules`, `design_tokens`, `ui_test_utils` | 8 | Generic rules in the skill; ask about empty-value rendering |
| `model_policy` | 1, 2 | Built-in tier table in `model-selection.md` |

### Resolution order (proposed; the format itself is shared with the meta cluster)

1. A project profile file at a fixed path (proposed `.claude/project-profile.md`, a flat `key: value` list).
2. `CLAUDE.md` and project rules already in context, matched by key name or obvious equivalent.
3. For command keys only: detection from repo files (`package.json` scripts, `Makefile`, `pyproject.toml`, `Cargo.toml`, `go.mod`, CI workflows). The skill prints the detected value and its source in its first output line. Pattern source: `AD:skills/test-driven-development/SKILL.md:24-34`.
4. Otherwise ask the user once, and offer to record the answer in the profile (a repo file edit, so it needs a yes).

Safety keys (D1–D3, D8, `commit.consent`, `read_only_systems`) are never set by step 3. Each SKILL.md opens with a 5–10 line "Project inputs" block naming the keys it reads and the default when unset.

### Taxonomy

| # | Category | Phase | Merged artifact |
|---|---|---|---|
| 1 | Plan execution and per-task delegation | Build | `execute-plan` (phase, slash) |
| 2 | Parallel agents and worktree isolation | Build infra | `parallel-work` (discipline, slash) |
| 3 | Incremental implementation, TDD, test design | Build | `implement` (discipline, auto) + `test-engineer` agent |
| 4 | Debugging and root cause | Build / incident | `diagnose` (discipline, auto) |
| 5 | Performance | Optimize | `perf` (specialist, slash) + optional `perf-auditor` agent |
| 6 | Refactoring and simplification | Maintain | `refactor` (phase, slash) |
| 7 | Migration and deprecation | Maintain | `expand-contract` (specialist, auto, narrow trigger) |
| 8 | UI building | Build | `build-ui` (specialist, auto, narrow trigger) |
| 9 | Principles, type discipline, context hygiene | All | `_shared/references/principles.md` (reference) |

Auto-invoked: 4 (`implement`, `diagnose`, `expand-contract`, `build-ui`). Stack depth lives in optional `references/stacks/<stack>.md` files; only TypeScript/JavaScript depth exists in the sources.

---

## 1. Plan execution and per-task delegation

Job: turn an approved plan into verified changes task by task, with a record that survives compaction. Phase: build.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| executing-plans | SP | 20405 + scripts 2633 | auto | Inline task loop, ledger, completion contract, one fresh whole-branch review |
| subagent-driven-development | SP | 32577 + prompts 20127 + scripts 6616 | auto | Fresh implementer per task, spec+quality review, fix loop, final review |
| implement | PO | 622 | slash | TDD at agreed seams, typecheck often, full suite at end |
| implement-spec | PO | 2780 | slash | Ticket task-graph frontier, implementer per ticket in a worktree |
| /build | AD | 3959 | slash | Default one task then stop; `auto` = single approval then every task |
| feature | PB | 2766 | router | Four-item throughput checkpoint, verify on the matching surface |
| autonomous-run | PB | 1878 | router | Checkable exit predicate |
| orchestrate | PB | 16779 | router | Brief template, standing orders, verdicts keyed by head SHA |

**Strongest mechanisms to keep**

- Ledger with an identity first line; done means a `Task N: complete` line; after compaction trust the ledger plus `git log` over memory. `SP:subagent-driven-development/SKILL.md:131-154`, `SP:executing-plans/SKILL.md:115-141`. The costliest observed failure was re-dispatching completed tasks.
- Task brief extracted to a file; exact values live only there; no subagent reads the whole plan. `SP:subagent-driven-development/SKILL.md:251-262`, `scripts/task-brief:30-41`.
- No accumulated history in dispatches (one dispatch was 42k chars, 99% pasted history). `SP:subagent-driven-development/SKILL.md:267-271`.
- Report file plus a 15-line return with four statuses DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT and a handling rule per status. `SP:subagent-driven-development/implementer-prompt.md:128-153`, `SKILL.md:288-306`.
- No nested dispatch from implementers or reviewers. `SP:subagent-driven-development/implementer-prompt.md:50-60`, `task-reviewer-prompt.md:55-62`.
- Review package cut from the recorded BASE, never `HEAD~1`, with guards that exit 3 on an empty or non-descendant range. `SP:subagent-driven-development/scripts/review-package:25-28`.
- Task reviewer: two verdicts (spec ✅/❌/⚠️, quality), report treated as unverified claims, read-only, no suite re-run, batched briefs checked file by file. `SP:subagent-driven-development/task-reviewer-prompt.md:52-53,64-92,94-113`.
- Controller never pre-judges findings in the reviewer prompt. `SP:subagent-driven-development/SKILL.md:339-344`.
- Scoped re-review (ADDRESSED / NOT ADDRESSED, fix-diff breakage only, out-of-scope to the ledger). `SP:subagent-driven-development/re-review-prompt.md:55-62,80-100`.
- Fix escalation: resume the implementer first, then a fresh one on a stronger model. `SP:subagent-driven-development/SKILL.md:375-386`.
- Pre-flight conflict table: one row per task pair sharing a file or interface, one self-consistency row per task. `SP:subagent-driven-development/SKILL.md:162-182`.
- `task-done` records the ledger line only when the test command exits 0. `SP:executing-plans/scripts/task-done:39-52`.
- Explicit model on every dispatch, chosen by task shape; "turn count beats token price". `SP:subagent-driven-development/SKILL.md:184-219`.
- Batch small same-shape edits into one dispatch. `SP:subagent-driven-development/SKILL.md:223-229`.
- Final whole-branch review on the most capable tier, findings re-graded by effect, one fix pass with RED then GREEN per fix. `SP:executing-plans/SKILL.md:234-289`.
- Exhaustive end-of-run lists of decisions and deferred minors. `SP:executing-plans/SKILL.md:291-298`.
- Single unambiguous approval ("looks reasonable" is not approval), clean-baseline check, stage only touched files, stop list (ambiguity, auth, destructive data, anything `git revert` cannot undo). `AD:.claude/commands/build.md:31-41`. Matches D5.
- Step mode: next task, then stop. `AD:.claude/commands/build.md:14-25`.
- Task graph frontier; context pointers over duplication; implementer verifies its worktree base before starting. `PO:engineering/implement-spec/SKILL.md:13-15,27-30`.
- Brief template GOAL / SCOPE / CONTEXT / ACCEPTANCE / VERIFY / TIMEBOX / FORBIDDEN / REPORT / STANDING; missing field means do not spawn; standing orders pasted into every spawn and resume. `PB:orchestrate.md:25,34-56`.
- Verdicts keyed by head SHA; a new SHA voids the verdict. `PB:orchestrate.md:87-89`.
- Throughput checkpoint with `n/a: <reason>` instead of dropping an item. `PB:feature.md:7-11`.
- Exit predicate that is never relaxed. `PB:autonomous-run.md:5,11`.
- Restartable session boundary: scope, status, changed files, exact verification commands and results, open questions; approval is never inferred from an earlier conversation. `AD:skills/context-engineering/SKILL.md:123-137`.

**Drop**

- "Rulings, not stalls", "do not pause between tasks". `SP:subagent-driven-development/SKILL.md:17-31`, `SP:executing-plans/SKILL.md:27-43`. Violates D5.
- Controller adjudication at round 5. `SP:subagent-driven-development/SKILL.md:411-429`. Replaced by D10. (EX: `2-engineering/minimal-change-discipline.md` treats round N fixing round N−1 as a split signal.)
- Workspace at `<repo-root>/.superpowers/sdd/`. `SP:subagent-driven-development/scripts/sdd-workspace:45-46`. Inside an isolated agent worktree `--show-toplevel` differs, so each agent resolves a different workspace.
- "Never dispatch implementers in parallel". `SP:subagent-driven-development/SKILL.md:282`. Too strict once writers have their own worktrees; D4 replaces it.
- Commit to the current branch; draft PR, mark ready, close tickets; max-concurrency background implementers. `PO:engineering/implement/SKILL.md:17`, `PO:engineering/implement-spec/SKILL.md:17,25,38`. D1, D2, D4.
- Commit per task and commit the plan file; "ask the user to commit, stash". `AD:.claude/commands/build.md:32-35`. D1, D3.
- Grok defaults, mandatory `arena`, "commit liberally", Opening a PR. `PB:feature.md:12,17`.
- Coordinator pushes, `gt` stacker, cloud workers, "When in doubt, act and log". `PB:orchestrate.md:15,65,79-82,107`. D2, D5.
- "Do not park reversible work for the human". `PB:autonomous-run.md:9`. D5.

**Merged skill spec**

- Name: `execute-plan`. Type: phase. Invocation: slash-only (`/execute-plan <plan> [step|inline|delegate]`). Reason: runs only after a human approved a plan; auto-triggering would bypass that approval.
- Project inputs: `base_branch`, `test.*`, `commit.convention`, `commit.consent`, `worktree.setup`, `shared_services`, `scope_threshold`, `review_rules`, `model_policy`.
- Description draft: `Run an approved implementation plan task by task with a resumable ledger: step mode (one task, then stop), inline, or delegate (fresh implementer per task in its own worktree, spec+quality review, scoped re-review, final review).`
- Steps:
  1. Gate: plan exists and names its spec; user approval recorded; read `commit.consent` (D1). Record the primary tree's branch. [AD build.md:31-34]
  2. Workspace: one absolute directory outside the repo (default `~/.claude/work/<repo-slug>/<plan-slug>/`); ledger identity line; resume from complete lines plus `git log`. [SP SDD:131-154, path changed]
  3. Read plan and spec once; todo per task; pre-flight conflict table. Mechanical conflict: `Decision:` line. Spec or scope conflict: stop and ask before Task 1 (D5). [SP SDD:162-182; AD context-engineering:253-298]
  4. Throughput checkpoint and file-overlap matrix from each task's file list plus `shared_services`. Disjoint tasks may run as one wave through `parallel-work`; the rest serialize (D4). Files outside the plan's list trigger D9. [PB feature.md:7-11]
  5. Step or inline mode: `task-start`, follow `implement`, `task-done -- <test.full or task command>`. [SP EP:170-232]
  6. Delegate mode: `task-brief`, record BASE, dispatch with explicit `model`, `isolation: "worktree"`, brief path, upstream interfaces, ambiguity resolutions, report path, standing orders. Implementer runs `worktree.setup`, asserts its base matches `base_branch` (resetting only inside its own worktree), then follows `implement`. [SP SDD:246-283; PO implement-spec:28; PB orchestrate:25,34-56]
  7. Handle the returned status. [SP SDD:288-306]
  8. `review-package BASE HEAD`; task reviewer gets brief, report, package and a constraints block built from the plan's Global Constraints plus `review_rules`. Resolve every ⚠️ item yourself. [SP SDD:308-352]
  9. Fix loop: rounds 1–2 resume the implementer, round 3 fresh implementer one tier up; scoped re-review per round. Still open after 3, or a round that finds a bug in an earlier round's code: stop and escalate with a split proposal (D10). [SP SDD:372-409 modified]
  10. Ledger completion line with commit range or diff hash and the test result. [SP SDD:431-443]
  11. Waves: merge serially into one local integration worktree, run `test.full` there. [PO implement-spec:32-34 modified]
  12. Final whole-branch review on the most capable tier using the review cluster's reviewer; re-grade by effect; one fix pass, each fix RED then GREEN. [SP EP:234-289]
  13. Finish: decisions (with cost if wrong), open escalations, deferred minors, verification commands and results, handoff fields. Push and PR are prepared, not run (D2). Assert the primary tree's branch is unchanged. [SP EP:291-298; AD context-engineering:125-137]
  14. After acceptance: delete the workspace; tear worktrees down per `worktree.teardown_when`.
- References: `references/ledger-format.md`, `references/model-selection.md` (role to haiku / sonnet / opus, overridable by `model_policy`), `_shared/references/brief-template.md`, `_shared/references/project-inputs.md`.
- Prompts (from SP, adapted): `implementer-prompt.md` (commit step conditional on D1, `commit.convention`, base assertion), `task-reviewer-prompt.md`, `re-review-prompt.md`.
- Scripts: `workspace`, `task-brief`, `review-package`, `task-start`, `task-done`. All stack-neutral; the test command is an argument.
- Estimated SKILL.md: 10–11 KB (SP pair: 53 KB plus 20 KB of prompts).

---

## 2. Parallel agents and worktree isolation

Job: fan out independent work safely and give each writer its own workspace. Phase: build infrastructure for categories 1, 4, 5.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| dispatching-parallel-agents | SP | 6078 | auto | Independence test, focused prompts, one message = parallel |
| using-git-worktrees | SP | 6813 | auto | Detect isolation, prefer native tool, check-ignore, baseline tests |
| swarm | PS | 2949 | slash | Done predicate, partition or race with declared selection rule |
| principle-separate-before-serializing-shared-state | PS | 1565 | slash | Remove the shared write target before locking |
| worktree-cleanup | PB | 2932 | router | Audit from `git worktree list`; wip vs scratch |
| orchestrate (liveness) | PB | 16779 | router | Rolling window, never resume to check, retry by mode |
| orchestration-patterns | AD ref | 18201 | ref | Endorsed fan-out patterns and anti-patterns |
| implement-spec (worktree parts) | PO | 2780 | slash | Worktree per ticket; notes outside the repo |

**Strongest mechanisms to keep**

- Independence graph and "don't use when" list. `SP:dispatching-parallel-agents/SKILL.md:18-45,129-134`.
- Prompt shape: one domain, self-contained, explicit constraints, explicit return. `SP:dispatching-parallel-agents/SKILL.md:58-64,87-127`.
- After return: read summaries, check for same-code edits, full suite, spot-check. `SP:dispatching-parallel-agents/SKILL.md:161-167`.
- Done predicate first; partition or race; race selection rule declared before spawning. `PS:swarm/SKILL.md:22-23`.
- PASS / ISSUES / BLOCKED listing every provable issue; missing required evidence → respawn once → gap; a gap is not a pass. `PS:swarm/SKILL.md:34,40`.
- Each actor owns its write target; serialize structurally, not by instruction. `PS:principle-separate-before-serializing-shared-state/SKILL.md:9-16`.
- Detect existing isolation (`GIT_DIR` vs `GIT_COMMON`, submodule guard). `SP:using-git-worktrees/SKILL.md:16-39`.
- Native isolation over raw `git worktree add`. `SP:using-git-worktrees/SKILL.md:51-57,163-164`.
- `git check-ignore` before a project-local worktree directory. `SP:using-git-worktrees/SKILL.md:78-88`.
- Baseline tests first; a failing baseline is the human's call. `SP:using-git-worktrees/SKILL.md:121-140`.
- Cleanup reads `git worktree list`; tracked uncommitted edits pause; untracked scratch is named then dropped. `PB:worktree-cleanup.md:5-8`.
- Rolling window, never resume to check liveness, retry by failure mode, account for every child. `PB:orchestrate.md:16,63,74,95,97`.
- Built-in `Explore` for read-heavy research; fan-out checklist; router-persona and deep-tree anti-patterns. `AD:references/orchestration-patterns.md:48-74,96-113,282-339`.
- Agent Teams for competing hypotheses (optional, experimental). `AD:references/orchestration-patterns.md:174-278`.
- Shared notes written outside the repo for later agents. `PO:engineering/implement-spec/SKILL.md:23`.

**Drop**

- Cursor cloud parameters and Grok defaults. `PS:swarm/SKILL.md:25,30-32`.
- "Add to .gitignore, commit the change". `SP:using-git-worktrees/SKILL.md:86`. D1.
- Hardcoded `npm install` / `cargo build` / `pip install` setup. `SP:using-git-worktrees/SKILL.md:106-119`. Becomes the `worktree.setup` input. (EX: a hoisted monorepo needs symlinks, and `npx jest` there silently installs the wrong jest.)
- Sandbox fallback to the current directory. `SP:using-git-worktrees/SKILL.md:100`. D3, D6: stop instead.
- `git worktree remove --force` plus `rm -rf`; simulator cleanup. `PB:worktree-cleanup.md:9-10`.

**Merged skill spec**

- Name: `parallel-work`. Type: discipline. Invocation: slash-only, also linked from `execute-plan`, `diagnose`, `perf`. Reason: the Agent tool already teaches one-message fan-out; the safety part is D3/D4, which every linking skill applies.
- Project inputs: `base_branch`, `worktree.setup`, `worktree.teardown_when`, `shared_services`, `model_policy`.
- Description draft: `Fan out independent work to parallel subagents: independence check, declared shape and selection rule, one worktree per writer off the base branch, PASS/ISSUES/BLOCKED drain, then integrate and run the full suite.`
- Steps:
  1. Classify independent / related / shared-state; build the file and `shared_services` overlap list (D4). [SP DPA:18-45]
  2. Frame: done predicate, shape, race selection rule, N, model per worker. [PS swarm:20-26]
  3. Brief each worker; own write target; readers use `Explore`, writers `isolation: "worktree"`. [PB orchestrate:34-56; PS separate:15; AD orch:113]
  4. Spawn in one message with `run_in_background: true`; cap the window; never poll or resume to check. [SP DPA:66-77; PB orchestrate:16,95]
  5. Worker entry check before the first edit: branch, base matches `base_branch`, `worktree.setup` done, focused baseline test green. [SP UGW:121-140]
  6. Drain: classify; respawn once on missing evidence; account for every child; retry by mode. [PS swarm:34-40; PB orchestrate:74,97]
  7. Integrate in a local integration worktree; conflict check; `test.full`; spot-check one claim per worker. [SP DPA:79-85,161-167]
  8. Report table and gaps; assert the primary tree's branch is unchanged.
  9. Teardown per `worktree.teardown_when` with empty `git status --porcelain`.
- References: `references/worktrees.md` (detect, create, base check, setup hook, shared-services caveats, teardown), `_shared/references/brief-template.md`, `references/orchestration-patterns.md` (AD catalog trimmed).
- Scripts: `wt-enter-check` (branch, base freshness, porcelain, runs `worktree.setup`; non-zero on mismatch), `wt-audit` (read-only list with porcelain counts and, when a forge CLI is configured, PR state).
- Estimated SKILL.md: 5–6 KB.

---

## 3. Incremental implementation, TDD and test design

Job: write production code in thin slices, each proven by a test seen failing for the right reason. Phase: build.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| test-driven-development | SP | 9578 | auto | Iron law, verify RED, full project suite |
| writing-good-tests | SP ref | 8268 | ref | Name the break, real thing, mock gate, mutation check |
| tdd | PS | 3143 | slash | Bug regression test when cheap; closest executable check otherwise |
| principle-test-behavior-not-implementation | PS | 1386 | slash | Delete tests that pass if every import returned `undefined` |
| principle-sequence-verifiable-units | PS | 1705 | slash | Before/after brackets; repro before fix |
| tdd | PO | 3629 + 3695 refs | auto | Seams up front, vertical tracer bullets, tautology ban |
| implement | PO | 622 | slash | Typecheck regularly, full suite once at end |
| test-driven-development | AD | 16517 | auto | Discover the stack's commands, Prove-It, pyramid, DAMP |
| incremental-implementation | AD | 9629 | auto | Vertical / contract / risk-first slices, scope discipline |
| /test | AD | 665 | slash | Wrapper |
| test-engineer | AD | 3275 | agent | Strategy, Prove-It test writer, scenario table |
| testing-patterns | AD ref | 7460 | ref | Jest / RTL / Supertest / Playwright examples |

**Strongest mechanisms to keep**

- Iron law; code written before its test is deleted. `SP:test-driven-development/SKILL.md:31-45`.
- Verify RED: fails (not errors) for the expected reason; a pre-passing test is a finding. `SP:test-driven-development/SKILL.md:113-128`.
- "Other tests" means the project suite; every red test seen is named in the report. `SP:test-driven-development/SKILL.md:185-193`.
- Name the break before the test body; derive expectations without the code under test. `SP:test-driven-development/writing-good-tests.md:20-30,65-79`.
- Mutation check. `SP:test-driven-development/writing-good-tests.md:157-169`.
- Mock gate: side effects first, complete real structure, test-only methods in test utilities. `SP:test-driven-development/writing-good-tests.md:99-148`.
- The `undefined` test and loose-assertion list. `PS:principle-test-behavior-not-implementation/SKILL.md:9-21`.
- Seams agreed up front (in the plan when there is one). `PO:engineering/tdd/SKILL.md:18-24`.
- Tautology and horizontal-slicing anti-patterns; vertical tracer bullets. `PO:engineering/tdd/SKILL.md:28-32`.
- Mock only at system boundaries; DI; SDK-style interfaces. `PO:engineering/tdd/mocking.md:3-59`.
- No correct seam is itself the finding. `PO:engineering/diagnosing-bugs/SKILL.md:116-120`.
- Discover the repo's own focused and full commands; never assume `npm test`. `AD:skills/test-driven-development/SKILL.md:24-34`. Becomes the `test.*` inputs.
- Prove-It; repro test written by a subagent that does not know the fix. `AD:skills/test-driven-development/SKILL.md:96-117,343-357`.
- No re-run on unchanged code. `AD:skills/test-driven-development/SKILL.md:373,398`.
- Vertical, contract-first, risk-first slicing. `AD:skills/incremental-implementation/SKILL.md:44-87`.
- "NOTICED BUT NOT TOUCHING" list. `AD:skills/incremental-implementation/SKILL.md:115-133`.
- Compilable, one change per increment, rollback-friendly; red flag past ~100 untested lines. `AD:skills/incremental-implementation/SKILL.md:135-181,226`.
- Scenario table (happy, empty, boundary, error, concurrency). `AD:agents/test-engineer.md:47-57`.
- DAMP over DRY; test sizes. `AD:skills/test-driven-development/SKILL.md:163-232`.
- Failing-before and passing-after evidence; closest executable check when no test is practical. `PS:tdd/SKILL.md:22-42`.

**Drop**

- Opt-in trigger and "prefer no new test". `PS:tdd/SKILL.md:3,26`. D11.
- Per-test seam confirmation. `PO:engineering/tdd/SKILL.md:22`. Confirm once at plan approval.
- "Refactoring is not part of the loop". `PO:engineering/tdd/SKILL.md:38`. Keep in-slice refactor of touched code.
- DevTools MCP browser testing. `AD:skills/test-driven-development/SKILL.md:312-341`. Browser checks go through `browser_verify`.
- Playwright login with `.fill()`. `AD:references/testing-patterns.md:205-206`. (EX: `fill()` on React-controlled inputs fires no request.) If kept in the TS stack reference, show `type()` and the caveat.
- Truthiness assertion catalogue and `toBeDefined()` in examples. `AD:references/testing-patterns.md:53-58`, `AD:skills/test-driven-development/SKILL.md:59`.
- Env-var feature flag snippet. `AD:skills/incremental-implementation/SKILL.md:147-160`. Project flag mechanism instead.
- Commit per slice. `AD:skills/incremental-implementation/SKILL.md:41`. D1.

**Merged skill spec**

- Name: `implement`. Type: discipline. Invocation: auto. Reason: fires on every production-code change and replaces three auto TDD skills plus AD's incremental skill with one description.
- Project inputs: `test.focused`, `test.full`, `typecheck`, `lint`, `generated_artifacts`, `scope_threshold`, plus a `test_rules` pointer (project-specific obligations such as an authz matrix or legacy-data fixtures).
- Description draft: `Use when writing or changing production code (feature, bug fix, behavior change). Thin slices; failing test first, watched red for the right reason; minimal green; full suite before done; out-of-scope findings listed, not fixed.`
- Steps:
  1. Resolve commands per section 0; print them with their source. [AD TDD:24-34]
  2. Slice the work and list seams; use the plan's seams when present. [AD incr:44-87; PO tdd:18-24]
  3. Per slice: name the break, write the test, run it, confirm RED for the expected reason. [SP WGT:65-79; SP TDD:71-128]
  4. GREEN with the minimum. [SP TDD:130-166]
  5. Focused test, typecheck, refactor touched code only, stay green. [SP TDD:168-202]
  6. Scope gate: out-of-scope items go to "NOTICED BUT NOT TOUCHING"; D9 for unplanned files. [AD incr:115-133]
  7. Test-quality gate: mutation check, `undefined` test, adversarial inputs (empty, zero, `false`, cleared, multi-element), each `test_rules` obligation, fail-then-pass proof for any new guard. [SP WGT:157-169; PS test-behavior:9]
  8. No correct seam: report it, with the closest executable check and its output. [PO diag:116-120; PS tdd:22-34]
  9. Run `generated_artifacts` regen for touched trigger paths; then `test.full`; name every red test. [SP TDD:185-193]
  10. Report failing-before and passing-after output, commands, files, NOTICED list. [PS tdd:36-42]
- References: `references/test-design.md` (SP writing-good-tests, PS test-behavior, PO tests/mocking, AD DAMP, sizes, scenario table; language-neutral), `references/slicing.md`, optional `references/stacks/typescript.md` (AD testing-patterns trimmed, `type()` caveat, PO shoehorn test-data section). Other stacks are empty slots.
- Agent: `test-engineer` (sonnet; writes test files only; Prove-It and coverage-gap modes). [AD agents/test-engineer.md]
- Estimated SKILL.md: 6 KB.

---

## 4. Debugging and root cause

Job: find the cause before touching code, fix it at the source, lock it with a regression test. Phase: build and incident.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| systematic-debugging | SP | 9465 + refs 13487 + example 5054 + script 1986 | auto | Iron law, four phases, 3 failed fixes → question architecture |
| principle-fix-root-causes | PS | 1246 | slash | No silencing guards; suspect state on restart |
| principle-attack-the-premise | PS | 1941 | slash | Two failed fixes on one premise → census |
| bug-fix | PB | 2255 | router | Every shipped line traces to runtime evidence |
| runtime-forensics / trace-forensics | PB | 1210 / 1763 | router | Real artifact, reduced in a subagent, mapped to source |
| diagnosing-bugs | PO | 8664 + 1316 | auto | Red-capable loop first, minimise, ranked hypotheses |
| debugging-and-error-recovery | AD | 10913 | auto | Stop the line, triage trees, untrusted error output |

**Strongest mechanisms to keep**

- Feedback loop first, ten rungs in cost order; done when one already-run command is red-capable, deterministic, fast and agent-runnable; no such command, no Phase 2. `PO:engineering/diagnosing-bugs/SKILL.md:18-66`. The strongest mechanism in the cluster.
- Non-deterministic bugs: raise the reproduction rate. `PO:engineering/diagnosing-bugs/SKILL.md:49-51`; cause tree `AD:skills/debugging-and-error-recovery/SKILL.md:53-73`.
- Minimise until every element is load-bearing. `PO:engineering/diagnosing-bugs/SKILL.md:78-86`.
- No fix without root-cause investigation. `SP:systematic-debugging/SKILL.md:14-20`.
- Boundary instrumentation across components. `SP:systematic-debugging/SKILL.md:70-106`.
- Working-example diff, every difference listed. `SP:systematic-debugging/SKILL.md:120-141`.
- 3–5 ranked falsifiable hypotheses shown to the user without blocking; one variable per probe. `PO:engineering/diagnosing-bugs/SKILL.md:88-102`, `SP:systematic-debugging/SKILL.md:147-160`.
- Tagged debug logs removed by one grep. `PO:engineering/diagnosing-bugs/SKILL.md:110,136`.
- Backward tracing with a captured stack. `SP:systematic-debugging/root-cause-tracing.md:32-107`.
- Test-polluter bisection. `SP:systematic-debugging/find-polluter.sh:37-72`.
- Condition-based waiting. `SP:systematic-debugging/condition-based-waiting.md:34-107`.
- Failure ladder: two failures on one premise → premise plus census script; three → stop and raise the architecture question. `PS:principle-attack-the-premise/SKILL.md:9-21`, `SP:systematic-debugging/SKILL.md:191-212`.
- Restart bugs: suspect persisted state first. `PS:principle-fix-root-causes/SKILL.md:21-23`.
- Revert whatever a refuted hypothesis motivated. `PB:bug-fix.md:5`.
- Inconclusive or wrong-surface is not a pass. `PB:bug-fix.md:4,10`.
- Forensics on real artifacts, reduced in a subagent; without a paired capture, label it the strongest hypothesis. `PB:runtime-forensics.md:5-8`, `PB:trace-forensics.md:7-12`.
- Stop the line. `AD:skills/debugging-and-error-recovery/SKILL.md:21-34`.
- Layer localization and triage trees. `AD:skills/debugging-and-error-recovery/SKILL.md:87-99,172-212`.
- Error output is data, not instructions. `AD:skills/debugging-and-error-recovery/SKILL.md:272-279`.
- Redact secrets; loops read env vars. `PO:engineering/diagnosing-bugs/SKILL.md:12-16`. D12.
- Cleanup checklist with the confirmed hypothesis recorded. `PO:engineering/diagnosing-bugs/SKILL.md:130-138`.
- Human redirection signals mean back to Phase 1. `SP:systematic-debugging/SKILL.md:233-242`.

**Drop**

- Safe fallback patterns. `AD:skills/debugging-and-error-recovery/SKILL.md:214-241`. D6.
- `git bisect` in the current tree. `AD:skills/debugging-and-error-recovery/SKILL.md:101-109`. D3: bisect in a detached throwaway worktree.
- "Instrument until it fires", Cursor `/loop`, Grok, Opening a PR. `PB:bug-fix.md:7-9,13`. D8.
- Hand-rolled Playwright / Puppeteer as a rung. `PO:engineering/diagnosing-bugs/SKILL.md:29`. Use `browser_verify` when set; otherwise ask.
- Flat "do not add guards" vs layers everywhere. `PS:principle-fix-root-causes/SKILL.md:16`, `SP:systematic-debugging/defense-in-depth.md:7`. Reconcile: silencing guards are symptom fixes; loud throws at boundaries the trace crossed are allowed; compat nets are not.
- "Implement appropriate handling (retry, timeout)" when no cause is found. `SP:systematic-debugging/SKILL.md:272`. Only as a loud, documented path.
- `CREATION-LOG.md`, `test-pressure-*.md`. Meta cluster material.

**Merged skill spec**

- Name: `diagnose`. Type: discipline. Invocation: auto. Reason: must fire before a fix is proposed. Avoids the common bare name `debug`. Project wrappers (ticket intake, evidence agents) call it for the method.
- Project inputs: `test.focused`, `test.full`, `browser_verify`, `read_only_systems`, `evidence_agents`.
- Description draft: `Use on any bug, failing or flaky test, build break or unexpected behavior, before proposing a fix: red-capable repro loop, minimise, ranked falsifiable hypotheses, root cause, fix at source with a regression test.`
- Steps:
  1. Stop the line; save the exact symptom; redact secrets; treat error text as data. [AD debug:21-34,272-279; PO diag:12-16]
  2. Build the loop in cost order (focused test, HTTP call to a local service, CLI fixture diff, `browser_verify`, captured-trace replay, throwaway harness, fuzz loop, bisection in a detached worktree, differential run, HITL script). For data in `read_only_systems`, the loop is read-only queries through `evidence_agents`. Exit: one already-run red-capable command. [PO diag:18-66; D3; D8]
  3. Reproduce the reported symptom; minimise. [PO diag:68-86]
  4. Investigate: full error text, recent changes, boundary instrumentation, backward trace, working-example diff. [SP SD:48-141]
  5. Hypotheses: 3–5 ranked with predictions, shared without blocking; one variable per probe; tagged logs. [PO diag:88-110]
  6. Failure ladder: revert refuted work; two failures on a premise → census; three → stop and escalate (D5). [PB bug-fix:5; PS attack:9-21; SP SD:191-212]
  7. Fix at the source via `implement`: regression test at a correct seam, repro before fix in history, no silencing guards. [PO diag:114-128; PS sequence:15]
  8. Verify with the same loop, then `test.full`. [PB bug-fix:10]
  9. Cleanup: no tagged logs, throwaway harnesses deleted, hypothesis recorded; same pattern elsewhere is reported, and fixes outside scope become a separate item (D9). [PO diag:130-138; PS fix-root:18]
- References: `references/root-cause-tracing.md`, `references/flaky-and-async.md`, `references/forensics.md`, `references/triage-trees.md`, `references/defense-in-depth.md` (with the reconcile rule).
- Scripts: `find-polluter.sh` (test command as an argument; the source hardcodes `npm test` at `:51`), `hitl-loop.template.sh`.
- Estimated SKILL.md: 7 KB.

---

## 5. Performance

Job: make a measured number move, and prove the number measured the work. Phase: optimize.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| benchmark-checklist | PS | 5002 | slash | Seven questions before a perf number is used |
| principle-explain-the-number | PS | 1663 | slash | Limiter plus alternative explanations |
| perf-issue | PB | 1446 | router | Mantras cheapest first |
| hillclimb | PB | 4403 | router | Frozen harness, decision log, keep or revert |
| performance-optimization | AD | 16678 + 9692 | auto | Measure, identify, fix, keep-or-revert, guard |
| performance-checklist | AD ref | 13139 | ref | Plans, indexes, pools, caching |
| web-performance-auditor | AD | 12278 | agent | Quick vs Deep, metric honesty |
| /webperf | AD | 1974 | slash | Wrapper |
| diagnosing-bugs (perf branch) | PO | (in 8664) | auto | Baseline then bisect |

**Strongest mechanisms to keep**

- Claim sentence first; read the measurement script; check machine load. `PS:benchmark-checklist/SKILL.md:13-17`.
- Seven questions: limiter, tuned, limits arithmetic, errors counted, A/B alternating ≥5 runs with median and range, end-to-end share, work actually happened. `PS:benchmark-checklist/SKILL.md:19-27`.
- Inconclusive rules. `PS:benchmark-checklist/SKILL.md:29-34`.
- Mantras in cost order. `PB:perf-issue.md:7-16`.
- Hillclimb: reproducing workload, predicate with a minimum attempt count, harness proven sensitive then frozen and printing error and work counts, decision log, full revert inside noise, parallel hypotheses in separate worktrees, never relax the predicate. `PB:hillclimb.md:7-18`.
- Keep-or-revert table; neutral is a revert; correctness gates the metric; reverted attempts logged. `AD:skills/performance-optimization/SKILL.md:139-172`.
- Symptom-to-measurement tree. `AD:skills/performance-optimization/SKILL.md:73-97`.
- Query plan before and after; unchanged plan → revert the index. `AD:references/performance-checklist.md:96-111`.
- Pool exhaustion: find the holder before resizing. `AD:references/performance-checklist.md:113-118`.
- Cache key carries tenant, viewer, locale, permissions; staleness window stated; stampede protection. `AD:references/performance-checklist.md:154-183`. A missing viewer key leaks one user's data to another.
- Metric honesty: static findings are "potential impact"; field vs lab labelled. `AD:agents/web-performance-auditor.md:41-51`.
- Identify the framework before recommending idioms. `AD:agents/web-performance-auditor.md:55`.

**Drop**

- Grok, commit per accepted fix, Cursor `/loop`, Opening a PR. `PB:hillclimb.md:9,12,15-16,19`. D1, D2.
- Timing code left in shipped code (`console.time`, `onLCP(console.log)`). `AD:skills/performance-optimization/SKILL.md:53-70`.
- DevTools MCP live capture and CrUX / PSI API keys as defaults. `AD:agents/web-performance-auditor.md:20-25`. Optional; external API calls need approval (D2).
- Fixed web budgets and CI gates as defaults. `AD:skills/performance-optimization/SKILL.md:191-210`. Optional reference.

**Merged skill spec**

- Name: `perf`. Type: specialist. Invocation: slash-only. Reason: rare and measurement-heavy; "explain the number before reporting it" belongs in the verify cluster's evidence gate, which is always on.
- Project inputs: `test.full`, a `bench` or `profile` command if declared, `browser_verify` for web work, `shared_services` (benchmarks against a shared DB serialize).
- Description draft: `Measure-first performance work: vet the baseline, find the limiter, try the cheapest fix first, keep only changes that beat run-to-run noise with tests green, log reverted attempts. Use for /perf, slow endpoint/page/query, or a speedup claim.`
- Steps:
  1. Frame: claim sentence, metric and direction, workload, stop predicate. [PS bench:15; PB hillclimb:7]
  2. Baseline: one command, seven questions, sensitivity proven, frozen; regression gate green. [PB hillclimb:8; PS bench:19-27]
  3. Locate the limiter (profiler, query plan, network waterfall). [AD perf:73-120]
  4. Hypotheses ordered by the mantras, each naming a mechanism. [PB perf-issue:7-16]
  5. Loop: one change, A/B measurement, keep only past noise with tests green; log every attempt outside the tree; independent hypotheses may race via `parallel-work`. [AD perf:139-172; PB hillclimb:11-15]
  6. Plateau: pivot; stop at the predicate. [PB hillclimb:17-18]
  7. Guard where cheap. [AD perf:174-189]
  8. Report: verdict, number with unit, runs, range, limiter. [PS bench:29-34]
- References: `references/benchmark-checklist.md`, optional `references/stacks/sql-backend.md` (N+1, plans, indexes, pools, caching), optional `references/stacks/web-frontend.md` (CWV, re-renders, bundles, metric honesty).
- Agent: optional `perf-auditor` (read-only; static findings tagged "potential impact").
- Estimated SKILL.md: 5 KB.

---

## 6. Refactoring and simplification

Job: change structure without changing behavior; keep it only if reader load drops. Phase: maintain.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| refactoring | PB | 3211 | router | Pin, subtract, prove equivalence, reader-load test |
| principle-laziness-protocol | PS | 1371 | slash | Deletion first, flat hierarchy |
| principle-subtract-before-you-add | PS | 909 | slash | Removal before construction |
| principle-minimize-reader-load | PS | 1996 | slash | Layers to trace, state to hold |
| principle-build-the-lever | PS | 2386 | slash | Codemod or script, proven by rerun |
| code-simplification | AD | 13545 | auto | Chesterton's fence, one change per test run, Rule of 500 |
| /code-simplify | AD | 1068 | slash | Wrapper |
| setup-ts-deep-modules | PO | 7546 + 3712 | slash | Entry-point boundaries; prove the rule bites |

**Strongest mechanisms to keep**

- Pin behavior first; typecheck and lint are not a pin. `PB:refactoring.md:7`.
- Chesterton's fence questions with `git blame`. `AD:skills/code-simplification/SKILL.md:107-121`.
- Reshape deletes branches or invalid states, never adds indirection. `PB:refactoring.md:8-9`.
- Subtract first. `PB:refactoring.md:10`, `PS:principle-subtract-before-you-add/SKILL.md:13-18`.
- One simplification, one test run, revert on red. `AD:skills/code-simplification/SKILL.md:157-169`.
- Spot-check renames in strings and prose. `PB:refactoring.md:11`.
- Rule of 500 and build-the-lever, first unit by hand then the tool, proven by rerun diff. `AD:skills/code-simplification/SKILL.md:171`, `PS:principle-build-the-lever/SKILL.md:14-18`.
- Equivalence proof on the real artifact. `PB:refactoring.md:12`.
- Keep only if reader load drops (30-second test). `PB:refactoring.md:13`, `PS:principle-minimize-reader-load/SKILL.md:9-18`.
- Tests unchanged; modifying a test means behavior changed. `AD:skills/code-simplification/SKILL.md:311,323`.
- Over-simplification traps. `AD:skills/code-simplification/SKILL.md:92-99`.
- Refactor ships separately. `AD:skills/code-simplification/SKILL.md:159`.
- Pattern tables. `AD:skills/code-simplification/SKILL.md:123-155`.
- Prove a new rule bites (pass, violation fails, revert passes). `PO:in-progress/setup-ts-deep-modules/SKILL.md:79-87`.

**Drop**

- Blanket "no compatibility shims" and same-wave delete. `PB:refactoring.md:11`, `PS:principle-migrate-callers-then-delete-legacy-apis/SKILL.md:11-15`. Allowed only for internal code APIs with no persisted data and no consumer across a deploy window; otherwise D7 via `expand-contract`.
- `user.nickname || user.fullName` as the recommended idiom. `AD:skills/code-simplification/SKILL.md:211`. `||` drops `""`, `0`, `false`; teach the nullish operator of the stack when nullish is meant.
- Grok, `figure-it-out`, `how`, Opening a PR. `PB:refactoring.md:5,7,11,14`.
- Installing dependency-cruiser and editing `CLAUDE.md` as a default. `PO:in-progress/setup-ts-deep-modules/SKILL.md:47-95`. Repo-wide project decision, TS-only.
- "Fewer lines beat elegant boilerplate". `PS:principle-laziness-protocol/SKILL.md:14`. Reader load is the tiebreaker.

**Merged skill spec**

- Name: `refactor`. Type: phase. Invocation: slash-only. Reason: deliberate scoped work; Claude Code's built-in `/simplify` covers quick cleanup of a fresh diff, so avoid that name.
- Project inputs: `test.*`, `scope_threshold`, optional `codemod` tool.
- Description draft: `Behavior-preserving restructure: pin the contract with a characterization test, subtract first, small green steps, prove equivalence, keep only if reader load drops. Use for /refactor, never to add behavior.`
- Steps:
  1. Classify structural only; split out found bugs or features. [PB refactoring:3-5]
  2. Understand responsibility, every caller and writer, history, tests. [AD simp:107-121]
  3. Pin current behavior; green. [PB refactoring:7]
  4. Target shape and reader-load baseline. [PB refactoring:8-9]
  5. Subtract confirmed-dead code, one-caller wrappers, redundant validators. [PB refactoring:10]
  6. Small green steps; codemod for repetitive or large edits, proven by rerun diff. [AD simp:157-171; PS lever:14]
  7. API reshape: internal-only → migrate callers and delete in one change; persisted, shared or cross-deploy → stop, use `expand-contract` (D7). [PS migrate-callers:17-20]
  8. Prove: pin green with unmodified tests, equivalence check, renames spot-checked. [PB refactoring:11-12]
  9. Keep or revert by reader-load delta. [PB refactoring:13]
  10. Report structure change, pin, proof, delta, reverts.
- References: `references/simplification-patterns.md` (language-neutral tables), optional `references/stacks/<stack>.md` examples, link to `_shared/references/principles.md`.
- Estimated SKILL.md: 4.5 KB.

---

## 7. Migration and deprecation

Job: change persisted shapes and shared contracts while existing data and every deployed version keep working. Phase: maintain.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| deprecation-and-migration | AD | 12642 | auto | Expand, backfill, switch, contract; down path; zero usage before removal |
| principle-migrate-callers-then-delete-legacy-apis | PS | 1146 | slash | Same-wave caller migration when nothing external depends |
| principle-outcome-oriented-execution | PS | 1078 | slash | Planned intermediate breakage |
| principle-make-operations-idempotent | PS | 1390 | slash | Converges on rerun or crash |
| migrate-to-shoehorn | PO | 2795 | auto | `fromPartial` / `fromAny` instead of `as` in tests |

**Strongest mechanisms to keep**

- Expand/contract worked example. `AD:skills/deprecation-and-migration/SKILL.md:164-183`.
- Additive first, destructive last and alone; tested down path; batched backfills; non-blocking index builds. `AD:skills/deprecation-and-migration/SKILL.md:185-190`.
- Deprecation decision; replacement first; consumers one at a time; zero usage before removal. `AD:skills/deprecation-and-migration/SKILL.md:37-56,67-118`.
- Hyrum's Law. `AD:skills/deprecation-and-migration/SKILL.md:29-31`.
- Idempotency test. `PS:principle-make-operations-idempotent/SKILL.md:19-24`. Covers data migrations, re-imports and one-off scripts.
- Same-wave caller migration with its applicability conditions. `PS:principle-migrate-callers-then-delete-legacy-apis/SKILL.md:11-20`.
- `fromPartial` / `fromAny` in TS tests. `PO:misc/migrate-to-shoehorn/SKILL.md:65-103`. Goes to the TS stack reference.

**Drop**

- Planned intermediate breakage. `PS:principle-outcome-oriented-execution/SKILL.md:14-15`. D7.
- Feature-flag routing snippet. `AD:skills/deprecation-and-migration/SKILL.md:151-162`. Project flag mechanism.
- Public deprecation notice and "Celebrate". `AD:skills/deprecation-and-migration/SKILL.md:77-92,117`.
- Installing shoehorn as a step. `PO:misc/migrate-to-shoehorn/SKILL.md:20-24`. A new dependency needs approval.

**Merged skill spec**

- Name: `expand-contract`. Type: specialist. Invocation: auto with a narrow trigger. Reason: the failure class is data loss and silent backward-compat breaks; one ~250-char description is cheaper than one miss. Avoids the bare name `migration`.
- Project inputs: `schema_inspect`, `migration_create`, `deploy_path`, `read_only_systems`, flag mechanism if declared.
- Description draft: `Use when changing a persisted shape (column, document field, enum), a shared or cross-deploy API contract, or removing an old code path: observe stored shape and every writer, expand, backfill, switch reads, contract later; old data keeps working.`
- Steps:
  1. Observe the stored shape with `schema_inspect` (embedded document vs table matters) and list every writer and reader. Ask when `schema_inspect` is unset. [EX must-not-miss "observe before you model"]
  2. Classify: internal-only → same-wave caller migration with a codemod; persisted or cross-deploy → expand/contract. [PS migrate-callers:17-20; AD dep:164-190]
  3. Expand: additive migration via `migration_create` (never a hand-typed version), up and down both run locally. [AD dep:177,187]
  4. Dual-write and backfill: idempotent, batched, no seed or demo data. [AD dep:178-179,188; PS idempotent:9-24]
  5. Switch reads behind an explicit opt-in discriminator; add a regression test that loads pre-existing data. [AD dep:180]
  6. Contract in a separate later change after zero usage is shown (code search plus a read-only data query). [AD dep:108-118,181,186]
  7. Each phase is its own change along `deploy_path`; never couple a drop with the code that stops using it. [AD dep:166]
  8. Report a phase table with a rollback per phase.
- References: `references/expand-contract.md` (columns, document sub-shapes, API fields), `references/deprecation-decision.md`.
- Estimated SKILL.md: 4 KB.

---

## 8. UI building

Job: build UI that handles every state, keeps layout positions stable, and is checked in a real browser. Phase: build.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| frontend-ui-engineering | AD | 11721 | auto | Container/presentation, state ladder, explicit states, WCAG AA |
| visual-parity | PB | 1197 | router | Baseline first, image diff, no baseline tampering |
| typescript-best-practices | PS | 2684 + 9214 | slash (paths) | Discriminated unions, no `as`, exhaustiveness |
| testing-patterns (component part) | AD ref | (in 7460) | ref | Query by role and label |
| web-performance-auditor (rendering) | AD | (in 12278) | agent | Memo everywhere, over-eager effects |

**Strongest mechanisms to keep**

- Data container separate from presentation; loading, empty, error and permission states each rendered. `AD:skills/frontend-ui-engineering/SKILL.md:77-99,233-251,337`.
- Simplest state first. `AD:skills/frontend-ui-engineering/SKILL.md:101-114`.
- Composition over configuration; split large components. `AD:skills/frontend-ui-engineering/SKILL.md:36-75,322`.
- Keyboard, labels, focus, color never the only signal. `AD:skills/frontend-ui-engineering/SKILL.md:170-231`.
- Spacing scale and semantic tokens. `AD:skills/frontend-ui-engineering/SKILL.md:144-174`.
- Short design contract before building. `AD:skills/frontend-ui-engineering/SKILL.md:118-127`.
- Visual parity by image diff with baseline and harness untouched. `PB:visual-parity.md:5-8`.
- UI state as a discriminated union. `PS:typescript-best-practices/references/patterns.md:24-37`.
- Query components by role and label. `AD:references/testing-patterns.md:135`.
- Rendering anti-patterns (memo everywhere, over-eager effects). `AD:agents/web-performance-auditor.md:92-95`.

**Drop**

- Fixed breakpoint sweep as a default. `AD:skills/frontend-ui-engineering/SKILL.md:267,336`. Viewports come from `ui_rules`; some projects pin one viewport for determinism.
- "AI aesthetic" table. `AD:skills/frontend-ui-engineering/SKILL.md:129-142`. Aesthetics belong to a design plugin; keep "use the project's tokens".
- DevTools MCP verification. `AD:skills/test-driven-development/SKILL.md:312-341`. `browser_verify`.
- Per-component worktrees and Cursor `/loop`. `PB:visual-parity.md:7-8`.
- React-specific code as core content. `AD:skills/frontend-ui-engineering/SKILL.md:24-99,182-303`. Moves to an optional React stack reference.

**Merged skill spec**

- Name: `build-ui`. Type: specialist. Invocation: auto with a narrow trigger, or `paths:`-scoped to the project's UI directories if skills honour `paths:` (meta cluster to confirm). Reason: UI rules recur on every UI change and differ per project, so the skill is mostly a checklist that reads `ui_rules`.
- Project inputs: `ui_rules` (empty-value rendering, layout pairing rules, a11y bar, prop typing convention, config-to-control parity rules), `design_tokens`, `ui_test_utils`, `browser_verify`.
- Description draft: `Use when building or changing UI components or pages: explicit loading/empty/error/permission states, project empty-value rule instead of hidden fields, stable layout slots, a11y, typed props, checked in a browser via the project's verify command.`
- Steps:
  1. Find the sibling component (and the reference screen for parity work); write a 5-line design contract. [AD fe:118-127]
  2. Model state as a discriminated union or the stack's equivalent; split container from presentation. [PS TS patterns:24-37; AD fe:77-99]
  3. Build with `design_tokens` and composition; type props per `ui_rules`. [AD fe:36-75,144-174]
  4. Render every state; empty values follow `ui_rules` (ask if unset; never hide a field silently, D6); a hidden cell in a positional grid keeps its slot. [AD fe:233-251; EX recurring-review-patterns #3, #22]
  5. A11y: roles, labels, focus, keyboard, reduced-motion fallback for animation, visible focus. [AD fe:176-231]
  6. Every configurable option has its editing control, when `ui_rules` declares such a pairing. [EX template-field-conventions]
  7. Tests through `implement`: query by role and label; layout assertions via `ui_test_utils` when declared. [AD testing:135]
  8. Verify with `browser_verify`: inspect the page before writing selectors, confirm it finished loading and returned a non-error status, keep screenshots; image diff for parity work. Unset → ask (D6). [PB visual-parity:5-8; EX browser-verification]
- References: `references/ui-states-a11y.md` (stack-neutral), `references/visual-parity.md`, optional `references/stacks/react.md` (AD component, state and optimistic-update examples), link to `references/stacks/typescript.md`.
- Estimated SKILL.md: 4 KB.

---

## 9. Principles, type discipline and context hygiene

Job: the short rules every build skill cites, loaded on demand. Phase: all.

| Skill | Source | Bytes | Inv. | Core mechanism |
|---|---|---|---|---|
| principle-laziness-protocol / subtract / build-the-lever | PS | 1371 / 909 / 2386 | slash | Smallest change, removal first, tools over hand edits |
| principle-make-operations-idempotent / separate-before-serializing | PS | 1390 / 1565 | slash | Convergent re-runs; own write targets |
| principle-sequence-verifiable-units / minimize-reader-load / explain-the-number | PS | 1705 / 1996 / 1663 | slash | Brackets; layers and state; limiter |
| principle-fix-root-causes / attack-the-premise / test-behavior | PS | 1246 / 1941 / 1386 | slash | Used by categories 3–4 |
| typescript-best-practices | PS | 2684 + 9214 | slash (paths) | Type-system rules with examples |
| poteto-agent | PS | 686 | agent | Router agent |
| context-engineering | AD | 15486 | auto | Context hierarchy, confusion management, restart boundaries |
| setup-ts-deep-modules | PO | 7546 | slash | Lint-enforced module boundaries |

**Strongest mechanisms to keep**

- Principle-leaf format: rule, reason, explicit test. `PS:principle-make-operations-idempotent/SKILL.md:19-24`, `PS:principle-minimize-reader-load/SKILL.md:18`.
- A lever cited with no script in the diff was not applied. `PS:principle-build-the-lever/SKILL.md:18`.
- Before/after bracket per unit. `PS:principle-sequence-verifiable-units/SKILL.md:13`.
- Explain the number. `PS:principle-explain-the-number/SKILL.md:9-15`.
- Type rules: `unknown` over `any`, no unvalidated `as`, narrowing order, lying guards, exhaustiveness, `satisfies`, derived types. `PS:typescript-best-practices/SKILL.md:12-29`. Stack reference, not core.
- Confusion management: surface conflicts with options; never invent requirements. `AD:skills/context-engineering/SKILL.md:253-298`. D5.
- Read before editing; one existing example; trust levels for loaded files. `AD:skills/context-engineering/SKILL.md:88-103`.
- Feed back one failing error; long output to a file, read the tail. `AD:skills/context-engineering/SKILL.md:105-111`, `SP:executing-plans/SKILL.md:166-168`.
- Compress before dropping; protect the task definition and current error. `AD:skills/context-engineering/SKILL.md:204-230`.
- Prove a structural rule bites. `PO:in-progress/setup-ts-deep-modules/SKILL.md:79-87`.

**Drop**

- `poteto-agent`. `PS:../agents/poteto-agent.md:1-9`.
- CLAUDE.md template and tool-specific rules files. `AD:skills/context-engineering/SKILL.md:38-79`. Meta cluster.
- MCP integrations table. `AD:skills/context-engineering/SKILL.md:241-251`.
- "Trim at 75% capacity". `AD:skills/context-engineering/SKILL.md:202`. The agent cannot trim its own window.
- "Executing unless you redirect" above reversible in-scope work. `AD:skills/context-engineering/SKILL.md:300-312`. D5.

**Merged artifact spec**

- Name: `_shared/references/principles.md`, `_shared/references/project-inputs.md`, `references/stacks/typescript.md`. Type: reference. Invocation: none; linked from the skills above. Reason: eleven principle descriptions plus context-engineering would cost ~3.5 KB of resident descriptions; references cost nothing until read.
- `principles.md`: one paragraph plus "the test" for laziness, subtract first, build the lever, idempotence, separate before serializing, sequence verifiable units, reader load, explain the number, confusion management, read before edit.
- `project-inputs.md`: section 0 of this document (D1–D12, keys, resolution order), the single place skills point to.
- `stacks/typescript.md`: PS rules and patterns, PO shoehorn, nullable-typing guidance.
- Estimated size: 5 KB + 3 KB + 6 KB.

---

## Cluster gaps (no source covers these well)

1. **Project input resolution.** No source has a project profile. Nearest: "check your instructions for a declared preference" (`SP:using-git-worktrees/SKILL.md:65-67`) and fixed spec paths (`AD:.claude/commands/build.md:31`). The key names, file format and the ask-once-then-record flow need design.
2. **Base commit of `isolation: "worktree"`.** No source says which commit an isolated agent worktree starts from; the entry check must assert it against `base_branch`.
3. **Worktree setup per stack.** Sources hardcode installs; monorepos with hoisted deps or required env files need the `worktree.setup` hook.
4. **Shared local services across parallel worktrees.** One local DB or fixed ports shared by every worktree; migrations from diverging branches collide. No source schedules this.
5. **Legacy-data regression fixtures** for evolving embedded document shapes.
6. **Authz and tenant-scope test matrix** (allow, deny, boundary, cross-tenant).
7. **Escalation parking mid-plan**: park one task with a default, continue disjoint tasks, batch questions (PB orchestrate `gates.md` at `:105` is closest).
8. **Commit consent in delegated worktrees**: review ranges want commits, D1 forbids them unless asked. The plan format needs a consent field, or reviews run on diff hashes.
9. **Claude model tier table** per role and effort.
10. **Full-suite budget across a parallel wave.**
11. **Flaky-test policy** (quarantine and ownership).
12. **Shared ledger location** outside any worktree.
13. **Generated artifacts** in the done checklist.
14. **Read-only differential debugging** when the failing data sits in a read-only system.
15. **Stack references beyond TS/JS.** All stack depth in the sources is TypeScript or JavaScript.

## Cross-cluster dependencies

- **Meta:** owns the project-profile format, the resolution order, D1–D12 wording (shared by every cluster), whether skills honour `paths:`, the description budget, agent file locations, and the SP skill-testing material.
- **Define / plan:** the plan format must carry per-task file lists, Interfaces / Produces / Consumes, Global Constraints, seams, Review Focus and a commit-consent field.
- **Review:** task and final reviewer prompts reuse the review cluster's reviewer and severity taxonomy; round ≥2 is scoped to the diff since the last reviewed SHA.
- **Verify:** evidence gate, "explain the number", "inconclusive is not a pass", and the `browser_verify` contract.
- **Ship:** push, PR, tracker updates, `commit.convention` and worktree teardown after `execute-plan` hands off.
- **Project wrappers:** ticket-intake skills and read-only evidence agents in a project call `diagnose` and `expand-contract` rather than duplicating their method.
