# Audit: addyosmani/agent-skills for cds-app-rewrite

Candidate: `addyosmani/agent-skills` v0.6.12, clone at `scratchpad/repos/addy/agent-skills` (shallow, HEAD `1be8e34`, 2026-10-10, "Merge #649"). Read-only audit: nothing from the candidate was installed or executed. Paths below are relative to the clone root unless prefixed with `cds:` (the target repo).

## Verdict

Do not install the plugin as a whole. It is a well-built, Claude-Code-native plugin with real CI and evals, and it installs no hooks by default. The problem is fit. Its git, commit, ship and browser guidance contradicts at least ten of this repo's hard rules. About two thirds of its catalog duplicates superpowers, the project skills, or built-ins that are already installed. Its own comparison doc warns against running it alongside superpowers as a second router (`docs/comparison.md:119`).

Cherry-pick 5 to 7 skills or references that add capability nothing installed has: observability, performance keep-or-revert, the floor-guard diff check, idempotency and expand/contract guidance, and adversarial fresh-context review. Adapt each one to the project rules first.

---

## 1. Skill inventory

Bytes = `wc -c SKILL.md`; the figure in parentheses is the whole skill directory where supporting files exist. "CC-ready" means usable under this repo's rules without edits.

| Skill | Phase | Purpose | Bytes | CC-ready |
|---|---|---|---:|---|
| using-agent-skills | Meta | Flowchart router + 6 "core operating behaviors" | 10,446 | Y (do not wire; superpowers already routes) |
| interview-me | Define | One-question-at-a-time intent interview to ~95% confidence | 15,080 | Y |
| idea-refine | Define | Divergent/convergent ideation → `docs/ideas/*.md` one-pager | 8,111 (39,879) | Y |
| spec-driven-development | Define | Six-area SPEC.md, gated SPECIFY→PLAN→TASKS→IMPLEMENT | 13,096 | needs-edit (SPEC.md at root, no Linear) |
| constraint-driven-development | Define | CONSTRAINTS.md quality bar, tool install, floor-guard diff check | 21,008 (31,689) | needs-edit (installs tools, edits CLAUDE.md) |
| planning-and-task-breakdown | Plan | Vertical-slice tasks → `tasks/plan.md`, `tasks/todo.md` or tracker | 10,564 | needs-edit (creates tracker items) |
| incremental-implementation | Build | Thin slices: implement→test→verify→commit | 9,629 | needs-edit (auto-commit per slice) |
| test-driven-development | Build/Verify | Red-green-refactor, Prove-It, pyramid, DevTools section | 16,517 | needs-edit (DevTools MCP; name clash with superpowers) |
| context-engineering | Build | Rules files, context packing, restartable boundaries | 15,486 | Y (low value here) |
| source-driven-development | Build | Fetch official docs, cite sources | 10,038 | Y (citations-in-comments clash with no-comments) |
| doubt-driven-development | Build/Review | Adversarial fresh-context reviewer per non-trivial decision | 16,647 | needs-edit (mandatory cross-model offer, cost) |
| frontend-ui-engineering | Build | Components, design system, WCAG, states | 11,721 | needs-edit (no reduced-motion) |
| api-and-interface-design | Build | Contract-first, error semantics, idempotency keys | 14,886 | Y (Express/Zod examples, not NestJS) |
| browser-testing-with-devtools | Verify | Chrome DevTools MCP runtime verification | 14,539 | N (conflicts with `cds-session.mjs` harness) |
| debugging-and-error-recovery | Verify | Reproduce→localize→reduce→fix→guard | 10,913 | needs-edit (safe fallbacks, bisect) |
| code-review-and-quality | Review | Five-axis review, severity labels, change sizing | 20,976 | needs-edit (taxonomy ≠ Bug/Suggestion/Nit) |
| code-simplification | Review | Behavior-preserving simplification, Chesterton's Fence | 13,545 | Y |
| security-and-hardening | Review | Threat model, OWASP/LLM Top 10, three-tier boundaries | 17,559 (30,595) | Y |
| performance-optimization | Review | Measure-first, keep-or-revert, attempt ledger | 16,678 (26,370) | Y |
| git-workflow-and-versioning | Ship | Trunk-based, atomic Conventional Commits, save-point, semver | 14,141 | N (multiple hard conflicts) |
| ci-cd-and-automation | Ship | Quality-gate pipeline, GitHub Actions, Vercel examples | 11,332 | needs-edit (auto-merge, agent push loop) |
| deprecation-and-migration | Ship | Advisory/compulsory deprecation, expand/contract schema | 12,642 | Y (trigger overlaps "V1→V2 migration") |
| documentation-and-adrs | Ship | ADRs, inline docs, README, prose review | 10,910 | Y |
| observability-and-instrumentation | Ship | Structured logs, RED metrics, tracing, alerts, runbooks | 13,948 | Y |
| shipping-and-launch | Ship | Pre-launch checklist, flags, canary, rollback | 11,515 | needs-edit (env model ≠ main→qa→uat→production) |

Also shipped:

- 9 Claude commands in `.claude/commands/`: spec, plan, build, test, review, code-simplify, ship, constraints, webperf.
- 4 agents in `agents/`: code-reviewer, security-auditor, test-engineer, web-performance-auditor. None has a `tools:` restriction: `grep '^tools' agents/*.md` returns nothing.
- 7 references in `references/`.
- 4 hook scripts in `hooks/`, none wired.

Totals: SKILL.md files are 341,927 B (~85k tokens); all skill files together are 407,104 B.

---

## 2. Scores

### 1. Claude Code compatibility: 4/5

- It is a native plugin: `.claude-plugin/plugin.json:11-15` declares `"commands": ["./.claude/commands", "./commands"]`, `"skills": "./skills"` and `"experimental": {"evals": "evals/plugin"}`. Marketplace entry is `.claude-plugin/marketplace.json:9-22`.
- CI validates and installs it with the real CLI: `.github/workflows/test-plugin-install.yml:141-145` runs `claude plugin validate .`, and `:160-167` runs `claude plugin marketplace add ./` and `claude plugin install agent-skills@addy-agent-skills`.
- Agents are auto-discovered as plugin subagents (`AGENTS.md:84`). `/ship` relies on parallel Agent calls (`.claude/commands/ship.md:11-17`).
- Friction 1: hooks are not wired by the plugin. There is no `hooks/hooks.json` and no `hooks` key in plugin.json. `hooks/session-start.sh:5-8` says this is deliberate. The opt-in instructions use `${CLAUDE_PROJECT_DIR}/hooks/...` paths that do not exist in a consumer repo (`hooks/SDD-CACHE.md:24,47`; `hooks/SIMPLIFY-IGNORE.md:27-38`).
- Friction 2: the `./commands` TOML directory (Antigravity) produces a warning that the docs call cosmetic (`docs/getting-started.md:141-145`).
- Friction 3: `/review` shadows Claude Code's built-in `/review` and would need `/agent-skills:review`; evals/README.md:53 shows the namespaced form. `/plan` may also collide depending on CLI version; check with `/help`.
- Friction 4: plugin agents ship without `tools:` limits, so the `/ship` reviewers can edit files.
- Rewriting needed: none to install. Significant work to make it fit this repo (§4).

### 2. Lifecycle coverage: 4/5

| Phase | Skill(s) |
|---|---|
| Clarify/discover | interview-me, idea-refine |
| Spec/plan/design | spec-driven-development, planning-and-task-breakdown, api-and-interface-design, documentation-and-adrs (ADRs) |
| Implement | incremental-implementation, frontend-ui-engineering, source-driven-development, context-engineering |
| TDD | test-driven-development (+ `references/testing-patterns.md`) |
| Debug/root-cause | debugging-and-error-recovery |
| Code review | code-review-and-quality, doubt-driven-development, code-simplification; personas code-reviewer, security-auditor, test-engineer |
| Verification/proof | Every skill's Verification checklist; `references/definition-of-done.md`; browser-testing-with-devtools |
| Ship/PR | shipping-and-launch, git-workflow-and-versioning, ci-cd-and-automation, `/ship` go/no-go |
| Learning/retro | None. Closest: perf attempt ledger (`performance-optimization/SKILL.md:162-172`); contributor-only `evals/skill-impact.md` (empty) |
| Issue-tracker integration | One paragraph: "create one tracker item per task" (`planning-and-task-breakdown/SKILL.md:162`). No Linear workflow, no status or PR linkage |
| Parallel/multi-agent | `/ship` fan-out (`ship.md:9-19`), `references/orchestration-patterns.md`, planning parallelization (`planning…:213-219`), worktree snippet (`git-workflow…:147-171`). No per-task executor or worktree orchestration |
| Security | security-and-hardening, security-auditor, `references/security-checklist.md` |
| Performance | performance-optimization, web-performance-auditor, `/webperf` |
| A11y | frontend-ui-engineering, `references/accessibility-checklist.md` (no `prefers-reduced-motion`: `grep motion` returns nothing in either) |
| Observability | observability-and-instrumentation, `references/observability-checklist.md` |
| Quality bar | constraint-driven-development + floor-guard |

Broadest of the three candidates past the Build phase. Gaps: tracker integration, retros/learning loop, multi-agent execution.

### 3. Systematic-ness: 4/5

- There is a real command chain with explicit human gates:
  - `/spec` stops the turn after writing the spec (`spec-driven-development/SKILL.md:170-174`, "STOP YOUR TURN IMMEDIATELY").
  - `/plan` writes `tasks/plan.md` and waits for review (`plan.md:14-16`).
  - `/build` does one task. `/build auto` has a single approval gate (`build.md:34`) and stops on risky or irreversible steps (`build.md:36-39`).
  - `/ship` fans out and returns GO/NO-GO (`ship.md:39-64`).
- A pipeline-integrity validator keeps the artifact paths consistent across commands (`scripts/validate-artifact-paths.js:1-22`).
- There is a standing Definition of Done (`references/definition-of-done.md`), referenced from planning, incremental-implementation and shipping.
- The router is advisory on Claude Code: `using-agent-skills` is not injected (`hooks/session-start.sh:5-8`; `docs/getting-started.md:45-47`), so routing is native description matching.
- Internal inconsistency 1, the severity taxonomy differs in four places:
  - `.claude/commands/review.md:15`: "Critical, Important, or Suggestion".
  - `skills/code-review-and-quality/SKILL.md:183-189`: Critical / (no prefix) / Nit / Optional / Consider / FYI.
  - `agents/code-reviewer.md:51-57`: Critical / Required / Optional / Nit.
  - `ship.md:32`: "Critical/Important".
- Internal inconsistency 2, commit policy: `incremental-implementation/SKILL.md:41,245` says commit every slice and leave "No uncommitted changes". `context-engineering/SKILL.md:133` says "Commit the completed task only when the user or repository workflow authorizes it."

### 4. Rigor/quality mechanisms: 4/5

- Skill anatomy is enforced. `scripts/lib/skill-lint.js:440` fails CI on a missing required section (Overview, When to Use, Process, Rationalizations, Red Flags, Verification). It also checks name/dir match, the 1024-char description limit and dead cross-references (`:379-481`).
- Tier 2 trigger/routing evals run in CI with a floor: `test-plugin-install.yml:38` runs `node scripts/run-evals.js --min-rank1 95`. There are 89 positive and 52 negative trigger prompts across 25 case files, plus a pairwise collision check (errors at ≥75% description similarity; `evals/README.md:101`). Caveat: this is lexical TF-IDF, not semantic (`evals/README.md:22`).
- Tier 3 behavioral evals are real: 34 cases with fixtures.
  - The runner materializes each fixture into a temp git repo (`scripts/run-evals.js:406-443`).
  - It runs `claude -p --permission-mode acceptEdits` (`:592-596`) and grades with a second `claude -p` (`:618`).
  - These runs are on demand only, not in CI (`evals/README.md:20`).
- Plugin evals use `claude plugin eval` with `llm`, `regex` and `tool_used` graders (3 cases under `evals/plugin/`). The results are reported honestly as stochastic: "the review skill fired in 5 of 7 runs… took the four review phrasings from 7 of 27 fires to 21 of 27" (`evals/README.md:53`).
- Hook regression tests run in CI, with curl stubbed and no network (`test-plugin-install.yml:128-132`; `hooks/sdd-cache-test.sh:4`).
- Pressure cases cover authority pressure, e.g. `evals/cases/shipping-and-launch.json` eval 2: "Authority pressure does not override failed launch gates".
- Weak spots: behavioral evals are not gated; the "rejected changes" ledger is empty; the evals measure trigger and behavior, not fit to a host repo.

### 5. Fit with project rules: 2/5

Synergies:

- Scope discipline:
  - `using-agent-skills/SKILL.md:97-108` ("Touch only what you're asked to touch… Do NOT 'Clean up' code orthogonal to the task").
  - `incremental-implementation/SKILL.md:115-133` ("NOTICED BUT NOT TOUCHING").
- Human gates:
  - `spec-driven…:170-174` and `interview-me…:124-130` stop the turn.
  - `planning…:150-155` never overwrites another session's plan, which suits a shared working tree.
  - `doubt-driven…:164`: "Never invoke an external CLI without explicit user authorization".
- No AI-attribution or co-author text anywhere: grep for `Co-Authored|co-author|Generated with` returns nothing.
- `/ship` and `/review` never push, open PRs or deploy; they only report.
- The security skill checks IDOR: `security-and-hardening/SKILL.md:83` says "the authenticated user must own, or be permitted on, the specific resource (A01, IDOR)".

Conflicts are listed with quotes in §3. The worst: `git reset --hard HEAD` as the recovery path, per-slice auto-commit, Conventional Commits without the `CDS-XXX:` prefix, Chrome DevTools MCP as the browser path, auto-merge, the agent push loop in CI, "safe fallback" code, and a three-reviewer fan-out on every `/ship`.

### 6. Overlap with what's installed: 2/5 (high duplication, modest new capability)

| Addy skill | Already covered by |
|---|---|
| using-agent-skills | superpowers:using-superpowers (SessionStart-injected, `superpowers/6.4.1/hooks/hooks.json`) |
| interview-me, idea-refine, spec-driven-development | superpowers:brainstorming |
| planning-and-task-breakdown | superpowers:writing-plans |
| incremental-implementation, `/build auto` | superpowers:executing-plans, subagent-driven-development; caveman:lean-build, surgical-patch |
| test-driven-development | superpowers:test-driven-development (same name, both load) |
| debugging-and-error-recovery | superpowers:systematic-debugging; cds:`investigate-bug`; engineering:debug; caveman:investigate-first |
| code-review-and-quality, `/review`, code-reviewer | cds:`pr-review` (50 KB), `self-review`, `review-pr`, `resolve-pr-comments`; superpowers:requesting/receiving-code-review; built-in code-review; engineering:code-review; caveman-review |
| code-simplification, `/code-simplify` | built-in `simplify`; user `no-comments` |
| security-and-hardening, security-auditor | built-in `security-review` (partial) |
| git-workflow-and-versioning | cds:`commit` skill; superpowers:using-git-worktrees, finishing-a-development-branch |
| shipping-and-launch | engineering:deploy-checklist; cds QA-handoff runbook |
| documentation-and-adrs | engineering:architecture, engineering:documentation |
| browser-testing-with-devtools | cds:`scripts/cds-session.mjs` harness, `verify-local-app` |
| frontend-ui-engineering | frontend-design plugin (partial) |
| definition-of-done | superpowers:verification-before-completion; caveman:verify-and-stop |

Adds something new:

- constraint-driven-development's floor-guard, a diff-scoped check for weakened tests and suppressions.
- observability-and-instrumentation.
- performance-optimization's keep-or-revert discipline.
- api-and-interface-design's idempotency-key section.
- deprecation-and-migration's expand/contract schema migration.
- source-driven-development.
- doubt-driven-development's ARTIFACT+CONTRACT adversarial prompt.
- The web-performance-auditor persona.

### 7. Context/token cost: 3/5

- 25 skills, 9 commands, 4 agents.
- Always-loaded: about 11.6k chars, roughly 2.9k tokens (skills 9.7k chars name+description, commands 1.0k, agents 0.9k). The largest description is constraint-driven-development at 880 chars.
- The session-start hook is not wired. If wired, it would add `using-agent-skills/SKILL.md` (10,446 B) plus a preface, about 10.5k chars or 2.6k tokens, on every session (`hooks/session-start.sh:23-30`).
- This stacks on the project's ~22k-token always-loaded rules plus superpowers' injected router.
- On demand, typical skill loads are 2.5k to 5k tokens. Five largest SKILL.md files:
  1. constraint-driven-development: 21,008 B (31,689 with floor-guard)
  2. code-review-and-quality: 20,976 B
  3. security-and-hardening: 17,559 B (30,595 with references)
  4. performance-optimization: 16,678 B (26,370)
  5. doubt-driven-development: 16,647 B
- Multipliers:
  - `/ship` spawns 3 subagents on every non-trivial change (`ship.md:68-72`).
  - doubt-driven spawns a reviewer per non-trivial decision, up to 3 cycles (`doubt-driven…:181-191`).
  - git-workflow's description "Use when making any code change" (`git-workflow…:3`) invites a 14 KB load on routine edits.

### 8. Safety/risk: 3/5

- The default install is inert: no hooks, no MCP servers, no telemetry, no network.
- `hooks/session-start.sh` reads a local SKILL.md and prints JSON. No writes, no network. Needs `jq`.
- `hooks/sdd-cache-pre.sh` (opt-in, PreToolUse WebFetch):
  - When a cache entry exists, it sends `curl -sI -o /dev/null … -L` with If-None-Match / If-Modified-Since to the URL (`:71-74`).
  - On a 304 it exits 2 and replays the cached model-processed body as a tool error (`:94-106`).
  - It writes only a debug log when debug mode is enabled (`:29-34`).
- `hooks/sdd-cache-post.sh` (opt-in, PostToolUse WebFetch):
  - It sends an extra `curl -sI -L --max-time 5 "$URL"` (`:82`).
  - It writes `{url, prompt, etag, last_modified, content, fetched_at}` to `$CLAUDE_PROJECT_DIR/.claude/sdd-cache/<sha256>.json` (`:75-77,117-128`) and removes its own entry when there are no validators (`:111`).
  - Risk: the cache directory is not in `cds:.gitignore`, which only ignores `.claude/settings.local.json` at line 143, so `git add -A` would commit it. A stale cache can be served if a server returns a wrong 304 (`SDD-CACHE.md:159`).
- `hooks/simplify-ignore.sh` (opt-in, Read/Edit/Write/Stop) is the high-risk hook:
  - On every Read of any file containing `simplify-ignore-start`, not only during `/code-simplify`, it rewrites the source file in place with `BLOCK_<hash>` placeholders: `cat "$FILTERED" > "$FILE_PATH"` (`:312-350`).
  - Backups go to `.claude/.simplify-ignore-cache/` (`:31`).
  - The real code is restored only at Stop (`:256-307`).
  - A crash leaves placeholders on disk (`SIMPLIFY-IGNORE.md:71-77`).
  - It shells out to `perl` (`:148`).
  - In this shared working tree, other sessions, the tsc PostToolUse hook, jest and `git add` would all see mangled source mid-turn. Do not enable it.
- Skill text that drives risky commands:
  - `git reset --hard HEAD` (`git-workflow…:189`).
  - `git bisect`, which checks out commits in the current tree (`debugging…:104-108`; `git-workflow…:254-257`).
  - `npx -y chrome-devtools-mcp@latest`, unpinned (`browser-testing…:28-39`).
  - `/constraints` installs tools machine-wide (`brew install gitleaks`, `pipx install semgrep`) and edits package.json and CLAUDE.md (`constraints.md:21,25`; `constraint-driven…:140,153-160`).
  - doubt-driven may pipe code to Gemini or Codex CLIs, but only after explicit per-call authorization (`doubt-driven…:116-135,164,205`).
- Contributor-only: the eval runner uses `--permission-mode acceptEdits` inside `os.tmpdir()` workspaces (`run-evals.js:406,595`).

### 9. Maintenance/maturity: 4/5

- MIT licence (`LICENSE`). Version 0.6.12 is synchronized across 5 manifests and CI-checked (`scripts/validate-versions.js`; `test-plugin-install.yml:28-29`).
- The last merge was 2026-10-10 and is numbered #649, which suggests high PR volume. The clone is shallow, so cadence was not measured from git history.
- Three named maintainers (`README.md:396-402`). Community contributions are reviewed (`docs/comparison.md:27`).
- CI covers Ubuntu, macOS and Windows (`test-plugin-install.yml:76-120`).
- Multi-host: Claude Code, Codex, Gemini CLI, Antigravity, Copilot CLI, Cursor, OpenCode, Windsurf, Kiro, Command Code (`README.md:46-210`).
- Risks:
  - Pre-1.0, with fast churn in descriptions, and descriptions are what decide routing.
  - There is a known portability gap for per-skill installs that lose `references/` (#361, `README.md:61-66`).
  - A fork would need regular rebasing.

---

## 3. Conflicts with project rules (quoted, file:line)

| # | Project rule | Candidate line | Severity |
|---|---|---|---|
| 1 | Shared tree: "Do NOT `git checkout`… / `git reset --hard` / `git stash`" (`cds:CLAUDE.md:40`; `git-branch-and-commit-safety.md:28`) | `git-workflow-and-versioning/SKILL.md:189`: "If an agent goes off the rails, `git reset --hard HEAD` takes you back to the last successful state." Also `:180,184`: "Test fails? → Revert to last commit" | High |
| 2 | Shared tree (bisect checks out commits in place) | `debugging-and-error-recovery/SKILL.md:107-108`: "Git will checkout midpoint commits; run your test at each" / `git bisect run …`; `git-workflow…:254-257` | High |
| 3 | "Commit or push only when the user asks." (`git-branch-and-commit-safety.md:58`) | `incremental-implementation/SKILL.md:41`: "**Commit** -- save your progress"; `:245`: "No uncommitted changes remain"; `.claude/commands/build.md:24`: "7. Commit with a descriptive message"; `build.md:35`: "make one commit per task"; `git-workflow…:36`: "Each successful increment gets its own commit." | High |
| 4 | "Prefix every commit with the branch's Linear issue ID (`CDS-720: ...`)" (`cds:CLAUDE.md:95`; `cds:.claude/skills/commit/SKILL.md:5`) | `git-workflow…:81-94`: "**Format:** `<type>: <short description>`" with types feat/fix/refactor… and no issue ID; examples `:102-103` `git commit -m "refactor: extract validation logic…"` | High |
| 5 | Branch naming `<linear-issue-id>-short-description` (`git-branch-and-commit-safety.md:6`; user memory prefers `CDS-XXXX/name`) | `git-workflow…:141-144`: `feature/<short-description>`, `fix/…`, `chore/…`, `refactor/…` | Medium |
| 6 | Base is `origin/<base>` by env; local main is untrusted (`git-branch-and-commit-safety.md:12-19`) | `git-workflow…:133`: "Branch from `main` (or the team's default branch)"; `:153` `git worktree add ../project-feature-a feature/task-creation` | Medium |
| 7 | "Never remove a worktree with uncommitted/untracked work" (`git-branch-and-commit-safety.md:46`) | `git-workflow…:170`: "If one experiment fails, delete the worktree — nothing is lost" | Medium |
| 8 | Squash-merge is the repo default (`git-branch-and-commit-safety.md:41`) | `git-workflow…:319`: "'I'll squash it all later' → Squashing destroys the development narrative." | Low |
| 9 | Human-in-the-loop: "Never auto-merge." (`multi-agent-orchestration.md:40`) | `ci-cd-and-automation/SKILL.md:307`: "**Auto-merge:** If all checks pass and approved, merge automatically" | High |
| 10 | No autonomous push (`multi-agent-orchestration.md:27-36`) | `ci-cd…:181`: "Agent fixes → pushes → CI runs again"; `:187`: "Lint failure → Agent runs `npm run lint --fix` and commits"; `shipping-and-launch/SKILL.md:272`: "`git revert <commit> && git push`"; `git-workflow…:292`: `git push origin v1.4.0` | High |
| 11 | Outward Linear actions need approval (`multi-agent-orchestration.md:33-34`) | `planning-and-task-breakdown/SKILL.md:162`: "if the project's agent rules (`CLAUDE.md`…) … designate an issue tracker (e.g. … Linear …), create one tracker item per task". This repo's CLAUDE.md is Linear-first, so it would fire. | High |
| 12 | Browser verification via `scripts/cds-session.mjs`; MCP only for 4 named exceptions (`cds:CLAUDE.md:47-52`; `browser-verification.md:13`). No hand-rolled login (`ports-and-local-artifacts.md:74-75`) | `browser-testing-with-devtools/SKILL.md:3`: "Tests in real browsers via Chrome DevTools MCP… Use when building or debugging anything that runs in a browser"; `:192` "Navigate to http://localhost:3000/tasks" with no auth path; `test-driven-development/SKILL.md:22,312-341`; `.claude/commands/test.md:19`: "invoke agent-skills:browser-testing-with-devtools to verify with Chrome DevTools MCP" | High |
| 13 | "No silent fallbacks — throw with full context; don't return empty/defaults." (`minimal-change-discipline.md:11`); "Never swallow an error in a bare `catch`" (`recurring-review-patterns.md:136`) | `debugging…:216`: "When under time pressure, use safe fallbacks:"; `:224` `return DEFAULTS[key] ?? '';`; `:236-238` `catch (error) { console.error(…); return <ErrorState …/> }` | High |
| 14 | "Round 1: fan out. Round ≥2: `pr-review` alone." (`multi-agent-orchestration.md:134`) | `ship.md:68`: "The three Phase A personas run in parallel — never sequentially."; `:72`: "Skip the fan-out only if… 2 files or fewer, the diff is under 50 lines…"; doubt-driven loops a fresh reviewer up to 3 cycles per decision (`doubt-driven…:181-191`) | Medium |
| 15 | Findings as `Bug` / `Suggestion` / `Nit` (`pr-review-conventions.md:5,14`) | `code-review-and-quality…:183-189`, `review.md:15`, `code-reviewer.md:51-57` (three different taxonomies, none of them Bug/Suggestion) | Medium |
| 16 | ">3–4 files, pause and confirm scope" (`cds:CLAUDE.md:104`; `minimal-change-discipline.md:5`) | `planning…:251`: "No task touches more than ~5 files"; `planning…:131` M = 3–5 files; `spec-driven…:200` "~5 files"; `build.md:34`: "This is the only human gate — after approval, run autonomously"; `/constraints` edits package.json, CLAUDE.md, AGENTS.md, CONSTRAINTS.md and installs tools (`constraints.md:19-25`) | Medium |
| 17 | `prefers-reduced-motion` fallback for every new animation (`recurring-review-patterns.md:193,198`) | `frontend-ui-engineering/SKILL.md:277`: `animate-pulse` skeleton with no motion fallback; `grep motion` finds nothing in the skill or `references/accessibility-checklist.md` | Low |
| 18 | Minimal change; don't refactor unrelated files | `frontend-ui-engineering…:322`: "Components with more than 200 lines (split them)"; `code-review-and-quality…:113`: "Decompose, then add." | Low |
| 19 | Match comment density / user `no-comments` skill | `source-driven-development…:145-151`: source URLs as code comments | Low |
| 20 | Prod deploy path main→qa→uat→production (`stack-and-environments.md`) | `shipping-and-launch…:114-140`: staging → prod flag OFF → 5% canary → 25/50/100%; `ci-cd…:197-208,268` Vercel preview and rollback | Low (generic, not executed) |

No conflict on AI attribution: the pack never adds co-author or "Generated with" text.

---

## 4. Top strengths

1. Real measurement of the skills themselves:
   - CI-gated structural lint and routing evals (rank-1 floor 95%, pairwise collision check).
   - 34 fixture-backed behavioral evals with LLM graders.
   - `claude plugin eval` cases with honestly reported stochastic firing rates (`evals/README.md:53`).
   - Neither superpowers nor the project skills have catalog-wide trigger tests.
2. Breadth past the Build phase that nothing installed covers:
   - observability (RED metrics, symptom alerts, runbooks into `docs/runbooks/`, a directory that already exists here).
   - Performance keep-or-revert with an attempt ledger (`performance-optimization…:139-172`).
   - Idempotency-key implementation (`api-and-interface-design…:156-215`).
   - Expand/contract schema migration (`deprecation-and-migration…:164-190`).
   - The floor-guard diff check for weakened bars (`constraint-driven…:202-224` + `references/floor-guard.md`).
3. Safe defaults for a plugin:
   - Zero hooks wired, no network, no telemetry on install.
   - Human checkpoints are explicit ("STOP YOUR TURN IMMEDIATELY", `spec-driven…:174`).
   - Untrusted-data rules for fetched docs, browser content and error output (`source-driven…:97-114`; `debugging…:272-279`).
   - Cross-model calls need per-call authorization (`doubt-driven…:164,205`).

## 5. Top risks

1. Its git workflow fights the repo:
   - `git reset --hard HEAD` and bisect in the shared tree.
   - Per-slice auto-commits.
   - Conventional Commits without `CDS-XXX:`.
   - `feature/` branch names.
   - Auto-merge and the agent push loop.
   - Autonomous Linear item creation.
   - git-workflow's description, "Use when making any code change" (`:3`), means it will fire constantly.
2. Two routers and duplicated skills:
   - superpowers already injects its router at SessionStart. Adding 25 more descriptions creates same-name or same-purpose pairs: TDD ×2; debugging ×4; review ×7 including the project's pr-review.
   - Addy's own doc says "What does not work is running two of them as your active router at the same time" (`docs/comparison.md:119`).
   - Routing between them is stochastic (`evals/README.md:53`).
3. Browser and failure-handling guidance contradicts severity-axis rules:
   - DevTools MCP with unpinned `@latest` instead of `cds-session.mjs` reopens the hand-rolled `fill()` login trap.
   - "Safe fallback" code contradicts no-silent-fallbacks.
   - If anyone enables the optional simplify-ignore hook, it rewrites source files in place in a shared tree.

---

## 6. Cherry-pick list

| Item | Decision | Reason |
|---|---|---|
| observability-and-instrumentation | **Adopt** (light edit) | New capability. Point runbooks at existing `docs/runbooks/`. Swap Express examples for NestJS logger/interceptor. |
| performance-optimization | **Adopt** (light edit) | New. Measure-first, "Neutral is a revert" (`:158`), attempt ledger. Drop the DevTools-MCP measurement line (`:51`) in favor of the harness or Lighthouse. |
| api-and-interface-design | **Adapt** | Keep the idempotency and error-semantics sections. Add NestJS DTO/class-validator (rule #9) and tenant/IDOR scoping (rule #15), which the skill omits. |
| deprecation-and-migration | **Adapt** | Keep expand/contract and the tested-down-path rules. Narrow the description so "migration" does not route V1→V2 prod-migration bugs away from `prod-migration-issue`. Reference migration-authoring rules (no hand-typed timestamps). |
| constraint-driven-development | **Adapt (floor-guard only)** | Vendor the read-only diff guard from `references/floor-guard.md` into `self-review` Mechanical Claim Checks. Base must be `origin/<base>`. Skip the interview, tool installs and CLAUDE.md edits. |
| doubt-driven-development | **Adapt** | The ARTIFACT+CONTRACT, "do NOT pass the CLAIM" adversarial prompt (`:85-110`) is a strong addition to `self-review`. Remove the mandatory cross-model question every cycle (`:116-124`). Bound it by the round-1 fan-out rule. |
| source-driven-development | **Adapt (optional)** | Useful for NestJS/TypeORM/Next version-specific APIs. Drop citations-in-comments (`:145-151`) and the sdd-cache hook. |
| references/security-checklist.md + security-and-hardening/references/hardening-patterns.md | **Adopt as reference** | Solid OWASP + LLM Top 10 + destructive-path checks. Link from pr-review rather than adding another review skill. |
| references/definition-of-done.md | **Adapt** | Merge the standing checklist into `self-review`, mapped to the QA-handoff rule. |
| agents/web-performance-auditor.md | **Adopt (optional)** | New persona. Add `tools: Read, Grep, Glob` and Quick/Deep mode inputs from the harness or Lighthouse JSON. |
| code-review-and-quality | **Skip** (borrow 2 ideas) | pr-review is the house standard. Borrow the mutation probe (`:164`) and dependency-upgrade discipline (`:294-300`) into pr-review. |
| security-and-hardening (skill) | **Skip** | Built-in `security-review` + pr-review cover it; keep only the references above. |
| test-driven-development | **Skip** | Duplicates superpowers TDD under the same name. DevTools section conflicts. |
| debugging-and-error-recovery | **Skip** | superpowers:systematic-debugging + `investigate-bug`. Safe-fallback and bisect conflicts. |
| git-workflow-and-versioning | **Skip** | Conflicts #1–8. |
| ci-cd-and-automation | **Skip** | Auto-merge / push loop. Vercel-centric. Repo CI conventions already in rules. |
| shipping-and-launch, `/ship` | **Skip** | Env model and QA-handoff runbook own this. Fan-out cost conflicts. |
| incremental-implementation, `/build` | **Skip** | Auto-commit. Scope discipline already in minimal-change rules. |
| planning-and-task-breakdown, `/plan` | **Skip** | superpowers:writing-plans. Tracker clause would create Linear items. |
| spec-driven-development, `/spec` | **Skip** | Linear + superpowers:brainstorming. Root `SPEC.md`/`tasks/` are not gitignored here. |
| interview-me | **Skip** (optional user-invoked) | Overlaps superpowers:brainstorming. The rule "Don't over-ask" applies. |
| idea-refine | **Skip** | Product ideation is not this team's gap. |
| using-agent-skills | **Skip** | Second router. |
| context-engineering | **Skip** | The project's rules system is more mature. The restartable-boundary section (`:123-137`) is the only new idea. |
| code-simplification, `/code-simplify` | **Skip** | Built-in `simplify` + `no-comments`. |
| frontend-ui-engineering | **Skip** | frontend-design plugin. No reduced-motion. Encourages splits. |
| documentation-and-adrs | **Skip** | engineering:architecture covers ADRs. No ADR convention here. |
| browser-testing-with-devtools | **Skip** | Conflicts with the harness rule. |
| code-reviewer / security-auditor / test-engineer agents | **Skip** | Covered by pr-review fan-out and built-ins. No `tools:` limits. |
| All 4 hooks | **Skip** | simplify-ignore mutates source in place. sdd-cache writes an un-ignored cache and sends extra HEADs. session-start would be a second router. |
| Other 9 commands | **Skip** | Built-in `/review` collision. Conflicting chain. |

## 7. Estimated adoption effort

**(a) Whole framework: 20–30 h initial, plus ~2 h/month.**

Claude Code cannot disable individual plugin skills cleanly, so a fit-for-repo install means a fork. The work:

1. Rewrite git-workflow, incremental-implementation and `/build` (commit format and consent, branch naming, no reset/bisect/stash): 4–5 h.
2. ci-cd and shipping (no auto-merge, push or deploy; env model): 2–3 h.
3. Reroute TDD, `/test` and browser-testing to `cds-session.mjs`: 2 h.
4. Debugging fallbacks: 0.5 h.
5. Unify the review taxonomy to Bug/Suggestion/Nit across 4 files: 1 h.
6. `/ship` fan-out to round rules: 1 h.
7. Planning's tracker clause to prepare-only: 0.5 h.
8. Resolve superpowers duplication: drop or rename TDD, debugging and planning on one side, and retune descriptions so the routing evals still pass, 4–6 h.
9. `.gitignore` entries (`tasks/`, `SPEC.md`, `.claude/sdd-cache/`, `.claude/.simplify-ignore-cache/`): 0.25 h.
10. Trial on 2–3 tickets and fix fallout: 4–6 h.
11. Team docs: 1–2 h.

Ongoing rebases against a pre-1.0 upstream whose descriptions churn come to about 2 h/month. This is not recommended.

**(b) Cherry-pick: 8–12 h.**

1. Observability + performance (adopt, NestJS examples): 2 h.
2. api-and-interface-design + deprecation (adapt, add authz and migration-rule links, narrow description): 2.5 h.
3. Floor-guard into `self-review` (adapt to `origin/<base>`, test on 2 real diffs): 2–3 h.
4. Doubt-driven prompt into `self-review` (bounded): 1 h.
5. DoD + security references linked from pr-review: 1 h.
6. web-performance-auditor agent (optional): 0.5 h.
7. Trial: 1–2 h.

Per the 3–4 file gate, land this as 2–3 small PRs: (1) observability + performance skills, (2) api + deprecation skills, (3) self-review additions with floor-guard. Each adds roughly 70–110 tokens of always-loaded description.
