// Removal mutations on the Task 30 guards: apply one, run the three test files, expect a failure, restore.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = process.argv[2];
const RE = 'scripts/route-eval.mjs';
const LR = 'scripts/lib/lint-rules.mjs';
const KR = 'scripts/lib/kernel-rows.mjs';
const M = [
  [RE, 'floors missing check', "    if (!existsSync(path)) { setup.push(`evals/${name} is missing`); return null; }\n", ''],
  [RE, 'floors finite check', "    if (bad.length) { setup.push(`evals/${name} needs a finite number for ${bad.join(' and ')}`); return null; }\n", ''],
  [RE, 'setup exit', "  if (setup.length) {\n    for (const e of setup) console.log(`error: ${e}`);\n    console.log('route-eval: FAILED');\n    process.exit(1);\n  }\n", ''],
  [RE, 'Math.max -> floors only', 'Math.max(baseline.min_rank1, floors.rank1)', 'floors.rank1'],
  [RE, 'Math.max -> baseline only', 'Math.max(baseline.min_rank1, floors.rank1)', 'baseline.min_rank1'],
  [RE, 'minHeldout wiring', 'minHeldout: floors.heldout_rank1', 'minHeldout: null'],
  [RE, 'heldout missing when required', "    if (required) errors.push('evals/heldout.json is missing, so the held-out floor cannot be checked');\n", ''],
  [RE, 'heldout invalid JSON catch', "  try { held = JSON.parse(readFileSync(path, 'utf8')); }\n  catch (e) { errors.push(`evals/heldout.json: invalid JSON: ${e.message}`); return null; }\n", "  held = JSON.parse(readFileSync(path, 'utf8'));\n"],
  [RE, 'heldout array check', "  if (!Array.isArray(held) || !held.length) { errors.push('evals/heldout.json must be a non-empty array of { owner, prompt }'); return null; }\n", ''],
  [RE, 'heldout entry shape', "  if (bad >= 0) { errors.push(`evals/heldout.json entry ${bad} is not { owner, prompt }`); return null; }\n", ''],
  [RE, 'heldout unknown owner', "      if (!owners.some((t) => ownerOf(t.name) === h.owner)) { errors.push(`heldout: no owner \"${h.owner}\" for \"${h.prompt}\"`); continue; }\n", ''],
  [RE, 'empty corpus', "  if (minRank1 !== null && !positives) errors.push('no case positives to rank, so the rank-1 floor cannot be checked');\n", ''],
  [RE, 'ownerOf by kind', "(kinds.get(name) === 'row' ? name.replace(/^row-/, '') : name)", "name.replace(/^row-/, '')"],
  [RE, 'positive grader error', "      if (p.grader !== undefined) errors.push(", "      if (false) errors.push("],
  [RE, 'unknown grader error', "      if (n.grader !== undefined && !modelGraded(n)) errors.push(", "      if (false) errors.push("],
  [RE, 'model-graded skip', '      if (modelGraded(n)) { graded.push({ owner: expected, prompt: n.prompt }); continue; }\n', ''],
  [RE, 'route-eval minimum counts lexical only', '(d.trigger?.negative || []).filter((n) => !modelGraded(n)).length', '(d.trigger?.negative || []).length'],
  [RE, 'CLI prints model-graded', '  for (const m of r.modelGraded) console.log(`model-graded, not checked here: ${m.owner}: "${m.prompt}"`);\n', ''],
  [LR, 'rule 7 fixture check', "    if (!settings.length) out.push(", "    if (false) out.push("],
  [LR, 'rule 7 header requirement', "r.status === 0 && (r.stdout || '').split('\\n').some((l) => l.startsWith(header))", "r.status === 0 && (r.stdout || '').trim() !== ''"],
  [LR, 'rule 7 exit requirement', "r.status === 0 && (r.stdout || '').split('\\n').some((l) => l.startsWith(header))", "(r.stdout || '').split('\\n').some((l) => l.startsWith(header))"],
  [LR, 'rule 7 start not rendered', "      if (!rendered(start)) out.push(", "      if (false) out.push("],
  [LR, 'rule 7 again not rendered', "      if (rendered(start) && !rendered(again)) out.push(", "      if (false) out.push("],
  [LR, 'rule 7 git init', "      if (init.status !== 0) out.push(", "      if (false) out.push("],
  [LR, 'rule 7 routes.md cap', "    if (model.routesText.length > 1500) out.push(", "    if (false) out.push("],
  [LR, 'rule 7 standing cost', "      if (bare.length + desc > 4800) out.push(", "      if (false) out.push("],
  [LR, 'rule 6 kernel names routes.md', "    if (kernelRows(model.routesText).length && !model.kernelText.includes('{ROOT}/kernel/routes.md')) {", "    if (false) {"],
  [LR, 'rule 6 reads routes.md', "['kernel/routes.md', model.routesText]];", '];'],
  [LR, 'rule 12 flagged positive', "      if (flagged) out.push(", "      if (false) out.push("],
  [LR, 'rule 12 invalid JSON', "      if (c.parseError) { out.push(err(12, path, `evals/cases/${key}.json is not valid JSON: ${c.parseError}`)); return; }\n", "      if (c.parseError) return;\n"],
  [LR, 'rule 12 lexical negatives only', "c.trigger?.negative?.filter((n) => n.grader !== 'model').length", 'c.trigger?.negative?.length'],
  [LR, 'rule 12 rows of routes.md', "for (const [src, text] of [['kernel/kernel.md', model.kernelText], ['kernel/routes.md', model.routesText]]) {", "for (const [src, text] of [['kernel/kernel.md', model.kernelText]]) {"],
  [LR, 'routed tier from routes.md', "routedSkills(`${kernelText}\\n${routesText}`)", 'routedSkills(kernelText)'],
  [LR, 'routed tier from rows only', "routedSkills(`${kernelText}\\n${routesText}`)", "new Set([...`${kernelText}\\n${routesText}`.matchAll(/Read \\{KERN\\}\\/([a-z0-9-]+)\\/SKILL\\.md/g)].map((m) => m[1]))"],
  [LR, 'rule 5 scans routes.md', "    if (model.routesText) docs.push(", "    if (false) docs.push("],
  [KR, 'parseRow routes.md error', "  if (base === 'ROOT' && path === 'kernel/routes.md') return {", "  if (false) return {"],
  [KR, 'parseRow bare-form error', "  if (!m) return { error:", "  if (!m) return null; if (false) return { error:"],

];
const tests = ['tests/route-eval-rows.test.mjs', 'tests/lint-rules.test.mjs', 'tests/route-eval.test.mjs'];
const originals = Object.fromEntries([RE, LR, KR].map((f) => [f, readFileSync(join(root, f), 'utf8')]));
let killed = 0;
const survived = [];
try {
  for (const [file, name, from, to] of M) {
    const src = originals[file];
    const n = src.split(from).length - 1;
    if (n !== 1) { console.log(`NO-MATCH (${n}) ${name}`); survived.push(`${name} (no match)`); continue; }
    writeFileSync(join(root, file), src.replace(from, () => to));
    const r = spawnSync(process.execPath, ['--test', ...tests], { cwd: root, encoding: 'utf8' });
    writeFileSync(join(root, file), src);
    if (r.status !== 0) { killed++; console.log(`killed   ${name}`); }
    else { survived.push(name); console.log(`SURVIVED ${name}`); }
  }
} finally {
  for (const [f, s] of Object.entries(originals)) writeFileSync(join(root, f), s);
}
console.log(`mutations: ${M.length}, killed: ${killed}, survived: ${survived.length}${survived.length ? ` (${survived.join('; ')})` : ''}`);
