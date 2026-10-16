---
status: draft (parked under autopilot)
form: full
date: 2026-10-15
approved: (unset until an explicit yes)
issue: (tracker id, or none)
---

## Problem

What is wrong or missing today, for whom, with evidence.

## Intent

Outcome. User. Why now. Success. Constraint. Out of scope.

## Constraints

- Always: what every change in this work does (a check to run, a convention to keep).
- Ask first: what needs the user's yes before it happens (a schema change, a new dependency).
- Never: what no task may do (a file not to touch, a system that stays read-only).

plan copies these three lines verbatim into the plan's Global Constraints.

## Assumptions

Each one marked said (the user said it) or assumed (you inferred it).

## Success criteria

How the user will judge it, measurable where possible.

## Acceptance criteria

1. One observable, testable line per criterion.

## Decisions

Modules, interfaces, schema and contracts chosen, each with the alternative rejected.

## Compatibility

Existing data and consumers; every writer of a gated property; the stored shape as it is today; the regression test by name.

## Authorization

Who may call or see what, and the check that scopes it.

## Rollout

Base branch, promotion chain, flags, migration order (expand, migrate, contract).

## Checklists

One line per extra `checklists` item.

## Test seams

Where tests attach: public functions, handlers, CLI entries, components. Prefer the highest seam that already exists and the fewest seams, and confirm the list with the user.

## Not doing

## Open questions
