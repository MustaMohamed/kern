<!-- Source audit of 2026-10-14 against kern 0.2.0 (3f7bc38) and the design spec. Paths are relative to .upstream/<source>/ unless noted. Read-only agent output, kept as the evidence behind docs/specs/coverage.md. -->

# pocock + caveman + local audit (part 1)

12 SBU: 11 caveman, 1 pocock; local unslop adds 1 more.
Claimed kern bug (to verify): when hooks/lib/settings.sh or hooks/lib/decide.sh is missing, PreToolUse returns no decision; `git push origin main` goes through Claude Code's normal permission flow with no kern guard.
Tests ran on scratch copies; kern repo unchanged.

| Source | Rows | KB | SBP | SBU | REJ |
|---|---|---|---|---|---|
| pocock (38 skills + 6 repo mechanisms, grouped) | 35 | 11 | 16 | 1 | 7 |
| caveman (22 skill dirs, 3 agents, 10 hook scripts, tests, evals, products) | 38 | 17 | 3 | 11 | 7 |
| local | 5 | 2 | 2 | 1 | 0 |

## Parser test: kern hooks/prompt-submit vs caveman caveman-parse.js, 43 phrases

| Case | kern | caveman |
|---|---|---|
| Intended on (16) | 7 | 16 |
| Intended off (15) | 6 | 12 |
| Should not switch (12) | 12 correct | 9 correct (3 false off) |

kern misses on: "use terse mode", "enable terse", "turn on terse mode", bare "terse", "terse please", "be brief", "fix the bug, then go terse".
kern misses off: "turn off terse", "disable terse", "terse mode off", "exit terse mode", "go back to normal mode", "write the notes, then stop terse".
kern has no false switches (reads first line only). caveman's false offs match known-failing cases in its own corpus.

## pocock (partial)

| Mechanism | Source | Enforced | kern counterpart | Verdict | Reason |
|---|---|---|---|---|---|
| ask-matt (PHASE-BOUNDARIES) | engineering/ask-matt | prose | kernel routing, kernel/context.md (M1) | KB | kern router fires itself |
| setup-matt-pocock-skills | setup-matt-pocock-skills:63-82 | prose | help setup (M1) | KB | Untracked file, not CLAUDE.md |
| grilling, grill-me, loop-me, grill-with-docs | productivity/grilling | prose | define step 6 (M2); domain-model (M5) | KB | |
| to-spec | to-spec:15-57 | prose | define spec template (M2) | KB | Adds approval gate |
| to-tickets | to-tickets:27-67 | prose | plan step 7 (M2) | KB | Tracker writes are drafts |
| implement | implement:7-17 | prose | implement (M2) | KB | |
| implement-spec | implement-spec:13-40 | prose | execute-plan, parallel-work (M2) | KB | |
| tdd | tdd:18-38 | prose | implement + test-design.md, slicing.md (M2) | KB | Seam note is a nit |
| diagnosing-bugs, hitl template | diagnosing-bugs:57-138 | prose + template | diagnose (M2) | KB | Nits: diff forced mutation vs pristine copy (:125); re-run original scenario |
| code-review (two axes, quotes the spec) | code-review:58-80 | prose | self-review step 4 (M2); pr-review lanes B, C (M3) | SBP | |
| pr (visual summary, screenshot evidence) | pr:13-33,158-164 | prose | finish-branch pr-body.md (M2) | SBU | No visual summary, no screenshot tier |
| codebase-design | codebase-design, DEEPENING.md | prose | architect (M5) | SBP | |
| improve-codebase-architecture | HTML-REPORT.md | prose | architect scan (M5), visual (M4) | SBP | |

# part 2: pocock rows (domain-modeling on) and local

| Mechanism | Source | Enforced | kern counterpart | Verdict | Reason |
|---|---|---|---|---|---|
| domain-modeling (GLOSSARY, ADR format) | skills/engineering/domain-modeling, ADR-FORMAT.md | prose | domain-model (M5) | SBP | ADR shape at M5 |
| prototype (logic and UI variants) | prototype/SKILL.md, UI.md | prose | prototype (M5); visual variants (M4) | SBP | |
| research | research/SKILL.md | prose | explain (M5); investigator (M2) | SBP | |
| teach | productivity/teach | prose | explain (M5) | SBP | |
| triage (agent brief, out-of-scope record) | triage/SKILL.md:56-110, OUT-OF-SCOPE.md | prose | triage (M5) | SBP | Out-of-scope record not named in kern's triage row |
| wayfinder | engineering/wayfinder | prose | plan map mode, deferred by X22 (M5) | SBP | Missing from §9 catalogue; add a row |
| to-questionnaire | productivity/to-questionnaire | prose | define questionnaire mode (M5) | SBP | |
| retro (navigation, checks, no-ops, tool economy) | retro/SKILL.md:15-23 | prose | retro, correct (M6) | SBP | |
| handoff, claude-handoff | productivity/handoff; in-progress/claude-handoff | prose | handoff (M6) | SBP | |
| wait-what | productivity/wait-what | prose | plain (M6) | SBP | |
| writing-for-agents, SKILL-MECHANICS | productivity/writing-for-agents | prose | write-skill (M6) | SBP | |
| setup-ts-deep-modules | in-progress, dependency-cruiser.config.cjs | code | correct, mechanism first (M6) | SBP | Generic form only |
| .out-of-scope/ + SCOPE.md | .out-of-scope/*.md, SCOPE.md:9-10 | prose | §11.1 tier 3, §11.4 (M6) | SBP | No .out-of-scope/ dir yet |
| git-guardrails-claude-code | misc/.../block-dangerous-git.sh | code | G1 (M1) | KB | Theirs bypassed by -C, needs jq, no tests |
| changesets, version sync, release workflow | scripts/sync-plugin-version.mjs, release.yml | code | check-version.mjs, release.mjs, lint rule 14 (M0) | KB | |
| link-skills.sh, list-skills.sh, invocation.md, ADRs | scripts/, .agents/ | code+prose | --plugin-dir; tiers §3.2 | KB | |
| wizard (template.sh) | engineering/wizard | code | none | REJ | |
| chief-of-staff | in-progress | prose | none | REJ | |
| writing-beats, -fragments, -shape | in-progress | prose | none | REJ | |
| migrate-to-shoehorn, scaffold-exercises | misc | prose | none | REJ | |
| setup-pre-commit | misc/setup-pre-commit:83 | prose | none | REJ | |
| openai.yaml, Codex/Copilot installs | agents/openai.yaml | n/a | none | REJ | |
| needs-info, triage-label workflows, ISSUE_TEMPLATE | .github/ | code | none | REJ | |

## local

| Mechanism | Source | Enforced | kern counterpart | Verdict | Reason |
|---|---|---|---|---|---|
| unslop catalog, artifact shapes | local/unslop/SKILL.md | prose | skills/unslop, path tier (M1) | KB | |
| unslop applied to chat and subagent returns | local/unslop description "Load at session start. Must always apply" | prose, auto-loaded | kernel.md:37 sends only persisted text to unslop; normal voice has no rules; kernel-subagent.md:6 return shape only | SBU | Normal voice loses the AI-tell catalog |
| recall | local/recall/SKILL.md | prose | recall (M2, C11) | KB | Drops two lines: "memory is context, never state"; "read the full transcript region when it hinges on what an agent did" (nit) |
| no-comments (fact-loss audit, constraint comments into checks, one rerun then stop) | no-comments/SKILL.md:31-36 | prose | no-comments (M3) | SBP | Keep fact-loss audit and encoding step |
| comment-sicko | comment-sicko.md | prose + tools | comment-sicko agent (M3) | SBP | |

# part 3: caveman table (paths under .upstream/caveman/)

| Mechanism | Source | Enforced | kern counterpart | Verdict | Reason |
|---|---|---|---|---|---|
| Voice ruleset | skills/caveman/SKILL.md (4,678 chars) | prose | modes/terse.md (1,676 chars, M1) | KB | Same rules, a third of the cost |
| Two missing terse rules: leave existing comments alone; changed lines plus 1-2 lines of context | skills/caveman/SKILL.md:58 | prose | none | SBU | Terse voice can leak into edited files |
| ultracave, megacave | skills/ultracave, skills/megacave | prose | dropped | REJ | |
| Slash parsing, status, unknown arg not echoed, envelope unwrap, foreign envelope skips NL | src/hooks/caveman-parse.js:173-337; caveman-mode-tracker.js:165-189 | code | hooks/prompt-submit:134-167 (M1) | KB | Tested in prompt-submit.bats |
| NL switch: anywhere in prompt, negation per clause, quoted text ignored, verb-gap whitelist, lost off is the worse failure | caveman-parse.js:84-171,248-257 | code | prompt-submit natural():111-132, first line only | SBU | 28/31 vs 13/31 intended switches; kern no false switches |
| Phrase corpus test (known failures recorded, real hook) | tests/test_mode_activation_corpus.js:60-96; tests/fixtures/mode-activation/cases.json | test | 5 NL cases in prompt-submit.bats:88-99 | SBU | |
| Per-turn reminder; full rules re-sent on switch | caveman-mode-tracker.js:114-121,386 | code | prompt-submit:171-197 | KB | |
| No reminder on scheduled-task prompts | caveman-mode-tracker.js:163 | code | reminder printed (scheduled-task prompt, voice=terse) | SBU | Spec 6.3 says skip |
| Headless/SDK starts without the voice | src/hooks/caveman-activate.js:247-254 | code | prompt-submit:183,192 skip for sdk* | KB | No kern test sets CLAUDE_CODE_ENTRYPOINT |
| Per-session state; off survives compaction; /clear resets | caveman-activate.js:207-245 | code | state.sh, session-start (M1) | KB | session-start.bats:36 |
| State file safety (symlinks, atomic, valid ids, size cap) | src/hooks/caveman-config.js | code | state.sh:9-58 | KB | state.bats:42,77 |
| Cleanup of old session state files | caveman-config.js:645-670 | code | none | SBU | Tiny |
| Missing library handled in a known direction (21 tests) | caveman-mode-tracker.js:17-61; tests/test_hook_missing_sibling.js | code+tests | hooks/pre-tool-use:6-15,50,72 | SBU | kern fails open for settings.sh and decide.sh (controller verified) |
| SubagentStart: carries mode, off does not leak, kern-voiced agents skipped (10 tests) | caveman-activate.js:290-294; tests/hooks/subagent-start.test.mjs | code+tests | hooks/subagent-start; 2 tests | SBU | Test depth only |
| Repo-local and user config layers | caveman-config.js | code | settings.sh (M1) | KB | |
| Statusline + setup nudge | src/hooks/caveman-statusline.sh; caveman-activate.js:446-598 | code | fix-a-run.md:14 snippet | KB | Nudge rejected |
| Token stats, SessionEnd record, per-mode attribution | src/hooks/caveman-stats.js:241-336; plugin.json SessionEnd | code | none | SBU | |
| Voice evals: no-prompt, "Answer concisely." control, skill arms; fidelity regex; isolation; snapshot; reminder test; benchmarks | evals/README.md, llm_run.py, score_fidelity.py, reminder_run.py, benchmarks/ | code | tier 2 blind A/B (M6), not voice-specific | SBU | |
| Windows support | install.ps1, caveman-statusline.ps1, tests/hooks/plugin-json-windows-hook-path.test.mjs | code | none | REJ | Needs a decision |
| caveman-commit | skills/caveman-commit | prose | commit (M2) | REJ | |
| caveman-review | skills/caveman-review | prose | unslop finding shape, review.taxonomy, task-reviewer list | KB | |
| caveman-compress | skills/caveman-compress, scripts/ | code | none | REJ | |
| caveman-help | skills/caveman-help | prose | help (M1) | KB | |
| caveman-explore, cavecrew-investigator | skills/caveman-explore; agents/ | prose+tools | investigator, G18 (M2) | KB | |
| cavecrew skill, builder, reviewer | skills/cavecrew; agents/ | prose+tools | implementer, task-reviewer (M2); code-reviewer (M3) | KB | |
| cavecrew-model-overrides (edits installed agent files) | src/hooks/cavecrew-model-overrides.js:1-20 | code | model.<role> keys (M2) | KB | §11.4 never edit plugin cache |
| investigate-first, surgical-patch | skills/ | prose | diagnose (M2) | KB | |
| lean-build | skills/ | prose | define, implement (M2) | KB | |
| verify-and-stop | skills/ | prose | prove-it (M2) | KB | |
| safe-refactor | skills/ | prose | refactor (M5) | SBP | |
| migration | skills/ | prose | expand-contract (M5), D7 | SBP | |
| caveman-learn + repeated-procedure mining | skills/caveman-learn; proxy/internal/store/detect_procedures.go:11-38 | code | retro, correct (M6), prose only | SBU | |
| Hardened git calls (gitsafe) | proxy/internal/gitsafe/gitsafe.go | code | plain git in hooks (settings.sh:84, G1, G6) | SBU | Low risk |
| subagent-tax | packages/subagent-tax | code | lint rules 3, 7 (CI) | KB | |
| Host version drift probe | agents/drift-report.mjs, probe-installed.mjs | code | tier 2 records versions (M6) | SBP | Compare against docs/spikes/m1-payloads.md version |
| Cloud skills, proxy gateway, supabase, deploy | skills/, proxy/, supabase/ | code | none | REJ | |
| caveman-init, per-host builds, generated/, toml, Gemini/Codex/Cursor, browser extension | src/tools/, skills/native, skills/generated, extension/ | code | none | REJ | |
| MCP servers: mcp, cavemem, browse, shrink, engine | mcp/, mem/, browse/, shrink/, engine/ | code | none | REJ | |

# part 4: SBU homes, REJ reasons, fail-open repro

1. Fail closed when a hook library is missing. M1 patch 0.2.1, S. Check each source in pre-tool-use; on failure fail_closed; if decide.sh is missing print a literal ask JSON (deny under autopilot). One bats test per missing library for all four hooks. SubagentStart tests (normal voice no terse line; kern: off prints nothing; bad session id falls back to settings). CLAUDE_CODE_ENTRYPOINT=sdk-cli test for the reminder skip. Spec §8.4 rule 4: "cannot load its libraries".
2. NL switches and a phrase corpus. M1 patch or M2, S. On: use, enable, turn on, activate, bare "terse", "terse please"; off: turn off, disable, exit, quit, "terse mode off", "go back to normal", "switch back to normal"; trailing ", then go terse". Cases in tests/fixtures/mode-activation/cases.json with known_failing, run against the real hook. Anywhere-in-prompt needs per-clause negation and quoted-text blanking. Spec §6.2 bullet 2.
3. Measure the terse voice. M6, M. evals/voice/ with three arms (no prompt, "Answer concisely." control, terse.md + reminder); fidelity regex (numbers, negations, verbatim errors, plain prose in persisted text); isolation flags --setting-sources project --strict-mcp-config --disable-slash-commands --no-session-persistence; committed snapshot; optional stats over transcript token usage. Spec §11.1 tier 2, §14 M6.
4. Repeated-procedure mining as a retro signal. M6, M. Tool-signature sequences recurring in 3+ sessions; report as candidates with measured re-derive cost, never as savings. §11.4 Signal.
5. unslop in normal voice. M2 kernel edit, S. ~150 chars of top AI tells in the kernel Reply line or modes/normal.md; subagent kernel Return: line points at unslop shapes. Within 4,000 (3,083 used). §4.2, §6.4.
6. Two missing terse rules. M2 patch to modes/terse.md, S. Existing comments in edited files are payload; code in chat is changed lines plus 1-2 lines of context.
7. No reminder on scheduled-task prompts. M1 patch, S. Skip when wrapped as <scheduled-task (spec 6.3). Decide whether the autopilot line prints there; a test pins it today.
8. pr-body. M2 finish-branch references/pr-body.md, S. Summary as the smallest useful view (call tree, pseudocode, diagram); before/after screenshot tier (pocock pr/SKILL.md:13-33,158-164).
9. Hardened git in hooks. M2, S, low. -c core.fsmonitor=false -c core.hooksPath=/dev/null and other gitsafe flags. Verified: a repo-configured core.fsmonitor program runs on git ls-files -s and git diff --cached once the index has the fsmonitor extension; needs an untrusted .git (archive); clone does not carry .git/config.
10. Clean up old session state files. M1 patch, S. session-start deletes sessions/*.state older than N days, skips symlinks.

REJ: ultracave/megacave (D-5, §2 rule 4, goal 4); caveman-commit (§6.4); caveman-compress (§6.4, §5.1); Windows (D-2, §8.4 rule 1; user decides); Cloud, proxy, supabase, deploy (goal 3, model-routing non-goal); caveman-init, per-host builds, toml, Codex/Cursor/Gemini, extension, pocock openai.yaml (D-3, other-tools non-goal; caveman-init writes tracked rules, D1); MCP servers (goal 4; ~69% of request is schema weight); statusline setup nudge (goal 3, G16: writes ~/.claude/settings.json); pocock wizard (outside goal 2; gh secret/variable set are outward writes, D2); chief-of-staff (goal 3, §8.2; unattended on schedules without typed autopilot; §11.3 fixture 7); writing-*, shoehorn, scaffold-exercises (outside goal 2, D-2); setup-pre-commit (D1, commits itself at misc/setup-pre-commit:83); pocock issue/label workflows, ISSUE_TEMPLATE (team-distribution non-goal).

Repro (agent's; controller reproduced independently with git push --force origin main):
missing=none -> ask "kern G1: push to protected branch main"; missing=settings -> no output, exit 0; missing=decide -> no output, exit 0.
Cause: settings.sh missing -> kern_enabled (settings.sh:210) undefined -> `kern_enabled || exit 0` at pre-tool-use:50; decide.sh missing -> emit_decision (decide.sh:35) undefined at pre-tool-use:72. onFailure: block never applies (exit 0). Other three hooks exit 0 silent when settings.sh is missing; acceptable (context only).
