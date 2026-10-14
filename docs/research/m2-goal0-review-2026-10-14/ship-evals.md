<!-- Goal-0 review of the M2 plan, 2026-10-14, against kern 0.2.1 and docs/plans/2026-10-12-kern-m2-plan.md before its update pass. Read-only agent output, kept as evidence; plan line numbers refer to that version. -->

# Goal-0 review: commit, finish-branch, recall, routing, adherence, CI, pilot (part 1)

Every category BELOW; M2's close as planned cannot prove goal 0. Guards G2 and G5 are the strongest part (drafts, dedup, convention, staging shape in code; no source does that), but skill text and guard code conflict.

| Category | Strongest source | Verdict | Biggest gap |
|---|---|---|---|
| commit | addy git-workflow-and-versioning + kern G5 | BELOW | Step 6 writes the message to "a temp file"; G5 allows -F only inside WORK, so autopilot denies |
| finish-branch | SP finishing-a-development-branch; pstack opening-a-pr | BELOW | gh pr create has no --title (fails without a TTY); dedup blocks pushing follow-up fixes |
| recall | local recall; pstack recall, ketchup | BELOW (small) | C11 acceptance checks dropped; one eval case; session discovery prose |
| routing (T21 + F3) | addy run-evals routing tier; using-superpowers | BELOW | F3's code change not written down; no fixed rank-1 floor; plain "commit this" never reaches commit or finish-branch |
| adherence grader (T22) | SP explicit-skill-requests; caveman host isolation | BELOW | Runs use the user's config; an unprefixed `recall` Skill call counts as a pass |
| CI and acceptance (T23) | addy test-plugin-install.yml | BELOW | No coverage re-audit, no head-to-head, evidence gitignored, nothing measures the 1.2k-token goal |
| pilot (T24) | pstack eval.md blinding; SP analyze-token-usage.py | BELOW | Side-by-side runs have no protocol |

commit:
- Message file vs G5: plan:3841 "temp file"; G5 allows -F only inside MAIN, under WORK or not ignored (g05-commit.sh:326-333, 369-373); mktemp asks, autopilot denies, breaking execute-plan step 10 (plan:3486). Fix: write to $(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp)/commit-msg; pin in commit.test.mjs.
- Proof covers the wrong tree: step 4 proves the working tree, step 3 leaves files unstaged. addy git-workflow:211-230 reviews git diff --staged. Fix: show git diff --staged --stat first; when tracked changes stay unstaged, say the proof covers the working tree, or prove the staged patch in a detached copy.
- Granularity: gated execute-plan leaves the whole plan uncommitted (plan:3490) -> one big commit. addy git-workflow:48-63, pstack opening-a-pr:7. Fix: offer one commit per complete ledger task, in ledger order, staging that task's review-package paths (each commit matches a reviewed tree id: beats sources).
- No rationalization table (addy 313-325; SP 216-225). Add commit and finish-branch to lint rule 9's discipline set.
- Exceeds: G5 and G6 check convention, attribution, staging shape and secrets in code.

finish-branch:
- Missing title: plan:3971 gh pr create --draft --base <base> --body-file <file>, no --title; no TTY in Claude Code Bash. Fix: --title "<subject per commit.convention>", asserted in the test.
- Dedup mis-ported (plan:3969 stops whenever a PR exists at this head; blocks pushing review fixes; take-feedback is M3). Fix: if the PR head SHA equals local HEAD, report and stop; if an open PR is at an older head, push (G1 asks) and report the URL without a new PR.
- Which worktree: (truncated)

# part 2: finish-branch (rest), recall, routing

finish-branch:
- Which worktree: execute-plan finishes in the main session with work in the plan worktree (plan:3490); step 1 checks the cwd and refuses on main. G2 proves a draft only when the cwd's branch is the PR head (g02-pr.sh:371-374, _g02_here); `cd <wt> && gh ...` fails _gh_proven -> ask, autopilot deny. Fix: step 1 takes the worktree from the ledger's Worktree: line or git worktree list and cds into it in its own call before step 2.
- Body file location: G2 accepts --body-file only under WORK or a non-ignored file (g02-pr.sh:314-331, 350-354). Fix: $(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp)/pr-body.md.
- Detached HEAD not handled (SP finishing SKILL.md:44, 67-76); forks and spikes are detached (F15); G5 refuses detached (g05-commit.sh:374). Fix: offer "create branch <branch.pattern name> here" before the menu.
- Discard: SP lists branch, commits, worktree before the typed word (137-146); kern work is uncommitted -> list git -C <wt> status --porcelain -uall first.
- pr-body.md (plan:4000-4021): add pstack ## Tradeoffs (opening-a-pr.md:18), "drop a section with nothing to say", ~40-line cap (:13).
- Proven tree: record wt-snap at step 3; refuse push when HEAD^{tree} differs (turns SP's "Tests passed earlier" rationalization (216) into code).
- No rationalization table: port SP 216, 219, 220, 222, 225.
- Exceeds: G2 draft-only, dedup and body-file shape in code; size gate new.

recall:
- Acceptance dropped: C11 (skills spec:739-742) four checks (ledger's incomplete Task 3 is the next move; recall chat leads with the action-item count; "Resume session 7f3a" points to claude --resume; the ML question stays quiet) not in the plan; no recall.acceptance.md; recall.json one dialogue case (plan:4182-4194); pilot checklist (4926) omits recall and prove-it. Fix: four evals[] cases + acceptance file.
- Source lines dropped (~600 bytes; budget 6,500): local recall:19 memory is context, never state; :40 adjacent work out unless blocking, cut detail before threads; :42-47 red flags; ketchup:9 notifications and subagent results are not user messages; ketchup:15 earlier action items still count, work you can do is not one; session-pickup:9 re-verify inherited claims.
- Code where code can: session discovery is prose (slug rule, worktree sibling slugs, mtime order, skip current session and child folders); step 4 greps history.jsonl (cross-project, contradicts "never another project's transcripts"). Fix: scripts/recall-sessions <window> [topic] filtering by the project field, with bats tests; the pilot reuses it. Tag [verified, uncommitted] only when the ledger's last tree= equals a fresh wt-snap; state that wt-snap writes git objects (carve-out from "write nothing").
- Exceeds: ledgers first, every tag checked against live state, chat mode.

routing (Task 21 + F3):
- F3's code change unspecified: Task 21 parses model.kernelText (plan:4375 targets, 4423 rule 12). kernelRows, rules 6, 7, 12 must read the routed file (own size cap: per-task cost); the grader must accept Read routes file then Read skill before any other tool (under gap 10 the routes Read is the first call); two-hop routing is spec 15's risk: run adherence with rows in the kernel and with the routed file, record both.
- No fixed floor: evals/baseline.json min_rank1 0, rises only via --update-baseline; addy CI --min-rank1 95 (.github/workflows/test-plugin-install.yml:38). F7 and step 9 (plan:4488) tune TF-IDF ranks to pass, so they are not goal-0 evidence. Fix: fixed CI floor + frozen held-out organic prompt set (later real pilot prompts) that may not be reworded.
- No NL path to commit or finish-branch: "commit this"/"open a PR" match only the prove-it row (4445); both are disable-model-invocation. Fix: prove-it Gate line ends "then Read {KERN}/commit/SKILL.md for a commit, or {KERN}/finish-branch/SKILL.md for a push or PR".
- Re-reading: add a second same-route task to the multi-turn case (using-superpowers SKILL.md:45).
- Exceeds: kernel rows evaluated like descriptions, with owner merging.

# part 3: adherence grader, CI and acceptance, pilot

adherence grader (Task 22):
- No host isolation: runner (plan:4665, 4678) uses the user's settings, plugins (caveman), user skills, MCP, user CLAUDE.md; only superpowers off. caveman isolates with --setting-sources project --strict-mcp-config --disable-slash-commands --no-session-persistence (evals/README.md:48-52, llm_run.py:136-138). Fix: those flags except --disable-slash-commands; record them in the results file.
- False pass: grade() accepts a bare-name Skill call (plan:4618 [route, `kern:${route}`]); a user-level recall skill passes recall-resume. Fix: accept only kern:<route> or a Read of <plugin root>/skills/<route>/SKILL.md; test the false pass.
- Too thin (one run, positives only, 4 of 10 rows, plan:4707-4710). Add 3 runs per case as a pass rate; negative cases (casual question, user opt-out, kern: off, a project skill for the same job: 11.3 fixtures 1 and 4) = goal 0's false-alarm half and per-task cost; one adherence case per kernel row from each row-*.json first eval; one haiku pass, reported not gating (SP run-haiku-test.sh:55).
- Evidence discarded: evals/results/ gitignored (plan:4761). Commit the acceptance snapshot (model, claude version, per-case reasons) like caveman (README:41-44).
- Meta temp-dir name kern-adherence- visible to the model; pstack eval.md:7,10 wants project-shaped names.
- Exceeds once fixed: SP only warns on a pre-skill tool (run-test.sh:111-118, exit depends on trigger only 132-136); kern fails the case and grades steps.

CI and acceptance (Task 23):
- Shellcheck explicit lists (plan:4836-4840, 4849-4853) miss decided-gap scripts. Use globs with -x -S warning.
- M2 cost goal enforced nowhere: rule 3 caps auto + agents at 2,500 chars; rule 7 warns at a 4,000-char kernel; ~6.5k chars total = full-build 1.7k tokens, not M2's 1.2k. Estimate with F3 (inferred): kernel raw 2,963 now, ~3.2k after M2; rendered ~3.5k (no settings) to 4.1k (longest); + prove-it 257, recall 265, agents 423 + ~90 tool lists -> 4.5k-5.1k chars, ~1.15k-1.35k tokens; without F3 +520 chars -> ~1.3k-1.45k. Fix: rule-7 error when rendered kernel + auto + agents > ~4,800 chars at M2; at release measure input + cache-creation tokens for a claude -p hello run with and without kern (caveman README:72); record in CHANGELOG.
- Outward skills tested by hand only (plan:3869-3872, 4028-4031). Add execution evals in a bare-origin fixture (make_fixture) with a gh PATH shim recording argv: menu before any push; existing PR at HEAD stops; nine files trigger a split proposal; under autopilot gh pr create carries --draft --title and gh pr ready never runs; commit uses -F <WORK file>. No source tests these.
- Release commit wording (plan:4876) claims a green adherence run that is not committed.

pilot (Task 24):
- Side-by-side protocol: >=3 tasks per project, >=6 total, chosen and written in docs/pilot.md before either run (define or plan, diagnose, execute-plan through finish-branch); same base commit, two worktrees; kern arm --plugin-dir with superpowers off locally, superpowers arm with kern absent; fresh session, identical first prompt; blind judging of diff, PR body, final reply labelled A/B at random (pstack eval.md:7-13) against a 3-5 item rubric written before; record per arm user corrections, fix rounds, red-then-green, later defects, input/output tokens and wall clock (SP analyze-token-usage.py:12-81); pass rule stated before: kern wins or ties most tasks and loses no task category outright; token ratio in the decision line.
- Wording: plan:4932 "same kinds of task" vs spec:573 same tasks; match the spec.
- Real-world adherence: kernel-adherence.mjs --transcript <jsonl> --route <r> grades pilot transcripts; adherence rate per route instead of the self-reported Route taken column (4909).
- Checklists (4926) omit recall and prove-it.
- 11.3 fixtures 1, 4, 5 as automated adherence cases.

# part 4: M2 acceptance vs goal 0; missing from the pending pass

M2 acceptance vs goal 0 (as planned, M2's close tests its own parts but does not compare with sources):
1 Coverage re-audit step in Task 23 before release: re-audit every M2 row and gaps 5-19 against built and tested code; each row cites the test or eval file that pins it (new column) with a small lint that the files exist; update counts; release blocked while any M2 row is source-stronger.
2 Head-to-head evals for debugging and planning: update spec 14 M2 row; new Task 22b after the T1 runner. Arms: kern, superpowers, no-plugin control (caveman "honest delta", evals/README.md:17); debugging adds pocock diagnose. Debugging fixtures 4-5 in evals/h2h/debugging/ with root cause away from the symptom (polluter test, helper off-by-one, stale cache, env-dependent failure). Planning fixtures 4-5 in evals/h2h/planning/ (planted ambiguity, contradiction, hidden constraint, a requirement not to invent). Hidden answer key; blinded dirs and prompts (pstack eval.md:7-10). Score real findings matching the key; false alarms = claims a blind grader rejects; debugging regression test must fail before the fix. 3 runs per arm, pinned model, committed snapshot. Gate: kern >= the strongest arm's key items, no more false alarms, per category.
3 Side-by-side pilot protocol (Task 24 steps 1, 4, 5).
4 Standing cost in tokens measured at release.
5 Adherence snapshot committed, with negative cases.

Missing from the pending pass:
1 finish-branch step 10 --title.
2 finish-branch step 8 dedup on head SHA; older-head PR -> push and report.
3 finish-branch step 1 worktree from the ledger or git worktree list, cd in its own call (_g02_here).
4 commit step 6, finish-branch step 10: message and body files under WORK via kern-dir tmp.
5 adherence grader counts only kern:<route>.
6 adherence runner host-isolation flags.
7 adherence negative cases, 3 runs, one case per row, committed snapshot, non-gating haiku, --transcript mode.
8 F3's changes spelled out (kernelRows source, rules 6/7/12, routed-file size cap, two-hop grader rule, A/B adherence of both shapes).
9 fixed rank-1 floor in CI + frozen organic held-out prompts.
10 prove-it Gate hands off by Read to commit and finish-branch.
11 recall: four C11 checks as eval cases + acceptance file, dropped source lines, scripts/recall-sessions, tree-id check for [verified, uncommitted], recall and prove-it in pilot checklists.
12 commit: gated mode one commit per complete ledger task.
13 commit and finish-branch: proven tree = committed/pushed tree (wt-snap vs HEAD^{tree}).
14 finish-branch: detached HEAD path, discard listing, pr-body Tradeoffs, drop-empty, ~40-line cap.
15 rationalization tables for commit and finish-branch; both in lint rule 9.
16 execution evals for commit and finish-branch with a gh PATH shim.
17 shellcheck by glob in Task 23.
18 Task 23 coverage re-audit, Task 22b head-to-head runner and fixtures, Task 24 side-by-side protocol, release-time token measurement, rule-7 combined budget ~4,800 chars, spec 14 M2 row with head-to-head.
