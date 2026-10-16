### Task 25: `finish-branch` (slash), and the hand-off from prove-it

**Files:**
- Create: `skills/finish-branch/SKILL.md`, `skills/finish-branch/references/pr-body.md`, `tests/skills/finish-branch.acceptance.md`
- Modify: `skills/prove-it/SKILL.md` (the Gate line), `tests/skills/prove-it.test.mjs`, `skills/help/references/map.md`, `CHANGELOG.md`
- Test: `tests/skills/finish-branch.test.mjs`, `tests/skills/prove-it.test.mjs`

**Interfaces:**
- Consumes: `prove-it`, `self-review`, `commit` (Tasks 16, 23, 24); `wt-snap`, `wt-new --detach` (Tasks 1, 2); `kern-dir tmp`; the ledger's `Worktree:` line (Task 22); guards G1 and G2 (M1).
- Produces: slash skill `finish-branch`; menu options `1 commit`, `2 commit and push`, `3 commit, push and open a draft PR`, `4 keep as is`; PR body sections in `references/pr-body.md`; the dedup rule (a PR at this head stops; an open PR at an older head gets a push and no new PR); the proven-tree rule (`HEAD^{tree}` equals the tree proven in step 3, or the proof re-runs on a detached copy of HEAD). prove-it's Gate line now ends by reading commit for a commit and finish-branch for a push or PR, so the routed row "About to say done, fixed or passing, commit, or open a PR" reaches both slash skills.

- [ ] **Step 1: Write the failing tests**

```js
// tests/skills/finish-branch.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/finish-branch/SKILL.md';

test('finish-branch frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'finish-branch',
    description: 'Finish a branch: verify, self-review, check base and size, then offer commit, push, draft PR or keep.',
    'disable-model-invocation': 'true',
    'allowed-tools': 'Bash(git status *), Bash(git fetch *), Bash(git rev-list *), Bash(git rev-parse *), Bash(gh pr list *)',
  });
});

test('finish-branch sections, steps and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 11);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['`Worktree:` line', 'Run `cd <wt>` as its own call', 'detached HEAD', 'git switch -c <name>',
    'gh pr list --head <branch> --state all --json number,state,headRefOid,url', 'whose `headRefOid` is `git rev-parse HEAD`', 'open no new PR',
    '`git rev-parse HEAD^{tree}` must equal the tree from step 3', 'gh pr create --draft --title "<subject per commit.convention>" --base <base> --body-file <dir>/pr-body.md',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`', 'never force it', 'typed word `discard`', 'status --porcelain -uall', 'skip: no-comments ships in M3',
    '${CLAUDE_PLUGIN_ROOT}/skills/self-review/SKILL.md', 'steps 3 to 6 of `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`']);
  assertMaxBytes(SKILL, 5000);
});

test('PR body template', () => {
  assertHeadings('skills/finish-branch/references/pr-body.md', ['# PR body', '## Why', '## What changed', '## Scope', '## Tradeoffs', '## Merge danger', '## Verification']);
  assertContains('skills/finish-branch/references/pr-body.md', ['drop a section with nothing to say', 'about 40 lines', 'smallest useful view', 'Screenshots first']);
  assertMaxBytes('skills/finish-branch/references/pr-body.md', 2000);
});
```

Append to `tests/skills/prove-it.test.mjs`:

```js
test('the gate hands a commit to commit and a push or PR to finish-branch', () => {
  assertContains(SKILL, ['for a commit, Read `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`', 'for a push or a PR, Read `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md`']);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/skills/finish-branch.test.mjs tests/skills/prove-it.test.mjs`
Expected: 3 failing finish-branch tests (`skills/finish-branch/SKILL.md exists`) and the new prove-it test failing on the missing hand-off.

- [ ] **Step 3: Write `skills/finish-branch/SKILL.md`**

Step 1's detached-HEAD branch and step 6's listing before discard adapt `.upstream/superpowers/skills/finishing-a-development-branch/SKILL.md:44`, `:67-76` and `:132-146`; the Red flags rows adapt `:216-225` of the same file.

```markdown
---
name: finish-branch
description: "Finish a branch: verify, self-review, check base and size, then offer commit, push, draft PR or keep."
disable-model-invocation: true
allowed-tools: Bash(git status *), Bash(git fetch *), Bash(git rev-list *), Bash(git rev-parse *), Bash(gh pr list *)
---

# finish-branch

Integrate finished work the user's way, with a fresh base and a reviewer-ready draft PR. Every path ends in an outward choice, so this skill is slash only.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Find the work and stand in it: the newest execute-plan ledger's `Worktree:` line, else `git worktree list`, else the current checkout. Run `cd <wt>` as its own call, because G1 and G2 judge a push or PR by the session's directory. Check the branch and worktree (`git rev-parse --git-dir` against `git rev-parse --git-common-dir`). On a detached HEAD, offer "create branch <name from branch.pattern> here" (`git switch -c <name>` in that worktree) and go on only after it. Refuse on a protected branch.
2. Run `git fetch origin <base>` and report ahead and behind (`git rev-list --left-right --count origin/<base>...HEAD`). Stale: propose a rebase in the worktree and run it only on yes.
3. Prove with `test.full` on this tree by following `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md`, then record the proven tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`.
4. Read `${CLAUDE_PLUGIN_ROOT}/skills/self-review/SKILL.md` and run it. Comment hygiene: `skip: no-comments ships in M3`.
5. Size gate: more than `scope_threshold` files or more than `pr.max_lines` changed lines: propose a split.
6. Show the menu, then wait: 1 commit; 2 commit and push; 3 commit, push and open a draft PR; 4 keep as is. Discard only on the typed word `discard`, after listing what it would destroy: `git -C <wt> status --porcelain -uall`, the branch's commits and the worktree path.
7. Commit by running steps 3 to 6 of `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`.
8. Before any push or PR, run `gh pr list --head <branch> --state all --json number,state,headRefOid,url`. A PR whose `headRefOid` is `git rev-parse HEAD`: report its URL and stop. An open PR at an older head: push in step 9, report its URL, and open no new PR.
9. Push only the proven tree: `git rev-parse HEAD^{tree}` must equal the tree from step 3; when it differs, run `test.full` again on a detached copy of HEAD (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new <slug>-check --detach --base <HEAD sha>`) first. Then run `git push -u origin <branch>` as its own call; G1 asks. Investigate a rejected push; never force it.
10. PR: write the body from `pr.template`, else from `references/pr-body.md`, with the Write tool to `<dir>/pr-body.md`, where `<dir>` is the path `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints. Run `gh pr create --draft --title "<subject per commit.convention>" --base <base> --body-file <dir>/pr-body.md` as its own call; it needs `--title` because no terminal can prompt for one. Report the URL; keep the worktree.

## Inputs

| Key | Default | Use |
|---|---|---|
| `base_branch`, `branch.protected`, `branch.pattern`, `deploy.envs` | detected; base plus deploy branches; detected; none | steps 1 and 2 |
| `test.full` | detected, source printed | step 3 |
| `scope_threshold`, `pr.max_lines` | 4 files, 300 lines | size gate |
| `push.policy`, `pr.policy`, `pr.dedup` | `ask`, `draft-after-approval`, `on` | steps 8 to 10 |
| `pr.template` | detected `.github/pull_request_template.md` | PR body |
| `commit.convention` | detected from `git log` | PR title |
| `tracker` | detected | issue link in the body |

## Outputs

A commit, a push or a draft PR, per the choice; a chat report.

## Stops and autopilot

Stops at steps 1, 3, 4 (`fix first` or `split`), 5 and 6. Under autopilot the menu resolves to option 3 after the dedup check: a draft PR only, `gh pr ready` denied, and a push of the current non-protected branch only.

## Red flags

| Thought | Reality |
|---|---|
| "Tests passed earlier this session" | A green run proves only the tree it ran on. Push the proven tree. |
| "A PR exists, so there is nothing to push" | A PR at an older head gets the new commits. Only a PR at this head stops. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` deletes work. |
| "The PR is up, so the worktree is clutter" | Review fixes happen in that worktree. It stays until the work lands. |
| "The push was rejected; force will fix it" | A rejected push means the remote moved. Investigate. |
```

- [ ] **Step 4: Write `skills/finish-branch/references/pr-body.md`**

Sections adapted from `.upstream/pstack/pstack/skills/poteto-mode/playbooks/opening-a-pr.md:13-22` (the order, Tradeoffs, drop-empty, about 40 lines) and `.upstream/pocock/skills/engineering/pr/SKILL.md:13-33,158-170` (the smallest useful view, screenshots as the best evidence, merge danger). A contract (coverage gap 17). Full text:

```markdown
# PR body

A one-minute briefing for a reviewer who has the diff. Write it with the Write tool to a file under `WORK/tmp` and pass `--body-file`. Use these sections in this order and drop a section with nothing to say. Keep the whole body under about 40 lines; detail goes in a linked file, not the body.

## Why

The problem and who has it, in two or three sentences. Link the issue.

## What changed

The behaviour change as the smallest useful view: a call tree, pseudocode, a short diff sketch or a diagram when it explains faster than prose; otherwise one to three bullets. Name both sides of a rename.

## Scope

What this PR covers, and a "Didn't touch" line for the nearby things a reviewer might expect.

## Tradeoffs

Only the rejected alternatives a reviewer would otherwise ask about. Skip it when there was no real choice.

## Merge danger

One-way or two-way door. The blast radius: data, consumers, deploy order. What breaks if this is wrong, and how to roll back.

## Verification

Before and after. Screenshots first when the change is visible and the environment can show it; otherwise commands with their output: the failing reproduction, the passing run, the full suite summary.
```

- [ ] **Step 5: Hand off from prove-it**

In `skills/prove-it/SKILL.md`, replace the Gate line with:

```markdown
Gate: steps 1 to 7 hold before any commit, push, PR, tracker write, or the words done, fixed, passing, verified. Then, for a commit, Read `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`; for a push or a PR, Read `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/SKILL.md`; and follow its steps.
```

commit and finish-branch keep `disable-model-invocation: true`; their step 1 consent check still stops a commit or push the user did not ask for.

- [ ] **Step 6: Write `tests/skills/finish-branch.acceptance.md`**

```markdown
# finish-branch: acceptance checks (run during the M2b pilot; Task 26 runs the gh-stub evals)

- [ ] A clean feature branch: the menu appears; nothing is pushed until the user picks.
- [ ] A PR already exists at this head: it stops and prints the PR URL.
- [ ] An open PR at an older head: the new commit is pushed and the existing PR is reported; no second PR.
- [ ] Nine files changed with `scope_threshold: 4`: a split is proposed before the menu.
- [ ] A detached worktree: it offers to create a branch before the menu.
- [ ] Under autopilot: a draft PR with `--title` after the dedup check; no merge; no `gh pr ready`.
```

- [ ] **Step 7: Add the map row and the changelog line**

Append to `skills/help/references/map.md`: ``| `finish-branch` | slash | /kern:finish-branch; prove-it's gate for a push or PR | Verify, review, then commit, push, draft PR or keep |``
Add under `## [Unreleased]`: `- finish-branch: verify, self-review and size gate before the commit, push or draft PR menu; the PR has a title, a body under .kern/tmp and a dedup on the head commit. prove-it hands commits and PRs to these skills.`

- [ ] **Step 8: Run the tests and lint**

Run: `node --test tests/skills/finish-branch.test.mjs tests/skills/prove-it.test.mjs && node scripts/lint-skills.mjs`
Expected: `# fail 0`; no lint errors (rule 4 resolves the two new paths in prove-it).

- [ ] **Step 9: Commit**

```bash
git add -- skills/finish-branch skills/prove-it/SKILL.md tests/skills/finish-branch.test.mjs tests/skills/prove-it.test.mjs tests/skills/finish-branch.acceptance.md skills/help/references/map.md CHANGELOG.md
git commit -m "M2: add the finish-branch skill" -m "gh pr create needs --title without a terminal, a PR body must live where G2 reads it, and a PR at an older head needs a push, not a stop."
```

---

