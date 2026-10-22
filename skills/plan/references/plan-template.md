# Plan template

Copy from the first `---` line to the end into `WORK/plans/<slug>.md`. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>` checks the result: structure, ordering of shared files and services, each consumed name blocked by its producer, every acceptance number covered.

---
status: draft
spec: WORK/specs/<slug>.md
issue: (tracker id, or none)
base: <base branch> (<source>); promotion: <branch chain, or none>
approved: (set only on an explicit yes, in the same edit as status: approved: the date, then one whole line of the user's message in double quotes)
execution:
commits: ask
---

**Goal:** one sentence.

**Architecture:** two or three sentences.

## Global Constraints

The spec's Constraints lines (Always, Ask first, Never), verbatim, then one line each for other exact values the spec fixes. Every task's brief includes this section.

## Review Focus

Inputs or conditions the spec implies but no test exercises, most likely first, each naming the task whose test pins it.

## Open questions

A spike's answer: the branch or SHA plus the evidence. Under autopilot, each `parked: <question>; default: <choice>; why: <one line>` line. Else none.

## File map

| Path | Task | Responsibility |
|---|---|---|

### Task 1: <name>

(Tasks follow `task-template.md`, one line per `checklists` item in each. Put a checkpoint step every 2 or 3 tasks, and add a regression check that runs the same scenario on base and head, naming the base by branch, never by a SHA no command printed.)
