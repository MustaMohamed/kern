# Merge map: understand and define

Read-only design research. Nothing was installed or executed from the sources.

**Target.** A personal, portable Claude Code plugin used across many projects and stacks. Project rules (CLAUDE.md, `.claude/rules/**`, a profile file) fill named extension points; the skills hold no project content. CDS appears only as a worked example that the extension points must be able to express.

**Source keys.** SP = `superpowers/6.4.1/skills`. PS = `pstack/skills`. PB = `pstack/skills/poteto-mode/playbooks`. PO = `pocock/skills/skills`. AD = `addy/agent-skills/skills`. ADC = `addy/agent-skills/.claude/commands`. CDS = the cds-app-rewrite `.claude/rules` and `CLAUDE.md` (example project). Line refs are `file:line` inside each source.

**Invocation model.** "slash" means `disable-model-invocation: true`. Per the Claude Code skills docs, a slash-only skill's description is not loaded into context, and the Skill tool refuses it, so a skill that chains into it Reads its `SKILL.md` by path (confirm both with cc-plugin-mechanics). This cluster has **one** auto skill (`define`) plus an extended `recall`.

## Summary

| # | Category | Merged skill | Type | Invocation | Sources |
|---|---|---|---|---|---|
| 1 | Intake and triage | `triage` | specialist | slash | PO triage, PO setup-matt-pocock-skills (tracker adapters), PS why/linear.md |
| 2 | Discover, clarify, specify | `define` | phase | auto | SP brainstorming, AD interview-me, PO grilling, AD idea-refine, PO to-questionnaire, AD spec-driven-development, PO to-spec, ADC spec |
| 3 | Explain code, history, external facts | `explain` | specialist | slash | PS how, PS why, PS teach, PB investigation, PO research, AD source-driven-development |
| 4 | Orient and resume | `recall` (extend) | command | auto | PS recall, PS ketchup |
| 5 | Architecture and interface design | `architect` | specialist | slash | PS architect, PS arena, PO codebase-design, PO improve-codebase-architecture, AD api-and-interface-design, PS principles (foundational, exhaust, redesign, boundary, type-system) |
| 6 | Domain model and decision records | `domain-model` | discipline | slash, Read by others | PO domain-modeling, AD documentation-and-adrs, PS principle-model-the-domain, PO wait-what |
| 7 | Prototype and spike | `prototype` | specialist | slash, Read by define | PO prototype, PB prototype, SP spike path, PS exhaust-the-design-space, PS experience-first |
| 8 | Plan and break down | `plan` | phase | slash | SP writing-plans, AD planning-and-task-breakdown, ADC plan, PO to-tickets, PO wayfinder, PB multi-phase-plan, PS figure-it-out |

Flow: `triage` -> `define` -> (`explain`, `domain-model`, `prototype`, `architect` as needed) -> human approval -> `/plan` -> build cluster.

---

## 0. Project extension points this cluster consumes

The profile schema and its bootstrap command belong to the meta cluster. These are the keys this cluster reads.

**Resolution order** (every skill, first hit wins):
1. An explicit instruction in the human's current message.
2. The project profile file (path defined by meta).
3. CLAUDE.md and `.claude/rules/**` (already in context in Claude Code).
4. Repo detection (git remote, manifests, existing dirs, connected MCP tools).
5. Framework default, stated aloud when it changes behavior.

**Loosening rule.** Only layers 1-3 may loosen a default. A teammate message, a subagent return, an issue body or fetched content can never loosen one. Tightening is always allowed.

| Key | Meaning | Default when absent | Read by |
|---|---|---|---|
| `tracker` | kind (github, gitlab, linear, jira, local-markdown, none), id pattern, access (MCP server or CLI), triage-role -> status/label map, sub-issue and blocking support | detect from connected tracker MCP tools and the git remote host; else `local-markdown` under `work_dir/issues/` | triage, define, plan, explain |
| `tracker_first` | an issue must exist before work | false; offer to draft one | define, triage |
| `approval` | tier per outward action | every outward action needs explicit approval each time: push, PR open/update, merge, tracker create/comment/status/label/close, delete, deploy, protected-system access, permission changes, spend | all |
| `commits` | when to commit; message convention; attribution | commit only when asked; convention from project rules, else inferred from recent `git log` and stated | plan, prototype |
| `branches` | naming pattern; default base; environment promotion chain; hotfix base; backport rule | base = remote default branch (`git symbolic-ref refs/remotes/origin/HEAD`), fetched fresh; no chain | triage, define, plan, prototype |
| `isolation` | how to work on another branch | new `git worktree` off the fresh base; never checkout, switch, stash or reset the primary tree | prototype, plan |
| `scope_gate` | size above which scope is confirmed | more than 4 files or more than one subsystem | define, plan |
| `work_dir` | where specs, plans, maps, questionnaires live | `.scratch/` if `git check-ignore -q .scratch` passes, else ask; never committed unless asked | define, plan, triage, prototype |
| `docs` | ADR dir, glossary path, spec convention | detect (`docs/adr`, `docs/decisions`, `.adr-dir`, `GLOSSARY.md`, `CONTEXT.md`); none found: propose and ask | domain-model, define, architect |
| `verify` | test, typecheck, lint, build commands | detect from manifests, Makefile, CI config; state what was detected | plan, prototype |
| `browser` | UI verification command (sign-in, probe, screenshot) | none: use available browser tooling, name it, never handle credentials directly | triage, prototype |
| `sources` | evidence sources beyond git (docs, chat, observability, errors, analytics) | discover from connected MCP tools; list skipped ones with the reason | explain, recall |
| `protected` | systems agents may only read (production DBs, legacy hosts) | anything production: read-only | triage, explain, prototype |
| `checklists` | project must-checks injected into spec, design and plan | generic three: existing-consumer and existing-data compatibility, authorization scope, persisted-schema change | define, architect, plan |
| `stack` | languages, frameworks, versions | detect from manifests; load `references/stacks/<name>.md` when present | explain, architect, prototype, plan |

**Fit check against the CDS example.** tracker = Linear MCP, id `CDS-\d+`, tracker_first = true. commits = only when asked, `CDS-XXXX:` prefix, no attribution. branches = `CDS-XXXX/<slug>`, base `origin/main`, chain main -> qa -> uat -> production, hotfix off `origin/production` with a uat PR first and a main backport. scope_gate = 3-4 files. browser = `node scripts/cds-session.mjs --probe <path>`. protected = V1 host and prod. checklists = legacy records (rule 21), server-side authz (rule 15), swagger regen (rule 7), `migration:create`. approval loosening = reversible tracker comments by the verifier. Every CDS rule the cluster touches maps to a key, so no skill needs CDS text.

---

## 1. Intake and triage

**Job.** Decide whether an issue is real, new and ready, then draft an agent brief or a needs-info note. **Phase.** Intake, before define.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| triage | PO | 6558 (+12609 refs) | slash | category + state roles; verify the claim; agent brief; out-of-scope record |
| setup-matt-pocock-skills | PO | 6978 (+12842 refs) | slash | per-repo tracker, label and domain-doc config with GitHub, GitLab, local-markdown and freeform adapters |
| why/references/sources/linear.md | PS | 2996 | reference | walk the issue tree; scope drift; duplicate chains |
| CDS verify-before-implement, dedup | CDS | n/a | example rule | gap checked on every target branch; dedup before outward action |

**Strongest mechanisms to keep**
- Redundancy check by domain concept, reporting where it looked; "already implemented" closes without being recorded as a rejection. PO `triage/SKILL.md:70`, `OUT-OF-SCOPE.md:86-88`. Concept search beats wording search, and keeping built features out of the rejection record keeps dedup honest.
- Verify the claim before any grilling, with three outcomes: confirmed with code path, failed, insufficient detail. PO `triage/SKILL.md:74`.
- Recommend category and state with reasons, then wait. PO `triage/SKILL.md:72`.
- Agent brief: durable (no paths or line numbers), behavioral not procedural, testable ACs, explicit out of scope, current vs desired behavior. PO `AGENT-BRIEF.md:9-68`, bad example `:185-207`.
- Needs-info notes keep "established so far" plus specific questions; a resumed session reads prior notes and does not re-ask. PO `triage/SKILL.md:94-112`.
- Prior-rejection lookup by concept similarity. PO `OUT-OF-SCOPE.md:72-82`.
- Walk sub-issue to parent (parents hold the why); read the full history for scope drift and duplicate chains. PS `why/references/sources/linear.md:21,35-38`. Tracker-agnostic despite the filename.
- Canonical roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) mapped to tracker strings in one table. PO `setup-matt-pocock-skills/triage-labels.md:5-13`. This becomes the `tracker` key's role map.
- Tracker adapters as small docs with the same operation names (create, read, list, comment, label, close, sub-issue, blocking) per tracker, including a local-markdown tracker for repos without one. PO `setup-matt-pocock-skills/issue-tracker-{github,gitlab,local}.md`; "other" as freeform prose `SKILL.md:47,114`. This is what makes triage portable.
- Gap checked on every branch the fix must land on, never a stale local tree. CDS `multi-agent-orchestration.md` rule 4. PO checks one tree only.
- Dedup again right before any outward action. CDS `multi-agent-orchestration.md`, "Concurrency / git".

**Drop**
- Posting, labelling and closing inside the flow. PO `triage/SKILL.md:78-86`. Default `approval` makes every tracker write a draft the human approves.
- `.out-of-scope/` directory of committed files. PO `OUT-OF-SCOPE.md:8-17,90-97`. Default record is the tracker's closed/won't-fix state plus a label; a project may opt into a docs dir through `docs`.
- "For a PR, check it out, run the tests." PO `triage/SKILL.md:74`. Breaks `isolation`; use a worktree.
- Setup editing CLAUDE.md with an `## Agent skills` block and running `gh label create`. PO `setup-matt-pocock-skills/SKILL.md:76-104`. Silent config edits and tracker writes; profile bootstrap moves to meta with propose-confirm-write.
- GitHub as the assumed default. PO `setup-matt-pocock-skills/SKILL.md:42`. Detection decides.
- Mandatory AI disclaimer on every comment. PO `triage/SKILL.md:13-17`. A profile option, off by default since the human posts.

**Merged skill spec: `triage`**
- Type specialist. Invocation slash: runs on a human's pick, reads heavily, sits next to tracker writes.
- Description (249 chars): "Triage an issue from the project tracker before work starts. Dedups against PRs and issues, checks the branches the fix must land on for an existing fix, reproduces the claim, recommends a state, and drafts an agent brief or needs-info note to post."

| Step | Action | Gate | Source |
|---|---|---|---|
| 1 | Resolve `tracker`; load the issue through its adapter: body, comments, parent, sub-issues, linked PRs; parse prior triage notes | none | PO triage:70,110-112; PS linear.md:19-23 |
| 2 | Dedup: open and closed PRs mentioning the id (`gh pr list --search <id> --state all` or forge equivalent); tracker search for duplicates and won't-fix issues by concept | open PR or duplicate: report, stop | PO OUT-OF-SCOPE:72-82; CDS dedup |
| 3 | Redundancy: search the behavior by concept on each branch in `branches` the fix must land on (`git fetch`, `git grep <pat> <remote>/<branch>`); list where it looked | none | PO triage:70; CDS rule 4 |
| 4 | Verify the claim: bug repro with `browser` or `verify` commands, never against `protected` systems; deep root cause goes to the debug cluster | report confirmed / failed / insufficient | PO triage:74 |
| 5 | Recommend category and state with reasons and a short code summary | STOP for direction | PO triage:72 |
| 6 | Needs shaping: Read `define/references/interview.md`, run frontier rounds | none | PO triage:76 |
| 7 | Draft the outcome: agent brief; ready-for-human brief with why it can't be delegated; needs-info notes; won't-fix reason (already implemented: point to the code) | tracker write per `approval`; default explicit go each time | PO triage:78-86; AGENT-BRIEF |

Queue mode (`/triage` bare): list untriaged issues and needs-info issues with reporter activity, oldest first, one line each; human picks. PO `triage/SKILL.md:56-66`.

References: `agent-brief.md` (~3KB), `adapters/{github,gitlab,linear,local-markdown}.md` (~1.5KB each, same operation names; others described in the profile as freeform). SKILL.md ~4.5KB.

---

## 2. Discover, clarify and specify

**Job.** Turn an ask into an approved shared understanding and, for architectural work, an approved spec, before any code. **Phase.** Define.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| brainstorming | SP | 17548 (+1747 reviewer, +13413 visual guide, ~49KB scripts) | auto | spike / bounded / architectural paths; hard approval gate; spec + self-review |
| interview-me | AD | 15080 | auto | hypothesis + confidence; one question at a time with a guess; explicit-yes gate; predict-next-three stop |
| grilling | PO | 2049 | auto | design tree; whole frontier per round with recommended answers; facts by subagent |
| grill-me, grill-with-docs | PO | 157, 247 | slash | aliases for grilling (+ domain-modeling) |
| idea-refine | AD | 8111 (+31426 refs) | auto | HMW restate; 5-8 variations; converge to 2-3; assumption audit; Not Doing list |
| to-questionnaire | PO | 2904 | slash | interview about the send; async questionnaire for whoever holds the knowledge |
| spec-driven-development | AD | 13096 | auto | capability map; assumptions block; success criteria; stop turn after spec |
| spec (command) | ADC | 913 | slash | entry to spec-driven-development |
| to-spec | PO | 3043 | slash | spec synthesized from conversation; agree test seams |
| principle-experience-first | PS | 1184 | slash | every feature justified; the next maintainer is a user |

**Strongest mechanisms to keep**
- Classify spike / bounded / architectural, say it out loud, take the heavier path when in doubt, upgrade mid-task and never downgrade. SP `brainstorming/SKILL.md:58-88`. The only source that scales the gate down to a two-sentence design instead of exempting small work (AD `spec-driven-development:20` opts out).
- Hard gate: approval covers only the stage presented; resume at the earliest incomplete stage; read-only exploration allowed meanwhile. SP `:38-56`.
- Red-flags table against "too simple to need approval". SP `:90-108`.
- Write back the understanding, separating what they said from assumptions. SP `:19-36`; AD `spec-driven-development:71-80` ("Correct me now or I'll proceed").
- HYPOTHESIS + CONFIDENCE, with missing items named below ~70%. AD `interview-me:40-51`.
- Two question modes split by kind. Intent questions one at a time with a GUESS, because early answers reshape framing (AD `interview-me:53-77,66-69`). Design decisions as frontier rounds: numbered, each with a recommended answer, worded so "yes" accepts it, dependent questions deferred (PO `grilling:6-26`).
- Facts are the agent's job: dispatch a subagent for lookups and keep asking the questions that don't depend on it. PO `grilling:28`.
- Want-vs-should-want probe. AD `interview-me:79-92`.
- Restate block Outcome / User / Why now / Success / Constraint / Out of scope, Out of scope mandatory. AD `interview-me:94-111`.
- Explicit yes only: "whatever you think", "sounds good" and silence are not yes. AD `interview-me:113-122`.
- Stop test: predict the reaction to the next three questions; floor: rounds without rising confidence mean step back. AD `interview-me:132-140,218`.
- Decompose first: capability map with stable module ids, one-way dependencies and build order, reviewed before any module spec. SP `:202-203`; AD `spec-driven-development:34-65`.
- Reframe vague asks as testable criteria. AD `spec-driven-development:156-168`.
- 2-3 approaches, recommendation first, YAGNI; design in sections with approval per section. SP `:209-222`.
- In existing code, only targeted improvements that affect the work. SP `:231-235`.
- Agree the test seams with the human: highest seam, fewest seams. PO `to-spec:15-17`.
- Spec is durable: no file paths or code, except a prototype snippet that encodes a decision. PO `to-spec:55-57`. Exact paths belong in the plan; resolves the SP vs PO conflict on paths.
- Spec self-review: placeholders, contradictions, scope, two-reading ambiguity. SP `:246-254`. Reviewer subagent calibrated to real planning problems only. SP `spec-document-reviewer-prompt.md:27-34`.
- Stop the turn after the spec; planning starts in a later turn. AD `spec-driven-development:170-174`, `interview-me:124-130`.
- Divergent mode for a vague idea: HMW restate, 5-8 variations by lens, converge to 2-3 directions, stress-test value / feasibility / differentiation, assumptions sorted must / should / might be true, Not Doing list. AD `idea-refine:56-138`, `refinement-criteria.md:75-113`.
- Async questionnaire: interview the human only about the send; questions aim at the gap, most important first, one idea each, answer stub under each. PO `to-questionnaire:9-52`.
- "Use the existing spec system if the project has one; this skill owns clarification and gates, the external tool owns the format." AD `spec-driven-development:150-154`. The portability rule for specs.
- Visual offer just-in-time, as its own message; per question, visual only when seeing beats reading. SP `:272-282`. The medium becomes the Artifact tool.

**Drop**
- Spec saved to `docs/superpowers/specs/` and committed. SP `:135,241-244`. Location comes from `work_dir`/`docs`; commit per `commits`.
- `SPEC.md` at repo root, `docs/intent/`, `docs/ideas/`, `idea-refine.sh` creating dirs. ADC `spec.md:17`; AD `interview-me:129,146`; AD `idea-refine:32,140`, `scripts/idea-refine.sh:6-10`.
- Commands / Project Structure / Code Style / Tech Stack sections when the project rules already hold them. AD `spec-driven-development:88-106,123-133`. Keep for greenfield only.
- "A LONG ... extremely extensive" user-story list. PO `to-spec:33-41`.
- Publishing the spec with `ready-for-agent`. PO `to-spec:19`. Tracker write without approval.
- Visual companion server and `.superpowers/` dir. SP `visual-companion.md:33-58`, `scripts/*`.
- "Create products people don't know they need yet" and the aphorism list. AD `idea-refine:45-50,80`. Pushes scope up.
- `elements-of-style` reference. SP `:243`. The framework's writing contract replaces it.
- grill-me, grill-with-docs, wait-what as separate skills. PO `grill-me:7`, `grill-with-docs:7`, `wait-what:7`. Aliases; wait-what goes to meta.

**Merged skill spec: `define`**
- Type phase. Invocation auto: the gate fails if it depends on the human remembering a command.
- Description (275 chars): "Use before building or changing behavior: a new feature, endpoint, field or flow, or an issue to implement. Also for 'grill me', 'interview me', 'stress-test this', 'ideate', 'write a spec'. Classifies spike, bounded or architectural and blocks code until the human approves."

| Step | Action | Gate | Source |
|---|---|---|---|
| 0 | Resolve profile keys. `tracker_first`: confirm an issue exists and read it; none: offer to draft one | no tracker write without approval | PO setup; PS linear.md:19-23 |
| 1 | Explore read-only: files, recent commits, related PRs; persisted shape of any stored field (schema describe, ORM model, migrations; commands in `explain/references/stacks/data-shape.md`); gap real on the target branches. Lookups go to Explore subagents | none | SP :116,123; PO grilling:28; CDS observe-before-model |
| 2 | Classify and announce. Bounded = existing flow, within `scope_gate`, no change to a shared contract (public API, persisted schema, authorization). Else architectural or an explicit scope confirmation | heavier when in doubt; upgrade only | SP :58-88 |
| 3 | Scope check: several independently testable capabilities -> capability map | map approved before any module spec | SP :202-203; AD spec-driven:34-65 |
| 4 | Intent: HYPOTHESIS + CONFIDENCE; intent questions one at a time with GUESS; want-vs-should probe; skip what the issue already states | none | AD interview-me:40-92; SP :34-36 |
| 5 | Decisions: frontier rounds with recommended answers. Term conflict: Read `domain-model/SKILL.md` | wait for answers each round | PO grilling:6-30; PO domain-modeling:44-58 |
| 6 | Restate: intent block + assumptions (said vs assumed) | explicit yes | AD interview-me:94-122; SP :25-27 |
| 7a | Spike: question + probe in 2-3 sentences -> Read `prototype/SKILL.md` -> recommendation; code stays throwaway | nod before probing | SP :65-70,106 |
| 7b | Bounded: in-chat design (approach, files, tests, each `checklists` item answered) | STOP for explicit yes, then build cluster | SP :71-80,126 |
| 7c | Architectural: 2-3 approaches -> one-way-door shape: suggest `/architect` -> sectioned design -> spec (project's spec system if any, else `references/spec-template.md`) in `work_dir` -> self-review -> reviewer subagent, round 1 only | per-section approval; STOP turn after spec; on approval ask the human to run `/plan <spec>` | SP :129-139,209-266; AD spec-driven:150-174 |
| 8 | Optional modes: `ideate` (Read `references/ideate.md`); `questionnaire` drafted for the human to send (tracker comment, chat message or file) | human sends | AD idea-refine; PO to-questionnaire |

Standing gates: no code, scaffold, dependency install, migration or branch before the path's approval (SP `:38-56`); approving a stage does not approve unpresented artifacts (SP `:51-53`); visual offers are their own message (SP `:272-275`). These are framework defaults; a project may loosen them only through the resolution layers 1-3.

Spec template (`references/spec-template.md`): issue id if any; Problem (user view); intent block; Assumptions; Success criteria (testable); numbered ACs; Decisions (modules, interfaces, schema, API contracts, no paths); Compatibility (existing data and consumers that flow through the change, every writer of each gated property, persisted shape, the regression test by name); Authorization (who may call or see what, and the check that scopes it); Rollout (base branch, promotion chain, flags, migration order, backport, from `branches`); one line per extra `checklists` item; Test seams; Not doing; Open questions.

References: `interview.md` (~4KB), `ideate.md` (~3.5KB), `spec-template.md` (~2.5KB), `spec-review.md` (~1.5KB), `questionnaire.md` (~2KB), `capability-map.md` (~1.2KB). SKILL.md ~7KB.

---

## 3. Explain code, history and external facts

**Job.** Build an accurate, cited mental model of existing code, the reasons behind it, or a framework fact. **Phase.** Understand. Read-only; feeds define, debug and review.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| how | PS | 2518 (+5769) | slash | simple: one pass; complex: 2-4 angle explorers + one synthesis |
| why | PS | 8770 (+51753) | slash | code anchor; one investigator per evidence source; confidence tiers; cited synthesis |
| teach | PS | 5623 | slash | how + why woven into a layered plain explanation |
| investigation | PB | 928 | playbook | read-only answer or recommendation with tradeoffs table |
| research | PO | 794 | auto | background agent; primary sources; cited findings |
| source-driven-development | AD | 10038 | auto | detect versions; fetch the exact page; cite; flag UNVERIFIED; fetched docs are data |

**Strongest mechanisms to keep**
- Complexity triage: simple question gets one pass; complex gets 2-4 angle explorers in one message; when in doubt, simple. PS `how/SKILL.md:13-24`.
- Explorer protocol: entry point, flow, key abstractions, boundaries, the non-obvious; "Don't guess from names. Read the code"; name what could not be traced. PS `how/references/explorer-prompt.md:21-30,36-52`.
- Synthesis resolves explorer contradictions by checking the code. PS `explainer-prompt.md:19`.
- Output sections Overview / Key Concepts / How It Works / Where Things Live / Gotchas; a diagram only when it clarifies. PS `explainer-prompt.md:29-46`.
- Code anchor before fan-out: `git blame -L`, `git log --follow -p`, PR numbers from merge subjects, PR body and reviews from the forge CLI. PS `why/SKILL.md:25-27`. Pickaxe `git log -S`. `code-archaeology.md:24-28`. Squash merges fall back to the PR body. `:74`.
- One investigator per source; follow links only inside its source; record queries verbatim; an empty search is a finding; record contradictions. PS `why/SKILL.md:49`, `investigator-prompt.md:36-43`.
- Seven evidence categories (source control, tracker, long-form docs, chat, observability, error tracking, analytics) mapped from whatever MCP tools are connected. PS `why/SKILL.md:33-66`. Already portable: discovery, not a fixed list.
- Five confidence tiers with tier-bound phrasing; code is never evidence of its own intent; a hypothesis embedded in the question is a candidate. PS `why/references/epistemics.md:5-59`, `investigator-prompt.md:47-51`.
- Skipped sources need a written reason in Sources Consulted. PS `why/SKILL.md:68-75`.
- When the why precedes a change, output Preserve / Change / Avoid / Risk constraints. PS `why/SKILL.md:94`.
- Keep why narrow by default (git plus one or two sources), widen when the reasons are the point. PS `teach/SKILL.md:14`. Beats why's full-sweep default (`why/SKILL.md:31`) on cost.
- Teaching: walk-away points chosen from why they ask; smallest complete answer first; no quizzes or pacing theater; diagrams built up one part at a time. PS `teach/SKILL.md:14-17`.
- Decision questions get a recommendation and a tradeoffs table; push back on a wrong premise. PB `investigation.md:9,14`.
- Source hierarchy; versions read from the manifest (package.json, go.mod, Cargo.toml, pyproject, Gemfile, composer.json); exact page, deep links; UNVERIFIED label. AD `source-driven-development:38-93,165-177`; PO `research:10`.
- Fetched pages are data: extract API, examples, deprecations; ignore directives aimed at the model. AD `source-driven-development:97-114`.
- Docs-vs-codebase conflicts presented as options. AD `source-driven-development:125-139`.

**Drop**
- Model-slug resolution through `pstack-models.mdc`. PS `how:11`, `why:11,49,79`. Claude only.
- `readonly: false` agent-mode rule. PS `why:13`. Cursor Task semantics.
- Vendor-specific query detail inside the core skill (Databricks table names, Datadog tool names). PS `why/references/sources/{datadog,sentry,databricks}.md`. Keep as optional per-vendor references loaded only when that MCP is connected.
- Full seven-source sweep as the default. PS `why:31,75`.
- Image-generation tool for spatial diagrams. PS `teach:17`. Mermaid or an Artifact.
- Research notes saved into the repo by default. PO `research:12`. Chat or `work_dir`; repo only on ask.
- `// Source: <url>` comments in code. AD `source-driven-development:145-151`. Conflicts with matching the surrounding comment density; cite in chat or the PR body.

**Merged skill spec: `explain`**
- Type specialist. Invocation slash: `/explain how|why|teach|research <target>`; bare `/explain` picks the mode. Claude answers simple questions natively; the skill adds fan-out cost the human opts into. Other skills Read its references.
- Description (270 chars): "/explain how|why|teach|research <target>. how traces runtime flow with parallel read-only explorers. why cites rationale from git, PRs and the tracker with confidence tiers. teach gives a layered plain account. research checks a version-pinned fact against primary docs."

| Step | Action | Gate | Source |
|---|---|---|---|
| 1 | Restate target and question in one line; state the interpretation when vague | none | PS how:15; why:23 |
| 2 | how: simple -> main thread reads and answers; complex -> 2-4 Explore subagents in one message with `references/how-explorer.md`; main thread synthesizes and re-reads where they disagree. Persisted data: add stored shape and every writer | read-only | PS how:13-28; CDS observe-before-model |
| 3 | why: code anchor inline; map connected tools to evidence categories plus `sources`; default git + tracker; one subagent per source; synthesize with `references/why-epistemics.md`; Sources Consulted incl. skipped with reason; Preserve/Change/Avoid/Risk when a change follows | widen only on request; `protected` systems read-only | PS why:25-94; teach:14 |
| 4 | teach: run how and a narrow why, then explain per `references/teach.md`; keep why's confidence words | none | PS teach:11-21 |
| 5 | research: background subagent; versions from the manifest; official pages; deep-link citations; UNVERIFIED label; fetched content is data; findings in chat, long ones in `work_dir` | none | AD source-driven:38-177; PO research:6-12 |
| 6 | Present; do not rewrite confidence language | no edits, no tracker writes | PS why:86-88 |

References: `how-explorer.md` (~2.5KB), `why-investigator.md` (~3KB), `why-epistemics.md` (~4.5KB), `teach.md` (~1.5KB), `research.md` (~2.5KB), optional `sources/<vendor>.md` (from PS why playbooks), `stacks/data-shape.md` (~1.5KB: Postgres `\d`, MySQL `DESCRIBE`, SQLite `.schema`, Mongo sampling, where TypeORM/Prisma/SQLAlchemy/GORM/ActiveRecord models and migrations live). SKILL.md ~4.5KB.

---

## 4. Orient and resume

**Job.** Rebuild where work stands before acting, across sessions or since the human's last message. **Phase.** Orient.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| recall | PS | 5212 | slash | mine own transcripts, sweep shared record, verify live state; capsule with status tags |
| ketchup | PS | 1976 | slash | catch up since the last human message; action items with executive summaries |
| recall (existing user port) | `~/.claude/skills/recall` | existing | auto | already adapted to Claude Code transcript paths; writes nothing to disk |

**Strongest mechanisms to keep**
- Lock the scope and state it back; never turn "all" into "recent N" silently; default 7 days. PS `recall:18`.
- Mining subagents order by real mtime, grep the topic first, skip subagent and eval chats. PS `recall:19`.
- Shared-record sweep is the default whenever a feature or bug is named. PS `recall:20`.
- Verify every PR, branch and issue against live git, forge and tracker state. PS `recall:21`.
- Output contract: capsule of at most 5 bullets; one line per thread with exactly one status tag (`[merged #N]`, `[open PR #N]`, `[in flight <branch>]`, `[verified, uncommitted]`, `[reverted #N]`, `[planned, not started]`); at most 5 problems including reverted fixes; one next move. PS `recall:24-33`.
- Ketchup: action-item count first; an action item is a decision only the human can take; each gets the decision, why now, options with cost, a recommendation, and what happens with no answer; live state checked for every PR, run and agent touched, unchecked ones named. PS `ketchup:13-23`.

**Drop**
- `~/.cursor/projects/.../agent-transcripts` paths. PS `recall:15`. The port fixed this.
- Hardwired why investigators in the sweep. PS `recall:20`. Use explain's discovered `sources`.
- Ketchup's dependency on the `/bro` voice. PS `ketchup:9`.

**Merged skill spec: `recall` (extend the existing skill)**
- Type command. Invocation auto, unchanged; its description is already budgeted. Ketchup becomes `/recall chat` instead of a new skill.

| Step | Action | Gate | Source |
|---|---|---|---|
| 1 | Mode: cross-session (existing) or this chat since the human's last message | none | PS ketchup:9 |
| 2 | Chat mode: gather own work, subagent reports, others' messages; check live state of each PR, CI run, agent; list what could not be checked | read-only | PS ketchup:13 |
| 3 | Reply: action-item count first; what happened, most important first; one executive summary per action item | none | PS ketchup:19-23 |
| 4 | Cross-session mode adopts the status-tag contract if the port lacks it; tracker reads go through the `tracker` adapter | none | PS recall:29 |

Size: about +1.2KB on the existing SKILL.md.

---

## 5. Architecture and interface design

**Job.** Choose the shape (types, signatures, module seams, API contracts) of one-way-door changes before code, and find deepening opportunities in existing code. **Phase.** Design.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| architect | PS | 5469 (+9151) | slash | ground via how/why; sketch via arena; design twice; red-flag screen; rationale; scrap tells |
| arena | PS | 4279 | slash | N candidates; rubric; cross-judge; pick a base; graft |
| codebase-design | PO | 6446 (+5218) | auto | deep-module vocabulary; deletion test; seam rules; design-it-twice with a constraint per agent |
| improve-codebase-architecture | PO | 6000 (+6641) | slash | git-history hot spots; friction scan; candidate report; grill the pick |
| api-and-interface-design | AD | 14886 | auto | Hyrum's law; contract first; one error shape; additive change; idempotency; TS variants |
| principle-foundational-thinking | PS | 1530 | slash | data structures first; scaffold first; concurrency question |
| principle-exhaust-the-design-space | PS | 1152 | slash | 2-3 structurally different options when there is no precedent |
| principle-redesign-from-first-principles | PS | 758 | slash | integrate a requirement as if it were day one |
| principle-boundary-discipline | PS | 1883 | slash | validate at boundaries, trust types inside, pure core |
| principle-type-system-discipline | PS | 3661 | slash | illegal states unrepresentable; brand primitives; no lying casts; exhaustive matches; derive from schema |

**Strongest mechanisms to keep**
- Ground before sketching: how on every touched subsystem; why when ownership or layering changes, so rationale becomes a constraint. PS `architect/SKILL.md:21-25`.
- Usage first: the caller's README and 2-3 call sites, types derived from them, sketch reconciled to usage. PS `architect/references/rationale-template.md:9-11`, `runner-prompt.md:9`.
- Data structures first; trace each dominant access pattern; "we'll add a cache later" means the structure is wrong. PS `runner-prompt.md:10`, `principle-foundational-thinking:11`.
- Design it twice with a different constraint per agent: minimal interface, flexibility, common caller, ports and adapters. PO `codebase-design/DESIGN-IT-TWICE.md:21-28`. Replaces arena's model diversity (PS `arena:17`), which needs non-Claude models.
- Rubric of 3-6 gradeable criteria written before fan-out; candidates see only the task. PS `arena:14-16`.
- Pick the base criterion by criterion; graft 1-2 things per loser by hand; convergence is agreement; wild divergence means reframe, never average. PS `arena:30-40`. Optional fresh cross-judge. `arena:26-28`.
- Red flags written for agent contributors: shallow module, information leakage, temporal decomposition, pass-through, split ownership, two ways to do one task, importable internals, hand-synced list. PS `architect/references/design-red-flags.md:5-57`; "the next contributor is an agent that copies the nearest example" `architect:35`.
- Fixed vocabulary with banned synonyms (module, interface, depth, seam, adapter, leverage, locality); deletion test; the interface is the test surface; one adapter is a hypothetical seam. PO `codebase-design/SKILL.md:10-65`. Language-neutral by design ("deliberately scale-agnostic", `:14`).
- Dependency category decides the test seam (in-process, local-substitutable, remote-owned port, true external mock). PO `DEEPENING.md:5-25`.
- Rationale template: Problem, Usage, Shape, Synthesis decision, Tradeoffs ("we accept X in exchange for Y"), Alternatives considered (required), Open questions phrased as questions, Next step. PS `rationale-template.md:5-35`.
- Scrap tells: one workaround repeated in unrelated code, special-case branches, escape-hatch types, "we need a lock", callers knowing internals, repeated deviations. PS `architect:55-75`. Same failure the CDS rules call "a rescue net means the design is wrong".
- Scan scoped by `git log` hot spots; candidates graded Strong / Worth exploring / Speculative with before and after; ADR conflicts raised only when friction is real; no interface proposals until the human picks. PO `improve-codebase-architecture:20-60`.
- API contract rules: Hyrum's law, one error shape, additive optional fields, input/output type split, validation at boundaries only. AD `api-and-interface-design:22-144`; PS `principle-boundary-discipline:13-34`.
- Type rules as concepts: sum types over optional-field bags, no unproven casts, exhaustive matching, types derived from the authoritative schema. PS `principle-type-system-discipline:11-18`. The source already names per-language idioms (`:16`), so the core stays neutral and idioms move to stack references.
- Idempotency: claim via unique constraint, payload-hash guard, deliberate in-flight duplicate policy. AD `api-and-interface-design:156-215`. Reference only, for state-changing external endpoints.

**Drop**
- "Default: proceed directly to implementation ... No human checkpoint." PS `architect:41-45`. The rationale review becomes a default hard gate.
- Grok runners and `pstack-models.mdc`. PS `architect:31`, `arena:17,28`.
- "The synthesis can ship as its own commit." PS `architect:47`. Commit per `commits`.
- A worktree per candidate for paper sketches. PS `arena:18`. `work_dir` subdirs; worktrees only when candidates are code.
- CDN Tailwind/Mermaid HTML written to `$TMPDIR` and opened. PO `improve-codebase-architecture:39-41`, `HTML-REPORT.md:7-34`. Private Artifact or a chat table.
- Inline glossary writes during the grilling loop. PO `improve-codebase-architecture:68-69`. Goes through domain-model with approval.
- "Old unit tests ... become waste ... delete them." PO `DEEPENING.md:34`. Deleting tests needs explicit approval.
- REST naming table, pagination template and TypeScript code in the core skill. AD `api-and-interface-design:146-154,232-321`. Moves to `stacks/rest-http.md` and `stacks/typescript.md`; the core says "match the project's existing endpoint conventions".

**Merged skill spec: `architect`**
- Type specialist. Invocation slash: `/architect <problem>` and `/architect scan [area]`. Fan-out costs 3+ subagents and pays only on one-way doors (PS `principle-exhaust-the-design-space:13-21`). define suggests it.
- Description (263 chars): "/architect for one-way-door shape decisions. Grounds in the code, sketches 2-3 structurally different interfaces in parallel, screens them against design red flags, picks and grafts, and writes a rationale for sign-off. /architect scan lists deepening candidates."

| Step | Action | Gate | Source |
|---|---|---|---|
| 1 | Need check: established pattern, clear target state, or constraints forcing one shape -> skip fan-out, write a one-candidate rationale | none | PS exhaust-the-design-space:18-21 |
| 2 | Ground: `/explain how` on touched subsystems, `/explain why` on ownership changes; record callers that cannot break, existing data, persisted shapes, writers, authorization checks, `checklists` items | none | PS architect:21-25 |
| 3 | Frame: problem, constraints, dependency categories, rubric; show the human while agents run. Load `references/stacks/<stack>.md` when present | none | PO DESIGN-IT-TWICE:9-17; PS arena:14-16 |
| 4 | Sketch: 2-3 subagents in one message with `references/runner-brief.md` and one constraint each; usage-first sketch into its own `work_dir` subdir | none | PO DESIGN-IT-TWICE:21-38; PS runner-prompt:9-20 |
| 5 | Screen each candidate against `references/red-flags.md` plus any project red flags from rules | revise or drop | PS architect:35 |
| 6 | Compare on depth, locality, seam and rubric; optional fresh judge; pick base; graft by hand; divergence -> reframe | none | PS arena:26-40; PO DESIGN-IT-TWICE:40-44 |
| 7 | Rationale with type sketch (`references/rationale-template.md`) | HUMAN approves the shape; pushback is new grounding, rerun from 2 | PS architect:49, default inverted |
| 8 | Hand to `/plan`; during build, sketch deviations get surfaced; scrap tells trigger a redesign that subtracts before adding | none | PS architect:51-75 |

Scan mode: hot spots from `git log --oneline`; one Explore subagent walks for friction with the vocabulary and the deletion test; candidates (Files, Problem, Solution, Wins, strength, dependency category, ADR or rule conflict) as a chat table or private Artifact; human picks; then define's interview reference and design mode. PO `improve-codebase-architecture:16-71`.

References: `vocabulary.md` (~2KB), `red-flags.md` (~3KB), `runner-brief.md` (~2KB), `rationale-template.md` (~2KB), `api-contracts.md` (~2.5KB, language-neutral), `deepening.md` (~1.5KB), `principles.md` (~2.5KB). Optional `stacks/`: `typescript.md` (discriminated unions, branded IDs, `never` exhaustiveness, schema parse at the boundary), `go.md` (newtypes, consumer-side interfaces, sealed-interface sums, error wrapping), `python.md` (dataclasses/pydantic at boundaries, `typing.assert_never`), `rest-http.md` (status codes, pagination, PATCH, idempotency keys), `nestjs.md` (guards, DTO validation, module seams), `react.md` (props contracts, component seams). SKILL.md ~5.5KB.

---

## 6. Domain model and decision records

**Job.** Keep one precise vocabulary for the project's concepts and record hard-to-reverse decisions so later sessions do not reopen them. **Phase.** Design and record; runs inside define, architect and triage.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| domain-modeling | PO | 3346 (+5033) | auto | challenge terms; scenarios; code cross-check; glossary inline; ADR only on 3 conditions |
| documentation-and-adrs | AD | 10910 | auto | match existing ADR convention; template; lifecycle; prose review |
| principle-model-the-domain | PS | 1858 | slash | encode the domain in a structure, not scattered conditionals |
| setup domain.md | PO | 2042 | reference | consumers read glossary and ADRs silently if present; flag ADR conflicts |
| wait-what | PO | 396 | slash | re-pitch in plain English with glossary terms |

**Strongest mechanisms to keep**
- Active challenges: a term conflicting with the glossary is called out at once; a fuzzy word gets a canonical term proposal; invented edge-case scenarios; check the code agrees with what the human says. PO `domain-modeling:44-58`.
- Glossary rules: opinionated, `_Avoid_` synonyms, one or two sentences on what it is, project-specific terms only, no implementation detail. PO `GLOSSARY-FORMAT.md:25-30`, `domain-modeling:64`.
- Single vs multi-context layout (`GLOSSARY-MAP.md` pointing at per-context glossaries), inferred from the repo. PO `GLOSSARY-FORMAT.md:32-60`. Portable across monorepos.
- ADR only when hard to reverse, surprising without context, and a real trade-off; qualifying list includes explicit no's and constraints not visible in code. PO `ADR-FORMAT.md:29-47`.
- Minimal ADR (1-3 sentences), optional sections only when they add value. PO `ADR-FORMAT.md:7-23`.
- Match the existing ADR convention (dir, extension, numbering, headings, `adr-tools`); surface a conflict instead of adding a second scheme. AD `documentation-and-adrs:36-44`.
- Never delete an ADR; supersede it. AD `documentation-and-adrs:93-100`.
- Prose review that keeps names, numbers, conditions and qualifiers. AD `documentation-and-adrs:259-265`.
- Read glossary and ADRs silently if present; flag a contradiction as "Contradicts ADR-NNNN, but worth reopening because...". PO `setup-matt-pocock-skills/domain.md:5-11,47-51`.
- Signs a structure is missing: an if/else chain that grows a branch per feature, a second boolean that must stay in sync. PS `principle-model-the-domain:13-24`.

**Drop**
- Lazy creation of `GLOSSARY.md` and `docs/adr/` without asking. PO `domain-modeling:40`, `ADR-FORMAT.md:5`. First creation proposes the location (`docs` key) and waits.
- Fixed default dirs (`docs/decisions/` in AD `:48`, `docs/adr/` in PO). Detection first, then ask.
- README, changelog and API-doc sections. AD `documentation-and-adrs:152-248`. Docs/release cluster.
- wait-what as a skill. PO `wait-what:7`. Meta layer.

**Merged skill spec: `domain-model`**
- Type discipline. Invocation slash: `/domain-model [term | adr <decision>]`. define, architect and triage Read its SKILL.md when a term or decision crystallizes. An auto description would duplicate define's triggers.
- Description (254 chars): "/domain-model to sharpen a domain term or record a decision. Challenges terms against the project glossary and the code, proposes glossary edits, and drafts an ADR only when the decision is hard to reverse, surprising, and the result of a real trade-off."

| Step | Action | Gate | Source |
|---|---|---|---|
| 1 | Resolve `docs`: glossary (single or multi-context), ADR dir; else domain facts in project rules. Absent: proceed silently | none | PO domain.md:5-11; GLOSSARY-FORMAT:54-60 |
| 2 | Challenge, sharpen, scenario, code cross-check; persisted shape for stored concepts | none | PO domain-modeling:44-58 |
| 3 | Glossary edit proposed as a diff in the format; first-ever glossary proposes its location | write on approval; commit per `commits` | PO GLOSSARY-FORMAT |
| 4 | ADR: test the three conditions; match convention; minimal template; supersede, never delete; prose review | write on approval | PO ADR-FORMAT; AD :36-100,259-265 |
| 5 | A term that reveals a state machine or variant set becomes a note for architect or plan | none | PS model-the-domain:13-24 |

References: `glossary-format.md` (~1.8KB incl. multi-context), `adr-format.md` (~2KB). SKILL.md ~3KB.

---

## 7. Prototype and spike

**Job.** Answer one design or feasibility question with throwaway code and evidence. **Phase.** De-risk, inside define or plan.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| prototype | PO | 2931 (+12949) | auto | the question picks the branch: single-file logic demo or UI variants via `?variant=` |
| prototype | PB | 2161 | playbook | scope the decision; isolated scratch; one switcher; verify on the surface; recommend |
| brainstorming spike path | SP | in 17548 | auto | question + probe, nod, an answer not code |
| principle-exhaust-the-design-space | PS | 1152 | slash | structurally different alternatives |
| principle-experience-first | PS | 1184 | slash | prototype before committing |

**Strongest mechanisms to keep**
- No decision, no prototype; the question goes at the top of the demo. PB `prototype.md:7`; PO `LOGIC.md:18-20`.
- Branch by question: a logic or state model gets one self-contained HTML file with a pure, liftable module, free-play buttons and guided scenario tabs in domain language; a UI question gets 3 (max 5) structurally different variants; a timing question gets the smallest script. PO `prototype/SKILL.md:12-17`, `LOGIC.md:22-50`, `UI.md:36-54`; PB `prototype.md:9`. The logic branch is stack-independent by construction.
- Variants on the existing route behind a URL switch, so they sit in real chrome and data; switcher hidden in production builds. PO `UI.md:14-32,85-90`. The source already says "adapt to the project's framework" (`UI.md:61`).
- Throwaway and labeled, trivial to run with the project's own task runner, no persistence, no polish, state shown after every action. PO `prototype/SKILL.md:21-25`.
- Verify by observing the matching surface (screenshots, timing logs). PB `prototype.md:11`.
- Present variants, evidence, tradeoffs and a recommendation; say it is throwaway. PB `prototype.md:12-14`.
- Spike gate: probe in 2-3 sentences and a nod first; keeping spike code is a new request. SP `brainstorming:65-70,106`.
- Capture the verdict and the question it settled. PO `prototype/SKILL.md:26`.
- Colour-only variants are tweaks; redo with an explicit structural constraint. PO `UI.md:54,109`.

**Drop**
- Commit and push a throwaway branch; push research branches with no PR. PO `prototype/SKILL.md:26`, `wayfinder:115`. Commit and push per `commits` and `approval`; default keeps it in the worktree.
- "Control skill" (`control-ui`). PB `prototype.md:11`. Use the `browser` key.
- Scratch DB named "PROTOTYPE, wipe me". PO `prototype/SKILL.md:23`. Local stacks may share a database across worktrees; default is no migrations and no DB writes unless the human approves a disposable DB.
- External moodboard. PB `prototype.md:8`. Optional only.

**Merged skill spec: `prototype`**
- Type specialist. Invocation slash; define's spike path and plan step 3 Read it.
- Description (262 chars): "/prototype to answer one design question with throwaway code: a single-file logic demo for a state model, or 3 structurally different UI variants on an existing route behind ?variant=. Built in an isolated worktree, verified with screenshots, never merged as is."

| Step | Action | Gate | Source |
|---|---|---|---|
| 1 | State the question and the decision it settles | no decision: stop | PB :7 |
| 2 | Pick branch: logic, UI, or timing script; ambiguous -> match surrounding code and state the assumption | none | PO :12-17; PB :9 |
| 3 | Present variants, location and run command in 2-3 sentences | nod | SP :65-70 |
| 4 | Build per `isolation` (worktree off the fresh base) or in `work_dir`. Logic: one HTML file. UI: URL switch on an existing route via `references/ui-frameworks.md`, non-production switcher, read-only data. No migrations or DB writes | never the primary tree; `protected` untouched | PO :21-25, UI.md |
| 5 | Verify: `browser` command per variant (probe and screenshot); logic -> walk the scenarios; timing -> log it | page settled before capture | PB :11 |
| 6 | Report variants, evidence paths, tradeoffs, recommendation; label throwaway | none | PB :12-14 |
| 7 | Capture the verdict in the spec or a tracker comment draft; offer a private Artifact for a logic demo; branch commit or push per `commits`/`approval`; build cluster rewrites the winner properly | human approves writes | PO :26, UI.md:112 |

References: `logic.md` (~2.5KB), `ui.md` (~2.5KB), `ui-frameworks.md` (~2KB: search-param switching for Next, React Router, Vue Router, SvelteKit, Angular, server-rendered pages; production gate idiom per build tool). SKILL.md ~3.5KB.

---

## 8. Plan and break down

**Job.** Turn an approved spec or issue into ordered, verifiable tasks and PR boundaries, or chart a multi-session effort as decision tickets. **Phase.** Plan.

| Skill | Source | Bytes | Invocation | Core mechanism |
|---|---|---|---|---|
| writing-plans | SP | 9092 (+1713) | auto | zero-context executor; files first; Interfaces; TDD steps with code; Global Constraints; Review Focus; no placeholders |
| planning-and-task-breakdown | AD | 10564 | auto | dependency graph; vertical slices; task template; sizing; checkpoints; never overwrite an open plan; tracker mapping |
| plan (command) | ADC | 805 | slash | read-only plan entry |
| to-tickets | PO | 5812 | slash | tracer-bullet tickets with blocking edges; expand-contract; quiz granularity; local or tracker output |
| wayfinder | PO | 12380 | slash | multi-session map of typed decision tickets; fog of war; one ticket per session |
| multi-phase-plan | PB | 12977 | playbook | per-PR program; prototypes first; unit/live/perf verification; plan checker |
| figure-it-out | PS | 3978 | slash | falsifiable done predicate; rigor level; riskiest first; baseline; verdict trail |

**Strongest mechanisms to keep**
- Skip the plan for 1-2 files with an obvious approach. PB `multi-phase-plan.md:5`.
- Write for a zero-context executor: exact files, real code in every code step. SP `writing-plans:10-12,143-151`.
- File map before tasks; files that change together live together. SP `:25-34`.
- Dependency graph, built bottom-up. AD `planning:35-55`.
- Vertical tracer bullets, each demoable alone and sized to one fresh context; prefactor first. PO `to-tickets:27-36`; AD `planning:57-77`.
- Wide refactor exception: expand, migrate in batches by blast radius, contract. PO `to-tickets:40`.
- Task size: the smallest unit with its own test cycle; split only where a reviewer could reject one task and approve its neighbor. SP `:36-43`.
- Interfaces block (Consumes / Produces, exact signatures). SP `:104-108`.
- Task fields: ACs, verification commands, dependencies, files, scope. AD `planning:83-104`.
- Global Constraints copied verbatim from the spec; Review Focus lists the 5 input classes the spec implies but no test exercises, each pinned by a test in its owning task. SP `:72-89,163`.
- No-placeholders list. SP `:143-151`.
- Self-review: spec coverage, placeholders, type consistency, Review Focus. SP `:153-165`. Calibrated reviewer prompt. `plan-document-reviewer-prompt.md:27-34`.
- Checkpoint every 2-3 tasks; high risk early; every task leaves the system working. AD `planning:106-123`; PS `figure-it-out:27`.
- Never overwrite an incomplete plan for different work; stop and ask. AD `planning:150-155`.
- Task list target is a markdown file by default or the project's tracker when the rules name one; the plan keeps an ordered index of tracker ids. AD `planning:157-164`. Portable by design.
- Parallel vs sequential classes (migrations and shared state sequential; contract first, then parallel). AD `planning:213-219`.
- Settle open questions by prototype before writing. PB `multi-phase-plan.md:6`.
- One PR is one change with its own evidence; per-PR dependency graph and file boundaries. PB `multi-phase-plan.md:8,47-51`.
- Done as a falsifiable predicate; baseline captured before the change; verdicts VERIFIED / NOT VERIFIED / INCONCLUSIVE. PS `figure-it-out:17-21,29,42`.
- Regression check runs the same scenario on base and head. PB `multi-phase-plan.md:13,102`.
- Quiz the human on granularity and blocking edges before publishing. PO `to-tickets:42-56`.
- Handoff: the human reviews the plan and picks subagent-driven or inline execution, given a one-sentence recommendation. SP `:167-192`.
- Wayfinding for efforts larger than a session: destination; decision tickets typed research / prototype / grilling / task, HITL or AFK; fog in "Not yet specified"; out of scope never graduates; one ticket per session (research excepted); refer by name, not id; local-markdown fallback for repos without a tracker. PO `wayfinder:7-127`, `issue-tracker-local.md:21-30`.

**Drop**
- Per-task `git commit -m "feat: ..."`. SP `:135-140`. Checkpoint steps say "stage explicit files; commit per `commits`".
- `docs/superpowers/plans/`, `tasks/plan.md`, `tasks/todo.md` at repo root. SP `:18`; AD `planning:145-148`; ADC `plan.md:16`. Plans go to `work_dir`.
- "REQUIRED SUB-SKILL: superpowers:..." lines. SP `:61,189-192`.
- Fixed size table with L = 5-8 files. AD `planning:127-135`, `spec-driven-development:200`. Sizing reads `scope_gate`.
- Publishing tickets with `ready-for-agent`. PO `to-tickets:58-63`. Drafts; tracker writes per `approval`.
- Wayfinder creating, claiming and closing issues and pushing research branches. PO `wayfinder:113-127`. Drafts; every tracker write gated by default.
- PRs opened ready, owners squash-merging, `/loop 1h` audit tick, ten cloud-VM lanes, Bugbot, `origin` forge, `check-plan.mjs`. PB `multi-phase-plan.md:10,41-42,56-61,100-111,131`. Autonomous PR and merge; infrastructure absent.
- "Never block on the human" for reversible work. PS `figure-it-out:23`. Conflicts with the default gate.
- "Avoid file paths" applied to plan tasks. PO `to-tickets:105`. Keep it for tickets (durable), not plan tasks (exact).

**Merged skill spec: `plan`**
- Type phase. Invocation slash: `/plan <spec path | issue id>` and `/plan map <destination>`. define's architectural path ends by asking the human to run it, so typing it is the approval act and no description loads per session. If the human approves in words, define Reads `plan/SKILL.md`.
- Description (270 chars): "/plan <spec or issue id> after the spec is approved. Maps files and dependencies, slices vertical tasks within the project's scope gate, writes exact steps with tests and verification, self-reviews, and drafts tracker sub-issues. /plan map charts a multi-session effort."

| Step | Action | Gate | Source |
|---|---|---|---|
| 0 | Resolve profile keys. Preconditions: approved spec or issue ACs; base and promotion path from `branches`; existing plan for this work is updated in place; dedup open PRs for the issue | another open plan for different work: stop and ask | AD planning:150-155 |
| 1 | Skip check: 1-2 files, obvious approach | say so, no plan | PB :5 |
| 2 | Ground read-only: Explore subagents return file pointers, conventions, `verify` commands, persisted shapes and writers | none | PB :7; AD :24-33 |
| 3 | Settle open questions with prototype or research; product calls go to the human as options | none | PB :6 |
| 4 | Done predicate per AC; baseline to capture before changes | none | PS figure-it-out:17-21,29 |
| 5 | File map and dependency graph | none | SP :25-34; AD :35-55 |
| 6 | Slice: vertical slices; expand-contract for wide refactors; one PR = one change with its own evidence; each PR within `scope_gate` or an explicit scope confirmation; overlapping files run in sequence | scope confirmation above the gate | PO to-tickets:27-40; PB :8 |
| 7 | Tasks per `references/task-template.md`: exact Files, Interfaces, test-first steps with code and `verify` commands, ACs, Blocked by, one line per `checklists` item | none | SP :94-151; AD :83-104 |
| 8 | Header: Goal, issue id, spec link, base and promotion path, Global Constraints verbatim, Review Focus | none | SP :54-92 |
| 9 | Order riskiest first; checkpoint every 2-3 tasks; regression check on base vs head | none | AD :106-123; PB :102 |
| 10 | Self-review and no-placeholder scan; reviewer subagent, round 1 only | none | SP :153-165 |
| 11 | Write the plan to `work_dir`; present it; human picks execution mode; offer tracker sub-issue drafts with blocking edges (no paths) | STOP; tracker writes per `approval` | SP :167-192; PO to-tickets:42-67; AD planning:157-164 |

Map mode: destination via define's interview reference; breadth-first frontier; map (Destination, Notes, Decisions so far, Not yet specified, Out of scope) in `work_dir` or as a tracker parent-issue draft; typed decision tickets; one ticket resolved per session; research tickets run as background subagents; every tracker write drafted by default. PO `wayfinder:7-127`.

References: `plan-template.md` (~2.5KB), `task-template.md` (~2KB), `plan-review.md` (~1.5KB), `tickets.md` (~2KB, vertical slices, expand-contract, tracker mapping via `triage/references/adapters/`), `wayfinder.md` (~4KB), optional `stacks/migrations.md` (~1.5KB, expand-contract per ORM and migration tool). SKILL.md ~7KB.

---

## Cluster gaps

| Gap | Why no source covers it | Where it lands |
|---|---|---|
| Project profile contract and resolution order | PO setup is the closest but covers tracker, labels and domain docs only, and edits CLAUDE.md itself; no source defines who may loosen a default | section 0 keys; schema and `/setup` bootstrap owned by meta |
| Defaults loosened only by project files or the human | every source either hardcodes autonomy (PB, PO) or hardcodes the gate (SP); none reads a tier table from project rules or rejects loosening from agent messages | section 0 loosening rule; meta enforces |
| Tracker adapter with draft-then-post | PO adapters write autonomously; no source drafts every tracker write and posts on approval, across GitHub, GitLab, Linear, Jira, local markdown | `triage/references/adapters/`, reused by define, plan, recall |
| Existing-data and existing-consumer compatibility at define time | no source asks which existing records and callers flow through a change or lists the writers of a gated property | `define` spec section; `plan` checklist; CDS rule 21 is one instance |
| Authorization scope at design time | AD covers 401/403 codes only; no tenant/IDOR scoping step | `define` spec section, `architect` red flags |
| Gap verification on every target branch | PO triage checks one tree | `triage` step 3, `define` step 1 via `branches` |
| Branch and environment model in planning | no source plans across a promotion chain, hotfix base or backport | `plan` step 0 and header via `branches` |
| Persisted-schema and migration planning per stack | to-tickets expand-contract is generic; nothing maps it to ORMs, migration tools or shared local DBs | `plan` optional `stacks/migrations.md`; build cluster |
| Stack detection and stack references | AD detects versions for docs only; no source loads stack-specific design depth on demand | `stack` key; `references/stacks/` in explain, architect, prototype, plan |
| Where working docs live without polluting the repo | every source writes into the repo | `work_dir` default with `git check-ignore`, else ask |
| Glossary bootstrap in a repo with none | PO creates files lazily without asking | `domain-model` step 3 proposes the location first |
| Stakeholder async loop | to-questionnaire writes a local file; nothing tracks answers back into the spec | `define` questionnaire mode |
| ACs mapped to environment evidence | figure-it-out has a predicate; nothing maps spec ACs to `browser`/`verify` evidence for a QA handoff | verify cluster |
| Claude-only fan-out cost | pstack relies on cheap non-Claude explorers | narrow-by-default rules in `explain` and `architect`; meta model-routing |

## Open decisions for the lead

1. The profile file name and format (meta owns it), and whether `work_dir` defaults to `.scratch/` or a `.claude/` subdir.
2. Whether `scope_gate` defaults to 4 files (conservative) or is unset until a project names it.
3. Whether `plan` should be model-invocable, if typing `/plan` after approval proves to be friction.

## Cross-cluster dependencies

| From | To cluster | What crosses |
|---|---|---|
| section 0 keys | meta | profile schema, `/setup` bootstrap (detect, propose, confirm, write), loosening rule enforcement, model routing for subagents |
| `define` bounded path | build | approved in-chat design is the contract; test-first work starts after the explicit yes |
| `plan` | build | task list, Interfaces blocks, execution mode; worktree per `isolation`; branch per `branches`; commit per `commits` |
| `define` spec, `plan` Review Focus | verify | success criteria and Review Focus become verification targets; `browser`/`verify` evidence |
| `define` spec, `plan` Review Focus, `explain why` Preserve/Change/Avoid/Risk | review | acceptance and lineage source for reviewers and self-review |
| `architect` red flags, type and boundary principles, `stacks/` | review, build | same checklist screens sketches and diffs |
| `triage` step 4 | debug | bug repro and root cause |
| `explain why` epistemics | debug, review | confidence tiers for regression and "why was this written" questions |
| `explain research` | build | version-pinned docs before framework code; better as a one-line ambient rule than an auto skill |
| `prototype` | verify, build | screenshot verification via `browser`; winner rewritten properly |
| tracker adapters | meta, verify | shared by recall, QA handoff and any skill that reads or drafts tracker content |
| all artifacts | meta | writing contract; outward-action gate; chaining slash-only skills by Read path; description budget; any hook-injected gate summary under 10,000 chars |
