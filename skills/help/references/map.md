# kern map

Installed skills only. The Tier column says how a skill loads. An `auto` skill loads by its description. A `path` skill loads through a kernel Routing row, in `kernel/kernel.md`, or when typed. A `slash` skill never loads by its description. It loads when typed, or when a kernel rule or another skill names its file. Nearest sibling names the skill to use instead, and when.

| Skill | Tier | Reached by | Job | Nearest sibling |
|---|---|---|---|---|
| `mode` | slash | `/kern:mode`, or "go terse", "html mode", "back to normal" | Switch voice and surface for this session | `autopilot` when the session should act without asking, not sound different |
| `autopilot` | slash | `/kern:autopilot on` or `/kern:autopilot go <ticket>`, typed only | Grant this session commits, branch pushes and draft PRs without asking; a go also takes one ticket through a draft PR to `gh pr ready` or a stop | `finish-branch` when one branch needs one commit, push or draft PR, asking as it goes |
| `help` | slash | `/kern:help`, `/kern:help setup`, `/kern:help check` | This map, fixes for a run, and project settings | `recall` when the question is where this work stands, not how kern works |
| `technical-writing` | path | Kernel row "Prose others read", or `/kern:technical-writing` | Docs, PR bodies, issues and commit messages | `unslop` when only a reply's tone needs fixing |
| `unslop` | slash | The kernel's Reply rule, technical-writing step 5, or `/kern:unslop` | Rules for prose others read | `technical-writing` when writing a doc, PR body, issue or commit message |
| `prove-it` | auto | Its description; routed row "About to say done, fixed or passing, commit, or open a PR" | Evidence before any done, fixed or passing | `self-review` when the whole diff needs checking before a PR, not one claim |
| `implement` | path | Routed row "One bounded change of 1 or 2 files with an agreed design, or tests for existing code"; /kern:implement | Thin slices, test first, full suite | `define` when the change is new behaviour with no agreed design |
| `diagnose` | path | Routed row "Bug, failing test, unexpected output"; /kern:diagnose | Root cause before any fix | `implement` when the cause is known and the fix agreed |
| `define` | path | Routed row "New behaviour and no agreed spec"; /kern:define | Clarify, size and approve before code; a quick, clear task or an approval waiver goes straight to implement | `plan` when the spec is already approved |
| `plan` | path | Routed row "Agreed spec, more than one step"; /kern:plan | Approved spec to ordered, checked tasks | `define` when no spec is approved yet |
| `parallel-work` | path | Routed row "Independent changes asked for in parallel"; execute-plan and diagnose; /kern:parallel-work | One worktree per writer, integrate, re-test | `execute-plan` when the changes are tasks of one approved plan |
| `execute-plan` | path | Routed row "Executing an agreed plan"; /kern:execute-plan | Run a plan with a ledger and two-verdict review | `parallel-work` when independent changes have no plan |
| `self-review` | path | Routed row "Review requested on your own diff, no PR yet"; /kern:self-review | Author's check before a PR | `finish-branch` when the branch should also be committed, pushed or opened as a PR |
| `commit` | slash | /kern:commit; prove-it's gate for a commit; the kernel's opt-out clause | One commit of named files, or one per reviewed task, per the project's convention | `finish-branch` when a push or PR follows the commit |
| `finish-branch` | slash | /kern:finish-branch; prove-it's gate for a push, PR or release | Verify, review, then commit, push, draft PR or keep; a release on request, tagged after the merge | `commit` when only a local commit is wanted |
| `recall` | auto | Its description; routed row "Starting or resuming after a gap" | Rebuild state across sessions; recall chat for this thread | `help` when the question is about kern, not the work |

## Close calls
- Writing a PR body: `technical-writing`, which applies `unslop`. Editing a reply's tone only: `unslop`.
- Terse chat but a full PR body: terse governs chat only. Persisted text always follows `unslop`.
