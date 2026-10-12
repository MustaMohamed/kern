# Context at phase boundaries

## Steps
1. Name the phase that just ended and the one that comes next.
2. Write what the next phase needs to a file, not only to chat: decisions, open questions, paths, and each command with its last result. Use `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir notes` for the directory.
3. Hand bulk reads, logs and transcripts to a subagent and keep only its conclusion.
4. If the context is filling, tell the user now, at this boundary, and suggest /compact or /clear, naming the file from step 2.
5. Never compact or clear in the middle of a phase on your own.
