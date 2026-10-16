# Source coverage audit: consolidated (2026-10-14)

Totals: 216 mechanisms grouped. pstack 58 (20 EQ, 16 PLAN, 12 GAP, 10 REJ); superpowers 35 (15, 7, 4, 9); addy 45 (14, 17, 5, 9); pocock 35 (11, 16, 1, 7); caveman 38 (17, 3, 11, 7); local 5 (2, 2, 1, 0). Gaps after dedupe: 31, plus kern's own unguarded ask-first items.

## 0.2.1 patch (M1)
- P1 Fail closed when a hook library cannot load (verified fail-open: settings.sh, decide.sh). S. [caveman]
- P2 No terse reminder on <scheduled-task prompts (spec 6.3). S. [caveman]
- P3 Clean up old session state files. S. [caveman]
- P4 Natural-language switch phrases + corpus fixture with known_failing, run against the real hook. S. [caveman]

## M2
- Plan/spec linter `plan-check`. S. [pstack]
- `wt-audit` cross-session worktree audit. S. [pstack]
- U1 Anti-rationalization + red-flag tables in prove-it, implement, diagnose; lint rule 9 requires them for discipline skills. S. [superpowers, addy]
- U2 floor-scan "bar lowered" class + ratchet.<metric> keys. M. [addy]
- U4 Contract-drift lint against contract.md. S. [addy]
- U5 Adherence grader: route before the first tool call; multi-turn case. S. [superpowers]
- U7 references/defense-in-depth.md (planned, dropped). S. [superpowers]
- U8 CI install smoke test + macOS leg. S. [addy]
- T1 On-demand behavioural runner (and pressure tests for discipline skills) next to the adherence grader. M. [addy, superpowers]
- unslop catalog in normal voice (kernel Reply line ~150 chars; subagent Return line). S. [local]
- Candor line in kernel ("no is an acceptable answer", ~90 chars). S. [pstack]
- Two terse rules (existing comments are payload; changed lines plus context). S. [caveman]
- pr-body visual summary + screenshot tier. S. [pocock]
- Hardened git flags in hooks (fsmonitor, hooksPath). S. [caveman]

## M3
- Autopilot Stop enforcement: predicate exit 0 or turn cap, one Stop hook with G7. M. [pstack]
- Nudge when edits have no proof at Stop. S. [pstack]
- `pr-state` merge-readiness script with fixtures. M. [pstack]
- Multi-PR stack delivery from a plan. M. [pstack]
- Tree-identity guard on content-preserving rewrites. S. [pstack]
- decision-log moved from M6 to M3 (autopilot shipped in M1), with formula escaping. M. [pstack]

## M5
- Principles reference (~15 unhomed principles). M. [pstack]
- verify-app create/maintain modes (generate a project verification skill on explicit yes). M. [pstack]
- Arena judge + graft in parallel-work race mode. S. [pstack]
- CLI-for-agents design reference. S. [pstack]
- U3 Observability reference from implement, plan, ship-check. S-M. [addy]

## M6
- U6 Redaction scrub before project evidence enters kern_repo; lint rule 8 proprietary list. S. [superpowers]
- Voice evals (three arms, fidelity regex, isolation, snapshot) + token stats. M. [caveman]
- Repeated-procedure mining as a retro signal. M. [caveman]

## Needs a decision
- kern's own ask-first items with no guard: local rm, spend, permission changes.
- Windows: rejected by D-2 and §8.4 rule 1 unless a Windows machine is added.

## Process fixes
- Coverage rule in the design spec: every source mechanism has a home (milestone + section) or a recorded rejection tied to a goal; docs/specs/coverage.md holds the matrix.
- M3-M6 spec rows list the mechanisms they port, so a drop from docs/research/merge-*.md is visible (two were dropped silently: defense-in-depth, floor-scan bar-moved checks).

## Rejected (about 38 grouped), by reason
- Goal 3 / D1 / D2 / floor: commits by default, merge-locally, auto-merge, push loops, ready PRs, tracker/chat writes without asking, continual-learning writing AGENTS.md, Benny, chief-of-staff, setup-pre-commit, sdd-cache network hooks, statusline settings nudge, telemetry logo, /constraints, wizard secrets.
- Non-goals (other tools, non-Claude models, team distribution): Cursor/Codex/Gemini/Copilot manifests and builds, cross-vendor reviewers, Grok defaults, issue workflows, integrations, caveman cloud/proxy/MCP.
- Goal 4 standing cost: agent-compatibility agents, MCP servers, automate-me, teaching.
- D3/D5/D6/D10: simplify-ignore, "rulings not stalls", safe fallbacks, delete-means-delete.
- Voice: ultracave, megacave, caveman-commit, caveman-compress.
