---
status: approved
date: 2026-10-10
approved: 2026-10-10, "yes, approved"
---

# Due-soon reminders

## Problem

Customers hear about an invoice only once it is overdue.

## Acceptance criteria

1. An open invoice due in exactly 3 days gets one "due-soon" email.
2. An open invoice due in 2 or 4 days gets none.
3. Running the job twice on the same day sends no second email.
4. Overdue reminders keep working as today.

## Constraints

- Never: send real email from a test.
