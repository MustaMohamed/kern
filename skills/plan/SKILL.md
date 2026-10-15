---
name: plan
description: Turn an approved spec into ordered tasks with exact files, test-first steps, verify commands and blocking edges.
disable-model-invocation: true
argument-hint: "[spec path | issue id]"
---

# plan

Produce a plan a zero-context executor can run, with PR boundaries inside the scope gate. Reached by the kernel row for an agreed spec with more than one step, or typed as `/kern:plan`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Check preconditions: a spec with `status: approved`, or issue acceptance criteria the user pointed to. Not approved: stop and route to define, writing nothing. A plan for this spec exists: update it in place. An unfinished plan for other work: stop and ask. Look for existing PRs with `gh pr list --search <id> --state all`; if gh fails or is not signed in: say so and ask. Get `tracker` from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get tracker`, else `kern-detect tracker`; both exit 3: ask.
2. Skip the plan for 1 or 2 files with an obvious approach: say so, write nothing, and the kernel routes to implement.
3. Ground the plan with `kern:investigator` subagents on `model.investigator` (default `sonnet`): file pointers, conventions, stored shapes and their writers. Get each verify command (`test.focused`, `test.full`, `typecheck`, `lint`, `build`) from `kern-get`, else `kern-detect`, and name its source in the plan; both exit 3: ask.
4. Send open product questions to the user as options with a recommendation; send fact questions to subagents. A question that reading cannot settle (does this library do X?) gets a spike first, through define step 8 in a `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach` worktree (exit 2: say why and ask).
5. Write a falsifiable done predicate per acceptance criterion, and the baseline to capture before any change.
6. Map the files, then build the dependency graph bottom-up.
7. Slice into vertical tracer bullets sized for one fresh context. Make the change easy first: a behaviour-preserving prefactor is its own task before the feature. Stored shapes, and a wide mechanical refactor whose call sites span the codebase, change by expand, migrate in batches, then contract. One PR is one change, within `scope_threshold` files or an explicit scope confirmation from the user. Tasks sharing a file or a `shared_services` entry are ordered by Blocked by, never parallel.
8. Write each task from `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/task-template.md`: exact Files (create, modify, test); Interfaces (Consumes, Produces, with signatures); test-first steps with real code; verify commands; Acceptance as a leading list of criterion numbers; Blocked by; one line per `checklists` item. No placeholders.
9. Write the header from `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/plan-template.md`: Goal, issue, spec link, base and promotion path, Global Constraints copied verbatim from the spec's Constraints section, Review Focus (inputs the spec implies but no test exercises, each pinned to a task), `execution:` empty, `commits: ask`.
10. Order the riskiest tasks first, put a checkpoint every 2 or 3 tasks, and add a regression check that runs the same scenario on base and head.
11. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>` and fix every line it prints: structure, ordering of shared files and services, each consumed name blocked by its producer, every acceptance number covered. Then self-review for placeholders and type consistency, and send the plan to one reviewer subagent with `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/plan-review.md` as its brief, round 1 only.
12. Write the plan with the Write tool to `<dir>/<slug>.md`, `<dir>` being what `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir plans` prints (exit 2: say why and ask), with `status: draft`; present a summary in chat (a visual page only when kern's `visual` skill is installed; otherwise say once "visual pages not installed"). Stop the turn: ask for the yes and the `step`, `inline` or `delegate` choice as a typed reply in chat, never through AskUserQuestion, with your one-line recommendation. After the user's yes message, leave the plan file untouched until the approval edit; revising after feedback is fine. On the yes, one Edit sets `status: approved`, `approved: <date>, "<one whole line of the user's yes, verbatim>"` and `execution:` together; run the same plan-check again. Draft tracker sub-issues only on request.

## Inputs

| Key | Default | Use |
|---|---|---|
| `work_dir` | `.kern` | where plans go |
| `base_branch`, `deploy.envs` | detected, none | base and promotion path |
| `scope_threshold` | 4 files | PR size gate |
| `test.*`, `typecheck`, `lint`, `build` | detected, source printed | verify commands in tasks |
| `checklists`, `shared_services` | see define; none | extra lines; ordering |
| `tracker` | detected | issue ids and sub-issue drafts |
| `model.investigator` | `sonnet` | grounding |

## Outputs

`WORK/plans/<slug>.md`; a summary in chat.

## Stops and autopilot

Stops at steps 1, 4 (a spike), 7 and 12. An AskUserQuestion answer records no prompt line, so Guard G20 denies it. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. When on, G20 denies any approval: write the plan with `status: draft`, give each open question in the reply as `parked: <question>; default: <choice>; why: <one line>`. execute-plan runs only an approved plan.

## Red flags

| Thought | Reality |
|---|---|
| "The tasks are obvious" | Write them down. Written tasks surface hidden ordering and forgotten edges. |
| "These two tasks can run side by side" | Not when they share a file or a service. plan-check says which. |
| "I'll work out the unknown during the build" | A question reading cannot settle gets a spike before the plan. |
| "One big task is simpler" | A task too big for one fresh context will be half done. Slice it. |
