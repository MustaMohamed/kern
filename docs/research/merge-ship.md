# Merge map: verify, review, ship, operate (portable plugin)

Target: a personal Claude Code plugin used across many projects. Every skill below is the framework's own. Projects supply conventions through named extension points, and a project skill that owns the same job wins. No project content is embedded. Appendix B lists findings about one repo (CDS) that sit outside the framework.

Source keys. `SP` superpowers 6.4.1. `PS` pstack (`ps:` skills, `pb:` poteto-mode playbooks, `pr:` poteto-mode references, `ag:` agents). `PO` pocock. `AD` addy (`ad:` skills, `cmd:` .claude/commands, `adag:` agents, `adref:` references, `hk:` hooks). `LOC` the user's adapted `~/.claude/skills/no-comments` and `~/.claude/agents/comment-sicko.md`. `USR` generic patterns from the user's own project skills, carried as ideas only. Line refs are `file:line` inside each source root. Byte counts come from `wc -c`.

## Summary

| # | Category | Plugin artifact | Type | Invocation |
|---|---|---|---|---|
| 0 | Framework contract | `references/project-contract.md` + `workflow.yml` profile | reference | read by every skill and hook |
| 1 | Proof before "done" | `prove-it` | discipline | model-auto |
| 2 | Author self-review and blast radius | `self-review` | phase | slash |
| 3 | Independent review | `independent-review` + agents `code-reviewer`, `spec-reviewer` | phase + agents | slash |
| 4 | Receiving review and PR babysitting | `receive-review` | phase | model-auto |
| 5 | Comment hygiene | `comment-hygiene` + agent `comment-sicko` | specialist + agent | slash |
| 6 | Security review | agent `security-auditor` + `references/security.md` | agent + reference | from `independent-review`, or by agent name |
| 7 | Runtime verification | `runtime-verify` | phase | slash |
| 8 | Commit, finish branch, open PR | `finish-branch` (modes `commit`, `pr`, `pause`) | phase | slash |
| 9 | Ship, deploy proof, rollback, observe | `ship-check` (+ optional `wizard`) | command | slash |
| 10 | Quality bar and guard hooks | `hooks/hooks.json` + bash scripts | guard-hook | deterministic |

Two model-auto descriptions in the cluster (about 570 chars per session). Everything else is slash-only, an agent, or a hook. Plugin skills are namespaced (`<plugin>:self-review`), so they never collide with a project skill of the same name, and none uses the built-in names `/code-review`, `/security-review` or `/review`.

---

## 0. Framework contract

Every skill and hook in this cluster reads conventions the same way. This should become one `references/project-contract.md` shared by all clusters.

### 0.1 Precedence

1. The user's explicit instruction in this session.
2. A project skill or command that owns the same job (0.3).
3. The project profile `.claude/workflow.yml`, then `.claude/workflow.local.yml` (gitignored personal overrides).
4. Project prose rules: `CLAUDE.md`, `.claude/rules/**`, `CONTRIBUTING.md`, `CODING_STANDARDS.md` (PO `code-review/SKILL.md:36`). Prose may tighten anything. Loosening a safety default needs a profile key so skills and hooks agree; a skill that finds a prose loosening with no key reports the mismatch and proposes the key.
5. The user profile `~/.claude/workflow.yml`.
6. Framework defaults (0.2).

When two project sources conflict, the stricter one wins and the skill names both.

### 0.2 Profile keys and defaults

Format: flat `key: value` lines, comma-separated lists, `#` comments. Hooks read a key with `sed -n 's/^key:[[:space:]]*//p'`, so no nesting. A missing file means defaults. Skills read the file with the Read tool and may propose additions; writing it needs approval because it changes the repo.

| Key | Default | Read by |
|---|---|---|
| `commit.policy` | `ask` (commit only when asked) | finish-branch, receive-review, G5 |
| `commit.subject_regex` | empty: match style detected from `git log --format=%s -30` | finish-branch, G5 |
| `commit.id_from_branch` | empty (regex extracting a ticket id from the branch) | finish-branch, G5 |
| `commit.attribution` | `none` (no co-author or AI trailers) | finish-branch, G5 |
| `branch.base` | remote default branch (`git symbolic-ref refs/remotes/origin/HEAD`) | all git skills, G1 |
| `branch.protected` | `branch.base` plus every branch in `deploy.envs` | G1, G15 |
| `branch.naming` | follow recent remote branch names, else `<slug>` | finish-branch |
| `push.policy` | `ask` | finish-branch, receive-review, G1 |
| `force_push.policy` | `deny` | G1 |
| `pr.policy` | `draft-after-approval` | finish-branch, G2 |
| `pr.template` | `.github/pull_request_template.md` if present, else framework `pr-body.md` | finish-branch |
| `pr.dedup` | `on` | finish-branch, receive-review, G2 |
| `merge.policy` | `human` (agent never merges) | ship-check, G1 |
| `forge` | `github` via `gh`; other values give a local report only | review skills, finish-branch |
| `tracker` | `none`; `github`, `linear`, `jira` or other via `gh` or an MCP server | review skills, ship-check |
| `tracker.id_regex` | empty | finish-branch, independent-review |
| `tracker.write_policy` | `ask` | ship-check, receive-review, G14 |
| `spec.source` | linked issue, then PR body, then `docs/specs/`, then ask | prove-it, independent-review |
| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` (first value blocks merge) | review skills, G3 |
| `review.posting` | `inline` (findings on `path:line`; body holds verdict and summary) | independent-review |
| `review.post_policy` | `ask` | independent-review, G3 |
| `review.rounds` | `fanout-first`: round 1 may fan out; round 2+ one reviewer on the delta since the last reviewed head | independent-review |
| `review.fanout_skip` | `files<=2,lines<50` with no sensitive path touched | independent-review |
| `review.sensitive_paths` | `**/auth*,**/*permission*,**/*polic*,**/migrations/**,**/.github/workflows/**,**/*.sql,**/.env*,**/config/**` | independent-review, security-auditor |
| `review.checklists` | the project prose rules from 0.1 step 4 | self-review, independent-review |
| `lessons.file` | none (proposals stay in chat) | self-review, receive-review |
| `verify.fast` / `verify.task` / `verify.full` | detected from package scripts, Makefile, pyproject, go.mod, Cargo; else ask once | prove-it, self-review, G7 |
| `verify.browser` | detect: project harness, Playwright or Cypress config, DevTools MCP with an isolated profile, else ask | runtime-verify, prove-it |
| `verify.doctor` | none (read-only health command) | runtime-verify |
| `verify.features_dir` | `.claude/verify/features/` | runtime-verify |
| `deploy.envs` | none; ordered `name=branch` list | ship-check, finish-branch, G15 |
| `deploy.proof` | CI run for the merge SHA | ship-check, prove-it |
| `deploy.commands` | see G15 defaults | G15 |
| `branch.hotfix_base` / `pr.backport_to` | none | finish-branch |
| `handoff.policy` | `none`; `qa` drafts re-test steps and evidence | ship-check |
| `comments.cap` | one line, only where the code cannot say it, no ticket ids | comment-hygiene |
| `security.rules` | prose rules mentioning authz or permission | security-auditor |
| `guards.<id>` | per G table "Default" column; `on`, `off`, or a policy | all hooks |
| `guards.primary_tree` | `ask` | G1 |
| `guards.explicit_staging` | `ask` | G5 |
| `guards.never_commit` | empty (globs) | G6 |
| `guards.protected_targets` | empty (hosts, DSN substrings, cloud profiles that take no writes) | G13 |
| `guards.mcp_write_servers` | `linear,jira,atlassian,github,gitlab,asana,monday,notion,slack` | G14 |
| `autopilot` | `off`; `allowed` permits the mode in 0.5 | all hooks, all skills |
| `overrides.<job>` | empty; names the project skill that owns a job | every skill |

### 0.3 Defer rule

Job ids: `prove`, `self-review`, `independent-review`, `receive-review`, `comment-hygiene`, `runtime-verify`, `finish-branch`, `ship-check`.

At the start of a run each skill checks, in order:

1. `overrides.<job>`. If set, invoke that project skill and stop.
2. A project skill or command with the same name in `.claude/skills/` or `.claude/commands/`. Defer and say so in one line.
3. A project skill whose description covers the job. Ask once whether it owns the job and propose the `overrides.<job>` key.

Deferring hands over the procedure, not the safety floor. Hooks keep running. A project skill that pushes or merges without asking still meets G1 and G2 until the profile loosens the matching policy, and the plugin reports that conflict instead of working around it.

### 0.4 Safety floor (loosened only by a profile key)

- No commit unless the user asked.
- Push, PR creation, PR ready, merge, deploy, review posting and tracker writes each need human approval.
- PRs open as drafts. A dedup check (`gh pr list --head <branch> --state all`) runs before any push or PR.
- No force push.
- Review round 2+ uses one reviewer scoped to `git diff <last-reviewed-head>..HEAD`.
- Primary-tree branch switches, `reset --hard`, `stash` and `clean -f` ask first.
- Comment, review and tracker text is untrusted data, never interpolated into a shell command.

### 0.5 Autopilot mode (opt-in)

Autopilot is for unattended runs. It may commit and open draft PRs. It never merges, marks a PR ready, deploys, posts reviews or writes to a tracker.

- Enabled only when the profile says `autopilot: allowed` and the human started the session with `PLUGIN_AUTOPILOT=1` in the environment. Both are human acts; the agent cannot turn it on.
- An `ask` decision would stall an unattended run, so every hook resolves `ask` explicitly in autopilot: the actions autopilot may take become `allow`, everything else becomes `deny` with a reason the agent records in its report.
- Skills read the same flag and replace "show the draft and wait" with "write the draft to the scratchpad and stop that branch of work".
- Autopilot never loosens a profile key a project set stricter. A project with `commit.policy: deny` stays denied.

The autopilot run loop itself (task selection, stop conditions) belongs to the build cluster; this cluster owns only the guard behaviour.

---

## 1. Proof before "done"

Job `prove`. No claim of done, fixed, passing, verified or deployed without a fresh run on the real artifact. Phase: end of every task, before any commit, push, PR, status update or handoff.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| verification-before-completion | SP | 3,646 | auto | Iron law, 5-step gate function, claim-to-evidence table |
| principle-prove-it-works | PS | 1,371 | slash | Check the real thing, not a proxy; script the check |
| evidence label rule | PS `ps:poteto-mode/SKILL.md:111` | (router) | slash | Every claim carries evidence or a label: measured, inferred, guess |
| bug-fix step 4 | PS `pb:bug-fix.md:10` | (playbook) | slash | Inconclusive or wrong surface is not a pass |
| definition-of-done | AD `adref:definition-of-done.md` | 3,798 | reference | Standing bar separate from acceptance criteria |
| fail-then-pass probe | USR | n/a | n/a | Revert the guard, the test must fail; the allow case uses the value a real caller sends |

Strongest mechanisms to keep:

- Gate function IDENTIFY, RUN, READ, VERIFY, CLAIM. `SP verification-before-completion/SKILL.md:24-36`. Ordered, and it names the command per claim.
- Claim-to-evidence table, especially "Agent completed: VCS diff shows changes" and "Requirements met: line-by-line checklist". `SP ...:40-48`. Neither PS nor AD distrusts subagent success reports.
- Red-green regression proof. `SP ...:82-86`. Extended with the allow-case trap: an allow test that copies the literal from the guard proves nothing (USR).
- Suspect the observation method before the system. `PS principle-prove-it-works/SKILL.md:16`.
- Script the check and keep its output as the artifact. `PS ...:18-20`.
- Evidence or label in the same sentence. `PS poteto-mode/SKILL.md:111`.
- Inconclusive or wrong surface is a fail. `PS bug-fix.md:10`.
- "Verified at runtime, not just compiled"; "tests that fail without the change". `AD definition-of-done.md:23-24`.

Drop:

- SP rationalization rows past the first four and "Violating the letter". `SP ...:12,61-72`.
- AD documentation and ADR items as per-task gates. `AD definition-of-done.md:42-45`. They belong to `finish-branch` and `ship-check`.
- "Commit the artifact for large work". `PS principle-prove-it-works/SKILL.md:22`.

Merged spec:

- `prove-it`, discipline, model-auto. The trigger is the agent's own wording ("done", "fixed", "passes"); nobody types a slash at that moment.
- Description (274 chars): "Use before saying work is done, fixed, passing, verified or deployed; before any commit, PR, status update or handoff; and when a subagent reports success. Run the proving command fresh on the real artifact, read all output, and label each claim measured, inferred or guess."
- Extension points: `verify.fast|task|full`, `verify.browser`, `deploy.proof`, `spec.source`.
- Steps:
  1. Name the claim and its proving command from `references/evidence.md`, resolved through the profile. `[SP :27, PS :13-16]`
  2. Run it fresh and in full on the tree you will integrate. `[SP :29, SP finishing:216]`
  3. Read exit code, failure count and the whole output. Inconclusive, skipped, or the wrong env counts as fail. `[SP :29, PS bug-fix:10]`
  4. New guard or regression test: fail-then-pass probe (G10); the allow case uses a real caller's value. Report "probe inconclusive, compiler-blocked" when that happens. `[SP :82-86, USR]`
  5. "Requirements met": re-read acceptance criteria from `spec.source` and tick each line against evidence. `[SP :48,94-98, AD DoD:22]`
  6. Subagent "success": read its worktree diff and artifacts yourself. `[SP :47,100-104]`
  7. State each claim with its evidence or label. `[PS poteto-mode:111]`
  - Gate: steps 1-7 hold before any commit, push, PR, tracker write, or the words done, fixed, verified.
- `references/evidence.md`: generic claim table. Tests, typecheck, lint and build map to `verify.*`. UI behaviour maps to `runtime-verify` with a settled page and a clean console. Deployed maps to `deploy.proof`, else the CI run for the merge SHA plus a live version read. Subagent success maps to `git -C <wt> diff`.
- Size: SKILL.md 3 KB, reference 2 KB.

---

## 2. Author self-review and blast radius

Job `self-review`. The author finds what the diff breaks beyond itself, proves the one fact it relies on, and runs every cheap deterministic check before anyone else spends tokens. Phase: before push and before each PR update.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| blast-radius | PS | 3,856 | slash | Find the one fact the change is safe because of; prove it by running code |
| doubt-driven-development | AD | 16,647 | auto | CLAIM, EXTRACT, DOUBT (artifact + contract only), RECONCILE, STOP at 3 |
| mutation probe | AD `ad:code-review-and-quality/SKILL.md:164` | (of 20,976) | auto | Invert one condition; a green suite is a finding |
| bar-weakening moves | AD `ad:constraint-driven-development/SKILL.md:202-216` | (of 21,008) | auto | Five ways an agent lowers the bar, visible in `git diff` |
| change summary | AD `ad:git-workflow-and-versioning/SKILL.md:191-209` | (of 14,141) | auto | Changes made, things I didn't touch, concerns |
| claim checks, writer sweep | USR | n/a | n/a | Cited SHAs reachable and read; absolute words in comments need evidence; list every writer |

Strongest mechanisms to keep:

- One load-bearing fact plus a five-rung confidence ladder (said so, pointed at the line, showed the bad case cannot happen, ran it, reproduced in the app). `PS blast-radius/SKILL.md:19-34`.
- Look where grep stops: pinned library source, wire formats, DB columns, JSON shapes, flags, three hops downstream. `PS ...:35`.
- Risks and Cleared reported separately. `PS ...:36,44-45`.
- Non-trivial decision definition as the spend gate. `AD doubt-driven-development/SKILL.md:16-22`.
- Reviewer gets ARTIFACT + CONTRACT, never the CLAIM; strip your reasoning. `AD ...:75-83,106`.
- Reconcile precedence: contract misread, actionable, trade-off, noise. `AD ...:172-177`.
- Stop at 3 cycles; a too-big artifact means decompose. `AD ...:183-191`.
- Doubt-theater signal. `AD ...:215`.
- Mutation probe by experiment. `AD code-review-and-quality/SKILL.md:164`.
- Bar-weakening moves on the diff. `AD constraint-driven-development/SKILL.md:206-216`.
- "Didn't touch" list. `AD git-workflow-and-versioning/SKILL.md:200-209`.
- Claim checks and writer sweep as commands, not prose (USR).
- Split signal: a round that fixes the previous round's fixes means split the change (USR).

Drop:

- Cross-model CLI offer every cycle (Gemini, Codex). `AD doubt-driven-development/SKILL.md:112-166`. Claude-only; keep "fresh Claude subagent, optionally another Claude model".
- Arena step. `PS blast-radius/SKILL.md:38`.
- Degraded self-questioning inside a subagent. `AD ...:47`. Escalate to the main session.

Merged spec:

- `self-review`, phase, slash. Expensive and user-triggered; `prove-it` covers the automatic gate.
- Description (227 chars): "Run before pushing a branch or opening a PR. Runs diff guards, cited-SHA and comment-claim checks, a writer sweep and fail-then-pass probes, proves the one fact the change relies on, and runs a bounded doubt cycle. /self-review"
- Extension points: `branch.base`, `verify.fast`, `verify.task`, `review.checklists`, `review.taxonomy`, `lessons.file`, `overrides.self-review`.
- Steps:
  1. Defer check (0.3). Branch check; `git fetch origin <base>`; diff merge-base to working tree including untracked files. `[AD floor-guard.md:9]`
  2. Deterministic pass with output pasted: `floor-guard.sh` (G7), `claim-checks.sh` (G9), `verify.fast`, related tests from `verify.task`. A skipped check counts as failed. `[AD constraint-driven:216, USR]`
  3. Walk the project checklists from `review.checklists`. `[PO code-review:36]`
  4. Blast radius when a changed symbol has callers outside its directory: writer sweep, the one safety fact pushed to rung 4 with a script, Risks and Cleared. `[PS blast-radius:19-46, USR]`
  5. Probes: fail-then-pass per new guard test; one mutation probe per new conditional, on a file copy, restored. `[USR, AD code-review-and-quality:164]`
  6. Doubt cycle for non-trivial decisions only, fresh subagent, max 3. `[AD doubt-driven:16-22,62-191]`
  7. Output in `review.taxonomy` classes with verdict `ready` / `fix first` / `rebase first` / `split`. `[USR]`
  8. Propose new patterns for `lessons.file`; write only on approval.
- References: `blast-radius.md`, `doubt-cycle.md` (AD steps and red flags `:209-221`), `claim-checks.md`.
- Size: SKILL.md 6 KB, references 8 KB.

---

## 3. Independent review

Job `independent-review`. A reviewer that did not write the code judges the diff against intent, spec and project rules; findings reach the forge in the project's format. Phase: after self-review, per PR round.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| requesting-code-review + code-reviewer.md | SP | 2,977 + 6,449 | auto | Fresh reviewer with crafted context and BASE/HEAD SHAs |
| interrogate (+ rubric, prompt, quality lens, lead judgment) | PS | 4,317 + 15,729 | slash | Parallel reviewers, lead judgment into Act on / Consider / Noted / Dismissed |
| code-review | PO | 6,670 | auto | Standards and Spec axes in parallel, never reranked across axes |
| code-review-and-quality | AD | 20,976 | auto | Five axes, structural remedies, sizing, dependency discipline |
| /review | AD cmd | 846 | slash | Wrapper |
| code-reviewer agent | AD adag | 3,995 | agent | Five-axis persona |

Strongest mechanisms to keep:

- Crafted context and SHAs, never session history. `SP requesting-code-review/SKILL.md:8,26-40,79-80`.
- Read-only on the checkout; other revisions via `git worktree add` in a temp dir. `SP code-reviewer.md:50-52`.
- A reviewer never spawns reviewers. `SP code-reviewer.md:54-61`.
- "Declined to judge" list, one line per behaviour set aside, ruled on by the orchestrator. `SP code-reviewer.md:43-48`.
- Spec is a vision document; a reasonable user's expectation is a requirement. `SP code-reviewer.md:33-41`.
- Intent paragraph before spawning; ask if unclear; reviewers do not question intent. `PS interrogate/SKILL.md:21-23`, `PS reviewer-prompt.md:15`.
- Spec axis as its own agent: missing or partial, unrequested, implemented wrong, each quoting the spec line, under 400 words; axes never reranked. `PO code-review/SKILL.md:68-89`.
- Standards sources found in the repo, with a smell baseline the repo overrides. `PO code-review/SKILL.md:34-41`.
- Validate the fixed point and a non-empty diff before spawning. `PO code-review/SKILL.md:21-23`.
- Lead judgment: trace the call site before accepting a hypothetical; nitpick gravity; "I'd do it differently" is dismissed; more than 5 Act-on items means under-filtered; Dismissed list kept as a trust record. `PS lead-judgment.md:18-58`.
- Independent agreement is the highest signal. `PS interrogate/SKILL.md:42`.
- Finding shape: severity, location, finding, evidence; empty review is valid; no praise. `PS reviewer-prompt.md:33-45`.
- Rubric items: idempotency, concurrency by structure, trace the execution path, structure over instructions, legacy dual paths. `PS rubric.md:14-41`.
- Structural lens: file crossing 1,000 lines, ad-hoc conditionals in unrelated flows, logic in the wrong layer. `PS code-quality-review.md:23-31`, `AD code-review-and-quality/SKILL.md:48-49,60-62,113`.
- Lead with the one structural problem. `AD ...:193`.
- Dependency upgrades: changelog, one package per change, lockfile diff. `AD ...:294-300`.
- Post once with inline comments and an event chosen from the verdict; never self-approve; follow-up rounds report Fixed / Still open / New; resolve threads only when asked (USR).

Drop:

- Three AD severity taxonomies. `AD cmd:review.md:15`, `ad:code-review-and-quality/SKILL.md:183-189`, `adag:code-reviewer.md:51-57`. Replaced by `review.taxonomy`.
- Mandatory praise. `SP code-reviewer.md:98`, `AD adag:code-reviewer.md:80-81,95`.
- Non-Claude reviewer models and fan-out every round. `PS interrogate/SKILL.md:27-36`.
- "Be ambitious, restructure" as a blocker. `PS code-quality-review.md:5,13-15,43`. Kept as a non-blocking lens.
- Review-speed SLA. `AD ...:251-258`.
- "Require cleanup before submission". `AD ...:269`. Adjacent gaps become a separate issue.
- PO's bare name `code-review` (built-in collision).

Merged spec:

- `independent-review`, phase + agents, slash. Posting is outward and round 1 costs real tokens.
- Description (281 chars): "Review a PR or local branch with reviewers that did not write it. Round 1 fans out code, spec and, for sensitive paths, security reviewers; later rounds use one reviewer on the new delta. Findings use the project's taxonomy and post after approval. /independent-review <pr>|--local"
- Extension points: `forge`, `tracker`, `spec.source`, `review.taxonomy`, `review.posting`, `review.post_policy`, `review.rounds`, `review.fanout_skip`, `review.sensitive_paths`, `review.checklists`, `security.rules`, `overrides.independent-review`.
- Steps:
  1. Defer check (0.3). Pin the head SHA and base; validate a non-empty diff. `[PO code-review:21-23]`
  2. Round detection: find my last review's `<!-- reviewed-head: <sha> -->` marker. With a marker, scope to `git diff <sha>..HEAD`, one `code-reviewer`, skip step 5. If `verdict-valid.sh` (G11) reports an unchanged patch, report "head unchanged in content since round N" and stop. `[USR, PS shipping:9]`
  3. Context: acceptance criteria from `spec.source`, PR body, intent paragraph; ask if intent is unclear. `[PS interrogate:21-23]`
  4. Deterministic checks: CI state, `floor-guard.sh` on the PR diff, `verify.fast` on PR content. `[AD floor-guard]`
  5. Round 1 fan-out in one message: `code-reviewer`, `spec-reviewer` (skipped with a note when no spec exists), `security-auditor` when `review.sensitive_paths` match. Skip fan-out under `review.fanout_skip`. `[SP requesting-code-review, PO code-review:58-80, AD cmd:ship.md:72]`
  6. The main session runs the blast-radius pass on shared code itself; it needs full context. `[PS blast-radius, USR]`
  7. Lead judgment: trace each finding to a reachable path; map Act on, Consider and Noted onto `review.taxonomy` in order; keep Dismissed and Declined-to-judge in the local report only. `[PS lead-judgment, SP code-reviewer.md:43-48]`
  8. Show the draft. On approval, post once per `review.posting` with the `reviewed-head` marker; never approve your own PR. Under autopilot, or with a non-GitHub forge, stop at the local report. `[USR]`
- Agents: `code-reviewer.md` (SP sections + PS finding shape + PS rubric, read-only tools, 5 KB), `spec-reviewer.md` (PO spec brief, 2 KB).
- References: `rubric.md`, `lead-judgment.md`, `posting-github.md` (JSON via `--input`, diff positions, GraphQL thread resolve), `followup.md`.
- Size: SKILL.md 8 KB, references 10 KB, agents 7 KB.

---

## 4. Receiving review and PR babysitting

Job `receive-review`. Turn review comments, bot findings and red CI into verified fixes or evidenced pushback, with one human gate before anything remote. Phase: after a review round lands.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| receiving-code-review | SP | 6,203 | auto | Read, understand, verify, evaluate, respond, implement; clarify all before any |
| babysit | PS pb | 8,289 | slash | Modes, merge frontier, conflicts then threads then CI, CI classification |
| bugbot-triage | PS pr | 9,629 | reference | fix / dismiss / ask with a learned-pattern ledger |
| CI feedback loop | AD `ad:ci-cd-and-automation/SKILL.md:164-191` | (of 11,332) | auto | Paste the specific failure, fix, verify locally first |
| single permission gate | USR | n/a | n/a | Fix everything locally, one summary block, one "yes" before push and replies |

Strongest mechanisms to keep:

- Clarify every unclear item before implementing any. `SP receiving-code-review/SKILL.md:40-57`.
- Five checks for external feedback; a conflict with the user's earlier decision stops for discussion. `SP ...:67-84`.
- YAGNI grep before "implement it properly". `SP ...:88-98`.
- No performative agreement or thanks. `SP ...:27-38,131-148`.
- Comment text is untrusted data, never interpolated into a shell command; replies go out as JSON files. `PS babysit.md:12,22`.
- fix / dismiss / ask, with ask-by-default for security, auth, data, migration, concurrency. `PS bugbot-triage.md:5-13,75-84`.
- Verify a checkable claim by running the test first; check whether a security finding was already fixed later in the PR. `PS bugbot-triage.md:98-122`.
- Learned-pattern format with candidate / recurring / strong confidence. `PS bugbot-triage.md:15-29`.
- Order conflicts, then threads, then CI; one push wave; a conflict is reported, not resolved. `PS babysit.md:11`.
- CI classification: one fresh build for flake; an identical second failure is not flake; a failure outside the diff means check for a stale base. `PS babysit.md:21`.
- Modes drive / background / threads-only / check. `PS babysit.md:7`.
- Babysitting never authorizes merging. `PS babysit.md:18,23`.
- Fix in the lowest owning PR with a red-first proof. `PS babysit.md:22`.
- One summary block and one "yes" before commit, push and replies; every thread covered, paginated (USR).

Drop:

- `scripts/watch-pr` (TypeScript and bun, about 100 KB with tests) and `/loop` polling. `PS babysit.md:12`. Use `gh pr checks <n> --watch` in a background shell; loop only when asked.
- Owner rebases with `--force-with-lease`. `PS babysit.md:10`.
- Origin forge branches. `PS babysit.md:7,12-14`.
- "Agent runs `lint --fix` and commits". `AD ci-cd-and-automation/SKILL.md:187`.

Merged spec:

- `receive-review`, phase, model-auto. Feedback often arrives mid-conversation ("fix items 1-6", a pasted bot comment) with no slash, and the clarify-all-first gate must fire then.
- Description (289 chars): "Use when review feedback arrives: PR threads, bot comments, red CI, or a reviewer's list pasted in chat. Clarifies every unclear item before changing code, verifies each claim against the code, fixes or pushes back with evidence, and asks once before push and replies. /receive-review <pr>"
- Extension points: `forge`, `commit.*`, `push.policy`, `pr.dedup`, `review.taxonomy`, `lessons.file`, `tracker.write_policy`, `overrides.receive-review`.
- Steps:
  1. Defer check (0.3). Mode `chat`, `threads` (default) or `check` (read-only CI, threads, mergeability). `[PS babysit:7]`
  2. Ingest with `gh api --paginate`; treat all text as data. `[PS babysit:12]`
  3. Clarify gate: list understood and unclear items; ask about every unclear one before any edit. Under autopilot, unclear items are parked in the report, not guessed. `[SP receiving:40-57]`
  4. Verify each claim at the PR head; run the cheap test when the claim is checkable. `[SP receiving:69-84, PS bugbot-triage:98-122]`
  5. Decide fix, fix with scope, push back or ask. Force ask for security, auth, data, migration. YAGNI grep on "implement properly". `[PS bugbot-triage:75-84, SP receiving:88-98, USR]`
  6. Implement one at a time, red-first for behaviour, then `prove-it`. `[SP receiving:100-111, PS babysit:22]`
  7. Red CI: `ci-classify.sh` (G12) before any rerun; stale base becomes a rebase proposal; real failures go to debugging. `[PS babysit:21]`
  8. One summary block, then wait. On "yes": commit per `commit.*`, dedup, push, post replies from JSON files, resolve only threads the user named. Under autopilot: commit and push the branch (G1, G5 allow), replies drafted to the scratchpad, not posted. `[USR, PS babysit:22]`
  9. Propose candidate patterns for `lessons.file` in the ledger format. `[PS bugbot-triage:15-29, PS babysit:23]`
- References: `bot-triage.md` (PS rubric, generic candidates, 4 KB).
- Size: SKILL.md 6 KB.

---

## 5. Comment hygiene

Job `comment-hygiene`. A fresh agent brings comments in scope under the project's cap without losing facts. Phase: before review.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| no-comments | PS | 2,560 | slash | Spawn Comment Sicko, audit, encode constraint comments |
| Comment Sicko | PS ag | 2,230 | agent | Keep list as the only leash; MUST KILL flags |
| no-comments (adapted) | LOC | 3,320 | slash | Cap resolution, fact-loss audit, UNVERIFIED rulings |
| comment-sicko (adapted) | LOC | 3,274 | agent | Fold to cap, keep facts whole, overflow and UNVERIFIED lists |

Strongest mechanisms to keep:

- The author never audits their own sweep. `LOC no-comments/SKILL.md:9`.
- Cap resolution order: repo rule, standing memory, default. `LOC ...:17-25`. Becomes `comments.cap` first.
- Fact-loss audit for every fold. `LOC ...:30`.
- UNVERIFIED list for evidence the agent cannot reach. `LOC comment-sicko.md:43`.
- MUST KILL flags for surprises in our own code. `PS ag:comment-sicko.md:17`, `LOC comment-sicko.md:35-37`.
- Correctness-rule suppressions are deleted and flagged. `PS ag:comment-sicko.md:24`.
- Constraint comments get an offered encoding and are deleted only on approval. `PS no-comments/SKILL.md:23`, `LOC ...:32`.
- One rerun, then fail open. `PS no-comments/SKILL.md:20`.

Drop: PS persona voice (`PS ag:comment-sicko.md:2-12`); "doubt kills" without the UNVERIFIED escape (`PS ag:comment-sicko.md:22`); PS `/architect`, `/how`, `/why` dependencies (`PS no-comments/SKILL.md:20-21`).

Merged spec:

- `comment-hygiene`, specialist, slash; agent `comment-sicko`.
- Description (218 chars): "Bring comments in a diff or file set under the project's comment cap. A fresh agent deletes or folds them, keeps every measured fact and external trap, and flags code that needs prose to be understood. /comment-hygiene"
- Extension points: `comments.cap`, `branch.base`, `overrides.comment-hygiene`.
- Steps: the LOC procedure unchanged (`LOC no-comments/SKILL.md:27-34`), with the cap read from `comments.cap` before repo prose.
- Size 6.6 KB. `finish-branch` step 4 runs it on the diff.

---

## 6. Security review

Job: trace untrusted input to sinks and check authorization scoping on every new write path. Phase: round-1 review when `review.sensitive_paths` match; on demand by agent name.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| security-and-hardening (+ hardening-patterns) | AD | 17,559 + 13,036 | auto | Threat model first, Always / Ask first / Never, destructive-path rule |
| security-checklist | AD adref | 14,360 | reference | Checklists, install-script gate, OWASP and LLM tables |
| security-auditor | AD adag | 4,992 | agent | STRIDE from trust boundaries; PoC for Critical/High |
| rubric, security lens | PS `pr:interrogate/references/rubric.md:70-77` | (of 4,772) | reference | Trace the input path per finding |

Strongest mechanisms to keep:

- Threat model before controls; trust follows who wrote a value. `AD security-and-hardening/SKILL.md:21-40` (`:25`).
- Abuse cases as the first tests. `AD ...:38`.
- Ask-first list (auth flows, new sensitive data, CORS, uploads, elevated permissions) as approval triggers. `AD ...:55-63`.
- Destructive operations on derived paths: allowlisted root, at least one level down, ownership evidence read first, stop on refusal. `AD ...:115-119`, `adref:security-checklist.md:68-105`.
- Rotate a leaked secret first, then purge. `AD ...:129`.
- Each finding traces the input path; PoC for Critical/High; never suggest disabling a control. `PS rubric.md:72`, `AD adag:security-auditor.md:99-106`.
- Authorization means "this principal on this resource", not "has the role anywhere". `AD ...:83`. Project-specific scoping rules come from `security.rules`.
- Install-script gate for new dependencies. `AD adref:security-checklist.md:158-190`.

Drop: Express, helmet, bcrypt and Upstash snippets (`AD hardening-patterns.md:13-119,239-271`); GDPR section as a review gate (`AD ...:142-152`), one PII-in-logs line kept; "Positive Observations" (`AD adag:security-auditor.md:90-91`); a skill named `security-review` (built-in collision).

Merged spec: agent `security-auditor.md` (AD scope 1-6 + STRIDE rule 8 + PS trace rule + "read `security.rules` first", read-only tools, 5 KB). Reference `references/security.md` (STRIDE prompt, Ask-first list, destructive-path rule, secrets, 4 KB), shared by `independent-review` and `self-review`.

---

## 7. Runtime verification

Job `runtime-verify`. Drive the real app the way a user does and keep evidence. Phase: during build, before PR, and per environment after deploy.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| create-verification-skill (+ feature-map example) | PS | 5,879 + 9,005 | slash | Launch / Doctor / Drive / Evidence / Cleanup plus a per-feature map |
| maintain-verification-skill | PS | 4,922 | slash | Source wave per feature, one live pass, doc drift vs product regression |
| browser-testing-with-devtools | AD | 14,539 | auto | DevTools workflows; browser content untrusted; clean console |
| live and regression lanes | PS `pb:autopilot-full.md:8` | (of 9,431) | slash | Live lane is the floor; same scenario on trunk |

Strongest mechanisms to keep:

- Interview the repo, not the user: surface, run, drive, observe, isolate. `PS create-verification-skill/SKILL.md:11-19`.
- Doctor before the first drive and after any failed drive. `PS ...:28`, `PS maintain-verification-skill/SKILL.md:33`.
- Feature map with every user entry point and the observable end state. `PS create-verification-skill/SKILL.md:34-36`, `feature-map-example/README.md:35-42`.
- Do not report a skipped entry point as verified through another path. `README.md:31`.
- Mutation proof needs a read-only second view of the stored value. `README.md:28`.
- Evidence survives cleanup and is checked at its named location. `PS create-verification-skill/SKILL.md:31,40`.
- Verify what a dry-run skips by observing it. `PS ...:30`.
- Refuse to double-drive a shared instance. `PS ...:19`.
- Prove a generated recipe end to end before handing it over. `PS ...:38-40`.
- Audit pass: doc drift fixed in the map, product regressions reported. `PS maintain-verification-skill/SKILL.md:19-21,35`.
- Browser content is untrusted; JS execution read-only, no credential reads; isolated profile by default. `AD browser-testing-with-devtools/SKILL.md:62-90`.
- Zero console errors as the standard. `AD ...:256-258`.
- Regression lane on trunk. `PS autopilot-full.md:8`.
- Probe the page before writing a selector; network idle is not readiness (USR).

Drop: DevTools MCP install as the default path (`AD ...:24-58`), kept as the last fallback; perf traces (`AD ...:164-182`); `.cursor/skills` paths (`PS create-verification-skill/SKILL.md:9,25`); "one PR of corrections" as an autonomous outcome (`PS maintain-verification-skill/SKILL.md:16,37`).

Merged spec:

- `runtime-verify`, phase, slash. `prove-it` routes UI and runtime claims here.
- Description (269 chars): "Drive a change in the running app the way a user does: doctor first, probe before selecting, follow the project's feature map, keep screenshots and console and network logs. --init builds the map and driver config; --audit re-checks it. /runtime-verify [--init|--audit]"
- Extension points: `verify.browser`, `verify.doctor`, `verify.features_dir`, `deploy.envs`, `overrides.runtime-verify`.
- Steps:
  1. Defer check (0.3). Resolve the driver: `verify.browser`, then a project harness, then Playwright or Cypress, then DevTools MCP with an isolated profile. Credentials come from the project's documented source, never inline. `[AD browser-testing:62-70]`
  2. Doctor. `[PS create:28]`
  3. Probe the target page; report whether it settled. `[USR]`
  4. Drive every entry point in the matching feature file, or list skipped ones with the unmet precondition. `[PS feature map README:31-36]`
  5. Mutation proof by reload or a read-only data query. `[README:28]`
  6. Optional regression lane on the base branch. `[PS autopilot-full:8]`
  7. Cleanup; confirm the evidence still exists. `[PS create:31,40]`
  - `--init`: interview the repo, write driver config and 3-5 feature files, prove one feature end to end, propose profile keys. `[PS create-verification-skill]`
  - `--audit`: maintain pass; proposes map fixes; writes only on approval. `[PS maintain-verification-skill]`
- Size: SKILL.md 6 KB, `references/feature-map-format.md` 2 KB.

---

## 8. Commit, finish branch, open PR

Job `finish-branch`. Integrate finished work the user's way, with a fresh base, clean commits and a reviewer-ready draft PR. Phase: end of a branch.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| finishing-a-development-branch | SP | 7,781 | auto | Verify, detect worktree, confirm base, fixed menu, typed discard |
| opening-a-pr | PS pb | 5,587 | slash | PR body sections; narrow PRs; opening is not babysitting |
| pause-safely | PS pb | 1,135 | slash | Safe boundary, no irreversible step, resume note |
| pr | PO | 4,169 | auto | Summary visual, before/after evidence, merge danger door and blast radius |
| git-workflow-and-versioning | AD | 14,141 | auto | Atomic commits, change summary, pre-commit hygiene, semver |
| setup-pre-commit | PO | 2,258 | auto | Husky + lint-staged + typecheck + tests |

Strongest mechanisms to keep:

- Run the suite on the tree you will integrate. `SP finishing-a-development-branch/SKILL.md:14-26,216`.
- `GIT_DIR` vs `GIT_COMMON` detects a linked worktree. `SP ...:30-44`. G1 reuses it to identify the primary tree.
- Confirm the base before integrating. `SP ...:46-51`.
- Fixed menu, then wait. `SP ...:53-82`.
- Discard only on the typed word `discard`. `SP ...:132-157`.
- Never `--force` a refused worktree removal. `SP ...:177-198`.
- Rejected push means investigate. `SP ...:225`.
- Keep the worktree after a PR opens. `SP ...:126`.
- PR body as a one-minute briefing: Why, What changed, Scope, Tradeoffs, Blast Radius, Verification. `PS opening-a-pr.md:13-22`.
- Before/after evidence. `PO pr/SKILL.md:158-164`.
- One-way vs two-way door. `PO pr/SKILL.md:166-170`.
- "Things I didn't touch". `AD git-workflow-and-versioning/SKILL.md:200-209`.
- Separate refactor from feature. `AD ...:96-109`.
- Opening a PR does not start a babysit. `PS opening-a-pr.md:32`.
- Pause leaves a resume note and takes no irreversible step. `PS pause-safely.md:3,6,8`.

Drop:

- "Open every PR ready, never as a draft". `PS opening-a-pr.md:30`.
- Hardcoded Conventional Commits and "commit liberally". `PS opening-a-pr.md:7,11`, `AD git-workflow-and-versioning/SKILL.md:81-94`. Replaced by `commit.subject_regex` or detected style.
- `git reset --hard origin/<branch>` between tasks. `PS opening-a-pr.md:5`.
- `wip:` commit to pause. `PS pause-safely.md:7`.
- Merge locally with `git checkout <base>`. `SP ...:86-111`.
- `git reset --hard HEAD` as save-point recovery. `AD ...:189`.
- Hardcoded `feature/` names and "squash destroys the narrative". `AD ...:138-145,319`.
- Husky install, full tests at commit time, auto-commit. `PO setup-pre-commit/SKILL.md:21-45,81-85`.

Merged spec:

- `finish-branch`, phase, slash. Every step ends in an outward choice.
- Description (266 chars): "Finish a branch: verify on the tree to integrate, self-review, check base freshness and size, then offer commit / push / draft PR / keep and wait. Dedups before any push, follows the project's commit and PR conventions, never merges. /finish-branch [commit|pr|pause]"
- Extension points: `branch.*`, `commit.*`, `push.policy`, `pr.policy`, `pr.template`, `pr.dedup`, `branch.hotfix_base`, `pr.backport_to`, `deploy.envs`, `tracker`, `overrides.finish-branch`.
- Steps:
  1. Defer check (0.3). Branch and worktree check; refuse on `branch.protected`. `[SP finishing:30-44]`
  2. `git fetch origin <base>`; report ahead and behind; propose a rebase if stale, run it only on approval. `[SP finishing:46-51]`
  3. `prove-it` on `verify.task`. `[SP finishing:14-26]`
  4. `self-review`, then `comment-hygiene` on the diff. `[PS opening-a-pr:9]`
  5. Size gate: more than 4 files or about 300 changed lines proposes a split. `[AD code-review-and-quality:107-111, USR]`
  6. Menu, then wait: 1 commit, 2 commit and push, 3 push and open a PR per `pr.policy`, 4 keep. Discard needs the typed word. Under autopilot the menu resolves to 3 with a draft PR. `[SP finishing:53-82,132-157]`
  7. `commit` mode: stage named files only; subject from `commit.subject_regex`, `commit.id_from_branch` or detected style; apply `commit.attribution`; commit; stop. `[AD git-workflow:211-230]`
  8. Dedup before push or PR; a PR at this head means report and stop. `[USR]`
  9. `pr` mode: body from `pr.template`, else framework `pr-body.md`; base from the target env; URL reported; worktree kept. Hotfix routing from `branch.hotfix_base` and `pr.backport_to`. `[PS opening-a-pr:13-22, PO pr:158-170]`
  10. `pause` mode: resume note in the scratchpad; no commit unless asked. `[PS pause-safely]`
- `references/pr-body.md`: Why, What changed, Scope (with didn't touch), Merge danger (door, blast radius), Verification (before/after, commands). 2 KB. SKILL.md 6 KB.

---

## 9. Ship, deploy proof, rollback, observe

Job `ship-check`. Decide go or no-go for a promotion, prove what is running, and leave a rollback path and telemetry. Phase: after merge, through handoff.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| shipping | PS pb | 5,439 | slash | Non-author verdicts, contiguous verified run, patch-id validity |
| autopilot-full / autopilot-stack | PS pb | 9,431 / 5,031 | slash | One owner per PR, swarm verdicts, root audits |
| shipping-and-launch | AD | 11,515 | auto | Pre-launch checklist, rollout thresholds, rollback template |
| /ship | AD cmd | 4,601 | slash | Three-persona fan-out, GO/NO-GO, rollback mandatory |
| ci-cd-and-automation | AD | 11,332 | auto | Gate pipeline, flags, rollback workflow |
| observability-and-instrumentation (+ checklist) | AD | 13,948 + 5,129 | auto | On-call questions first, structured logs, RED, symptom alerts |
| wizard (+ template.sh) | PO | 4,123 + 9,498 | auto | Bash script walks a human through steps only they can do |

Strongest mechanisms to keep:

- A verdict comes from an agent that did not write the code; CI green and bot approval are not verdicts. `PS shipping.md:7`.
- Patch-id rule: compare `git patch-id` of base..head at the verdict with now; reuse a verdict only when equal. `PS shipping.md:9`.
- Land only the contiguous verified run and report the ceiling. `PS shipping.md:8`. Maps to any ordered `deploy.envs` chain.
- `autoMergeRequest` is not readiness; explicit hard-fail conditions. `PS shipping.md:12,14`.
- State-then-wait; a stop means zero writes. `PS autopilot-full.md:5,11`, `PS autopilot-stack.md:3`.
- Count only side effects as progress; a lane past its runtime with none is stuck. `PS autopilot-full.md:10`.
- Rollback plan mandatory before GO; a blocker means NO-GO unless the user accepts. `AD cmd:ship.md:70-71`. Template with DB considerations. `AD shipping-and-launch/SKILL.md:259-284`.
- One-way vs two-way door. `PO pr/SKILL.md:166-170`.
- First-hour checks after deploy. `AD shipping-and-launch/SKILL.md:231-242`.
- On-call questions before telemetry. `AD observability-and-instrumentation/SKILL.md:27-40`.
- Entry-point field next to the correlation ID when several starters write one log. `AD ...:91-104`.
- Verify telemetry by forcing an error and finding it by request ID. `AD ...:190-197`.
- Never skip a gate or disable a rule to pass; CI never holds production secrets. `AD ci-cd-and-automation/SKILL.md:54,281`.
- Wizard: the agent writes the script, never runs it, traces it statically, hides secrets, confirms before irreversible steps. `PO wizard/SKILL.md:37-43`.

Drop:

- Owners merging, hourly `/loop` audits, cloud agents, ready-not-draft. `PS autopilot-full.md:6,9-10`.
- Shipping steps that rebase, retarget and merge. `PS shipping.md:10-11`. Under `merge.policy: human` the plugin prepares and the human lands.
- Canary percentages, error budgets, Web Vitals gates as defaults. `AD shipping-and-launch/SKILL.md:110-155,244-255`. Optional reference text.
- Rollback by `git revert && git push`. `AD ...:272`. Rollback follows the project's promotion path.
- Auto-merge and Actions YAML templates. `AD ci-cd-and-automation/SKILL.md:56-162,307`.
- `/ship` fan-out every time. `AD cmd:ship.md:68`. Reuse round-1 review results when the patch-id matches.

Merged spec:

- `ship-check`, command, slash. Never runs under autopilot; G1 and G15 deny merge and deploy there.
- Description (259 chars): "Go/no-go for a release or env promotion, proof of what is deployed, or a handoff draft. Reuses verdicts only when the patch-id matches, requires a non-author verdict and a rollback plan, and reads deploy state the project's way. /ship-check <pr|env sha|issue>"
- Extension points: `deploy.envs`, `deploy.proof`, `merge.policy`, `handoff.policy`, `tracker`, `tracker.write_policy`, `verify.browser`, `overrides.ship-check`.
- Steps:
  1. Defer check (0.3). Mode `go`, `deployed` or `handoff`.
  2. Locate the change in the `deploy.envs` chain with `git branch -r --contains <sha>`. Without envs, use the base branch only.
  3. Verdict validity with `verdict-valid.sh` (G11); stale verdicts rerun. `[PS shipping:9]`
  4. Require a non-author verdict: an `independent-review` result and a `runtime-verify` run on the source env. `[PS shipping:7]`
  5. Door, blast radius, rollback plan, including whether each new migration's down path ran. `[PO pr:166-170, AD shipping-and-launch:259-284]`
  6. GO / NO-GO; a blocker means NO-GO unless the user accepts the risk in writing. `[AD cmd:ship.md:70-71]`
  7. `deployed`: `deploy.proof` for `{env}` and `{sha}`; default is the CI run for the merge SHA plus a version read; then a `runtime-verify` smoke on that env. `[AD shipping-and-launch:231-242]`
  8. `handoff` (when `handoff.policy` is set): re-test steps and evidence drafted; tracker writes wait for approval.
- References: `rollback.md` (2 KB), `observability.md` (AD checklist subset, 3 KB), `ci.md` (gate list, flake policy, 1.5 KB). SKILL.md 6 KB.
- `wizard`: optional slash skill carried as is (4 KB + 9.5 KB template). Low priority.

---

## 10. Quality bar and guard hooks

Job: make the bar mechanical so a red check cannot turn green by weakening it, and stop unsafe git, forge, deploy and tracker actions before they run. Phase: every tool call that could cross the safety floor.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| constraint-driven-development (+ floor-guard) | AD | 21,008 + 10,681 | auto | Written bar with numbers, placement by cost, diff guard |
| /constraints | AD cmd | 2,762 | slash | Interview, CONSTRAINTS.md, check / guard sub-commands |
| git-guardrails-claude-code (+ script) | PO | 2,313 + 507 | auto | PreToolUse Bash, exit 2 on dangerous git |
| simplify-ignore hook | AD hk | 16,481 + 4,702 | hook | Hides marked blocks from the model by rewriting files in place |
| sdd-cache hooks | AD hk | 4,261 + 4,567 + 8,398 | hook | WebFetch cache served only after a 304 revalidation |

Strongest mechanisms to keep:

- Floor-guard contract: input includes untracked files; exit 0 clean, 1 violation, 2 could not run, and 2 never reads as 0; report rule and location, never a secret value. `AD floor-guard.md:7-13`.
- Weakening moves incl. `istanbul ignore`, `nosemgrep`, `gitleaks:allow`. `AD constraint-driven-development/SKILL.md:206-212`.
- Tightening is silent, loosening is loud. `AD ...:214`.
- Keep at least one external check. `AD ...:218-224`.
- Placement by cost: seconds after an edit, under 90 s at task end, CI for the rest. `AD ...:186-200`. This is the `verify.fast/task/full` split.
- Measure today's value and refuse to fall below it, 0.5% tolerance. `AD ...:226-232,248`.
- Exceptions carry owner and expiry. `AD ...:133-137`.
- `gitleaks --redact` is mandatory. `AD ...:164`.
- PreToolUse exit 2 with a stderr reason. `PO git-guardrails-claude-code/SKILL.md:18`, `scripts/block-dangerous-git.sh:18-23`.
- Regex guards stop the cheap road to green, not a determined adversary. `AD floor-guard.md:182`.

Drop:

- simplify-ignore. Placeholders stay in files on disk all session (`AD hk:simplify-ignore.sh:11`); any other process reading the tree sees broken code.
- PO blanket `git push` deny (`PO block-dangerous-git.sh:7`); its substring regexes miss `git -C <dir> push`, `git switch`, `git stash`, `git checkout <branch>`.
- Writing `CONSTRAINTS.md` plus a CLAUDE.md line, and the interview (`AD constraint-driven-development/SKILL.md:57-140`). Projects keep their bar where they already keep rules; the profile carries the command keys.
- sdd-cache (research cluster).

Merged spec: no skill. `hooks/hooks.json` plus the scripts below.

---

## Deterministic guards

Packaging. All guards ship in the plugin as `hooks/hooks.json` plus bash scripts under `${CLAUDE_PLUGIN_ROOT}/hooks/`. They need bash, POSIX tools and `git`; `gh`, `jq` and `gitleaks` are optional and detected. No project paths: the repo comes from `git rev-parse --show-toplevel`, config from `$CLAUDE_PROJECT_DIR/.claude/workflow.yml`, `.local.yml`, then `~/.claude/workflow.yml`.

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/bash-guard.sh\"" }] },
      { "matcher": "mcp__.*", "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/mcp-write-guard.sh\"" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/floor-guard.sh\" --stop" }] }
    ]
  }
}
```

`bash-guard.sh` dispatches G1-G6, G13 and G15 in one process per Bash call. Shared `hooks/lib.sh` provides `json_get` (jq when present, else a sed extractor for `.tool_input.command` and `.tool_name`), `profile_get <key> <default>`, `decide allow|ask|deny <reason>` (emits `hookSpecificOutput.permissionDecision`), `advise <text>` (emits `additionalContext`), `in_primary_tree` (`git rev-parse --git-dir` equals `--git-common-dir`) and `autopilot_on` (`autopilot: allowed` and `PLUGIN_AUTOPILOT=1`). When input cannot be parsed the hook decides `ask`, or `deny` under autopilot, never allow (AD `floor-guard.md:11`). Matching normalises whitespace and scans the whole command string, so `&&`, `;`, `|` and `bash -c` chains still match.

"Default ON" means active as soon as the plugin is installed; `guards.<id>: off` disables it per project. "Opt-in" means inactive until the project sets the listed key.

| # | Guard | Event | Interactive default | Autopilot | Profile keys | Source idea |
|---|---|---|---|---|---|---|
| G1 | git and merge safety | PreToolUse Bash | ON. Primary tree: `checkout <branch>`, `switch`, `reset --hard`, `stash`, `clean -f`, `branch -D`, `worktree remove --force` ask. Push asks. Force push denied. `gh pr merge` asks. Handles `git -C`. | Stricter: primary-tree ops deny; push to `branch.protected` deny; force push deny; merge deny. Looser: push of the current non-protected branch allowed. | `guards.primary_tree`, `push.policy`, `force_push.policy`, `merge.policy`, `branch.protected` | PO git-guardrails; SP finishing:177-198,225 |
| G2 | PR create | PreToolUse Bash on `gh pr create`, `gh pr ready` | ON. Missing `--draft` denied under `pr.policy: draft-*`; an existing PR for the head denied (dedup); otherwise ask. | Looser: draft create allowed after dedup passes. Stricter: non-draft and `gh pr ready` deny. | `pr.policy`, `pr.dedup` | target safety floor; USR dedup |
| G3 | review post | PreToolUse Bash on `gh api .../reviews`, `gh pr review` | ON. Self-approve and self-request-changes denied; inline bodies without a `review.taxonomy` prefix denied; post asks. | Stricter: all review posting deny. | `review.taxonomy`, `review.post_policy` | USR one-call posting |
| G4 | untrusted text | PreToolUse Bash on `gh api`, `gh pr comment`, `gh pr review`, `gh issue comment` | ON. `-f body=` and `--body "...$(...)..."` denied; `--input <file>` or `--body-file` required. | Same. | none | PS babysit:22; AD doubt-driven:135 |
| G5 | commit convention | PreToolUse Bash on `git commit`, `git add` | ON. Commit asks per `commit.policy`. Subject checked against `commit.subject_regex` and `commit.id_from_branch` when set. Trailers checked per `commit.attribution`. `git add -A` / `git add .` asks per `guards.explicit_staging`. Reads `-m` values and `-F` files. | Looser: commit allowed when the convention checks pass. Stricter: `git add -A` / `.` deny; a failed convention check deny. | `commit.*`, `guards.explicit_staging` | AD git-workflow:211-230 |
| G6 | secret scan | PreToolUse Bash on `git commit`, `git push` | ON. Staged diff (commit) or outgoing range (push): `gitleaks protect --staged --redact` when installed, else a redacted grep for private-key headers, `AKIA[0-9A-Z]{16}`, `gh[pousr]_[A-Za-z0-9]{20,}`, `xox[baprs]-`, `sk-[A-Za-z0-9]{20,}`, `-----BEGIN .*PRIVATE KEY-----`. Hits deny with rule and path only. Paths in `guards.never_commit` deny. | Same. | `guards.never_commit` | AD constraint-driven:164; AD hardening-patterns:289-295 |
| G7 | floor guard | Stop, plus called by `self-review` and `independent-review` | Opt-in on Stop (`guards.floor_stop: advisory`), always available as a script. Diff vs merge base incl. untracked: new suppressions, `.skip`/`xit`/`@pytest.mark.skip`/`t.Skip`, deleted test files, removed assertions in kept tests, empty catch, debug prints, `TODO` stubs. Exit 0/1/2. | Stricter: ON at Stop and blocking; the agent must fix or record each finding before stopping (`stop_hook_active` prevents a loop). | `guards.floor_stop`, `guards.floor_extra` | AD floor-guard.md, rewritten in bash + awk |
| G9 | claim checks | script | On demand (`self-review`). Cited SHAs in added lines reachable and on base; absolute words in added comments listed for evidence. | Same. | none | USR |
| G10 | probe | script `probe.sh <file> <test-cmd>` | On demand. Fail-then-pass on a file copy, restored by `trap`; prints `inconclusive` on compile failure. | Same. | none | SP verification:82-86; AD code-review-and-quality:164 |
| G11 | verdict validity | script `verdict-valid.sh <verdict-sha> <head> [base]` | On demand. Exit 0 when `git patch-id --stable` matches, 1 otherwise, 2 on error. | Same. | none | PS shipping:9 |
| G12 | CI classify | script `ci-classify.sh <pr>` | On demand. Stale base via `merge-base --is-ancestor`, retry count, identical repeat failure; refuses a second rerun. | Same. | none | PS babysit:21 |
| G13 | protected targets | PreToolUse Bash | Opt-in: active once `guards.protected_targets` lists anything. Denies `scp`, `rsync`, `sftp put` toward a listed host, and mutating statements (`INSERT`, `UPDATE`, `DELETE`, `ALTER`, `DROP`, `TRUNCATE`, `LOCK`, `SET GLOBAL`) sent through `ssh`, `mysql`, `psql` or a CLI whose args contain a listed host, DSN substring or cloud profile. | Same. | `guards.protected_targets` | generic read-only production pattern (USR) |
| G14 | tracker and chat writes | PreToolUse `mcp__.*` | ON. Asks when the server is in `guards.mcp_write_servers` and the tool name has a write verb (`create`, `save`, `update`, `delete`, `comment`, `post`, `send`, `merge`, `transition`). | Stricter: deny. | `tracker.write_policy`, `guards.mcp_write_servers` | target safety floor |
| G15 | deploy and publish | PreToolUse Bash | ON. Asks on `gh workflow run`, `gh release create`, `npm publish`, `cargo publish`, `twine upload`, `terraform apply`, `kubectl apply`/`rollout`, `helm upgrade`, `aws ... update-service`/`deploy`, and pushes to a `deploy.envs` branch, plus anything in `deploy.commands`. | Stricter: deny. | `deploy.commands`, `deploy.envs` | AD shipping-and-launch; target "never deploy" |

G8 (edit-time typecheck) is dropped. That cost and command belong to each project.

To confirm with `cc-plugin-mechanics` before building: `${CLAUDE_PLUGIN_ROOT}` expansion in plugin `hooks.json`; `permissionDecision: "ask"` and `"allow"` from PreToolUse; Stop-hook blocking and the `stop_hook_active` field; whether plugin hooks and project hooks both run for the same event.

Rejected as a hook: a Stop hook that blocks "done" without a test run. No deterministic signal separates a real verification from a partial one; `prove-it` keeps that job.

---

## Gaps and cross-cluster dependencies

Gaps no source fills:

- Round 2+ review needs a durable last-reviewed head. No source stores one; the `<!-- reviewed-head: <sha> -->` marker is new.
- Migration rollback proof. AD asks for a rollback plan (`shipping-and-launch:276-278`) but nothing runs the down path before promotion.
- Multi-tenant authorization. Sources check ownership by user id only; tenant scoping comes from `security.rules`.
- Env-chain proof of the running version. PS covers merge stacks and AD covers canaries; `deploy.proof` is new.
- Hook output visibility. No source checks that a hook's message reaches the model; every guard here uses JSON decisions or exit 2.
- Defer detection by description is fuzzy. `overrides.<job>` is the deterministic path, so `runtime-verify --init` and first-run setup should offer to write it.

Cross-cluster dependencies:

- All clusters: one shared `project-contract.md` and one `workflow.yml` key namespace. Keys here (`verify.*`, `tracker`, `spec.source`, `commit.*`, `branch.*`, `autopilot`) overlap with build, define and meta.
- Build: the autopilot run loop and its stop conditions (0.5), TDD red-first (`prove-it` step 4, G10), debugging handoff from `receive-review` step 7, worktree creation assumed by `finish-branch`.
- Define: `spec.source` and acceptance-criteria format for `spec-reviewer` and `prove-it` step 5.
- Meta: skill frontmatter rules, job ids for the defer rule, the `lessons.file` evolve loop, `unslop` for PR bodies, session pickup for `finish-branch pause`.
- `cc-plugin-mechanics`: the hook semantics listed under the guards, and whether `disable-model-invocation` removes a skill from the description budget.

---

## Appendix A: example profile (illustrative)

```
commit.subject_regex: ^[A-Z]+-[0-9]+: 
commit.id_from_branch: ^([A-Z]+-[0-9]+)
commit.attribution: none
branch.naming: <id>/<slug>
tracker: linear
tracker.id_regex: [A-Z]+-[0-9]+
review.taxonomy: Bug,Suggestion,Nit,Pre-existing Warning
lessons.file: .claude/lessons-learned.md
verify.browser: node scripts/session.mjs --env {env} --probe {path}
deploy.envs: staging=main,qa=qa,uat=uat,production=production
branch.hotfix_base: production
pr.backport_to: main
handoff.policy: qa
guards.primary_tree: deny
guards.protected_targets: legacy-prod-host
overrides.independent-review: pr-review
overrides.receive-review: resolve-pr-comments
autopilot: allowed
```

## Appendix B: CDS repo findings (outside framework scope)

1. `.claude/rules/3-workflow/pr-review-conventions.md` lets agents squash-merge approved PRs on their own. With the plugin installed, G1 asks on every merge unless the profile sets `merge.policy: ask`.
2. `.claude/skills/commit/SKILL.md:7-8` creates a branch from main in the current tree and pushes without asking. G1 and G5 will ask on both.
3. The `.claude/settings.json` PostToolUse tsc hook ends in `|| true` with plain stdout. The repo's own `scripts/hooks/browser-verification-reminder.sh:4-8` notes that exit-0 plain stdout from a tool hook never reaches the model, so the hook very likely never surfaces an error (inferred, not run).
4. The repo has four overlapping review skills (`pr-review`, `pr-review-unified`, `pr-review-v2`, `review-pr`). None of its cluster skills has frontmatter, so each is model-auto with its title as the description. `overrides.independent-review` picks one.
