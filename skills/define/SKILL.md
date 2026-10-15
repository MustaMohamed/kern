---
name: define
description: Clarify new behaviour, classify it spike, bounded or architectural, and get explicit approval before any code.
disable-model-invocation: true
argument-hint: "[issue id | idea]"
---

# define

Turn an ask into an approved shared understanding, plus an approved spec when architectural, before any code. Reached by the kernel row for new behaviour, or as `/kern:define`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Ticket. With `tracker.first: true`, read the issue, comments and parent. Get `tracker` from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get tracker`, else `kern-detect tracker`; both exit 3: ask. No issue: offer a draft, never post it.
2. Explore read-only with `kern:investigator` subagents on `model.investigator`, dispatched in one message: relevant files, recent commits, related PRs, the stored shape of a persisted field, every writer of a property the change gates on, and whether the gap is real on `origin/<base>`. Meanwhile ask what does not wait. Never ask the user a fact the repo can answer.
3. Classify and say it: spike; bounded (an existing flow, within `scope_threshold` files, no change to a public API, a persisted schema or authorization); else architectural. A request with no existing flow to extend is architectural. When in doubt take the heavier class; upgrade mid-task, never downgrade.
4. For several independently testable capabilities, draw a capability map (`references/capability-map.md`). The map is approved before any module spec.
5. Intent: state a HYPOTHESIS and a CONFIDENCE (name what is missing below about 70%); ask one question at a time, each with your guess; probe want versus should-want; skip what the issue states (`references/interview.md`).
6. Decisions: ask in numbered rounds in chat, each question with a recommended answer worded so "yes" accepts it. A question that depends on an open one waits a round. Three or more options: a visual page only when kern's `visual` skill is installed; otherwise chat, saying once "visual pages not installed".
7. Restate: Outcome, User, Why now, Success, Constraint, Out of scope; then what was said versus assumed. Only an explicit yes approves; "sounds good", "whatever you think" and silence do not.
8. Spike: state the question and probe in 2 or 3 sentences; wait for a nod. Probe in a `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach` worktree, or under `WORK/tmp`, never in the main checkout; exit 2 means say why and ask. Return an answer; the code is throwaway.
9. Bounded: give an in-chat design (approach, files, tests, always, ask first and never constraints, a line per `checklists` item) and ask for the yes as a typed reply in chat, never through AskUserQuestion. On yes, only then write the spec, a new short-form (`form: short`) file from `references/spec-template.md` in the directory `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir specs` prints, with `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` in that one write. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` (exit 1 lists `FILE:LINE: message`; fix each, keep both approval lines). The kernel then routes to implement.
10. Architectural: offer 2 or 3 approaches, recommendation first; present the design in sections, each approved; write the spec from `references/spec-template.md` (or the project's spec system) with `status: draft`; run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` and fix what it reports; self-review it for contradictions, scope and ambiguity; send it to one fresh general-purpose subagent on `model.reviewer`, with `${CLAUDE_PLUGIN_ROOT}/skills/define/references/spec-review.md` as its brief, round 1 only. Fix its findings, stop the turn, and ask for the yes as a typed reply in chat, never through AskUserQuestion. After the user's yes message, leave the file untouched until the approval edit. On the yes, one Edit sets `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` together; run the same plan-check again; the kernel then routes to plan.

Standing gate on every path: no code, scaffold, install, migration or branch before that path's approval. An approval covers only the stage presented. An AskUserQuestion answer records no prompt line, so Guard G20 denies it. G20 also denies a quote that is not one whole line (under 500 characters) of the user's last message, and a spec edited after it; quote only the line with the yes.

## Inputs

| Key | Default | Use |
|---|---|---|
| `tracker`, `tracker.first` | detected, `false` | issue |
| `scope_threshold` | 4 files | class |
| `checklists` | existing data and consumers; authorization scope; persisted-shape change | lines |
| `base_branch` | detected | gap check |
| `model.investigator`, `model.reviewer` | `sonnet` | explore; review |

The project's own spec system wins when it exists (`docs/specs`, an ADR directory) but its spec still carries kern's `status` and `approved` frontmatter lines, which G20 and plan read; else specs go to `WORK/specs`.

## Outputs

`WORK/specs/<slug>.md`.

## Stops and autopilot

Product and preference calls go to the user. After two rounds without rising confidence, say so and step back. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. When on, every path parks (spike, bounded, architectural), as G20 denies any approval: define writes the draft with its open questions, marks it `status: draft (parked under autopilot)`, and records each question under Open questions and in the reply as `parked: <question>; default: <choice>; why: <one line>`. Independent work continues.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to need a design" | A bounded change still gets a short design and a yes. |
| "I'll call it bounded and skip the spec" | Picking the lighter class to skip work is the doubt. Go heavier. |
| "The design is obvious, I'll start while they read" | The gate is the approval, not the design's length. Stop for the yes. |
| "It grew, but I'm nearly done" | Hidden scope upgrades the class. Stop and say so. |
| "They said sounds good" | Only an explicit yes approves. |
| "I'll write the spec and the plan in one turn" | The turn ends after the spec. The plan waits for the yes. |
