# Task 28 review: recall skill (7c554e7, cap commit c57f50f)

Spec verdict: ISSUES (one false routed-row citation, several ported gates dropped).
Quality verdict: NEEDS-FIXES (1 Important correctness bug in the verified tag, 4 Important, 6 Minor). No Critical.

## Check 1: does anything write
No. Walked every prescribed command.
- `kern-get work_dir .kern`: reads settings only, prints `.kern<TAB>default`, exit 0. Ran it in a scratch repo: no file created.
- `git rev-parse --path-format=absolute --git-common-dir`: read-only.
- `wt-audit`: `git --no-optional-locks`, `gh pr list`, `find`. Ran it: repo tree and `.git/info/exclude` unchanged. The mkdir/`>> info/exclude` lines are in `scripts/lib/wt-common.sh:28-30`, in a function wt-audit and recall-sessions do not call (`wt_dir` only resolves).
- `recall-sessions`: read-only (ran it in scratch HOME; nothing created).
- `wt-snap`: temp index plus objects. It also makes a `mktemp -d` under `$TMPDIR` (removed by trap). The skill's line "changes no file, ref or index" is true for the repo; "adds git objects" is correct. Fine.
- kern-dir is never named (test pins it).

## Check 2: G18 replay (real hooks/pre-tool-use, agent_type kern:investigator, KERN_GUARDS=g18, scratch HOME)
Harness sanity: `awk` and `sort | uniq` were denied, so the replay does vote.
ALLOW: `grep -n T f | cut -c1-300`; `-i`, `-E`, `\|` variants; `grep -c T f`, `grep -c T a b`; `grep -o`; `wc -c f`, `wc -c a b`; `sed -n 12,40p f`; `sed -n 12p f | wc -c`; `sed -n 12p f | cut -c1-500`; `sed -n 12,40p a | cut -c1-500`; `sed -n A,Bp a; sed -n C,Dp a`; `head -c 2000 f`, `head -n 5`, `tail -n 5`; `cut -d: -f1`; `jq -r .message f`; `jq -r 'select(.type=="user") | .message.content' f`; `jq -r --arg t foo 'select(.a==$t)' f`; `sed -n 12p f | jq -r .type`; `2>/dev/null`; `~` paths; `-- -x`.
DENY: `awk`, `sort | uniq`, `grep -n 'x>y' f` (any `>` even inside single quotes, hooks/guards/g18-readonly-agent.sh:18), `jq 'select(.n > 3)' f`.
Result: the four named commands plus grep -c, head -c and jq all pass. Gap, Minor (finding M1): a topic or jq filter containing `>` is denied even when quoted; the brief does not warn the miner.

## Check 3: step order and exits (scratch HOME)
- No topic: `recall-sessions --days 7` exit 0, empty. Skill says empty with exit 0 is no sessions. Correct.
- Empty topic: exit 2 usage. Skill forbids `--topic ""`. Correct.
- Bad option: exit 2. Covered by "Exit 1 or 2".
- Unreadable folder: exit 1, message "recall-sessions: cannot read <dir>", nothing on stdout. Skill: quote, Sources skipped, tag nothing from transcripts, go on. Correct.
- Exit 2 also means "not a git repository"; then live state is empty too, and "go on with live state" has nothing to go on. Minor (M2).
- Fixture walk (evals/fixtures/recall-ledger): `kern-get` gives `.kern`; common-dir parent plus `.kern` gives WORK; step 3 reads `ledgers/export/ledger.md` before step 4 (matches case 2's order). Task 3 has `start` and no `complete`, so a literal reading reaches "Task 3 is the next move" through Output contract "An incomplete ledger task is the next move". It does. But the thread for Task 3 has no clean tag: no `Worktree:` line, no branch, no PR. Step 7 only rules out the tag for a `<wt>` not in `git worktree list` or a failing `wt-snap`; an absent `Worktree:` line is not covered (gap 6 answer is incomplete). See I3.
- Caveat: the runner must materialize `_kern/` as `.kern/` inside a git repo; skill.md assumes that. Not verifiable (no runner yet). Case 2's `Main: /work/app` line is fake, harmless.

## Findings

### Important
I1. `[verified, uncommitted]` is not proven by the stated test. skills/recall/SKILL.md:19. The tag requires "last tree= equals a fresh wt-snap <wt>". Measured: after a commit of a clean tree, `wt-snap` equals `git rev-parse HEAD^{tree}` (both 3be22be... in my scratch repo). execute-plan commits per reviewed task, so committed-and-clean work also passes the test and would be tagged uncommitted. Fix: add "and differs from `git -C <wt> rev-parse HEAD^{tree}`; equal means committed: tag by its commit, PR or branch" (about 90 bytes; cap leaves 21).

I2. Dropped source gate: "When the answer hinges on what an agent actually did, read the full transcript region, not a summary" (.upstream/local/recall Steps 6). Nothing in SKILL.md says it; a miner summary can be the only evidence for a thread. Fix: one sentence in step 7. Cap fix: the skill is at 7,179 of 7,200; raise the cap with the spec again or cut elsewhere, never drop the rule. Spec C11 line 781 omits it too, so spec needs the same edit.

I3. Missing-`Worktree:`-line case unspecified (skills/recall/SKILL.md:19). The ledger fixture, and any ledger from before execute-plan step 5, has none. A started, incomplete task then has no allowed tag. Fix: "No `Worktree:` line, or a `<wt>` not in `git worktree list`, or a failing `wt-snap`: `[unverified, worktree unavailable]`" (and "no worktree recorded" instead of "gone").

I4. Chat-mode rules from pstack ketchup lost (step 9, SKILL.md:21). Missing: "assume the user remembers their last message and nothing after it; call things by a name they know"; "if nothing happened and nothing waits, say so and stop"; "say which are still running"; "if you do not know a part, say so instead of guessing"; "skip steps that changed nothing"; "name work you can still do yourself in one line". Spec C11 step 9 omitted them too, so this is faithful to the spec but not to the source rules ("behaviour is never dropped to fit a cap"). Fix: move chat mode to `references/chat.md` (about 1 KB; the ref has 800 bytes of room) and keep a one-line pointer plus the count-first rule in SKILL.md; frees SKILL.md bytes for I2.

I5. Load-bearing lines are unpinned: a removal-mutation run (68 sentence deletions in a scratch copy, test file `tests/skills/recall.test.mjs`) left 26 survivors; the meaningful ones: "An incomplete ledger task is the next move when one exists" (the whole case-2 behaviour), "A branch left behind after its PR merged is [merged #N] with cleanup pending" (ported gate), "`recall chat`: go to step 9", "A full state capsule already in the prompt: skip the mining", "The newest session is usually this one; skip it", "Two sessions or fewer: read them directly", "A source that cannot be reached ... unverified tag", "Cite transcript findings by session id", "Nothing is written", "No step asks a question", "List what could not be checked". (Survivors also include sentence fragments of my splitter, e.g. "Route.", ignore those.) Fix: add these to the `assertOnce` list. The report's "44 killed, 0 survived" only covers the pinned strings.

### Minor
M1. G18 and `>`: add to the miner brief sentence, or to `agents/investigator.md:12`, that `>` and `$(` are denied even inside quotes, so a topic like `x>y` must be searched by a prefix. Also investigator.md Rules 1 lists no `cut` or `jq` though the guard allows them and the skill prescribes `cut`; a miner that trusts the prose avoids `cut`.
M2. Exit 2 includes "not a git repository" (scripts/recall-sessions:49): say "outside a git repository there is no live state either; stop and say so".
M3. Routed row cited by map.md does not exist. skills/help/references/map.md:22 says `routed row "Starting or resuming after a gap"`; `grep -rn "after a gap" kernel skills` finds only that line, and kernel/kernel.md's routing table has two rows (technical-writing, context). Fix: drop the clause, or add the row to the kernel (a kernel edit, scope call for the lead).
M4. Collision with the user's own `~/.claude/skills/recall` (installed, confirmed: `~/.claude/skills/recall/SKILL.md` exists). CHANGELOG says "replaces the user-level recall skill" but nothing removes or disables it; two near-identical descriptions are both listed. No note in SKILL.md, help map or CHANGELOG on removing it. Fix: one line in CHANGELOG or README: "remove ~/.claude/skills/recall; both load otherwise".
M5. Product/personal names: evals/cases/recall.json:5 and tests/skills/recall.acceptance.md:3 say "floci swap" (spec C11 says it too); "billing work" is generic. No names, paths, dashes, curly quotes or source tags in skills/recall (grep clean). Fix: use "export feature" in the eval and acceptance prompt if the rule is strict.
M6. WORK resolution: `parent of --git-common-dir` is wrong for a bare repo or a separate git dir (the common dir is not `<main>/.git`), and `--path-format` needs git 2.31+. `kern_main_root` (hooks/lib) is the real resolver; also `work_dir` may be absolute, and "WORK is that parent plus the folder name" then breaks. Fix: say "an absolute work_dir is WORK itself". Also the miner brief does not tell the miner to keep each result under budget by quoting ids; fine as is.
Also: `model.miner` is named but the skill never says how to read it (kern-get model.miner haiku); the Inputs table gives the default only. Other skills do the same; ignore unless consistency demands.

Also noted, not graded: "Hold it to the unslop contract" (source) was dropped; kern's kernel applies unslop globally, so acceptable.

## Gap answers
1. `--topic` only when named: right and complete (empty topic = exit 2 confirmed).
2. WORK read-only: right; no write found; edge cases in M6.
3. Failed source to Sources skipped: right for recall-sessions and wt-audit; gh/tracker covered in step 6/7.
4. New tag: right; pinned once in the output contract.
5. Miner commands: right, G18 allows all named commands and grep -c, head -c, jq; denials only for `>` (M1). investigator.md lists neither cut nor jq (M1).
6. `[verified, uncommitted]` `<wt>`: incomplete (I1, I3).
7. wt-snap exception: right.

## Check 5, 6: routing and evals
route-eval rank-1 83% (baseline 0%), passed; no collision warnings printed. Negatives pass: ranked-first check on "Add a CSV export...", "Rename the config loader..." did not fire. Cases: 5 cases consistent with the skill; case 2 expectation "Reads .kern/ledgers/export/ledger.md before any transcript" matches step 3 before step 4; case 4 matches step 1; case 5's "Does not read skills/recall/SKILL.md" is checkable only by a transcript grader. Case 2 expected_output omits the tag question of I3.

## Commands run (all with HOME in the scratchpad t28 dir; kern repo unchanged, `git status --porcelain` empty)
- `node --test 'tests/**/*.test.mjs'`: tests 178, pass 178, fail 0.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: `rank-1 rate: 83% (baseline 0%)`, `route-eval: passed`.
- G18 replays: `/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t28/g18.sh` with `cmds.txt`, `c2.txt` (results above).
- recall-sessions: no topic (exit 0), `--topic ""` (2), `--bogus` (2), unreadable slug folder chmod 000 (exit 1, message quoted above).
- kern-get, wt-audit, wt-snap in a scratch repo: no writes (ls -a, git status, info/exclude checked).
- Removal mutations: 68 sentence deletions on a scratch copy via `scratchpad/t28/mut.mjs`: 26 survivors (I5). Copy deleted after.
