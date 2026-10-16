### Task 9: M0 acceptance

**Files:** none.

- [ ] **Step 1: Run the acceptance checks**

```bash
claude plugin validate . --strict; echo "validate exit=$?"
claude plugin validate .claude-plugin/plugin.json --strict; echo "plugin validate exit=$?"
scripts/ci-local
gh run list --limit 1 --json conclusion --jq '.[0].conclusion'
```
Expected: `validate exit=0` and `plugin validate exit=0`; `ci-local: all steps passed`; `success` (or the documented local-validation fallback from Task 8).

- [ ] **Step 2: Install from the marketplace on this machine**

In a Claude Code session: `/plugin marketplace add <owner>/kern`, then `/plugin install kern@kern`. In a throwaway directory, ask "hello kern".
Expected: the `hello` skill loads and replies with `kern 0.1.0 is installed.` Uninstall afterwards with `/plugin uninstall kern@kern` so superpowers stays the only router until the M2 pilot; development continues with `claude --plugin-dir ~/Code/projects/kern`.

- [ ] **Step 3: Record the result**

Append under `## [Unreleased]` in `CHANGELOG.md`: `- M0 accepted: plugin validates, CI green, marketplace install works.` Then run `git add -- CHANGELOG.md && git commit -m "M0: record acceptance"`.
