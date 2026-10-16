DONE

SHA: 34b64b5 (base 48aa899, branch main, explicit paths, no attribution)

Tests, failing then passing
- Before edits: `node --test tests/voice.test.mjs` pass 0 fail 2; bats: not ok 19 (Reply lines) and not ok 23 (subagent return); rest ok.
- After: `node --test 'tests/**/*.test.mjs'` pass 182 fail 0; bats 23/23 ok; `node scripts/lint-skills.mjs` clean; `node scripts/route-eval.mjs` passed (rank-1 83%).

Budgets (measured after edit, 50-char root, as bats/rule 7 measure)
- Kernel, no settings: 3,341 chars (limit 4,000). Brief predicted 3,487 after Task 30; Task 30 not yet applied, so lower is expected.
- Kernel, long-settings fixture: 3,813 (target 4,000; brief predicted 3,926 after Task 30).
- Subagent kernel 715 + terse-subagent 188 = 903 of 1,200 (brief predicted about 1,092 after Task 30).
- Rule 7 kernel + terse.md: 3,813 + 2,067 = 5,880 of 9,000.

Check 1
Premise holds. agents/ holds three files. implementer.md writes its full report to the dispatch-given report path. investigator.md says "You write no file" and names a command for the controller. task-reviewer.md cannot run commands or edit and returns verdicts inline. No agent relied on the dropped kernel sentence. No NEEDS_CONTEXT.

Check 3/4
No long dashes or curly quotes in kernel.md, kernel-subagent.md, terse*.md, voice.test.mjs (grep found none). The rendered kernel passes the bats test for both new lines, colons and commas intact.

Deviations
None. Lines verbatim from the brief.

NOTICED BUT NOT TOUCHING
- Terse rule 8 and the Before-sending section are unchanged.
- terse-subagent.md now has a trailing newline, as the brief's block implies; the old file's was equal.
