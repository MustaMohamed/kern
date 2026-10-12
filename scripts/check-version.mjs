#!/usr/bin/env node
// Lint rule 14: manifests and the newest CHANGELOG release agree; shipped changes add an Unreleased line.
// Idea from addyosmani/agent-skills scripts/validate-versions.js (MIT); the code is written for kern.
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

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

export function checkUnreleased(root, changedFiles) {
  if (!changedFiles.some((f) => SHIPPED.test(f))) return [];
  const changelog = readFileSync(join(root, 'CHANGELOG.md'), 'utf8');
  return unreleasedBullets(changelog).length ? [] : ['shipped files changed but ## [Unreleased] has no bullet'];
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = fileURLToPath(new URL('..', import.meta.url));
  const problems = checkVersions(root);
  const i = process.argv.indexOf('--pr');
  if (i > 0) {
    const base = process.argv[i + 1];
    const changed = execFileSync('git', ['-C', root, 'diff', '--name-only', `${base}...HEAD`], { encoding: 'utf8' }).split('\n').filter(Boolean);
    problems.push(...checkUnreleased(root, changed));
  }
  for (const p of problems) console.log(`error: ${p}`);
  console.log(problems.length ? 'versions: FAILED' : 'versions: agree');
  process.exit(problems.length ? 1 : 0);
}
