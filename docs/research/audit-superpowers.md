# Audit: superpowers 6.4.1 (baseline)

Read-only audit. Nothing was installed, edited or run from the plugin. Byte counts come from `wc -c`. The injected-context size was computed by rebuilding the hook's string in Python rather than running the hook.

- Plugin root (abbreviated `SP/` below): `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/`
- Target repo (abbreviated `REPO/` below): `/Users/musta/Code/projects/cds/cds-app-rewrite`
- Install record: `~/.claude/plugins/installed_plugins.json` shows scope `user`, installed 2026-04-30, lastUpdated 2026-09-24, gitCommitSha `5bf4e78011075bcfc0dc295f0724994cd123ee71`.
- Enablement: `~/.claude/settings.json:24` contains `"superpowers@claude-plugins-official": true`. `REPO/.claude/settings.json` does not mention superpowers, and `REPO/.claude/settings.local.json` does not exist.

## Scores

| # | Criterion | Score |
|---|---|---|
| 1 | Claude Code compatibility | 5/5 |
| 2 | Lifecycle coverage | 4/5 |
| 3 | Systematic-ness (router + gates) | 5/5 |
| 4 | Rigor / quality | 4/5 |
| 5 | Fit with CDS project rules | 2/5 |
| 6 | Overlap | skipped (this is the baseline) |
| 7 | Context / token cost | 3/5 |
| 8 | Safety / risk | 4/5 |
| 9 | Maintenance / maturity | 5/5 |

## Skill inventory

All 15 skills have only `name` and `description` in their frontmatter. None sets `disable-model-invocation`, so all 15 are model-invocable, and the plugin's instructions tell the model to invoke them. The plugin ships no `commands/` or `agents/` directory.

| Skill | Phase | Purpose | SKILL.md bytes | Dir bytes | Auto-invocable? |
|---|---|---|---|---|---|
| using-superpowers | router | Bootstrap: the "1% rule", invoke before any response, red-flag table, precedence | 3,192 | 20,630 | Yes, and injected at every SessionStart |
| brainstorming | clarify, spec | Spike/bounded/architectural path classification, intent discovery, HARD-GATE approval, written spec, optional browser visual companion | 17,548 | 82,281 | Yes ("You MUST use this before any creative work") |
| writing-plans | plan | Bite-sized TDD task plan with Global Constraints and Review Focus, then execution handoff | 9,092 | 10,805 | Yes |
| subagent-driven-development | implement | Controller dispatches an implementer and a task reviewer per task; 5-round fix loop; ledger; final review | 32,577 | 59,320 | Yes |
| executing-plans | implement | Inline execution of the same plan with ledger, `task-start`/`task-done`, one final reviewer | 20,405 | 23,038 | Yes |
| test-driven-development | TDD | Iron law: no production code without a failing test first; "delete means delete" | 9,578 | 17,846 | Yes |
| systematic-debugging | debug | 4-phase root-cause process; question the architecture after 3 failed fixes | 9,465 | 40,777 | Yes |
| verification-before-completion | verify | No completion claim without fresh command output | 3,646 | 3,646 | Yes |
| requesting-code-review | review | Dispatch one generic code-reviewer subagent on a SHA range | 2,977 | 9,426 | Yes |
| receiving-code-review | review | Verify feedback before acting, push back, no performative agreement | 6,203 | 6,203 | Yes |
| using-git-worktrees | isolation | Detect isolation, prefer native `EnterWorktree`, fall back to `.worktrees/`, setup, baseline tests | 6,813 | 6,813 | Yes |
| finishing-a-development-branch | ship / PR | Test, then a menu: merge locally, push + PR, keep; discard only on request | 7,781 | 7,781 | Yes |
| dispatching-parallel-agents | parallel | One agent per independent failure domain, dispatched in parallel | 6,078 | 6,078 | Yes |
| writing-skills | meta | TDD for skills, pressure tests, skill discovery optimization | 26,623 | 107,640 | Yes |
| diagnosing-superpowers | retro (plugin-only) | Transcript forensics with `path:line` evidence; GitHub issue only after approval | 6,904 | 40,841 | Yes |

## 1. Claude Code compatibility: 5/5

- Claude Code is the reference harness. `SP/skills/using-superpowers/references/claude-code-tools.md:3-4` says "Claude Code is the reference harness: skills speak its vocabulary (`Agent` for a subagent dispatch, todos, `Skill`)."
- The hook uses the documented contract. `SP/hooks/hooks.json:3-14` registers a SessionStart command hook with matcher `startup|clear|compact`, run through `${CLAUDE_PLUGIN_ROOT}`. `SP/hooks/session-start:42-44` emits `hookSpecificOutput.additionalContext` only when `CLAUDE_PLUGIN_ROOT` is set, which avoids double injection (comment at `:33-34`).
- It prefers native tools. `SP/skills/using-git-worktrees/SKILL.md:51-57` and `:164` name `EnterWorktree` as preferred over raw `git worktree add`.
- It supports nested subagents and the subagent depth env var (`claude-code-tools.md:14-16`).
- The bundled scripts are invoked through `bash scripts/...` so they survive stripped exec bits (`RELEASE-NOTES.md`, v6.4.1 Fixes).

## 2. Lifecycle coverage: 4/5

| Phase | Skill | Notes |
|---|---|---|
| Clarify | brainstorming | Intent first (`brainstorming/SKILL.md:19-36`), three paths (`:58-88`) |
| Spec | brainstorming (architectural path) | `docs/superpowers/specs/...` (`:135`, `:241`) |
| Plan | writing-plans | |
| Implement | subagent-driven-development, executing-plans | |
| TDD | test-driven-development | |
| Debug | systematic-debugging | |
| Review | requesting-code-review, receiving-code-review, SDD task reviewer | Generic reviewer, not the project's `pr-review` |
| Verify | verification-before-completion | Commands only. No browser or E2E notion, so nothing maps to `scripts/cds-session.mjs` |
| Ship / PR | finishing-a-development-branch | Push and PR; nothing on draft PRs, dedup, CI, or deploy |
| Retro | diagnosing-superpowers | Diagnoses superpowers sessions only. No project retro or lessons-learned writer |
| Linear / issue tracker | **none** | No ticket intake, branch naming, or status handling |
| Parallel agents | dispatching-parallel-agents; SDD is serial by design (`SDD/SKILL.md:282`) | |
| Security / perf / observability | **none dedicated** | Only checklist lines in `requesting-code-review/code-reviewer.md:78-81` |
| Worktrees | using-git-worktrees | |
| Meta | writing-skills | |

Gaps: Linear, security, performance, observability, browser/E2E verification, and release/deploy.

## 3. Systematic-ness: 5/5

**Router.** `SP/hooks/session-start:11` reads `skills/using-superpowers/SKILL.md`. At `:27` it wraps the content in `<EXTREMELY_IMPORTANT>You have superpowers ...`. The hook fires on startup, clear and compact (`hooks.json:5`), so the router is re-injected after every compaction.

**1% rule.** `using-superpowers/SKILL.md:11-13`: "If you think there is even a 1% chance a skill might apply ... you ABSOLUTELY MUST invoke the skill. ... YOU DO NOT HAVE A CHOICE." Further mechanics:
- `:20` requires invocation BEFORE "clarifying questions, exploring the codebase, or checking files".
- `:22` routes plan mode to brainstorming.
- `:24` requires announcing the skill and creating one todo per checklist item.
- `:37-50` lists 12 red-flag rationalizations.
- `:6-8` (`<SUBAGENT-STOP>`) exempts subagents.
- `:65` gives CLAUDE.md precedence over skills.

**Gates between skills.**
- brainstorming HARD-GATE, `:38-56`: separate approvals for the design, the written spec, and the plan plus execution method.
- Terminal states are path-bound, `:184-189`: after the architectural path, "the ONLY skill you invoke after brainstorming is writing-plans".
- The plan header names the required sub-skill, `writing-plans/SKILL.md:61`, and the handoff asks the user to review the plan and choose a method (`:167-192`).
- executing-plans loads TDD at setup (`:149-152`) and puts verification over completion claims (`:219-220`).
- SDD and executing-plans both end in finishing-a-development-branch (`SDD:487`, `executing-plans:304`).
- systematic-debugging links to TDD and verification (`:177`, `:189`).

**Script-enforced gates.**
- `executing-plans/scripts/task-done:43-46` writes the ledger line only when the tests pass.
- `subagent-driven-development/scripts/review-package:27-28` refuses an empty or non-descendant range (exit 3).

**Caveat.** Enforcement is prose only. There is no PreToolUse or Stop hook, so compliance depends on the model following injected text.

## 4. Rigor / quality: 4/5

**Evidence gates.**
- `verification-before-completion/SKILL.md:16-36`: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE".
- TDD requires a verified RED (`:113-128`) and the whole project suite, not only the file (`:185-193`).
- The implementer report must carry RED/GREEN evidence (`SDD/implementer-prompt.md:133-135`).
- The reviewer's "Declined to judge" list (`code-reviewer.md:43-48`) makes skipped checks visible.
- The executing-plans completion contract is at `:207-220`.

**Tests of its own skills.**
- `SP/tests/` holds plugin-code tests (brainstorm-server node tests, hooks, opencode, codex sync).
- Claude-in-the-loop tests: `tests/claude-code/*.sh` and `tests/explicit-skill-requests/` (9 prompts).
- Pressure-test fixtures: `skills/systematic-debugging/test-pressure-{1,2,3}.md`.
- writing-skills applies an iron law to skills themselves (`writing-skills/SKILL.md:376-395`).
- Release notes cite eval measurements, e.g. "sessions ran only that file in 11 of 12 probe runs" (`RELEASE-NOTES.md`, v6.4.1 TDD).

**Not verifiable from the package.**
- The behavior evals live in an external `evals/` submodule (`docs/testing.md:27-37`, the Quorum lab), and `SP/evals` is absent from the installed package.
- `.github/` ships only FUNDING, issue templates and a PR template. There are no workflow files, so no CI is visible.
- `.pre-commit-config.yaml` covers `evals/` only.

**Internal inconsistency.** `requesting-code-review/SKILL.md:28` uses `BASE_SHA=$(git rev-parse HEAD~1)`, while `SDD/SKILL.md:290` says "never `HEAD~1`, which silently drops all but the last commit".

## 5. Fit with project rules: 2/5

The only mitigation is `using-superpowers/SKILL.md:65`: "User instructions (CLAUDE.md ...) take precedence over skills". Every conflict below is therefore resolved only if the model notices it. The defaults themselves contradict the CDS rules in several high-stakes places.

### Conflicts

| # | Superpowers line | Quote | Project rule it violates |
|---|---|---|---|
| 1 | `brainstorming/SKILL.md:135` | "Write design doc — save to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit" | `git-branch-and-commit-safety.md:58` "Commit or push only when the user asks." |
| 2 | `brainstorming/SKILL.md:244` | "Commit the design document to git" | Same, plus `:55` (CDS prefix) and `:66` (no local-only refs) |
| 3 | `brainstorming/SKILL.md:259` | "Spec written and committed to `<path>`." | Commits before the user review gate |
| 4 | `writing-plans/SKILL.md:18` | "Save plans to: `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`" | Creates a new tracked docs tree in REPO; no such convention exists |
| 5 | `writing-plans/SKILL.md:10`, `:135-140` | "Frequent commits." / step "Commit" with `git commit -m "feat: add specific feature"` | `git-branch:55` "Prefix every commit with the branch's Linear issue ID"; `:58` |
| 6 | `subagent-driven-development/implementer-prompt.md:38` | "4. Commit your work" (every task) | `git-branch:58` |
| 7 | `executing-plans/SKILL.md:204` | "Commit as the plan's commit steps say." | `git-branch:58` |
| 8 | `subagent-driven-development/SKILL.md:17` | "Do not pause to check in with your human partner between tasks. Execute all tasks from the plan without stopping." | `minimal-change-discipline.md:5` ">3–4 files, pause and confirm scope" |
| 9 | `subagent-driven-development/SKILL.md:19-25` | "A running plan does not wait on a human. Conflicts, ambiguities, plan defects, a cap you would have asked to exceed — decide them." | `multi-agent-orchestration.md:110-111` "Judgment — spec interpretation, scope calls ... escalate to a human; never silently guess into code." |
| 10 | `executing-plans/SKILL.md:27-37` | Same "Continuous execution" and "Rulings, not stalls" text | Same as #8 and #9 |
| 11 | `subagent-driven-development/SKILL.md:373-386`, `:411-425` | Five fix rounds per task, then "Rule and continue" | `minimal-change-discipline.md:55` "stop and split when ... a review round finds a defect in code added by an earlier round" |
| 12 | `finishing-a-development-branch/SKILL.md:60` | "1. Merge back to <base-branch> locally" | `git-branch:63` "main is protected — always open a PR, never push directly" |
| 13 | `finishing-a-development-branch/SKILL.md:90-96` | `cd "$MAIN_ROOT"` / `git checkout <base-branch>` / `git pull` / `git merge <feature-branch>` | `CLAUDE.md:40` and `git-branch:28`: never `git checkout <branch>` in the shared primary tree. The menu gate is at `:78-82`, but this option exists in the menu |
| 14 | `finishing-a-development-branch/SKILL.md:116`, `:121-124` | `git push -u origin <feature-branch>`, then create the PR | No draft (`multi-agent-orchestration.md:163` "open PR **as draft**"); no dedup (`multi-agent:72` "AGAIN immediately before any push / PR-open") |
| 15 | `using-git-worktrees/SKILL.md:76` | "default to `.worktrees/` at the project root" | No such convention; existing worktrees live elsewhere |
| 16 | `using-git-worktrees/SKILL.md:86`, `:154` | "If NOT ignored: Add to .gitignore, commit the change, then proceed." | Edits a tracked file and commits without asking (`git-branch:58`); 3–4-file scope |
| 17 | `using-git-worktrees/SKILL.md:96` | `git worktree add "$path" -b "$BRANCH_NAME"` (off current HEAD) | `git-branch:14-17` "`git fetch origin <base>` first, then branch/worktree off `origin/<base>`"; no `CDS-XXXX` branch name (`git-branch` Linear-first; memory: `CDS-XXXX/name`) |
| 18 | `using-git-worktrees/SKILL.md:108` | `if [ -f package.json ]; then npm install; fi` | `ports-and-local-artifacts.md:99` "Symlink deps from the primary checkout" |
| 19 | `subagent-driven-development/SKILL.md:449` / `executing-plans/SKILL.md:238` | `git merge-base main HEAD` | `git-branch:15-17`: local `main` is stale; diffing against it mis-reads the base |
| 20 | `test-driven-development/SKILL.md:37-45` | "Write code before the test? Delete it. Start over. ... Delete means delete" | `minimal-change-discipline.md:9` "preserve existing functionality"; risky in a shared tree |
| 21 | `test-driven-development/SKILL.md:254` | "All of these mean: Delete code. Start over with TDD." | Same |
| 22 | `test-driven-development/SKILL.md:236` | "Existing code has no tests → You're improving it. Add tests for existing code." | `minimal-change-discipline.md:3-4` minimal fix, don't touch unrelated files |
| 23 | `requesting-code-review/SKILL.md:14-17`, `:34` | Mandatory generic `general-purpose` reviewer "after each task ... before merge" | Bypasses `pr-review` / `self-review` and the inline Bug/Suggestion/Nit format (`pr-review-conventions.md`); `multi-agent:134` "Round ≥2: `pr-review` alone" |
| 24 | `subagent-driven-development/SKILL.md:310-314` | A per-task reviewer on every task plus a final review | Multiplies review seats against the measured economics in `multi-agent:116-140`. Mitigation: re-reviews are scoped to the fix diff (`:396`), which matches `multi-agent:136` |
| 25 | `dispatching-parallel-agents/SKILL.md:66-77` | Parallel fix agents dispatched into the same working tree | `multi-agent-orchestration.md:44` "Each implementer runs in its **own** `git worktree`" |
| 26 | `receiving-code-review/SKILL.md:203-205` | Reply in PR threads via `gh api .../replies`, with no approval gate | `multi-agent-orchestration.md:27-40` treats posting as an outward action that a human gates |
| 27 | `using-superpowers/SKILL.md:20` | Invoke skills "BEFORE any response or action — including ... exploring the codebase" | Collides with project skills (`investigate-bug`, `prod-migration-issue`, `self-review`) and with project routing. `:22` forces brainstorming before plan mode |
| 28 | `brainstorming/visual-companion.md:58` | Persist mockups in `<repo>/.superpowers/brainstorm/`; "Remind the user to add `.superpowers/` to `.gitignore`" | Untracked state in the shared primary tree |
| 29 | `subagent-driven-development/scripts/sdd-workspace:46`, `:81` | Writes `<repo-root>/.superpowers/sdd/` and a self-ignoring `.gitignore` | Writes untracked state into whatever tree is checked out, including the primary tree |

### Places where it fits

- Read-only reviewer: `code-reviewer.md:50-52` says never move HEAD and use `git worktree add /tmp/...`.
- `finishing-a-development-branch` asks before integrating (`:78-82`), confirms the base (`:46-51`), never force-pushes or force-removes (`:177-181`, `:225`), and discards only on a typed `discard` (`:137-146`).
- `using-git-worktrees` asks consent before creating a worktree (`:41-45`).
- SDD and executing-plans stop on "a merge, a push to a shared branch, a publish" (`SDD:27-31`), and refuse to start on main without consent (`SDD:126-129`).
- systematic-debugging's "question the architecture after 3 failed fixes" (`:198-212`) matches the CLAUDE.md "rescue net means redesign".
- verification-before-completion matches "Don't claim verified without running" (`minimal-change-discipline.md:14`).
- receiving-code-review's "verify before implementing" matches "Reviewer output is a claim, not a fact" (`multi-agent:141`).

## 7. Context / token cost: 3/5

**Always-on, every session.**
- SessionStart injection: 3,418 bytes (the 3,192-byte `using-superpowers/SKILL.md` plus the wrapper from `session-start:27`), about 850 tokens. It is re-injected on `clear` and `compact`.
- Skill-list descriptions: 15 descriptions totalling 2,310 characters. With the `superpowers:<name>` prefixes this is about 2.8 KB, or about 700 tokens.
- Total always-on is about 6.2 KB, or about 1.55k tokens.
- Subagents also see the description list, but `<SUBAGENT-STOP>` tells them to ignore the router.

**On demand.**
- `SKILL.md` files total 168,882 bytes. All skill files total 366 KB.
- Five largest `SKILL.md` files:
  1. subagent-driven-development: 32,577
  2. writing-skills: 26,623
  3. executing-plans: 20,405
  4. brainstorming: 17,548
  5. test-driven-development: 9,578
- Largest supporting file: `writing-skills/anthropic-best-practices.md`, 46,197 bytes.
- A full architectural arc (brainstorming, worktrees, writing-plans, SDD, TDD, verification, requesting-code-review, finishing) loads about 90 KB, or about 22k tokens, into the controller. It also spends a fresh subagent context per task plus one per review. The README says it can "work autonomously for a couple hours" (`README.md:44`).

## 8. Safety / risk: 4/5

**Hooks.** There is one hook, SessionStart. It only reads (`cat` + `printf`, `session-start:11-51`), makes no network calls, and always exits 0. There are no PreToolUse, PostToolUse or Stop hooks, so nothing intercepts tool calls. The Windows polyglot wrapper (`run-hook.cmd:13-46`) is benign.

**Scripts.**
- `sdd-workspace` writes `<repo>/.superpowers/sdd/<plan>/` and a `.gitignore` (`:46`, `:65-66`, `:81`).
- `task-done` executes whatever test command it is given (`:40`).
- SDD Finish runs `rm -rf <workspace>`, scoped to this plan's directory (`SDD/SKILL.md:483`).
- The brainstorm visual companion is a Node HTTP + WebSocket server on `127.0.0.1` with a random port and a session-key token (`start-server.sh:26`, `server.cjs:100`, `visual-companion.md:45-51`). It auto-opens the browser, and `stop-server.sh` does `kill -9` / `rm -rf` on its own session directory.

**Telemetry.** The visual companion loads a logo from `primeradiant.com` that carries the plugin version (`server.cjs:106-112`, `README.md:397`). It is opt-out through `SUPERPOWERS_DISABLE_TELEMETRY`, `DISABLE_TELEMETRY` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`.

**Destructive commands in skill prose.**
- `git checkout`, `git pull` and `git merge` in the main root (`finishing:94-96`).
- `git branch -D` on discard (`finishing:156`).
- `git push` (`finishing:116`).
- Committing a `.gitignore` edit (`worktrees:86`).
- `gh issue create` against obra/superpowers, only after approval (`diagnosing-superpowers/references/github-issues.md:26-31`).

All of these sit behind a user menu or an explicit request. The risk is the default *options* in a shared tree, not unprompted execution.

**Update drift.** `README.md:391` says updates "are often automatic", and behavior changes between versions. v6.4.1 removed the executing-plans check-ins: "Heads up: `executing-plans` no longer stops every few tasks" (RELEASE-NOTES v6.4.1).

## 9. Maintenance / maturity: 5/5

- Version 6.4.1, released 2026-09-18 (`.claude-plugin/plugin.json:4`, `RELEASE-NOTES.md:3`).
- MIT license (`LICENSE`); author Jesse Vincent (obra, Prime Radiant).
- Distributed through the official `claude-plugins-official` marketplace.
- `RELEASE-NOTES.md` has 53 release sections, from v2.0.1 (2025-10-12) to v6.4.1. Recent cadence is roughly every 3 to 5 weeks: 6.0.0 on 06-16, 6.1.0 on 06-30, 6.2.0 on 07-23, 6.3.0 on 08-12, 6.4.1 on 09-18.
- Design specs and plans are kept in-repo (`SP/docs/superpowers/{specs,plans}`).
- It ships manifests for about 10 harnesses, and `.version-bump.json` keeps 11 manifest versions in sync.
- The risk is churn, not abandonment.

## Repo references (edits a replacement would need)

`git -C REPO grep -n -i superpowers` returns no matches. A wider `git grep` for every superpowers skill name also returns no matches. A filesystem grep of REPO outside `node_modules`, and of `~/.claude/{CLAUDE.md,rules,skills,agents,commands}` and the project memory directory, finds nothing. `REPO/.superpowers`, `REPO/.worktrees` and `REPO/docs/superpowers` do not exist.

- **Repo edits needed: none.** The repo does not depend on or reference superpowers.
- **Config edit needed:** `~/.claude/settings.json:24` `"superpowers@claude-plugins-official": true`, which is the only coupling. Optionally uninstall the entry in `~/.claude/plugins/installed_plugins.json`.
- **Functional dependencies that would disappear:**
  - The project's own skills (`REPO/.claude/skills/{self-review,pr-review*,investigate-bug,commit,...}`) do not call superpowers skills by name.
  - The session would lose the global TDD, verification and debugging defaults that superpowers injects.
  - Nothing in the CDS rules restates those defaults, except "Don't claim verified without running" (`minimal-change-discipline.md:14`) and the rescue-net rule.

## Top strengths

1. The strongest router in the class. The SessionStart injection plus the 1% rule plus path-bound terminal states make skills actually fire. It is re-injected after compaction.
2. Evidence discipline: the verification iron law, TDD RED/GREEN evidence in reports, `task-done` refusing to ledger a red run, and `review-package` range guards.
3. Compaction-resilient execution: an on-disk ledger, a "Rulings I made" list, model-tier selection per role, and fix-diff-scoped re-reviews.
4. Approval gating where it counts most: the brainstorming HARD-GATE, the plan review, the finishing menu, typed `discard`, no force-push, and a consent prompt before creating a worktree.
5. A mature, fast-moving project with measured changes, an MIT license and the official marketplace.

## Top risks for CDS

1. **Silent commits by default.** Spec commits (`brainstorming:135`, `:244`), per-task implementer commits (`implementer-prompt.md:38`), the plan template's `feat:` commits (`writing-plans:139`), and `.gitignore` commits (`worktrees:86`) all contradict "commit only when the user asks" and the `CDS-XXX:` prefix.
2. **The local-merge option checks out the base in the shared primary tree** (`finishing:90-96`). That is the exact action CLAUDE.md forbids, and it targets a protected `main`.
3. **Autonomous "rulings" instead of escalation** (`SDD:17-25`, `executing-plans:27-37`), with five fix rounds that never trigger a split. This inverts the project's ">3–4 files confirm" and "escalate judgment" rules and its PR-split rule.
4. **Worktree defaults are wrong for this monorepo.** They branch off the current HEAD instead of `origin/<base>` (`:96`), run `npm install` instead of symlinking (`:108`), use `.worktrees/` in-repo (`:76`), and diff against local `main` (`SDD:449`).
5. **Precedence depends on model attention.** `using-superpowers:11-13` ("YOU DO NOT HAVE A CHOICE") and `:20` push hard against `:65` ("CLAUDE.md takes precedence"). No hook enforces the project rules, so conflicts get resolved case by case. Auto-updates can also change behavior silently (v6.4.1 removed check-ins).
