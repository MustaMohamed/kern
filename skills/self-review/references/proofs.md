# Proofs

One proof per acceptance line, and per state the line names after `States:`. `proof-check <spec> <proofs>` matches the table to the spec and lists every line or state with no proof.

## Table

`<package>.proofs.md` holds one Markdown table: a `| Line | State | Evidence |` header, a divider, then one row per state a line names, or one `-` row for a line with no `States:`. Line is the acceptance number. State is one of the line's backticked states; a `-` row on a line that names states is `unknown`.

## Evidence

Evidence is what this session ran and saw: a command in backticks and its result (`npm test -- form`: 12 passed), or the path of a file it wrote, such as a screenshot of that state, in backticks and starting with `/`, `./` or `../`. A path must exist. A claim, `none` or an empty cell proves nothing. A screenshot shows the state it is filed under: the edit form for `edit`, the rows after the scroll for rows reached by scrolling.

## Gaps

A line or state with no row is unproven: the check fails, and the verdict is `fix first`. Get the proof, or ask the user to drop the state from the spec; never file a proof for a state it does not show.
