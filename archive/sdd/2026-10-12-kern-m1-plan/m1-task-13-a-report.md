# M1 Task 13 unit A report (G14)

Saved by the controller from the implementer's replies.

Status before commit: NEEDS_CONTEXT on a third file (resolved: option 1). g13-g15 17/17; full bats 326/327 (only g02-g04-gh.bats:289, fixed by the approved one-line change); node 46/46; 253 s; shellcheck clean.

Family allowlists (exact, case-sensitive):
- github: create_issue update_issue add_issue_comment issue_write sub_issue_write label_write (review list; no github MCP loaded in the session to check).
- linear: save_issue save_comment create_issue_label save_issue_label save_project save_milestone (claude.ai Linear connector deferred-tool list, schemas read; save_issue_label added, create_issue_label is deprecated in its favour). Deletes, share/unshare, diff and review tools, releases, attachments out; label retire/restore, initiative and project labels, documents, status updates, initiatives, notifications out of scope.
- notion: notion-create-comment (claude.ai Notion connector). create-pages can mark a page as a skill or put it under a shared parent; update-page has replace_content and allow_deleting_content, so both stay out.
- jira, atlassian, asana, gitlab, monday, clickup, todoist, trello, shortcut, height, zendesk and any mcp.write_servers entry: none (no source; those connectors show only authenticate tools here).

Behaviour choices (accepted): substring match kept for ask/deny, whole-word family for an allow; ambiguous or decorated server names get no allow; early return keeps quoted gh; write verbs read split and unsplit (reOpen_issue).

Commit 4f06b87 "M1: G14 closed per-family MCP allowlists, gh delete and alias fixes" (g14-tracker.sh, g13-g15.bats, g02-g04-gh.bats line 289 only). bats 327/327, node 46/46, 252 s, shellcheck clean.

Concerns: argument-level wrong allows under auto (W1 a github tool comments on any repo the token reaches; W2 label_write method delete; W3 github assignees set to Copilot starts an agent; W4 Linear save_issue delegate hands the issue to an agent; W5 Linear save_issue team moves the issue); 8 of the review's 28 writes still get no vote (request_copilot_review among them); the new `run` verb makes github reads such as get_workflow_run ask (denied under autopilot).

## Parts 1-3 (delivered after the commit)

- Choice 5: writes ce5bb04 allowed that now ask under auto: mcp.write_servers servers (no family list, e.g. youtrack update_issue); atlassian, jira, asana, monday, todoist, gitlab and other list-less families; `gh issue develop --list` (a read) asks under ruling (5).
- TDD: RED at ce5bb04 for tests 14 (merge allowed), 15 (createJiraIssue no vote), 16 (`gh issue new` no vote); test 17 (gh in another case, a path, g''h) is a regression pin that fails against the ruling's literal prefilter. GREEN 17/17; reOpen_issue added RED then GREEN with split and unsplit verbs. Full suite 326/327 before the third-file line, 327/327 after.
- Allow probes: the review's 130 names under auto went from 85 allows to 11, all list entries; 20 of the review's 28 no-vote writes now ask. A 183-name probe gives 44 allows, exactly the list entries on github/claude_ai_GitHub/GitHub, linear/claude_ai_Linear/plugin_engineering_linear/Linear-MCP, notion/claude_ai_Notion; 135 ask (decorated, decoy, cross-family, list-less); 4 no vote. gh: of the review's 98 shapes exactly 8 changed, all intended; 24 allows remain; issue new matches issue create on 23 pairs. A 304-name superset check lost no vote ce5bb04 gave.
- Wrong allows at the argument level: W1 github tools reach any repo the token reaches (most serious); W2 label_write method delete; W3 assignees naming the Copilot agent; W4 Linear save_issue delegate (assignee same class); W5 Linear save_issue id plus team moves the issue. Implementer recommends dropping github from the MCP auto path (gh covers the same writes with a proven shape) and argument rules for Linear only.
- Timing (machine slower today: ce5bb04 168-171 ms on ls): ls 161 ms after; G14 alone on ls 10.3 ms before, 2.8 ms after; MCP save_issue 88.2 -> 79.6 ms; gh issue close 97 ms both.
- Still no vote (8): github request_copilot_review, dismiss_notification, manage_notification_subscription, star_repository; gitlab cancel_pipeline; notion-spawn-session, notion-stop-session, notion-convert-page-to-skill. Candidate verbs: copilot, cancel, spawn, stop, convert, dismiss, star, manage.
- The `run` verb makes github reads ask (get_workflow_run, list_workflow_run_artifacts, download_workflow_run_artifact).
- The github list is unchecked against a loaded github MCP. A server with linear as a word gets Linear's list (per ruling (1)).
- Scratch: t13a/ (gh-base.tsv, gh-new2.tsv, mcp-base.tsv, mcp-new2.tsv, allow-new2.tsv, p-allow.txt).

## Fix round 1 (original ruling, before the amendment): 1dbca9b

Commit 1dbca9b "M1: G14 MCP allows prove their arguments; read-first tools never vote" (g14-tracker.sh, g13-g15.bats). g13-g15 22/22, g02-g04-gh 34/34, shellcheck clean.
- (a) as first ruled: github owner/repo equal the main worktree's github.com origin (git remote get-url, parsed; 26 URL forms probed, 0 mismatches), label_write create/update, no copilot assignee/reviewer; Linear save_issue no delegate, no team with an id; any family: a backslash-u escape in tool_input asks (kern's JSON reader leaves it undecoded), and a value key must appear once (_g14_once). Values read with a sentinel so a trailing escaped newline cannot pass.
- (b) a first word that is a read verb never votes; (c) verbs request dismiss manage star cancel spawn stop convert catch the 8.
- Corpus: 176 reads, 114 writes; new false ask github pull_request_read (request verb); leftover false ask download_workflow_run_artifact; fixed get_workflow_run and 5 more; no vote lost (304-name check); unstar_repository has no vote.
- 41 argument probes (12 allow, 29 ask), 7 escape probes, 0 mismatches.
- Timing: ls 162.4 -> 162.9 ms; add_issue_comment allow 90.7 -> 100.7 ms; Linear save_issue allow 80.4 -> 87.9 ms.
- Choices: github.com only; backslash-u rule for every family (a Windows path in a body asks); copilot check only when the word appears; Linear keys at any depth; the read rule takes the first word only.
- Concerns: pull_request_read and download_workflow_run_artifact ask; unstar has no vote; sub_issue_write's sub_issue_id may name another repo; Linear assignee allowed; github and other names from memory. Re-review note: build backslash-u payloads with printf or chr(92) and check with od.

## Amended fix round: 9df7f01

Commit 9df7f01 "M1: G14 github MCP writes ask; Linear assignee asks; download reads" on 1dbca9b (g14-tracker.sh, g13-g15.bats; a 74-character first subject amended at once, nothing pushed). g13-g15 21/21, g02-g04-gh 34/34, shellcheck clean.
- github has no list: every github MCP write asks under auto, denied under autopilot; _g14_origin and _g14_once removed. Linear save_issue asks on a delegate or assignee key (any value, null included), or team with id. The backslash-u rule stays.
- download is a read verb; copilot replaces request as a verb.
- RED at 1dbca9b for the matching-repo github comment, a Linear assignee, download_workflow_run_artifact and pull_request_read; GREEN 21/21.
- Probes: 21 argument, 7 escape, 0 mismatches; 26 allows, all Linear or Notion list names; 130 review names and 98 gh shapes unchanged; no read votes in the 290-name corpus; 0 votes lost against 4f06b87 and 1dbca9b.
- Timing: ls 158.6-161.8 ms (no change); github add_issue_comment G14-only 99.0 -> 79.0 ms.
- Concerns: unstar_repository no vote; a null assignee asks; the github reason does not point to gh.
