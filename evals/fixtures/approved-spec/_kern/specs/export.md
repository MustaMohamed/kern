---
status: approved
form: short
date: 2026-10-12
approved: 2026-10-12, "yes, approved"
issue: none
---

# CSV export

## Problem

Totals cannot leave the service except by copying them by hand.

## Constraints

- Always: keep `npm test` green.
- Ask first: a new dependency.
- Never: change the `sum` signature.

## Acceptance criteria

1. `toCsv([{ a: 1, b: 2 }])` returns `"a,b\n1,2\n"`.
2. A value holding a comma or a quote is quoted, with inner quotes doubled.
3. `toCsv([])` returns an empty string.

## Test seams

`toCsv` in `src/export.js`, called directly from `test/export.test.js`.
