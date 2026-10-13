<!-- Source audit of 2026-10-14 against kern 0.2.0 (3f7bc38) and the design spec. Paths are relative to .upstream/<source>/ unless noted. Read-only agent output, kept as the evidence behind docs/specs/coverage.md. -->

# pstack audit (part 1 of report, rows 1-10)

58 mechanisms: KERN-EQUAL-OR-BETTER 20, SOURCE-BETTER-PLANNED 16, SOURCE-BETTER-UNPLANNED 12, REJECT-CANDIDATE 10.
PLANNED = kern has only a milestone row naming the job; EQUAL = built or specified at step level.
Correction to the M1 comparison: pstack has three hook sets (advisor/hooks/* 4 events, ralph-loop/hooks/*, continual-learning/hooks/*.ts) and tested code (watch-pr/*.test.ts, orch/orch.test.ts, check-plan.mjs).
Keys: PM = pstack/skills/poteto-mode, PS = pstack/skills, TK = cursor-team-kit/skills; C3/C8 = sections of docs/specs/2026-10-12-kern-m1-m2-skills.md; § = design spec.

| # | Mechanism | Source | Enforced by | kern counterpart | Verdict | Reason |
|---|---|---|---|---|---|---|
| 1 | Playbook routing, steps copied verbatim into the todo list, skip: lines, per-turn reminder | PM/SKILL.md:8,121 | prose (user types it) | kernel/kernel.md:15-21 plus prompt-submit reminder (M1) | EQUAL+ | kern injects the rules every session; pstack only when typed. |
| 2 | Questions a command could answer get a prototype, not a question | PM/SKILL.md:20 | prose | kernel.md:27, define step 8 spike (C1) | EQUAL | Same rule. |
| 3 | Evidence label on each claim, no invented links; verify-this verdicts | PM/SKILL.md:101-113, TK/verify-this | prose | kernel.md:31, unslop (M1), prove-it (C7) | EQUAL | Same labels; inconclusive is a fail. |
| 4 | "No is an acceptable answer" (candor) | PM/SKILL.md:89 | prose | none; unslop:88 covers tone only | UNPLANNED | Nothing tells kern to decline weak scope or proposals. |
| 5 | You own subagent output; fresh subagent per round | PM/SKILL.md:93-99 | prose | Evidence line; C3 step 9 resumes rounds 1-2, fresh at round 3 | EQUAL | Brief and report are files; choices differ deliberately. |
| 6 | Principles corpus (25 leaves plus the-algorithm); cite only leaves read this session | PS/principle-*, PM/SKILL.md:15,38-79 | prose | §3.1 lists a principles reference with no milestone; about 8 folded into M2 steps | UNPLANNED | About 15 principles have no home. |
| 7 | check-plan.mjs lints plan structure, required boxes and prose | PM/scripts/check-plan.mjs:1-190 | code | plan step 11 self-review plus one reviewer (C2) | UNPLANNED | Plans and specs checked only by prose and a reviewer. |
| 8 | Multi-phase plan: per-PR proof, regression lane trunk vs head, throughput checkpoint | PM/playbooks/multi-phase-plan.md:13-153, feature.md:7-11 | prose | plan C2 steps 5-10; execute-plan C3 step 4 | EQUAL | Same content, gated. |
| 9 | Multi-PR delivery as one verified linear stack the user lands | PM/playbooks/autopilot-stack.md:5-12, opening-a-pr.md:28 | prose | plan cuts PR boundaries (C2 step 7); execute-plan one branch (C3 step 5); M3 stacks post-hoc | UNPLANNED | A plan with several PRs has no delivery path. |
| 10 | watch-pr: tested merge-readiness verdict (conflicts > threads > CI > gate; READY/WAITING/ADVANCE; backoff) | PM/scripts/watch-pr/policy.ts:214-262 | code and tests | take-feedback drive with gh pr checks --watch (§10.2, M3) | UNPLANNED | gh pr checks ignores threads and mergeability. |

# part 2: rows 11-34

| # | Mechanism | Source | Enforced by | kern counterpart | Verdict | Reason |
|---|---|---|---|---|---|---|
| 11 | Babysit: merge frontier first, no topology change, conflicts then threads then CI, classify CI before rerun (also fix-ci, loop-on-ci, ci-watcher, fix-merge-conflicts, dyl-ready-pr) | PM/playbooks/babysit.md:7-23 | prose | §10.2-10.3 (M3) | EQUAL+ | Specified; aborts on a behaviour conflict, D10 caps rounds. |
| 12 | Bot-review triage rubric with learned dismissal patterns; security, auth, data always escalate | PM/references/bugbot-triage.md:5-124 | prose | take-feedback threads (§10.2), G4 | PLANNED | Port the fix/dismiss/ask rubric; patterns to lessons. |
| 13 | Verdict valid only while patch-id unchanged | PM/playbooks/shipping.md:9 | prose | §10.3, G11 (M3) | EQUAL+ | Same rule. Port the build-twice noise test. |
| 14 | Delegation contract: brief fields, refuse to spawn on a missing field, standing orders, liveness by side effects, gap accounting | PM/playbooks/orchestrate.md:25,38-56,93-100 | prose | C4 steps 3-6; SubagentStart hook | EQUAL+ | kern injects standing orders by hook. |
| 15 | Enforced stop for autonomous runs: iteration cap, completion check | ralph-loop/hooks/stop-hook.sh:43-84; PM/playbooks/autonomous-run.md:5-11 | code | skills/autopilot/SKILL.md:15 (prose); no Stop hook | UNPLANNED | No milestone covers it. |
| 16 | Pause safely: clean stop, resume note | PM/playbooks/pause-safely.md:5-8 | prose | handoff (M6) | PLANNED | Drop the wip: commit (conflicts with D1). |
| 17 | Session pickup, recall, ketchup, weekly-review, what-did-i-get-done | PS/recall, PS/ketchup, PM/playbooks/session-pickup.md | prose | recall C11 plus ledger resume C3 step 2 | EQUAL+ | Adds ledgers and live state checks. |
| 18 | Cross-session worktree audit: buckets wip, open PR, merged, recent chat | PM/scripts/worktree-audit.sh:30-84; worktree-cleanup.md | code | per-run teardown only (C3 step 14, C4 step 9) | UNPLANNED | Nothing finds worktrees left from earlier sessions. |
| 19 | Bug fix, runtime and trace forensics, tdd | PM/playbooks/bug-fix.md, runtime-forensics.md, trace-forensics.md; PS/tdd | prose | diagnose C6 with forensics.md; implement C5 | EQUAL+ | Refuses hypotheses until a red-capable loop exists. |
| 20 | Perf, hillclimb, benchmark-checklist (7 questions) | PM/playbooks/hillclimb.md:5-18; PS/benchmark-checklist:15-40 | prose | perf (M5) | PLANNED | Port checklist, frozen harness, attempt floor. |
| 21 | Refactoring: pin the contract, reader-load test | PM/playbooks/refactoring.md:7-14 | prose | refactor (M5) | PLANNED | |
| 22 | Prototype with a variant switcher | PM/playbooks/prototype.md | prose | prototype (M5); define spike (M2) | PLANNED | |
| 23 | Visual parity (image-diff baseline, baseline must not be edited); build-figma visual judge | PM/playbooks/visual-parity.md:5-8; dyl-stack/skills/build-figma | prose | build-ui (M5) | PLANNED | Baseline-tamper ban missing from G7. |
| 24 | how, why (MCP evidence map, null results recorded), teach | PS/how; PS/why:30-90; PS/teach | prose | explain (M5); investigator (M2) | PLANNED | |
| 25 | Eval blinding: no meta words, organic prompt, chain checked from transcripts | PM/playbooks/eval.md:5-25 | prose | §11.1 tier 2 blind A/B; skill-eval (M6) | PLANNED | |
| 26 | Skill and plugin validation | PM/playbooks/authoring-a-skill.md; scripts/validate-plugins.mjs | prose and code | scripts/lint-skills.mjs, claude plugin validate (M0) | EQUAL+ | 15 lint rules. |
| 27 | PR body sections; review-and-ship; new-branch-and-pr | PM/playbooks/opening-a-pr.md:13-22; TK/review-and-ship | prose | finish-branch C10 with pr-body.md | EQUAL+ | Adds dedup, size gate, gates. |
| 28 | Arena: cross-judge, pick a base, graft from the losers | PS/arena | prose | parallel-work race mode (C4 step 2) | UNPLANNED | No judge phase, no graft phase. |
| 29 | Architect: design twice, red-flag screen, signs to scrap | PS/architect | prose | architect (M5) | PLANNED | |
| 30 | Swarm | PS/swarm | prose | parallel-work C4 | EQUAL+ | Worktree forks; a gap is not a pass. |
| 31 | Review lanes: interrogate, thermos (file passing 1k lines, devex breaks, feature-flag leak), dyl-review | PS/interrogate; thermos/skills/*; dyl-stack/skills/dyl-review | prose | pr-review lanes plus G10 probe (§10.1) | EQUAL+ | Port the thermos rubric items. |
| 32 | Blast radius: 5-level proof ladder | PS/blast-radius:20-46 | prose | self-review C8 step 5 | EQUAL+ | |
| 33 | figure-it-out | PS/figure-it-out | prose | define classify plus plan (C1, C2) | EQUAL+ | |
| 34 | correct, reflect, workflow-from-chats | PS/correct; PS/reflect; TK/workflow-from-chats | prose | correct and retro (M6), §11.4 | PLANNED | |

# part 3: rows 35-58

| # | Mechanism | Source | Enforced by | kern counterpart | Verdict | Reason |
|---|---|---|---|---|---|---|
| 35 | show-me-your-work trail plus log.sh (escapes spreadsheet formulas, transcript audit, review of the trail) | PS/show-me-your-work; scripts/log.sh | code and prose | decision-log (M6) | PLANNED | Sequencing note in final part. |
| 36 | bro | PS/bro | prose | plain (M6) | PLANNED | Trivial. |
| 37 | no-comments and comment-sicko | PS/no-comments; pstack/agents/comment-sicko.md | prose | M3 | PLANNED | |
| 38 | deslop | TK/deslop | prose | G7 floor scan script (M2 Task 5) | EQUAL+ | kern's check is code. |
| 39 | Generate and maintain a project verification skill plus feature map, proven end to end | PS/create-verification-skill; PS/maintain-verification-skill | prose | verify-app (M5) runs an existing check only | UNPLANNED | Projects with no harness stay without one. |
| 40 | control-ui, control-cli, smoke tests | TK/control-ui, control-cli, run-smoke-tests | prose | verify-app (M5) | PLANNED | |
| 41 | setup-pstack: model per role, budget | PS/setup-pstack | prose | model.* keys (A5, A10), help setup | EQUAL+ | |
| 42 | TypeScript practices; always-apply style rules | PS/typescript-best-practices; cursor-team-kit/rules/*.mdc | prose | stacks/* (M5) | PLANNED | Keep on demand. |
| 43 | poteto-help and guide | PS/poteto-help; pstack/docs/guide | prose | help (M1, built) | EQUAL+ | |
| 44 | Advisor consult with a stronger model | advisor/skills/advisor | prose | doubt cycle C8 step 7; final review on opus C3 step 12 | EQUAL+ | kern withholds the author's claim from the reviewer. |
| 45 | Advisor Stop-hook nudge when edits happened but no review ran | advisor/hooks/stop-hook.sh:29-47, mark-pending.sh | code | G7 Stop hook (M3) floor items only | UNPLANNED | Evidence rule still prose at turn end. |
| 46 | Tree-identity guard on history rewrites | TK/make-pr-easy-to-review:20-45 | code shown in skill | none | UNPLANNED | A regroup or squash could change content silently. |
| 47 | PR review canvas, docs canvas | pr-review-canvas; docs-canvas | prose | visual (M4) | PLANNED | |
| 48 | cli-for-agents design guide | cli-for-agent/skills/cli-for-agents | prose | none | UNPLANNED | Nothing covers designing a CLI that agents run. |
| 49 | "Just do it" for team chat and tickets | PM/SKILL.md:83 | prose | G14, G15 | REJECT | |
| 50 | Program-scale autonomy: owners self-merge, Shipping lands, orchestrate, orch store | PM/playbooks/autopilot-full.md:6-10, orchestrate.md, shipping.md:10-14 | prose and code | floor | REJECT | |
| 51 | PRs opened ready not draft; Origin forge; dyl gh pr ready without asking | PM/playbooks/opening-a-pr.md:24,30 | prose | G2 | REJECT | |
| 52 | Cross-vendor model diversity (Grok defaults) | interrogate, arena, advisor | prose | none | REJECT | |
| 53 | automate-me (generates a personal -mode skill) | PS/automate-me | prose | none | REJECT | |
| 54 | continual-learning (Stop hook writes AGENTS.md automatically) | continual-learning/hooks/*.ts | code | §11.4 | REJECT | |
| 55 | Benny Slack automations | pstack/automations/benny | prose | triage (M5), drafts only | REJECT | |
| 56 | agent-compatibility scan (4 agents) | agent-compatibility | prose | wt-new baseline | REJECT | |
| 57 | teaching | teaching | prose | none | REJECT | |
| 58 | Integrations: third_party, grok-voice, cursor-sdk, origin-apps, make-bot-ui | various | prose | none | REJECT | |

Totals: 20 EQUAL+, 16 PLANNED, 12 UNPLANNED, 10 REJECT.

# part 4: UNPLANNED homes and REJECT reasons

## SOURCE-BETTER-UNPLANNED (proposed home, size)

1. Multi-PR stack delivery (row 9), M3, M: execute-plan cuts one branch per PR slice; per-layer verdict keyed to tree or patch-id; delivery via `gh stack submit --auto` drafts or `git rebase --update-refs`; user lands it. Home: design §10.3, C3.
2. Stop enforcement for autopilot (row 15), M3, M: one Stop hook shared with G7; under autopilot blocks the stop until a recorded predicate command exits 0 or a turn cap is hit; honours stop_hook_active; state written only by the hook (G16). Home: §8.2, §8.3.
3. Merge-readiness script (row 10), M3, M: `pr-state` script; one verdict across conflicts, threads, checks, review gate, stack ceiling; fixture tests; take-feedback check and drive call it. Home: §10.2.
4. Principles reference (row 6), M5, M: condense ~15 unhomed principles into references/principles.md (~6 KB), read on demand by architect, refactor, implement, self-review; cite only if read and name the choice it changed; give §3.1's principles row a milestone.
5. Generated-plan linter (row 7), M2, S: `plan-check` for WORK/plans and WORK/specs: frontmatter status, required headings, Files/Interfaces/verify/Blocked by per task; flags TBD and "similar to Task N"; reuses prose lint rule 11. Plan step 11 and define step 10 run it.
6. Verification-skill generator (row 39), M5, M: verify-app create and maintain modes; write .claude/skills/verify-<app>/ only on explicit yes (tracked file, D1, D2); prove launch, doctor, drive, evidence, cleanup end to end.
7. Worktree audit (row 18), M2, S: read-only `wt-audit`; buckets from wip state, `gh pr list --state all`, transcript mtime under ~/.claude/projects/<slug>; used by recall and teardown proposals.
8. Nudge when edits have no proof (row 45), M3, S: PostToolUse marks Edit/Write; at Stop, no proving command since the last edit nudges once per batch; silent when the reply ends with a question. Home: G7 Stop hook.
9. Arena judge and graft (row 28), M5 with architect, S: race mode adds a fresh read-only judge on a pre-declared rubric, picks a base, grafts by hand.
10. Tree-identity guard (row 46), M3 take-feedback rebase mode, S: record HEAD^{tree} before a content-preserving rewrite; block the push if it changed.
11. Candor line (row 4), M1 kernel Reply section, S: ~90 chars; kernel at 3,083 of 4,000.
12. CLI design reference (row 48), M5 architect reference, S: on demand, no standing cost.

Sequencing note (row 35): autopilot shipped in M1 but decision-log arrives in M6; until then unattended runs leave only parked: ledger lines. Consider moving decision-log with log.sh's formula escaping to M3 next to items 2 and 8.

## REJECT-CANDIDATE

- 49 external writes without asking: goal 3, D2, G14.
- 50 owners self-merge, autonomous landing, hourly program loop, Cursor cloud agents: merge floor (§5.1), goal 3, Cursor non-goal. Useful parts already ported (C4 brief, gap accounting, §10.3 patch-id).
- 51 PRs opened ready, gh pr ready without asking, Origin forge: D2, pr.policy draft-after-approval, G2, Cursor non-goal.
- 52 cross-vendor model diversity: non-goal "model routing to non-Claude models".
- 53 automate-me: a second router competing with the kernel; goal 4 budget. Transcript mining belongs to retro (M6).
- 54 continual-learning: writes tracked AGENTS.md automatically; breaks the kernel Learning line, goal 3, §11.4 approval. Borrow the transcript mtime index for retro.
- 55 Benny: posts to Slack and creates tickets unattended; goal 3, G14, Cursor non-goal.
- 56 agent-compatibility: four more agent descriptions against the 2,500-char budget (goal 4, §3.2).
- 57 teaching: outside goal 2's job set; goal 4 budget.
- 58 integrations: non-goal "other coding tools"; Claude Code connectors cover these.
