---
status: approved
date: 2026-10-10
approved: 2026-10-10, "yes, approved"
---

# Q4 changes

## Problem

Finance renamed the "clerk" role to "accountant", and wants invoices as a spreadsheet.

## Acceptance criteria

1. Every permission check that accepts "clerk" accepts "accountant" instead.
2. Stored users with role "clerk" read as "accountant".
3. `GET /invoices.xlsx` returns the invoice rows as a spreadsheet.
4. The spreadsheet has a header row: id, total.

## Constraints

- Ask first: a new dependency.
