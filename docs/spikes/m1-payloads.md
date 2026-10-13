# M1 payload spike

Claude Code version: 2.1.296
Date: 2026-10-12

UserPromptExpansion fires for a disable-model-invocation plugin skill: yes
Decision: expansion fires; the primary switch path works, the UserPromptSubmit path stays as the fallback.
command_name for /kern:mode: kern:mode
Decision: Task 8 already accepts `kern:mode`; no change. The autopilot command arrives as `kern:autopilot`.
command_source for /kern:mode: plugin
Typed slash command also fires UserPromptSubmit: yes
UserPromptSubmit prompt for a typed /kern:mode terse: raw (`/kern:mode terse`)
Decision: raw path, covered by Task 8. UserPromptExpansion also carries `expansion_type: slash_command`, `command_args: terse`, and `prompt: /kern:mode terse`.
Background subagent report wrapper tag: <agent-message from="<agent_id>"> (body starts `[Subagent hand-back]`); no <task-notification> seen
Decision: CHANGES TASK 8. `agent-message` is not in the covered list. Add `<agent-message` to `KERN_WRAPPER_TAGS` in `hooks/prompt-submit` and to the test `wrapped prompts never switch`. Fixture `submit-task-notification.json` holds this payload.
SubagentStart fields: session_id, transcript_path, cwd, scratchpad_dir, prompt_id, agent_id, agent_type, hook_event_name
SubagentStart additionalContext reached the subagent (it reported SPIKE-MARKER-7731): yes
Decision: keep JSON `additionalContext`.
agent_type in subagent PreToolUse: kern:investigator
Decision: recorded verbatim for M2 G18. The value is plugin-prefixed (`kern:investigator`), not the bare agent name. Main-session PreToolUse carries no `agent_type`.
/clear gives a new session_id: yes
Decision: recorded only. The `source: clear` SessionStart carried a new id.
CLAUDE_CODE_ENTRYPOINT interactive: cli
CLAUDE_CODE_ENTRYPOINT headless (-p): sdk-cli
Decision: starts with `sdk`; the reminder skip in Task 8 works as written.
ask under bypassPermissions: prompted
Decision: no `decide.sh` change. The user rejected the prompt for `git stash`; a hook replay gives `kern G1: git stash in the main checkout changes shared state (D3)`.
mode survives /compact: yes
Decision: none. After `/compact` the kernel was rendered again with `voice=terse`, and `/kern:mode status` said terse.
Claude asked to write its own session state: declined, and told the user to type `/kern:autopilot on`. A hook replay of the write gives `kern G16: kern session state is written only by kern hooks`.
gh pr merge under autopilot: Claude did not run it and told the user to run it with `!`. A hook replay gives `kern G1: gh pr merge under autopilot: merge stays human`.
Smoke checklist (Task 18 Step 5): 6 of 6 pass.
Live-check findings, fixed in be26d2f: `/kern:autopilot off` created `.kern/ledgers` without asking; help setup named its template path ambiguously; a terse reply ran long with detail nobody asked for.

Other observations: payloads carry `permission_mode` (seen `auto`) and `prompt_id`. The headless run logged 3 lines under `sdk-cli`, 12 lines under `cli` overall in this log.
