// Helpers for tests that pin skill and agent files to their contracts.
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { parseFrontmatter } from '../../scripts/lib/frontmatter.mjs';

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
export const DEFER = '0. Defer: if the kern settings block names an override for this job, follow that project skill instead, say so in one line, and stop.';

export function readDoc(rel) {
  const path = join(ROOT, rel);
  assert.ok(existsSync(path), `${rel} exists`);
  const raw = readFileSync(path, 'utf8');
  const { data, body, error } = raw.startsWith('---') ? parseFrontmatter(raw) : { data: {}, body: raw, error: null };
  return { path, raw, data, body, error };
}

export function stripFences(text) {
  let fence = false;
  return text.split('\n').map((l) => {
    if (/^\s{0,3}(```|~~~)/.test(l)) { fence = !fence; return ''; }
    return fence ? '' : l;
  }).join('\n');
}

export const h2s = (body) => stripFences(body).split('\n').filter((l) => /^## /.test(l)).map((l) => l.trim());

export function section(body, heading) {
  const lines = stripFences(body).split('\n');
  const i = lines.findIndex((l) => l.trim() === heading);
  if (i < 0) return null;
  const out = [];
  for (const l of lines.slice(i + 1)) { if (/^## /.test(l)) break; out.push(l); }
  return out.join('\n');
}

export const steps = (body) => (section(body, '## Steps') ?? '').split('\n').filter((l) => /^\d+\.\s/.test(l));

export function assertFrontmatter(rel, expected) {
  const d = readDoc(rel);
  assert.equal(d.error, null, `${rel} frontmatter parses`);
  assert.deepEqual(d.data, expected);
  return d;
}

export function assertHeadings(rel, headings) {
  const found = stripFences(readDoc(rel).raw).split('\n').filter((l) => /^#{1,3} /.test(l)).map((l) => l.trim());
  let at = -1;
  for (const h of headings) {
    const i = found.indexOf(h, at + 1);
    assert.ok(i > at, `${rel}: heading "${h}" missing or out of order; found ${JSON.stringify(found)}`);
    at = i;
  }
}

export function assertMaxBytes(rel, n) {
  const size = statSync(join(ROOT, rel)).size;
  assert.ok(size <= n, `${rel} is ${size} bytes; limit ${n}`);
}

export function assertContains(rel, needles) {
  const { raw } = readDoc(rel);
  for (const n of needles) assert.ok(raw.includes(n), `${rel} must contain: ${n}`);
}
