### Task 1: Payload spike

Record the real hook payloads M1 depends on, before writing the hooks that parse them. The spike plugin lives in a temporary directory and is never committed; only the sanitized payloads and the findings are.

**Files:**
- Create: `docs/spikes/m1-payloads.md`
- Create: `tests/fixtures/payloads/*.json` (one file per recorded event, names below)
- Temporary, not committed: `$SPIKE/plugin/**`, `$SPIKE/repo`

**Interfaces:**
- Consumes: Claude Code 2.1.296 with `claude --plugin-dir`.
- Produces: `docs/spikes/m1-payloads.md` with one line per finding in the form `<question>: <answer>`, including exactly `agent_type in subagent PreToolUse: <value or absent>` (M2 Task 7 reads it). Fixtures `tests/fixtures/payloads/{expansion-mode,expansion-autopilot,submit-slash-mode,submit-task-notification,subagent-start,pretooluse-subagent,sessionstart-clear}.json`, each one JSON object with `session_id` replaced by `test-session` and the throwaway repo path replaced by `/tmp/kern-fixture`. A file is absent when its event never fired; Task 8's replay test skips absent files.

- [ ] **Step 1: Build the spike plugin and a throwaway repo**

```bash
SPIKE=$(mktemp -d)/kern-spike
mkdir -p "$SPIKE/plugin/.claude-plugin" "$SPIKE/plugin/hooks" "$SPIKE/plugin/skills/mode" "$SPIKE/plugin/skills/autopilot" "$SPIKE/plugin/agents"
cat >"$SPIKE/plugin/.claude-plugin/plugin.json" <<'JSON'
{ "name": "kern", "version": "0.0.0", "description": "Payload spike for kern M1. Delete after use." }
JSON
cat >"$SPIKE/plugin/hooks/log.sh" <<'SH'
#!/usr/bin/env bash
# Spike logger: appends CLAUDE_CODE_ENTRYPOINT and the hook's stdin to payloads.log, one line each.
in=$(cat)
printf '%s\t%s\n' "${CLAUDE_CODE_ENTRYPOINT-unset}" "$(printf '%s' "$in" | tr '\n' ' ')" >>"$(dirname "$0")/payloads.log"
case "$in" in
  *SubagentStart*) printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"SPIKE-MARKER-7731"}}\n' ;;
esac
exit 0
SH
cat >"$SPIKE/plugin/hooks/hooks.json" <<'JSON'
{ "hooks": {
  "SessionStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/log.sh"] }] }],
  "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/log.sh"] }] }],
  "UserPromptExpansion": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/log.sh"] }] }],
  "SubagentStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/log.sh"] }] }],
  "PreToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/log.sh"] }] }]
} }
JSON
for s in mode autopilot; do
  printf -- '---\nname: %s\ndescription: Spike skill %s.\ndisable-model-invocation: true\n---\n\nReply with one line: spike %s skill loaded, arguments: $ARGUMENTS\n' "$s" "$s" "$s" >"$SPIKE/plugin/skills/$s/SKILL.md"
done
printf -- '---\nname: investigator\ndescription: Spike agent that runs one read-only command.\ntools: Read, Bash\n---\n\nRun the command you are given and report its output. Also report any context line that starts with SPIKE-MARKER.\n' >"$SPIKE/plugin/agents/investigator.md"
chmod +x "$SPIKE/plugin/hooks/log.sh"
git init -q "$SPIKE/repo" && git -C "$SPIKE/repo" commit -q --allow-empty -m init
mkdir -p "$SPIKE/repo/.claude"
printf '{ "enabledPlugins": { "superpowers@claude-plugins-official": false, "caveman@caveman": false } }\n' >"$SPIKE/repo/.claude/settings.local.json"
echo "SPIKE=$SPIKE"
```
Expected: the last line prints the spike directory. Keep it for the next steps.

- [ ] **Step 2: Ask the user to run the interactive part**

Tell the user, in full sentences: "Please open a second terminal and run `cd <SPIKE>/repo && claude --plugin-dir <SPIKE>/plugin`. Then type these, one at a time, waiting for each reply: (1) `/kern:mode terse`; (2) `/kern:autopilot on`; (3) `Use the kern:investigator agent in the background to run git log --oneline -1 and report the output, plus any line in its context that starts with SPIKE-MARKER.`; (4) wait until the background report arrives and Claude answers it; (5) `/clear`; (6) `/exit`. Tell me when you are done." Wait for the user.

- [ ] **Step 3: Record the headless run**

```bash
cd "$SPIKE/repo" && claude -p --plugin-dir "$SPIKE/plugin" "/kern:mode terse" >/dev/null; cd -
wc -l "$SPIKE/plugin/hooks/payloads.log"
```
Expected: at least 10 log lines.

- [ ] **Step 4: Answer each question from the log and write the record**

Run these and read the output:

```bash
SPIKE=${SPIKE:?set SPIKE to the path Step 1 printed}
L="$SPIKE/plugin/hooks/payloads.log"
grep -c '"UserPromptExpansion"' "$L"
grep '"UserPromptExpansion"' "$L" | grep -o '"command_name":"[^"]*"' | sort -u
grep '"UserPromptExpansion"' "$L" | grep -o '"command_source":"[^"]*"' | sort -u
grep '"UserPromptSubmit"' "$L" | grep -o '"prompt":"[^"]\{0,120\}' | head -8
grep '"PreToolUse"' "$L" | grep -o '"agent_type":"[^"]*"' | sort -u
grep '"SubagentStart"' "$L" | grep -o '"agent_[a-z]*":"[^"]*"' | sort -u
grep '"SessionStart"' "$L" | grep -o '"source":"[^"]*"\|"session_id":"[^"]*"'
cut -f1 "$L" | sort | uniq -c
```

Write `docs/spikes/m1-payloads.md` with these lines, filling each answer from the output (write `absent` when a field never appears):

```markdown
# M1 payload spike

Claude Code version: <claude --version>
Date: <YYYY-MM-DD>

UserPromptExpansion fires for a disable-model-invocation plugin skill: <yes|no>
command_name for /kern:mode: <value>
command_source for /kern:mode: <value>
Typed slash command also fires UserPromptSubmit: <yes|no>
UserPromptSubmit prompt for a typed /kern:mode terse: <envelope|raw|other: first 80 chars>
Background subagent report wrapper tag: <for example <task-notification>, or none>
SubagentStart fields: <agent_id, agent_type, ...>
SubagentStart additionalContext reached the subagent (it reported SPIKE-MARKER-7731): <yes|no>
agent_type in subagent PreToolUse: <value or absent>
/clear gives a new session_id: <yes|no>
CLAUDE_CODE_ENTRYPOINT interactive: <value>
CLAUDE_CODE_ENTRYPOINT headless (-p): <value>
ask under bypassPermissions: pending (Task 18)
```

- [ ] **Step 5: Apply the decision each finding drives**

The hooks in Tasks 6 to 9 already handle every documented shape; these branches only add what a finding requires. Record the branch taken under each line of the record as `Decision: ...`.

1. Expansion fires (yes): the primary switch path works; keep the UserPromptSubmit envelope path as the fallback. Expansion does not fire (no): the envelope or raw path is the only path; nothing to change, because Task 8 tests both.
2. `command_name` is `kern:mode`, `/kern:mode` or `mode`: Task 8's `prompt-submit` accepts all three (`mode` only with `command_source` `plugin` and a prompt starting `/mode` or `/kern:mode`). Any other value: add it to the `case "${NAME#/}" in` line of `hooks/prompt-submit` in Task 8 and add a test with the recorded fixture.
3. UserPromptSubmit prompt is the envelope (`<command-message>...<command-name>/kern:mode</command-name>...`) or the raw `/kern:mode terse`: covered by Task 8. Something else while Expansion also did not fire: stop and tell the user that autopilot cannot be switched on safely with this Claude Code version, and wait for a decision before Task 8.
4. Background report wrapper tag is one of `<task-notification`, `<cross-session-message`, `<scheduled-task`, `<teammate-message`, `<channel-message`: covered. Another tag: add it to `KERN_WRAPPER_TAGS` in `hooks/prompt-submit` (Task 8) and add it to the test `wrapped prompts never switch`.
5. SubagentStart context reached the subagent (yes): keep JSON `additionalContext`. No: record it in the M2 risk list; execute-plan briefs will carry the subagent kernel text instead (M2 Task 7 reads this line).
6. `agent_type` in subagent PreToolUse is recorded verbatim for M2's G18.
7. Headless `CLAUDE_CODE_ENTRYPOINT` starts with `sdk`: the reminder skip in Task 8 works as written. Another value `<v>`: in Task 8 change `case "${CLAUDE_CODE_ENTRYPOINT-}" in sdk*) exit 0 ;; esac` to `case "${CLAUDE_CODE_ENTRYPOINT-}" in sdk* | <v>) exit 0 ;; esac`, and change the autopilot-line condition `[ "${CLAUDE_CODE_ENTRYPOINT#sdk}" = "${CLAUDE_CODE_ENTRYPOINT-}" ]` to `case "${CLAUDE_CODE_ENTRYPOINT-}" in sdk* | <v>) false ;; *) true ;; esac`.
8. `/clear` session id: recorded only. State resets on `source: clear` either way.

- [ ] **Step 6: Save sanitized fixtures**

```bash
mkdir -p tests/fixtures/payloads
SPIKE=${SPIKE:?set SPIKE to the path Step 1 printed}
L="$SPIKE/plugin/hooks/payloads.log"
save() { # save NAME EVENT GREP_PATTERN
  grep "\"$2\"" "$L" | grep -- "$3" | head -n 1 | cut -f2- |
    sed -e 's/"session_id":"[^"]*"/"session_id":"test-session"/' \
        -e "s#$SPIKE/repo#/tmp/kern-fixture#g" \
        -e 's#"transcript_path":"[^"]*"#"transcript_path":"/tmp/kern-fixture/t.jsonl"#' >"tests/fixtures/payloads/$1.json"
  [ -s "tests/fixtures/payloads/$1.json" ] || rm -f "tests/fixtures/payloads/$1.json"
}
save expansion-mode UserPromptExpansion 'mode'
save expansion-autopilot UserPromptExpansion 'autopilot'
save submit-slash-mode UserPromptSubmit 'kern:mode'
save submit-task-notification UserPromptSubmit '<task-notification\|<cross-session-message\|<scheduled-task'
save subagent-start SubagentStart 'investigator'
save pretooluse-subagent PreToolUse '"agent_type"'
save sessionstart-clear SessionStart '"source":"clear"'
ls tests/fixtures/payloads
for f in tests/fixtures/payloads/*.json; do node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$f" || echo "BAD $f"; done
grep -l "$HOME" tests/fixtures/payloads/*.json || echo "no home paths"
```
Expected: the fixture files that fired, no `BAD` line, and `no home paths`. If a home path remains (for example in `transcript_path`), replace it with `/tmp/kern-fixture` by hand.

- [ ] **Step 7: Commit and clean up**

```bash
git add -- docs/spikes/m1-payloads.md tests/fixtures/payloads
git commit -m "M1: record real hook payloads and the decisions they drive" -m "Mode and autopilot parsing, subagent context and G18 depend on payload shapes the docs leave open."
rm -rf "$(dirname "${SPIKE:?set SPIKE to the path Step 1 printed}")"
```

---

