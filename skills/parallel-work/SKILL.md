---
name: parallel-work
description: "Fan out independent work: one worktree per writer, overlaps serialized, results integrated and re-tested."
disable-model-invocation: true
---

# parallel-work

Run independent units at once, never two writers in one tree. Reached from execute-plan step 4, from diagnose when racing hypotheses, or typed as `/kern:parallel-work`.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Classify each unit independent, related or shared-state. Build the overlap list from each unit's files and `shared_services` (none set: any unit running migrations or DB-backed tests overlaps). Overlapping units run serially. Separate a shared write target before anything serializes on it. With 3 or more writers doing one kind of change, run one pilot unit first and read its result first. A unit you cannot classify is a stop.
2. Frame the run: the done predicate; partition or race (a race declares its selection rule before spawning and integrates only the winner); at most `parallel.max` workers at once, the rest wait; a model named in every dispatch (`model.implementer`, `model.investigator`). Record the main checkout's branch with `git rev-parse --abbrev-ref HEAD`. A script exit this skill does not name stops that unit; report its output.
3. Per writer: create its worktree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-fork <source-wt> <slug>` to carry earlier uncommitted work, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug> --detach`; each prints the path, and any non-zero exit: say why and ask, never share a tree. The base ref is `origin/<base_branch>` for wt-new, the source's HEAD for wt-fork. Record its starting tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`. Write the brief with the Write tool to `<tmp>/brief-<worker>.md` (`<tmp>` is what `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints) from `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/brief-template.md`, its VERIFY starting with the entry check `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-check <wt> <base-ref>` and then the focused baseline; resolve `${CLAUDE_PLUGIN_ROOT}` to the absolute root in all a worker receives (its Read substitutes nothing). Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/brief-check <brief>`: anything but `brief-check: ok` means do not spawn; fix each printed line and rerun. A reader gets no worktree and no brief: its prompt holds the question, scope, sources and a return budget (`kern:investigator`, or Explore).
4. Spawn every worker in one message, each with `run_in_background: true` and its model named. A writer is `kern:implementer`, given the brief path, WT, base ref, a report path under `<tmp>`, the absolute path of `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`, rulings and standing orders. Never poll a worker or resume it to check liveness.
5. Drain each worker to PASS, ISSUES or BLOCKED. `kern:implementer`, by its `Status:` line (none: BLOCKED): DONE is PASS, DONE_WITH_CONCERNS is ISSUES, BLOCKED and NEEDS_CONTEXT are BLOCKED. `kern:investigator`: an answer where every fact carries a citation and a label, with an empty or "none" could-not-trace list, is PASS; an uncited fact or a "could not trace" list is ISSUES; no answer, or a return that names a command it needs run, is BLOCKED. Missing evidence (no test output, no report file) gets one respawn naming it, then a gap. A worker silent past its TIMEBOX: check read-only whether its report file exists and whether `wt-snap` prints another tree, record a gap with what you found, and never resume it; a silent reader, which has neither, is re-asked once, then BLOCKED. Account for every worker; a gap is not a pass.
6. Integrate one worker at a time. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-diff <wt> <starting-tree> --out <dir>/<worker>.diff --allow <path>` with one `--allow` per writable SCOPE path (a directory ends in `/`, a prefix in `*`); `<dir>` is the caller's ledger `reviews/` folder, else `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir reviews` prints it. It prints the package path, the tree, then changed paths; the patch is `<dir>/<worker>.diff.patch`. Exit 3 is no change: a gap. Exit 4 is a write outside SCOPE: ISSUES, apply nothing, stop. Then `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-apply <dir>/<worker>.diff.patch <integration-wt>` (the caller's, else a `wt-new` one) prints `applied`, and only then record wt-diff's second line; exit 3 is a conflict with nothing applied: stop, no tree recorded. After the last patch run `test.full` there (`kern-get`, else `kern-detect`; both exit 3: ask), name each red test as before or after, and spot-check one claim per worker against its diff.
7. Report a table with columns `worker | verdict | files | evidence | gaps`, serial units with their reason, each recorded tree in evidence. Assert the main branch still matches step 2's.
8. Teardown follows `${CLAUDE_PLUGIN_ROOT}/skills/parallel-work/references/worktrees.md`: `wt-audit` filtered to this run's worktrees, `--force` only when all five preconditions there hold, every removal only on the user's yes.

## Inputs

| Key | Default | Use |
|---|---|---|
| `base_branch` | detected | worktree base |
| `worktree.dir`, `worktree.setup` | `.claude/worktrees` under MAIN; none | location; setup |
| `shared_services` | none | serialization |
| `parallel.max` | 3 | workers at once |
| `model.implementer`, `model.investigator` | `sonnet`, `sonnet` | worker models |

## Outputs

Packages and patches in step 6's `<dir>` (default `WORK/reviews/`); briefs and reports in `WORK/tmp/`.

## Stops and autopilot

Stops at steps 1, 3, 6, 7 and 8 (a unit or worktree that will not pass, a conflict, a gap, teardown). An AskUserQuestion answer records no prompt line, so Guard G20 denies it; ask in chat. Autopilot is on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's "Autopilot:" line; a turn with no mode line changes nothing. When on, each stop parks as `parked: <question>; default: <choice>; why: <one line>`: an unclassifiable unit or a brief that will not pass parks that unit while the rest continue, a conflicted or out-of-SCOPE worker stays unapplied, the gap stands. Teardown never runs under autopilot (G1 denies `git worktree remove --force`); the worktrees are listed instead.
