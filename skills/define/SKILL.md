---
name: define
description: Clarify new behaviour, size it after the intent, and get an explicit yes before code unless the user calls it quick.
disable-model-invocation: true
argument-hint: "[issue id | idea]"
---

# define

Turn an ask into an approved shared understanding, plus an approved spec when architectural, before code. Reached by the kernel row for new behaviour, or as `/kern:define`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Fast path: when the user's own words call the task quick and clear, say in one line what you will build and your choices, then route to implement: no design, spec or approval. A public API, schema or authorization change, or a missing fact that changes the build: say so, and ask whether to keep it.
2. Ticket. With `tracker.first: true`, read the issue, comments and parent. Get `tracker` from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get tracker`, else `kern-detect tracker`; both exit 3: ask. No issue: offer a draft, never post it.
3. Explore read-only with `kern:investigator` subagents on `model.investigator`, dispatched in one message: relevant files, recent commits, related PRs, the stored shape of a persisted field, every writer of a property the change gates on, and whether the gap is real on `origin/<base>`. Meanwhile ask the rest. Never ask the user a fact the repo can answer.
4. Intent, per `references/interview.md`: the skip offer, the build choices the user owns, a HYPOTHESIS and a CONFIDENCE, one question at a time with your guess. Skip what the issue states.
5. Restate as interview.md says, said apart from assumed. Only an explicit yes approves; "sounds good", "whatever you think" and silence do not.
6. Size it now, in plain words; the user may override: a spike (a throwaway probe); bounded (designed in chat: an existing flow, within `scope_threshold` files, no public API, persisted schema or authorization change); else architectural (a written spec). A request with no existing flow to extend is architectural. In doubt go heavier; upgrade mid-task, never downgrade. Several independently testable capabilities: map them (`references/capability-map.md`). The map is approved before any module spec.
7. Decisions: ask in numbered rounds in chat, each question with a recommended answer worded so "yes" accepts it. A question that depends on an open one waits a round. Three or more options: chat, saying once "visual pages not installed", unless kern's `visual` skill is installed.
8. Spike: state the question and probe in 2 or 3 sentences; wait for a nod. Probe in a `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach` worktree, or under `WORK/tmp`, never in the main checkout; exit 2: say why and ask. Return an answer; the code is throwaway.
9. Bounded: give an in-chat design (approach, files, tests, always, ask first and never constraints, a line per `checklists` item) and ask for the yes as a typed reply in chat, never through AskUserQuestion. On yes, only then write a new short-form (`form: short`) spec from `references/spec-template.md` in the directory `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir specs` prints, with `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` in that one write. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` (fix what it prints; keep both approval lines). The kernel then routes to implement.
10. Architectural: offer 2 or 3 approaches, recommendation first; present the design in sections, each approved; write the spec from `references/spec-template.md` (or the project's spec system) with `status: draft`; run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <spec>` and fix what it reports; self-review it; send it to one fresh general-purpose subagent on `model.reviewer`, with `${CLAUDE_PLUGIN_ROOT}/skills/define/references/spec-review.md` as its brief, round 1 only. Fix its findings; sort its builder questions as `references/handover.md` says. Stop the turn and ask for the yes as a typed reply in chat, never through AskUserQuestion. After the user's yes message, leave the file untouched until the approval edit. On the yes, one Edit sets `status: approved` and `approved: <date>, "<one whole line of the user's yes, verbatim>"` together; run the same plan-check again; the kernel then routes to plan.

Standing gate on every path: no code, scaffold, install, migration or branch before that path's approval (on the fast path, the user's words); commits, pushes and every other ask stay gated. An approval covers only the stage presented. An AskUserQuestion answer records no prompt line, so Guard G20 denies it. G20 also denies a quote that is not one whole line of the user's last message, and a spec edited after it; quote only the line with the yes.

## Inputs

| Key | Default | Use |
|---|---|---|
| `tracker`, `tracker.first` | detected, `false` | issue |
| `scope_threshold` | 4 files | size |
| `checklists` | existing data and consumers; authorization scope; persisted-shape change | lines |
| `base_branch` | detected | gap check |
| `model.investigator`, `model.reviewer` | `sonnet` | explore; review |

A project's own spec system (`docs/specs`, an ADR directory) wins, but its spec still carries kern's `status` and `approved` lines, which G20 and plan read; else specs go to `WORK/specs`.

## Outputs

`WORK/specs/<slug>.md`.

## Stops and autopilot

Product and preference calls go to the user. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. When on, every path parks (spike, bounded, architectural), as G20 denies any approval: define writes the draft with its open questions, marks it `status: draft (parked under autopilot)`, and records each question under Open questions and in the reply as `parked: <question>; default: <choice>; why: <one line>`. The fast path runs. Independent work continues.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to need a design" | Only the user's own "quick and clear" skips the design. |
| "I'll call it bounded and skip the spec" | Going lighter to skip work is the doubt. Go heavier. |
| "The design is obvious, I'll start while they read" | The gate is the approval. Stop for the yes. |
| "It grew, but I'm nearly done" | Hidden scope upgrades the size. Stop and say so. |
