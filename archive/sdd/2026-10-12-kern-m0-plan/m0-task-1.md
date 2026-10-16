### Task 1: Repo skeleton and documents

**Files:**
- Create: `~/Code/projects/kern/.gitignore`
- Create: `~/Code/projects/kern/README.md`
- Create: `~/Code/projects/kern/docs/specs/2026-10-12-kern-design.md` (copy)
- Create: `~/Code/projects/kern/docs/specs/2026-10-12-kern-m1-m2-skills.md` (copy)
- Create: `~/Code/projects/kern/docs/plans/contract.md`, `docs/plans/2026-10-12-kern-m0-plan.md`, `docs/plans/2026-10-12-kern-m1-plan.md`, `docs/plans/2026-10-12-kern-m2-plan.md` (copies)
- Create: `~/Code/projects/kern/docs/research/` (copies of merge-define.md, merge-build.md, merge-ship.md, merge-meta.md, replacement-map.md, modes-research.md, audit-superpowers.md, audit-pstack.md, audit-pocock.md, audit-addy.md, kernel-draft.md, kernel-subagent-draft.md)

**Interfaces:**
- Consumes: the scratchpad documents at `$SP/kern-spec/` and `$SP/*.md`, where `SP=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad`.
- Produces: the repo root `KR=~/Code/projects/kern` with `main` as its branch; every later task runs commands from `KR`.

- [ ] **Step 1: Check the toolchain**

Run:
```bash
node --version; git --version; gh --version | head -1; claude --version; command -v bats shellcheck || echo MISSING
```
Expected: node v22 or later, claude 2.1.295 or later. If bats or shellcheck is missing, ask the user before running `brew install bats-core shellcheck` (installs software on their machine). Tests run on macOS `/bin/bash` 3.2 on purpose, the bash hooks meet there; bash 3.2 ignores a false `[[ ]]` in the middle of a bats test, so every `[[ ]]` assertion in a `.bats` file ends with `|| false` (M1 Task 2 makes `tests/run-bats` enforce it).

- [ ] **Step 2: Confirm the scratchpad documents still exist**

Run:
```bash
SP=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad
ls "$SP/kern-spec/"*.md "$SP/kern-spec/plans/"*.md "$SP"/merge-*.md "$SP"/audit-*.md
```
Expected: every file listed. If `/private/tmp` was cleaned, stop and tell the user: the spec and plans must be restored from the published artifacts before continuing.

- [ ] **Step 3: Create the repo and copy the documents**

```bash
KR=~/Code/projects/kern
test ! -e "$KR" || { echo "$KR exists; stop and ask"; exit 1; }
mkdir -p "$KR"/docs/specs "$KR"/docs/plans "$KR"/docs/research
git -C "$KR" init -b main
cp "$SP"/kern-spec/2026-10-12-kern-design.md "$SP"/kern-spec/2026-10-12-kern-m1-m2-skills.md "$KR"/docs/specs/
cp "$SP"/kern-spec/plans/*.md "$KR"/docs/plans/
for f in merge-define merge-build merge-ship merge-meta replacement-map modes-research audit-superpowers audit-pstack audit-pocock audit-addy kernel-draft kernel-subagent-draft; do cp "$SP/$f.md" "$KR/docs/research/"; done
```

- [ ] **Step 4: Write `.gitignore`**

```gitignore
.upstream/
node_modules/
evals/results/
.lint-names
.DS_Store
```

- [ ] **Step 5: Write `README.md`**

```markdown
# kern

A personal Claude Code plugin that routes work through a small always-on kernel, enforces safety with guard hooks, and defers to each project's own rules and skills.

## Install

1. `gh auth login`
2. In Claude Code: `/plugin marketplace add <owner>/kern`, then `/plugin install kern@kern` at user scope.
3. Optional: restore `~/.claude/kern.yml`. Per project, run `/kern:help setup` when the defaults are not enough.

## Develop

Clone to the path named by `kern_repo` in `~/.claude/kern.yml` and run `claude --plugin-dir <path>`. Run `scripts/ci-local` before pushing.

## Documents

- Design: `docs/specs/2026-10-12-kern-design.md`
- Skill specs for M1 and M2: `docs/specs/2026-10-12-kern-m1-m2-skills.md`
- Plans: `docs/plans/`
```

- [ ] **Step 6: Verify and commit**

Run: `git -C "$KR" status --porcelain | sort`
Expected: `?? .gitignore`, `?? README.md`, `?? docs/`.

```bash
git -C "$KR" add -- .gitignore README.md docs
git -C "$KR" commit -m "M0: start the kern repo with its spec, plans and research notes" -m "The spec and plans lived in a temporary scratchpad; the repo is now their durable home."
```

---

