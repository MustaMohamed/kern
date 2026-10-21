---
name: define
description: Clarify new behaviour, size it, and get an explicit yes before code unless the user calls it quick or waives it.
disable-model-invocation: true
argument-hint: "[issue id | idea]"
---

# define

Turn an ask into an approved shared understanding, plus an approved spec when architectural, before code.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Fast path: when the user's own words call the task quick and clear, or explicitly waive approval: no design, spec or approval. After your reads, before any edit, say `Building: <what>. My choices: <each>.` A change to an existing public API (not a new export), schema or authorization, or a missing fact that changes the build: say so, and ask whether to keep it; under a waiver, ask nothing: say it in that line, a missing fact as your assumption. Then route to implement.
2. Ticket. With `tracker.first: true`, read the issue, comments and parent. Get `tracker` from `kern-get tracker`, else `kern-detect tracker`; both exit 3: ask. No issue: offer a draft, never post it.
3. Explore read-only with `kern:investigator` subagents on `model.investigator`, dispatched in one message: relevant files, recent commits, related PRs, the stored shape of a persisted field, every writer of a property the change gates on, and whether the gap is real on `origin/<base>`. Meanwhile ask the rest. Never ask the user a fact the repo can answer.
4. Intent, per `references/interview.md`: the skip offer, the build choices the user owns, a HYPOTHESIS and a CONFIDENCE, one question at a time with your guess. Skip what the issue states.
5. Restate as interview.md says, said apart from assumed. Only an explicit yes approves; "sounds good", "whatever you think" and silence do not.
6. Size it now, in plain words; the user may override: a spike (a throwaway probe); bounded (designed in chat: an existing flow, within `scope_threshold` files, no public API, persisted schema or authorization change); else architectural (a written spec). A request with no existing flow to extend is architectural. In doubt go heavier; upgrade mid-task, never downgrade. Several independently testable capabilities: map them (`references/capability-map.md`). The map is approved before any module spec.
7. Decisions: ask in numbered rounds in chat, each question with a recommended answer worded so "yes" accepts it. A question that depends on an open one waits a round. Three or more options: chat, saying once "visual pages not installed", unless `visual` is installed.
8. Spike: state the question and probe in 2 or 3 sentences; wait for a nod. Probe in a `wt-new <slug> --detach` worktree, or under `WORK/tmp`, never in the main checkout; exit 2: say why and ask. Return an answer; the code is throwaway.
9. Bounded: give an in-chat design (approach, files, tests, always, ask first and never constraints, a line per `checklists` item) and ask for the yes as a typed reply in chat, never through AskUserQuestion. On yes, write a `form: short` spec from `references/spec-template.md` in the directory `kern-dir specs` prints, with `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` in that one write. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` (fix what it prints; keep both approval lines). The kernel then routes to implement.
10. Architectural: offer 2 or 3 approaches, recommendation first; present the design in sections, each approved; write the spec from `references/spec-template.md` with `status: draft`; run `plan-check <spec>` and fix what it reports; self-review it.
11. Spec review (architectural): send the spec to one fresh general-purpose subagent on `model.reviewer` with `run_in_background: false`, its brief `${CLAUDE_PLUGIN_ROOT}/skills/define/references/spec-review.md`, round 1 only. An approved design does not skip it; only the user naming the review does. The user's own review is not this one. Fix its findings; sort its builder questions as `references/handover.md` says.
12. Architectural approval: stop the turn and ask for the yes as a typed reply in chat, never through AskUserQuestion. After the user's yes message, leave the file untouched until the approval edit. On the yes, one Edit sets both of step 9's approval lines; run the same plan-check again; the kernel then routes to plan.

Standing gate on every path: no code, scaffold, install, migration or branch before that path's approval (on the fast path, the user's words); commits, pushes and every other ask stay gated. An approval covers only the stage presented. An AskUserQuestion answer records no prompt line, so Guard G20 denies it.

## Inputs

| Key | Default | Use |
|---|---|---|
| `tracker`, `tracker.first` | detected, `false` | issue |
| `scope_threshold` | 4 files | size |
| `checklists` | existing data and consumers; authorization scope; persisted-shape change | lines |
| `base_branch` | detected | gap check |
| `model.investigator`, `model.reviewer` | `sonnet` | explore; review |

A project's own spec system (`docs/specs`) wins, but its spec still carries kern's `status` and `approved` lines, which G20 and plan read.

## Outputs

`WORK/specs/<slug>.md`.

## Stops and autopilot

Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. When on, every path parks, as G20 denies any approval: define writes the draft with its open questions, marks it `status: draft (parked under autopilot)`, and records each question under Open questions and in the reply as `parked: <question>; default: <choice>; why: <one line>`. The fast path runs. Independent work continues.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to need a design" | Only the user's own "quick and clear" or approval waiver skips the design. |
| "I'll call it bounded and skip the spec" | Going lighter to skip work is the doubt. Go heavier. |
| "The design is obvious, I'll start while they read" | The gate is the approval. Stop for the yes. |
| "It grew, but I'm nearly done" | Hidden scope upgrades the size. Stop and say so. |
| "The design is approved, so the review adds nothing" | The reviewer reads the spec as its builder and finds what the design left open. |
