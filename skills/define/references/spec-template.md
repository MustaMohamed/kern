# Spec template

Copy from the first `---` line to the end into `WORK/specs/<slug>.md`. Complete every section, or write `none` and why. Decisions name modules and contracts, not file paths; paths belong in the plan. A bounded change uses the short form: set `form: short` and keep only Problem, Constraints, Acceptance criteria and Test seams. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` checks the sections for either form. To approve, one Edit replaces the lines from `status: draft` through `approved:` with `status: approved` and `approved: <date>, "<one whole line of the user's yes>"`.

---
status: draft
form: full
date: YYYY-MM-DD
approved: (unset until an explicit yes)
issue: (tracker id, or none)
---

## Problem

What is wrong or missing today, for whom, with evidence.

## Intent

Outcome. User. Why now. Success. Anti-goals: what would make it a failure even if it works. Prior art: what the user has seen elsewhere, loved or hated. Constraint. Out of scope.

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

Modules, interfaces, schema and contracts chosen, each with the alternative rejected. Mark each one you settled without the user as `kern's call`, and name what is left to the builder.

## Compatibility

Existing data and consumers; every writer of a gated property; the stored shape as it is today; the regression test by name.

## Authorization

Who may call or see what, and the check that scopes it.

## Rollout

Base branch, promotion chain, flags, migration order (expand, migrate, contract). The rollback path at each stage; each stage is safe to rerun and its partial failure shows; a test runs the old and the new path at each stage where both are live.

## Checklists

One line per extra `checklists` item.

## Test seams

Where tests attach: public functions, handlers, CLI entries, components. Prefer the highest seam that already exists and the fewest seams, and confirm the list with the user.

## Not doing

## Open questions
