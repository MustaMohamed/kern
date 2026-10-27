# Verification tasks

A verification task shows that the plan's change reaches the states its spec names. Its Files modify nothing. Its evidence (scripts, reads, screenshots) goes under `kern-dir tmp`, never in the repository.

## Brief

- CONTEXT: only the spec lines and states its steps name, the evidence rows to fill and the project's method file for them. Not the earlier tasks' reports or reviews.
- ACCEPTANCE: one line per state, saying what its evidence must show.
- REPORT: a `| State | Evidence | Result |` table. Each Evidence cell names a stored file: a value with no stored output proves nothing.

## Review

`wt-diff` exits 3 by design: say so in the review prompt and go on. Dispatch `kern:task-reviewer` in mode `evidence` with the brief, the report and the evidence directory, saved and recorded as step 8 says. At most two rounds, the review and one fix round: each round repeats the whole gathering. A state still unproven after round 2: stop and ask, naming each one; never start a third round.

## Close

`task-done <ledger> <N> <wt> <tree-after> --no-probe "verification task: no code" -- bash <script>`, where `<script>` is a `kern-dir tmp` file that runs `test -s` on each evidence file the report names.
