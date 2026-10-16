# M1 Task 13 report: G13, G14, G15

The implementer cannot write report files (harness rule); the controller saves its SendMessage parts here, unchanged in substance.

## Part 1: status, commits, files, deviations

Status: DONE_WITH_CONCERNS.

Commits (local main, not pushed):
- 60f0f3d M1: add G13, G14 and G15 for protected targets, trackers and deploys. The brief verbatim with its message; extracted tests and guards diffed identical to the brief, which is identical to the plan's Task 13.
- ce5bb04 M1: G14 allows only a proven gh shape; G15 asks on unknown targets. Both binding corrections plus the `*` rule (amended from 99b799c, unpushed; the `*` rule has its own test 13).

Recounted: G13 74 misses (75 probes with no vote, one `rsync ... --dry-run` has no effect); G14 MCP path 25 wrong allows (two are the delete policy question); G14 misses 17 MCP tools plus 6 gh verbs; G15 51 final misses; the brief's gh path had 54 wrong allows.

Files:
- hooks/guards/g13-protected.sh: brief Step 3 verbatim.
- hooks/guards/g14-tracker.sh: brief Step 4; commit 2 adds gh 2.100 option tables for the issue and label verbs G2 lacks, `_g14_proven`, a PROVEN argument to `_g14_decide` (default 1, MCP path unchanged), a `_gh_load` loop in `_g14_gh`.
- hooks/guards/g15-deploy.sh: brief Step 5; commit 2 adds two votes in the push-target loop, an empty target (detached HEAD) and a `*` target, both ask (deny under autopilot), only when deploy.envs is set.
- tests/hooks/g13-g15.bats: brief Step 1 verbatim (10 tests) plus 3 appended.

Commit 2, G14: tracker.policy auto allows a gh issue or label write only when `_g14_proven` passes: `_gh_proven` (first record, starts with `gh `, later records `_g01_filter` filters, no substitution, `_gh_literal`, no `?` token, quiet redirections only), `_gh_only` against the verb's closed safe set, the argument rule, `_gh_file_ok` for --body-file. Reused `_GH_COMMENT_OPTS`/`_GH_COMMENT_SAFE` (g03) for issue comment; new tables for issue create, edit, close, reopen, lock, `_GH_YES_OPTS` (issue delete, label delete), `_GH_REPO_OPTS` (transfer), label create, label edit. Arguments: none for issue create; one label name for label verbs; one issue number in digits otherwise (a URL may name another repo); transfer takes two, so always asks. Left out of every safe set: repo (-R/--repo fail), attach, recover, template, body, editor, web, assignee and add-assignee (@copilot starts the Copilot agent), parent, blocked-by, blocking, sub-issue, duplicate-of. An unproven write asks; autopilot denies every tracker write.

## Parts 2 to 9: not delivered

A safety classifier halted the implementer's report messages (the probe lists hold destructive command text). The raw probe data stays in the scratchpad `t13/` (p-g13.txt, p-g13fp.txt, p-g15.txt, p-gh*.txt, gh-table.tsv, run.sh). Open policy questions named by the implementer: tracker deletes under auto; github and gitlab on the MCP allow path; the commit-2 safe sets. Counts: G13 74 misses, G14 MCP path 25 wrong allows, G14 misses 17 MCP tools plus 6 gh verbs, G15 51 misses, the brief's gh path 54 wrong allows (closed by ce5bb04).
