# Where the records are

recall reads four kinds of record. It never writes any of them.

## Transcripts

`~/.claude/projects/<slug>/*.jsonl`, one file per session. `<slug>` is the workspace path with every UTF-16 code unit outside A-Z, a-z and 0-9 turned into `-` (`é` gives one `-`, an emoji two); a slug over 200 characters is cut to 200 and gets `-<hash>`. Sessions of kern worktrees live under sibling slugs `<slug>--claude-worktrees-<name>`. Skip the per-session child folders (`subagents/`, `tool-results/`, `workflows/`): they are not the user's chat. Order by modification time, never by name. Skip the `current` session: recall-sessions marks the one whose id is `CLAUDE_CODE_SESSION_ID`, the running session (in a subagent, its parent). With no `current` line, skip none; a transcript holding only this request is this one.

## Prompt index

`~/.claude/history.jsonl` holds every project's prompts and indexes command-line sessions only; desktop sessions never appear there. Do not grep it: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/recall-sessions` reads it and the transcript folders together and keeps only this project's lines.

## Working files

kern's `WORK` folders: `ledgers/`, `plans/` and `specs/` under the main checkout's `work_dir`. A ledger's incomplete task is the strongest next move. Memory files are distilled and dated: context, never state.

## Live state

`git` (branches, worktrees, `git log --since`), `gh` (PRs, issues, checks) and the tracker named by `tracker`; `workflow_records` names any further per-ticket records. A transcript is history and live state is truth. A source that is unavailable is named in the brief, and its threads are tagged unverified.
