# Fix a run

| Symptom | Check | Fix |
|---|---|---|
| No routing, no `kern mode:` line | The first context block of the session starts with `# kern <version>` | Run `claude --debug` and look for the kern SessionStart hook; bash must be on PATH; `kern: off` disables kern per project |
| Two routers answer | superpowers is enabled in this project | Set `"superpowers@claude-plugins-official": false` under `enabledPlugins` in `.claude/settings.local.json` |
| Two voices | Another plugin injects a terse voice at session start | Disable that plugin; kern's `terse` mode replaces it |
| `/kern:mode terse` did nothing | `/kern:mode status` shows the hook line | No line: hooks did not run (see the first row). A line with the old value: the word was not recognized |
| A guard asked or denied unexpectedly | The reason starts with `kern G<n>:` | Each guard's rule is in kern's design spec, section 8.3. A policy key (`commit.policy`, `push.policy`, `pr.policy`, `tracker.policy`, `review.post_policy`) changes ask to auto or deny; floor actions have no key |
| Settings ignored in a worktree | Settings live in the main checkout | Put `.claude/kern.local.yml` at the main worktree root (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root`) |
| Autopilot refused | "autopilot denied by <file>" | That file sets `autopilot: denied`; only the user changes it |
| kern ignored a project rule | The rule tightens a default | Project rules tighten; only settings keys loosen. Add the key, or report the gap |

## Status line
A plugin cannot add a status line. Add this to your own `statusLine` command to show `[kern terse]`, `[kern html]` or `[kern autopilot]`:

```bash
sid=$(sed -n 's/.*"session_id":"\([A-Za-z0-9_-]*\)".*/\1/p'); f="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}/sessions/$sid.state"
[ -f "$f" ] && awk -F': ' '$1=="autopilot"&&$2=="on"{a=1} $1=="voice"&&$2=="terse"{t=1} $1=="surface"&&$2=="html"{h=1} END{if(a)printf "[kern autopilot] "; if(t)printf "[kern terse] "; if(h)printf "[kern html] "}' "$f"
```
