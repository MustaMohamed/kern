#!/usr/bin/env node
// CLI over scripts/lib/lint-rules.mjs. Exit 1 when any error remains.
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadModel, runLint } from './lib/lint-rules.mjs';

const root = resolve(process.argv[2] || fileURLToPath(new URL('..', import.meta.url)));
const findings = runLint(loadModel(root));
for (const f of findings) console.log(`${f.level} ${f.path}: rule ${f.rule}: ${f.message}`);
const errors = findings.filter((f) => f.level === 'error').length;
console.log(errors ? `lint: ${errors} error(s)` : 'lint: clean');
process.exit(errors ? 1 : 0);
