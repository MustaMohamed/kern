### Task 24: `commit` (slash)

**Files:**
- Create: `skills/commit/SKILL.md`, `tests/skills/commit.acceptance.md`
- Modify: `skills/help/references/map.md`, `CHANGELOG.md`
- Test: `tests/skills/commit.test.mjs`

**Interfaces:**
- Consumes: `prove-it` (Task 16); `wt-snap` (Task 2); `kern-dir tmp` (M1); the ledger format (Task 22); M1's `technical-writing` skill and guards G5 and G6.
- Produces: slash skill `commit`; finish-branch step 7 and autopilot execute-plan step 10 run its steps 3 to 6. The message file is `<WORK>/tmp/commit-msg`, written with the Write tool and passed to `git commit -F` by its literal path in its own call, the only `-F` shape G5 allows under autopilot (pinned by Task 26's `ship-commands.bats`).

- [ ] **Step 1: Write the failing test**

```js
// tests/skills/commit.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/commit/SKILL.md';

test('commit frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'commit',
    description: "Commit named files with a message that follows the project's convention, after the checks pass.",
    'disable-model-invocation': 'true',
    'argument-hint': '[files...]',
    'allowed-tools': 'Bash(git status *), Bash(git diff *), Bash(git log *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)',
  });
});

test('commit sections, steps and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 8);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['git add -- <files>', 'never `-A` or `.`', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`', 'git commit -F <dir>/commit-msg', 'as its own call, with the literal path',
    'git diff --staged --stat', 'one commit per complete task, in ledger order', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap', 'HEAD^{tree}', 'detached HEAD',
    '72 characters or fewer', 'never a retry with a looser message', '${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md']);
  assert.ok(!readDoc(SKILL).raw.includes('temp file'), 'the message file lives under WORK/tmp, which G5 accepts, not in a temp file');
  assertMaxBytes(SKILL, 4200);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/skills/commit.test.mjs`
Expected: 2 failing tests; `skills/commit/SKILL.md exists`.

- [ ] **Step 3: Write `skills/commit/SKILL.md`**

Step 3's per-task commits and staged view adapt `.upstream/addy/skills/git-workflow-and-versioning/SKILL.md:48-63` and `:211-230`; the Red flags rows adapt `:313-325` of the same file and `.upstream/superpowers/skills/finishing-a-development-branch/SKILL.md:216`.

```markdown
---
name: commit
description: Commit named files with a message that follows the project's convention, after the checks pass.
disable-model-invocation: true
argument-hint: "[files...]"
allowed-tools: Bash(git status *), Bash(git diff *), Bash(git log *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)
---

# commit

One clean commit of the right files. Committing is the user's call; finish-branch and, under autopilot only, execute-plan run these steps too.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Consent: the user typed `/kern:commit` or asked to commit in this session, or autopilot is on. Otherwise stop.
2. Where: run `git rev-parse --show-toplevel` and name the branch. On a protected branch, stop and ask: commit locally anyway, or the user moves the work. On a detached HEAD, stop: finish-branch offers to create a branch. Never switch branches.
3. Files: read `git status --porcelain`; propose the files this task touched; list the rest and leave them out unless the user named them. Work from an execute-plan ledger in `WORK/ledgers/` that has complete tasks: offer one commit per complete task, in ledger order, each staging the paths in its review package's `## Files changed` list. Stage with `git add -- <files>` in its own call, never `-A` or `.`. Refuse paths that match `never_commit`. Show `git diff --staged --stat`.
4. Prove: follow `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md` (`verify.fast` and the focused tests). When tracked changes stay unstaged, say that the proof ran on the working tree, not on the commit. Record the proven tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <toplevel>`.
5. Message: use `commit.convention` from settings, or infer it from `git log --format=%s -30` and state it; take the ticket id from the branch name with `commit.id_from_branch`; an imperative subject of 72 characters or fewer; a body that says why; one concern per commit (a refactor mixed with a feature becomes a proposal for two commits). Prose follows `${CLAUDE_PLUGIN_ROOT}/skills/technical-writing/SKILL.md`. Add attribution only as `commit.attribution` says.
6. Write the message with the Write tool to `<dir>/commit-msg`, where `<dir>` is the path `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints, then run `git commit -F <dir>/commit-msg` as its own call, with the literal path. G5 reads a message file only inside the main worktree. G5's prompt is the confirmation; under autopilot G5 allows it when the checks pass.
7. Report the short SHA, the subject, the files, and what stayed unstaged. When nothing stayed unstaged, `git rev-parse HEAD^{tree}` must equal the tree from step 4; a mismatch means the commit is not what was proven, so say so.

## Inputs

| Key | Default | Use |
|---|---|---|
| `commit.convention` | detected from `git log` | subject format |
| `commit.id_from_branch` | `[A-Z][A-Z0-9]+-[0-9]+` | ticket id |
| `commit.attribution` | `none` | trailers |
| `commit.policy` | `ask` | G5 |
| `branch.protected` | `base_branch` plus `deploy.envs` branches | step 2 |
| `never_commit` | none | refused paths (G6 also checks) |

## Outputs

One commit, or one per complete ledger task; a chat report.

## Stops and autopilot

Stops at steps 1, 2 and 4. Under autopilot a failing convention check is a denial, never a retry with a looser message.

## Red flags

| Thought | Reality |
|---|---|
| "I'll commit when the whole plan is done" | One giant commit cannot be reviewed or reverted. Commit each reviewed task. |
| "git add -A is quicker" | It stages what nobody reviewed. Name the files. |
| "The tests passed earlier" | Prove the tree you are about to commit. |
| "The message does not matter" | The subject follows the convention; the body says why. |
| "The check failed, so I'll loosen the message" | Under autopilot a failed check is a stop, never a retry. |
```

- [ ] **Step 4: Write `tests/skills/commit.acceptance.md`**

```markdown
# commit: acceptance checks (run during the M2b pilot; Task 26 runs the guard and gh-stub checks)

- [ ] On `CDS-2465/replace-minio` with `commit.convention: "^CDS-[0-9]+: "`: the subject starts `CDS-2465: `; no trailers; only touched files are staged.
- [ ] An untracked `.env.local` exists: it is not staged, and it is listed.
- [ ] On `main`: it stops and asks.
- [ ] After a delegate run with three complete ledger tasks: three commits are offered, one per task, in ledger order.
- [ ] A project with `.claude/skills/commit/`: kern defers in one line; G5 and G6 still check the commit.
```

- [ ] **Step 5: Add the map row and the changelog line**

Append to `skills/help/references/map.md`: ``| `commit` | slash | /kern:commit | One commit of named files, or one per reviewed task, per the project's convention |``
Add under `## [Unreleased]`: `- commit: named files, convention-checked message from a file under .kern/tmp, one commit per reviewed task, no attribution by default.`

- [ ] **Step 6: Run the tests and lint**

Run: `node --test tests/skills/commit.test.mjs && node scripts/lint-skills.mjs`
Expected: `# fail 0`; no lint errors (rule 9 finds the Red flags table).

- [ ] **Step 7: Commit**

```bash
git add -- skills/commit tests/skills/commit.test.mjs tests/skills/commit.acceptance.md skills/help/references/map.md CHANGELOG.md
git commit -m "M2: add the commit skill" -m "A temp-file message is a shape G5 denies under autopilot; the message now lives under .kern/tmp, and a delegate run is committed one reviewed task at a time."
```

---

