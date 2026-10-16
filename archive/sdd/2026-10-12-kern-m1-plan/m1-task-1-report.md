# Task 1 report (Step 1 only)

Step 1 ran exactly as written (PATH set to include volta). Last line printed:

    SPIKE=/var/folders/h_/h42hf5_179g1grz4t4yx62w40000gn/T/tmp.J3RNZ8hrC7/kern-spike

Created: plugin/.claude-plugin/plugin.json, hooks/{log.sh,hooks.json}, skills/{mode,autopilot}/SKILL.md, agents/investigator.md, repo (git init, one empty commit, .claude/settings.local.json). log.sh is executable.

Status: NEEDS_CONTEXT. Step 2 needs the user to run the interactive session. Nothing committed.

## Steps 3 to 7
Step 3: headless run output 'spike mode skill loaded, arguments: terse'; log 15 lines.
Step 4: UserPromptExpansion 3; wrapper tag agent-message; agent_type kern:investigator; entrypoints cli 12, sdk-cli 3; marker reached subagent.
Step 6 fixtures (7, valid JSON, no home paths): expansion-autopilot, expansion-mode, pretooluse-subagent, sessionstart-clear, subagent-start, submit-slash-mode, submit-task-notification. Save pattern for task-notification extended with <agent-message; sed also maps /private prefix and scratchpad_dir.
Step 7: committed 2e2cae2, spike dir removed. Decision changing later task: Task 8 add agent-message to KERN_WRAPPER_TAGS and its test.

Full record:
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
ask under bypassPermissions: pending (Task 18)

Other observations: payloads carry `permission_mode` (seen `auto`) and `prompt_id`. The headless run logged 3 lines under `sdk-cli`, 12 lines under `cli` overall in this log.
