# Fix a run

| Symptom | Check | Fix |
|---|---|---|
| No routing, no `kern mode:` line | The first context block of the session starts with `# kern <version>` | Run `claude --debug` and look for the kern SessionStart hook. Put bash on PATH. `kern: off` turns kern off in one project |
| Two routers answer | superpowers is enabled in this project | Set `"superpowers@claude-plugins-official": false` under `enabledPlugins` in `.claude/settings.local.json` |
| Two voices | Another plugin injects a terse voice at session start | Disable that plugin. kern's `terse` mode replaces it |
| `/kern:mode terse` did nothing | `/kern:mode status` shows the hook line | No line means the hooks did not run, so see the first row. A line with the old value means the hook did not know the word |
| A guard asked or denied unexpectedly | The reason starts with `kern G<n>:` | The reason names the shape the guard checks. A policy key set to `auto`, and autopilot, allow only the shapes under What auto and autopilot allow in `${CLAUDE_PLUGIN_ROOT}/kernel/settings.md`. Any other shape still asks. Floor actions have no key. Each guard's contract is in `${CLAUDE_PLUGIN_ROOT}/docs/plans/contract.md`, and its rule in kern's design spec, section 8.3 |
| Settings ignored in a worktree | Settings live in the main checkout | Put `.claude/kern.local.yml` at the main worktree root, which `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root` prints |
| Autopilot refused | "autopilot denied by <file>" | That file sets `autopilot: denied`. Only the user changes it |
| kern ignored a project rule | The rule tightens a default | Project rules only tighten, and only settings keys loosen. Add the key, or report the gap |

## Status line
A plugin cannot add a status line. Add this to your own `statusLine` command to show `[kern terse]`, `[kern html]` or `[kern autopilot]`:

```bash
sid=$(sed -n 's/.*"session_id":"\([A-Za-z0-9_-]*\)".*/\1/p'); f="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}/sessions/$sid.state"
[ -f "$f" ] && awk -F': ' '$1=="autopilot"&&$2=="on"{a=1} $1=="voice"&&$2=="terse"{t=1} $1=="surface"&&$2=="html"{h=1} END{if(a)printf "[kern autopilot] "; if(t)printf "[kern terse] "; if(h)printf "[kern html] "}' "$f"
```
