<!-- Source re-audit of 2026-10-17 against kern 0.3.0 (tag v0.3.0, eee601d), superpowers 7.0.0 (bb92a77; old pin 5bf4e78, 6.4.1) and addy agent-skills 0.6.13 (aeac41d; old pin 1be8e34, 0.6.12). Source paths are relative to .upstream/superpowers/ or .upstream/addy/; kern paths are relative to the repo root. Read-only lane output, kept as the evidence behind docs/specs/coverage.md. -->

Counts. superpowers 7.0.0: 57 mechanisms; Equal or better 26, Planned 10, Gap 8, Rejected 13. addy 0.6.13: 49 mechanisms; Equal or better 20, Planned 19, Gap 1, Rejected 9. Rows whose verdict moved: 10 (superpowers 5, addy 5).

Codes: EQ = Equal or better, PLAN = Planned, GAP = Gap, REJ = Rejected. A kern prose skill counts as built and tested when it ships with its structural test (tests/skills/<skill>.test.mjs); its behaviour is proven in M2b (workflow and pressure cases, docs/plans/2026-10-14-kern-m2b-plan.md:73-74). superpowers 7.0.0 ships no in-repo behaviour test for brainstorming either: its rebuild design says the evals live elsewhere (docs/superpowers/specs/2026-10-05-brainstorming-rebuild-design.md:150-152).

## superpowers

| # | Mechanism | Source | By | kern counterpart | V | Reason | Moved |
|---|---|---|---|---|---|---|---|
| 1 | SessionStart router injection | hooks/hooks.json:4-12, hooks/session-start | code | hooks/session-start, kernel/kernel.md; tests/hooks/session-start.bats, tests/hook-shape.sh | EQ | Same path; project skills outrank kern; lower standing cost. PATH independence is row 51 | |
| 2 | 1% rule, announce, one todo per item | skills/using-superpowers/SKILL.md:11-24 | prose | kernel/kernel.md:16 (route before the first tool call; Steps copied verbatim into the todo list); kernel rows in tests/route-eval-rows.test.mjs | EQ | Built and routed; adherence grading moved to M2b (gap 10, row 30) | |
| 3 | Rationalization and red-flag tables | TDD, verification, debugging SKILL.md files | prose, pressure-tested | "## Red flags" in skills/prove-it/SKILL.md:40, skills/implement/SKILL.md:45, skills/diagnose/SKILL.md:43; lint rule 9 requires a 2-6 row table in discipline skills (scripts/lib/lint-rules.mjs:334-350; tests/lint-rules.test.mjs) | EQ | Built in M2a (gap 7). Pressure tests stay row 17 | GAP -> EQ |
| 4 | Hard gate before building; spike stays throwaway | skills/brainstorming/SKILL.md:179-193 (7.0.0) | prose | skills/define/SKILL.md:22 (spike in a `wt-new --detach` worktree), :26 (standing gate); guard G20 denies an approval without a whole-line quote of the user's yes (tests/hooks/g20.bats, g20-probes.bats) | EQ | kern enforces the gate in code; superpowers in prose, and 7.0.0 drops the gate on an opt-out. The classification and the spec reviewer that this row also held are re-judged in rows 43 and 44 | scope narrowed |
| 5 | Commit the spec and plan | brainstorming:157; writing-plans:10 | prose | D1 | REJ | Goal 3 | |
| 6 | Visual companion server, owner-PID watchdog, idle stop | skills/brainstorming/scripts/server.cjs:554,634-642; tests/brainstorm-server/ | code | design spec 7.4-7.5 (M4) | PLAN | M4. Port from 7.0.0, not 6.4.1 (row 48) | |
| 7 | Telemetry logo | server.cjs:106-112 | code | removed (design spec 7.5) | REJ | Goal 3 | |
| 8 | writing-plans with a plan reviewer | skills/writing-plans/SKILL.md | prose | skills/plan/SKILL.md:25 (plan-check, self-review, a fresh reviewer on `model.reviewer`); tests/skills/plan.test.mjs, tests/scripts/plan-check.bats | EQ | 6.4.2 removed superpowers' plan-document-reviewer-prompt.md; kern keeps a lint and a reviewer. Step content is row 50 | |
| 9 | SDD controller, three prompts, model per role | skills/subagent-driven-development/* | prose | skills/execute-plan, agents/implementer.md, agents/task-reviewer.md; tests/scripts/no-commit-review.bats, ledger.bats | EQ | Review without commits; reviewer read-only | |
| 10 | 5 fix rounds, then "rule and continue" | SDD:17-25,373-425 | prose | D5, D10; autopilot parks | REJ | D5, D10 | |
| 11 | task-brief, review package, sdd-workspace | SDD/scripts/* | code | scripts/task-brief, wt-diff, kern-dir; tests/scripts/brief-check.bats, wt-snap-diff.bats, kern-dir.bats | EQ | Brief fence-aware; packages include untracked files. 7.0.0 fixes are row 52 | |
| 12 | Ledger written only when the test passes | skills/executing-plans/scripts/task-done:43-48 | code | scripts/task-done:85-108; tests/scripts/task-done.bats:71-94 | EQ | kern also needs an approved review of the same tree and a fail-then-pass probe. Silent pass is row 53 | |
| 13 | TDD iron law, writing-good-tests | skills/test-driven-development/* | prose | skills/implement; tests/skills/implement.test.mjs | EQ | Adds a mutation probe | |
| 14 | "Delete means delete" | TDD:37-45 | prose | none | REJ | Kernel "Ask first: deletes" (kernel/kernel.md:25) | |
| 15 | 4-phase debugging, 3-fix stop, tracing, find-polluter with test | skills/systematic-debugging/* | prose+code | skills/diagnose/SKILL.md:15-23; tests/scripts/find-polluter.bats, loop-rate.bats | EQ | Red-capable loop gate before hypotheses | |
| 16 | Defense-in-depth layers | systematic-debugging/defense-in-depth.md | prose | skills/diagnose/references/defense-in-depth.md; tests/skills/diagnose.test.mjs:26,37 | EQ | Built in M2a (gap 11), with a probe per layer | GAP -> EQ |
| 17 | Pressure scenarios; RED/GREEN/PRESSURE runs | test-pressure-1..3.md, testing-skills-with-subagents.md | tests | M2b Task 1 pressure cases (m2b plan:73) | PLAN | Home moved from M6 to M2b (gap 13) | |
| 18 | verification-before-completion | its SKILL.md | prose | skills/prove-it, scripts/claim-check, scripts/probe; tests/scripts/claim-probe.bats | EQ | Fail-then-pass is a script | |
| 19 | Requesting review; "Declined to judge" list | skills/requesting-code-review/* | prose | skills/self-review/SKILL.md:15-22 (deterministic pass, built-in code-review lane, spec lane on `kern:task-reviewer`, probes, doubt cycle, verdict with a Declined to judge list); tests/skills/self-review.test.mjs:25; evals/seeded-diffs | EQ | Built in M2a. PR-review lanes for others' PRs stay M3 (row 20) | PLAN -> EQ |
| 20 | Receiving review: verify each comment, YAGNI grep, no performative agreement | skills/receiving-code-review/SKILL.md | prose | take-feedback (M3) | PLAN | M3 | |
| 21 | Worktrees: native, .worktrees/, consent, baseline tests | skills/using-git-worktrees/SKILL.md | prose | scripts/wt-new, wt-check; tests/scripts/wt-new.bats | EQ | Fresh origin/<base>; entry check | |
| 22 | Finish menu, discard only on a typed word | skills/finishing-a-development-branch/SKILL.md | prose | skills/finish-branch; G1, G2; evals/exec finish-* cases | EQ | Draft PR and dedup enforced | |
| 23 | Merge-locally option | finishing-a-development-branch:60,90-96 | prose | floor | REJ | Merge floor | |
| 24 | Parallel dispatch per failure domain | skills/dispatching-parallel-agents/SKILL.md | prose | skills/parallel-work; tests/skills/parallel-work.test.mjs | EQ | One worktree per writer | |
| 25 | writing-skills: TDD for skills, description as trigger | skills/writing-skills/SKILL.md | prose | write-skill (M6); lint, route-eval | PLAN | M6 | |
| 26 | render-graphs.js, graphviz conventions | skills/writing-skills/render-graphs.js | code | none | REJ | Skills spec A7, numbered steps | |
| 27 | Persuasion principles | skills/writing-skills/persuasion-principles.md | prose | none | REJ | Design spec 5.1 precedence | |
| 28 | Session forensics with parallel analysts; token breakdown | skills/diagnosing-superpowers/prompts/*; tests/claude-code/analyze-token-usage.py | prose+code | retro (M6) | PLAN | M6 | |
| 29 | Redaction policy, scrub and scrub-audit passes | diagnosing-superpowers/references/redaction-policy.md | prose | gap 32 in docs/specs/coverage.md, M6 row of the design spec | PLAN | Homed since 2026-10-14 (gap 32, M6) | GAP -> PLAN |
| 30 | Explicit-request test: fails when any non-todo tool runs before the skill; multi-turn | tests/explicit-skill-requests/run-test.sh:103-111 | code | gap 10, M2b Task 2 (scripts/kernel-adherence.mjs, m2b plan:42) | PLAN | Homed in M2b; not built in M2a | GAP -> PLAN |
| 31 | End-to-end SDD run with a real model | tests/claude-code/test-subagent-driven-development-integration.sh | code | M2b workflow-execute-plan-ledger case (m2b plan:74,373) | PLAN | Home moved from M6 to M2b | |
| 32 | Hook output shape test | tests/hooks/test-session-start.sh | code | tests/hook-shape.sh over fixtures; tests/hooks/session-start.bats | EQ | | |
| 33 | Version bump, shell lint, release notes | scripts/bump-version.sh; tests/version-bump | code | scripts/release.mjs, check-version.mjs; tests/versions.test.mjs; CI shellcheck | EQ | | |
| 34 | Windows polyglot hook runner | hooks/run-hook.cmd | code | none | REJ | D-2, design spec 8.4 rule 1 | |
| 35 | Other harnesses | .codex-plugin, .cursor-plugin, .hermes-plugin, tests/* | code | none | REJ | Non-goal: other coding tools (D-3) | |
| 36 | Opening check: a quick, clear task is done at once, with no design and no approval | skills/brainstorming/SKILL.md:17-24,136 | prose | skills/define/SKILL.md:26 (standing gate on every path), :52 (red flag "Too simple to need a design"); kernel/kernel.md:16 (a user opt-out matches no route) | REJ | D-4 gated default and the skills spec C1 gate: every new behaviour gets a design and a quoted yes. Judgment call for the user: superpowers dropped this ceremony on purpose (rebuild design:121) | new |
| 37 | First message offers to skip the questions; on a skip, one line states the platform, language or medium chosen | brainstorming:28-39 | prose | kernel/kernel.md:16 honours an opt-out, but define never offers it and states no build choice on one | GAP | New gap N2 | new |
| 38 | Draw out the want before proposing: an open question about a real moment, menus only when stuck, "just guess" gets a concrete proposal | brainstorming:35-37,52-55,78-81 | prose | skills/define/SKILL.md:19 and references/interview.md:7-23 (hypothesis with confidence, one question at a time with a visible guess, a deliberately wrong guess for agreeable users), :25-27 (want versus should-want), :35 ("whatever you think" gets two concrete options), :37-39 (step back after two flat rounds); approaches only at step 10 | EQ | kern adds the confidence check and the step-back rule. kern's decision rounds lead with a recommended answer (SKILL.md:20), which superpowers' red flag "Options steer" (brainstorming:199) warns against; they come after intent, so this stays EQ | new |
| 39 | Ground to cover: what makes it special, why now, success, goals, non-goals, anti-goals, prior art loved or hated, current state | brainstorming:67-76 | prose | restate: Outcome, User, Why now, Success, Constraint, Out of scope (SKILL.md:21; interview.md:31-33); spec Problem and Not doing (spec-template.md:13-19,65) | GAP | No anti-goals (what makes it a failure even if it technically works) and no prior art. New gap N4 | new |
| 40 | Offer recon of the project, the user's files or the web; the user decides | brainstorming:83-85 | prose | skills/define/SKILL.md:16 (investigators explore files, commits, PRs, stored shapes and the gap on origin/<base> by default, read-only; "Never ask the user a fact the repo can answer"); kernel/kernel.md:24 | EQ | kern does the project recon by default. Web prior art goes with N4 | new |
| 41 | Think wide privately; show the comparison only when it helps | brainstorming:87-90 | prose | skills/define/SKILL.md:24 (2 or 3 approaches, recommendation first) | EQ | | new |
| 42 | Play back each part in 200-300 words as it becomes clear, guesses marked, each chunk ends asking what is wrong or missing | brainstorming:112-127 | prose | a guess on every question (interview.md:18-21); restate with said versus assumed (SKILL.md:21; interview.md:31-35); spec Assumptions marked said or assumed (spec-template.md:29-31); architectural design approved section by section (SKILL.md:24) | EQ | kern's intent playback is one 5-8 line restate, but its guesses are visible per question and its design is approved per section | new |
| 43 | Size the work after understanding it, in plain words (quick task, small change, project with a written design); the user can override; step up if it grows; several projects one at a time | brainstorming:129-143 | prose | skills/define/SKILL.md:17 (classify spike, bounded or architectural at step 3, before intent at step 5; heavier in doubt; upgrade only); capability map for several capabilities (SKILL.md:18; references/capability-map.md) | GAP | kern sizes before it understands, and its own criteria (files touched, public API, schema) need the intent first; it says the class in process words. The capability map is equal or better. New gap N3 | new |
| 44 | Builder check: a fresh subagent reads the design as its builder and lists only questions where a wrong guess matters; the agent sorts them into answered, minor (settled and marked as its own call) and the user's; the user's go in one message, most important first; handover lists the calls made | brainstorming:160-177; builder-check-prompt.md:1-23 | prose | skills/define/SKILL.md:24 (self-review, one fresh reviewer with references/spec-review.md, round 1, "Fix its findings"); spec-review.md:5-13 checks placeholders, contradictions, scope, ambiguity, checkable constraints, Compatibility, Authorization, unrequested features | GAP | kern's reviewer checks the document; it never asks what the builder would still need, and nothing sends the questions only the user can answer to the user or lists kern's own calls. Replaces old row 4's reviewer half. New gap N1 | new |
| 45 | Written design: intent, goals, non-goals, anti-goals, constraints, the how they decided, what is left to the builder | brainstorming:145-158 | prose | skills/define/references/spec-template.md:13-67 (Problem, Intent, Constraints, Assumptions, Success and Acceptance criteria, Decisions, Compatibility, Authorization, Rollout, Test seams, Not doing, Open questions); plan-check (SKILL.md:23-24); tests/skills/define.test.mjs:32 | EQ | kern's spec is richer and linted. Anti-goals are N4; "left to the builder" is N1 | new |
| 46 | Build choices: ask which of platform, language, libraries or medium the user wants to own; state each default picked; build on existing work; record each as the agent's call; also on a skip | brainstorming:57-65,200 | prose | step 2 explores the existing repo (SKILL.md:16); decision rounds with recommended answers (SKILL.md:20); spec Decisions and Assumptions said or assumed (spec-template.md:29-31,41-43) | GAP | Nothing asks which build choices the user owns or names platform and language, so a greenfield ask can build the wrong platform, the failure superpowers fixed (#2482). New gap N2 | new |
| 47 | Visual companion offered whenever seeing helps: screens, layouts, flows, options that look different, diagrams; mockups beside the playback | brainstorming:92-102,205-225 | prose | skills/define/SKILL.md:20 (a page only for three or more options, and only with the visual skill); design spec 7.1 auto rule (:339) covers variants, design previews and diagrams | PLAN | M4 (auto thresholds). define's trigger is narrower than 7.1's list; M4 should widen it | new |
| 48 | Screen content inserted literally (`$'`, `$&` no longer read as replacement patterns), with a test | skills/brainstorming/scripts/server.cjs:264; tests/brainstorm-server/server.test.js:215 | code | design spec 7.5 (page server adapted from superpowers, M4) | PLAN | M4; the port must start from 7.0.0 | new |
| 49 | Brainstorming for any domain (a talk, a business, a renovation) | brainstorming:3 | prose | none; kern routes software work (kernel/routes.md:7) | REJ | Design spec section 1 and D-2: a personal Claude Code plugin for software work. Proposed rejection: goal 2 says kern covers every superpowers job, so this needs the user's yes | new |
| 50 | Plan steps record decisions, not code: a code step gives the signature, file and spec values, a body only for an algorithm they do not determine; a proportion check against the spec's length; the reader is capable; a step is one action with a checkable result | skills/writing-plans/SKILL.md:10,43-45,140-160,175 (6.4.2) | prose | skills/plan/SKILL.md:22 ("test-first steps with real code"); references/task-template.md:20-22 ("the real code"); plan-review.md:11 flags a step that does not show the code | GAP | superpowers measured the same 9/9 planted-defect result with a quarter of the time and a third of the tokens, and stopped Opus 5.5 building the project while planning (RELEASE-NOTES 6.4.2). kern still asks for full code and has no proportion check. New gap N5 | new |
| 51 | SessionStart works under an empty or broken PATH (claude-code#43127): no dirname, cat or bash lookup; tests run with PATH="" | hooks/session-start:6-26,62-69; tests/hooks/test-session-start.sh:220-318 | code | hooks/hooks.json:3 starts `bash` by name; hooks/session-start:5 calls `dirname`; under an empty PATH it resolves KERN_ROOT to `/` and prints "kern did not load ... reinstall kern" (:21-27), so the kernel is missing and the message misleads | GAP | New gap N6 | new |
| 52 | sdd-workspace leaves a committed .gitignore alone; repo-relative plan markers on Windows | skills/subagent-driven-development/scripts/sdd-workspace:48,84-86; tests/claude-code/test-sdd-workspace.sh | code | scripts/kern-dir:30-35 appends `/.kern/` to .git/info/exclude once and never writes a tracked file; exits 2 when the work dir holds tracked files; tests/scripts/kern-dir.bats | EQ | Windows half: REJ as row 34 | new |
| 53 | task-done records a task whose passing test prints nothing, with a test | skills/executing-plans/scripts/task-done:48; tests/claude-code/test-executing-plans-scripts.sh:136-150 | code | scripts/task-done:108 (an empty grep is tolerated, so the line ends with an empty `last=`) | GAP | Built but untested: every task-done.bats case that passes uses a command with output (task-done.bats:71-94). New gap N8 | new |
| 54 | Skill body free of `$1`, which Claude Code replaces with an argument word | skills/requesting-code-review/SKILL.md:55 | prose | no `$<digit>` or `$ARGUMENTS` in any kern SKILL.md body (grep over skills/*/SKILL.md); awk `$1` lives only in scripts (skills/diagnose/scripts/loop-rate.sh:43), which are not substituted | EQ | Neither side has a lint for it | new |
| 55 | Debugging example reports only whether a secret is set | skills/systematic-debugging/SKILL.md:91,95 | prose | skills/diagnose/SKILL.md:15 ("Redact secrets"); no example prints an environment value; G6 denies a staged secret | EQ | | new |
| 56 | Windows run-hook.cmd: per-user Git, skip WSL bash, ignore bash and where in the current directory, pass exit codes | hooks/run-hook.cmd:27-34; tests/hooks/test-run-hook-cmd-windows.sh | code | none | REJ | As row 34: D-2, design spec 8.4 rule 1 | new |
| 57 | Antigravity manifest; Hermes skill descriptions | .antigravity-plugin/plugin.json; .hermes-plugin/__init__.py:43 | code | none | REJ | As row 35: non-goal other coding tools (D-3) | new |

## addy

| # | Mechanism | Source | By | kern counterpart | V | Reason | Moved |
|---|---|---|---|---|---|---|---|
| 1 | Router skill and session-start hook (not wired) | skills/using-agent-skills; hooks/session-start.sh:5-8 | prose | kernel (M1); hooks/session-start | EQ | Hook-injected | |
| 2 | interview-me, spec-driven, /spec stops the turn | skills/spec-driven-development:170-174 | prose | skills/define/SKILL.md:19-24; tests/skills/define.test.mjs | EQ | Built in M2a | |
| 3 | idea-refine with frameworks and a script | skills/idea-refine/* (0.6.13 adds When to Use and Common Rationalizations, :12,163) | prose | define ideate mode, M5 (skills spec X22) | PLAN | M5; 0.6.13 is a structure change only | |
| 4 | planning-and-task-breakdown, /plan | skills/planning-and-task-breakdown | prose | skills/plan; tests/skills/plan.test.mjs, plan-check.bats | EQ | | |
| 5 | One tracker item per task | planning-and-task-breakdown:162 | prose | G14; tracker drafts only | REJ | D2, G14 | |
| 6 | incremental-implementation, NOTICED BUT NOT TOUCHING, /build auto | skills/incremental-implementation; .claude/commands/build.md | prose | skills/implement, skills/execute-plan, autopilot | EQ | Autopilot bounded by hooks | |
| 7 | Per-slice commits, reset --hard recovery, auto-merge, push loop | incremental-implementation:41 and others | prose | D1, D3, floor, D2 | REJ | | |
| 8 | TDD skill, testing-patterns, test-engineer agent, /test | skills/test-driven-development; agents/test-engineer.md | prose | skills/implement (built); test-engineer and stack refs (M5) | PLAN | M5 for the agent and refs. The 0.6.13 description change is row 47 | |
| 9 | debugging-and-error-recovery | skills/debugging-and-error-recovery | prose | skills/diagnose | EQ | Bisection in a detached worktree | |
| 10 | "Safe fallbacks" under time pressure | debugging-and-error-recovery:216-238 | prose | D6 | REJ | | |
| 11 | Five-axis review, change sizing, dependency-upgrade discipline, /review, code-reviewer agent | skills/code-review-and-quality; agents/code-reviewer.md | prose | skills/self-review (built: correctness, spec, blast radius, probes); finish-branch size gate; security and performance lanes in pr-review (M3) | PLAN | Security and performance axes at M3 | |
| 12 | Doubt pass in a fresh context | doubt-driven-development:16-191 | prose | skills/self-review/SKILL.md:21 (doubt cycle); tests/skills/self-review.test.mjs | EQ | | |
| 13 | Cross-model CLI reviewer | doubt-driven-development:116-135 | prose | none | REJ | Non-goal: non-Claude models | |
| 14 | code-simplification | skills/code-simplification | prose | refactor (M5) | PLAN | | |
| 15 | Security skill, references, security-auditor | skills/security-and-hardening/* | prose | M3 | PLAN | | |
| 16 | Performance skill, references, perf auditor | skills/performance-optimization/* (0.6.13 relabels code blocks) | prose | perf (M5) | PLAN | | |
| 17 | Frontend UI skill, accessibility checklist | skills/frontend-ui-engineering | prose | build-ui (M5) | PLAN | | |
| 18 | API design | api-and-interface-design:156-215 | prose | architect (M5) | PLAN | | |
| 19 | deprecation-and-migration | skills/deprecation-and-migration | prose | expand-contract (M5) | PLAN | | |
| 20 | browser-testing-with-devtools | skills/browser-testing-with-devtools | prose | verify-app (M5) | PLAN | | |
| 21 | source-driven-development | skills/source-driven-development | prose | explain research mode (M5) | PLAN | | |
| 22 | context-engineering | skills/context-engineering | prose | kernel/context.md; execute-plan resume from the ledger | EQ | | |
| 23 | documentation-and-adrs | skills/documentation-and-adrs | prose | technical-writing (M1); decision records (M5) | PLAN | | |
| 24 | git-workflow-and-versioning | skills/git-workflow-and-versioning | prose | skills/commit, skills/finish-branch; G1, G5; evals/exec | EQ | | |
| 25 | shipping-and-launch, /ship | skills/shipping-and-launch | prose | ship-check (M5) | PLAN | | |
| 26 | ci-cd-and-automation | skills/ci-cd-and-automation | prose | take-feedback ci (M3); ship-check (M5) | PLAN | | |
| 27 | Observability skill and checklist | skills/observability-and-instrumentation | prose | gap 31, M5 | PLAN | Homed since 2026-10-14 | GAP -> PLAN |
| 28 | Floor guard with reference test | constraint-driven-development/references/floor-guard.md; scripts/floor-guard-reference-test.js | code | scripts/floor-scan; tests/scripts/floor-scan.bats; evals/seeded-diffs | EQ | | |
| 29 | Bar-moved checks and ratchet | floor-guard.md; constraint-driven-development:202-232 | code+prose | scripts/floor-scan:4,17 (lowered-bar class, `ratchet.<metric>` keys); evals/seeded-diffs/s08-coverage-lowered.diff, s09-strict-off.diff, s10-ci-nonblocking.diff | EQ | Built in M2a (gap 8) | GAP -> EQ |
| 30 | /constraints edits CLAUDE.md, installs tools | .claude/commands/constraints.md:19-25 | prose | none | REJ | Design spec 5.1; goal 3 | |
| 31 | definition-of-done, orchestration-patterns refs | references/* | prose | prove-it; parallel-work refs | EQ | | |
| 32 | Skill lint with required sections | scripts/lib/skill-lint.js (0.6.13 removes the idea-refine exemption, :89) | code | lint rules 1-16; rule 9 red flags (scripts/lib/lint-rules.mjs:334-350) | EQ | | |
| 33 | Reference-link and version validators | scripts/validate-reference-links.js, validate-versions.js | code | lint rule 4, check-version.mjs | EQ | | |
| 34 | Artifact-path pipeline validator | scripts/validate-artifact-paths.js | code | contract-drift lint against docs/plans/contract.md (scripts/lib/lint-rules.mjs:384-412; tests/lint-rules.test.mjs) | EQ | Built in M2a (gap 9) | GAP -> EQ |
| 35 | Multi-host command parity | scripts/validate-commands.js; commands/*.toml | code | none | REJ | Non-goal: other tools | |
| 36 | Routing tier: TF-IDF, top_k, collision check; 0.6.13 decodes quoted skill identities with one shared parser | scripts/run-evals.js:34,160 | code | scripts/route-eval.mjs:7,18 reads skills through the lint's loadModel, which strips quotes once (scripts/lib/frontmatter.mjs:15); distractors and kernel rows | EQ | | |
| 37 | Behavioural runner with fixtures and pressure cases | scripts/run-evals.js:403-640 | code | M2b Task 1 (gap 13) | PLAN | Home moved from M6 to M2b | |
| 38 | claude plugin eval, with and without the plugin | evals/plugin/*; plugin.json experimental.evals | code | skill-eval (M6); M2b head-to-head has a no-plugin control | PLAN | | |
| 39 | Rejected-change ledger | evals/skill-impact.md | doc | evals/rejected.md | EQ | | |
| 40 | CI install smoke test | .github/workflows/test-plugin-install.yml:148-167 | code | .github/workflows/ci.yml:76-87 (marketplace add, plugin install) | EQ | Built in M2a (gap 12) | GAP -> EQ |
| 41 | CI macOS leg | test-plugin-install.yml:77-82 | code | .github/workflows/ci.yml:53-75 (bash 3.2, BSD awk) | EQ | Built in M2a (gap 12) | GAP -> EQ |
| 42 | CI Windows leg | test-plugin-install.yml:77-82 | code | none | REJ | D-2, 8.4 rule 1 | |
| 43 | sdd-cache WebFetch hooks | hooks/sdd-cache-pre.sh, sdd-cache-post.sh | code | none | REJ | Goal 3 | |
| 44 | simplify-ignore hook; 0.6.13 keeps a change reverted with git and re-hides the file | hooks/simplify-ignore.sh; hooks/simplify-ignore-test.sh | code | none | REJ | D3: it still rewrites tracked source in place | |
| 45 | Contributor rules, skill-anatomy doc | .claude/rules/skills-contributing.md; docs/skill-anatomy.md | prose | write-skill (M6) | PLAN | | |
| 46 | Behavioural grading rejects blank evidence, reported apart from bad JSON, with tests | scripts/run-evals.js:476-480,619; scripts/run-evals-test.js:95-181 | code | exec-eval grades in code (scripts/lib/exec-grade.mjs:250); the planned M2b parseVerdict keeps a blank evidence string (m2b plan:237) | GAP | New gap N7 | new |
| 47 | TDD description fires on pasted code with no mention of tests; routing prompts; a fires and stays-quiet plugin eval pair | skills/test-driven-development/SKILL.md:3; evals/cases/test-driven-development.json; evals/plugin/tdd-fires-on-pasted-bug, tdd-stays-quiet-on-debug | prose+code | a bug routes to diagnose, whose fix is red first (kernel/routes.md:11; skills/diagnose/SKILL.md:21); route-eval positives and negatives (evals/cases/row-diagnose.json) hold no pasted-code prompt; behavioural negative cases in M2b (gap 13) | PLAN | M2b. Note: "add tests to this function" matches no kern route and falls to plan (kernel/kernel.md:16) | new |
| 48 | Review severity labels aligned across command, skill and agent; /review and /test run in the main session | .claude/commands/review.md:15; agents/code-reviewer.md | prose | one `review.taxonomy` key (skills/self-review/SKILL.md:35); task-reviewer's Critical and Important map into it (:22; agents/task-reviewer.md:29,46) | EQ | | new |
| 49 | Documented verification loop matches what CI runs | docs/developer-onboarding.md | doc | scripts/ci-local:2 runs CI's steps in CI's order | EQ | A script, not a doc, so it cannot drift silently | new |

## M2a rows a source still beats

None of the 2026-10-14 rows whose counterpart is M2a work is still source-stronger: gaps 7, 8, 9, 11 and 12 shipped in 0.3.0 and are equal or better (superpowers rows 3, 16, 19; addy rows 29, 34, 40, 41).

These M2a skills and scripts are beaten by mechanisms new in superpowers 6.4.2 and 7.0.0, which M2a was not scoped against:

- define, builder check (superpowers row 44): kern's spec reviewer checks the document but never asks what the builder would still need, and never sorts the answers into the user's questions and kern's own calls.
- define, build choices and skip offer (rows 37, 46): nothing asks which of platform, language and libraries the user owns, or says the defaults kern picked.
- define, sizing (row 43): kern classifies at step 3, before the intent at step 5, and names the class in process words.
- define, interview ground (row 39): no anti-goals and no prior art.
- plan, step content (row 50): kern asks for full code in each step and has no proportion check; superpowers measured equal defect detection at about a third of the tokens.
- task-done, silent pass (row 53): handled at scripts/task-done:108 but pinned by no test.

## New gaps

| # | Gap | Source | Proposed home | Size |
|---|---|---|---|---|
| N1 | Builder check in define: the reviewer brief asks, as the builder, which questions a wrong guess would make costly; define answers what it can, settles minor calls and marks them as kern's, sends the user's questions in one message, and lists its calls at handover; the spec gains a "Left to the builder" line | superpowers 7.0.0 | M2b, a define fix before the define workflow and pressure cases run | S |
| N2 | Build choices in define: ask which of platform, language, libraries and medium the user owns; state each default as kern's call (Assumptions: assumed); offer once to skip the interview, and on a skip still state the build choices in one line; red flag "a default they never heard" | superpowers 7.0.0 | M2b, define | S |
| N3 | Size after understanding: classify after the restate, not before the intent; say the class in plain words; the user may override; keep heavier-in-doubt and upgrade-only | superpowers 7.0.0 | M2b, define | S |
| N4 | Interview ground: anti-goals and prior art (loved or hated, including an offer to look on the web) in the restate and the spec's Intent | superpowers 7.0.0 | M2b, define | S |
| N5 | Plan steps record decisions: a code step gives the signature, file and spec values and a body only where they do not decide it; test steps keep real assertions; plan self-review and plan-review.md add a proportion check | superpowers 6.4.2 | M2b, plan, measured by the planning head-to-head against superpowers 7.0.0 | S |
| N6 | Hooks under an empty or broken PATH: give each hook a fallback PATH before its first external call, say the real cause when a library fails to load, and add a bats case run with PATH="" | superpowers 7.0.0 | M3, with the M1 parser deferrals | S |
| N7 | The M2b behaviour grader treats blank evidence as an invalid run and says so, apart from bad JSON | addy 0.6.13 | M2b Task 1 (`parseVerdict`) | S |
| N8 | A task-done.bats case for a passing command that prints nothing | superpowers 7.0.0 | M2b Task 9, which pins each M2 row with a test | S |

Notes for the lead:

- Process: M2b would measure against the old sources. scripts/fetch-upstream:11,14 and UPSTREAM.md:7,10 pin superpowers 5bf4e78 (6.4.1) and addy 1be8e34 (0.6.12), and the M2b plan names 5bf4e780 (m2b plan:11). M2b's head-to-head planning arm would then test the pre-6.4.2 writing-plans and the pre-7.0.0 brainstorming. Bump the pins before the M2b evidence runs (S, M2b).
- N1 to N4 all edit define, whose SKILL.md is 6,499 bytes against a 6,500-byte cap (tests/skills/define.test.mjs:27); plan's SKILL.md is also 6,499 bytes (tests/skills/plan.test.mjs:26). The new text has to go into references (interview.md has 822 bytes of headroom, spec-review.md 447) or replace step text. Done together, N1 to N4 are closer to M than four S items.
- Rows 36 and 49 are rejections that need the user's yes. Row 36 keeps the gate on a quick, clear task; row 49 leaves out non-software brainstorming, which goal 2 ("cover every job superpowers does") could be read to require.
- The old verdict of superpowers row 4 rested on the 6.4.1 spec reviewer and classify-first order; both changed in 7.0.0, so that row now holds only the gate and the spike, and rows 43 and 44 hold the rest.

addy's 25 commits, by row:

| Commit | Row |
|---|---|
| 55de435, f340094, 576fd18 (idea-refine anatomy, boundary line) | 3, 32 |
| 7abea51, 42a590e, 6db395e (non-blank grader evidence) | 46 |
| 7c47146, 1347a91, 7d65f5e (TDD fires on pasted code; eval pair) | 47 |
| 2bdbe1f, de3761d (main-session /review and /test; severity labels) | 48 |
| b7c1cb1, 0e35f3e, 14b7411 (verification loop docs) | 49 |
| 2a6f7a7, e6e5213 (quoted skill identities) | 36 |
| 51e4485, 1fec945 (command descriptions through the shared parser) | 35, 36 |
| 35c3acb, 4bcae53 (JavaScript code-block labels; Codex manifest count) | 16, 35 |
| e9e172d, b82d927 (simplify-ignore restores through git) | 44 |
| aeac41d (manifest bump to 0.6.13) | 35 |
| 5beffae, 8ed8511 (merges of main) | none |

## What changed upstream

- superpowers: two releases. 6.4.2 (8ca22db) rewrote writing-plans so a plan records decisions instead of code, and removed plan-document-reviewer-prompt.md. 7.0.0 (bb92a77) rebuilt brainstorming from scratch (skills/brainstorming/SKILL.md, 466 lines changed; builder-check-prompt.md replaces spec-document-reviewer-prompt.md), made SessionStart independent of PATH, and fixed sdd-workspace, task-done, the requesting-code-review example, the systematic-debugging example, the visual companion's content insertion, Windows run-hook.cmd and Hermes. It adds an Antigravity manifest.
- addy: 25 commits (mapped to rows at the end). Behavioural grading now rejects blank evidence; the TDD description fires on pasted code, with a fires and stays-quiet plugin eval pair; review severity labels are aligned; idea-refine conforms to skill anatomy; simplify-ignore restores through git; docs and manifests.
