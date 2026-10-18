---
status: approved
date: 2026-10-10
approved: 2026-10-10, "yes, approved"
---

# Archive paid invoices

## Problem

The invoice list shows every invoice ever issued. Accountants want paid invoices older than a year out of the default list, without losing them.

## Acceptance criteria

1. An invoice paid more than 365 days ago is archived: it has an `archived_at` timestamp.
2. The default list (`listInvoices()`) hides archived invoices; `listInvoices({ includeArchived: true })` shows them.
3. Archiving runs nightly and is idempotent.
4. Archived invoices are never deleted.

## Constraints

- Always: every migration has a working `down`.
- Never: change the shape of `invoices.status`.
