# superpowers + addy audit (part 1: counts, notes, superpowers rows 1-19)

Codes: EQ = KERN-EQUAL-OR-BETTER, PLAN = SOURCE-BETTER-PLANNED, GAP = SOURCE-BETTER-UNPLANNED, REJ = REJECT-CANDIDATE.

| Source | Mechanisms | EQ | PLAN | GAP | REJ |
|---|---|---|---|---|---|
| superpowers 6.4.1 | 35 | 15 | 7 | 4 | 9 |
| addy 0.6.12 | 45 | 14 | 17 | 5 | 9 |

Notes:
- superpowers 6.4.1 ships no agents/ or commands/; its reviewer is the prompt file requesting-code-review/code-reviewer.md.
- Many M3-M6 PLAN rows are detailed only in docs/research/merge-*.md; the design spec has one line per skill, so plans can be dropped silently. Two already were (U2, U7).
- m1-compare item 9 ("no ADR shape") is planned: decision records in domain-model, M5.
- m1-compare item 6 ("CI Linux only") splits: macOS leg is a GAP (U8); Windows leg is REJ.

## superpowers

| # | Mechanism | Source | By | kern counterpart | V | Reason |
|---|---|---|---|---|---|---|
| 1 | SessionStart router injection | hooks/hooks.json:4-12, hooks/session-start | code | hooks/session-start, kernel/kernel.md (M1) | EQ | Same path; project skills outrank kern; lower standing cost |
| 2 | 1% rule, announce, one todo per item | using-superpowers/SKILL.md:11-24 | prose | kernel.md:16 routing rule + T22 adherence grader (M2) | EQ | Observable rows; steps copied verbatim and graded |
| 3 | Rationalization and red-flag tables | TDD, verification, debugging SKILL.md files | prose, pressure-tested | none | GAP | U1 |
| 4 | HARD-GATE; spike, bounded, architectural; spec reviewer | brainstorming/SKILL.md:38-88 | prose | define C1 (M2) | EQ | Explicit-yes rule; status: approved checked downstream |
| 5 | Commit the spec and plan | brainstorming:135,244; writing-plans:10 | prose | D1 | REJ | |
| 6 | Visual companion server, owner-PID watchdog, idle stop | server.cjs:554,634-642; 9 files in tests/brainstorm-server/ | code | spec 7.4-7.5 (M4) | PLAN | Port the tests with the server; M4 acceptance has 3 checks |
| 7 | Telemetry logo | server.cjs:106-112 | code | removed (7.5) | REJ | |
| 8 | writing-plans + plan reviewer | writing-plans/* | prose | plan C2 (M2) | EQ | |
| 9 | SDD controller, three prompts, model per role | subagent-driven-development/* | prose | execute-plan C3, agents D, A10 (M2) | EQ | Review without commits; reviewer read-only through tools |
| 10 | 5 fix rounds, then "rule and continue" | SDD:17-25,373-425 | prose | D5, D10; autopilot parked: | REJ | |
| 11 | task-brief, review-package, sdd-workspace | SDD/scripts/* | code | task-brief, wt-diff, kern-dir (M2 T2, T4) | EQ | Brief fence-aware; packages include untracked files |
| 12 | Ledger written only when the test passes | executing-plans/scripts/task-done:43-46 | code | task-done (M2 T4) | EQ | |
| 13 | TDD iron law + writing-good-tests | test-driven-development/* | prose | implement C5 (M2) | EQ | Adds a mutation probe |
| 14 | "Delete means delete" | TDD:37-45 | prose | none | REJ | |
| 15 | 4-phase debugging, 3-fix stop, tracing, waiting, find-polluter + test | systematic-debugging/* | prose+code | diagnose C6, find-polluter.bats (M2 T12) | EQ | Adds a red-capable loop gate before hypotheses |
| 16 | Defense-in-depth layers | systematic-debugging/defense-in-depth.md | prose | dropped from M2 T12 | GAP | U7 |
| 17 | Pressure scenarios; RED/GREEN/PRESSURE runs | test-pressure-1..3.md, testing-skills-with-subagents.md, test-worktree-native-preference.sh | tests | spec 11.1 tier 2 (M6) | PLAN | M2 discipline skills ship without a pressure test |
| 18 | verification-before-completion | its SKILL.md | prose | prove-it C7 + claim-check and probe scripts (M2 T6) | EQ | Fail-then-pass is a script |
| 19 | Requesting review; "Declined to judge" list | requesting-code-review/* | prose | self-review (M2); pr-review lanes (M3, merge-ship.md:250) | PLAN | |

# part 2: superpowers rows 20-35 (paths under .upstream/superpowers/skills/ unless noted)

| # | Mechanism | Source | By | kern counterpart | V | Reason |
|---|---|---|---|---|---|---|
| 20 | Receiving review: verify each comment first, YAGNI grep, no performative agreement, thread replies | receiving-code-review/SKILL.md | prose | take-feedback threads (M3; docs/research/merge-ship.md:311-341) | PLAN | kern adds G3/G4 posting gates |
| 21 | Worktrees: native EnterWorktree, .worktrees/ + committed .gitignore, consent, baseline tests | using-git-worktrees/SKILL.md | prose | wt-new, wt-check (M2 Task 1) | EQ | Fresh origin/<base> and entry check; SP branches off HEAD |
| 22 | Finish menu, discard only on typed word, never force | finishing-a-development-branch/SKILL.md | prose | finish-branch C10 + G1, G2 | EQ | Draft PR and dedup enforced by hooks |
| 23 | Merge-locally menu option | finishing-a-development-branch:60,90-96 | prose | floor action | REJ | |
| 24 | Parallel dispatch per failure domain | dispatching-parallel-agents/SKILL.md | prose | parallel-work C4 (M2) | EQ | One fork per writer |
| 25 | writing-skills: TDD for skills, description-as-trigger, micro-tests | writing-skills/SKILL.md | prose | write-skill (M6); lint, route-eval (M0) | PLAN | |
| 26 | render-graphs.js, graphviz conventions, with test | writing-skills/render-graphs.js; tests/writing-skills | code | none | REJ | |
| 27 | Persuasion principles for skill wording | writing-skills/persuasion-principles.md | prose | none | REJ | |
| 28 | Session forensics: parallel analysts (missed triggers, repeated work, stumbles, plan adherence, cost/time), cite or discard; per-subagent token breakdown | diagnosing-superpowers/prompts/*; tests/claude-code/analyze-token-usage.py | prose+code | retro (M6), detail only in docs/research/merge-meta.md:240-256 | PLAN | Detail only in merge map; no token script named |
| 29 | Redaction policy, scrub and scrub-audit passes | diagnosing-superpowers/references/redaction-policy.md, prompts/scrub*.md | prose | G6, lint rule 8 (scripts/lib/lint-rules.mjs:150-151) | GAP | U6 |
| 30 | Explicit-request test: fails when any non-todo tool runs before the skill; multi-turn and haiku variants | tests/explicit-skill-requests/run-test.sh:103-111, run-multiturn-test.sh | code | kernel-adherence grader (M2 Task 22) | GAP | U5 |
| 31 | End-to-end SDD run with a real model | tests/claude-code/test-subagent-driven-development-integration.sh | code | M6 nightly; M2 Task 23 no-commit-review.bats runs no model | PLAN | |
| 32 | Hook output shape test | tests/hooks/test-session-start.sh | code | session-start.bats, tests/hook-shape.sh over 7 fixtures (M1) | EQ | |
| 33 | Version bump, shell lint, release notes | scripts/bump-version.sh, .version-bump.json, scripts/lint-shell.sh | code | release.mjs, check-version.mjs, CI shellcheck | EQ | |
| 34 | Windows polyglot hook runner | hooks/run-hook.cmd; docs/windows/polyglot-hooks.md | code | none | REJ | |
| 35 | Other harnesses (Cursor, Codex, OpenCode, Pi, Kimi, Hermes, Devin, Gemini) | hooks/hooks-cursor.json, .codex-plugin, scripts/sync-to-codex-plugin.sh, tests/* | code | none | REJ | |

# part 3: addy table (45 mechanisms, paths under .upstream/addy/)

| # | Mechanism | Source | By | kern counterpart | V | Reason |
|---|---|---|---|---|---|---|
| 1 | Router skill and session-start hook (not wired) | skills/using-agent-skills; hooks/session-start.sh:5-8 | prose; hook off | kernel (M1) | EQ | Hook-injected; addy listing 9.3k chars |
| 2 | interview-me, spec-driven, /spec stops the turn | skills/spec-driven-development:170-174 | prose | define C1 steps 5, 7, 10 (M2) | EQ | |
| 3 | idea-refine with frameworks and idea-refine.sh | skills/idea-refine/* | prose | define ideate mode, M5 (X22) | PLAN | |
| 4 | planning-and-task-breakdown, /plan | skills/planning-and-task-breakdown | prose | plan C2 (M2) | EQ | |
| 5 | One tracker item per task | planning-and-task-breakdown:162 | prose | G14; tracker drafts only | REJ | |
| 6 | incremental-implementation, NOTICED BUT NOT TOUCHING, /build, /build auto | skills/incremental-implementation; .claude/commands/build.md | prose | implement C5, execute-plan, autopilot (M1) | EQ | Autopilot bounded by hooks |
| 7 | Per-slice commits, reset --hard recovery, auto-merge, agent push loop | incremental-implementation:41; git-workflow-and-versioning:189; ci-cd-and-automation:181,307 | prose | D1, D3, floor, D2 | REJ | |
| 8 | TDD skill, testing-patterns, test-engineer agent, /test | skills/test-driven-development; references/testing-patterns.md; agents/test-engineer.md | prose | implement (M2); test-engineer and stack refs (M5) | PLAN | |
| 9 | debugging-and-error-recovery | skills/debugging-and-error-recovery | prose | diagnose C6 (M2) | EQ | Bisection in a detached worktree |
| 10 | "Safe fallbacks" under time pressure | debugging-and-error-recovery:216-238 | prose | D6 | REJ | |
| 11 | Five-axis review, change sizing, mutation probe, dependency-upgrade discipline, /review, code-reviewer agent | skills/code-review-and-quality; agents/code-reviewer.md | prose | self-review (M2); pr-review lane B (M3; merge-ship.md:241-262) | PLAN | |
| 12 | Doubt pass in a fresh context | doubt-driven-development:16-191 | prose | self-review step 7 (M2) | EQ | |
| 13 | Cross-model CLI reviewer (Gemini, Codex) | doubt-driven-development:116-135 | prose | none | REJ | |
| 14 | code-simplification, /code-simplify | skills/code-simplification | prose | refactor (M5) | PLAN | |
| 15 | Security skill, references, security-auditor | skills/security-and-hardening/*; agents/security-auditor.md | prose | security-auditor and refs (M3; merge-ship.md:393-409) | PLAN | |
| 16 | Performance skill, references, web-performance-auditor, /webperf | skills/performance-optimization/*; agents/web-performance-auditor.md | prose | perf, perf-auditor (M5) | PLAN | |
| 17 | Frontend UI skill, accessibility checklist | skills/frontend-ui-engineering; references/accessibility-checklist.md | prose | build-ui (M5; merge-build.md:582) | PLAN | |
| 18 | API design: contract first, error shape, idempotency keys | api-and-interface-design:156-215 | prose | architect (M5; merge-define.md:298-320) | PLAN | |
| 19 | deprecation-and-migration | skills/deprecation-and-migration | prose | expand-contract (M5) | PLAN | |
| 20 | browser-testing-with-devtools | skills/browser-testing-with-devtools | prose | verify-app, verify.browser (M5) | PLAN | Project harness first |
| 21 | source-driven-development | skills/source-driven-development | prose | explain research mode (M5; merge-define.md:244) | PLAN | |
| 22 | context-engineering | skills/context-engineering | prose | kernel/context.md (M1), execute-plan step 13, handoff (M6) | EQ | |
| 23 | documentation-and-adrs | skills/documentation-and-adrs | prose | technical-writing (M1); decision records in domain-model (M5) | PLAN | "no ADR shape" is planned at M5 |
| 24 | git-workflow-and-versioning | skills/git-workflow-and-versioning | prose | commit, finish-branch (M2), G1, G5 | EQ | |
| 25 | shipping-and-launch; /ship GO/NO-GO with rollback | skills/shipping-and-launch; .claude/commands/ship.md | prose | ship-check (M5) | PLAN | |
| 26 | ci-cd-and-automation | skills/ci-cd-and-automation | prose | take-feedback ci (M3); ship-check ci.md (merge-ship.md:578) | PLAN | Partial |
| 27 | Observability skill and checklist | skills/observability-and-instrumentation; references/observability-checklist.md | prose | ship-check ref only in merge map (merge-ship.md:578); not in spec | GAP | U3 |
| 28 | Floor guard with reference test | skills/constraint-driven-development/references/floor-guard.md; scripts/floor-guard-reference-test.js | code | floor-scan (M2 Task 5); G7 Stop hook (M3) | EQ | kern has more patterns |
| 29 | Bar-moved checks (threshold loosened, rule removed, new exception), ratchet, one external check | floor-guard.md; constraint-driven-development:202-232 | code+prose | none; merge-ship.md §10 kept, spec G7 dropped | GAP | U2 |
| 30 | /constraints writes CONSTRAINTS.md, edits CLAUDE.md, installs tools | .claude/commands/constraints.md:19-25 | prose | none | REJ | |
| 31 | definition-of-done, orchestration-patterns refs | references/* | prose | prove-it step 5; parallel-work ref (M2) | EQ | |
| 32 | Skill lint with test | scripts/lib/skill-lint.js | code | lint rules 1-15 | EQ | Required sections under U1 |
| 33 | Reference-link and version validators with tests | scripts/validate-reference-links.js, validate-versions.js | code | lint rule 4, check-version.mjs | EQ | |
| 34 | Artifact-path pipeline validator with test | scripts/validate-artifact-paths.js | code | contract.md + per-file assertContains | GAP | U4 |
| 35 | Multi-host command parity; TOML/Gemini | scripts/validate-commands.js; commands/*.toml; .gemini/ | code | none | REJ | |
| 36 | Routing tier: TF-IDF, top_k, owners, collision check, --min-rank1 95, runner test | scripts/run-evals.js:208-396 | code | route-eval.mjs (M0) + distractors, kernel rows (M2 Task 21) | EQ | kern floor 0 today, only rises |
| 37 | Behavioural runner (fixture to temp repo, claude -p, LLM grader); 34 cases, 50 fixtures, pressure cases | scripts/run-evals.js:403-640; evals/cases; evals/fixtures | code | schema linted; runner at M6; M2 adherence grader only | PLAN | Timing gap T1 |
| 38 | claude plugin eval, with and without the plugin | evals/plugin/*; plugin.json experimental.evals | code | spec 11.1 tier 2; skill-eval (M6) | PLAN | |
| 39 | Rejected-change ledger | evals/skill-impact.md | doc | evals/rejected.md, .out-of-scope (11.4) | EQ | |
| 40 | CI install smoke test | .github/workflows/test-plugin-install.yml:148-167 | code | ci.yml validates only | GAP | U8 |
| 41 | CI macOS leg | test-plugin-install.yml:77-82 | code | ubuntu only; macOS via manual ci-local | GAP | U8 |
| 42 | CI Windows leg | test-plugin-install.yml:77-82 | code | none | REJ | |
| 43 | sdd-cache WebFetch hooks with test | hooks/sdd-cache-pre.sh, sdd-cache-post.sh | code | none | REJ | |
| 44 | simplify-ignore hook with test | hooks/simplify-ignore.sh:312-350 | code | none | REJ | |
| 45 | Contributor rules, skill-anatomy doc | .claude/rules/skills-contributing.md; docs/skill-anatomy.md | prose | write-skill (M6; merge-meta.md:356) | PLAN | |

# part 4: GAP list (U1-U8, T1) and REJ list

U1 Anti-rationalization sections (S; SP 3, addy 32): SP's TDD/verification/debugging carry rationalization and red-flag tables from pressure tests; addy lint fails a skill without "## Common Rationalizations" and "## Red Flags" (scripts/lib/skill-lint.js:75-79). kern rule 9 requires only "## Steps". Home: short tables in prove-it, implement, diagnose (M2 Tasks 10-12); rule 9 requires them for discipline skills. Zero standing cost.
U2 "Bar lowered" class in floor-scan (M; addy 29): loosened threshold, removed rule, new exception (floor-guard-reference-test.js:166-209); ratchet (constraint-driven-development:226-232). merge-ship.md §10 kept; spec G7 dropped. Home: M2 Task 5 patterns (coverage threshold lowered, tsconfig strict off, lint rule off, CI step deleted or continue-on-error); ratchet.<metric> keys in spec 5.4 read by self-review.
U3 Build-time observability (S-M; addy 27): on-call questions first, correlation/entry-point ID, RED metrics, symptom alerts, prove telemetry by forcing an error. kern: only a ship-check ref in merge-ship.md:578, not in the design spec. Home: M5 references/observability.md from implement and plan ("observability" checklist item) and ship-check.
U4 Contract-drift lint (S; addy 34): pair every token a skill reads with a producer, checked against docs/plans/contract.md. Home: M2 Task 21.
U5 Adherence grader matches the kernel (S; SP 30): kernel.md:16 says route before the first tool call or question; M2 Task 22 pass rule (M2 plan:4513) only needs it before the first Edit or Write. SP fails any non-todo tool before the skill (run-test.sh:103-111) and tests mid-conversation. Home: M2 Task 22: tighten pass rule, add multi-turn case.
U6 Redaction before project evidence enters kern_repo (S; SP 29): lint rule 8 checks machine paths and names, G6 secrets; neither catches hostnames, org IDs, proprietary terms; kern repo is pushed to GitHub. Home: M6 scrub step in retro and correct; lint rule 8 "proprietary" list in ~/.claude/kern.yml.
U7 Defense-in-depth reference (S; SP 16): merge-build.md:366 planned references/defense-in-depth.md; M2 Task 12 dropped it. Home: M2 Task 12.
U8 CI install smoke test + macOS leg (S; addy 40, 41): bash 3.2 / BSD awk only in manual ci-local (M2 plan:4856). Home: M2 Task 23.
T1 Planned too late (M; SP 17, addy 37): lint rule 12 forces one behavioural case per auto skill and kernel row; M2 acceptance says "Each skill's eval cases pass"; nothing runs them until M6. Fix: port addy's on-demand --behavioral runner into M2 Task 22; pressure tests for M2 discipline skills same gap.

REJ:
1 Commits by default (SP 5, addy 7): D1, goal 3.
2 "Delete means delete" (SP 14): kernel "Ask first: deletes".
3 Merge-locally (SP 23); auto-merge, agent push loop, reset --hard (addy 7): floor, D2, D3.
4 "Rulings, not stalls", 5-round fix loop (SP 10): D5, D10.
5 One tracker item per task (addy 5): D2, G14.
6 Safe fallbacks (addy 10): D6.
7 Telemetry logo (SP 7): goal 3; spec 7.5 removes it.
8 sdd-cache hooks (addy 43): goal 3 (own network requests); writes .claude/sdd-cache/ outside .kern/ (D-8).
9 simplify-ignore (addy 44): D3; rewrites tracked source in place, restores only at Stop.
10 /constraints (addy 30): spec 5.1 (kern never edits project rules); machine-wide installs vs goal 3.
11 Cross-model CLI reviewer (addy 13): non-goal model routing to non-Claude models.
12 Other harnesses, multi-host parity (SP 35, addy 35): non-goal other coding tools (D-3).
13 Windows runner and CI leg (SP 34, addy 42): personal scope (D-2), bash-only hooks (8.4 rule 1). Judgment call; revisit if a Windows machine is added.
14 Graphviz flowcharts (SP 26): A7 todo idiom needs numbered ## Steps.
15 persuasion-principles (SP 27): spec 5.1 precedence; authority wording would compete with project rules.
