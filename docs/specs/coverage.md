# Source coverage

kern's design (section 1) promises the strongest mechanism per category from its five sources. This file holds that promise to account. Every mechanism in a source has one of four verdicts:

- **Equal or better:** kern has built or specified a mechanism at least as strong.
- **Planned:** the source is stronger today, and a named milestone ports it.
- **Gap:** the source is stronger and has a home below. A gap without a home is not allowed.
- **Rejected:** kern does not take it, for a stated goal, non-goal or decision.

The audit of 2026-10-14 grouped 216 mechanisms against kern 0.2.0 and the design spec. The per-mechanism tables, with file and line evidence, are in `docs/research/coverage-2026-10-14/`.

| Source | Mechanisms | Equal or better | Planned | Gap | Rejected |
|---|---|---|---|---|---|
| pstack 0.15.17 | 58 | 20 | 16 | 12 | 10 |
| superpowers 6.4.1 | 35 | 15 | 7 | 4 | 9 |
| addy 0.6.12 | 45 | 14 | 17 | 5 | 9 |
| pocock 1.3.1 | 35 | 11 | 16 | 1 | 7 |
| caveman 3.2.0 | 38 | 17 | 3 | 11 | 7 |
| local | 5 | 2 | 2 | 1 | 0 |

## Rule

1. A milestone row in section 14 names the source mechanisms it ports. A mechanism detailed only in `docs/research/merge-*.md` is not planned until a row names it.
2. Before a milestone closes, its ported mechanisms are checked against this file. A mechanism dropped from a milestone moves to another milestone or to Rejected, with the reason.
3. A new source version, or a new source, gets an audit before kern ports from it.

## Gaps and their homes

| # | Gap | Source | Home | Size |
|---|---|---|---|---|
| 1 | PreToolUse fails closed when a hook library cannot load | caveman | 0.2.1 | S |
| 2 | Natural-language switch phrases, with a corpus run against the real hook | caveman | 0.2.1 | S |
| 3 | No voice reminder on scheduled prompts | caveman | 0.2.1 | S |
| 4 | Remove old session state files | caveman | 0.2.1 | S |
| 5 | `plan-check`: lint generated plans and specs | pstack | M2 | S |
| 6 | `wt-audit`: find worktrees left by earlier sessions | pstack | M2 | S |
| 7 | Rationalization and red-flag tables in prove-it, implement and diagnose; lint rule 9 requires them in discipline skills | superpowers, addy | M2 | S |
| 8 | floor-scan catches a lowered bar (coverage threshold, `strict` off, a lint rule off, a CI step removed or made non-blocking), with `ratchet.<metric>` keys | addy | M2 | M |
| 9 | Contract-drift lint: every token a skill reads has a producer in `docs/plans/contract.md` | addy | M2 | S |
| 10 | Adherence grader passes only when the route is read before the first tool call; a multi-turn case | superpowers | M2 | S |
| 11 | `references/defense-in-depth.md` for diagnose | superpowers | M2 | S |
| 12 | CI install smoke test and a macOS job | addy | M2 | S |
| 13 | On-demand behavioural eval runner and pressure tests for discipline skills | addy, superpowers | M2 | M |
| 14 | unslop's main AI tells in the normal voice and in subagent returns | local | M2 | S |
| 15 | Candor line in the kernel: no is an acceptable answer | pstack | M2 | S |
| 16 | Terse rules: existing comments are payload; code in chat is the changed lines plus context | caveman | M2 | S |
| 17 | PR body with a smallest-useful-view summary and a screenshot tier | pocock | M2 | S |
| 18 | Hook git calls run with `core.fsmonitor` and `core.hooksPath` disabled | caveman | M2 | S |
| 19 | SubagentStart tests: normal voice, `kern: off`, a bad session id | caveman | M2 | S |
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

## Accepted limits

- Spending and permission changes outside the Claude Code settings files stay kernel text ("ask first"). No command reliably signals spending.
- Windows: hooks are bash and POSIX tools (section 8.4 rule 1) and kern is personal (D-2). Revisit if a Windows machine is added.

## Rejected

| Reason | Mechanisms |
|---|---|
| Goal 3, D1, D2 or the merge floor | Commits by default, merge-locally, auto-merge and push loops, PRs opened ready, tracker and chat writes without asking, continual-learning writing AGENTS.md, Slack automations, scheduled chief-of-staff runs, setup-pre-commit, network-calling cache hooks, a statusline nudge that writes settings, telemetry, `/constraints`, wizard secret writes |
| Non-goals: other tools, non-Claude models, team distribution | Cursor, Codex, Gemini and Copilot manifests and builds; cross-vendor reviewers; issue workflows; third-party integrations; caveman cloud, proxy and MCP servers |
| Goal 4, standing cost | Extra compatibility agents, MCP servers, automate-me, teaching |
| D3, D5, D6, D10 | simplify-ignore, "rulings, not stalls", safe fallbacks, "delete means delete" |
| Voice decisions (section 6.4, D-5) | ultracave, megacave, caveman-commit, caveman-compress |
| Skill format (skills spec A7: numbered steps) | Graphviz flowcharts, persuasion wording |
