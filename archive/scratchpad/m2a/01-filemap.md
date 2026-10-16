
## File map

| Path | Task | Responsibility |
|---|---|---|
| `scripts/lib/wt-common.sh`, `scripts/wt-new`, `scripts/wt-check`, `tests/helpers/wt.bash`, `tests/scripts/wt-new.bats` | 1 | Create and verify kern worktrees |
| `scripts/wt-snap`, `scripts/wt-diff`, `tests/scripts/wt-snap-diff.bats` | 2 | Snapshot trees, review packages, allowed paths |
| `scripts/wt-fork`, `scripts/wt-apply`, `tests/scripts/wt-fork-apply.bats` | 3 | Forks that carry uncommitted state; serial integration |
| `scripts/wt-audit`, `tests/scripts/wt-audit.bats` | 4 | Read-only bucket list of kern worktrees |
| `scripts/lib/test-paths.awk`, `scripts/lib/floor-scan.awk`, `scripts/floor-scan`, `tests/scripts/floor-scan.bats`, `kernel/settings.md` | 5 | G7 as a script, with a lowered-bar class and `ratchet.<metric>` keys |
| `scripts/claim-check`, `scripts/probe`, `tests/scripts/claim-probe.bats` | 6 | G9 and G10, with test files kept and mutation probes |
| `evals/seeded-diffs/**`, `scripts/seeded-diffs.mjs`, `tests/seeded-diffs.test.mjs` | 7 | Labelled review diffs: recall and false alarms in CI |
| `scripts/ledger-open`, `scripts/task-brief`, `scripts/task-start`, `tests/scripts/ledger.bats` | 8 | Ledger identity and approval gate, briefs, task start |
| `scripts/task-review`, `scripts/task-done`, `tests/scripts/task-done.bats` | 9 | Review lines; completion only on a reviewed, proven tree |
| `scripts/brief-check`, `tests/scripts/brief-check.bats` | 10 | Refuse an incomplete worker brief |
| `scripts/plan-check`, `tests/scripts/plan-check.bats` | 11 | Lint plans and specs; overlap, waves and Files |
| `hooks/guards/g18-readonly-agent.sh`, `hooks/pre-tool-use`, `tests/hooks/g18.bats`, `docs/spikes/m1-payloads.md` | 12 | Read-only investigator |
| `agents/implementer.md`, `agents/task-reviewer.md`, `agents/investigator.md`, `tests/helpers/md.mjs`, `tests/agents.test.mjs` | 13 | The three M2 agents |
| `hooks/guards/g20-approval.sh`, `hooks/lib/state.sh`, `hooks/prompt-submit`, `hooks/pre-tool-use`, `hooks/session-start`, `tests/hooks/g20.bats` | 14 | Approvals quote the user's last message |
| `scripts/lib/lint-rules.mjs`, `tests/lint-rules.test.mjs`, `scripts/lint-exemptions.json` | 15 | Lint rules 5, 9 (with Red flags) and 16 (contract drift) |
| `skills/prove-it/**`, `evals/cases/prove-it.json`, `tests/skills/prove-it.test.mjs` | 16 | Evidence gate; placeholder removed |
| `skills/implement/**`, `tests/skills/implement.*` | 17 | Thin slices, test first |
| `skills/diagnose/**`, `tests/skills/diagnose.*`, `tests/scripts/find-polluter.bats`, `tests/scripts/loop-rate.bats`, `tests/hooks/g18-parity.bats` | 18 | Root cause before fix |
| `skills/define/**`, `tests/skills/define.*` | 19 | Clarify and approve |
| `skills/plan/**`, `tests/skills/plan.*` | 20 | Spec to checked tasks |
| `skills/parallel-work/**`, `tests/skills/parallel-work.*` | 21 | Fan out with one worktree per writer |
| `skills/execute-plan/**`, `tests/skills/execute-plan.*` | 22 | Ledger, delegation, two-verdict review |
| `skills/self-review/**`, `tests/skills/self-review.*` | 23 | Author's pre-PR check with a spec lane |
| `skills/commit/SKILL.md`, `tests/skills/commit.*` | 24 | One clean commit, or one per reviewed task |
| `skills/finish-branch/**`, `skills/prove-it/SKILL.md`, `tests/skills/finish-branch.*`, `tests/skills/prove-it.test.mjs` | 25 | Verify, review, then the outward menu |
| `scripts/lib/claude-run.mjs`, `scripts/lib/exec-grade.mjs`, `scripts/exec-eval.mjs`, `evals/exec/**`, `tests/exec-eval.test.mjs`, `tests/skills/ship-commands.bats`, `evals/snapshots/` | 26 | Execution evals for commit and finish-branch |
| `scripts/recall-sessions`, `tests/scripts/recall-sessions.bats` | 27 | This project's sessions and prompts |
| `skills/recall/**`, `evals/cases/recall.json`, `tests/skills/recall.*` | 28 | Rebuild state |
| `kernel/kernel.md`, `kernel/kernel-subagent.md`, `modes/terse.md`, `modes/terse-subagent.md`, `tests/hooks/session-start.bats`, `tests/hooks/subagent-start.bats`, `tests/voice.test.mjs` | 29 | Candor, AI tells in the normal voice, terse payload rules |
| `kernel/kernel.md`, `kernel/routes.md`, `scripts/lib/kernel-rows.mjs`, `scripts/route-eval.mjs`, `evals/cases/row-*.json`, `evals/heldout.json`, `evals/floors.json`, `scripts/lib/lint-rules.mjs`, `skills/help/references/map.md`, `tests/route-eval-rows.test.mjs`, `tests/lint-rules.test.mjs` | 30 | Routed file, kernel rows, row evals, fixed floors, lint rules 6, 7 and 12 |
| `hooks/session-start`, `hooks/subagent-start`, `hooks/prompt-submit`, `hooks/pre-tool-use`, `tests/hooks/git-hardening.bats`, `tests/hooks/subagent-start.bats` | 31 | Hardened git in hooks; SubagentStart tests |
| `hooks/prompt-submit`, `tests/hooks/prompt-submit.bats`, `tests/fixtures/mode-activation/cases.json`, `tests/helpers/common.bash`, `tests/hooks/pre-tool-use.bats`, `skills/mode/SKILL.md` | 32 | The 0.2.1 minor findings |
| `tests/scripts/no-commit-review.bats`, `scripts/ci-local`, `.github/workflows/ci.yml`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md` | 33 | CI for M2a and release 0.3.0 |

Every task also adds its line to `CHANGELOG.md` when it changes `skills/`, `agents/`, `kernel/` or `hooks/`, and each skill task appends its row to `skills/help/references/map.md`.

Checkpoints: after Tasks 3, 7, 11, 15, 18, 22, 26, 30 and 33, run `scripts/ci-local` and stop if anything is red.

---
