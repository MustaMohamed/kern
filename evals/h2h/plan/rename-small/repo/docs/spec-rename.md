---
status: approved
date: 2026-10-10
approved: 2026-10-10, "yes, approved"
---

# Rename calcTotal

## Problem

`calcTotal` reads like a calculator helper; the team calls it the invoice total.

## Acceptance criteria

1. The export is named `invoiceTotal`; `calcTotal` no longer exists.
2. `npm test` passes.
