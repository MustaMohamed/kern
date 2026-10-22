// unslop and technical-writing: ported bodies keep their headings; frontmatter and Steps are kern's.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';
import { steps, DEFER } from './helpers/md.mjs';

const read = (name) => parseFrontmatter(readFileSync(join(import.meta.dirname, '..', 'skills', name, 'SKILL.md'), 'utf8'));
const h2 = (body) => body.split('\n').filter((l) => l.startsWith('## ')).map((l) => l.slice(3));

test('unslop: path-tier frontmatter and the upstream sections in order', () => {
  const { data, body } = read('unslop');
  assert.equal(data['disable-model-invocation'], 'true');
  assert.ok(data.description.length <= 120);
  assert.deepEqual(h2(body), ['Shape', 'Document rules', 'Process', 'Adding soul', 'Patterns to detect and fix']);
  assert.match(body, /Chat replies follow the active kern voice first\. Everything else composed for a reader follows this file: /);
});

test('technical-writing: opens with Steps that apply unslop, then the standard', () => {
  const { data, body } = read('technical-writing');
  assert.equal(data['disable-model-invocation'], 'true');
  assert.ok(data.description.length <= 120);
  assert.deepEqual(h2(body), ['Steps', 'Standard', 'Vary the rhythm', 'Pick the mode first (Diátaxis)', 'Write sentences to the reader (Google developer style)', 'Make statements load one at a time (STE rules)', 'Leave no sentence open to two readings (Global English)', 'Voice and repo specifics', 'Worked example']);
  assert.match(body, /5\. Apply `\$\{CLAUDE_PLUGIN_ROOT\}\/skills\/unslop\/SKILL\.md` to the whole text\./);
  assert.doesNotMatch(body, /Indent code snippets with tabs/);
});

// The per-prompt routing reminder sends a model to a route or to the override named for its job; the route
// itself defers too, as every other route does, so a project technical-writing skill wins (audit 2026-10-22, B4).
test('technical-writing: step 0 defers to an override for the job, like every other route', () => {
  const s = steps(read('technical-writing').body);
  assert.equal(s[0], DEFER);
  assert.match(s[1], /^1\. Name the reader and the artifact/);
});
