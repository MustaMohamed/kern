# kern settings

Files, highest first:
1. `.claude/kern.local.yml`, the default per-project file, untracked.
2. `.claude/kern.yml`, shared, committed only if a team wants it.
3. `~/.claude/kern.yml`, the user's defaults.

kern reads project files from the main worktree root. The highest file that sets a key wins. Four list keys add up across all files instead: `protected_targets`, `never_commit`, `branch.protected` and `deploy.envs`. A project file therefore cannot drop an entry that the user file sets. Two settings do not follow highest-wins for the committed `.claude/kern.yml`, because a cloned repo could use them against the user. `kern: off` counts only from `.claude/kern.local.yml` or `~/.claude/kern.yml`, so a committed `kern: off` is ignored. The local file counts as local only when it is the user's own untracked file: a regular file, not a symlink, in a real `.claude` directory that is not a symlink, a submodule or a repository of its own and sits inside the main worktree, with git not tracking it in any case of its name. Otherwise it gets the committed-file rules. A committed policy key may be `ask` or `deny` and never `auto`: a committed `auto` reads as unset, so a lower file or the default applies. The same holds for `rebase.push: autopilot`. A committed `base_branch` only adds a protected branch: the `origin/HEAD` branch stays protected, as do main, master, trunk and develop when `origin/HEAD` is unknown. `autopilot: denied` in any file wins over `allowed` in a higher one.

Above all files, the user's instruction in this session comes first, then a project skill that owns the job, then project rules in CLAUDE.md, `.claude/rules` and memory. Project rules may tighten a setting and never loosen it.

Format: one `key: value` per line. `#` starts a comment at line start or after whitespace outside quotes. kern strips surrounding quotes, so quote a value that ends in a space. Lists are comma-separated. A key with `<...>` in this table stands for a family, such as `overrides.commit`. In the Read by column, `pre-tool-use G1` means guard G1 of the pre-tool-use hook.

Policy keys take `ask`, `auto` or `deny`, and default to `ask`. The hooks read any other value as `ask`. `auto` lets through only the shapes under What auto and autopilot allow below, and kern asks or denies every other shape. `deny` denies in both modes. Floor actions have no key and never loosen: merge, production deploy, data deletion, force-push to a shared branch, messaging people. kern reports and ignores a key that names a floor action.

| Key | Default | Values | Read by |
|---|---|---|---|
| `kern` | `on` | `on`, `off`. `off` turns off routing and guards in this project | session-start, subagent-start, prompt-submit, pre-tool-use |
| `kern_repo` | none | path to the kern clone, in the user file only | help |
| `work_dir` | `.kern` | relative directory at the main worktree root | kern-dir, pre-tool-use G2, G3, G5 and G14, all skills |
| `mode.voice` | `normal` | `normal`, `terse` | session-start, prompt-submit, subagent-start |
| `mode.voice.headless` | `normal` | `normal`, `terse`. The voice a headless session (`claude -p`, the Agent SDK) starts in, in place of `mode.voice` | session-start, prompt-submit, subagent-start |
| `mode.surface` | `auto` | `chat`, `auto`, `html` | session-start, prompt-submit |
| `autopilot` | `allowed` | `allowed`, `denied` | session-start, prompt-submit, pre-tool-use for every guard |
| `base_branch` | detected from `refs/remotes/origin/HEAD` | branch name | pre-tool-use G1 and G5, kern-detect, plan, finish-branch |
| `branch.pattern` | detected | pattern with `{id}` and `{slug}` | kern-detect, execute-plan, wt-new |
| `branch.protected` | none. `base_branch` and `deploy.envs` are always protected, and main, master, trunk and develop are when the base branch is unknown | comma list, added to those | pre-tool-use G1 and G5, commit, finish-branch |
| `deploy.envs` | none | comma list of deploy branches | pre-tool-use G1, G5 and G15, finish-branch, ship-check |
| `deploy.proof` | none | command or URL that proves a deploy | ship-check |
| `worktree.dir` | `.claude/worktrees` | directory under the main worktree root | wt-new, execute-plan, parallel-work |
| `worktree.setup` | none, and wt-new honours `.worktreeinclude` | shell command run in a new worktree | wt-new |
| `shared_services` | none: migrations and DB-backed tests overlap | comma list | plan, execute-plan, parallel-work |
| `parallel.max` | `3` | integer | parallel-work |
| `scope_threshold` | `4` | files per change before a pause | define, plan, implement, self-review, finish-branch |
| `pr.max_lines` | `300` | changed lines before a split is proposed | finish-branch |
| `test.focused` | detected | command. `{file}` stands for the test path. Where a file cannot be targeted, use `{dir}` for go or `{name}` for cargo | kern-detect, implement, diagnose, prove-it |
| `test.full` | detected | command | kern-detect, implement, prove-it, finish-branch |
| `typecheck` | detected | command | kern-detect, implement, prove-it |
| `lint` | detected | command | kern-detect, prove-it |
| `build` | detected | command | kern-detect, prove-it |
| `verify.fast` | each of `typecheck` and `lint` that resolves; at least one | command | self-review, prove-it |
| `verify.browser` | none: ask when a UI claim needs it | command | prove-it, diagnose, verify-app |
| `generated_artifacts` | none | comma list of `trigger-glob=command` | implement, prove-it, self-review |
| `ratchet.<metric>` | none | `<path>:<key>`, with `:max` appended when a higher value loosens the bar | floor-scan, self-review |
| `checklists` | existing data and consumers, authorization scope, persisted-shape change | comma list | define, plan |
| `tracker` | detected | `none`, `github`, `gitlab`, `linear`, `jira`, or another name | kern-detect, define, plan, recall, triage |
| `tracker.first` | `false` | `true`, `false` | define, plan |
| `tracker.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use G14 |
| `mcp.write_servers` | none | comma list of extra MCP server names treated as trackers | pre-tool-use G14 |
| `spec.source` | linked issue, PR body, `.kern/specs` | path or `issue` | prove-it, pr-review |
| `commit.convention` | unset. G5 then uses the convention kern-detect finds in the last 30 `git log` subjects, and checks none when it finds none | extended regular expression for the subject. An explicit empty `commit.convention:` turns the convention check off | pre-tool-use G5, kern-detect, commit |
| `commit.id_from_branch` | `[A-Z][A-Z0-9]+-[0-9]+` | extended regular expression | pre-tool-use G5, commit |
| `commit.attribution` | `none` | `none`, `allowed`. Governs commit trailers and a PR body's attribution footer | pre-tool-use G2, G5, commit, finish-branch, autopilot |
| `commit.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use G5, commit |
| `push.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use G1, finish-branch |
| `pr.policy` | `draft-after-approval`, read as `ask` | `ask`, `auto`, `deny`. PRs are always drafts | pre-tool-use G2, finish-branch |
| `pr.dedup` | `on` | `on`. G2 always checks | finish-branch |
| `pr.template` | detected | path | kern-detect, finish-branch |
| `rebase.push` | `ask` | `ask`, `autopilot` | pre-tool-use G1, take-feedback |
| `stack.tool` | detected | `gh-stack`, `git`, `none` | take-feedback, finish-branch |
| `protected_targets` | none | comma list. Each entry is an exact host, matched in any case, also as user@host or in a URL. An entry may also be a host:port, where localhost, 127.0.0.1 and ::1 count as one host, or an sqlite file path. List every ssh alias and each SSH tunnel's local host:port | pre-tool-use G13, diagnose |
| `evidence_agents` | none | comma list of project agents for read-only data | diagnose |
| `never_commit` | none | comma list of path globs | pre-tool-use G6, commit |
| `review.rules` | CLAUDE.md, `.claude/rules/**`, CONTRIBUTING.md | comma list of paths | self-review, execute-plan, pr-review |
| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` | comma list of labels | pre-tool-use G3, self-review, pr-review |
| `review.post_policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use G3 |
| `review.rounds` | `fanout-first-then-single` | `fanout-first-then-single`, `single` | pr-review |
| `review.sensitive_paths` | auth, permission, migration and secret paths by name | comma list of globs | pr-review |
| `review.builtin` | `on` | `on`, `off` | self-review, pr-review |
| `review.builtin.self_effort` | `low` | `low`, `medium`, `high` | self-review |
| `review.builtin.effort` | `high` | `low`, `medium`, `high`, `xhigh`, `max` | pr-review |
| `review.builtin.delta_effort` | `medium` | as above | pr-review |
| `review.builtin.max_findings` | `15` | integer or `all` | self-review, pr-review |
| `review.builtin.security` | `off` | `on`, `off` | pr-review |
| `security.rules` | project prose | comma list of paths | pr-review |
| `lessons` | none: proposals stay in chat | path | self-review, retro, correct |
| `rule_bar` | 3 occurrences or 1 severe incident, 2 for a mechanism | text | retro, correct |
| `model.implementer` | `sonnet` | model alias | execute-plan, parallel-work |
| `model.reviewer` | `sonnet` | model alias | define, execute-plan |
| `model.final_review` | `opus` | model alias | execute-plan |
| `model.investigator` | `sonnet` | model alias | define, plan, diagnose |
| `model.miner` | `haiku` | model alias | recall |
| `model.implementer.effort` | `low` batched, `medium` normal, `high` cross-module or round 3 | `low`, `medium`, `high`, `xhigh`, `max` | execute-plan, parallel-work |
| `model.reviewer.effort` | `medium` | as above | define, plan, execute-plan, self-review |
| `model.final_review.effort` | `high` | as above | execute-plan |
| `model.investigator.effort` | `low` | as above | define, plan, diagnose, self-review |
| `model.miner.effort` | `low` | as above | recall |
| `workflow_records` | none | comma list of paths or tools with run records | recall |
| `stack` | detected | text | architect, build-ui, implement |
| `overrides.<job>` | none. session-start also finds a project skill with the job's name | project skill name, or `off` for no override: kern's route stays and the same-name match is off | session-start, every skill |

G13 lets through only proven reads to a `protected_targets` entry and denies every other call that names one, in both modes.

## What auto and autopilot allow

A policy key set to `auto`, or autopilot, lets an action through without asking only in the shapes below. For any other shape kern asks or denies, and autopilot denies it. The guard's reason names the shape it wanted.

| Action | Allowed shape | With the policy key at `auto` | Under autopilot |
|---|---|---|---|
| Commit | `git commit -m <msg>` or `git commit -F <file>`, exactly one of the two, plus only `-q` or `-v`, on a branch that is not protected. The message passes the convention, ticket-id and attribution checks | `commit.policy` allows it | allowed |
| Push | `git push [-u] <remote> <current-branch>` to a branch that is not protected. The remote is one `git remote` lists, with no push URL and no URL rewrite | `push.policy` allows it | allowed |
| Lease push | `git push --force-with-lease <remote> <current-branch>` to a branch that is not protected, when every commit on it past the base branch is the user's | never allowed. It asks or denies | allowed only with `rebase.push: autopilot` |
| Draft PR | `gh pr create --draft` from the current branch, with `--title`, `--base`, `--fill`, `--fill-first`, `--fill-verbose`, `--dry-run`, `--no-maintainer-edit`, `--body-file <file>` or `--head` naming the current branch, after the duplicate check finds no PR for the branch | `pr.policy` allows it | allowed |
| Review post | `gh pr review [<number>]` with `--comment`, `--request-changes` or `--approve`, or `gh pr comment [<number>]`, with any body in `--body-file <file>` | `review.post_policy` allows it | denied |
| gh issue or label write | `gh issue create`, `comment`, `edit`, `close`, `reopen` or `lock`, or `gh label create` or `edit`, in this repo. The command names an issue by number, not by URL | `tracker.policy` allows it | denied |
| Linear MCP write | `save_issue` with no assignee, no delegate and no move to another team, `save_comment`, `save_issue_label`, `create_issue_label` or `save_milestone` | `tracker.policy` allows it | denied |
| Notion MCP write | `notion-create-comment` | `tracker.policy` allows it | denied |
| GitHub MCP write | none. A github MCP tool can name any repo, so use `gh issue` or `gh label` | always asks | denied |

Under autopilot kern also denies commands it cannot read: a command name built at run time, a shell script it cannot parse, and code piped into a shell. Interpreter code in a file, or a python here-doc, is fine. Stage and commit in separate calls: a `git add` before a commit in the same call asks, and autopilot denies it. A gh alias or extension asks, and autopilot denies it.

Each allowed git or gh shape is the whole Bash call. Nothing runs before it: no `cd`, wrapper or assignment. No word expands, and no `$( )` or backtick appears. Only `head`, `tail`, `grep` or `cat` with no file argument may follow it, and a redirection may only go to `/dev/null` or copy a file descriptor.

A `<file>` is a regular file, not a symlink, inside the main worktree and outside `.git`. It is under `work_dir`, or git does not ignore it.

The other guards still vote, and the strictest vote wins. G6 denies a commit or push that holds a possible secret or a `never_commit` path. G3 denies a review body that does not open with a `review.taxonomy` label, and an approval of the user's own PR.

`tracker.policy: auto` never covers a delete or another tracker's MCP writes. Chat messages always ask. Merge, deploys and the other floor actions have no allowed shape.
