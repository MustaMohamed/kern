---
name: plan
description: Turn an approved spec into ordered tasks with exact files, test-first steps, verify commands and blocking edges.
disable-model-invocation: true
argument-hint: "[spec path | issue id]"
---

# plan

Produce a plan a zero-context executor can run, with PR boundaries inside the scope gate.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Check preconditions: a spec file with `status: approved`. Not approved: stop and route to define, writing nothing; issue acceptance criteria alone are not approved (its bounded path records them as an approved short spec). A plan for this spec exists: set `status: draft`, then update it in place. An unfinished plan for other work: stop and ask. Under autopilot a step 1 stop parks: give the `parked:` line in the reply and create no plan file. Look for existing PRs with `gh pr list --search <id> --state all`; if gh fails or is not signed in: say so and ask. Get `tracker` from `kern-get`, else `kern-detect`; both exit 3: ask.
2. Skip the plan for 1 or 2 files with an obvious approach: say so, write nothing; the kernel routes to implement.
3. Ground it with `kern:investigator` subagents on `model.investigator`: file pointers, conventions, stored shapes and their writers. Get each verify command from `kern-get`, else `kern-detect`, naming its source in the plan; both exit 3: ask.
4. Product questions go to the user as options with a recommendation; fact questions go to subagents. A question that reading cannot settle gets a spike first, through define step 8 in a `wt-new <slug> --detach` worktree (exit 2: say why and ask). Record its answer under Open questions as the branch or SHA plus the evidence.
5. Write a falsifiable done predicate per acceptance criterion, and the baseline to capture first.
6. Map the files, then build the dependency graph bottom-up.
7. Slice into vertical tracer bullets, each demoable on its own and sized for one fresh context. A behaviour-preserving prefactor is its own task before the feature. Stored shapes, and a wide mechanical refactor whose call sites span the codebase, change by expand, migrate in batches, then contract, the contract task blocked by every migrate batch. One PR is one change, within `scope_threshold` files, else stop and ask the user to confirm the scope or split. Wherever the plan or reply states the limit, write `scope_threshold: <n> (kern-get)` when `kern-get scope_threshold` prints a value, else `scope_threshold: 4 (kern default; not set)`, never "your limit" for a default. Tasks sharing a file or a `shared_services` entry are ordered by Blocked by, never parallel.
8. Write each task from `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/task-template.md`: exact Files; Interfaces; test-first steps that record decisions, not code; verify commands; Acceptance; Blocked by. No placeholders.
9. Write the header from `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/plan-template.md`: Global Constraints verbatim from the spec's Constraints section, Review Focus, `execution:` empty, `commits: ask`. Get `base_branch` from `kern-get`, else `kern-detect`, naming its source; both exit 3: `base: <current branch> (current branch; not detected)`, from `git branch --show-current`; it prints nothing: `base: unknown (detached HEAD; not detected)`.
10. Order the riskiest tasks first; add checkpoints and the base-and-head regression check as plan-template.md says.
11. Write the plan with the Write tool to `<dir>/<slug>.md`, `<dir>` being what `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir plans` prints (exit 2: say why and ask), with `status: draft`. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>` and fix every line it prints. Self-review it for placeholders, type mismatches and proportion; send the plan to one fresh general-purpose subagent on `model.reviewer` (`run_in_background: false`), with `${CLAUDE_PLUGIN_ROOT}/skills/plan/references/plan-review.md` as its brief, round 1 only. Only the user's word skips this review, never size or budget.
12. Present a summary in chat, saying when the base was not detected (a visual page when kern's `visual` skill is installed, else say once "visual pages not installed"). Stop the turn: ask for the yes and the `step`, `inline` or `delegate` choice as a typed reply in chat, never through AskUserQuestion, with your one-line recommendation. A yes with a change request: make it, show it, ask again. A reply that is no explicit yes or names no choice: ask again. After the user's yes message, leave the plan file untouched until the approval edit. On the yes, one Edit sets `status: approved`, `approved: <date>, "<one whole line of the user's yes, verbatim>"` and `execution:` together; run the same plan-check again. Draft tracker sub-issues only on request.

## Inputs

| Key | Default | Use |
|---|---|---|
| `work_dir` | `.kern` | where plans go |
| `base_branch`, `deploy.envs` | detected, none | base and promotion path |
| `scope_threshold` | 4 files | PR size gate |
| `test.*`, `typecheck`, `lint`, `build` | detected, source printed | task verify commands |
| `checklists`, `shared_services` | see define; none | extra lines; ordering |
| `tracker`, `tracker.first` | detected, `false` | issue ids and sub-issue drafts |
| `model.investigator`, `model.reviewer` | `sonnet` | grounding; review |

## Outputs

`WORK/plans/<slug>.md`; a summary in chat.

## Stops and autopilot

Stops at steps 1, 4 (a spike), 7 and 12. An AskUserQuestion answer records no prompt line, so Guard G20 denies it. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. When on, every stop parks: the step 4 spike is not run and the step 7 scope question takes its default, the split, never a plan over `scope_threshold`; write the plan with `status: draft`; put each as `parked: <question>; default: <choice>; why: <one line>` under Open questions in the plan and in the reply. execute-plan runs only an approved plan.

## Red flags

| Thought | Reality |
|---|---|
| "The tasks are obvious" | Write them down: writing surfaces hidden order and missed edges. |
| "These two tasks can run side by side" | Not when they share a file or a service. plan-check says which. |
| "One big task is simpler" | A task too big for one fresh context ends half done. Slice it. |
