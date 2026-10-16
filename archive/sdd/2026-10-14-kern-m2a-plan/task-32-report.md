STATUS: DONE (all five gates green)

SHAs (base e087653)
- 8e69c1b  M2: close the 0.2.1 minor findings
- 73d7b8f  M2: help allows only the exact git commands it prescribes

Tests, failing then passing
- Commit 1, run against HEAD code with the new tests copied in (isolated worktree, removed after): prompt-submit.bats not ok 23 (corpus), 25 (200-char), pre-tool-use.bats not ok 42 (need-list); skills-control mode wording test not ok 7.
- After: prompt-submit.bats + pre-tool-use.bats 0 failures; node --test 'tests/**/*.test.mjs' pass 215 fail 0; lint-skills clean; shellcheck clean; plugin validate passed.
- Commit 2, new help tests against the old SKILL.md: not ok 5 and not ok 7 (pass 5, fail 2). After: pass.

Long-line timing
- 30 KB first line (go terse + 15000 " ."), whole hook run, 3 runs: 0.128 s, 0.111 s, 0.111 s. Before: about 10 s. The cap returns before the sed loop, so cost is one `sed -n` plus a length test; the 3 s bound has a 25x margin. SECONDS has 1 s resolution, so the test only fails if the hook takes 3+ s of real time.

Help allowed-tools
Before: Read, git remote *, git symbolic-ref *, git log *, git for-each-ref *, git worktree list *, kern-get *, kern-detect *, git rev-parse *, git check-ignore *, kern-root *
After:  Read, git remote -v, git rev-parse --git-common-dir, git check-ignore -q *, git worktree list, kern-get *, kern-detect *, kern-root *
Git commands help prescribes (SKILL.md, references/): `git remote -v` (Setup 1), `$(git rev-parse --git-common-dir)` (Setup 6), `git check-ignore -q <path>` (Setup 6), `git worktree list` (Check). Nothing prescribes symbolic-ref, log or for-each-ref (kern-detect runs git itself, outside allowed-tools).
Why each entry is safe
- git remote -v: exact; lists, no add/set-url.
- git rev-parse --git-common-dir: exact; prints a path.
- git check-ignore -q *: only wildcard over git; prefix fixes the subcommand and -q, so the tail is pathnames or other check-ignore options (--stdin, -v, -n, --no-index, -z), none of which write or run a program. `git -c` cannot be injected, since the prefix starts `git check-ignore`.
- git worktree list: exact; the list subcommand takes no write.
- kern-get / kern-detect / kern-root `*`: scripts read only (settings, repo files, git reads); args are a key, or a dir for kern-root.
Dropped, not replaced: git symbolic-ref, git log, git for-each-ref, git rev-parse *, git remote * (would now prompt if the model runs them; help does not need them). kern-dir stays unlisted (writes), so Setup 6 prompts as before. The append to info/exclude is a shell write and prompts too.
Tests: skills-help.test.mjs pins the exact string and that check-ignore -q is the only git entry ending in `*`; the older line 56 assertion was updated to the new entries.

Sweep of skills/*/SKILL.md allowed-tools (changed only help)
- autopilot: Read, Glob, kern-root *, kern-get *. Clean.
- commit: kern-get *, kern-detect *. Clean.
- mode: Read. Clean.
- finish-branch: `git status *` is low risk: no option writes a file or runs a program, but status refreshes the index (a write to .git/index), and core.fsmonitor in repo config would run a program. `git rev-parse *` reads only. `gh pr list *` writes nothing, though --web opens a browser and -R reads another repo. No --output, --ext-diff, -c, --upload-pack or --exec class found. Suggest narrowing git status to `git status --porcelain` and `git rev-parse --abbrev-ref HEAD` style exacts later.
- Scripts kern-get/kern-detect/kern-root `*`: no write path via args. kern-detect calls git (symbolic-ref, log reads) with repo config in force, not hardened like the hooks.

Deviations
- Commit 1 message follows the brief. Implementation was written before I proved the red state; I proved red afterwards by running the new tests against HEAD code in a temporary worktree (removed). Same for commit 2 (old SKILL.md restored briefly, then re-copied).
- Corpus is now 205 cases per the brief (not recounted by me; test passes).
- `git status` showed no leftover changes after commit 2.

NOTICED BUT NOT TOUCHING
- finish-branch git status * / gh pr list * as above.
- kern-detect git calls do not get the GIT_CONFIG fsmonitor/hooksPath hardening that the hooks have.
- hooks/prompt-submit sources libs in a `for lib in ...` loop, which odd_lib_sources would flag; need_lists_match is only run on pre-tool-use and session-start, so no test fails, but adding it to prompt-submit would.
