# Eval harness: kern against its upstreams

Research for M3, 2026-10-22. Read-only: no runner was started and no model was called. Inputs: kern at `29a7f67`; `.upstream/superpowers` at `bb92a77` (7.0.0), `.upstream/caveman` at `d262ab38`, `.upstream/addy` at `aeac41d` (0.6.13), `.upstream/pstack`; the M2b ledger `.superpowers/sdd/2026-10-14-kern-m2b-plan/progress.md` (Task 16 entries, cited as "ledger N" for line N) and its diagnoses 1 to 5 and the two h2h diagnoses in the same folder.

## Verdict

Every harness bug in the Task 16 ledger has an upstream practice that prevents it or narrows it. The four that matter most:

- superpowers runs one `claude -p` process per user turn. Turns cannot collapse or cross.
- caveman scores offline from saved outputs and tests every check against known-pass and known-fail answers before a paid run.
- addy grades the whole trace and makes a missing fixture a CI error.
- Claude Code's own `claude plugin eval` gives each run a fresh home and config, a with/without-plugin arm and a 2-of-3 judge. addy uses it, and kern's M0 design picked it for fires and stays-quiet cases (`docs/research/merge-meta.md:663`, coverage gap 38, deferred to M6).

kern adapted grader shapes from upstream: the adherence pass rule from superpowers `run-test.sh` (`scripts/lib/adherence.mjs:8`), the blank-evidence rule from addy (`scripts/lib/behave.mjs:312`), the blinding rules from pstack. It did not adapt how upstream drives turns, keeps evidence, sizes samples or isolates the host. The ledger already records the miss (ledger 280).

Part of the loop was arithmetic, not bugs. A case passes at 2 of 3 runs. A case whose true pass rate is 90% passes that rule 97% of the time, but 19 such cases all pass together only 58% of the time. No upstream gates a suite on three runs per case.

kern is ahead of every upstream on run validity: invalid is never fail, a usage limit stops the runner, hooks are traced, the plugin copy hides the answer keys, and the env allowlist keeps the caller's tokens out. Keep all of that.

## Sources and limits

- superpowers' behaviour lab (Quorum, formerly drill) is a git submodule at `evals/` that `.upstream/superpowers` does not hold. kern's audit noted it (`docs/research/audit-superpowers.md:119`) and never fetched it. The Quorum facts below come from the in-tree design spec `docs/superpowers/specs/2026-05-06-lift-drill-into-evals-design.md`, `docs/testing.md:27-37` and the public README of `prime-radiant-inc/superpowers-evals`, not from its code.
- The `claude plugin eval` facts come from the Claude Code docs pages `plugin-evals` and `plugins/cli-reference` as read on 2026-10-22. kern has never run it. The docs tie some behaviour to versions: git 2.31+ from 2.1.283, an API error scored 0 without grading from 2.1.299.

## Per-harness summary

### superpowers 7.0.0

Two layers: live `claude -p` scripts under `tests/` and the out-of-tree Quorum lab.

- **Turns.** One `claude -p` per user turn. Turn 2 onward adds `--continue`, which resumes the latest session in the cwd; each run has its own timestamped project folder, so "latest" is unambiguous. Each turn's stream-json goes to its own file, and grading reads only the last turn's file (`tests/explicit-skill-requests/run-multiturn-test.sh:46-84`; five turns in `run-extended-multiturn-test.sh`). A cheaper form fakes history inside one prompt (`prompts/claude-suggested-it.txt` opens with `[Previous assistant message]:`). Quorum drives multi-turn sessions with an LLM agent playing the user from a scripted story.
- **Grading.** Scripted. `grep` for a Skill tool call naming the skill, plus a premature-tool check that ignores todo tools (`run-test.sh:81-112`). `tests/claude-code/test-helpers.sh` asserts case-insensitive patterns, counts and order on the reply. The SDD integration test greps the session JSONL and checks repo state: files, `npm test`, commit count (`test-subagent-driven-development-integration.sh:187-280`). Quorum combines an LLM self-grade against acceptance criteria with deterministic post-checks in a bash DSL. A pass needs both, and the verdict is pass, fail or indeterminate.
- **Grader noise.** Handled by method, not code. `skills/writing-skills/SKILL.md:577-587`: read every flagged match by hand, because template echoes and quoted counter-examples pass for hits.
- **Runs and statistics.** Scripts default to one run (`test-worktree-native-preference.sh:26`). Campaigns use more: 5 reps per arm with every reply read (`docs/superpowers/specs/2026-07-06-sdd-plan-scoped-workspace-eval-results.md:6`), 50 of 50 across three phases (`test-worktree-native-preference.sh:19`). The written rules: 5+ reps per variant, always a no-guidance control, and "Variance is a metric". No intervals.
- **Control arms and fixture gates.** RED/GREEN arms on the same fixture. In the SDD campaign the RED control arm validated the fixture, and a Step 1 sanity gate caught a fixture-generator bug "before any scenario rep ran" (`...eval-results.md:139`).
- **Isolation.** In-tree scripts barely isolate: `--plugin-dir` with `--dangerously-skip-permissions`, user settings and plugins load. `run-test.sh:8` says "Uses isolated HOME" but sets none, and `run-haiku-test.sh:25-30` copies the user's CLAUDE.md in on purpose. Quorum pins HOME, the XDG dirs and TMPDIR to a per-run home.
- **Failures.** In-tree: `timeout` and `|| true`, so a usage-limit reply reads as FAIL. Quorum: a rate-limit response skips the remaining queued cells for that endpoint, setup or capture failures are `indeterminate` (exit 2), and nothing retries automatically.

### caveman

Single-turn only, built to measure output length and fidelity of a response style.

- **Turns.** One `claude -p --output-format json` per prompt and arm, stdin closed (`evals/llm_run.py:133-160`). `reminder_run.py` delivers per-turn hook text through a real UserPromptSubmit hook passed with `--settings`, still one turn.
- **Grading.** No judge model. Length is counted with tiktoken and with Claude's own usage figures. Fidelity uses regex `must_include` and `must_not_include` per case (`evals/score_fidelity.py`). Each case carries known-pass and known-fail answers, and `tests/test_eval_fidelity.py:145` runs the checks against them in CI, "so a miscalibrated regex fails here, not after a paid run". Scoring reads a saved snapshot, so a corrected check is re-scored with no new calls.
- **Arms.** Baseline, a terse control and the skill; "the honest delta for any skill is `<skill>` vs `__terse__`" (`evals/README.md:17`). `reminder_run.py` runs the old text from a git ref (`@base`) and the new text (`@head`) in the same run.
- **Runs and statistics.** One run per prompt and arm, spread reported across prompts as median, mean, min, max and stdev. The README says it is not a powered experiment (`evals/README.md:229`). The API benchmark uses 3 trials at temperature 0 and reports medians.
- **Isolation.** `--setting-sources project --strict-mcp-config --disable-slash-commands --no-session-persistence` from an empty temp cwd, skill as a system-prompt file (`llm_run.py:136`). kern's `ISOLATION` list is the same minus `--disable-slash-commands`. `reminder_run.py:72` sets HOME and `CLAUDE_CONFIG_DIR` to a temp dir and runs serially, because parallel `claude -p` calls dropped installed plugins from the host's settings.json (`reminder_run.py:24`).
- **Failures.** A failed call is retried after 5 s and 20 s. If it still fails, the run stops, writes `results.partial.json` with null cells and `metadata.error`, leaves `results.json` alone and exits 1 (`llm_run.py:101,262`). `snapshot_contract.py` refuses an incomplete matrix before any report. The harness has its own unit tests for retry, partial output and an error result printed on exit 0 (`tests/test_eval_llm_run.py`).

### addy 0.6.13

Three tiers in `scripts/run-evals.js`, plus Claude Code's built-in plugin eval under `evals/plugin/`.

- **Turns.** Tier 3 is single-turn: prompt on stdin, skill text through `--append-system-prompt` (`scripts/run-evals.js:597-604`). Plugin eval cases are single prompts. The docs offer multi-turn only as a recorded `context.history_file` whose next user turn is the case prompt.
- **Grading.** Tier 3 sends the whole stream-json trace to one `claude -p` grader over stdin, fenced as untrusted (`run-evals.js:614-624`). The reply is validated: ids bound to expectations 1..n, blank evidence invalid, counters derived from the verdicts rather than the grader's summary (`run-evals.js:455-505`). Plugin eval graders are `regex`, `tool_used`, `tool_order`, `file_exists`, `llm` and `baseline`. An `llm` grader votes 3 times and passes on 2. There are no custom-code graders.
- **Runs and statistics.** Tier 3: one run. Plugin eval: 3 runs per arm by default, with and without the plugin, Δ between them. The README reports raw counts over many runs and pins the model and CLI version: the review clause took four phrasings "from 7 of 27 fires to 21 of 27" with must-not-fire prompts at 0 of 27 (`evals/README.md:53`).
- **Isolation.** Tier 3 builds a fresh git workspace from fixtures, with an optional working-tree patch (`run-evals.js:402-450`), but passes no `--setting-sources`, so the host's plugins and settings reach the run. Plugin eval gives each run a temp home, temp working dir and fresh config with only the plugin under test; user settings, hooks, CLAUDE.md, MCP servers and other plugins stay out, and a `scaffold_script` builds the fixture.
- **Failures.** Tier 3: 15-minute executor and 5-minute grader timeouts. A malformed grading is saved raw and counted as a failure; an executor error has no catch and ends the whole run (`run-evals.js:596-650`). No retry. Plugin eval: a rate or usage limit scores 0 without grading and exits 1; a cost ceiling or rejected auth gives a partial result and exit 2.
- **Fixture gate.** Missing case files, invalid fixture paths and absent required fixtures are CI errors (`evals/README.md:95-97`).

### pstack

`pstack/skills/poteto-mode/playbooks/eval.md` is a method, not a runner. kern's h2h took its blinding rules. It did not take step 7: read every candidate output end to end and compare it with the judge, because disagreement means a biased model or an ambiguous rubric.

### kern at 29a7f67

- **Turns.** One long-lived process. `scripts/lib/claude-drive.mjs` writes prompt k+1 as a stream-json frame after the k-th prompt result. Multi-prompt runs set `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, and the count check ignores task-notification results (`scripts/lib/claude-run.mjs:94-188`).
- **Grading.** Adherence and exec are scripted. Behave runs scripted `CHECKS` plus one Sonnet grader call on a digest capped at 40,000 characters (`behave.mjs` `RECORD`). h2h runs one blind Opus grader over redacted digests: score 0 to 10, false alarms counted against a labels key.
- **Runs and statistics.** 3 runs; a case passes at 2 of 3 valid runs (`caseResult`, adherence). h2h compares means over 3 runs. No intervals.
- **Isolation.** `ISOLATION` flags, a plugin copy without evals, tests and docs, an env allowlist, a workspace under the OS temp dir. HOME and `CLAUDE_CONFIG_DIR` are inherited, so every run shares one config dir and one kern data dir, `plugins/data/kern-inline` (`task-16l-investigation.md:42`). Exec refuses a host `~/.claude/kern.yml`; behave, adherence and h2h do not check for it.
- **Failures.** A `<synthetic>` usage-limit reply stops the runner (ledger 145). A timeout, signal, non-zero exit or network error makes one run invalid and the runner goes on. No retry. Snapshots and transcript folders are named by date.

## Kern problems against upstream practice

| Problem | What happened | Home-built part | Upstream practice that prevents it | Prevented? |
|---|---|---|---|---|
| Collapsed turns | `runClaude` wrote every prompt to stdin at once and Claude Code 2.1.304 ran them as one turn: all six multi-diagnose runs of 2026-10-20 had one result event (diagnosis 1, X3). Fixed in 16e. | One process fed stream-json on stdin | superpowers: one `claude -p` per turn with `--continue`, one log per turn. Plugin eval: `history_file` leaves one live turn. | Yes. A process per turn cannot merge turns. |
| Background-agent turns | 2.1.304 backgrounds an Agent call that omits `run_in_background`, and its notification starts an unasked turn: 14 extra results over 160 transcripts, runs marked invalid, a turn could join a queued prompt (diagnosis 2, Y1). Fixed in 16h by turning background tasks off, which changes the behaviour under test. | Same driver; result-count check | superpowers' per-turn process. kern saw a one-prompt run hold its process until background work ended (`claude-run.mjs:94-100`), so notification turns land in that turn's file before the next turn starts. | Mostly. The count check must still accept notification results, but background agents can stay on as users have them. |
| Grader flips | Same behaviour, opposite verdicts: pressure-prove-it-deadline E0 got 1, 2, then 0 of 3 on the same nine replies; recall-1, recall-2 and commit-unverified flipped too; 13/19 graded against 16/19 on a plain reading (diagnosis 2 Y3, diagnosis 3 Z2, diagnosis 5). Fixed in 16j and 16p by scripted checks. | One Sonnet verdict per expectation; conditional or vacuous expectations | caveman: no judge, and every check runs against known-pass and known-fail answers in CI. superpowers: grep plus a hand read of every flagged match. Plugin eval: 2-of-3 `llm` vote. | Mostly. Calibration examples catch vacuous wording before a paid run; a vote damps the flips that remain. |
| Digest gaps | The grader record dropped assistant text, cut Write bodies at 800 characters and had no tool results (diagnosis 1, X2); a tail-only Bash result hid a ledger read (diagnosis 2); a loop printed the ledger inside the cut (16j). Fixed in 16e, 16h and 16j. | `digest`, `behaveDigest`, `RECORD` caps | addy sends the whole stream-json trace to the grader over stdin, fenced as untrusted. caveman scores whole outputs. | Yes for behave, at higher grader input cost. h2h still needs a redacted digest. |
| Missing fixtures | node-bug has no origin and sits on protected `main`, so implement step 1 stops and `wt-new` exits 2: five cases could not pass on a compliant kern (diagnosis 1, X1). prove-it-1/2 and recall-1/3 ran without the files their prompts name, execute-plan-ledger's plan failed plan-check, define-spec lacked `data/invoices.json` (ledger 155). Fixed in 16f. | `workspace()`; `loadCases` checks only that a layer exists | superpowers' fixture sanity gate before any rep, with a RED control arm that validates the fixture. addy: absent fixtures are CI errors. Quorum: `pre()` checks, a failure is indeterminate. | Yes, with per-case pre-checks of what the prompt assumes. |
| Partial-read grading | Sonnet re-read diagnose with `Read` `limit: 12`, which stops at `## Steps`. `routeCall` ignored `limit`, so runs that read no step passed: 0 of 7 observable runs read the steps (diagnosis 5). Fixed in 16p. | Route-read detection by Read path | superpowers and addy grade a Skill tool call, which loads the whole skill; plugin eval uses `tool_used` with `input_match`. A caveman-style known-fail set taken from real transcripts would include a `limit: 12` read. | Partly. Routing by Read of an absolute path is kern's own design, so only the calibration set applies. |
| False-alarm rubric | h2h plan: the grader counted kern's true but unsourced `base: main` as unsupported, because it lacked the git facts the session saw: 4 to 5 of kern's 5 false alarms. h2h review: a false alarm was any decoy hit or unmatched finding, true or not; 7 of kern's 11 were real issues the key omitted, and the pstack and control arms scored 3.67 too (both h2h diagnoses). Fixed in 16n and 16o. | `graderPrompt` rubric and labels key | pstack step 7: read every output and compare it with the judge. caveman: read the failures before citing a rate. superpowers: a control arm validates the fixture before the variant is judged. | Likely. The control arm's own 3.67 false alarms already showed the key was incomplete. |
| Lost evidence (also seen) | Same-date names overwrote the morning's transcripts (ledger 228). Archives kept in the scratchpad were lost on a session restart (ledger 229). | Date-named folders | Plugin eval writes `results/<timestamp>/`. caveman never overwrites a good snapshot with a partial one. | Yes. |
| Network outages (also seen) | TLS interception voided h2h diagnose and review and five behave cases on 2026-10-22; "a VOID/invalid wave means a network outage" lives only in the ledger (ledger 249, 272). | No retry; runner goes on after an invalid run | caveman retries twice, then stops with a partial file. Quorum stops an endpoint's queue on a rate limit. Plugin eval exits 2 on a partial. | Yes. |
| Shared host state (risk, not yet a failure) | Behave, adherence and h2h inherit HOME and one config dir; only exec refuses a host `~/.claude/kern.yml`, which kern's hooks read past `--setting-sources`. None exists today. | `INHERITED_NAMES` passes HOME and `CLAUDE_CONFIG_DIR` | Plugin eval and Quorum give each run its own home and config. caveman's reminder runner does the same. | Yes. |

## Why three runs looped

Odds that a case passes the 2-of-3 rule, and that every case of a suite passes together, for a given true pass rate per case:

| True rate per case | Case passes 2 of 3 | All 19 behave cases pass | All 16 adherence cases pass |
|---:|---:|---:|---:|
| 0.80 | 0.896 | 0.12 | 0.17 |
| 0.90 | 0.972 | 0.58 | 0.63 |
| 0.95 | 0.993 | 0.87 | 0.89 |

A case at 0.5 passes half the time. multi-diagnose was graded 5 of 10 over four measurements (diagnosis 5), a 95% Wilson interval of 0.24 to 0.76, so each measurement was a coin flip. A single 2 of 3 has an interval of 0.21 to 0.94 and cannot separate a good case from a weak one. Claude Code also moved from 2.1.304 to 2.1.308 between measurements (diagnosis 5), so measurements taken days apart were not the same experiment.

## Adopt list for M3

Ranked by payoff over effort. Effort: S is under a day, M is one to three days. Rows refer to the table above.

| Rank | Adopt | From | Change in kern | Effort | Payoff |
|---:|---|---|---|---|---|
| 1 | A statistical gate | superpowers (5+ reps, variance as a metric), addy (counts over many runs) | Snapshots record k of n and a Wilson interval per case; runs of an unchanged case on the same CLI version pool. Pass when the lower bound clears the target, fail when the upper bound misses it, otherwise add 3 runs up to a cap. Gate the suite on the cases, not on all-pass at n=3. | S | High: ends gates that flip on chance, the main reason Task 16 looped. |
| 2 | Immutable run folders and offline regrade | caveman (snapshot, offline score, contract), plugin eval (`results/<timestamp>/`) | Each run writes `evals/results/<runner>-<UTC time>/` with events, tree state, grader input and reply, and never overwrites. Add `--regrade <dir>` to behave, h2h and exec, like adherence's `--transcript`. A snapshot contract refuses an incomplete matrix. Gating-run transcripts are kept outside the scratchpad. | S to M | High: every grader fix from 16e to 16p could have been checked on all earlier runs at no cost. Closes lost evidence. |
| 3 | Fixture pre-checks | superpowers' sanity gate, addy's CI fixture errors, Quorum `pre()` | Each case lists what its prompt assumes: named paths exist, branch and origin as intended, the plan passes plan-check, the baseline test is red or green as expected. A node test builds every workspace and runs the checks with no model. | S to M | High: closes missing fixtures, which cost the first two measurement rounds. |
| 4 | A grader calibration set | caveman's pass and fail examples, addy's fires and stays-quiet pairs | Every scripted check and every LLM-graded expectation gets pass and fail excerpts cut from saved transcripts; the Task 16 diagnoses already cite 68 transcript lines. Node tests run the scripted checks on them. An on-demand `--calibrate` sends the LLM-graded ones through the grader before a gating run. | M | High: closes grader flips, partial-read grading and the false-alarm rubric. Needs rank 2's saved transcripts. |
| 5 | An infrastructure-failure policy | caveman's retry and partial file, Quorum's queue stop, plugin eval's exit 2 | Before the first paid call, check the TLS chain to the API host and `claude --version`. Retry a network error twice with backoff. Stop the batch after two infra failures in a row and write a partial snapshot the gate refuses. | S | Medium: closes network outages; no more VOID waves. |
| 6 | An adjudication step | pstack step 7, superpowers' hand read, caveman's "read the failures" | A gating run ends with a read of every case whose verdict changed since its last run or disagrees with a plain reading. Each disagreement goes into rank 4's set. | S | Medium: kern did this only after a gate failed, five times. |
| 7 | A per-run home and config dir | plugin eval, Quorum, caveman `reminder_run.py` | Each run gets a temp HOME and `CLAUDE_CONFIG_DIR` with its own plugin data. Credentials reach it by token env or a copy. The host-`kern.yml` refusal is then not needed. Spike first: how a fresh config dir signs in on this Mac without the default Team login (memory `kern-eval-auth`). | M | Medium: closes shared host state; no plugin data shared across runs. |
| 8 | A process per turn | superpowers `--continue`, plugin eval `history_file` | A multi-prompt case runs one `claude -p` per prompt, resumed with `--resume <session_id>` from turn 1's init event, with session persistence on inside the rank 7 config dir. Each turn's events go to their own file and background agents stay on. A case that grades only its last turn records the earlier turns once and replays them as history. Spike first: `--resume` with `-p` and `--plugin-dir` on the current CLI. | M | Medium to high: removes `claude-drive.mjs`, `NO_BACKGROUND` and the count-check special cases; closes collapsed turns and background-agent turns by construction. Needs rank 7. |
| 9 | `claude plugin eval` for single-turn cases | addy `evals/plugin/`; kern's own M0 plan | Spike three cases: a route fire, a stays-quiet case and a single-turn behaviour case using `tool_order`. Compare with adherence on the same prompts. If they agree, move the single-turn routing rows there and keep the home-built runners for multi-turn, exec and h2h. | M | Medium to high: per-run isolation, a no-plugin arm, a 2-of-3 judge, a cost ceiling and partial exit codes for free. Limits: two arms only, no custom-code graders, env keys must match `EVAL_*`, so no gh stub on PATH (inferred). The "at most one call before the route" rule may not be expressible. |
| 10 | Control and base arms in the same run | caveman terse control and `@base`/`@head`, plugin eval ablation, superpowers RED/GREEN | Behave and adherence take arms: head, a base tree (adherence already has `--plugin`), and no plugin, interleaved in one run so CLI drift hits every arm alike. A fix needs the control to show the failure first (superpowers' micro-test rule). | M | Medium to high: tells a kern defect from model or CLI drift. Doubles or triples the spend per case. |
| 11 | The whole trace to the behave grader | addy tier 3 | Behave sends the full stream-json on stdin, fenced, up to a size cap, and falls back to the digest above it. h2h keeps its redacted digest. | S | Medium: closes digest gaps for behave. Grader input tokens rise. |
| 12 | A 2-of-3 vote on LLM-graded expectations | plugin eval `llm` grader | Three grader calls per run for unscripted expectations in gating runs, or two with a third only on a split. The user chose "Scripted checks + one model" over this on 2026-10-21 (D7); revisit only for expectations that cannot be scripted. | S | Medium: damps the flips that scripting cannot remove. Up to 3x grader spend. |
| 13 | Read Quorum | superpowers-evals | Fetch it at a pin into `.upstream/` and audit its simulated user, three-valued verdict, post-check DSL and campaign scheduler. | S to M | Unknown: the only upstream harness with a simulated user. It could change rank 8. |

## Keep

Invalid is never fail, with a reason (superpowers' scripts grade a usage-limit reply as FAIL; addy tier 3 ends the whole run on an executor error). A `<synthetic>` usage-limit reply stops the runner. The exec hook trace (16l), the `treeState` no-write check, the env allowlist, the plugin copy without answer keys, h2h blinding and redaction, the probe PATH guard and the reaper have no upstream equivalent.

## Not adopted

- superpowers' in-tree isolation (user settings load) and copying the user's CLAUDE.md into the fixture.
- caveman's single-turn-only design: kern's routes and workflows span turns.
- `claude plugin eval` for h2h (two arms only) and exec (gh stub, git state and hook-trace graders need custom code).
