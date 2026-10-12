#!/usr/bin/env node
// Bumps both manifests and the CHANGELOG. Prints the tag command; never commits, tags or pushes.
import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function bump(version, part) {
  const [ma, mi, pa] = version.split('.').map(Number);
  if (part === 'major') return `${ma + 1}.0.0`;
  if (part === 'minor') return `${ma}.${mi + 1}.0`;
  if (part === 'patch') return `${ma}.${mi}.${pa + 1}`;
  throw new Error(`unknown part ${part}; use major, minor or patch`);
}

export function release(root, part, date) {
  const pluginPath = join(root, '.claude-plugin/plugin.json');
  const marketPath = join(root, '.claude-plugin/marketplace.json');
  const logPath = join(root, 'CHANGELOG.md');
  const plugin = JSON.parse(readFileSync(pluginPath, 'utf8'));
  const market = JSON.parse(readFileSync(marketPath, 'utf8'));
  const log = readFileSync(logPath, 'utf8');
  const block = (log.match(/^## \[Unreleased\]\n([\s\S]*?)(?=^## \[)/m)?.[1] || '').trim();
  if (!block) throw new Error('Unreleased is empty; add a line before releasing');
  const next = bump(plugin.version, part);
  plugin.version = next;
  market.plugins[0].version = next;
  const updated = log.replace(/^## \[Unreleased\]\n[\s\S]*?(?=^## \[)/m, () => `## [Unreleased]\n\n## [${next}] - ${date}\n\n${block}\n\n`);
  writeFileSync(pluginPath, JSON.stringify(plugin, null, 2) + '\n');
  writeFileSync(marketPath, JSON.stringify(market, null, 2) + '\n');
  writeFileSync(logPath, updated);
  return next;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = fileURLToPath(new URL('..', import.meta.url));
  const next = release(root, process.argv[2], new Date().toISOString().slice(0, 10));
  console.log(`released ${next}; review the diff, commit, then run: git tag v${next}`);
}
