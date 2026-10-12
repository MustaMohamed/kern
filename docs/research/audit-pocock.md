# Audit: mattpocock/skills for cds-app-rewrite

Candidate clone: `scratchpad/repos/pocock/skills`, HEAD `49dd158` (shallow, one commit, 2026-10-09). All `path:line` refs without a repo prefix are inside that clone. Target-repo refs are prefixed `cds:`. Nothing from the candidate was executed; files were read only.

Verdict: do not adopt the framework. Cherry-pick 6 to 8 skills as vendored, edited copies in `cds:.claude/skills/`. The core flow (`implement`, `implement-spec`, `to-spec`, `wayfinder`, `code-review`) duplicates superpowers and breaks the outward-action gate, the shared-tree rule and the Linear-first workflow in ways that need a fork to fix. The plugin install is read-only, so a fork is the only way to fix them.

## Scores

| # | Criterion | Score | One-line reason |
|---|---|---|---|
| 1 | Claude Code compatibility | 4/5 | Native plugin in `claude-plugins-official`; bare-name Skill calls collide with the built-in `code-review`; plugin is read-only so edits need a fork or vendored copies |
| 2 | Lifecycle coverage | 4/5 | Clarify, spec, tickets, implement, TDD, debug, review, PR body, retro, triage, parallel build all present; no verification gate, no review-feedback loop, no deploy; Linear only via free-text "Other" |
| 3 | Systematic-ness | 3/5 | One documented chain plus a router (`ask-matt`), but the router cannot fire skills and user-invoked skills cannot call each other; the human is the dispatcher by design |
| 4 | Rigor / quality mechanisms | 3/5 | `diagnosing-bugs` and `tdd` carry strong evidence gates; no evals, CI checks nothing about skills, and the docs admit open bugs in `implement` and `implement-spec` |
| 5 | Fit with project rules | 2/5 | `implement` commits to the current branch, `implement-spec` opens/readies PRs and closes tickets, `wayfinder` pushes branches, `code-review` always fans out; Linear is out of scope |
| 6 | Overlap with installed (5 = additive) | 2/5 | 12 of 27 shipped skills duplicate a superpowers or project skill; the additive ones are mostly peripheral |
| 7 | Context / token cost | 4/5 | ~2.5k chars always loaded (11 model-invoked descriptions); flows are expensive at runtime (2 subagents per review, N implementers + mergers per spec) |
| 8 | Safety / risk | 3/5 | No hooks, no telemetry; but model-invoked skills write repo files and commit branches, `setup` edits CLAUDE.md, `wizard` writes GitHub secrets |
| 9 | Maintenance / maturity | 4/5 | v1.3.1, changesets, CHANGELOG, MIT, explicit scope policy, ADRs; no tests, breaking renames each minor, single maintainer, Linear explicitly unsupported |

## Skill inventory

Status: shipped = listed in `.claude-plugin/plugin.json:21-49`. Bytes = `SKILL.md` / whole dir excluding `agents/openai.yaml`. Inv = U (user-invoked, `disable-model-invocation: true`) or M (model-invoked). CC-ready: Y runs in Claude Code and is safe here as written; needs-edit runs but must be edited before use in this repo; N not usable here.

| Skill | Status | Inv | Phase | Purpose | Bytes | CC-ready |
|---|---|---|---|---|---|---|
| ask-matt | shipped | U | router | Map of flows over this repo's skills | 12594 / 16843 | Y (useless without the set) |
| grill-with-docs | shipped | U | clarify | Calls `grilling` + `domain-modeling` | 247 / 247 | needs-edit (writes GLOSSARY/ADR) |
| triage | shipped | U | issue tracker | Label state machine, agent briefs, `.out-of-scope/` KB | 6558 / 19167 | N (GitHub labels, AI disclaimer) |
| improve-codebase-architecture | shipped | U | design / health | Deepening candidates as HTML report in `$TMPDIR`, then grill | 6000 / 12641 | Y (writes via domain-modeling only on grill) |
| setup-matt-pocock-skills | shipped | U | setup | Writes tracker/labels/domain docs + CLAUDE.md block | 6978 / 19820 | N (Linear unsupported, edits CLAUDE.md) |
| to-spec | shipped | U | spec | Synthesize conversation into a spec, publish to tracker | 3043 / 3043 | needs-edit |
| to-tickets | shipped | U | plan | Tracer-bullet tickets with blocking edges, published | 5812 / 5812 | needs-edit (Linear mapping) |
| implement | shipped | U | implement | tdd at seams, code-review, commit to current branch | 622 / 622 | N |
| implement-spec | shipped | U | implement, parallel | Task-graph build on integration branch via worktree subagents | 2780 / 2780 | N |
| wayfinder | shipped | U | plan (multi-session) | Decision-ticket map on tracker | 12380 / 12380 | N |
| retro | shipped | U | learning | Suggest environment improvements after a session | 4369 / 4369 | needs-edit |
| prototype | shipped | M | design | Throwaway logic HTML or `?variant=` UI variants | 2931 / 15880 | needs-edit (branch commits) |
| diagnosing-bugs | shipped | M | debug | Tight red loop, minimise, ranked hypotheses, regression test | 8664 / 9980 | needs-edit (Playwright item) |
| research | shipped | M | research | Background agent writes cited md into repo | 794 / 794 | needs-edit |
| tdd | shipped | M | TDD | Seams confirmed with user, red-green, anti-patterns | 3629 / 7324 | needs-edit (conflicts superpowers TDD) |
| domain-modeling | shipped | M | clarify / docs | Challenge terms, write GLOSSARY.md and ADRs inline | 3346 / 8379 | needs-edit |
| codebase-design | shipped | M | design | Deep-module vocabulary, deletion test, design-it-twice | 6446 / 11664 | Y |
| code-review | shipped | M | review | Standards + Spec axes in two parallel subagents | 6670 / 6670 | N (name collision, fan-out) |
| pr | shipped | M | ship | PR body: visual summary, before/after evidence, merge danger | 4169 / 4773 | needs-edit (merge into project PR template) |
| wizard | shipped | M | ops | Generate bash wizard; writes `.env`, `gh secret set` | 4123 / 13621 | needs-edit |
| grill-me | shipped | U | clarify | Calls `grilling` | 157 / 157 | Y |
| grilling | shipped | M | clarify | Frontier-batched interview with recommended answers | 2049 / 2049 | needs-edit (conflicts brainstorming) |
| handoff | shipped | U | context | Handoff doc to `$TMPDIR` | 940 / 940 | Y |
| teach | shipped | U | learning | Stateful teaching workspace in cwd | 9733 / 18066 | Y (off-topic) |
| to-questionnaire | shipped | U | clarify | Questionnaire md for a third party | 2904 / 2904 | needs-edit (writes to cwd) |
| wait-what | shipped | U | comms | Re-pitch last message in plain English | 396 / 396 | Y |
| writing-for-agents | shipped | M | meta | Reference for skills / CLAUDE.md authoring | 10886 / 13515 | Y |
| chief-of-staff | in-progress | U | orchestration | Long-running goal via subagents and schedules | 2112 | N |
| claude-handoff | in-progress | U | context | `claude --bg` seeded with handoff | 1424 | N |
| loop-me | in-progress | U | personal | Workflow-spec grilling | 2522 | N |
| setup-ts-deep-modules | in-progress | U | setup | Install dependency-cruiser entry-point rules | 7546 / 11258 | N |
| writing-beats / -fragments / -shape | in-progress | U | writing | Article writing | 4855 / 3558 / 5922 | N |
| git-guardrails-claude-code | misc (frozen) | M | safety | PreToolUse hook blocking dangerous git | 2313 / 2820 | N |
| migrate-to-shoehorn | misc (frozen) | M | refactor | `as` to shoehorn in tests | 2795 | N |
| scaffold-exercises | misc (frozen) | M | course | Exercise dirs | 3589 | N |
| setup-pre-commit | misc (frozen) | M | setup | Husky + lint-staged, auto-commits | 2258 | N |

`skills/deprecated/` is empty (`skills/deprecated/README.md:3`). Shipped: 27 (11 M, 16 U). In-progress and misc are excluded from the plugin (`CLAUDE.md:9`, `skills/in-progress/README.md:3`).

## 1. Claude Code compatibility: 4/5

- Native plugin. `.claude-plugin/plugin.json:1-50` lists 27 skill dirs; `.claude-plugin/marketplace.json` is a fallback. Install: `claude plugin install mattpocock-skills@claude-plugins-official` (`README.md:35`).
- Listed in the official marketplace on this machine with a pinned sha: `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json` entry `mattpocock-skills`, `sha c55ee46...`. The audited clone is `49dd158`. The pin lags HEAD by design (`.agents/adr/0002-ship-as-a-claude-code-plugin.md:40`), so the installed content can differ from what this audit read. Not verified which pending changesets the pin includes.
- Non-Claude constructs: every skill has `agents/openai.yaml` (Codex metadata, `.agents/invocation.md:10`). Claude Code ignores it. Cross-skill calls use "Call the Skill tool with ..." (`.agents/invocation.md:16`), which matches Claude Code.
- Name collision. This session already has a built-in `code-review` skill and `engineering:code-review`. `implement/SKILL.md:15` and `implement-spec/SKILL.md:36` say `Call the Skill tool with "code-review"` by bare name, which can resolve to the built-in instead of `mattpocock-skills:code-review`. Upstream refuses to rename (`.out-of-scope/harness-name-collisions.md:3`, prior reports #423, #483 at `:24-25`). Behaviour not executed here; flagged as likely.
- Read-only plugin. Any edit for Linear or the gates means vendoring copies via skills.sh or by hand, and installing both duplicates every skill (`.agents/install-block.md:121`).

## 2. Lifecycle coverage: 4/5

| Phase | Skill | Notes |
|---|---|---|
| Clarify / discover | grilling, grill-me, grill-with-docs, to-questionnaire, wait-what, research | `grilling/SKILL.md:8` batches the whole frontier per round |
| Spec / plan / design | to-spec, to-tickets, wayfinder, prototype, codebase-design, improve-codebase-architecture | `to-tickets/SKILL.md:40` expand-contract for wide refactors |
| Implement | implement, implement-spec | `implement/SKILL.md:7-17` is 6 lines |
| TDD | tdd | seams confirmed first, `tdd/SKILL.md:22` |
| Debug / root cause | diagnosing-bugs | 6 gated phases |
| Code review | code-review | Standards + Spec axes |
| Verification / proof | partial: diagnosing-bugs Phase 1/6 checklists, implement typecheck/tests (`implement/SKILL.md:13`), pr Evidence | no standalone "evidence before claiming done" gate |
| Ship / PR | pr (body only); implement commits; implement-spec drafts PR | no push/merge/branch-finish flow |
| Learning / retro | retro | read-only, presents candidates |
| Issue tracker | setup-matt-pocock-skills, triage, to-spec, to-tickets, wayfinder | GitHub, GitLab, local md only |
| Parallel / multi-agent | implement-spec, wayfinder research subagents, code-review, codebase-design design-it-twice | |

Linear: out of scope. `.out-of-scope/mainstream-issue-trackers-only.md:9` "Requests to add a first-class backend for any other tracker are out of scope. That includes Jira, Linear, ...". The only path is `setup-matt-pocock-skills/SKILL.md:47` "Other (Jira, Linear, etc.): ask the user to describe the workflow in one paragraph; the skill will record it as freeform prose", stored in `docs/agents/issue-tracker.md` (`:49`). Wayfinder, to-tickets and triage then follow prose for sub-issues, blocking edges, labels and frontier queries, which the GitHub template spells out as exact commands (`setup-matt-pocock-skills/issue-tracker-github.md:39-46`).

Missing: security review, receiving/resolving review comments, deploy/release, browser verification.

## 3. Systematic-ness: 3/5

Intended pipeline (`ask-matt/SKILL.md:15-34`, `docs/engineering/implement.md:90`):

```
grill-with-docs → [handoff → prototype → handoff] → to-spec → to-tickets
  → implement (per ticket, /clear between) | implement-spec (whole graph)
  → tdd inside → code-review → pr → retro
on-ramps: triage, diagnosing-bugs, wayfinder (merges at to-spec)
precondition: setup-matt-pocock-skills
```

- One router, `ask-matt`, but it only hints. User-invoked skills "can never reach another user-invoked skill" (`.agents/invocation.md:8`), so each step needs the human to type it. This is deliberate: `README.md:17-19` positions the set against process-owning frameworks (GSD, BMAD, Spec-Kit).
- Gates exist inside skills, not between them: tdd seam confirmation (`tdd/SKILL.md:22`), to-tickets approval loop (`to-tickets/SKILL.md:56`), diagnosing-bugs "No red-capable command, no Phase 2" (`diagnosing-bugs/SKILL.md:66`), grilling "Do not act on it until the user confirms" (`grilling/SKILL.md:30`).
- Context hygiene is specified (`ask-matt/SKILL.md:36-40`, `PHASE-BOUNDARIES.md:17-40`).
- No gate between implement and ship: `implement` ends at a commit with no verification step that must show output.

## 4. Rigor / quality mechanisms: 3/5

Strong:
- `diagnosing-bugs/SKILL.md:59-66` Phase 1 done only when one command "you have already run at least once" is red-capable, deterministic, fast, agent-runnable. `:125` diff a forced mutation against a pristine copy. `:134-138` cleanup checklist incl. grep of tagged debug logs.
- `tdd/SKILL.md:31` tautological-test anti-pattern; `tdd/tests.md:63-77` example.
- `code-review/SKILL.md:78-80` keeps Standards and Spec axes unmerged; spec axis quotes the spec line per finding (`:72`).
- `pr/SKILL.md:158-164` before/after evidence, screenshots top tier. `:166-170` one-way/two-way door and blast radius.
- `retro/SKILL.md:19` mechanical violations become deterministic checks, judgement calls go to standards.

Weak:
- No evals. `docs/productivity/writing-for-agents.md:47` "There is no automated eval." No test files in the repo.
- CI covers release and issue labelling only: `.github/workflows/release.yml`, `needs-info.yml`, `triage-label.yml`. Manifest validation is manual (`CLAUDE.md:11` "Run `claude plugin validate . --strict` after touching either manifest"); `npm run check-plugin-version` exists (`package.json:14`) but no workflow runs it.
- Open bugs documented in its own docs:
  - `docs/engineering/implement.md:63-65`: `code-review` diffs `<fixed-point>...HEAD`, and `implement` runs it before committing, so the review can see nothing. "Multiple people have reported this and it is unfixed on both sides."
  - `docs/engineering/implement-spec.md:48`: review/fix loop has no stop condition; a five-ticket feature took "roughly four hours".
  - `docs/engineering/implement-spec.md:56`: parallel implementers collide on shared files; blocking edges are "a guess".
  - `docs/engineering/implement-spec.md:66`: tests reading gitignored fixtures silently skip in worktrees and report green. This repo's worktrees lack `node_modules` and root `.env` (`cds:.claude/rules/6-operations/ports-and-local-artifacts.md:53,95`), so this applies directly.
- No subagent recursion guard by policy (`.out-of-scope/subagent-recursion.md:3`; #573 was code-review recursing at `:14`).

## 5. Fit with project rules: 2/5

Conflicts, candidate line vs project line:

| Candidate | Quote | Project rule it breaks |
|---|---|---|
| `implement/SKILL.md:17` | "Commit your work to the current branch." | `cds:.claude/rules/3-workflow/git-branch-and-commit-safety.md:58` "Commit or push only when the user asks."; `cds:CLAUDE.md:95` commit prefix `CDS-XXX:` not specified by the skill; primary checkout is on `main` today (`git rev-parse --abbrev-ref HEAD` = `main`), `cds:CLAUDE.md:99` main is protected. `docs/engineering/implement.md:27` "It does not create one, and it does not ask." |
| `implement-spec/SKILL.md:25` | "open a draft PR after the first merge in step 5 ... marked as closing the spec and tickets" | `cds:.claude/rules/3-workflow/multi-agent-orchestration.md:27,32` no autonomous "opening / pushing a PR"; `cds:.claude/rules/3-workflow/git-branch-and-commit-safety.md:65` "Don't proactively suggest branches/PRs" |
| `implement-spec/SKILL.md:38` | "If a draft PR exists, mark it ready for review. Otherwise, resolve each ticket the way the issue tracker closes work" | `multi-agent-orchestration.md:33` "moving a Linear status" is gated; `:164` status change is Require-approval |
| `implement-spec/SKILL.md:13,34` | frontier tickets run in parallel "for maximum concurrency" | `multi-agent-orchestration.md:51` "File-overlap = serialize"; candidate's own docs concede collisions (`docs/engineering/implement-spec.md:56`) |
| `implement-spec/SKILL.md:21-27` | read spec, spawn implementers | `multi-agent-orchestration.md:59-61` Verify-before-implement against `origin/main` and the deploy branch; no such step |
| `implement-spec/SKILL.md:25` | "Create the integration branch." | `cds:CLAUDE.md:40` no `git checkout`/`switch` in the shared tree; skill does not say to use a worktree for the integration branch itself; no `origin/<base>` freshness (`git-branch-and-commit-safety.md:14`) |
| `wayfinder/SKILL.md:115` | "Push the branch but open no PR" | `git-branch-and-commit-safety.md:58`; `multi-agent-orchestration.md:32` |
| `wayfinder/SKILL.md:123-125` | claim = assign; resolve = comment, close issue | `multi-agent-orchestration.md:33`; comment sprawl vs `:82` "One consolidated comment per ticket" |
| `prototype/SKILL.md:26` (model-invoked) | "commit it to a throwaway branch, out of main" | `cds:CLAUDE.md:40` shared tree; branch naming `git-branch-and-commit-safety.md:6` and user memory `branch-naming-slash` (`CDS-XXXX/name`) |
| `to-spec/SKILL.md:19` | "Write the spec ... then publish it to the project issue tracker. Apply the `ready-for-agent` triage label" | No draft-review step before publishing; `multi-agent-orchestration.md:27` prepare-then-commit |
| `to-tickets/SKILL.md:63` | "Apply the `ready-for-agent` triage label unless instructed otherwise" | Linear uses statuses, not triage labels; label vocabulary does not exist in the CDS workspace |
| `triage/SKILL.md:13-17` | every comment "must start with this disclaimer: > *This was generated by AI during triage.*" | `cds:CLAUDE.md:97` "No co-author / AI-attribution tags unless explicitly requested" (stated for commits; tension for tracker text) |
| `code-review/SKILL.md:11,58-60` | "Both axes run as parallel sub-agents" every run | `multi-agent-orchestration.md:134` "Round 1: fan out. Round ≥2: `pr-review` alone."; `:139` prefer deterministic checks |
| `code-review/SKILL.md:21` | `git diff <fixed-point>...HEAD` | `multi-agent-orchestration.md:136` scope round ≥2 to `<last-reviewed-sha>..HEAD`; `git-branch-and-commit-safety.md:14` local `main` is stale, must be `origin/<base>` |
| `code-review/SKILL.md:76-78` | report under `## Standards` / `## Spec` | `cds:.claude/rules/3-workflow/pr-review-conventions.md:5` findings inline on `file:line` as Bug/Suggestion/Nit |
| `diagnosing-bugs/SKILL.md:29` | "Headless browser script (Playwright / Puppeteer) that drives the UI" | `cds:.claude/rules/6-operations/browser-verification.md:13-15` harness is `scripts/cds-session.mjs`; `ports-and-local-artifacts.md:74` "Still do not hand-roll a Playwright login" |
| `domain-modeling/SKILL.md:62` (model-invoked) | "update `GLOSSARY.md` right there. Don't batch these up" | `cds:.claude/rules/2-engineering/minimal-change-discipline.md:3-5` no unrelated files, 3-4 file gate |
| `setup-matt-pocock-skills/SKILL.md:76-82` | "If `CLAUDE.md` exists, edit it." adds `## Agent skills` block | `cds:CLAUDE.md` is team-shared and checked in; the change needs its own PR and adds always-loaded lines on top of ~22k tokens (`cds:.claude/rules/README.md:10`) |
| `setup-matt-pocock-skills/SKILL.md:61` | offer multi-context `GLOSSARY-MAP.md` on monorepo signals | `cds:package.json:29` has `workspaces`, so setup would propose per-package `GLOSSARY.md` files |
| `retro/SKILL.md:41` | "`CLAUDE.md`/`AGENTS.md` ... should be used incredibly sparingly, usually only for navigation pointers" | `cds:.claude/rules/README.md:22` "Safety-critical rules should stay unscoped so they are always present." Retro will flag the project's deliberate design every run |
| `to-spec/SKILL.md:55`, `triage/AGENT-BRIEF.md:15-16` | "Do NOT include specific file paths", "Don't reference line numbers" | `multi-agent-orchestration.md:83` sub-agents return "verdict + plan + file:line" |
| `.out-of-scope/mainstream-issue-trackers-only.md:9` | Linear out of scope | `git-branch-and-commit-safety.md:3-6` Linear-first, branch per Linear ID |

Synergies:
- `docs/engineering/implement.md:57` documents the same shared-checkout corruption (amend on another session's commit, lost stash) that motivates `cds:CLAUDE.md:36-44`.
- `pr/SKILL.md:158-164` evidence matches the QA handoff screenshot rule (`cds:.claude/rules/3-workflow/pr-review-conventions.md`, QA handoff section) and blast-radius thinking in `production-hotfix-and-sql.md`.
- `diagnosing-bugs` Phase 1 matches "Don't claim verified without running the code" (`minimal-change-discipline.md`).
- `retro` deterministic-check-first matches `multi-agent-orchestration.md:139`.
- `tdd` tautological tests and seam notes reinforce `recurring-review-patterns.md` #8 and #17.

## 6. Overlap with what's installed: 2/5

| Pocock skill | Duplicates | Adds |
|---|---|---|
| grilling, grill-me | superpowers:brainstorming | Frontier batching, recommended answer per question. Contradicts `brainstorming/SKILL.md:206` "Only one question per message" |
| to-spec, to-tickets | superpowers:writing-plans | Tracer-bullet slices, blocking edges, expand-contract (`to-tickets/SKILL.md:40`) |
| implement | superpowers:executing-plans, project `commit` | none |
| implement-spec | superpowers:subagent-driven-development, dispatching-parallel-agents, using-git-worktrees | Task-graph frontier scheduling |
| tdd | superpowers:test-driven-development | Seam confirmation; excludes refactor (`tdd/SKILL.md:38`) where superpowers includes it (`test-driven-development/SKILL.md:47`) |
| diagnosing-bugs | superpowers:systematic-debugging, project investigate-bug, engineering:debug, caveman:investigate-first | Red-capable completion criterion, minimisation, HITL script |
| code-review | built-in code-review, engineering:code-review, superpowers:requesting-code-review, project pr-review, pr-review-unified, pr-review-v2, review-pr, self-review, caveman-review | Spec axis vs originating issue, Fowler smell baseline |
| writing-for-agents | superpowers:writing-skills, anthropic-skills:skill-creator | Context-pointer and no-op vocabulary |
| handoff | user skill recall, built-in /compact | none |
| teach | anthropic-skills:tech-content-teacher | none |
| retro | partial: superpowers:diagnosing-superpowers | Environment-improvement categories |
| codebase-design, improve-codebase-architecture | engineering:architecture (ADR only) | Deep-module vocabulary, HTML deepening survey |
| domain-modeling | none | GLOSSARY + lightweight ADR discipline |
| pr | none (project has no PR-body skill) | Merge-danger section |
| prototype, wizard, to-questionnaire, wait-what, wayfinder, triage | none | New, mostly niche here |

No pocock skill covers superpowers:verification-before-completion, receiving-code-review, finishing-a-development-branch, or project resolve-pr-comments, run-local-stack, verify-local-app, prod-migration-issue.

## 7. Context / token cost: 4/5

- Always loaded: 11 model-invoked descriptions, 2,152 chars; listing lines with `mattpocock-skills:` prefix about 2,515 chars, roughly 630 tokens. Computed by `scratchpad/tools/desc.py` over the frontmatter. The 16 user-invoked skills set `disable-model-invocation: true` and stay out of model context per `.agents/invocation.md:5`; their descriptions total 1,720 chars if a harness lists them anyway.
- Largest model-invoked description: `code-review` 419 chars (`code-review/SKILL.md:3`), `wizard` 313, `codebase-design` 265.
- `setup` adds an `## Agent skills` block to CLAUDE.md (about 10 lines, `setup-matt-pocock-skills/SKILL.md:86-100`), and `domain.md:5-11` tells every engineering skill to read GLOSSARY + ADRs before exploring.
- On demand: shipped `SKILL.md` total 129,220 bytes; shipped dirs 214,836 bytes. Largest `SKILL.md`: ask-matt 12,594, wayfinder 12,380, writing-for-agents 10,886, teach 9,733, diagnosing-bugs 8,664. Largest dirs: setup-matt-pocock-skills 19,820, triage 19,167, teach 18,066, ask-matt 16,843, prototype 15,880.
- Runtime: `retro` loads `writing-for-agents` (13.5 KB) every run by policy (`.out-of-scope/lazy-load-writing-for-agents.md:3`). `code-review` spawns 2 subagents per call; `implement` calls it per ticket. `implement-spec` spawns exploration, N implementers, a merger per ticket and a fixer. The docs cite 150k tokens for one `implement` ticket as normal (`docs/engineering/implement.md:69-71`).

## 8. Safety / risk: 3/5

- Hooks: none shipped. `plugin.json` has no `hooks` key and the repo has no `hooks/` dir. The only hook script is `skills/misc/git-guardrails-claude-code/scripts/block-dangerous-git.sh`, not shipped, frozen, with known bypasses: `git -C <dir> push` (#301) and fail-open without `jq` (#898), listed at `.out-of-scope/frozen-misc-skills.md:16,18`.
- Scripts:
  - `wizard/template.sh`: run by the human, not the agent (`wizard/SKILL.md:43`). Writes `.env` at mode 0600 (`template.sh:140-151`), sets GitHub repo secrets and variables via `gh secret set` / `gh variable set` (`:155-179`), opens URLs (`:67-76`). Outward writes to GitHub settings.
  - `diagnosing-bugs/scripts/hitl-loop.template.sh`: prompts and prints captures; no file or network writes.
  - `scripts/link-skills.sh:55-57` dev-only: `rm -rf "$target"` for any non-symlink dir in `~/.claude/skills` or `~/.agents/skills` with a matching skill name. Not part of the plugin; destructive if someone runs it.
  - `skills/misc/setup-pre-commit/SKILL.md:83` "Stage all changed/created files and commit". Not shipped.
- Network: `improve-codebase-architecture/HTML-REPORT.md:13-16` loads `cdn.tailwindcss.com` and unpinned `mermaid@11` with `securityLevel: "loose"`, in a local temp file. No telemetry. README images from cloudinary.
- Repo writes by shipped skills:
  - `setup-matt-pocock-skills`: CLAUDE.md block, `docs/agents/issue-tracker.md`, `domain.md`, `triage-labels.md` (`:65-68,106-112`), `gh label create` (`:104`). Shows a draft first (`:63-70`).
  - `domain-modeling` (M): `GLOSSARY.md`, `GLOSSARY-MAP.md`, `docs/adr/NNNN-*.md` (`:40,62`, `ADR-FORMAT.md:3`).
  - `research` (M): a Markdown file "where the repo already keeps such notes" (`research/SKILL.md:12`).
  - `prototype` (M): code next to the target module plus a committed throwaway branch (`prototype/SKILL.md:21,26`).
  - `to-tickets` local mode: `.scratch/<feature>/issues/*.md` (`:62`).
  - `triage`: `.out-of-scope/*.md` and closes issues (`triage/SKILL.md:82-85`).
  - `to-questionnaire`: `to-questionnaire-<slug>.md` in cwd (`:16`).
  - `implement`: commit (`:17`). `implement-spec`: branches, merges, worktree resets (`:27-29`), draft PR (`:25`). `wayfinder`: pushed branches (`:115`).
- Model-invoked writers are the main risk: `domain-modeling` triggers on "discussing codebase terminology" (`domain-modeling/SKILL.md:3`), which is most CDS conversations.

## 9. Maintenance / maturity: 4/5

- Version 1.3.1 (`plugin.json:3`, `package.json:3`), changesets with 17 pending patch entries in `.changeset/`, `CHANGELOG.md` 330 lines across 1.0.0 to 1.3.1. Issue numbers reach #1238 (`.out-of-scope/lazy-load-writing-for-agents.md:11`), so the tracker is busy. Cadence from git is unmeasurable: shallow clone, one commit. ADR updates dated 2026-08-05, 2026-10-07, 2026-10-08 (`.agents/adr/0002-ship-as-a-claude-code-plugin.md:30,43,49`).
- License MIT (`LICENSE:1`), so vendoring copies is allowed.
- Scope policy: new skills closed (`.out-of-scope/new-skills.md:3`), misc frozen (`.out-of-scope/frozen-misc-skills.md:3`), only observed failures accepted (`SCOPE.md:9-10`), Linear out of scope.
- Breaking changes per minor: 1.0.0 renamed `diagnose` and removed skills (`CHANGELOG.md` 1.0.0 section); 1.3.0 renamed `CONTEXT.md` to `GLOSSARY.md` and requires a `git mv` (`CHANGELOG.md:23-25`), removed `resolving-merge-conflicts`.
- Docs pages per skill with honest "Common questions" that list open defects. No tests or evals.

## Top strengths

1. `diagnosing-bugs`: the best debugging gate of the installed set. A red-capable command already run, minimisation until every element is load-bearing, 3-5 falsifiable hypotheses shown before testing, and a mutation diff (`diagnosing-bugs/SKILL.md:59-66,80-84,90-98,125`).
2. Design vocabulary that this repo lacks: `codebase-design` (deletion test, one adapter = hypothetical seam) and `improve-codebase-architecture`, which writes only to `$TMPDIR` and asks before anything else (`improve-codebase-architecture/SKILL.md:39,60`).
3. Documents that admit their own failure modes. `pr` merge-danger and evidence tiers, `retro` deterministic-check-first, and docs pages that state known bugs (`docs/engineering/implement.md:63-65`, `implement-spec.md:48,56,66`) make it cheap to judge each skill.

## Top risks

1. Outward and branch-changing actions without a gate: `implement` commits to the current branch, `implement-spec` creates a branch, opens and readies a PR and closes tickets, `wayfinder` pushes branches, `prototype` commits a branch while being model-invoked. Each line is cited in section 5.
2. Linear is unsupported by policy, so every tracker-writing skill would run on a one-paragraph prose description. Sub-issues, blocking edges, labels-vs-statuses and frontier queries would be improvised at runtime.
3. Duplicate disciplines with contradictory rules next to superpowers: two TDD loops (refactor in vs out), two interview styles (one question vs whole frontier), five debugging skills, ten review skills, and a bare-name `code-review` call that can hit the built-in. The model will pick inconsistently between them.

## Cherry-pick list

| Skill | Decision | Reason |
|---|---|---|
| diagnosing-bugs | adapt | Merge Phase 1 completion criterion and Phase 2 minimise into `investigate-bug` or keep as `/diagnosing-bugs` user-invoked; replace `:29` Playwright with `scripts/cds-session.mjs --probe`; add the V1 read-only constraint to `:55`. Pick it or superpowers:systematic-debugging, not both |
| codebase-design | adopt | Reference only, 265-char description, no writes |
| improve-codebase-architecture | adapt | Keep user-invoked; drop the `domain-modeling` write side effects in step 3 or make them ask first |
| pr | adapt | Fold Summary visual, Evidence, Merge Danger into the project's PR body convention; make user-invoked to avoid fighting the commit skill |
| retro | adapt | Point it at `.claude/lessons-learned.md` and the recurrence/severity policy in `cds:.claude/rules/README.md`; remove the "CLAUDE.md sparingly" bias at `:41` |
| tdd | adapt (fold content) | Copy the tautological-test anti-pattern and seam trade-off notes into `self-review` or recurring-review-patterns; do not install a second TDD skill |
| domain-modeling | adapt | User-invoked only; write `GLOSSARY.md` and ADRs only on explicit request, per workspace (`cds-api`, `cds-web`) |
| to-tickets | adapt (later) | Vertical slices and blocking edges are useful for Linear epics; rewrite step 5 to draft Linear issues via MCP after approval, no `ready-for-agent` label |
| to-questionnaire | adopt (optional) | Product-owner questions; change output path to scratchpad, not cwd |
| wait-what | adopt (optional) | 396 bytes; drop the GLOSSARY dependency |
| grilling, grill-me, grill-with-docs | skip | superpowers:brainstorming covers it with a conflicting question rule |
| ask-matt | skip | Routes only this set |
| setup-matt-pocock-skills | skip | Edits CLAUDE.md, Linear unsupported |
| to-spec | skip | Publishes without draft review; superpowers:writing-plans + Linear-first cover it |
| implement | skip | Commits to current branch, review runs on empty diff |
| implement-spec | skip | PR/ticket actions, no file-overlap serialization, no stop condition |
| wayfinder | skip | Pushes branches, heavy tracker writes, GitHub-shaped |
| triage | skip | GitHub label machine, AI disclaimer, no Linear status mapping |
| code-review | skip (harvest) | Name collision, always fans out; borrow the Spec axis and smell baseline into `pr-review` |
| research | skip | Explore agents and WebSearch cover it; writes md into the repo |
| prototype | skip for now | UI-variant pattern is good but commits branches; revisit as a worktree-only, user-invoked copy |
| wizard | skip | Infra here is AWS/Terraform; `gh secret set` is an outward write |
| writing-for-agents | skip (read once) | superpowers:writing-skills and skill-creator cover it; worth reading when editing `.claude/rules` |
| handoff, teach | skip | recall, /compact, tech-content-teacher cover them |
| all in-progress | skip | Unstable by declaration (`skills/in-progress/README.md:3`) |
| all misc | skip | Frozen; guardrail hook bypassable; pre-commit auto-commits |

## Adoption effort

(a) Whole framework: 35 to 50 hours, plus a re-check every minor release.

| Item | Hours |
|---|---|
| Install, run setup with Linear "Other" prose, CLAUDE.md block via PR | 2-3 |
| Write and test a Linear tracker doc (create, sub-issue, blocking, status vs label, frontier) against to-spec, to-tickets, triage, wayfinder, implement-spec | 8-12 |
| Fork or vendor to remove commit/push/PR/close steps and fix the bare `code-review` call | 8-12 |
| Precedence rules vs superpowers and project skills (or disable superpowers) | 3-5 |
| Pilot on 2-3 tickets, retro, fixes | 8-12 |
| Ongoing: breaking renames each minor, pinned-sha drift | 2-4 per release |

(b) Cherry-pick (first 7 rows marked adopt/adapt above): 10 to 14 hours. diagnosing-bugs 2-3, codebase-design + improve-codebase-architecture 1-2, pr 1-2, retro 1-2, domain-modeling 2, tdd content fold 1, PR and review 2. This touches more than 4 files in `.claude/skills/`, so it trips the 3-4 file gate (`cds:CLAUDE.md:104`): confirm scope or split into two PRs.
