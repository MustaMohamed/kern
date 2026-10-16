
## File map

| Path | Task | Responsibility |
|---|---|---|
| `scripts/lib/behave.mjs`, `scripts/behave.mjs`, `evals/behave/pressure.json`, `evals/behave/workflows.json`, `evals/behave/fixtures/**`, `tests/behave.test.mjs` | 1 | Behavioural runner and pressure tests |
| `scripts/lib/adherence.mjs`, `scripts/kernel-adherence.mjs`, `evals/adherence/cases.json`, `evals/adherence/fixtures/**`, `tests/adherence.test.mjs` | 2 | Kernel-adherence grader |
| `scripts/lib/h2h.mjs`, `scripts/h2h.mjs`, `evals/h2h/arms.json`, `evals/h2h/diagnose/three-calls/**`, `tests/h2h.test.mjs` | 3 | Head-to-head harness and its first fixture |
| `evals/h2h/plan/**`, `tests/h2h.test.mjs` | 4 | Planning fixtures |
| `evals/h2h/diagnose/**`, `tests/h2h.test.mjs` | 5 | Debugging fixtures |
| `evals/h2h/review/invoice-branch/**`, `tests/h2h.test.mjs` | 6 | Review fixture; the fixture set is complete |
| `scripts/standing-cost.mjs`, `tests/standing-cost.test.mjs` | 7 | Standing cost in tokens |
| `evals/snapshots/*.json`, `CHANGELOG.md` | 8 | The evidence runs |
| `docs/specs/coverage.md`, `tests/coverage.test.mjs` | 9 | Coverage re-audit of M2 |
| `docs/pilot.md`, `tests/skills/prove-it.acceptance.md` | 10 | Pilot protocol, written before any pilot run |
| `scripts/route-eval.mjs`, `evals/heldout-pilot.json`, `tests/route-eval-rows.test.mjs`, `docs/pilot.md` | 11 | Pilot runs; real prompts frozen |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`, `docs/pilot.md` | 12 | Release 0.4.0 and the switch-off decision |

Checkpoints: after Tasks 3, 6 and 9, run `scripts/ci-local` and stop if anything is red. Tasks 1 to 7 and 9 to 10 change no skill, agent, kernel or hook file, so lint rule 14 asks for no CHANGELOG line from them; Task 8's fixes do.

Hours: Task 1 1.5, Task 2 1.5, Task 3 2, Task 4 1.5, Task 5 2.5, Task 6 1, Task 7 0.5, Task 8 2 plus fixes, Task 9 1.5, Task 10 1, Task 11 2.5 of agent time (the user's own pilot hours are not counted), Task 12 0.5. Total about 18 hours before fixes, against the design's 12 to 16; the fixtures (Tasks 3 to 6, 7 hours) are the overrun.

---
