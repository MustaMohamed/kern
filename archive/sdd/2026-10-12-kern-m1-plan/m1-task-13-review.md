### Spec Compliance

- ✅ G13 is brief Step 3 verbatim (`hooks/guards/g13-protected.sh:5-59`). It denies in both modes and is inactive without `protected_targets` (`:9`).
- ✅ G14 is brief Step 4 plus ruling (2) (`hooks/guards/g14-tracker.sh:110-144`). `-R`/`--repo` is in no safe set, an unproven write asks (`:84-86`), and autopilot denies first (`:72-75`). All 98 `gh-table.tsv` shapes re-run on ce5bb04: 0 mismatches.
- ✅ G15 is brief Step 5 plus rulings (1) and (3) (`hooks/guards/g15-deploy.sh:27-35`).
- ✅ Tests: the brief's 10, plus 3 more (`tests/hooks/g13-g15.bats:102,118,132`).
- ❌ Contract `docs/plans/contract.md:100` says an allow must prove the full shape. The MCP allow (`g14-tracker.sh:47-58,83`) proves only a tracker word in the server name and a write word in the action. Issue 1. Plan-mandated.
- ❌ The brief says reads stay allowed (`g13-protected.sh:3`), but 10 of 11 read probes are denied. Issue 2. Plan-mandated.
- ⚠️ G13 fires only when the target string appears in the command (`:17`). SQL over an SSH tunnel (`mysql -h 127.0.0.1 -P 3307`), or a script that connects, never names the target. The real V1 MySQL write path is outside G13: document it, or add a `host:port` entry form.

### Strengths

- The gh proof holds: 25 of 98 shapes allow, all intended; chains, cd, env, URLs and outside body files ask.
- It reuses the `_gh_*` helpers. G15 asks on an unknown push target, with tests.

### Issues

#### Critical

1. `g14-tracker.sh:39-58,83`: the MCP allow goes by tool name (plan-mandated). I ran `run.sh --tool` on 130 names under `tracker.policy: auto`: 85 allow, and 46 of those are wrong.

| Class | n | Examples |
|---|---|---|
| Code-hosting writes | 26 | `mcp__github__merge_pull_request`, `mcp__github__create_or_update_file`, `mcp__gitlab__merge_merge_request`, `mcp__claude_ai_Linear__merge_diff` |
| Deletes | 10 | `mcp__claude_ai_Linear__delete_comment`, `mcp__atlassian__confluence_delete_page` |
| Sharing outward | 4 | `mcp__claude_ai_Linear__share_issue`, `mcp__github__create_gist`, `notion-move-pages` |
| Agent or config triggers | 4 | `mcp__github__assign_copilot_to_issue` (the gh path refuses @copilot), `notion-upload-skill` |
| CI and release | 2 | `mcp__gitlab__create_pipeline`, `mcp__gitlab__create_release` |

Why it matters: an allow skips Claude Code's prompt and gets around the push, pr and review.post policies, which have no MCP path. The server match is a substring (`:39-44`).

Fix: under auto, allow only a closed list of issue, comment, label and project actions for each family (github: `create_issue`, `update_issue`, `add_issue_comment`, `issue_write`, `sub_issue_write`, `label_write`). Any other write on a matched server asks, and is denied under autopilot. Match the family as a token, not a substring. Add tests that pin a merge, a delete and a share as ask.

#### Important

2. `g13-protected.sh:32,41,56`: permitted reads are denied (plan-mandated). 10 of 11 `p-g13fp.txt` probes deny. They include `ssh v1-host 'dir C:\data' 2>&1` and `ssh v1-host ls 2>/dev/null`, which are exactly the reads the user's V1 rule permits. Three causes:
- Any `>` in the joined ssh words counts as a write (`:41`).
- A local path that contains the target name counts as the destination (`:32`).
- Every SQL keyword in the whole command is scanned (`:56`): a commit message or a grep trips it, and `pg_dump -f out.sql` reads its own output file.

Fix: look for `>` only in the remote command. Take the destination from the last positional `host:path` word. Scan SQL only in a client's `-c`/`-e` values and input files.

3. G13 misses, ranked by cost on a read-only Windows host. The ruling says to report these, not apply them. 68 of 82 probes get no vote.

| Rank | Class | n | Examples | Fix (all cheap and safe) |
|---|---|---|---|---|
| 1 | ssh write outside the verb list (Windows, uppercase, services, scripts) | 13 | `ssh v1-host 'DEL C:\data\x'`, `ssh v1-host 'perl app2020arcp.pl'` | Invert: the remote command must be on a read list (`dir ls type cat Get-ChildItem Get-Content findstr`), else deny |
| 2 | Remote shell on stdin or a heredoc, or no command | 7 | `ssh v1-host bash < fix.sh`, `cat fix.sh \| ssh v1-host bash` | No command, or a shell as the command, denies; `-N` is exempt |
| 3 | SQL forms the regex lacks | 21 | `UPDATE users2 SET a=1`, `LOCK TABLE users`, `INTO OUTFILE` | Invert: each statement starts with SELECT, SHOW, DESCRIBE, EXPLAIN or WITH, and has no OUTFILE or LOCK; else deny. Minimum: add `0-9` to the name class |
| 4 | SQL source not read | 7 | `mysql -h prod-db.internal < fix.txt`, `cat fix.sql \| mysql ...` | Read any file after `-f` or `<`, and expand `~`; a piped input denies |
| 5 | scp/rsync: last word is a redirection or option; host case | 6 | `scp a.txt v1-host:/data/ 2>&1`, `rsync --remove-source-files v1-host:/data/x .` | Take the last positional, match the host in any case, and deny `--remove-source-files` |
| 6 | sftp batch, pipe or heredoc; missing verbs | 6 | `sftp -b batch.txt v1-host`, `<<< 'reput ...'` | Read the `-b` file and here-strings; allow only get, ls, cd and similar reads |
| 7 | Head not recognised (path, case, wrapper) | 8 | `/usr/bin/ssh v1-host 'rm -f /data/x'`, `caffeinate scp ...` | Lowercase the basename of the head; the hidden-word scan (as in `_g01_hidden`) costs more |

4. `g15-deploy.sh:12-13`: 51 forms get no vote in either mode; autopilot stops none (plan-mandated, deferred by the ruling).

| Rank | Class | n | Examples | Fix (all cheap and safe) |
|---|---|---|---|---|
| 1 | Wrappers: the awk drops only bare wrapper words | 8 | `timeout 600 terraform apply`, `env NODE_ENV=production npm publish` | Use `_cmd_words` instead of the awk |
| 2 | Global options before the verb | 13 | `kubectl -n prod apply -f x.yml`, `terraform -chdir=infra apply` | Skip options, and the values of known value-taking options |
| 3 | Runners | 12 | `npx -y vercel deploy`, `pnpm dlx vercel deploy --prod` | Strip npx, dlx, exec and bunx; add wrangler, netlify and aws-cdk |
| 4 | Tools or verbs missing | 11 | `gcloud run deploy api`, `helm delete api` | Add those two, plus flyctl, `gh run rerun`, `docker stack deploy`, `uv publish` and others |
| 5 | Head case or path | 7 | `TERRAFORM apply`, `./node_modules/.bin/vercel deploy --prod` | Lowercase the basename of word 1 |

The 5 missed push forms cost nothing: G1 asks on them, and denies under autopilot.

5. G14 misses that get past the autopilot deny:
- gh (`g14-tracker.sh:100`). These get no vote in either mode: `issue new` (an alias of create), `issue develop` (creates a remote branch), `issue pin`, `unpin`, `unlock`, and `label clone`. Fix: add them to the case, with `new` on create's table and the rest unproven. Cheap and safe.
- MCP. 28 writes get no vote in any mode:
  - The Atlassian connector's camelCase names (`createJiraIssue` and 5 others) never split on `_` (`:62-66`).
  - Verbs are missing: push (`push_files`), run, rerun, retry, play, fork, schedule (`slack_schedule_message`), duplicate, restore and unshare.
  - Fix: split camelCase names and add the verbs, but only after fix 1, or under auto they become allows.

#### Minor

6. Cost. `ls` takes 126 ms at 88d6d4f and 160 ms at ce5bb04. Per guard:

| Part | ms | Where the time goes |
|---|---|---|
| G15 | ~15 | `ti_get`, `settings_get`, and a pipeline for each segment |
| G14 | ~10 | `_gh_load` and `gh_sub` |
| Sourcing the three files | ~5 | |
| G13 | ~4 | `settings_get` |

A scratch copy with prefilters measured 139 ms (-21 ms). G14 returns unless the decoded command contains `gh` in any case; G15 returns, before `settings_get`, unless it names one of its tools. A prefilter on raw `$TOOL_INPUT` gave 135 ms, but a `\u` escape can hide letters, so it is not a proven superset. Prefilter on tool names, not verbs, so it stays a superset after issue 4's fixes.

7. `tests/hooks/g13-g15.bats:59-65`: the only MCP allow test is a positive one. Nothing fails if a merge or a delete becomes an allow. Add those tests with fix 1.

#### Policy questions

(a) Tracker deletes under auto: always ask. A GitHub issue delete and a Jira delete are permanent, and auto was granted to file and update. Drop `issue delete` and `label delete` from `_g14_proven`, and treat any MCP `delete` action as unproven.

(b) github and gitlab on the MCP path: keep them for ask and deny, but allow only their issue tools (fix 1). Their code, CI and review tools belong under the push, pr, review.post and deploy policies, which have no MCP path. File the gap as a follow-up.

(c) ce5bb04's safe sets: right and conservative. Remove `yes` per (a). Keep `label create --force` (same reach as `label edit`). Add the verbs from issue 5.

### Assessment

**Task quality:** Needs fixes. The gh proof is sound, but the MCP allow approves merges, commits, deletes and shares by tool name, and on the user's real host G13 denies the permitted reads while missing most writes.
