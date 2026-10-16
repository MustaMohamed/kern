### Task 7: SubagentStart

**Files:**
- Create: `kernel/kernel-subagent.md`, `modes/terse-subagent.md`, `hooks/subagent-start`
- Test: `tests/hooks/subagent-start.bats`

**Interfaces:**
- Consumes: `render_template`, `kern_version` (Task 6), `state_get` (Task 5).
- Produces: SubagentStart JSON `{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"..."}}`, at most 1,200 characters of context with the terse line included.

- [ ] **Step 1: Write the failing test**

`tests/hooks/subagent-start.bats`:
```bash
#!/usr/bin/env bats
# hooks/subagent-start: JSON shape, size, voice.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)"
}

context_of() {
  printf '%s' "$1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);if(j.hookSpecificOutput.hookEventName!=="SubagentStart")process.exit(3);process.stdout.write(j.hookSpecificOutput.additionalContext)})'
}

@test "valid SubagentStart JSON under 1,200 characters" {
  run bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"Explore"')"
  [ "$status" -eq 0 ]
  ctx=$(context_of "$output")
  [[ "$ctx" == "# kern "*"(subagent)"* ]] || false
  [ "${#ctx}" -le 1200 ]
  [[ "$ctx" != *"Voice: terse"* ]] || false
}

@test "terse voice reaches the subagent" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  printf 'voice: terse\nsurface: auto\nautopilot: off\n' >"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  run bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"kern:implementer"')"
  ctx=$(context_of "$output")
  [[ "$ctx" == *"Voice: terse"* ]] || false
  [ "${#ctx}" -le 1200 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run-bats tests/hooks/subagent-start.bats`
Expected: FAIL; `hooks/subagent-start: No such file or directory`, then a `JSON.parse` error from `context_of`.

- [ ] **Step 3: Write `kernel/kernel-subagent.md`**

```markdown
# kern {VERSION} (subagent)
Your dispatcher already routed this task. Do the brief; do not re-route it or start work outside it.
Precedence: the brief, then the project's CLAUDE.md, rules and skills, then kern steps, then your defaults.
Evidence: "done", "fixed" and "passing" need a command you ran and its output. Findings cite path:line. Label other claims measured, inferred or guess.
Autonomy: read, search and edit inside your scope. Never commit, push, merge, post or message anyone unless the brief says so.
Return: verdict first, then deltas and file paths. Put bulk in a file and return its path.
In kern files read by path, ${CLAUDE_PLUGIN_ROOT} means {ROOT_PATH}.
{VOICE}
```

- [ ] **Step 4: Write `modes/terse-subagent.md`**

```markdown
Voice: terse. Verdict or answer first, short sentences, no ceremony. Keep code, commands, paths and errors exact. Files you write use plain prose.
```

- [ ] **Step 5: Write `hooks/subagent-start`**

```bash
#!/usr/bin/env bash
# kern SubagentStart: injects the subagent kernel and, when terse is active, the terse voice line.
KERN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KERN_ROOT
for lib in json settings state render; do
  # shellcheck source=/dev/null
  . "$KERN_ROOT/hooks/lib/$lib.sh"
done

# shellcheck disable=SC2034 # read by the json.sh functions
KERN_INPUT=$(cat)
SID=$(json_get session_id) || SID=""
CWD=$(json_get cwd) || CWD="$PWD"
KERN_MAIN=$(kern_main_root "$CWD" 2>/dev/null) || KERN_MAIN=""
export CWD KERN_MAIN
kern_enabled || exit 0

voice=$(state_get "$SID" voice 2>/dev/null) || voice=$(settings_get mode.voice normal)
K_VOICE=""
[ "$voice" = terse ] && K_VOICE=$(cat "$KERN_ROOT/modes/terse-subagent.md")
K_VERSION=$(kern_version)
K_ROOT="$KERN_ROOT"
export K_VERSION K_ROOT K_VOICE
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"%s"}}\n' \
  "$(render_template "$KERN_ROOT/kernel/kernel-subagent.md" | json_escape)"
exit 0
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `chmod +x hooks/subagent-start && tests/run-bats tests/hooks/subagent-start.bats`
Expected: `2 tests, 0 failures`.

- [ ] **Step 7: Commit**

```bash
git add -- kernel/kernel-subagent.md modes/terse-subagent.md hooks/subagent-start tests/hooks/subagent-start.bats
git commit -m "M1: inject the subagent kernel and voice" -m "Subagents get precedence, evidence and autonomy rules once at launch, within 1,200 characters."
```

---

