---
status: approved
spec: .kern/specs/export.md
date: 2026-10-12
approved: 2026-10-12, "approved, go"
---

# CSV export plan

## Task 1: toCsv for plain values

Files: `src/export.js`, `test/export.test.js`

- [ ] Step 1: write failing tests for AC 1 and AC 3.
- [ ] Step 2: run `npm test`; expect a fail on the missing module.
- [ ] Step 3: add `toCsv` that joins the first row's keys, then each row's values.
- [ ] Step 4: run `npm test`; expect a pass.

## Task 2: quoting

Files: `src/export.js`, `test/export.test.js`

- [ ] Step 1: write a failing test for AC 2.
- [ ] Step 2: quote a value that holds a comma or a quote, doubling inner quotes.
- [ ] Step 3: run `npm test`; expect a pass.
