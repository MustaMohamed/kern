# Task 32 review (8e69c1b, 73d7b8f)

Spec verdict: compliant.
Quality verdict: approved. No Critical or Important findings; four Minors.

## Findings

### Minor 1: no test pins the 200 boundary
tests/hooks/prompt-submit.bats:~249 (the long-line test) uses a 30 KB line, so any cap from 201 up to about 20000 passes.
Mutation: `-le 200` changed to `-le 2000` in hooks/prompt-submit:128 leaves every bats test green.
Scenario: someone raises the cap to 10000, the quadratic sed loop costs seconds again, and no test notices; or lowers it to 100 and nothing notices.
Fix: add a 200-vs-201 case. Both pad forms work: `"go terse"` followed by 192 spaces must switch to terse, and 193 spaces must not. Or add the cases to cases.json.

### Minor 2: the cap counts trailing spaces but not leading ones
hooks/prompt-submit:127-128, with the leading strip at line ~157 (`sed '1s/^[[:space:]]*//'`).
Measured on bash 5.3 and /bin/bash 3.2.57, BSD sed:
- `go terse` + trailing spaces to 199 or 200 total: terse. At 201: normal (refused).
- `go terse` + leading spaces to 199, 200 or 201 total: terse, because TRIM already stripped them.
- `go` + 300 inner spaces + `terse`: refused.
Answer to the padding question: yes, a valid phrase padded to over 200 raw characters is refused, whether the padding is trailing or inner. The comment's "no phrase is that long" is true of phrases, not of padded lines. Accepting this is reasonable: reject-not-truncate was the ruling, and 200+ trailing blanks is not a real prompt.
Scenario: none realistic. The mode doc says "a line over 200 characters", which is slightly off since leading blanks are not counted.
Fix (optional): say "over 200 characters after leading blanks" in the doc, or leave it.

### Minor 3: need_lists_match still misses two indirect load forms
tests/helpers/common.bash, `odd_lib_sources`.
Probed against a copy of pre-tool-use with one extra line prepended. Rejected (status 1): indented `.`, `source`, loop with `$lib`, braced `${KERN_ROOT}`, unquoted path, `x=1 .`, a commented-out source (a false positive, in the safe direction).
Accepted (status 0): `d=$KERN_ROOT/hooks; . "$d/lib/json.sh"` and `eval '. $KERN_ROOT/hooks/lib/json.sh'`, because neither line contains `hooks/lib/` in the form the grep reads.
Scenario: someone adds a library through a variable prefix and the need list is not checked against it.
Fix: also flag any `\.|source` line containing `/lib/`, not only `hooks/lib/`. Low priority; nobody writes the hook that way today.

### Minor 4: sweep, finish-branch `git status *` runs a repo-config program unprompted
skills/finish-branch/SKILL.md:5.
Measured: with `core.fsmonitor=<script>` in the repo config, `git status --porcelain` starts the script (GIT_TRACE shows start_command). `git check-ignore`, `git worktree list`, `git rev-parse` and `git remote -v` do not start it.
So the sweep's "may run fsmonitor" is confirmed, and help's new list is clean of it.
Effect: code runs from repo config without a prompt. It needs write access to .git/config, which already allows hooks, so the real exposure is small. Grade Minor.
Fix: narrow to `git status --porcelain` and the exact rev-parse forms the skill prescribes, or run it under the same GIT_CONFIG override the hooks use. The report's note that kern-detect's git calls lack that hardening is correct; same grade, separate fix.

`gh pr list *` (same file):
- `--web` opens a browser (confirmed in `gh pr list --help`). It writes nothing and runs no program. Effect: a stray window. Minor, cosmetic.
- `-R other/repo` reads another repo's PR list with the user's own token and prints it into the session. It sends nothing out beyond the query. No leak found. Minor, informational; `--search` is the same class.

## Checks by item

1. `natural`
- The cap runs on the raw first non-blank line before any sed on that line (line 128, before the sed at 129). The only earlier sed is `sed -n '/[^[:space:]]/{p;q;}'`, which stops at the first non-blank line.
- Corpus: 205 cases pass. Mutation results below.
- CR (`go terse\r`), tab (`go\tterse`) and a leading blank line (`\n\n  go terse`): terse.
- Multi-line: `go terse\nand fix bug` switches because only the first non-blank line counts, as documented. `fix bug\ngo terse` does not switch.
- `use terse voice for the logger`: no switch.
- Identical results under bash 5.3.15 and /bin/bash 3.2.57, with BSD sed. `shellcheck -x -S warning hooks/prompt-submit` is clean.
- The hardened-git block (lines 7-14) is untouched by the diff (the diff touches only lines 119-134), and the git-hardening tests pass.
2. need_lists_match
- Strict as specified, see Minor 3 for the two gaps.
- prompt-submit has no `need` lines. It sources four libs unguarded in a `for lib` loop, so there is nothing for need_lists_match to compare, and it is not run on prompt-submit. A need-list mismatch cannot occur there. The old check also did not cover it (it ran on pre-tool-use and session-start only). Not a gap.
3. help allowed-tools
- Every git or script command in skills/help/SKILL.md maps to an entry: `git remote -v`, `git rev-parse --git-common-dir`, `git check-ignore -q <path>`, `git worktree list`, `kern-detect`, `kern-get`, `kern-root`. `kern-dir` is deliberately absent and prompts, and so does the `>>` append to info/exclude. references/ prescribes no git and only `kern-root`.
- `git check-ignore -q *`: its options are -q, -v, --stdin, -z, -n, --no-index and --index. None write or run a program. `-c` and `-C` after the subcommand fail with `error: unknown switch` (exit 129); they are not read as paths, and not as git's global options.
- The pin test compares the whole string and asserts the only `*)` git entry is check-ignore -q. A re-added wildcard fails it.
4. Sweep: see Minor 4. The other skills are as the report says.
5. Doc wording in skills/mode/SKILL.md:23-24 matches the hook: first non-blank line, leading please/ok/okay, trailing please/now/./!, extra spaces, " mode" after terse or normal, the 200 cap, and the two new phrases.
6. Gates all pass, see below.

## Commands run and results
- `tests/run-bats tests/hooks/prompt-submit.bats tests/hooks/pre-tool-use.bats`: 0 failures (pre-tool-use ends at ok 42).
- `node --test 'tests/**/*.test.mjs'`: 215 pass, 0 fail.
- `node scripts/lint-skills.mjs`: clean.
- `shellcheck -x -S warning hooks/prompt-submit`: no output.
- Manual `natural` probes via the hook under bash 5.3 and /bin/bash 3.2.57: results above (scratchpad nat.sh).
- need_lists_match probes (9 forms): scratchpad nl.bats.
- `git check-ignore -h` and `-c`/`-C` probes; fsmonitor probes per git subcommand with GIT_TRACE.
- Mutations on a `git archive HEAD` copy under scratchpad/t32/m (the repo was not touched), running prompt-submit.bats:
  - M1 delete the cap: caught (test 25, slow).
  - M2 remove the blank fold (it also dropped part of the trim): caught (corpus test 23).
  - M3 remove "terse voice" and "terse mode on": caught (corpus test 23).
  - M4 cap changed to 2000: NOT caught (Minor 1).
  - M5 move the cap after the sed: caught (test 25).
