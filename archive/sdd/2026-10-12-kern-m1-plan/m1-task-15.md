### Task 15: `unslop` and `technical-writing` (ports)

**Files:**
- Create: `skills/unslop/SKILL.md` (port of `.upstream/local/unslop/SKILL.md`, lines 5 to 105)
- Create: `skills/technical-writing/SKILL.md` (port of `.upstream/pstack/pstack/skills/technical-writing/SKILL.md`, lines 8 to 106, MIT)
- Modify: `NOTICE` (File map lines)
- Test: `tests/skills-writing.test.mjs`

**Interfaces:**
- Consumes: `.upstream/local` and `.upstream/pstack` from M0's `scripts/fetch-upstream`.
- Produces: `skills/technical-writing/SKILL.md`, the target of the kernel row "Prose others read", whose first H2 is `## Steps`; `skills/unslop/SKILL.md`, which the kernel's Reply rule and technical-writing step 5 name by path.

Adaptation rules for both files: no source tags; no personal names or machine paths; kern vocabulary (`/kern:` commands, "the kernel"); unslop rules; no long dashes, no curly quotes. Required headings, in order: unslop `## Shape`, `## Document rules`, `## Process`, `## Adding soul`, `## Patterns to detect and fix`; technical-writing `## Steps`, `## Standard`, `## Vary the rhythm`, `## Pick the mode first (Diátaxis)`, `## Write sentences to the reader (Google developer style)`, `## Make statements load one at a time (STE rules)`, `## Leave no sentence open to two readings (Global English)`, `## Voice and repo specifics`, `## Worked example`.

- [ ] **Step 1: Write the failing test**

`tests/skills-writing.test.mjs`:
```js
// unslop and technical-writing: ported bodies keep their headings; frontmatter and Steps are kern's.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';

const read = (name) => parseFrontmatter(readFileSync(join(import.meta.dirname, '..', 'skills', name, 'SKILL.md'), 'utf8'));
const h2 = (body) => body.split('\n').filter((l) => l.startsWith('## ')).map((l) => l.slice(3));

test('unslop: path-tier frontmatter and the upstream sections in order', () => {
  const { data, body } = read('unslop');
  assert.equal(data['disable-model-invocation'], 'true');
  assert.ok(data.description.length <= 120);
  assert.deepEqual(h2(body), ['Shape', 'Document rules', 'Process', 'Adding soul', 'Patterns to detect and fix']);
  assert.match(body, /chat replies follow the active kern voice first/);
});

test('technical-writing: opens with Steps that apply unslop, then the standard', () => {
  const { data, body } = read('technical-writing');
  assert.equal(data['disable-model-invocation'], 'true');
  assert.ok(data.description.length <= 120);
  assert.deepEqual(h2(body), ['Steps', 'Standard', 'Vary the rhythm', 'Pick the mode first (Diátaxis)', 'Write sentences to the reader (Google developer style)', 'Make statements load one at a time (STE rules)', 'Leave no sentence open to two readings (Global English)', 'Voice and repo specifics', 'Worked example']);
  assert.match(body, /5\. Apply `\$\{CLAUDE_PLUGIN_ROOT\}\/skills\/unslop\/SKILL\.md` to the whole text\./);
  assert.doesNotMatch(body, /Indent code snippets with tabs/);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node --test tests/skills-writing.test.mjs`
Expected: FAIL with `ENOENT ... skills/unslop/SKILL.md`.

- [ ] **Step 3: Port `unslop`**

The frontmatter and the first body sentence are the contract parts; the rest is the upstream body unchanged.

```bash
mkdir -p skills/unslop
{
  printf -- '---\nname: unslop\ndescription: "Rules for prose others read: artifact shapes, document rules and the catalogue of AI-writing tells."\ndisable-model-invocation: true\n---\n'
  sed -e '1,4d' .upstream/local/unslop/SKILL.md
} | sed -e 's/^The output contract\. It applies to everything composed for a reader: chat replies, /The output contract. It applies to everything composed for a reader (chat replies follow the active kern voice first): chat replies, /' >skills/unslop/SKILL.md
sed -n '1,9p' skills/unslop/SKILL.md
```
Expected: the new frontmatter, `# Unslop`, and the edited first sentence `The output contract. It applies to everything composed for a reader (chat replies follow the active kern voice first): chat replies, subagent returns, ...`.

- [ ] **Step 4: Port `technical-writing`**

The frontmatter, the title and `## Steps` are the contract parts; `## Standard` starts the upstream body, with three edits.

```bash
mkdir -p skills/technical-writing
{
  cat <<'MD'
---
name: technical-writing
description: Write docs, PR bodies, issues and commit messages a tired engineer understands on the first read.
disable-model-invocation: true
---

# Technical writing

## Steps
1. Name the reader and the artifact: PR body, commit message, issue, doc, or a reply others will read.
2. For a doc, pick its mode (tutorial, how-to, reference or explanation) and keep to it. PR bodies and commit messages skip this step.
3. Draft with the sentence rules below: the reader as "you", the actor named, the condition before the instruction, one instruction per sentence.
4. Read every sentence for a second reading and rewrite each one that has it.
5. Apply `${CLAUDE_PLUGIN_ROOT}/skills/unslop/SKILL.md` to the whole text.
6. Check every count, path and command in the text against the repo at the commit that lands it.

## Standard
MD
  sed -e '1,7d' .upstream/pstack/pstack/skills/technical-writing/SKILL.md
} | sed \
  -e 's/Apply the \*\*unslop\*\* skill to every doc this skill touches. That skill owns/Apply unslop (step 5) to every text this skill touches. It owns/' \
  -e "s/Propose a new offender and its replacement as an addition to \`unslop\`'s abstract-metaphor rule in your reply, with the diff. Don't edit that skill./Propose a new offender and its replacement for unslop's abstract-metaphor rule in your reply. Do not edit unslop yourself./" \
  -e 's/ Indent code snippets with tabs\.//' >skills/technical-writing/SKILL.md
grep -n 'unslop' skills/technical-writing/SKILL.md
```
Expected: three lines: step 5, the jargon paragraph ending `Do not edit unslop yourself.`, and `- Apply unslop (step 5) to every text this skill touches. It owns the slop-pattern catalog: ...`.

- [ ] **Step 5: Add the NOTICE file map lines**

Append under `## File map` in `NOTICE`:

```markdown
- skills/unslop/SKILL.md: local unslop/SKILL.md (the user's adapted copy of pstack unslop)
- skills/technical-writing/SKILL.md: pstack pstack/skills/technical-writing/SKILL.md
- modes/terse.md: caveman skills/caveman/SKILL.md (idea only; text written for kern)
- hooks/prompt-submit: caveman src/hooks/caveman-parse.js and caveman-mode-tracker.js (ideas only: envelope parsing, negation and question guards; code written for kern)
```

- [ ] **Step 6: Check, then run the test and lint**

```bash
for h in 'Shape' 'Document rules' 'Process' 'Adding soul' 'Patterns to detect and fix'; do grep -q "^## $h$" skills/unslop/SKILL.md || echo "missing unslop: $h"; done
for h in 'Steps' 'Standard' 'Vary the rhythm' 'Voice and repo specifics' 'Worked example'; do grep -q "^## $h$" skills/technical-writing/SKILL.md || echo "missing tw: $h"; done
wc -c skills/unslop/SKILL.md skills/technical-writing/SKILL.md
node --test tests/skills-writing.test.mjs && node scripts/lint-skills.mjs && node --test tests/licensing.test.mjs
```
Expected: no `missing` line; sizes about 8.7 KB and 9.5 KB (each under 12,000 bytes); `# pass 2`; `lint: clean`; the licensing test passes.

- [ ] **Step 7: Commit**

```bash
git add -- skills/unslop/SKILL.md skills/technical-writing/SKILL.md tests/skills-writing.test.mjs NOTICE
git commit -m "M1: port unslop and technical-writing as kern skills" -m "The kernel routes prose others read to technical-writing, which applies unslop; both ports keep their upstream sections."
```

---

