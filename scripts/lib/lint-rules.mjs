// kern lint rules (design spec 11.2). Pure checks over a loaded model; the CLI is scripts/lint-skills.mjs.
// Rule set informed by addyosmani/agent-skills scripts/lib/skill-lint.js (MIT); the code is written for kern.
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { parseFrontmatter } from './frontmatter.mjs';

export const SKILL_KEYS = new Set(['name', 'description', 'when_to_use', 'argument-hint', 'arguments', 'disable-model-invocation', 'user-invocable', 'allowed-tools', 'disallowed-tools', 'model', 'effort', 'context', 'agent', 'background', 'hooks', 'paths', 'shell', 'metadata', 'license', 'compatibility']);
export const AGENT_KEYS = new Set(['name', 'description', 'tools', 'disallowedTools', 'model', 'effort', 'color', 'maxTurns', 'skills', 'memory', 'background', 'isolation']);
export const AGENT_KEYS_IGNORED_IN_PLUGINS = new Set(['permissionMode', 'hooks', 'mcpServers', 'initialPrompt']);
export const SHIPPED_DIRS = ['skills', 'agents', 'kernel', 'modes', 'hooks'];
export const LIMITS = { auto: 300, manual: 120, agent: 150, autoTotal: 1500, autoPlusAgents: 2500 };
const KEBAB = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const TRIGGER = /\buse (this )?when\b|\buse (before|after|during)\b/i;
const MACHINE_PATH = /(\/Users\/[A-Za-z]|\/home\/[a-z]|[A-Z]:\\Users\\|~\/Code\/)/;
const BINARY_EXT = /\.(png|jpe?g|gif|ico|webp|woff2?|ttf|otf|pdf|zip|gz)$/i;
const LONG_DASH = /[–—]/g;
const CURLY = /[‘’“”]/g;

export const rel = (model, p) => relative(model.root, p);

function walk(dir) {
  if (!existsSync(dir)) return [];
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else out.push(p);
  }
  return out;
}

export function loadModel(root) {
  const skills = [];
  const skillsDir = join(root, 'skills');
  if (existsSync(skillsDir)) {
    for (const dir of readdirSync(skillsDir)) {
      const file = join(skillsDir, dir, 'SKILL.md');
      if (!existsSync(file)) continue;
      const fm = parseFrontmatter(readFileSync(file, 'utf8'));
      skills.push({ name: fm.data.name, dir, file, data: fm.data, body: fm.body, error: fm.error });
    }
  }
  const kernelPath = join(root, 'kernel', 'kernel.md');
  const kernelText = existsSync(kernelPath) ? readFileSync(kernelPath, 'utf8') : '';
  const routed = new Set([...kernelText.matchAll(/Read \{KERN\}\/([a-z0-9-]+)\/SKILL\.md/g)].map((m) => m[1]));
  for (const s of skills) s.tier = s.data['disable-model-invocation'] !== 'true' ? 'auto' : routed.has(s.name) ? 'path' : 'slash';
  const cases = {};
  const casesDir = join(root, 'evals', 'cases');
  if (existsSync(casesDir)) {
    for (const f of readdirSync(casesDir).filter((n) => n.endsWith('.json'))) {
      try { cases[f.replace(/\.json$/, '')] = JSON.parse(readFileSync(join(casesDir, f), 'utf8')); }
      catch (e) { cases[f.replace(/\.json$/, '')] = { parseError: e.message }; }
    }
  }
  const agents = [];
  const agentsDir = join(root, 'agents');
  if (existsSync(agentsDir)) {
    for (const f of readdirSync(agentsDir).filter((n) => n.endsWith('.md'))) {
      const file = join(agentsDir, f);
      const fm = parseFrontmatter(readFileSync(file, 'utf8'));
      agents.push({ name: fm.data.name, base: f.replace(/\.md$/, ''), file, data: fm.data, body: fm.body, error: fm.error });
    }
  }
  const exFile = join(root, 'scripts', 'lint-exemptions.json');
  const exemptions = existsSync(exFile) ? JSON.parse(readFileSync(exFile, 'utf8')) : [];
  const shipped = SHIPPED_DIRS.flatMap((d) => walk(join(root, d)));
  return { root, skills, agents, exemptions, shipped, kernelText, cases };
}

export const err = (rule, path, message) => ({ rule, path, level: 'error', message });
export const warn = (rule, path, message) => ({ rule, path, level: 'warn', message });

export const RULES = [
  { id: 1, check(model) {
    const out = [];
    for (const s of model.skills) {
      const p = rel(model, s.file);
      if (s.error) { out.push(err(1, p, s.error)); continue; }
      if (!KEBAB.test(s.dir)) out.push(err(1, p, `directory ${s.dir} is not kebab case`));
      else if (s.name !== s.dir) out.push(err(1, p, `name ${s.name} does not equal directory ${s.dir}`));
    }
    for (const a of model.agents) {
      const p = rel(model, a.file);
      if (a.error) { out.push(err(1, p, a.error)); continue; }
      if (a.name !== a.base) out.push(err(1, p, `name ${a.name} does not equal file name ${a.base}`));
    }
    return out;
  } },
  { id: 2, check(model) {
    const out = [];
    for (const s of model.skills) {
      for (const k of Object.keys(s.data)) if (!SKILL_KEYS.has(k)) out.push(err(2, rel(model, s.file), `unknown frontmatter key ${k}`));
    }
    for (const a of model.agents) {
      for (const k of Object.keys(a.data)) {
        if (AGENT_KEYS_IGNORED_IN_PLUGINS.has(k)) out.push(err(2, rel(model, a.file), `${k} is ignored for plugin agents; use tools, disallowedTools and kern guards`));
        else if (!AGENT_KEYS.has(k)) out.push(err(2, rel(model, a.file), `unknown agent key ${k}`));
      }
    }
    return out;
  } },
  { id: 3, check(model) {
    const out = [];
    let autoTotal = 0;
    let agentTotal = 0;
    for (const s of model.skills) {
      if (s.error) continue;
      const d = s.data.description || '';
      const p = rel(model, s.file);
      if (!d) { out.push(err(3, p, 'description missing')); continue; }
      if (s.tier === 'auto') {
        autoTotal += d.length;
        if (d.length > LIMITS.auto) out.push(err(3, p, `auto description ${d.length} chars, limit ${LIMITS.auto}`));
        if (!TRIGGER.test(d)) out.push(err(3, p, 'auto description needs a trigger such as "Use when" or "Use before"'));
      } else if (d.length > LIMITS.manual) out.push(err(3, p, `description ${d.length} chars, limit ${LIMITS.manual}`));
    }
    for (const a of model.agents) {
      const d = a.data.description || '';
      agentTotal += d.length;
      if (d.length > LIMITS.agent) out.push(err(3, rel(model, a.file), `agent description ${d.length} chars, limit ${LIMITS.agent}`));
    }
    if (autoTotal > LIMITS.autoTotal) out.push(err(3, 'skills', `auto descriptions total ${autoTotal} chars, limit ${LIMITS.autoTotal}`));
    if (autoTotal + agentTotal > LIMITS.autoPlusAgents) out.push(err(3, 'skills', `auto plus agent descriptions total ${autoTotal + agentTotal} chars, limit ${LIMITS.autoPlusAgents}`));
    return out;
  } },
  { id: 4, check(model) {
    const out = [];
    for (const s of model.skills) {
      const p = rel(model, s.file);
      const local = [...s.body.matchAll(/`(?:\.\/)?((?:references|templates|scripts|prompts)\/[\w./-]+)(?:#[^`\s]*)?`|\]\((?:\.\/)?((?:references|templates|scripts|prompts)\/[\w./-]+)(?:#[^)\s]*)?\)/g)].map((m) => m[1] || m[2]);
      for (const r of local) if (!existsSync(join(model.root, 'skills', s.dir, r)) && !existsSync(join(model.root, r))) out.push(err(4, p, `referenced file missing: ${r}`));
      const rooted = [...s.body.matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/([\w./-]+)/g)].map((m) => m[1].replace(/[.,;:]+$/, ''));
      for (const r of rooted) if (!existsSync(join(model.root, r))) out.push(err(4, p, `referenced file missing: \${CLAUDE_PLUGIN_ROOT}/${r}`));
    }
    return out;
  } },
  { id: 8, check(model) {
    const out = [];
    const names = (process.env.KERN_LINT_NAMES || '').split(',').map((n) => n.trim()).filter(Boolean);
    for (const f of ['.lint-names', 'scripts/lint-names.txt']) {
      const namesFile = join(model.root, f);
      if (existsSync(namesFile)) names.push(...readFileSync(namesFile, 'utf8').split('\n').map((n) => n.trim()).filter((n) => n && !n.startsWith('#')));
    }
    const nameRes = names.map((n) => new RegExp(`\\b${n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i'));
    for (const f of model.shipped) {
      const text = readFileSync(f, 'utf8');
      const p = rel(model, f);
      if (MACHINE_PATH.test(text)) out.push(err(8, p, 'machine-specific path'));
      for (const re of nameRes) if (re.test(text)) out.push(err(8, p, `personal name matches ${re.source}`));
    }
    return out;
  } },
  { id: 10, check(model) {
    return model.exemptions.filter((e) => !e.reason || !String(e.reason).trim()).map((e) => err(10, 'scripts/lint-exemptions.json', `exemption for rule ${e.rule} on ${e.path} has no reason`));
  } },
  { id: 11, check(model) {
    const out = [];
    const files = [...model.shipped.filter((f) => !BINARY_EXT.test(f)), ...['README.md', 'CHANGELOG.md'].map((n) => join(model.root, n)).filter((f) => existsSync(f))];
    for (const f of files) {
      const text = readFileSync(f, 'utf8');
      const p = rel(model, f);
      if ((text.match(LONG_DASH) || []).length) out.push(err(11, p, 'long dash; use a period or a comma'));
      if ((text.match(CURLY) || []).length) out.push(err(11, p, 'curly quotes; use straight quotes'));
    }
    return out;
  } },
];

export function runLint(model) {
  const findings = RULES.flatMap((r) => r.check(model));
  const valid = model.exemptions.filter((e) => e.reason && String(e.reason).trim());
  return findings.filter((f) => f.rule === 10 || !valid.some((e) => e.rule === f.rule && e.path === f.path));
}
