# kern map

Installed skills only. The Tier column says how a skill loads. An `auto` skill loads by its description. A `path` skill loads through a kernel Routing row, in `kernel/kernel.md`, or when typed. A `slash` skill never loads by its description. It loads when typed, or when a kernel rule or another skill names its file.

| Skill | Tier | Reached by | Job |
|---|---|---|---|
| `mode` | slash | `/kern:mode`, or "go terse", "html mode", "back to normal" | Switch voice and surface for this session |
| `autopilot` | slash | `/kern:autopilot on`, typed only | Grant this session commits, branch pushes and draft PRs without asking |
| `help` | slash | `/kern:help`, `/kern:help setup`, `/kern:help check` | This map, fixes for a run, and project settings |
| `technical-writing` | path | Kernel row "Prose others read", or `/kern:technical-writing` | Docs, PR bodies, issues and commit messages |
| `unslop` | slash | The kernel's Reply rule, technical-writing step 5, or `/kern:unslop` | Rules for prose others read |
| `prove-it` | auto | Its description; routed row "About to say done, fixed or passing, commit, or open a PR" | Evidence before any done, fixed or passing |
| `implement` | path | Routed row "One bounded change with an agreed design"; /kern:implement | Thin slices, test first, full suite |
| `diagnose` | path | Routed row "Bug, failing test, unexpected output"; /kern:diagnose | Root cause before any fix |
| `define` | path | Routed row "New behaviour and no agreed spec"; /kern:define | Clarify, size and approve before code; a quick, clear task or an approval waiver goes straight to implement |
| `plan` | path | Routed row "Agreed spec, more than one step"; /kern:plan | Approved spec to ordered, checked tasks |
| `parallel-work` | path | Routed row "Independent changes asked for in parallel"; execute-plan and diagnose; /kern:parallel-work | One worktree per writer, integrate, re-test |
| `execute-plan` | path | Routed row "Executing an agreed plan"; /kern:execute-plan | Run a plan with a ledger and two-verdict review |
| `self-review` | path | Routed row "Review requested on your own diff, no PR yet"; /kern:self-review | Author's check before a PR |
| `commit` | slash | /kern:commit | One commit of named files, or one per reviewed task, per the project's convention |
| `finish-branch` | slash | /kern:finish-branch; prove-it's gate for a push or PR | Verify, review, then commit, push, draft PR or keep |
| `recall` | auto | Its description; routed row "Starting or resuming after a gap" | Rebuild state across sessions; recall chat for this thread |

## Close calls
- Writing a PR body: `technical-writing`, which applies `unslop`. Editing a reply's tone only: `unslop`.
- Terse chat but a full PR body: terse governs chat only. Persisted text always follows `unslop`.
