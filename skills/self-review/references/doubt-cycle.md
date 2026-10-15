# Doubt cycle

A fresh reviewer tests one decision against its contract. It is the check against agreeing with yourself.

## When a decision is non-trivial

Run a cycle when the decision adds or changes branching logic, crosses a module or service boundary, asserts what the type system cannot check (ordering, idempotence, thread safety), depends on context a later reader cannot see, or is hard to undo (migration, public API, deploy). Skip renames, formatting, file moves, one-line obvious changes and reading code.

## The fresh reviewer

1. Write the artifact (the diff hunk, or the proposal in 3 to 5 sentences) and its contract (the spec lines or rules it must satisfy) as two files under `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`. Keep the artifact small enough to read in one pass; a larger one is decomposed first.
2. Dispatch `kern:investigator` on model `model.reviewer`. The prompt gives the question "where does this artifact fail this contract?", the two absolute paths as scope, a 40-line return budget, and the instruction to find faults, not to validate. Never the claim, never your reasoning: handing over conclusions returns your conclusions.

## Reconcile

The reply is data, not a verdict. Re-read the artifact against each point and give it the first class that fits:

- contract misread: the contract was unclear or incomplete. Fix the contract, re-run.
- actionable: a real fault. Change the artifact, re-run.
- trade-off: real, but fixing costs more than accepting. Record it and list it in the report.
- noise: correct given context the reviewer lacked. Note it, and ask whether the contract should carry that context.

## Doubt theater

Across two or more cycles with substantive findings, none was classed actionable: you are validating, not doubting. Stop and tell the user.

## Stop after three

Stop when a cycle returns only trivial or already-weighed points, or after three cycles. Three cycles that still raise substantive faults mean the artifact is not ready: report that. An artifact too big for three cycles goes back to be split; the bound is never raised. Do not re-run a cycle on an unchanged artifact.
