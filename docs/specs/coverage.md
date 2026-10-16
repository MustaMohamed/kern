# Source coverage

kern's design (section 1) promises the strongest mechanism per category from its five sources. This file holds that promise to account. Every mechanism in a source has one of four verdicts:

- **Equal or better:** kern has built or specified a mechanism at least as strong.
- **Planned:** the source is stronger today, and a named milestone ports it.
- **Gap:** the source is stronger and has a home below. A gap without a home is not allowed.
- **Rejected:** kern does not take it, for a stated goal, non-goal or decision.

The audit of 2026-10-17 re-measured 274 mechanisms against kern 0.3.0 (eee601d) and these source versions: superpowers 7.0.0, pstack 0.15.25, addy 0.6.13, pocock 1.3.1 (unchanged), caveman 4.0.1 and the unchanged local files. The per-mechanism tables, with file and line evidence, are in `docs/research/coverage-2026-10-17/`. The 2026-10-14 audit of 216 mechanisms against kern 0.2.0 is in `docs/research/coverage-2026-10-14/`, and it set gaps 1 to 34.

"Moved" counts rows whose verdict changed since 2026-10-14, a split row included.

| Source | Mechanisms | Equal or better | Planned | Gap | Rejected | Moved |
|---|---|---|---|---|---|---|
| pstack 0.15.25 | 72 | 27 | 29 | 5 | 11 | 15 |
| superpowers 7.0.0 | 57 | 26 | 10 | 8 | 13 | 5 |
| addy 0.6.13 | 49 | 20 | 19 | 1 | 9 | 5 |
| pocock 1.3.1 | 37 | 13 | 16 | 1 | 7 | 3 |
| caveman 4.0.1 | 54 | 28 | 6 | 2 | 18 | 15 |
| local | 5 | 3 | 2 | 0 | 0 | 1 |

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
| 10 | Adherence grader passes only when the route is read before the first tool call; a multi-turn case | superpowers | M2b | S |
| 11 | `references/defense-in-depth.md` for diagnose | superpowers | M2a (shipped in 0.3.0) | S |
| 12 | CI install smoke test and a macOS job | addy | M2a (shipped in 0.3.0) | S |
| 13 | On-demand behavioural eval runner and pressure tests for discipline skills | addy, superpowers | M2b | M |
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
| 35 | define has no builder check: nothing asks what a builder would still need, sorts the answers into the user's questions and kern's own calls, or lists those calls at handover | superpowers 7.0.0 | M2b, a define fix before its workflow and pressure cases run | S |
| 36 | define never asks which of platform, language, libraries and medium the user owns, never states its defaults as its own calls, and offers no skip of the interview | superpowers 7.0.0 | M2b, define | S |
| 37 | define sizes the work before it understands the intent, and names the class in process words | superpowers 7.0.0 | M2b, define | S |
| 38 | define's interview and spec have no anti-goals and no prior art | superpowers 7.0.0 | M2b, define | S |
| 39 | plan asks for full code in each step and has no proportion check against the spec | superpowers 6.4.2 | M2b, plan, measured by the planning head-to-head | S |
| 40 | Hooks do not survive an empty or broken PATH, and the misleading "kern did not load" message hides the real cause | superpowers 7.0.0 | M3, with the M1 parser deferrals | S |
| 41 | The M2b behaviour grader keeps blank evidence instead of treating it as an invalid run | addy 0.6.13 | M2b Task 1 (`parseVerdict`) | S |
| 42 | No `task-done.bats` case covers a passing command that prints nothing | superpowers 7.0.0 | M2b Task 9 | S |
| 43 | plan-check reads fences by flipping on any line that starts with three backticks or tildes, so a spec quoting Markdown fails it | pstack 0.15.25 | M2b | S |
| 44 | No step names the expert's method for a task, loosens an overspecified ask, or works outside define (`/sharpen`) | pstack 0.15.25 | M6, beside plain | S |
| 45 | recall chat holds the 0.15.17 ketchup text, not the 0.15.25 rules (short, checked numbers, no invented action items) | pstack 0.15.25 | M2b | S |
| 46 | No dispatch passes per-subagent `effort`, and model-selection has no effort column | pstack 0.15.25 | M2b | S |
| 47 | diagnose step 9 does not propose the cheap always-on signal that would have shown the cause | pstack 0.15.25 | M2b | S |
| 48 | The M2b head-to-head has no pstack arm, and its pins named the old superpowers, pstack and addy. The pins moved with the 2026-10-17 audit; the arm remains | pstack 0.15.25, superpowers 7.0.0, addy 0.6.13 | M2b Task 3 (`arms.json`) | S |
| 49 | self-review's Standards axis has no baseline of labelled code smells when a repo documents no standards | pocock | M2b, or gap 27 in M5 | S |
| 50 | Terse mode lacks four clauses: an explicit reply-language instruction wins, quoted text never switches the language, one term per thing, a pronoun only with an obvious referent | caveman 4.0.1 | M2b, or a 0.3.1 patch | S |
| 51 | A headless session (`sdk-*` entrypoint) starts in the terse voice when the user default is terse, which reaches exec-eval and M2b runs | caveman 4.0.1 | M2b, before its runners spend tokens | S |

Gaps 35 to 38 all edit define, whose `SKILL.md` is 6,499 bytes against a 6,500-byte cap. The new text goes into references or replaces step text, so together they are closer to M than four S items. Gap 39 meets the same cap in plan.

The goal-0 review of the M2 plan (2026-10-14) found further source mechanisms the plan ported weaker or dropped, such as define's red flags, debugging redirection signals, forensics proof rules, "where grep stops", the "Declined to judge" list, recall's source lines and caveman-style eval isolation. Its reports are in `docs/research/m2-goal0-review-2026-10-14/`, and each item is homed in M2a or M2b in the M2 plans.

## M2a rows a source still beats (2026-10-17)

Rule 4 closed M2a with none left against the sources it audited. The sources have since moved, and the re-audit found these rows where a source is stronger now. Their homes are M2b, which closes them before it closes.

- define: gaps 35, 36, 37 and 38 (superpowers 7.0.0).
- plan: gap 39 (superpowers 6.4.2).
- task-done: gap 42, a built behaviour with no test.
- plan-check: gap 43, fence parsing (pstack 0.15.25).
- recall chat: gap 45, the ketchup rules (pstack 0.15.25).
- execute-plan model selection: gap 46, subagent effort (pstack 0.15.25).
- diagnose: gap 47, the always-on signal (pstack 0.15.25).
- self-review: gap 49, the smell baseline (pocock code-review). Gap 27 in M5 is the fallback home.

## Pending the user

Both rows are in the superpowers table of `docs/research/coverage-2026-10-17/sp-addy.md`. Each stays "pending the user" until answered.

- Row 36, a quick and clear task is done at once with no design and no approval. Proposed rejection: define keeps its gate on every path (D-4, skills spec C1). Alternative: a task the user calls quick and clear skips design and approval.
- Row 49, brainstorming for any domain. Proposed rejection: kern is software only (D-2). Alternative: define accepts non-software work, because goal 2 says kern covers every job superpowers does.

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
