---
status: approved
form: short
date: 2026-10-25
approved: 2026-10-25, "yes, approved"
issue: none
---

# Currency totals

## Problem

bin/cli.js writes a bare number to total.txt; a total carries no currency.

## Size

Files: 4 (src/format.js, new; bin/cli.js; test/format.test.js, new; test/cli.test.js, new). Lines: about 60 changed, insertions plus deletions with tests, as `git diff --shortstat` counts. Concerns: one, currency formatting of the total.

## Constraints

- Always: keep `npm test` green.
- Ask first: a new dependency.
- Never: change the `sum` signature.

## Acceptance criteria

1. `formatCurrency(5, 'USD')` returns `"$5.00"` and `formatCurrency(5, 'EUR')` returns `"€5.00"`. States: `USD`, `EUR`. Handles: `formatCurrency` in `src/format.js`.
2. `formatCurrency(5, 'XYZ')` throws an error whose message is `unknown currency XYZ`. Handles: `formatCurrency`.
3. `node bin/cli.js 2 3 EUR` writes `€5.00` to total.txt, and `node bin/cli.js 2 3` writes `$5.00`. States: `code given`, `no code`. Handles: `bin/cli.js`, `total.txt`.

## Test seams

`formatCurrency` from `test/format.test.js`; `bin/cli.js` run as a child process from `test/cli.test.js`.
