---
name: define
description: Clarify new behaviour, classify it spike, bounded or architectural, and get explicit approval before any code.
disable-model-invocation: true
argument-hint: "[issue id | idea]"
---

# define

Turn an ask into an approved shared understanding, and for architectural work an approved spec, before any code. Reached by the kernel row for new behaviour with no agreed spec, or typed as `/kern:define`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Ticket. With `tracker.first: true`, find and read the issue: body, comments, parent. Get `tracker` from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get tracker`, else `kern-detect tracker`; when both exit 3, ask. No issue: offer an issue draft, and never post it.
2. Explore read-only with `kern:investigator` subagents on `model.investigator` (default `sonnet`): relevant files, recent commits, related PRs, the stored shape of any persisted field, every writer of a property the change gates on, and whether the gap is real on `origin/<base>`. Ask meanwhile what does not wait on them. Never ask the user a fact the repo can answer.
3. Classify and say it: spike; bounded (an existing flow, within `scope_threshold` files, no change to a public API, a persisted schema or authorization); else architectural. A request with no existing flow to extend is architectural. Take the heavier class when in doubt; upgrade mid-task, never downgrade.
4. For several independently testable capabilities, draw a capability map with a build order (`references/capability-map.md`). The map is approved before any module spec.
5. Intent: state a HYPOTHESIS and a CONFIDENCE, naming what is missing below about 70%. Ask intent questions one at a time, each with your guess; probe want versus should-want; skip what the issue already states (`references/interview.md`).
6. Decisions: ask in numbered frontier rounds in chat, each question with a recommended answer worded so "yes" accepts it. Three or more options: a visual page only when kern's `visual` skill is installed; otherwise chat, saying once "visual pages not installed".
7. Restate: Outcome, User, Why now, Success, Constraint, Out of scope; then what was said versus what is assumed. Only an explicit yes approves; "sounds good", "whatever you think" and silence do not.
8. Spike: state the question and the probe in 2 or 3 sentences and wait for a nod. Probe in a `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach` worktree, or under `WORK/tmp`, never in the main checkout; exit 2 means say why and ask. Return an answer, not code; the code is throwaway.
9. Bounded: give an in-chat design (approach, files, tests, constraints as always, ask first and never, one line per `checklists` item) and ask for the yes as a typed reply in chat, never through AskUserQuestion. On yes, write the spec only now, as a new file in the directory `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir specs` prints, in short form (`form: short`) from `references/spec-template.md`, with `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` in that one write. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` (exit 1 prints `FILE:LINE: message`; fix each with an edit that leaves both approval lines alone). The kernel then routes to implement.
10. Architectural: offer 2 or 3 approaches, recommendation first; present the design in sections and get approval per section; write the spec from `references/spec-template.md` (or the project's spec system) with `status: draft`; run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` and fix what it reports; self-review it for contradictions, scope and two-reading ambiguity; send it to one fresh general-purpose subagent on `model.reviewer` with `references/spec-review.md`, round 1 only. Fix what it finds, then stop the turn and ask for the yes as a typed reply in chat, never through AskUserQuestion. Touch the file in no other way after the user's message. On the yes, one Edit sets `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` together; the kernel then routes to plan.

Standing gate on every path: no code, scaffold, dependency install, migration or branch before that path's approval. An approval covers only the stage presented. Every approval is a typed reply: an AskUserQuestion answer records no prompt line, so G20 denies the approval. Guard G20 also denies a quote that is not one whole line (under 500 characters) of the user's last message, and a spec edited after that message; quote only the line that holds the yes.

## Inputs

| Key | Default | Use |
|---|---|---|
| `tracker`, `tracker.first` | detected, `false` | read the issue first |
| `scope_threshold` | 4 files | bounded versus architectural |
| `checklists` | existing data and consumers; authorization scope; persisted-shape change | extra design lines |
| `base_branch` | detected | where the gap is checked |
| `work_dir` | `.kern` | where specs go |
| `model.investigator`, `model.reviewer` | `sonnet` | exploration; the spec review |

The project's own spec system wins when it exists (`docs/specs`, `docs/rfcs`, an ADR directory); else specs go to `WORK/specs`.

## Outputs

`WORK/specs/<slug>.md`.

## Stops and autopilot

Product and preference calls go to the user. After two rounds without rising confidence, step back and say so. Under autopilot define cannot approve itself (G20 denies it): it writes the draft with open questions and recommended answers, marks it `status: draft (parked under autopilot)`, and records each question under Open questions and in the reply as `parked: <question>; default: <choice>; why: <one line>`. Only work that does not depend on it continues.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to need a design" | A bounded change still gets a short design and a yes. |
| "I'll call it bounded and skip the spec" | Reaching for the lighter class to skip work is the doubt. Take the heavier one. |
| "The design is obvious, I'll start while they read" | The gate is the approval, not the design's length. Stop until you hear yes. |
| "It grew, but I'm nearly done" | Hidden scope upgrades the class. Stop and say so. |
| "They said sounds good" | Only an explicit yes approves, quoted in the spec. |
| "I'll write the spec and the plan in one turn" | The turn ends after the spec. The plan waits for the yes. |
