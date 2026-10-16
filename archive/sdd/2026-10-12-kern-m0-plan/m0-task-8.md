### Task 8: CI

**Files:**
- Create: `.github/workflows/ci.yml`, `scripts/ci-local`

**Interfaces:**
- Consumes: every CLI from Tasks 2 to 7.
- Produces: job `checks` that M1 extends with `bats tests/hooks tests/scripts` and shellcheck lines, and `scripts/ci-local` that runs the same steps locally (M1 and M2 append to both).

- [ ] **Step 1: Write `scripts/ci-local`**

```bash
#!/usr/bin/env bash
# Runs the CI job's steps locally, in the same order, before a push.
set -euo pipefail
cd "$(dirname "$0")/.."
node --test 'tests/**/*.test.mjs'
node scripts/lint-skills.mjs
node scripts/check-version.mjs
node scripts/route-eval.mjs
claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json --strict
bats tests/scripts
shellcheck scripts/fetch-upstream scripts/ci-local
echo "ci-local: all steps passed"
```

- [ ] **Step 2: Run it to verify it passes locally**

Run: `chmod +x scripts/ci-local && scripts/ci-local`
Expected: last line `ci-local: all steps passed`.

- [ ] **Step 3: Write `.github/workflows/ci.yml`**

```yaml
name: ci
on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
      - name: Unit tests
        run: node --test 'tests/**/*.test.mjs'
      - name: Lint skills
        run: node scripts/lint-skills.mjs
      - name: Versions agree
        run: node scripts/check-version.mjs
      - name: Unreleased line for shipped changes
        if: github.event_name == 'pull_request'
        run: node scripts/check-version.mjs --pr origin/${{ github.base_ref }}
      - name: Routing evals
        run: node scripts/route-eval.mjs
      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code@2.1.296
      - name: Validate marketplace and plugin manifests
        run: |
          claude plugin validate . --strict
          claude plugin validate .claude-plugin/plugin.json --strict
      - name: Install bats and shellcheck
        run: sudo apt-get update && sudo apt-get install -y bats shellcheck
      - name: Script tests
        run: bats tests/scripts
      - name: Shellcheck
        run: shellcheck scripts/fetch-upstream scripts/ci-local
```

- [ ] **Step 4: Commit**

```bash
git add -- .github/workflows/ci.yml scripts/ci-local
git commit -m "M0: run lint, tests, routing evals and plugin validation in CI"
```

- [ ] **Step 5: Create the GitHub repo and push (outward action)**

Ask the user: "Create the private GitHub repo `kern` under your account and push `main`?" Only on a yes:
```bash
gh repo create kern --private --source . --remote origin --push
id=""
for i in $(seq 1 30); do id=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId // empty'); [ -n "$id" ] && break; sleep 2; done
gh run watch --exit-status "$id"
```
Expected: the `ci` run ends green. If `claude plugin validate` fails in CI because it needs a login, replace that CI step with `node scripts/check-version.mjs` (already present) plus a note in `README.md` that `scripts/ci-local` validates the plugin before each push, and commit that change as `M0: validate the plugin locally when CI cannot log in`.

---

