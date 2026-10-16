# SDD ledger — plan: docs/plans/2026-10-12-kern-m0-plan.md

Ruling: work runs on `main` of the new kern repo — the user approved plans that commit there and the repo has no other branch or users — cost if wrong: history would need a branch rename, no data loss.
Ruling: implementers prefix PATH with $HOME/.volta/bin — /usr/local/bin/node (v18) shadows Volta 22 in subagent shells — cost if wrong: none, node 22 is the plan floor.
Ruling: bats 1.14.0 and shellcheck 0.11.0 installed from GitHub releases into ~/.local/bin — Homebrew 5.1.14 rejects macOS 27 — cost if wrong: versions differ from brew, same tools.
Ruling: briefs extracted with scratchpad/tools/brief.py, which respects fence length — the skill task-brief toggles on any backtick line and the M2 plan nests four-backtick fences — cost if wrong: none; output checked per task.

Task 1: implemented c8a78b1 (doc copies cmp-identical to sources; README matches brief)
Task 1: review — 2 Important (node v18 seen, gh unverified) resolved by controller checks: Volta node 22.23.3 is the default when ~/.volta/bin leads PATH; gh 2.100.0 logged in as MustaMohamed
Task 1: complete (commits root..c8a78b1, review clean)

Pre-flight table: preflight.md (38 rows, 16 findings). Rulings:
Ruling: F1, F2 (Task 1 guard and SP/KR scoping) need no change — Task 1 already ran and verified — cost if wrong: none.
Ruling: F3 accepted — distractor test now asserts /positive prompt ranked #2/ with a skill that shares "plan" — cost if wrong: one test rewrite.
Ruling: F4 accepted — release() moves the whole Unreleased block verbatim; new test keeps ### headings and wrapped lines — cost if wrong: changelog formatting.
Ruling: F5 accepted — Task 7 adds NOTICE map lines for rank.mjs and route-eval.mjs; Task 8 no longer lists NOTICE — cost if wrong: a missing attribution line.
Ruling: F6 accepted — M0 leaves evals/baseline.json at 0; M2 raises it after real auto skills — cost if wrong: weaker floor during M0-M1 only.
Ruling: F7 accepted — tracked scripts/lint-names.txt (owner's names and handles) feeds rule 8 in CI; .lint-names stays for local extras — cost if wrong: names list in a private repo.
Ruling: F8 accepted — Task 8 waits up to 60 s for the first run id before gh run watch — cost if wrong: none.
Ruling: F9 accepted — Task 9 stages CHANGELOG.md before its commit — cost if wrong: none.
Ruling: F10 no change — Task 7 Step 5 already says to use the upstream first clause; wording now says "verbatim" — cost if wrong: a distractor mismatch.
Ruling: F11 keep agents/ and modes/ in the Unreleased check — they ship behaviour like skills; the spec's list reads as a minimum — cost if wrong: an extra changelog line per PR.
Ruling: F12 accepted — expected bats output covers TAP and pretty formats — cost if wrong: none.
Ruling: F13 the plan governs: no attribution trailers in kern commits — the user approved the plan text and kern's own G5 default is commit.attribution none — cost if wrong: commits lack a session link.
Ruling: F14 accepted — lint-rules.mjs and check-version.mjs carry a one-line "informed by addy, written for kern" comment — cost if wrong: none.
Ruling: F15 keep licenses/caveman.* names — naming a licence file after its source is attribution, not product use of the mark — cost if wrong: two file renames.
Ruling: F16 no change — controller checked gh auth: logged in as MustaMohamed — cost if wrong: none.
Ruling: Task 8 Step 5 runs without asking — the user approved on 2026-10-12: create the private repo kern and push main after M0, M1 and M2 — cost if wrong: a private repo exists.
Ruling: Task 9 Step 2 uses the CLI (claude plugin marketplace add / install, a headless "hello kern" in a throwaway dir, then uninstall) — an interactive /plugin session needs the user — cost if wrong: the check runs headless instead of interactive.
Task 2: implemented c8a78b1..9591a90
Task 2: ⚠️ items resolved by controller: no trailers, but no commit body (the plan step gives -m subject only); .upstream ignored; test evidence in report
Task 2: minor (deferred): cp -R and mkdir failures inside fetch/copy_from are not caught (set -e suspended under ||); add `|| { rm -rf; return 3; }`
Task 2: minor (deferred): superpowers cache fallback triggers on any clone or checkout failure and is untested; the `local` default branch is untested
Task 2: minor (deferred): cache paths hardcode 6.4.1 and 3.2.0
Task 2: minor (deferred): checkout 2>/dev/null hides the real git error
Task 2: complete (commits c8a78b1..9591a90, review clean)
Ruling: commits whose plan step gives only a subject keep it without a body — the step text is the plan's explicit choice and amending rewrites history — cost if wrong: a few commits lack a why line.
Task 3: implemented 9591a90..a870879
Task 3: minor (deferred): licensing test checks licence files exist, not their content (plan-mandated)
Task 3: minor (deferred): pstack/pocock/addy pins are 7-char short SHAs (plan-mandated)
Task 3: minor (deferred): UPSTREAM.md intro says every source is cloned at its pin; caveman is copied from the cache
Task 3: complete (commits 9591a90..a870879, review clean)
Task 4: implemented a870879..0d601ce
Ruling: CI, ci-local and Task 9 validate both `.` (marketplace) and `.claude-plugin/plugin.json` — validating `.` checks only marketplace.json when both exist (Task 4 finding, confirmed by controller) — cost if wrong: one redundant step.
Task 4: minors need no action: docs/specs file exists (Task 1); version agreement is checked by Task 6
Task 4: complete (commits a870879..0d601ce, review clean)
Task 5: implemented 0d601ce..04b5606
Task 5: review — Needs fixes: 4 Important (all plan-mandated), 10 Minor
Ruling: Task 5 I-1 accepted — rule 11 scans every file under the shipped dirs except binary extensions, instead of an extension allowlist — cost if wrong: a binary-ish text file trips rule 11 and needs an exemption.
Ruling: Task 5 I-2 rejected — rule 4 keeps scanning fenced blocks: skills put real ${CLAUDE_PLUGIN_ROOT} commands in fences, and stripping them would hide missing scripts — cost if wrong: an example path in a fence needs a per-file exemption.
Ruling: Task 5 I-3 partly accepted — a local reference resolves against the skill dir, then the repo root; a #anchor or leading ./ is ignored; {KERN} rows stay with M1 rule 6 — cost if wrong: a path that exists only at repo root passes for a skill that meant its own dir.
Ruling: Task 5 I-4 accepted — add a passing rule-4 case and a repo-root fallback case — cost if wrong: none.
Task 5: minor (deferred): TRIGGER rejects "Use this skill when"; BOM or empty frontmatter reads as missing; malformed lint-exemptions.json throws; MACHINE_PATH is case-sensitive and hard-codes ~/Code/; rule 11 gives no line; walk follows symlinks; lint-skills.mjs not executable; rule 8 test env leak on throw; rule 3 ignores when_to_use
Task 5: fix round 1/5 (3 addressed, 0 open; commits 04b5606..25515fd)
Task 5: minor (deferred): rule 4 rooted ${CLAUDE_PLUGIN_ROOT} form takes no #anchor suffix
Task 5: complete (commits 0d601ce..25515fd, review clean)
Task 6: implemented 25515fd..ee65653
Task 6: review — Needs fixes: 3 Important (plan-mandated), 5 Minor
Ruling: Task 6 I-1 accepted — CLI entry guards compare realpaths through a shared scripts/lib/is-main.mjs; Task 7's route-eval.mjs uses it too — cost if wrong: none.
Ruling: Task 6 I-2 rejected for now — kern files are LF and macOS-only in use; CRLF handling deferred — cost if wrong: a Windows checkout with autocrlf misreads Unreleased.
Ruling: Task 6 I-3 rejected for now — kern's CHANGELOG always has a prior release heading (0.1.0), so release() never sees Unreleased last — cost if wrong: a false "Unreleased is empty" in a repo without releases.
Task 6: minor (deferred): CRLF changelog; first release with Unreleased last; --pr without a value gives a raw git error; prerelease headings skipped; only "- " bullets count; footer compare links not updated; no CLI or --pr test
Task 6: fix round 1/5 (1 addressed, 0 open; commits ee65653..367a526)
Task 6: minor (deferred): symlink CLI test depends on the live repo versions agreeing
Task 6: complete (commits 25515fd..367a526, review clean)
Task 7: implementer removed a stray 2-line fragment from the brief test (controller edit error in F3 rewrite); plan text corrected
Ruling: brainstorming distractor uses the upstream first sentence verbatim, per the F10 ruling — cost if wrong: one distractor reads longer than the others.
Task 7: implemented 367a526..1581167
Task 7: review — Needs fixes: 2 Important, 5 Minor
Ruling: Task 7 I-1 rejected — a malformed case file crashes route-eval with a non-zero exit, which fails CI loudly; case files are repo-authored — cost if wrong: a stack trace instead of a tidy message.
Ruling: Task 7 I-2 accepted — add tests for collision error and overlap warning, negative ranked #1, owner outranks (pass and fail) and unknown owner — cost if wrong: none.
Task 7: minor (deferred): owner equal to the skill passes silently; duplicate target names overwrite in the corpus; auto skill with empty description escapes coverage; non-numeric baseline disables the floor; fixture path not checked for ..
Task 7: fix round 1/5 (5 addressed, 0 open; commits 1581167..b7c36bd)
Task 7: complete (commits 367a526..b7c36bd, review clean)
Task 8: implemented b7c36bd..3bd64cd; repo https://github.com/MustaMohamed/kern (private); CI run 38226071050 success
Task 8: minor (deferred): ci-local header says same steps but omits the PR-only --pr check; push and pull_request both trigger; apt bats version floats; no permissions: contents: read
Task 8: complete (commits b7c36bd..3bd64cd, review clean)
Task 9: dispatched (CLI marketplace install, headless hello, uninstall, plan sync commit, CHANGELOG commit, push main); user asked to pause after it
Task 9: implemented 3bd64cd..1c5eaff (plan sync dacc7fe, acceptance 1c5eaff); hello replied "kern 0.1.0 is installed."; kern uninstalled and marketplace removed (controller verified); CI run 38226345153 success. PAUSED: Task 9 review and the M0 final whole-branch review are next.
Task 9: review gaps resolved by controller: m2 plan cmp-identical to source (no sync needed); CI run 38226345153 on MustaMohamed/kern = success at 1c5eaff
Task 9: complete (commits 3bd64cd..1c5eaff, review clean)
Final review (opus, c8a78b1..1c5eaff): Ready to build on: Yes. 1 Important, 5 new Minor; every deferred Minor triaged "leave".
Ruling: final fix wave covers I-1 (Unreleased check must see a bullet added since the base), M-1 (fetch-upstream replaces a tree only after the new one succeeds), M-3 (ci-local refuses Node below 22), M-4 partial (test that rule 8 reads scripts/lint-names.txt), full 40-char pins for pstack, pocock and addy, and `permissions: contents: read` in CI — each is cheap and M1/M2 lean on them — cost if wrong: one extra review round.
Ruling: M-2 (shipped list from the filesystem, not git ls-files) and M-5 (frontmatter edge cases) left for later — local-only noise and no M1/M2 skill uses those shapes — cost if wrong: a local-only lint false positive.
Final fix wave: 6 addressed, 0 open (commits bce1aad..92cecaa; scoped re-review clean)
Final: minor (parked): fetch-upstream swap step (`rm -rf && mv`) is not checked, so a failed rm or mv reports success — Ruling: leave; needs a permission fault inside .upstream — cost if wrong: a stale tree after a failed refresh.
Final: minor (parked): --pr compares against the base tip, not the merge-base — Ruling: matches the ruled design; base tips move forward only — cost if wrong: a bullet added on the base after branching counts as not new.
M0: complete (c8a78b1..92cecaa)
