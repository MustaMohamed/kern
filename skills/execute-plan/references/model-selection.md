# Model selection

Every dispatch names its model. A `model.<role>` setting overrides the default.

## Table

| Role | Setting | Default | Up a tier when |
|---|---|---|---|
| Implementer, batched mechanical edits | `model.implementer` | `haiku` | the edit needs judgment |
| Implementer, normal task | `model.implementer` | `sonnet` | cross-module work, or a round-3 fix |
| Implementer, cross-module or round 3 | `model.implementer` | `opus` | never higher |
| Task reviewer | `model.reviewer` | `sonnet` | not raised |
| Final whole-branch review | `model.final_review` | `opus` | not raised |
| Investigator | `model.investigator` | `sonnet` | not raised |
| Transcript miner | `model.miner` | `haiku` | not raised |

## Rules

- Name the model in every Agent call; never rely on the agent file's default alone.
- A BLOCKED status may move one tier up once; record it as a `Decision:` line.
- Cost grows with tier; do not raise a reviewer to fix an implementer problem.
