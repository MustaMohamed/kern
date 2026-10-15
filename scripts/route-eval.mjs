#!/usr/bin/env node
// Tier 1 routing evals (design spec 11.1). Adapted from addyosmani/agent-skills scripts/run-evals.js (MIT), deterministic tier only.
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isMain } from './lib/is-main.mjs';
import { loadModel } from './lib/lint-rules.mjs';
import { buildCorpus, rank, similarity } from './lib/rank.mjs';
import { kernelRows, routeText } from './lib/kernel-rows.mjs';

const MIN_POSITIVE = 3;
const MIN_NEGATIVE = 2;
const MIN_EVALS = 1;
const COLLISION_WARN = 0.5;
const COLLISION_ERROR = 0.75;

export function targets(root) {
  const model = loadModel(root);
  const skills = model.skills.filter((s) => s.tier === 'auto' && s.data.description)
    .map((s) => ({ name: s.name, text: s.data.description, kind: 'skill' }));
  const rows = kernelRows(routeText(model)).map((r) => ({ name: `row-${r.route}`, text: r.when, kind: 'row' }));
  const dPath = join(root, 'evals', 'distractors.json');
  const distractors = existsSync(dPath) ? JSON.parse(readFileSync(dPath, 'utf8')).map((d) => ({ name: d.name, text: d.description, kind: 'distractor' })) : [];
  return [...skills, ...rows, ...distractors];
}

// A negative marked "grader": "model" is one the lexical ranker cannot judge, such as a question about the words a
// row uses. It is listed on every run, left out of the checks and minimums here, and checked by M2b's model-graded runner.
const modelGraded = (n) => n.grader === 'model';

function loadCases(root) {
  const dir = join(root, 'evals', 'cases');
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => f.endsWith('.json')).sort().map((f) => {
    try { return { file: f, data: JSON.parse(readFileSync(join(dir, f), 'utf8')) }; }
    catch (e) { return { file: f, parseError: e.message }; }
  });
}

// evals/heldout.json: a non-empty array of { owner, prompt }. Missing is an error only when a floor is set; malformed
// always is. Returns null when there is nothing to rank.
function loadHeldout(root, required, errors) {
  const path = join(root, 'evals', 'heldout.json');
  if (!existsSync(path)) {
    if (required) errors.push('evals/heldout.json is missing, so the held-out floor cannot be checked');
    return null;
  }
  let held;
  try { held = JSON.parse(readFileSync(path, 'utf8')); }
  catch (e) { errors.push(`evals/heldout.json: invalid JSON: ${e.message}`); return null; }
  if (!Array.isArray(held) || !held.length) { errors.push('evals/heldout.json must be a non-empty array of { owner, prompt }'); return null; }
  const bad = held.findIndex((h) => typeof h?.owner !== 'string' || typeof h?.prompt !== 'string');
  if (bad >= 0) { errors.push(`evals/heldout.json entry ${bad} is not { owner, prompt }`); return null; }
  return held;
}

export function evaluate(root, { minRank1, minHeldout = null }) {
  const all = targets(root);
  // A kernel row and the skill it routes to are one owner: either ranking first is a hit. Only a row folds, by its
  // kind, so a skill or distractor that happens to be named row-<x> stays its own owner.
  const kinds = new Map(all.map((t) => [t.name, t.kind]));
  const ownerOf = (name) => (kinds.get(name) === 'row' ? name.replace(/^row-/, '') : name);
  const owners = all.filter((t) => t.kind !== 'distractor');
  const corpus = buildCorpus(all);
  const names = new Set(all.map((t) => t.name));
  const cases = loadCases(root);
  const errors = [];
  const warnings = [];
  const graded = [];
  let positives = 0;
  let rank1 = 0;

  for (const t of owners) if (!cases.some((c) => c.file === `${t.name}.json`)) errors.push(`${t.name}: no eval case file (evals/cases/${t.name}.json)`);

  for (const c of cases) {
    if (c.parseError) { errors.push(`${c.file}: invalid JSON: ${c.parseError}`); continue; }
    const d = c.data;
    const expected = c.file.replace(/\.json$/, '');
    if (d.skill_name !== expected) errors.push(`${c.file}: skill_name "${d.skill_name}" does not match the file name`);
    if (!owners.some((t) => t.name === expected)) { errors.push(`${c.file}: no such auto skill or kernel row`); continue; }
    for (const ev of d.evals || []) {
      const ok = Number.isInteger(ev.id) && typeof ev.prompt === 'string' && typeof ev.expected_output === 'string' && Array.isArray(ev.expectations) && ev.expectations.length > 0;
      if (!ok) errors.push(`${c.file}: eval id=${ev.id} does not match the evals schema`);
      const kind = ev.kind || 'execution';
      if (!['execution', 'dialogue'].includes(kind)) errors.push(`${c.file}: eval id=${ev.id} has unknown kind "${kind}"`);
      if (kind === 'execution' && !(Array.isArray(ev.files) && ev.files.length)) errors.push(`${c.file}: eval id=${ev.id} needs files[]`);
      for (const f of ev.files || []) if (!existsSync(join(root, 'evals', 'fixtures', f))) errors.push(`${c.file}: eval id=${ev.id} fixture not found: evals/fixtures/${f}`);
    }
    for (const p of d.trigger?.positive || []) {
      if (p.grader !== undefined) errors.push(`${expected}: a positive prompt cannot carry "grader"; only a negative can be model-graded: "${p.prompt}"`);
      positives++;
      const topK = p.top_k || 3;
      const r = rank(p.prompt, corpus);
      const idx = r.findIndex((x) => ownerOf(x.name) === ownerOf(expected));
      const hit = r[idx];
      if (idx === 0 && hit.score > 0) rank1++;
      if (!hit || hit.score === 0) errors.push(`${expected}: description shares no vocabulary with "${p.prompt}"`);
      else if (idx >= topK) errors.push(`${expected}: positive prompt ranked #${idx + 1} (need top ${topK}): "${p.prompt}"; top: ${r.slice(0, 3).map((x) => `${x.name} ${x.score.toFixed(2)}`).join(', ')}`);
    }
    for (const n of d.trigger?.negative || []) {
      if (n.grader !== undefined && !modelGraded(n)) errors.push(`${expected}: unknown grader "${n.grader}" for negative "${n.prompt}"; the only grader is "model"`);
      if (modelGraded(n)) { graded.push({ owner: expected, prompt: n.prompt }); continue; }
      const r = rank(n.prompt, corpus);
      if (ownerOf(r[0].name) === ownerOf(expected) && r[0].score > 0) errors.push(`${expected}: ranked #1 for negative prompt "${n.prompt}"`);
      if (n.owner) {
        if (!names.has(n.owner)) errors.push(`${c.file}: negative names unknown owner "${n.owner}"`);
        else {
          const oi = r.findIndex((x) => x.name === n.owner);
          const si = r.findIndex((x) => ownerOf(x.name) === ownerOf(expected));
          if (r[oi].score === 0 || oi > si) errors.push(`${expected}: owner ${n.owner} does not outrank it for "${n.prompt}"`);
        }
      }
    }
    const pc = (d.trigger?.positive || []).length;
    const nc = (d.trigger?.negative || []).filter((n) => !modelGraded(n)).length;
    const ec = (d.evals || []).length;
    if (pc < MIN_POSITIVE || nc < MIN_NEGATIVE || ec < MIN_EVALS) errors.push(`${expected}: below required minimums (${pc}/${nc}/${ec}; need ${MIN_POSITIVE}/${MIN_NEGATIVE}/${MIN_EVALS})`);
  }

  // targets() puts owners first and distractors last, so all[i] === owners[i] for i < owners.length.
  for (let i = 0; i < owners.length; i++) {
    for (let j = i + 1; j < all.length; j++) {
      const a = owners[i].name;
      const b = all[j].name;
      if (ownerOf(a) === ownerOf(b)) continue;
      const sim = similarity(a, b, corpus);
      if (sim >= COLLISION_ERROR) errors.push(`collision: ${a} and ${b} are ${(sim * 100).toFixed(0)}% similar`);
      else if (sim >= COLLISION_WARN) warnings.push(`overlap: ${a} and ${b} are ${(sim * 100).toFixed(0)}% similar`);
    }
  }

  const rank1Rate = positives ? Math.floor((rank1 / positives) * 100) : null;
  if (minRank1 !== null && rank1Rate !== null && rank1Rate < minRank1) errors.push(`rank-1 rate ${rank1Rate}% is below the floor ${minRank1}%`);
  if (minRank1 !== null && !positives) errors.push('no case positives to rank, so the rank-1 floor cannot be checked');

  // Held-out organic prompts (evals/heldout.json), frozen by a test: never reworded to pass.
  let heldoutRate = null;
  const held = loadHeldout(root, minHeldout != null, errors);
  if (held) {
    let hits = 0;
    for (const h of held) {
      if (!owners.some((t) => ownerOf(t.name) === h.owner)) { errors.push(`heldout: no owner "${h.owner}" for "${h.prompt}"`); continue; }
      const r = rank(h.prompt, corpus);
      if (ownerOf(r[0].name) === h.owner && r[0].score > 0) hits++;
    }
    heldoutRate = Math.floor((hits / held.length) * 100);
    if (minHeldout != null && heldoutRate !== null && heldoutRate < minHeldout) errors.push(`held-out rank-1 rate ${heldoutRate}% is below the floor ${minHeldout}%`);
  }
  return { errors, warnings, rank1Rate, heldoutRate, modelGraded: graded };
}

if (isMain(import.meta.url)) {
  const root = resolve(process.argv.slice(2).find((a) => !a.startsWith('--')) || fileURLToPath(new URL('..', import.meta.url)));
  const basePath = join(root, 'evals', 'baseline.json');
  // The gate's own inputs. A missing or malformed file stops the run with a message; it never falls back to a floor
  // of 0, and a null or NaN floor never reaches a comparison, where it would pass everything.
  const setup = [];
  const gateFile = (name, keys) => {
    const path = join(root, 'evals', name);
    if (!existsSync(path)) { setup.push(`evals/${name} is missing`); return null; }
    let data;
    try { data = JSON.parse(readFileSync(path, 'utf8')); }
    catch (e) { setup.push(`evals/${name}: invalid JSON: ${e.message}`); return null; }
    const bad = keys.filter((k) => !Number.isFinite(data?.[k]));
    if (bad.length) { setup.push(`evals/${name} needs a finite number for ${bad.join(' and ')}`); return null; }
    return data;
  };
  const baseline = gateFile('baseline.json', ['min_rank1']);
  // evals/floors.json holds fixed floors a test pins; the baseline only rises above them.
  const floors = gateFile('floors.json', ['rank1', 'heldout_rank1']);
  if (setup.length) {
    for (const e of setup) console.log(`error: ${e}`);
    console.log('route-eval: FAILED');
    process.exit(1);
  }
  const minRank1 = Math.max(baseline.min_rank1, floors.rank1);
  const r = evaluate(root, { minRank1, minHeldout: floors.heldout_rank1 });
  for (const w of r.warnings) console.log(`warn: ${w}`);
  for (const e of r.errors) console.log(`error: ${e}`);
  for (const m of r.modelGraded) console.log(`model-graded, not checked here: ${m.owner}: "${m.prompt}"`);
  console.log(`rank-1 rate: ${r.rank1Rate ?? 'n/a'}% (baseline ${baseline.min_rank1}%, fixed floor ${floors.rank1}%)`);
  if (r.heldoutRate !== null) console.log(`held-out rank-1 rate: ${r.heldoutRate}% (fixed floor ${floors.heldout_rank1}%)`);
  if (process.argv.includes('--update-baseline') && !r.errors.length && r.rank1Rate !== null && r.rank1Rate > baseline.min_rank1) {
    writeFileSync(basePath, JSON.stringify({ min_rank1: r.rank1Rate }, null, 2) + '\n');
    console.log(`baseline raised to ${r.rank1Rate}%`);
  }
  console.log(r.errors.length ? 'route-eval: FAILED' : 'route-eval: passed');
  process.exit(r.errors.length ? 1 : 0);
}
