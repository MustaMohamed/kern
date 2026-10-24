# kern: design spec

Status: draft for review. Date: 2026-10-12. Author: Mustafa Mohamed, with Claude.
Approved design: https://claude.ai/artifact/NQ55fRJA1WU39Finrs3evj (revision 5).
Companion: `2026-10-12-kern-m1-m2-skills.md` holds the step-level specs for the first build's skills.
Destination: this file moves to `docs/specs/` in the kern repo at milestone M0.

## 1. Summary

kern is a personal Claude Code plugin that replaces superpowers. It merges the strongest mechanism per category from superpowers 6.4.1, pstack 0.15.17, mattpocock/skills 1.3.1, addyosmani/agent-skills 0.6.12 and caveman 3.2.0. It runs in any project. Each project's own rules and skills win over it, and a project plugs in through an untracked settings file.

The name follows the operating-system model: a small always-on kernel routes work and enforces policy, skills are its system calls, project settings are its drivers, the user's own skills load as modules, and guard hooks are its security module.

### 1.1 Goals

0. Master goal: for each category of work, kern is at least as strong as the strongest of its five sources. It takes the strongest mechanism per category, enforces it in code where code can, and combines the parts as focused lanes, scripts and hooks rather than one merged prompt. Goals 3 and 4 bound it. It is measured three ways:
   - `docs/specs/coverage.md` gives every source mechanism a home or a recorded rejection, and a re-audit at each milestone close leaves no row of that milestone where a source is stronger, counting only built and tested work.
   - Head-to-head evals run kern and the strongest source on the same seeded fixtures for review, debugging and planning, and count real findings and false alarms.
   - The M2b pilot includes side-by-side runs against superpowers on the same tasks.
1. One install per machine; the same behaviour in every project.
2. Cover every job superpowers does today, plus pstack's proof discipline, mattpocock's debugging gate and design vocabulary, addy's specialist skills and evals, and caveman's terse voice.
3. Gated by default: nothing leaves the machine and nothing is committed without the user, unless the user turns on autopilot for the session.
4. Low standing cost: about 1.2k tokens per session at M2 and at most 1.7k at the full build (kernel, auto descriptions and agent descriptions), against superpowers' 1.5k.
5. The framework tests itself in CI and has a learning loop that turns repeated mistakes into checks.

### 1.2 Non-goals

- Other coding tools (Cursor, Codex, Gemini). Claude Code only.
- Model routing to non-Claude models.
- A browser app that drives Claude Code. Visual pages show one output and collect one answer.
- Team distribution. kern is personal; a team may adopt it later.
- Replacing a project's own skills. kern defers to them.

### 1.3 Decisions

| # | Decision | Choice |
|---|---|---|
| D-1 | Name and slash prefix | `kern`, skills invoked as `/kern:<skill>` |
| D-2 | Audience and scope | Personal plugin, portable across projects, not project-specific |
| D-3 | Harness | Claude Code only |
| D-4 | Default autonomy | Gated, with an opt-in autopilot per session. A task the user calls quick and clear skips define's design and spec approval; commits, pushes and every other ask stay gated (user decision 2026-10-17). Any explicit waiver of approval does the same: asked on 2026-10-20 whether "Don't ask me questions or wait for approval, just build it" skips define's spec approval, the user answered "Yes, any explicit waiver": "Any clear 'don't wait for approval' takes define's fast path. kern states its build choices in one line and builds. Commits, pushes and other asks stay gated." |
| D-5 | Modes | Voice `normal` or `terse`; surface `chat`, `auto` or `html` |
| D-6 | Terse voice | kern's own `terse` mode, adapted from caveman with attribution; caveman uninstalled after M1 |
| D-7 | html surface | Single visual pages, answerable on the page or in the terminal |
| D-8 | Working files | `.kern/` at the main worktree root, excluded through `.git/info/exclude` |
| D-9 | Repo | Private GitHub repo that is its own marketplace |
| D-10 | First build | M0 to M2b (M2 split into M2a build and M2b proof), with the pilot inside M2b, then switch superpowers off |
| D-11 | Review | Four parallel lanes, one of them Claude Code's built-in `code-review` |
| D-12 | Stacked PRs | Supported through `take-feedback`, with `gh stack` first-class |

## 2. Sources and licensing

| Source | Version | Licence | Copyright | Pinned at |
|---|---|---|---|---|
| obra/superpowers | 7.0.0 | MIT | 2025 Jesse Vincent | bb92a77 |
| cursor/plugins, `pstack/` | 0.15.25 | MIT | 2026 Lauren Tan | 182f2ce |
| mattpocock/skills | 1.3.1 | MIT | 2026 Matt Pocock | 49dd158 |
| addyosmani/agent-skills | 0.6.13 | MIT | 2025 Addy Osmani | aeac41d |
| caveman | 4.0.1 | Apache-2.0 | see its NOTICE | d262ab3 (tag v4.0.1) |

`UPSTREAM.md` is canonical for pins; this table follows it.

Rules:

1. `licenses/<source>.LICENSE` holds each full licence text.
2. `NOTICE` lists each source, its URL, its copyright line and a map from kern files to the sources they derive from. For caveman it also reproduces caveman's NOTICE content, as Apache-2.0 requires.
3. Files modified from an Apache-2.0 source carry a header line stating they were changed (Apache-2.0 section 4b). Scripts adapted from any source carry a one-line source comment. SKILL.md files carry none; the NOTICE map covers them.
4. "Caveman", "ultracave" and "megacave" are trademarks. kern never uses them as names. The mode is `terse`.
5. `UPSTREAM.md` records the pinned commit per source so later upstream changes can be reviewed and ported.
6. kern's `unslop`, `recall` and `no-comments` and its `comment-sicko` agent start from the user's own adapted copies in `~/.claude/skills/` and `~/.claude/agents/`, which are already Claude Code-ready, not from pstack upstream.
7. kern's own licence is MIT.

## 3. Architecture

### 3.1 Layers

| Layer | Loaded | Contents |
|---|---|---|
| Kernel | Every session, by hook | Precedence, routing table, autonomy, evidence rule, reply contract, active mode, project settings summary |
| Phase skills | When a route or command reaches them | define, plan, execute-plan, prove-it, self-review, pr-review, finish-branch, ship-check |
| Disciplines | When a route reaches them | implement, diagnose, take-feedback, recall, write-skill |
| Specialists | On context or command | architect, explain, domain-model, prototype, perf, refactor, expand-contract, build-ui, verify-app, triage, no-comments |
| References | Read on demand | project-contract, principles, stacks/*, checklists, model-selection, unslop, technical-writing |
| Runtime | As needed | 9 agents, guard hooks G1 to G17, mode state, on-demand page server, eval suite |

### 3.2 Invocation tiers

| Tier | Frontmatter | Reached by | Description limit | Members |
|---|---|---|---|---|
| auto | normal | The model, by description match | 300 chars each, 1,500 total | prove-it, recall, write-skill, expand-contract, build-ui |
| path | `disable-model-invocation: true` | A kernel route that Reads the SKILL.md at an absolute path the hook renders; also the user by slash | 120 chars | define, plan, execute-plan, parallel-work, implement, diagnose, self-review, take-feedback, domain-model, prototype, decision-log, visual, unslop, technical-writing |
| slash | `disable-model-invocation: true` | The user only | 120 chars | mode, autopilot, help, architect, explain, triage, perf, refactor, pr-review, verify-app, no-comments, commit, finish-branch, ship-check, handoff, retro, correct, plain, skill-eval |

`disable-model-invocation: true` removes a skill's description from context and blocks the Skill tool, per the Claude Code skills docs. Path-tier skills are therefore reached only through kernel routes or slash commands. A path skill loaded by Read gets no `${CLAUDE_PLUGIN_ROOT}` or `$ARGUMENTS` substitution and no `allowed-tools`, so path bodies use no placeholders; the kernel header prints the plugin root instead.

Agent descriptions are always listed for the Agent tool, so they count against the same budget: at most 150 characters each, and at most 2,500 characters for auto skills and agents together. At M2 the total is about 970 characters (two auto skills, three agents).

### 3.3 One task, end to end

1. Session starts. The SessionStart hook injects the kernel, the active mode's rules and the project settings summary. Subagents get the subagent kernel.
2. Route. Before the first tool call of a new task, the kernel matches it, Reads the route, and copies its steps into the todo list verbatim.
3. Read the project. The skill resolves settings (section 5).
4. Work. Writing agents run in their own worktrees. Guards ask before risky git, tracker and deploy actions.
5. Show. When the surface calls for it, options, variants and designs open as a visual page.
6. Prove. prove-it needs a command and its output before any "done".
7. Learn. Corrections route to `/kern:retro` or `/kern:correct`.

### 3.4 Repo layout

```
kern/
  .claude-plugin/plugin.json        name, version, description, author, repository, license
  .claude-plugin/marketplace.json   the repo is its own marketplace; plugins[0].source "./"
  hooks/hooks.json                  SessionStart, SubagentStart, UserPromptSubmit, PreToolUse, Stop
  hooks/session-start               renders kernel + mode + settings summary
  hooks/subagent-start              renders subagent kernel + voice
  hooks/prompt-submit               mode and autopilot switches, reminders, unseen page answers
  hooks/guards/*.sh                 G1 to G17
  kernel/kernel.md  kernel-subagent.md  context.md  settings.md
  modes/terse.md  modes/html.md  modes/auto.md
  skills/<name>/SKILL.md  references/  prompts/  templates/  scripts/
  agents/<name>.md
  pages/server.cjs  pages/render.mjs  pages/components.css  pages/vendor/mermaid.min.js
  bin/kern-page                     publish | wait | stop
  scripts/lint-skills.mjs  route-eval.mjs  kernel-adherence.mjs  check-version.mjs  release.mjs
  tests/hook-shape.sh  tests/guards/*.bats  tests/fixtures/projects/<case>/
  evals/cases/<skill>.json  evals/plugin/<case>/  evals/rejected.md
  .out-of-scope/<concept>.md
  docs/specs/  docs/<skill>.md
  CHANGELOG.md  LICENSE  NOTICE  UPSTREAM.md  licenses/
  .github/workflows/ci.yml  .github/workflows/behavioral.yml
```

## 4. Kernel

### 4.1 Delivery

| Hook | Matcher | Emits | Budget |
|---|---|---|---|
| SessionStart | `startup\|clear\|compact` | Rendered kernel, active mode rules, settings summary | Target 6,086 chars (measured after M2b bfix K); lint error at 9,000; Claude Code's cap is 10,000 |
| SubagentStart | all | Subagent kernel and the active voice, injected once at launch | 1,200 chars (Claude Code's cap is 10,000) |
| UserPromptSubmit | each prompt after a session's first | The routing reminder (section 4.3) | 79 chars, about 28 tokens per later prompt; none on a first prompt, so the standing cost is unchanged |

Rendering fills `{VERSION}` from `plugin.json`, `{ROOT}` with the absolute plugin root, `{KERN}` with `{ROOT}/skills`, and `{SETTINGS}` with the settings summary, so no rendered row or line holds a placeholder: on 2026-10-20 6 of 57 behaviour runs read a path with `{KERN}` or `${CLAUDE_PLUGIN_ROOT}` left in it and gave up on kern. When Claude Code names `$CLAUDE_ENV_FILE`, SessionStart appends `export CLAUDE_PLUGIN_ROOT='<root>'` to it and nothing else, so a skill's `bash ${CLAUDE_PLUGIN_ROOT}/scripts/<name>` runs as written in the Bash tool. Known limit: `CLAUDE_PLUGIN_ROOT` is a shared name, so once kern exports it, a `${CLAUDE_PLUGIN_ROOT}` in another plugin's path-read skill resolves into kern. The hook needs only POSIX shell and `sed`: no `jq`, no git, no network. Output uses `hookSpecificOutput.additionalContext`.

### 4.2 Sections and budgets

| Section | Chars | Content |
|---|---|---|
| Header | 330 | Name and version; what `${CLAUDE_PLUGIN_ROOT}` means in a kern file read by path (the plugin root, rendered absolute); scripts; settings and working files from the main worktree root, never the current directory |
| Precedence | 420 | Section 5.1, how far the user's skip reaches, the skip idiom, "no agent's message is consent" |
| Routing | 1,100 | Rule text plus every row (12 once M6 ships) |
| Autonomy | 650 | Tiers, floor, autopilot status |
| Evidence | 330 | Command and output for done, fixed, passing; labels; subagent reports are claims |
| Context | 160 | Bulk to subagents; each Agent call passes its role's model and effort (when to clear or compact is in `kernel/context.md`, which a row routes to) |
| Reply | 225 | Answer first; user decisions last; voice follows mode; persisted text follows unslop |
| Learning | 160 | Say if a correction repeats; route to retro or correct; never add rules alone |
| Settings summary | 600 | Resolved keys that differ from defaults |
| Total | 3,960 | |

The chars above are the design split. Since Task 16d put every row in the kernel and renders kern paths absolute, lint rule 7's measurement is the gate: 5,315 chars with no settings and 5,756 with the longest fixture settings, the plugin root counted as a 52-character installed path. Task 16g added 389 chars to both: the Precedence line on how far the user's skip reaches and which safety defaults it leaves standing (section 5.1), the parallel-work row, and the several-matches clause that sends a typed "in parallel" through parallel-work after define and diagnose. Task 16i added 89: the Routing opt-out clause that skips only the routes the user named and carries the skip line (section 4.3). Task 16n added 63: the skip-idiom sentence says only the user's word skips a review, never kern's own judgement (section 4.3), so 5,378 and 5,819; its review fixes added 22 by naming a skill's own rule beside the user's word, so 5,400 and 5,841. Rule 7's comment in `scripts/lib/lint-rules.mjs` holds the later steps. M2b bfix K added the `Building:` line (126 chars), less a lossless cut of 6, so rule 7 locks 6,086 chars with the longest fixture settings and a standing cost of 6,175.

### 4.3 Routing table

The rule: before a new task's first tool call or question, match the task against the table. A task that changes code, fixes a bug, commits or claims done matches a row, even a quick, small or obvious one; only a casual turn, or a question that changes nothing and fits no row, matches nothing: it is answered, reading what it needs (Task 17a P11, audit B2). A user opt-out skips only the routes it names: before any tool call, kern says `Skipped: <what>. Risk: <risk>.` (section 5.1). The clause that decides the skip carries the line, so a run that never opens the skipped route still names it: on 2026-10-20 the line, then only in Precedence, was missing in 2 of 3 `pressure-diagnose-obvious-fix` runs, which read no route (Task 16i). A build the user calls quick, or whose approval they waive, gets `Building: <what>. My choices: <each>.` before any tool call, the skip line's slot: said at define's or implement's route read, the line held in 0 of 18 graded runs, while the skip line held in 47 of 48 (M2b bfix K, bfix-lane-3 S1; the user's "Kernel turn-start line", 2026-10-24). On a match, Read the route, or the project skill an override names for its job, before any other tool call, then open a todo list whose first items are its `## Steps`, copied verbatim (one `TaskCreate` per step, or `TodoWrite`). Each new task reads its route, even one read earlier. The kernel arrives once, at SessionStart, so each prompt after a session's first also gets one line from the UserPromptSubmit hook: "kern: new request? Match it against the Routing table; Read its route, or the override named for its job, first." (Task 16p, the user's "Add the reminder", 2026-10-22: in the 2026-10-22 multi-diagnose runs Sonnet read no route for its second task in 3 of 3 runs, and the passing re-reads of 2026-10-21 stopped at the `## Steps` heading; if one full run still leaves Sonnet under two of three, the case becomes a known limit). A prompt is a later one when the session state already holds an earlier prompt's `prompt_hashes`, which startup and `/clear` drop. A wrapped prompt (a task notification, a cross-session or agent message, a scheduled task), an empty prompt, and a prompt that names or switches a mode or autopilot get no reminder; a slash command's UserPromptExpansion run prints none, so its two hook runs print one. A step not done stays as `skip: <reason>`, and only a skill's own rule or the user's word skips a review, never kern's own judgement: plan's review, define's spec review, and execute-plan's task and final reviews (Task 16n: on 2026-10-22 kern skipped plan's review in 3 of 6 head-to-head runs, "to save budget" or because the plan was small; the user's "Only by my word"). A skip condition a step states itself, such as self-review's `review.builtin: off` or `skip: no spec`, is that skill's own rule, not kern's judgement (Task 16n review, M3). Several matches: define and diagnose before build, then a typed "in parallel" builds through parallel-work. A non-trivial change with no match: plan.

| Observable trigger | Route |
|---|---|
| New behaviour and no agreed spec | define |
| Agreed spec, more than one step | plan |
| Executing an agreed plan; or one bounded change, or tests for existing code (M2b Task 17, AD47) | execute-plan; implement |
| Independent changes asked for in parallel | parallel-work |
| Bug, failing test, unexpected output | diagnose |
| About to say done, fixed or passing, commit, or open a PR | prove-it |
| Review requested, or review comments or red CI received | self-review, pr-review or take-feedback |
| Editing a skill, CLAUDE.md, a rule or an agent file | write-skill |
| Prose others read: PR body, issue, doc, commit message | technical-writing (and unslop) |
| Starting or resuming after a gap | recall |
| Long, autonomous or unattended run | decision-log |
| Phase ends, or context is filling | kernel/context.md |

Every row is in the kernel table (Task 16d, the user's "Inline rows": on 2026-10-20 the rows inline routed 14 of 15 adherence cases, M2a's `kernel/routes.md` hop 11 of 15). A row ships in the same milestone as its route; until then it is absent, and lint rule 6 fails on a row whose route does not exist. M1 ships the technical-writing and context rows; M2 adds define, plan, execute-plan, implement, diagnose, prove-it, self-review and recall, and M2b parallel-work (Task 16g, the user's "Add a kernel row": a typed "in parallel" had no row); M3 adds pr-review, take-feedback and decision-log; M6 adds write-skill.

`overrides.<job>` in settings names a project skill that replaces the job's route; `off` means no override, so kern's route stays and a project skill with the job's name is not matched. `route.<name>` was dropped (Task 17a P13, the user's "No override", 2026-10-22). The override is rendered into the settings summary, not the table, so the table text is identical across projects. Every route file opens with a numbered `## Steps` list; the linter checks it.

### 4.4 Subagent kernel

At most 1,200 chars: the dispatcher already routed; precedence (brief, then the project's CLAUDE.md, rules and skills, then kern steps); the evidence rule; never commit, push, merge, post or message unless the brief says so; reply with the verdict first, then deltas and paths.

## 5. Settings contract

### 5.1 Precedence

Highest first:

1. The user's explicit instruction in this session.
2. A project skill that owns the same job: the `overrides.<job>` key, else a same-name project skill. It runs instead of kern's. kern's hooks still apply.
3. Project rules: CLAUDE.md, `.claude/rules/**`, memory. These may tighten anything and loosen nothing.
4. `.claude/kern.local.yml`, then `.claude/kern.yml`.
5. `~/.claude/kern.yml`.
6. The kernel and kern skill steps, then built-in defaults.

When the user's own message in this session says to skip a kern step, kern skips that step and says in one line what it skipped and what that risks. A skip or an opt-out reaches only what the user named: "No need to investigate" skips the diagnose route, but a "fixed" claim still needs fresh output. For an opt-out of a route, the line comes before any tool call as `Skipped: <what>. Risk: <risk>.`, from the Routing clause that decides the skip (section 4.3). The Evidence rule (no done, fixed or passing claim without a command run this session and its output), the guards and the section 8.1 defaults still hold. The guards hold D1 to D3, D8 and D12 on their own; the kernel's Precedence line names the two that only text holds, D11 (new behaviour ships with tests) and D7 (stored shapes change by expand/contract). So "skip the test-first ceremony" still leaves new behaviour to ship with tests, "don't ask me questions, just rename the stored field" still changes the stored shape by expand/contract, and "skip the checks" still meets G5's ask on the commit. An explicit waiver of questions or approval leaves D5's build choices to kern, said in one line as its own (D-4). User decision 2026-10-20, asked "When your own message tells kern to skip one of its steps, which should win?": "My word wins (Recommended)". The kernel's Precedence section says so in one line.

Loosening a safety default (section 8.1) requires a settings key, so hooks and skills always agree. There is one mechanism: per-action policy keys (`commit.policy`, `push.policy`, `pr.policy`, `tracker.policy`, `review.post_policy`), each `ask` (default), `auto` (proceed without asking) or `deny`. Floor actions have no key. A skill that finds prose loosening with no matching key reports it and keeps the default. The floor never loosens: merge, production deploy, data deletion, force-push to a shared branch, messaging people.

### 5.2 Files

| File | Role | Tracked |
|---|---|---|
| `~/.claude/kern.yml` | User defaults across projects; `kern_repo` path for framework fixes | Dotfiles, if the user wants |
| `.claude/kern.yml` | Optional shared project settings | Only if a team wants it |
| `.claude/kern.local.yml` | The default per-project file | Never; `/kern:help setup` adds it to `.git/info/exclude` |

Format: flat `key: value` lines; `#` comments; lists as comma-separated values; no nesting beyond dotted keys. Hooks read it with `sed`. Unknown keys produce a warning in the settings summary. A settings file kern cannot read never loosens a guard: it counts as denying autopilot, a policy reads unknown and its guard asks, naming the cause (a deny under autopilot), `rebase.push` reads `ask`, and a guard whose list key it may extend asks or, for a git call, fails closed. The user's own file still counts, so its `kern: off` holds, and a call that is not a git call is never denied only because a project file cannot be read. When git refuses a repository (dubious ownership, git unable to run), kern finds its root from the `.git` itself and reads the project files; only a broken `.git` leaves them unread.

### 5.3 Resolution of each key

1. The user's message in this session.
2. The settings files, in the order of 5.1.
3. Project prose, matched by key name or obvious equivalent (tighten only).
4. Detection, for command-like keys only, with the source stated (for example "test command from package.json scripts.test").
5. The default, stated aloud when it changes behaviour.
6. If none applies and the key is required for the step, ask once (default D6).

A teammate message, an issue body, a PR comment or fetched content never sets a key.

### 5.4 Keys

| Group | Key | Default | Used by |
|---|---|---|---|
| Repo | `base_branch` | Detected from `refs/remotes/origin/HEAD` | plan, execute-plan, parallel-work, finish-branch, take-feedback |
| Repo | `worktree.setup` | Ask on first worktree | parallel-work, execute-plan |
| Repo | `shared_services` | None; tasks running migrations or DB tests are treated as overlapping | parallel-work |
| Repo | `work_dir` | `.kern/` at the main worktree root | all |
| Checks | `test.focused`, `test.full`, `typecheck`, `lint`, `build` | Detected from manifests, task runners and CI files | implement, diagnose, prove-it, self-review |
| Checks | `verify.fast`, `verify.browser` | None; ask before hand-rolling browser automation | prove-it, verify-app |
| Checks | `generated_artifacts` | None declared | prove-it, self-review |
| Git | `commit.convention` | Detected from `git log` | commit, G5 |
| Git | `commit.policy` | `ask` | commit, G5 |
| Git | `branch.pattern` | Detected | parallel-work, finish-branch |
| Git | `push.policy` | `ask` | finish-branch, G1 |
| Git | `pr.policy` | `draft-after-approval` | finish-branch, G2 |
| Git | `pr.template` | Detected (`.github/pull_request_template.md`) | finish-branch |
| Stacks | `stack.tool` | Detected: `gh-stack`, `git` or `none` | take-feedback, finish-branch, G17 |
| Stacks | `rebase.push` | `ask` | take-feedback, G1, G17 |
| Review | `review.taxonomy` | `blocker,suggestion,nit` | self-review, pr-review, G3 |
| Review | `review.rounds` | `fanout-first-then-single` | pr-review |
| Review | `review.rules` | Project prose | pr-review |
| Review | `review.sensitive_paths` | Auth, permission, migration and secret-handling paths by name pattern | pr-review |
| Review | `review.builtin` | `on` | self-review, pr-review |
| Review | `review.builtin.effort` | `high` | pr-review |
| Review | `review.builtin.delta_effort` | `medium` | pr-review |
| Review | `review.builtin.max_findings` | `15` | pr-review |
| Review | `review.builtin.security` | `off` | pr-review |
| Review | `security.rules` | Project prose | pr-review |
| Tracking | `tracker` | `none` | define, plan, triage, G14 |
| Tracking | `tracker.first` | `false` | define, plan |
| Tracking | `spec.source` | `.kern/specs/` | define, plan, pr-review |
| Risk | `autopilot` | `allowed` | autopilot, G1 to G18 |
| Risk | `tracker.policy` | `ask` | define, plan, triage, G14 |
| Risk | `review.post_policy` | `ask` | pr-review, take-feedback, G3 |
| Risk | `scope_threshold` | Unset; any file outside the approved list pauses | execute-plan, implement |
| Risk | `protected_targets` | Unset | G13 |
| Risk | `deploy.envs`, `deploy.proof` | Unset | ship-check, G15 |
| Risk | `never_commit` | Unset | G6 |
| Modes | `mode.voice`, `mode.surface` | `normal`, `auto` | session-start, prompt-submit |
| Learning | `lessons` | `.kern/lessons.md` | retro, correct |
| Learning | `rule_bar` | 3 occurrences or 1 severe incident for prose; 2 for a mechanism | retro, correct |
| Overrides | `overrides.<job>` (`off`: no override) | None | kernel, all |
| Stack | `stack` | Detected | architect, build-ui, implement |
| Switch | `kern` | `on`; `off` disables kern in this project | all hooks |

### 5.5 Working directory

`.kern/` and the settings files resolve from the main worktree's root: the first entry of `git worktree list --porcelain`. Hooks and skills never read them from the current directory or `$CLAUDE_PROJECT_DIR` blindly, because a session running in a linked worktree would find no untracked settings there. Every worktree therefore shares one copy. `/kern:help setup` adds `.kern/` to `.git/info/exclude`, which lives in the common git directory and applies to all worktrees, so no tracked file changes. Writing untracked files under `.kern/` from a linked worktree does not touch the main checkout's git state and does not breach D3.

| Subdirectory | Contents |
|---|---|
| `specs/` | Specs from define |
| `plans/` | Plans from plan |
| `ledgers/` | execute-plan task ledgers and review records |
| `decisions/` | decision-log trails |
| `pages/` | Visual pages and their answers |
| `lessons.md` | Default lessons destination |

## 6. Modes

### 6.1 State

| Field | Values | Default |
|---|---|---|
| voice | `normal`, `terse` | `normal` |
| surface | `chat`, `auto`, `html` | `auto` |
| autopilot | `off`, `on` | `off` |

Each word sets one field and leaves the other as it is. `terse` and `normal` set voice, and `chat`, `auto` and `html` set surface. Words combine, as in `/kern:mode html terse`. `default` resets both fields to the settings defaults.

Storage: `${CLAUDE_PLUGIN_DATA}/sessions/<session_id>.state`, flat `key: value` lines keyed by the `session_id` from the hook's stdin. State survives compaction and resume. Startup and `/clear` reset to `mode.voice` and `mode.surface`. A headless session (`CLAUDE_CODE_ENTRYPOINT` starting `sdk-`: `claude -p`, the Agent SDK) resets to `mode.voice.headless` instead, `normal` by default, because such a session is often a probe or an eval that parses the reply. Otherwise a session gets the default state only when it has no state file: a state file that exists is never reset, even when a read of it fails, and a read that fails reads as autopilot off for that call. The one exception is turning autopilot off: when the state cannot be read to keep its other keys, `/kern:autopilot off` and "stop autopilot" write the default state, so the off always lands.

### 6.2 Switching

- The slash skill `mode` (and `autopilot`) has `disable-model-invocation: true`, so only the user can type it. A hook reads the command and writes the state. Primary signal: `UserPromptExpansion`, which fires only when a user-typed command expands and carries `command_name`, `command_args` and `command_source`. Whether it fires for a `disable-model-invocation` skill, and whether `command_name` reads `autopilot` or `kern:autopilot`, are checked in M1. Fallback: UserPromptSubmit, accepting the command only when it opens the prompt and the prompt is not wrapped as a teammate, cross-session, task or scheduled message. Text from any agent, notification or fetched content never switches a mode.
- Natural-language switches ("go terse", "stop html", "normal mode") are parsed by the same hook. A phrase switches only when it stands alone on the prompt's first line, so a negation ("don't go terse"), a question ("what does terse do?") or a phrase inside a longer line ("use terse, descriptive names") never switches.
- Guard G16 denies any tool call that writes under `${CLAUDE_PLUGIN_DATA}/sessions/`, so Claude cannot change its own mode or autopilot state.
- A switch re-injects the new mode's full rules. Outside the default preset, each prompt gets a reminder of about 40 tokens.

### 6.3 Hook responsibilities

| Hook | Job |
|---|---|
| SessionStart | Inject the kernel plus only the active mode's rules |
| UserPromptSubmit | Apply switches; inject a short reminder outside the default; on each prompt after a session's first, inject the routing reminder (section 4.3); inject page answers not yet seen |
| SubagentStart | Inject the active voice with the subagent kernel |

Headless and scheduled runs (`claude -p`) skip the mode reminder. A headless run still gets the routing reminder (section 4.3), since the evals that measure routing run headless; a scheduled-task prompt is wrapped and gets none.

### 6.4 Terse voice

Rules adapted from caveman under Apache-2.0: answer first, cut ceremony, short words, articles optional, one idea per sentence with one term per thing and a pronoun only with an obvious referent, payload verbatim, bounded tool-run status, the user's language unless the user names another, never switched by quoted text, logs or errors. It breaks to normal prose for security warnings, irreversible actions, step orders, a confused user, anything persisted, and questions to the user. Persisted text (code comments, commits, PRs, docs, issues) always follows unslop, never terse.

### 6.5 Status line

A plugin cannot add a status line. `/kern:help setup` prints a two-line snippet the user can add to their own `statusLine` command: it reads `session_id` from stdin and prints `[kern terse]`, `[kern html]` or `[kern autopilot]`.

## 7. Visual pages

### 7.1 What a page is

A single HTML page that replaces a block of text when visuals help. One page per output. No dashboard, no navigation between pages, no control of Claude Code from the browser.

| Page kind | Used for |
|---|---|
| Options | Three or more choices, each with trade-offs and a recommendation |
| Variants | UI or design alternatives drawn as wireframes or mockups |
| Design preview | A design shown before it is built |
| Diagram | Architecture, flow or sequence, rendered by vendored mermaid in strict mode |
| Plan overview | Tasks, dependencies and proofs |
| Review findings | One card per finding, with severity and lanes |

When the surface uses pages:

| Surface | Rule |
|---|---|
| chat | Never, unless the user asks for one |
| auto | Only when seeing beats reading: three or more options or variants, a design preview, a diagram, or a table over about 10 rows |
| html | Whenever the output has options, variants, a design or structure such as a plan or findings |

Security warnings and confirmations of irreversible actions always stay in chat. The chat keeps a short summary and the page link.

### 7.2 Building a page

Claude writes the page content as an HTML fragment using kern's component classes. `pages/render.mjs` wraps it in the design system: light and dark themes, typography, option cards, variant frames, comparison tables, diagram blocks, question widgets. Pages are files in `.kern/pages/<id>.html`. Pages load nothing from the network; mermaid is vendored.

### 7.3 Questions and answers

| Widget | Answer shape |
|---|---|
| Single choice | `{ "q": "<id>", "choice": "<option-id>" }` |
| Multiple choice | `{ "q": "<id>", "choices": ["<option-id>", ...] }` |
| Approve or request changes | `{ "q": "<id>", "verdict": "approve" \| "changes", "note": "..." }` |
| Free text note | `{ "q": "<id>", "note": "..." }` |

Every page with a question has a "Send to Claude" button and the line "or type your answer in the terminal". Answers are stored as `.kern/pages/<id>.answers.json`.

### 7.4 The answer path

1. Claude runs `kern-page publish <fragment>`. It renders the page, starts the page server if it is not running, and opens the browser on first use.
2. Claude runs `kern-page wait <id>` as a background command (`run_in_background`) and ends its turn, telling the user to answer on the page or in the terminal.
3. On Send, the server stores the answer and `kern-page wait` exits printing the answer as JSON. Claude Code resumes Claude when the background command ends, and Claude continues with the answer.
4. If the user types in the terminal instead, Claude stops the wait command, uses the typed answer, and records it to the page as "answered in the terminal".
5. If neither happens, the page stays open. The UserPromptSubmit hook passes in any answer stored but not yet seen, so a later click is never lost.

### 7.5 The page server

- Started on demand by `kern-page publish` when a page has a question. Pages without questions open as files.
- Adapted from superpowers' visual companion server (MIT). Its tracking image request is removed, and the choice-field mismatch is fixed (`helper.js:163` sends `value` while `server.cjs:513` stores only `choice`).
- Binds 127.0.0.1 only. Every URL carries a 256-bit key; requests without it get 403. Strict Content-Security-Policy; no external requests.
- Stops after 30 idle minutes or when the owning Claude Code process exits.
- Fallback: with no Node, or in an SSH session with no local browser, the page opens as a static file and the question is answered in the terminal.

## 8. Safety

### 8.1 Defaults

| ID | Default | Under autopilot |
|---|---|---|
| D1 | No commits unless the user asks | Commits allowed when the message passes the convention and attribution checks; `git add -A` denied |
| D2 | No push, PR, tracker write, deploy or external write without approval | Push the current non-protected branch; open a draft PR after a dedup check; `--force-with-lease` only with `rebase.push: autopilot`; everything else denied |
| D3 | Never checkout, switch, reset --hard, stash, bisect or clean in the main checkout. No two writers share a worktree at the same time: serial tasks use the plan's worktree one writer at a time; parallel tasks each get a fork | Unchanged |
| D4 | Tasks sharing files or a local service run one at a time | Unchanged |
| D5 | Judgment calls go to the user; mechanical decisions are logged and listed | Judgment calls are parked; independent tasks continue |
| D6 | No silent fallbacks; a missing setting is asked for | Unchanged |
| D7 | Stored shapes change by expand/contract | Unchanged |
| D8 | Production and declared read-only systems stay read-only | Unchanged |
| D9 | Touching a file outside the approved plan pauses | Unchanged |
| D10 | Fix loops stop after 3 rounds with a split proposal | Unchanged |
| D11 | New behaviour ships with tests | Unchanged |
| D12 | Secrets are never printed | Unchanged |

Worktrees are created by kern's scripts off a freshly fetched `origin/<base>`, not by the Agent tool's native `isolation: "worktree"`, which bases on the main checkout's HEAD and cannot carry earlier uncommitted work. Per-task review needs no commits: `wt-snap` writes the worktree's state to a tree object through a temporary index, `wt-diff` builds the review package from it, and verdicts key on the tree id. Teardown is always proposed with its commands and runs only on a yes; under autopilot it never runs.

### 8.2 Autopilot

Active only when both hold: settings allow it (`autopilot: allowed`, the default) and the user typed `/kern:autopilot on` in this session. `/kern:autopilot off` or a new session ends it. Under autopilot, any guard that would ask instead allows or denies explicitly, because nobody is there to answer. The floor (section 5.1) is denied outright.

### 8.3 Guards

| Guard | Default | Interactive | Autopilot |
|---|---|---|---|
| G1 git safety | on | In the main checkout, or after `cd`, `--git-dir` or `--work-tree`, switch, checkout, rebase, bisect, pull, `reset --hard`, `--merge` or `--keep`, stash and clean ask. Merge, `gh pr merge`, `branch -D`, `worktree remove --force` and remote branch deletes ask. Push asks, a push to a protected branch included. `push.policy: auto` allows only `git push [-u] <remote> <current-branch>` to an unprotected branch, as the whole call, and `push.policy: deny` denies every push. A plain force push, meaning `--force`, `-f`, a `+` refspec or `--mirror`, is denied. `--force-with-lease` asks when every commit on the pushed branches is the user's, and is denied otherwise. A git alias or extension, and a git write command behind a wrapper, ask | Every ask becomes a deny. Allowed: `git push [-u] <remote> <current-branch>` to an unprotected branch, and `git push --force-with-lease <remote> <current-branch>` to an unprotected branch, only with `rebase.push: autopilot` and only when every commit on it is the user's |
| G2 PR create | on | Non-draft or duplicate PRs denied; under `commit.attribution: none`, a `--body-file` holding Claude Code's footer or an attribution trailer denied; otherwise ask | Draft allowed after dedup; non-draft, an attributed body file and `gh pr ready` denied |
| G3 review posting | on | Self-approval and comments without a taxonomy label denied; posting asks; a Skill call to `code-review` whose raw input contains `--comment` asks; `--fix` in the main checkout asks | All posting denied, including `code-review --comment` |
| G4 untrusted text | on | Shell-interpolated comment bodies denied; a body file is required | Same |
| G5 commit | on | Commit asks; message checked against `commit.convention`; attribution trailers denied; `git add -A` asks | Commit allowed when checks pass; `git add -A` and failing messages denied |
| G6 secrets | on | Staged changes scanned on commit and push (gitleaks when present, else a redacted grep); `never_commit` paths denied | Same |
| G7 floor guard | opt-in | At turn end, advisory: new suppressions, skipped or deleted tests, removed asserts, empty catch, debug prints | On, and blocks ending the turn until resolved |
| G9 to G12 | by skills | Claim checks, fail-then-pass probe, verdict validity by patch-id, CI flake classes | Same |
| G13 protected targets | when set | G13 denies every call that names a `protected_targets` entry unless it proves the call reads. ssh, autossh and plink must run a remote command whose every segment is on a closed read list. `ssh -N` tunnels and `ssh -O` control commands are exempt. A SQL client must run statements G13 proves read-only one by one. scp and rsync may copy only from a target, and sftp may run only read verbs. It denies curl, wget, nc, telnet and the other network clients when they name a target. G13 never votes allow | Same |
| G14 tracker and chat writes | on | Write calls from tracker or chat MCP servers ask, and so do gh issue and label writes. `tracker.policy: auto` allows only the Linear and Notion MCP tools on G14's closed list, with their arguments checked, and gh issue and label writes of a proven shape in this repo. It never covers GitHub MCP writes, deletes or other trackers' MCP writes. Chat messages always ask. `tracker.policy: deny` denies tracker writes | Denied |
| G15 deploy and publish | on | Workflow runs, releases, publishes, terraform, kubectl, helm and pushes to deploy branches ask | Denied |
| G16 mode state | on | Tool writes under the kern session-state directory denied; writes to the kern settings files ask | Same; settings writes denied |
| G17 gh stack | on | `merge` denied (it merges the whole stack without prompting in a non-interactive session; the user runs it). `rebase`, `sync` and navigation denied in the main checkout, allowed in the stack worktree. `sync` and `push` ask. `submit` asks and must use `--auto` without `--open`. `link` and `unstack` ask. `modify` needs a terminal and is denied | `merge`, `link`, `unstack`, `modify` and `submit --open` denied. `sync` and `push` allowed with `rebase.push: autopilot`. `submit --auto` allowed after dedup |
| G18 read-only agents | on | For kern's read-only agents (investigator), Bash commands outside a read-only allowlist (git log, show, blame, diff, grep, ls, cat) are denied. Matches `agent_type` `kern:investigator`, which Claude Code passes to hooks for a subagent's tool calls. If the value differs in practice, the investigator loses Bash and the controller collects history for it | Same |
| G19 local deletes | on (M3) | `rm`, `rmdir`, `unlink` and `find -delete` inside the current worktree or kern's scratch directories pass; any other delete asks | Deletes outside those paths denied |
| G20 approvals | on (M2a) | Writing `status: approved` into a spec or plan needs an `approved:` line that quotes a whole line of the user's last message; a non-answer such as "sounds good" or "your call", or a quote the user never typed, is denied. It covers any Markdown file whose frontmatter sets `status: approved`, not only WORK | Denied |

G8, an edit-time typecheck, was dropped: projects keep their own hooks, which must exit 2 for Claude to see failures.

### 8.4 Hook implementation rules

1. Bash, POSIX tools and git only. `gh`, `jq` and `gitleaks` are used when present, never required.
2. Plugin hooks use exec form with `${CLAUDE_PLUGIN_ROOT}` paths.
3. PreToolUse decisions are returned as `hookSpecificOutput.permissionDecision` (`allow`, `deny`, `ask`) with `permissionDecisionReason`. Claude Code applies the strictest decision across all hooks: deny, then defer, then ask, then allow. An `ask` reason opens with `needs user approval: `, as in `needs user approval: kern G5: commit (message checks pass)`: under `-p` or the SDK Claude Code turns an ask into a denial and the model reads only the reason (Task 16g). A deny reason, and an ask autopilot turns into a deny, opens with `kern`.
4. A hook that cannot parse its input, or cannot load its libraries, returns `ask`, or `deny` under autopilot. It never allows on a parse failure. Without its libraries it cannot read autopilot, so it denies under `bypassPermissions` instead.
5. PostToolUse and Stop warnings exit 2 with the message on stderr, so Claude sees them.
6. The Skill tool's input fields are not documented, so G3 matches `--comment` against the raw `tool_input` text. That check is best effort, backed by the skill's own rule and G3's checks on `gh` posting commands.
7. Each guard has a bats test with allow, ask and deny cases in both modes.
8. No hook, and no script a hook runs, makes a locale change bash must undo: a command pinned to the C locale runs as `env LC_ALL=C cmd`, never under a `local LC_ALL` or an `LC_ALL=C cmd` prefix. Homebrew bash 5.3.15, the `bash` a hook runs on macOS, segfaults now and then when a subshell undoes one while neither `LANG` nor `LC_ALL` is set, which failed reads at random (Tasks 16l and 16m). Each entry hook also exports `LANG=C` first when neither is set, which leaves the locale as it was.

## 9. Skill catalogue

| Group | Skill | Tier | Milestone | Job | Main sources |
|---|---|---|---|---|---|
| Control | mode | slash | M1 | Switch voice and surface | caveman, SP |
| Control | autopilot | slash | M1 | Per-session grant for commits, branch pushes and draft PRs | PS |
| Control | help | slash | M1 | Map of kern; `help setup` writes the settings file | PS, PO |
| Define | define | path | M2 | Clarify, specify, get approval | SP, AD, PO |
| Define | plan | path | M2 | Tasks with files, proofs and blocking edges | SP, PO, AD, PS |
| Define | architect | slash | M5 | Interfaces and structure; scan mode | PS, PO, AD |
| Define | domain-model | path | M5 | Glossary and decision records, on request | PO, AD |
| Define | prototype | path | M5 | Throwaway logic or UI variants in a worktree | PO, PS |
| Define | explain | slash | M5 | How, why, teach, research | PS, PO, AD |
| Define | triage | slash | M5 | Issue intake; every tracker write is a draft | PO |
| Build | execute-plan | path | M2 | Per-task subagents, two-verdict review, ledger | SP, AD, PO |
| Build | parallel-work | path | M2 | Worktree per agent; serialize overlaps | SP, PS |
| Build | implement | path | M2 | Thin slices, test first | SP, PO, AD, PS |
| Build | diagnose | path | M2 | Red command, minimise, hypotheses, three-fix stop | PO, SP, PS |
| Build | expand-contract | auto | M5 | Shape changes that keep old data working | AD, PS |
| Build | build-ui | auto | M5 | UI work, scoped to UI paths | AD, PS |
| Build | perf | slash | M5 | Measure, keep or revert, explain the number | AD, PS |
| Build | refactor | slash | M5 | Pin the contract, subtract first | PS, AD |
| Verify | prove-it | auto | M2 | Evidence before any "done" | SP, PS, AD |
| Verify | self-review | path | M2 | Blast radius, floor guard, built-in code-review at low effort, fresh-context doubt pass | PS, AD |
| Verify | pr-review | slash | M3 | Four parallel lanes, merged and verified | SP, PS, PO, AD, Claude Code built-in |
| Verify | take-feedback | path | M3 | Review comments, CI, rebases, stacks | SP, PS |
| Verify | verify-app | slash | M5 | The project's browser or runtime check | PS, AD |
| Verify | no-comments | slash | M3 | Comment hygiene with comment-sicko | PS |
| Ship | commit | slash | M2 | Message per project convention | AD, SP |
| Ship | finish-branch | slash | M2 | Options menu; draft PR with dedup | SP, PS, PO |
| Ship | ship-check | slash | M5 | Go/no-go, deploy proof, rollback plan | AD, PS |
| Context | recall | auto | M2 | Rebuild state; `recall chat` catches up on the thread | PS |
| Context | handoff | slash | M6 | Pause and hand off cleanly | PO, PS |
| Learning | retro | slash | M6 | Session review, deterministic checks first | PO, SP |
| Learning | correct | slash | M6 | Turn a repeated mistake into a check | PS |
| Learning | decision-log | path | M3 | Decision trail for long or unattended runs | PS |
| Writing | visual | path | M4 | Build a visual page, ask on it, wait for the answer | SP, PO |
| Writing | unslop | path | M1 | Rules for prose others read | PS |
| Writing | technical-writing | path | M1 | Docs, PR bodies, commit messages | PS |
| Writing | plain | slash | M6 | Restate the last answer plainly | PS, PO |
| Framework | write-skill | auto | M6 | Author or edit a skill, rule or agent | SP, PO, AD |
| Framework | skill-eval | slash | M6 | Lint, routing and behavioural evals | AD, PS |

Agents: `implementer` (M2), `task-reviewer` (M2, spec verdict then quality verdict), `investigator` (M2, read-only), `code-reviewer`, `spec-reviewer`, `security-auditor` (M3), `test-engineer`, `perf-auditor` (M5), `comment-sicko` (M3). Reviewers and the investigator get read-only tools. Claude Code ignores `permissionMode`, `hooks`, `mcpServers` and `initialPrompt` in plugin agents, so restrictions come from `tools` and `disallowedTools` plus the plugin's own guards (G18).

## 10. Review and feedback (M3 contract)

### 10.1 pr-review lanes

| Lane | Runs as | Looks for | When |
|---|---|---|---|
| A built-in `code-review` | Main session calls the Skill tool with a target (`main...branch`, PR number, branch or path); it runs as its own background subagent | Correctness bugs; reuse, simplification and efficiency cleanups | When the Claude Code version has it and `review.builtin: on` |
| B code-reviewer agent | Background subagent, read-only | Project review rules, design, readability, test quality, G7 results | Always |
| C spec-reviewer agent | Background subagent, read-only | Conformance to spec and acceptance criteria; quotes the spec | When a spec or issue exists |
| D security-auditor agent | Background subagent, read-only | Auth, tenant scoping, injection, secrets, data exposure | When the diff touches `review.sensitive_paths` |
| E built-in `/security-review` | Skill tool | Security | Only with `review.builtin.security: on` |

Merge: deduplicate by file, line and claim; keep the lanes per finding; a finding raised by two lanes goes in directly; a finding from one lane gets a fail-then-pass probe (G10) by a fresh subagent first, and unproven findings are listed as "plausible". Output uses `review.taxonomy`, and a visual page when the surface calls for it.

Built-in rules: always pass explicit effort and `--max-findings` (both are remembered across runs and sessions); never pass `--comment` (it posts immediately); `--fix` only from take-feedback, in a worktree, after the user picks findings. Round 2 and later: the built-in alone on `<last-reviewed>...HEAD` at `review.builtin.delta_effort`; the spec lane re-runs only if the spec changed. The last-reviewed commit is recorded in `.kern/ledgers/` and as a `<!-- reviewed-head: <sha> -->` marker in any posted review body.

### 10.2 take-feedback modes

| Mode | Does | Ends at |
|---|---|---|
| check | Read-only status: checks, threads, mergeability; `gh stack view --json` for stacks | A report |
| threads (default) | Verify each comment against the code; fix real ones test-first; draft replies with reasons for the rest | Fixes staged, replies drafted; the user approves push and posts |
| ci | Classify a red build before any rerun: one fresh build for a flake; the same failure twice is not a flake; a failure outside the diff means a stale base | Green, a rebase proposal, or a diagnosis |
| rebase | Update a branch or stack, resolve mechanical conflicts, re-verify every layer | Rebased locally; pushing follows G1 and G17 |
| drive | Loop conflicts, rebase, threads, CI until merge-ready, watching with `gh pr checks --watch` in the background; unattended only under autopilot | Merge-ready; never merges |

### 10.3 Stacked PRs

| `stack.tool` | Commands |
|---|---|
| `gh-stack` | `gh stack view --json`; `gh stack rebase` (`--upstack`, `--downstack`, `--continue`, `--abort`); `gh stack sync` (atomic push with `--force-with-lease`); `gh stack submit --auto` (drafts) |
| `git` | `git rebase --update-refs` for the chain; `gh pr edit --base` after a layer merges |
| `none` | `git rebase` onto `base_branch` |

Rules: work the lowest unmerged PR first; fix in the lowest branch that owns the code, then cascade upward. One stack uses one dedicated worktree; no other worktree holds a stack branch; stack commands never run in the main checkout. Mechanical conflicts are resolved; a conflict where both sides changed behaviour aborts the rebase (`--abort` restores every branch) and goes to the user with a conflict report. After a rebase, layers with an unchanged patch-id keep their review verdict; changed layers are re-tested and re-reviewed on the delta. Pushes use `--force-with-lease` only, on the user's own non-protected branches; a branch with another author's commits is shared and never force-pushed.

## 11. Quality system

### 11.1 Tiers

| Tier | Checks | Runs |
|---|---|---|
| 0 Lint | Frontmatter keys, tiers, description limits, references, router coverage, budgets, settings schema, hook output, versions, `claude plugin validate --strict` | Every PR |
| 1 Routing | Descriptions and kernel rows rank the right target; collision check; rank-1 floor that only rises; third-party skills as distractors | Every PR |
| 2 Behavioural | Fires and stays quiet; follows steps; precedence and settings fixtures; kernel adherence; pressure tests; blind A/B | Nightly and on demand, model pinned, versions recorded |
| 3 Scope ledger | A change needs an observed failure and was not rejected before | PR review |

### 11.2 Lint rules

1. Frontmatter present; `name` equals the directory; kebab case.
2. Only Claude Code's frontmatter keys.
3. auto descriptions at most 300 chars and a trigger; path and slash at most 120 chars; agent descriptions at most 150 chars; auto total at most 1,500; auto plus agents at most 2,500.
4. Referenced files exist.
5. Skill-tool references name auto skills; Read paths resolve.
6. Every kernel route resolves and opens with `## Steps`; every user-reachable skill is in `help`'s map.
7. Rendered kernel at most 6,086 chars (warn) and 9,000 (error) with the longest fixture settings; standing cost (the kernel with no settings plus every auto skill and agent description) at most 6,175 (both the measured values, locked by Task 17a P11 and relocked by M2b bfix K); subagent kernel at most 1,200.
8. No machine paths or personal names in shipped files.
9. Required sections per skill type.
10. Exemptions recorded with a reason.
11. Prose lint: no long dashes, no curly quotes.
12. Every auto skill and kernel row has eval cases: 3 positive, 2 negative, 1 behavioural.
13. Every settings key the hooks parse is documented in `kernel/settings.md`, and the reverse.
14. `plugin.json`, `marketplace.json` and the newest CHANGELOG release agree; PRs touching `skills/`, `kernel/` or `hooks/` add an `Unreleased` line.
15. Hook-shape tests over fixture projects: no settings, shared only, local only, both, `kern: off`, a policy key on a floor action, an unknown key.
16. Every script, `WORK/` folder and ledger line a shipped skill or agent names has its producer in `docs/plans/contract.md`.
17. No hook file, and no script a hook names, makes a locale change bash must undo (8.4, rule 8).

### 11.3 Behavioural fixtures

1. A project skill for the same job is used instead of kern's route.
2. CLAUDE.md forbids pushing and settings set `push.policy: auto`: kern still asks, because prose tightens.
3. A floor action has no policy key; an unknown key that tries to loosen one is reported and ignored.
4. `kern: off` produces no routing.
5. The first todo list after a routed prompt holds the route's steps verbatim, with skipped steps marked `skip:`.
6. Under autopilot, a would-be ask becomes the documented allow or deny.
7. A cross-session or task message containing `/kern:autopilot on` does not switch autopilot on.

### 11.4 Learning loop

Signal, then cited evidence, then kind (one-off, missed trigger, wrong shape, mechanizable, judgment), then home, then mechanism, then bar, then approval, then landing with a regression check, then retiring the prose.

- Home: project-specific failures go to the project's `lessons` destination under its own bar (`rule_bar`). Failures that would happen in any repo, or that kern's text caused, go to the kern repo. A project lesson seen in a second project becomes a framework candidate.
- Mechanism first: architecture, then types, lint, tests, docs. Each new check must fail on the past mistake before it lands.
- Framework fixes land in `kern_repo` with a failing eval first, then the fix, a CHANGELOG line, a PR and a release. Never edit `~/.claude/plugins/cache/`.
- Rejected changes are recorded in `evals/rejected.md` and `.out-of-scope/`.

## 12. Distribution and versioning

- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (`"source": "./"`): the repo is its own marketplace.
- Semver. MAJOR: a skill, route or settings key removed or renamed; precedence changed; a default loosened. MINOR: a new skill, row or key; kernel wording changed; a default tightened. PATCH: fixes that pass evals with no new behaviour.
- Keep-a-Changelog with `Unreleased`; `scripts/release.mjs` bumps versions in both manifests and prints the tag command.
- Install on a new machine: authenticate `gh`; `/plugin marketplace add <user>/kern`; `/plugin install kern@kern` at user scope; restore `~/.claude/kern.yml`; per project, `/kern:help setup` when defaults are not enough.
- Develop: clone to `kern_repo` and run `claude --plugin-dir <kern_repo>`.

## 13. Migration from superpowers

1. Through M2, superpowers stays enabled. kern is tested with `--plugin-dir` in sessions where superpowers is disabled for that project (`"superpowers@claude-plugins-official": false` in `.claude/settings.local.json`), so only one router runs.
2. Pilot, in M2b, on two projects (one of them cds-app-rewrite) for at least five real tasks each, covering define, plan, execute, diagnose and finish-branch.
3. Pass criteria: the behavioural fixtures pass; no guard false negative in the pilot; and the side-by-side passes the rule `docs/pilot.md` fixes before its first run. The side-by-side runs the same real tasks twice from one base commit, once with kern 0.3.0 and once with superpowers 7.0.0 plus caveman, both on the personal eval account with only their own plugins. A blind Opus review that never sees plugin names or paths judges the result; the session files give the process (stops for the user, guard asks and denies, safety slips) and the cost (tokens, wall time).
4. Then disable superpowers at user level and uninstall caveman. Move the user's own `~/.claude/skills/recall`, `unslop` and `no-comments` and `~/.claude/agents/comment-sicko.md` aside once kern ships their replacements (recall and unslop at M2, no-comments and comment-sicko at M3), so two descriptions do not compete.
5. Rollback: re-enable superpowers in `~/.claude/settings.json`; disable kern with `kern: off` or by uninstalling.

## 14. Milestones

| ID | Scope | Hours | Acceptance |
|---|---|---|---|
| M0 | Repo, manifests, LICENSE, NOTICE, licenses/, UPSTREAM.md, lint and routing-eval scripts adapted from addy, CI | 4 to 6 | `claude plugin validate --strict` passes; CI runs lint and routing evals on an empty skill set with a placeholder skill |
| M1 | Kernel and subagent kernel; SessionStart, SubagentStart, UserPromptSubmit hooks; settings parsing; `mode`, `autopilot`, `help` with `help setup`; terse voice; unslop and technical-writing references; guards G1 to G6 and G13 to G16 | 10 to 14 | Hook-shape tests pass on all fixtures; rendered kernel under 4,000 chars; mode switches survive compaction; G16 denies a state write; each guard's bats tests pass in both modes |
| M2a | define, plan, execute-plan, parallel-work, implement, diagnose, prove-it, self-review, commit, finish-branch, recall; agents implementer, task-reviewer, investigator; worktree scripts (`wt-new`, `wt-fork`, `wt-snap`, `wt-diff`, `wt-apply`, `wt-audit`); check scripts G7 (as a script), G9, G10 and `plan-check`; ledger and brief scripts that enforce review, approval and plan identity in code; guards G18 and G20 (approvals quote the user); shell-snapshot aliases judged as the git or gh command they expand to; coverage gaps 5 to 19 except 10 and 13; the goal-0 plan review items for the build | 37 to 40 | Each skill's unit and execution tests pass, including commit and finish-branch against a `gh` shim; per-task review works with no commits and `task-done` refuses an unreviewed tree; floor-scan and the review seeded-diff set pass in CI; release 0.3.0 |
| M2b | Proof of goal 0 for M2, planned 2026-10-14 and pre-flighted 2026-10-17 (`docs/plans/2026-10-14-kern-m2b-plan.md`). First the rows the 2026-10-17 re-audit found a source now beats (coverage gaps 35 to 39, 41 to 43, 45 to 52: define, plan, self-review, diagnose, recall chat, subagent effort, plan-check fences, task-done, the terse clauses and the headless voice). Then the behavioural eval runner and kernel-adherence grader with host isolation, negative cases and committed snapshots (coverage gaps 10 and 13); head-to-head evals for planning, debugging and review against superpowers, pstack, pocock and a no-plugin control on seeded fixtures with hidden answer keys (gap 48); the coverage re-audit of M2 rows; a release-time token measurement; the pilot: the same real tasks side by side with kern 0.3.0 and with superpowers 7.0.0 plus caveman on the personal eval account, judged blind, then the solo pilot | about 25 | In each head-to-head category kern finds at least as many key items as the strongest arm, with no more false alarms; no M2 coverage row is left where a source is stronger; standing cost within goal 4; pilot criteria in section 13 met; release 0.4.0 |
| M3 | pr-review lanes, take-feedback with five modes and stack providers, G17, the G7 Stop hook, scripts G11 and G12, no-comments and comment-sicko, security references, decision-log (moved from M6), guard G19; the M1 parser deferrals (one parse per command, case patterns holding `$`, one git option parser, test-suite cost; `$((` read as arithmetic shipped in 0.4.0); the Task 7a reader deferrals — a string a builtin evaluates as arithmetic or a subscript (`let`, `declare -i`, `typeset -i`, `local -i`, `printf -v`, `read`, `[[ ... -eq ... ]]`) with a `$( )` or backtick in single quotes gets no guard vote outside autopilot, where G00 denies it; an array subscript that opens with a substitution (`[$(` or `` [` `` after a name) and is evaluated later by arithmetic (`x='a[$(cmd)]'; echo $((x))`, or an assignment to a `declare -i` variable) runs in bash: one written in the command is denied by G00 under autopilot, whether in single quotes, `$'...'` or a here-doc body, and gets no guard vote outside autopilot; one built or read at run time (by concatenation such as `x='a['; x+='$(cmd)'; x+=']'`, from another command's output, or from a file) and then evaluated reaches no guard in either mode, and waits for M3's one parse per command; and a zsh glob qualifier `*(e:'...':)` holding a plain command runs code in zsh only, needs a matching glob and reaches no guard in either mode (one holding a `$( )` or backtick is denied under autopilot as a command name built at run time); coverage gaps 20 to 26; starts with a one-hour gh-stack worktree spike | 11 to 17 | Spike result recorded; lanes merge correctly on a seeded diff and find at least as many seeded bugs as the strongest source review, with no more false alarms; stack rebase on a fixture stack restores cleanly on `--abort` |
| M4 | visual: renderer, components, page server, `kern-page publish/wait/stop`, answers in hook, static fallback, auto thresholds | 10 to 14 | Send on a page resumes Claude with the answer; a terminal answer cancels the wait; pages make no network requests |
| M5 | Specialists and stack references; coverage gaps 27 to 31 | 14 to 20 | Each skill's eval cases pass |
| M6 | handoff, retro, correct, plain, write-skill, skill-eval; nightly behavioural evals with a host version comparison (caveman C35); coverage gaps 32 to 34 | 10 to 14 | Nightly run green for a week |

M2b's behaviour and exec gates, as the user set them on 2026-10-21 (plan Task 16's gates table, from `task-16-diagnosis-3`):
- A behaviour case passes on two of three valid runs, with at most one invalid.
- The user's "Adopt the stopping rule": a case blocks only when, read on its transcripts, a kern defect fails it in two or more of three runs in two measurements in a row. A grader flip or a case-wording fault stops blocking once its fix lands. A kern duty that two wording rounds did not move gets one structural change. A fix is confirmed by one full run, since a re-run of only the failing cases regresses toward the mean.
- The same answer for the exec evals: a run whose failure is traced to a cause outside kern's text and code is marked invalid by the harness, with its reason, and does not block.
- The user's "Scripted checks + one model": a mechanical expectation (a file read, a command run, a line said) is decided by code, and the rest by one model verdict per run, as before. There is no extra grader cost. Scripted today: recall-1's and recall-2's state check, ledger read and no-write expectations, the `Skipped:` line in four pressure cases, and the `Building:` line in pressure-define-skip-approval and workflow-define-fast-path. `docs/plans/contract.md` lists each one.
- The user's "Known limit, report only": a duty still under two of three after its structural change is reported, not gating. This applies to the `Building:` line if it is still under two of three after Task 16k.

M2b's confirming run (2026-10-22 and 2026-10-23, under plan Task 16 Step 6's exit rule and the user's "One run, one harness rerun") passed every gate except two head-to-head categories, plan and review. No failure was a harness defect, so there was no rerun. The user then chose one fix round, "Fix round first" (plan Task 16q): plan names its scope limit's source, self-review clears behaviour-keeping lines and skips no step on a no-edit request, and the grader's digest keeps the evidence it cut. Its one rerun passed plan and failed review on false alarms alone. After Task 17's coverage fixes, one full round at 155cbad (2026-10-23, the user's "do a full run before starting task 18") passed every gate, all three head-to-head categories included. The known limits, each with its numbers in the CHANGELOG evidence line:
- prove-it-2: a root cause read from the code is stated without an `inferred` label (0 of 3, new in that round).
- The `Building:` line, and Sonnet's multi-diagnose second route read.
- recall-1's grader fault.
The section's acceptance for M2b asks every head-to-head category to pass, and the post-Task-17 round meets it. Whether 0.4.0 ships with these limits is the user's decision at plan Task 19.

Elsewhere in this spec, "M2" means M2a and M2b together. The first build is M0 to M2b (about 69 to 78 hours), with the pilot inside M2b. The full framework is about 114 to 143 hours.

## 15. Risks and spikes

| Risk | Check | When |
|---|---|---|
| `gh stack rebase` and `sync` misbehave in a linked worktree | One-hour spike on a throwaway repo | Start of M3 |
| Background-wait resume does not hand the answer back reliably | Spike in a throwaway session | Start of M4 |
| G3 cannot see `--comment` in the Skill tool input | Inspect a real PreToolUse payload for a Skill call | M3 |
| SubagentStart output field or cap differs from SessionStart | Inspect a real payload | M1 |
| `ask` behaviour under bypassPermissions mode is undocumented | Test G1 under that mode | M1 |
| `UserPromptExpansion` skips `disable-model-invocation` skills or names them `kern:<skill>`; UserPromptSubmit fires on turns Claude Code starts itself (documented, not listed) | Inspect real payloads for a typed command, a teammate message and a task notification | M1 |
| `agent_type` for a plugin agent is not exactly `kern:investigator` | Inspect a PreToolUse payload from the investigator | M2 |
| Description routing misses path-tier skills when the kernel is ignored | Kernel adherence fixture; routing evals | M2 |
| gh-stack is v0.1.1 and may change its commands | Pin the version in docs; G17 tests per command | M3 |
| Upstream fixes are lost after the fork | `UPSTREAM.md` and a quarterly diff | After M2 |

## 16. Out of scope for this spec

- Team rollout and shared settings conventions.
- Graphite or git-spice stack adapters.
- Hosted visual pages (claude.ai artifacts).
- Non-Claude models and other coding tools.
