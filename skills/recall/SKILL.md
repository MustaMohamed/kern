---
name: recall
description: 'Use when starting or resuming work and state must be rebuilt first: "where did I leave off", "catch me up on X", "what remains", "I got lost in these PRs", a session after days away, or "recall chat" for this thread since my last message. Not for one named session.'
---

# recall

Rebuild the current state from kern's working files, transcripts and live state, then hand back a short brief. Write nothing to disk: live state is the only source of truth, and the brief is a reply. The one exception is `wt-snap`, which adds git objects and changes no file, ref or index.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Route. One named prior session: point to `claude --resume` and stop. A full state capsule already in the prompt: skip the mining. `recall chat`: go to step 9.
2. Right after reading this file, before any other tool call, say `Scope: <window>, <topic>, <workspace>.`: the window (7 days unless stated; never turn "all" into "recent"), the topic, and the workspace (never another project's transcripts unasked). Adjacent work stays out unless it blocks this.
3. Read kern's working files first. Find `WORK` with two separate commands, never `kern-dir`, which creates folders and edits `.git/info/exclude`: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get work_dir .kern` prints the folder name, a tab and its source; `git rev-parse --path-format=absolute --git-common-dir` prints a path whose parent is the main checkout, from a linked worktree too. `WORK` is that parent plus the folder name. A missing `WORK`, or a failed `rev-parse`, is not an error: say there are no kern working files. Else read `WORK/ledgers/*/ledger.md` (incomplete tasks and `parked:` lines) and the status lines of `WORK/plans/*` and `WORK/specs/*`. List kern worktrees with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-audit`; a non-zero exit, or a worktree in the `unknown` bucket, goes in Sources skipped with its evidence, never as clean. Memory files are context, never state.
4. Find the sessions with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/recall-sessions --days <n>`, adding `--topic <topic>` only when a topic was named (an empty topic is a usage error). `session` lines are this project's transcripts, its worktrees' included, newest first; with a topic, `prompt` lines are its prompts that name it (`-` is an unknown session id). The newest session is usually this one; skip it (`references/transcripts.md`). Exit 1 (a record could not be read) or 2 never means there were no sessions: quote its message, name transcripts in Sources skipped, tag nothing from transcripts, and go on with live state (exit 2 outside a git repository: no live state either, say so and stop).
5. Mine in parallel: dispatch `kern:investigator` on model `model.miner`, one per 2 to 4 transcripts, with the absolute paths from the `session` lines, one question (for the topic: goal, decisions, open threads, corrections and artifacts of each session) and a return budget of 15 lines per session. It may run only read commands: `grep -n` the topic first (pipe to `cut -c1-300`), `wc -c` before reading, and `sed -n <first>,<last>p` with line numbers and p only; narrow any record over 500 characters (`sed -n <n>p <file> | wc -c` measures one). G18 denies `>` anywhere in a command, even quoted: search one side of it or put `.` in its place. If it reports a command the allowlist blocks, run that command yourself; never widen the guard. When the answer hinges on what an agent actually did, read the full transcript region, not a grep line or summary. Two sessions or fewer: read them directly.
6. When a feature, ticket or bug is named, sweep `tracker` and `workflow_records` in parallel with step 5 (a key unset: `tracker` is detected, `workflow_records` is none; no tracker found is said once). A source that did not run (tracker tools absent or erroring, `gh` missing, `gh auth status` failing) goes in Sources skipped; a null result from a source that ran is a finding.
7. Verify every PR, branch, issue and claim the mining inherited against live `git`, `gh` and the tracker before tagging it. For squash merges, trust `gh pr list --head <branch> --state all`, not `git branch --merged`. A source that cannot be reached (no remote, `gh` or the tracker unavailable) leaves the thread with the unverified tag. `[verified, uncommitted]` needs `<wt>`, the path on the ledger's `Worktree:` line, and two checks: that work's last `tree=` equals a fresh `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`, and that snapshot differs from `git -C <wt> rev-parse HEAD^{tree}`; equal to `HEAD^{tree}` means committed, so tag by its branch or PR, as for a differing `tree=`. No `Worktree:` line, a `<wt>` not in `git worktree list`, or a failing `wt-snap` rules the tag out: tag from its branch or PR when the `Worktree:` line or the thread names a branch (never the `Main:` line's), else `[unverified, worktree unavailable]`; the next move still comes from the incomplete ledger task.
8. Write the brief per the output contract below.
9. `recall chat`: follow `references/chat.md`, reply with the action-item count first, and stop.

## Output contract

- Capsule: at most 5 bullets on what this work is and where it stands.
- Threads: one line per thread, starting with its one tag, as `- [tag] <thread>`: `[merged #N]`, `[open PR #N]`, `[in flight <branch>]`, `[verified, uncommitted]`, `[reverted #N]`, `[blocked, <why>]`, `[parked]`, `[planned, not started]`, or `[unverified, <source> unavailable]`; a transcript alone never earns a stronger tag. A branch left behind after its PR merged is `[merged #N]` with "cleanup pending" on the same line. A line without a tag goes under Problems or Sources skipped.
- Problems: at most 5, the recurring ones.
- Next move: one concrete action. An incomplete ledger task is the next move when one exists.
- Sources skipped: one line naming each source that did not run, or omit.

Cite transcript findings by session id and live findings by PR, issue or ticket number. When the brief outgrows a screen, cut detail before threads.

## Inputs

| Key | Default | Use |
|---|---|---|
| `tracker` | detected | issue states |
| `workflow_records` | none | extra per-ticket records to sweep |
| `work_dir` | `.kern` | ledgers, plans, specs |
| `model.miner` | `haiku` | transcript miners |

## Outputs

Chat only (a page only when kern's `visual` skill is installed and the brief is long; otherwise say once "visual pages not installed"). Nothing is written.

## Stops and autopilot

Read-only, the same under autopilot; `wt-snap` is the one exception named above. No step asks a question.

## Red flags

| Thought | Reality |
|---|---|
| "The transcript says it merged" | Transcripts are history. Check `gh` or `git` first. |
| "recall-sessions printed nothing, so no work" | Empty output with exit 0 is no sessions. A non-zero exit is a failed source. |
| "I'll read the whole transcript here" | Slice, measure, delegate. |
| "A status file will make next time faster" | Next time runs this skill. |
| "My work on X means everything this week" | Keep the topic. |
