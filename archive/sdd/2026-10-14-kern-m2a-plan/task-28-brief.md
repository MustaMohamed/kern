### Task 28: `recall` (auto)

**Files:**
- Create: `skills/recall/SKILL.md`, `skills/recall/references/transcripts.md`, `evals/cases/recall.json`, `evals/fixtures/recall-ledger/_kern/ledgers/export/ledger.md`, `tests/skills/recall.acceptance.md`
- Modify: `skills/help/references/map.md`, `CHANGELOG.md`
- Test: `tests/skills/recall.test.mjs`

**Interfaces:**
- Consumes: kern working files (`WORK/ledgers/*/ledger.md`, `WORK/plans/*`, `WORK/specs/*`); `wt-audit` (Task 4); `wt-snap` (Task 2); `recall-sessions` (Task 27); `git`, `gh`; the tracker named by `tracker`.
- Produces: auto skill `recall`; thread tags `[merged #N]`, `[open PR #N]`, `[in flight <branch>]`, `[verified, uncommitted]` (only when the ledger's last `tree=` equals a fresh `wt-snap`), `[reverted #N]`, `[blocked, <why>]`, `[parked]`, `[planned, not started]`. Writes no file; `wt-snap` adds git objects only. Five behavioural cases in `evals/cases/recall.json`, four of them the skills spec's C11 acceptance checks, for M2b's runner.

The description holds double quotes and `: `, so it is single-quoted in YAML; M0's `parseFrontmatter` strips surrounding single quotes (pre-flight I33, measured).

- [ ] **Step 1: Write the failing test**

```js
// tests/skills/recall.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, readDoc, assertFrontmatter, h2s, steps, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/recall/SKILL.md';

test('recall frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'recall',
    description: 'Use when starting or resuming work and state must be rebuilt first: "where did I leave off", "catch me up on X", "what remains", "I got lost in these PRs", a session after days away, or "recall chat" for this thread since my last message. Not for one named session.',
  });
});

test('recall sections, steps and the source lines it keeps', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Output contract', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 10);
  assert.equal(s[0], DEFER);
  assertContains(SKILL, ['claude --resume', 'never turn "all" into "recent"', 'WORK/ledgers', '`model.miner`', 'gh pr list --head <branch> --state all', '[planned, not started]',
    'Write nothing to disk', 'action-item count first', '${CLAUDE_PLUGIN_ROOT}/scripts/recall-sessions', '${CLAUDE_PLUGIN_ROOT}/scripts/wt-audit',
    'equals a fresh `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`', 'which adds git objects', 'Memory files are context, never state',
    'Adjacent work stays out unless it blocks this', 'cut detail before threads', 'notifications and subagent results are not the user\'s messages',
    'work you can do yourself is not an action item', 'claim the mining inherited']);
  assert.ok(!readDoc(SKILL).raw.includes('history.jsonl'), 'recall finds prompts through recall-sessions, which filters by project');
  assertMaxBytes(SKILL, 6500);
});

test('transcripts reference', () => {
  assertHeadings('skills/recall/references/transcripts.md', ['# Where the records are', '## Transcripts', '## Prompt index', '## Working files', '## Live state']);
  assertContains('skills/recall/references/transcripts.md', ['recall-sessions']);
  assertMaxBytes('skills/recall/references/transcripts.md', 2200);
});

test('the C11 acceptance checks are behavioural cases', () => {
  const c = JSON.parse(readFileSync(join(ROOT, 'evals', 'cases', 'recall.json'), 'utf8'));
  assert.equal(c.evals.length, 5);
  const text = JSON.stringify(c.evals);
  for (const needle of ['next move', 'action-item count', 'claude --resume', 'recall mean in machine learning']) assert.ok(text.includes(needle), needle);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/skills/recall.test.mjs`
Expected: 4 failing tests; `skills/recall/SKILL.md exists`.

- [ ] **Step 3: Write `skills/recall/SKILL.md`**

Body adapted from `.upstream/local/recall/SKILL.md` (steps, output contract and red flags; line 19 memory is context, line 40 adjacent work and cutting detail, lines 42-47 red flags), `.upstream/pstack/pstack/skills/ketchup/SKILL.md:9-15` (chat mode, and which messages count) and `.upstream/pstack/pstack/skills/poteto-mode/playbooks/session-pickup.md:9` (re-verify inherited claims). Full text:

```markdown
---
name: recall
description: 'Use when starting or resuming work and state must be rebuilt first: "where did I leave off", "catch me up on X", "what remains", "I got lost in these PRs", a session after days away, or "recall chat" for this thread since my last message. Not for one named session.'
---

# recall

Rebuild the current state from kern's working files, transcripts and live git, forge and tracker state, then hand back a short brief. Write nothing to disk: live state is the only source of truth, and the brief is a reply. The one exception is `wt-snap`, which adds git objects and changes no file, ref or index.

## Steps

0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.
1. Route. One named prior session: point to `claude --resume` and stop. A full state capsule already in the prompt: skip the mining. `recall chat`: go to step 9.
2. Lock the scope and say it back: the window (7 days unless stated; never turn "all" into "recent"), the topic, and the workspace (never another project's transcripts unasked). Adjacent work stays out unless it blocks this.
3. Read kern's working files first: `WORK/ledgers/*/ledger.md` (incomplete tasks and `parked:` lines), the status lines of `WORK/plans/*` and `WORK/specs/*`, and kern worktrees from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-audit`. Memory files are context, never state.
4. Find the sessions with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/recall-sessions --days <n> --topic <topic>`: this project's transcripts, its worktrees' included, newest first, and its prompts that name the topic. The newest session is usually this one; skip it (`references/transcripts.md`).
5. Mine in parallel: one `model.miner` subagent per 2 to 4 transcripts; each greps the topic first and returns one block per session (id, date, goal, decisions, open threads, corrections, artifacts). Measure a record before reading it and narrow any over 500 characters. Two sessions or fewer: read them directly.
6. When a feature, ticket or bug is named, sweep `tracker` and `workflow_records` in parallel with step 5. Null results are findings.
7. Verify every PR, branch, issue and claim the mining inherited against live `git`, `gh` and the tracker before tagging it. For squash merges, trust `gh pr list --head <branch> --state all`, not `git branch --merged`. Tag `[verified, uncommitted]` only when the ledger's last `tree=` for that work equals a fresh `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`.
8. Write the brief per the output contract below.
9. `recall chat`: gather your own work, subagent reports and others' messages since the user's last message; notifications and subagent results are not the user's messages. Check the live state of each PR, CI run and agent; reply with the action-item count first, then what happened by importance, then per action item: the decision, why now, the options with their cost, a recommendation, and what happens with no answer. An item still waiting from before the user's last message counts; work you can do yourself is not an action item. List what could not be checked.

## Output contract

- Capsule: at most 5 bullets on what this work is and where it stands.
- Threads: one line each with exactly one tag: `[merged #N]`, `[open PR #N]`, `[in flight <branch>]`, `[verified, uncommitted]`, `[reverted #N]`, `[blocked, <why>]`, `[parked]`, `[planned, not started]`. A branch left behind after its PR merged is `[merged #N]` with "cleanup pending" on the same line.
- Problems: at most 5, the recurring ones.
- Next move: one concrete action. An incomplete ledger task is the next move when one exists.
- Sources skipped: one line, or omit.

Cite transcript findings by session id and live findings by PR, issue or ticket number. When the brief outgrows a screen, cut detail before threads.

## Inputs

| Key | Default | Use |
|---|---|---|
| `tracker` | detected | issue states |
| `workflow_records` | none | extra per-ticket records to sweep |
| `work_dir` | `.kern` | ledgers, plans, specs |
| `model.miner` | `haiku` | transcript miners |

## Outputs

Chat only (a page only when kern's `visual` skill is installed and the brief is long; otherwise say once "visual pages not installed"). Nothing is written.

## Stops and autopilot

Read-only; the same under autopilot.

## Red flags

- Tagging a thread from a transcript without a `gh` or `git` check.
- Reading whole transcripts in the main thread instead of slicing and delegating.
- Writing a status file "so next time is faster". Next time runs this skill.
- Widening "my work on X" to everything touched that week.
```

- [ ] **Step 4: Port `skills/recall/references/transcripts.md`**

Source: `.upstream/local/recall/SKILL.md:13-19` ("Where the records are").
Required headings: `# Where the records are`, `## Transcripts`, `## Prompt index`, `## Working files`, `## Live state`.
Adaptation: transcripts live at `~/.claude/projects/<slug>/*.jsonl`, where `<slug>` is the workspace path with every character outside A-Z, a-z and 0-9 turned into `-`; worktree sessions live under sibling slugs `<slug>--claude-worktrees-<name>`; skip the per-session child folders (`subagents/`, `tool-results/`, `workflows/`); the prompt index `~/.claude/history.jsonl` holds every project's prompts and indexes CLI sessions only, so recall reads both through `bash ${CLAUDE_PLUGIN_ROOT}/scripts/recall-sessions`, which keeps this project's lines; working files are kern's `WORK` folders; live state is `git`, `gh` and the tracker, and an unavailable source is named in the brief. Remove every product, company and personal name and every per-user path from the source; the user's own trackers become the `tracker` and `workflow_records` settings.
Check: `for h in '# Where the records are' '## Transcripts' '## Prompt index' '## Working files' '## Live state'; do grep -qxF "$h" skills/recall/references/transcripts.md || echo "missing $h"; done && [ "$(wc -c < skills/recall/references/transcripts.md)" -le 2200 ]`

- [ ] **Step 5: Write `evals/cases/recall.json` and its fixture**

The negatives share no token with the description (pre-flight F6: "What does recall mean in machine learning metrics?" and "Explain what this regex does" ranked recall first). The ML question stays as behavioural case 5, where the model, not the ranker, must stay quiet.

```json
{
  "skill_name": "recall",
  "trigger": {
    "positive": [
      { "prompt": "Where did I leave off on the floci swap?", "top_k": 3 },
      { "prompt": "Catch me up on the billing work, I have been away for days", "top_k": 3 },
      { "prompt": "I got lost in these PRs. What remains?", "top_k": 3 }
    ],
    "negative": [
      { "prompt": "Add a CSV export to the reports page" },
      { "prompt": "Rename the config loader to settings loader" }
    ]
  },
  "evals": [
    {
      "id": 1,
      "kind": "dialogue",
      "prompt": "Where did I leave off on the export feature?",
      "expected_output": "States the scope back, checks kern ledgers and live PR state, and returns a brief with one tag per thread and one next move, writing no files.",
      "expectations": [
        "Says the window, topic and workspace back before mining",
        "Checks PR or branch state with gh or git before tagging a thread",
        "Gives exactly one tag per thread and one next move",
        "Writes no file"
      ]
    },
    {
      "id": 2,
      "kind": "execution",
      "files": ["recall-ledger"],
      "prompt": "Where did I leave off on the export plan?",
      "expected_output": "Reads the ledger, sees Tasks 1 and 2 complete and Task 3 started but not complete, and names Task 3 as the next move.",
      "expectations": [
        "Reads .kern/ledgers/export/ledger.md before any transcript",
        "Names Task 3 of the export plan as the next move",
        "Writes no file"
      ]
    },
    {
      "id": 3,
      "kind": "dialogue",
      "prompt": "recall chat",
      "expected_output": "Opens with the action-item count, then what happened by importance, then each action item with the decision, options, a recommendation and what happens with no answer.",
      "expectations": [
        "The first sentence gives the action-item count, or says there are none",
        "Each action item has a recommendation",
        "Treats notifications and subagent results as reports, not as the user's messages"
      ]
    },
    {
      "id": 4,
      "kind": "dialogue",
      "prompt": "Resume session 7f3a",
      "expected_output": "Points to claude --resume and stops without mining transcripts.",
      "expectations": [
        "Names claude --resume",
        "Reads no transcript and runs no recall-sessions"
      ]
    },
    {
      "id": 5,
      "kind": "dialogue",
      "prompt": "What does recall mean in machine learning metrics?",
      "expected_output": "Answers the question directly; recall does not run.",
      "expectations": [
        "Does not read skills/recall/SKILL.md or call the recall skill",
        "Answers with the precision and recall definition"
      ]
    }
  ]
}
```

`evals/fixtures/recall-ledger/_kern/ledgers/export/ledger.md` (M2b's runner copies `_kern` to `.kern`):

```markdown
# kern ledger: /work/app/.kern/plans/export.md
Main: /work/app branch=main status=0000000000000000000000000000000000000000
Task 1: start tree=1111111111111111111111111111111111111111 at=2026-10-10T09:00:00Z
Task 1: review round=1 tree=2222222222222222222222222222222222222222 spec=compliant quality=approved
Task 1: complete tree=2222222222222222222222222222222222222222 test=npm test exit=0 review=approved probe=ok last=# pass 4
Task 2: start tree=2222222222222222222222222222222222222222 at=2026-10-10T10:00:00Z
Task 2: review round=1 tree=3333333333333333333333333333333333333333 spec=compliant quality=approved
Task 2: complete tree=3333333333333333333333333333333333333333 test=npm test exit=0 review=approved probe=ok last=# pass 6
Task 3: start tree=3333333333333333333333333333333333333333 at=2026-10-10T11:00:00Z
```

- [ ] **Step 6: Write `tests/skills/recall.acceptance.md`**

```markdown
# recall: acceptance checks (the skills spec's C11; run during the M2b pilot and by M2b's runner)

- [ ] "Where did I leave off on the floci swap?": scope stated back; transcripts found with recall-sessions and mined by subagents; PR states checked with `gh`; one tag per thread; no file written.
- [ ] A ledger shows Task 3 of 5 incomplete: the brief names it as the next move.
- [ ] "recall chat" after a long background run: the action-item count comes first.
- [ ] "Resume session 7f3a": points to `claude --resume`, no mining.
- [ ] "What does recall mean in ML?": recall stays quiet.
```

- [ ] **Step 7: Add the map row and the changelog line**

Append to `skills/help/references/map.md`: ``| `recall` | auto | Its description; routed row "Starting or resuming after a gap" | Rebuild state across sessions; recall chat for this thread |``
Add under `## [Unreleased]`: `- recall: rebuild state from kern working files, this project's transcripts and live state; replaces the user-level recall skill.`

- [ ] **Step 8: Run the tests, lint and routing evals**

Run: `node --test tests/skills/recall.test.mjs && node scripts/lint-skills.mjs && node scripts/route-eval.mjs`
Expected: `# fail 0`; no lint errors (auto total 522 of 1,500; auto plus agents 945 of 2,500); `route-eval: passed` (rank-1 rate 83%, measured on this corpus).

- [ ] **Step 9: Commit**

```bash
git add -- skills/recall tests/skills/recall.test.mjs tests/skills/recall.acceptance.md evals/cases/recall.json evals/fixtures/recall-ledger skills/help/references/map.md CHANGELOG.md
git commit -m "M2: add the recall skill" -m "Rebuilding state starts from kern's own ledgers and plans, then this project's transcripts, and always checks live PR state before tagging."
```

---

