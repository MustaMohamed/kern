# Model selection

Every dispatch names its model and its effort. A `model.<role>` setting overrides the model, and `model.<role>.effort` the effort.

## Table

| Role | Setting | Default | Effort | Up a tier when |
|---|---|---|---|---|
| Implementer, batched mechanical edits | `model.implementer` | `haiku` | `low` | the edit needs judgment |
| Implementer, normal task | `model.implementer` | `sonnet` | `medium` | cross-module work, or a round-3 fix |
| Implementer, cross-module or round 3 | `model.implementer` | `opus` | `high` | never higher |
| Task reviewer | `model.reviewer` | `opus` | `medium` | not raised |
| Final whole-branch review | `model.final_review` | `opus` | `high` | not raised |
| Investigator | `model.investigator` | `opus` | `low` | not raised |
| Transcript miner | `model.miner` | `haiku` | `low` | not raised |

## Rules

- Name the model and pass `effort` in every Agent call; never rely on the agent file's default alone.
- Pass `run_in_background: false` when your next step waits on the agent's return; only parallel-work's workers and define's explorers run in the background.
- Effort is the role's `model.<role>.effort`, else the table's. Raise it one step, to `high` at most, for cross-module work or a round-3 fix; keep lookups and transcript mining at `low`.
- A BLOCKED status may move one tier up once; record it as a `Decision:` line.
- Cost grows with tier and effort; do not raise a reviewer to fix an implementer problem.
