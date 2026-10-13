# kern map

Installed skills only. Tier: `auto` skills load by description; `path` skills load through a kernel Routing row or when typed; `slash` skills never load by description: they load when typed, or when a kernel rule or another skill names their file.

| Skill | Tier | Reached by | Job |
|---|---|---|---|
| `mode` | slash | `/kern:mode`, or "go terse", "html mode", "back to normal" | Switch voice and surface for this session |
| `autopilot` | slash | `/kern:autopilot on`, typed only | Grant this session commits, branch pushes and draft PRs without asking |
| `help` | slash | `/kern:help`, `/kern:help setup`, `/kern:help check` | This map, fixes for a run, and project settings |
| `technical-writing` | path | Kernel row "Prose others read", or `/kern:technical-writing` | Docs, PR bodies, issues and commit messages |
| `unslop` | slash | The kernel's Reply rule, technical-writing step 5, or `/kern:unslop` | Rules for prose others read |

## Close calls
- Writing a PR body: `technical-writing` (it applies `unslop`). Editing a reply's tone only: `unslop`.
- Terse chat but a full PR body: terse governs chat only; persisted text always follows `unslop`.
