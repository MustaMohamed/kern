#!/usr/bin/env node
// Lint rule 14: manifests and the newest CHANGELOG release agree; shipped changes add an Unreleased line.
// Idea from addyosmani/agent-skills scripts/validate-versions.js (MIT); the code is written for kern.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { isMain } from './lib/is-main.mjs';

const SHIPPED = /^(skills|agents|kernel|modes|hooks)\//;
const json = (root, p) => JSON.parse(readFileSync(join(root, p), 'utf8'));

export function unreleasedBullets(changelog) {
  const m = changelog.match(/^## \[Unreleased\]\n([\s\S]*?)(?=^## \[|(?![\s\S]))/m);
  return m ? m[1].split('\n').filter((l) => /^- /.test(l)) : [];
}

export function checkVersions(root) {
  const problems = [];
  const plugin = json(root, '.claude-plugin/plugin.json').version;
  const market = json(root, '.claude-plugin/marketplace.json').plugins?.[0]?.version;
  const changelog = readFileSync(join(root, 'CHANGELOG.md'), 'utf8');
  const release = changelog.match(/^## \[(\d+\.\d+\.\d+)\]/m)?.[1];
  if (plugin !== market) problems.push(`plugin.json ${plugin} != marketplace.json ${market}`);
  if (!release) problems.push(`CHANGELOG.md has no release heading; expected ## [${plugin}] - <date>`);
  else if (release !== plugin) problems.push(`newest CHANGELOG release ${release} != plugin.json ${plugin}`);
  return problems;
}

export function checkUnreleased(root, changedFiles, baseChangelog) {
  if (!changedFiles.some((f) => SHIPPED.test(f))) return [];
  const changelog = readFileSync(join(root, 'CHANGELOG.md'), 'utf8');
  const old = new Set(baseChangelog === undefined ? [] : unreleasedBullets(baseChangelog));
  const added = unreleasedBullets(changelog).filter((b) => !old.has(b));
  return added.length ? [] : ['shipped files changed but ## [Unreleased] has no new bullet compared with the base'];
}

function baseChangelogAt(root, base) {
  try {
    return execFileSync('git', ['-C', root, 'show', `${base}:CHANGELOG.md`], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) {
    if (/exists on disk, but not in|does not exist in|path .* does not exist/.test(String(e.stderr))) return '';
    throw e;
  }
}

if (isMain(import.meta.url)) {
  const root = fileURLToPath(new URL('..', import.meta.url));
  const i = process.argv.indexOf('--pr');
  const base = i > 0 ? process.argv[i + 1] : undefined;
  if (i > 0 && !base) {
    console.error('usage: check-version.mjs [--pr <base-ref>]');
    process.exit(2);
  }
  const problems = checkVersions(root);
  if (i > 0) {
    const changed = execFileSync('git', ['-C', root, 'diff', '--name-only', `${base}...HEAD`], { encoding: 'utf8' }).split('\n').filter(Boolean);
    problems.push(...checkUnreleased(root, changed, baseChangelogAt(root, base)));
  }
  for (const p of problems) console.log(`error: ${p}`);
  console.log(problems.length ? 'versions: FAILED' : 'versions: agree');
  process.exit(problems.length ? 1 : 0);
}
