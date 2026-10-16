### Spec Compliance

Contract against code at d322e19. hooks.json matches the contract byte for byte ✅. Disagreements:

1. ❌ contract.md:62: json_escape does not always produce a valid JSON string. It escapes only `\ " tab CR LF` (C1).
2. ❌ contract.md:114 forbids `${var//[...]/}` on command text. gitctx.sh:99 still does it (I1).
3. ❌ contract.md:67: settings_get never sets SETTINGS_SOURCE. Line :186 supersedes it, but :67 was not edited.
4. ❌ contract.md:60: json_get stops at the first KEY. When that value is not a string it exits 1 instead of looking further.
5. ❌ contract.md:76 and :78: state_get also exits 2 (bad id, symlink), and state_reset also writes `since`.
6. ❌ contract.md:88: git_words also splits on a single `&` and splits `eval` arguments.
7. ❌ contract.md:89: git_sub reads more global options than listed, and matches `git` case-sensitively (M4).
8. ❌ contract.md:91: branch_protected also protects main, master, trunk and develop when no base resolves.
9. ❌ contract.md:96: unreadable input fails closed before kern_enabled runs (the safe direction). Guards read TOOL_INPUT, not KERN_INPUT.
10. ❌ contract.md:102: G1's and gitctx's git calls do not set `core.fsmonitor=false`. None of them refreshes the index, so this is wording only.
11. ❌ contract.md:190: gh_sub prints `<group>` alone when only one word follows.

⚠️ Task 18 should confirm two things. First, that Claude Code ignores PreToolUse stdout that is not valid JSON (C1). Second, that a subagent's PreToolUse carries the parent's session_id. The spike rewrote every id to `test-session`, and denying under autopilot inside a subagent depends on it.

### Strengths

- decide.sh:11-48 combines votes correctly. Deny beats ask, and allow wins only when no other vote exists. Only emit_decision turns ask into deny, so the 16 inline autopilot-deny lines change reason text only.
- Fail-closed paths hold: unreadable input, tool_name, tool_input, cwd and agent_type, a missing entry function, the G13 and G15 judges, and an unfinished G6 walk. No fatal bash expansion touches input.
- Every guard is sourced before any guard runs. Cross-file use is checked with `declare -F` (`_g05_ready`, `_g06_ready`, `_gh_proven`).
- Late helper changes left no stale caller. Only G15 reads the git_words status. cw_opt is one table with three readers. `+=` is parsed wherever assignments are parsed.

### Issues

**Critical**

- **C1 json.sh:85-90, decide.sh:47-48: one appended record removes every kern decision.**
  - Cause: json_get decodes `\b` and `\f` to raw bytes, and some reasons echo command words: `_g01_foreign`, `_g01_hidden`, `_g02_hidden`, push targets and G15 words. json_escape passes those bytes through.
  - Probe, under autopilot: `git push --force origin main; git x\by`. The G1 deny prints with a raw 0x08. node JSON.parse and Python both reject it ("Bad control character … position 223").
  - Interactively, asks are lost the same way. G6 reasons print paths read with `core.quotePath=false`, which is the same exposure (not probed).
  - The Task 2 and 7 deferrals assumed no input carries these bytes. json_get itself produces them.
  - Fix: escape every byte below 0x20 as `\u00XX`. Add a test that parses the output for each control character.

**Important**

- **I1 gitctx.sh:99: the first-word strip `${first//[\"\'\\]/}` is cubic.**
  - Each of the 7 guards that call git_words runs it once per record. `X='<blob>' ls` on /bin/bash 3.2 in en_US.UTF-8 takes 1.1 s at 1 KB, 13.9 s at 3 KB and 460 s at 10 KB. Bash 5 takes 0.3 s.
  - It runs inside `$( )`. Killing the dispatcher left a child and grandchild at 99 % CPU with ppid 1. This is probably the 17 h orphan in ledger line 380.
  - Fix: run `LC_ALL=C tr -d` only when the word holds a quote or a backslash. Add a 10 KB UTF-8 test.
- **I2: every guard parses the command again.**
  - Each Bash call runs git_words 7 times. Per record, G1 forks once and G2, G3 and G4 fork 3 times each with no gh prefilter. G5 and G6 call `_g05_split`.
  - 200 records take 7.7 to 10.7 s (G4 2.5 s, G14 2.5 s, G2 1.8 s). A 131-line `bash -c` takes 10.7 s. About 400 simple commands hit the 20 s timeout, which blocks the call with no kern reason.
  - Fix: parse once in the dispatcher (git_words plus one awk pass for `_cmd_words`) into shared arrays. First steps: G14's gh prefilter in G2, G3 and G4, and `_gh_load` reusing `_GH_RECS` for the same command.
- **I3 settings.sh:53-69: list-valued safety keys go to the first layer that sets them.**
  - A project `protected_targets: db.internal` silently drops the user's `protected_targets: v1-host`. `ssh v1-host 'del C:\x'` then gets no vote.
  - This matches the contract, so it is a user decision before the CDS pilot.
  - Proposal: union `protected_targets`, `never_commit`, `branch.protected` and `deploy.envs` across layers, as ruling Task 5 I-1 did for `autopilot: denied`.

**Minor**

- **M1 g06-secrets.sh:46:** the scan budget starts at G6. G2's 10 s plus G6's 14 s reach 24 s for `gh pr create --draft … && git push`, contradicting the comment at :10-11. Fix: drop the reset, because `SECONDS` already counts from dispatcher start.
- **M2 pre-tool-use:52-55:** a partly loaded guard is silent. A syntax error after `guard_g01` gave no decision on `git push --force origin main`, and a deleted file is silent too. Use `. "$f" || fail_closed …`, since `.` returns non-zero on a syntax error, and keep a list of expected guard ids.
- **M3 g16-state.sh:160-165:** four `tr` processes run before the prefilter. That adds 16 ms to every Bash call, the most of any guard on `ls`. Prefilter on the raw text first.
- **M4 gitctx.sh:330, g15-deploy.sh:177:** git is matched case-sensitively, so `GIT push origin feat:production` gets no G15 vote. G1 still asks.
- **M5 prompt-submit:185:** the per-prompt autopilot line lacks Task 14's shapes. After compaction, the first bare `git push` is denied, and the denial names the fix.
- **M6 pre-tool-use:47:** json_get finds `agent_type` at any depth. A main-session MCP argument with that name sets AGENT. M2's G18 must read the top level only.
- **M7 tests:**
  - payloads.bats:50-55 also passes on the G0 fail-closed ask.
  - `decision_of` returns `none` when output is only bash errors. The 28 `= none` assertions outside G16 never check status. Fix: print `error` when output is non-empty and holds no decision.
  - No test parses the emitted JSON.
  - The 2 s test at g13-g15.bats:647 uses a here-doc body that git_words drops, so neither I1 nor I2 is exercised.
- **M8 dead code, duplicates and stale comments:**
  - Dead: `cmd_head` (gitctx.sh:353) and `word_value` (:478) are called only by tests. AGENT and K_KERN are unread in M1.
  - Duplicates: the ask-then-autopilot-deny helper exists 4 times (`_g01_destructive`, `_g03_ask`, `_g06_unscanned`, `_g15_vote`). List trimming is in both `list_has` and `_g06_paths`. Relative-path code has 4 copies.
  - Stale comments: g06:10-11 and render.sh:3.
- **M9:** update the contract for Spec Compliance items 3-11.
- **M10 suite cost:**
  - g13-g15 took 129 s for 65 tests and g05-g06 103 s for 67, while other agents loaded the machine. The slowest tests are table loops: G15 round-1 rows 11.2 s, the git subcommand list 7.8 s, the G15 rider rows 7.1 s, and `git add -A` spellings 7.0 s.
  - The biggest costs are one dispatcher process per assertion (90 ms minimum even with KERN_GUARDS set) and `make_repo` per test (140 ms, about 46 s over the suite). System time exceeds user time (67 s against 46 s).
  - Fix: build the repo once in `setup_file`, run table rows in-process, and keep one dispatcher run per behaviour.

**Cost data** (/bin/bash 3.2, UTF-8, median of 5, all guards):

| Command | Time |
|---|---|
| `ls` | 0.20 s (dispatcher alone 0.088 s) |
| `git status` | 0.22 s |
| 10 KB inline `gh pr create --body`, no settings | 1.1 s |
| Same, protected_targets set, body naming ssh and mysql | 2.1-2.4 s (G13 1.29 s) |
| Same body in here-doc form | 0.47 s |
| 312 KB prompt, prompt-submit | 1.9 s |

On `ls`, G16 adds 16 ms, G4 11 ms, and G5 and G6 9 ms each. The inputs closest to the timeout are I1, I2 and M1.

### Assessment

**Task quality:** Needs fixes. Each part passes on its own, but at the seams one appended record can remove every decision (C1), and the shared parser is cubic in one place and repeated per guard (I1, I2). Fix these and settle I3 before release.
