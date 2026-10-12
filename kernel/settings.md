# kern settings

Files, highest first: `.claude/kern.local.yml` (untracked, the default per-project file), `.claude/kern.yml` (shared, committed only if a team wants it), `~/.claude/kern.yml` (user defaults). Project files are read from the main worktree root. Above all files: the user's instruction in this session, then a project skill that owns the job, then project rules (CLAUDE.md, `.claude/rules`, memory), which may tighten and never loosen.

Format: one `key: value` per line. `#` starts a comment at line start or after whitespace outside quotes. Surrounding quotes are stripped; quote a value that ends in a space. Lists are comma-separated. A key with `<...>` in this table stands for a family, such as `overrides.commit`.

Policy keys take `ask` (default), `auto` or `deny`. Floor actions have no key and never loosen: merge, production deploy, data deletion, force-push to a shared branch, messaging people. A key that names a floor action is reported and ignored.

| Key | Default | Values | Read by |
|---|---|---|---|
| `kern` | `on` | `on`, `off` (no routing, no guards in this project) | session-start, subagent-start, prompt-submit, pre-tool-use |
| `kern_repo` | none | path to the kern clone (user file only) | help |
| `work_dir` | `.kern` | relative directory at the main worktree root | kern-dir, all skills |
| `mode.voice` | `normal` | `normal`, `terse` | session-start, prompt-submit, subagent-start |
| `mode.surface` | `auto` | `chat`, `auto`, `html` | session-start, prompt-submit |
| `autopilot` | `allowed` | `allowed`, `denied` | prompt-submit, pre-tool-use (G1, G2, G5, G14, G15) |
| `base_branch` | detected from `refs/remotes/origin/HEAD` | branch name | pre-tool-use (G1, G6), kern-detect, plan, finish-branch |
| `branch.pattern` | detected | pattern with `{id}` and `{slug}` | kern-detect, execute-plan, wt-new |
| `branch.protected` | `base_branch` plus `deploy.envs` | comma list | pre-tool-use (G1), commit, finish-branch |
| `deploy.envs` | none | comma list of deploy branches | pre-tool-use (G1, G15), finish-branch, ship-check |
| `deploy.proof` | none | command or URL that proves a deploy | ship-check |
| `worktree.dir` | `.claude/worktrees` | directory under the main worktree root | wt-new, execute-plan, parallel-work |
| `worktree.setup` | none; `.worktreeinclude` honoured | shell command run in a new worktree | wt-new |
| `shared_services` | none: migrations and DB-backed tests overlap | comma list | plan, execute-plan, parallel-work |
| `parallel.max` | `3` | integer | parallel-work |
| `scope_threshold` | `4` | files per change before a pause | define, plan, implement, self-review, finish-branch |
| `pr.max_lines` | `300` | changed lines before a split is proposed | finish-branch |
| `test.focused` | detected | command; `{file}` stands for the test path, or `{dir}` (go) or `{name}` (cargo) where a file cannot be targeted | kern-detect, implement, diagnose, prove-it |
| `test.full` | detected | command | kern-detect, implement, prove-it, finish-branch |
| `typecheck` | detected | command | kern-detect, implement, prove-it |
| `lint` | detected | command | kern-detect, prove-it |
| `build` | detected | command | kern-detect, prove-it |
| `verify.fast` | `typecheck` then `lint` | command | self-review, prove-it |
| `verify.browser` | none: ask when a UI claim needs it | command | prove-it, diagnose, verify-app |
| `generated_artifacts` | none | comma list of `trigger-glob=command` | implement, prove-it, self-review |
| `checklists` | existing data and consumers; authorization scope; persisted-shape change | comma list | define, plan |
| `tracker` | detected | `none`, `github`, `gitlab`, `linear`, `jira`, or another name | kern-detect, define, plan, recall, triage |
| `tracker.first` | `false` | `true`, `false` | define, plan |
| `tracker.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use (G14) |
| `mcp.write_servers` | none | comma list of extra MCP server names treated as trackers | pre-tool-use (G14) |
| `spec.source` | linked issue, PR body, `.kern/specs` | path or `issue` | prove-it, pr-review |
| `commit.convention` | detected from `git log` | extended regular expression for the subject | pre-tool-use (G5), kern-detect, commit |
| `commit.id_from_branch` | `[A-Z][A-Z0-9]+-[0-9]+` | extended regular expression | pre-tool-use (G5), commit |
| `commit.attribution` | `none` | `none`, `allowed` | pre-tool-use (G5), commit |
| `commit.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use (G5), commit |
| `push.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use (G1), finish-branch |
| `pr.policy` | `draft-after-approval` (read as `ask`) | `ask`, `auto`, `deny`; PRs are always drafts | pre-tool-use (G2), finish-branch |
| `pr.dedup` | `on` | `on` (G2 always checks) | finish-branch |
| `pr.template` | detected | path | kern-detect, finish-branch |
| `rebase.push` | `ask` | `ask`, `autopilot` | pre-tool-use (G1), take-feedback |
| `stack.tool` | detected | `gh-stack`, `git`, `none` | take-feedback, finish-branch |
| `protected_targets` | none | comma list of hosts, DSN fragments or profiles | pre-tool-use (G13), diagnose |
| `evidence_agents` | none | comma list of project agents for read-only data | diagnose |
| `never_commit` | none | comma list of path globs | pre-tool-use (G6), commit |
| `review.rules` | CLAUDE.md, `.claude/rules/**`, CONTRIBUTING.md | comma list of paths | self-review, execute-plan, pr-review |
| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` | comma list of labels | pre-tool-use (G3), self-review, pr-review |
| `review.post_policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use (G3) |
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
| `rule_bar` | 3 occurrences or 1 severe incident; 2 for a mechanism | text | retro, correct |
| `model.implementer` | `sonnet` | model alias | execute-plan, parallel-work |
| `model.reviewer` | `sonnet` | model alias | execute-plan |
| `model.final_review` | `opus` | model alias | execute-plan |
| `model.investigator` | `sonnet` | model alias | define, plan, diagnose |
| `model.miner` | `haiku` | model alias | recall |
| `workflow_records` | none | comma list of paths or tools with run records | recall |
| `stack` | detected | text | architect, build-ui, implement |
| `overrides.<job>` | none; a same-name project skill is found by session-start | project skill name, or `off` | session-start, every skill |
| `route.<name>` | none | project skill name, or `off` | session-start |
