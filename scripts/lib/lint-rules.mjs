// kern lint rules (design spec 11.2). Pure checks over a loaded model; the CLI is scripts/lint-skills.mjs.
// Rule set informed by addyosmani/agent-skills scripts/lib/skill-lint.js (MIT); the code is written for kern.
import { readFileSync, readdirSync, existsSync, statSync, mkdtempSync, mkdirSync, copyFileSync, rmSync } from 'node:fs';
import { join, relative } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
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
  { id: 6, check(model) {
    const out = [];
    for (const line of model.kernelText.split('\n')) {
      if (!line.trimStart().startsWith('|') || !/\{(KERN|ROOT)\}\//.test(line)) continue;
      const m = line.match(/^\|[^|\n]*\|\s*Read \{(KERN|ROOT)\}\/([^\s|]+)\s*\|\s*$/);
      if (!m) { out.push(err(6, 'kernel/kernel.md', `a route row must end in a bare Read {KERN}/<path> or Read {ROOT}/<path> cell: ${line.trim()}`)); continue; }
      const target = m[1] === 'KERN' ? join('skills', m[2]) : m[2];
      const file = join(model.root, target);
      if (!existsSync(file)) { out.push(err(6, 'kernel/kernel.md', `route ${target} does not exist`)); continue; }
      const body = parseFrontmatter(readFileSync(file, 'utf8')).body.replace(/\r\n/g, '\n');
      const firstH2 = body.split('\n').find((l) => l.startsWith('## '));
      if (firstH2 !== '## Steps') out.push(err(6, target, 'a route file must open with ## Steps'));
      else if (!/^## Steps\n+\d+\. /m.test(body)) out.push(err(6, target, '## Steps must open with a numbered list'));
    }
    const mapFile = join(model.root, 'skills', 'help', 'references', 'map.md');
    if (existsSync(mapFile)) {
      const listed = new Set([...readFileSync(mapFile, 'utf8').matchAll(/^\| `([a-z0-9-]+)` \|/gm)].map((m) => m[1]));
      for (const s of model.skills) {
        if (s.data['user-invocable'] === 'false') continue;
        if (!listed.has(s.name)) out.push(err(6, rel(model, s.file), `${s.name} is missing from skills/help/references/map.md`));
      }
    }
    return out;
  } },
  { id: 7, check(model) {
    if (!existsSync(join(model.root, 'hooks', 'session-start'))) return [];
    const out = [];
    const tmp = mkdtempSync(join(tmpdir(), 'kern-rule7-'));
    try {
      const repo = join(tmp, 'repo');
      mkdirSync(join(repo, '.claude'), { recursive: true });
      spawnSync('git', ['init', '-q', repo]);
      const fixture = join(model.root, 'tests', 'fixtures', 'projects', 'long-settings');
      for (const f of ['kern.local.yml', 'kern.yml']) if (existsSync(join(fixture, f))) copyFileSync(join(fixture, f), join(repo, '.claude', f));
      const env = { ...process.env, HOME: join(tmp, 'home'), CLAUDE_PLUGIN_DATA: join(tmp, 'data') };
      const run = (name, payload) => spawnSync('bash', [join(model.root, 'hooks', name)], { input: JSON.stringify(payload), env, encoding: 'utf8' });
      const hook = (name, payload) => run(name, payload).stdout || '';
      const norm = (s) => s.split(model.root).join('/Users/someone/.claude/plugins/cache/kern/kern/0.1.0');
      const start = run('session-start', { session_id: 'lint', source: 'startup', cwd: repo, hook_event_name: 'SessionStart' });
      if (start.status !== 0 || !(start.stdout || '').trim()) out.push(err(7, 'hooks/session-start', `exited ${start.status} with ${(start.stdout || '').length} chars of output, so the kernel was not measured`));
      const kernel = norm(start.stdout || '');
      const terse = existsSync(join(model.root, 'modes', 'terse.md')) ? readFileSync(join(model.root, 'modes', 'terse.md'), 'utf8').length : 0;
      if (kernel.length > 4000) out.push(warn(7, 'kernel/kernel.md', `rendered kernel ${kernel.length} chars with the longest fixture settings, target 4,000`));
      if (kernel.length + terse > 9000) out.push(err(7, 'kernel/kernel.md', `rendered kernel plus terse rules ${kernel.length + terse} chars, limit 9,000`));
      const sub = hook('subagent-start', { session_id: 'lint', cwd: repo, hook_event_name: 'SubagentStart', agent_id: 'a', agent_type: 'Explore' });
      let ctx = '';
      try { ctx = norm(JSON.parse(sub).hookSpecificOutput.additionalContext); } catch { out.push(err(7, 'hooks/subagent-start', 'output is not SubagentStart JSON')); }
      const terseSub = existsSync(join(model.root, 'modes', 'terse-subagent.md')) ? readFileSync(join(model.root, 'modes', 'terse-subagent.md'), 'utf8').length : 0;
      if (ctx.length + terseSub > 1200) out.push(err(7, 'kernel/kernel-subagent.md', `subagent kernel with terse voice ${ctx.length + terseSub} chars, limit 1,200`));
      return out;
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  } },
  { id: 13, check(model) {
    const table = join(model.root, 'kernel', 'settings.md');
    if (!existsSync(table)) return [];
    const out = [];
    const rows = readFileSync(table, 'utf8').split('\n').filter((l) => /^\| `/.test(l)).map((l) => {
      const cells = l.split('|').slice(1, -1).map((c) => c.trim());
      return { key: cells[0].replace(/`/g, ''), readBy: cells[cells.length - 1] };
    });
    const prefix = (k) => (k.includes('<') ? k.slice(0, k.indexOf('<')) : null);
    const known = (k) => rows.some((r) => r.key === k || (prefix(r.key) && k.startsWith(prefix(r.key))));
    const code = [...walk(join(model.root, 'hooks')), ...walk(join(model.root, 'scripts')).filter((f) => /\/kern-[a-z]+$/.test(f))]
      .map((f) => ({ f, text: readFileSync(f, 'utf8') }));
    const read = new Map();
    const add = (k, f) => { if (!read.has(k)) read.set(k, f); };
    for (const { f, text } of code) {
      // A hook's `need LIB FUNCTION...` line names the functions a library must define; it calls none.
      const calls = text.replace(/^need .*$/gm, '');
      for (const m of calls.matchAll(/(?:settings_(?:get|source)|_settings_lookup\s+"?\$\w+"?)\s+["']?([a-z_][a-z0-9_.]*)/g)) add(m[1], f);
      for (const m of calls.matchAll(/policy_for\s+["']?([a-z][a-z.]*)/g)) if (m[1] !== 'ACTION') add(m[1] === 'review.post' ? 'review.post_policy' : `${m[1]}.policy`, f);
      if (/policy_for\s+["']?\$/.test(calls)) out.push(err(13, rel(model, f), 'policy_for takes a variable, so rule 13 cannot check its key; pass the action literally'));
      if (f.endsWith('/kern-detect')) for (const m of text.matchAll(/^ {2}([a-z_.]+)\)$/gm)) add(m[1], f);
    }
    for (const [k, f] of read) if (!known(k)) out.push(err(13, rel(model, f), `reads settings key ${k}, which kernel/settings.md does not list`));
    const hookReader = /session-start|subagent-start|prompt-submit|pre-tool-use|kern-detect|kern-dir|kern-get/;
    const allCode = code.map((c) => c.text).join('\n');
    for (const r of rows) {
      if (!hookReader.test(r.readBy)) continue;
      const ok = prefix(r.key) ? allCode.includes(prefix(r.key)) : read.has(r.key);
      if (!ok) out.push(err(13, 'kernel/settings.md', `${r.key} names a hook or kern script as reader, but none reads it`));
    }
    return out;
  } },
  { id: 15, check(model) {
    if (!existsSync(join(model.root, 'hooks', 'session-start'))) return [];
    const out = [];
    for (const c of ['no-settings', 'shared-only', 'local-only', 'both', 'kern-off', 'floor-policy-key', 'unknown-key', 'long-settings']) {
      const dir = join(model.root, 'tests', 'fixtures', 'projects', c);
      if (!existsSync(join(dir, 'expect.txt'))) out.push(err(15, `tests/fixtures/projects/${c}`, 'hook-shape fixture has no expect.txt'));
      if (c !== 'no-settings' && !['kern.local.yml', 'kern.yml'].some((f) => existsSync(join(dir, f)))) out.push(err(15, `tests/fixtures/projects/${c}`, 'hook-shape fixture has no kern.local.yml or kern.yml'));
    }
    if (!existsSync(join(model.root, 'tests', 'hook-shape.sh'))) out.push(err(15, 'tests/hook-shape.sh', 'hook-shape runner missing'));
    return out;
  } },
];

export function runLint(model) {
  const findings = RULES.flatMap((r) => r.check(model));
  const valid = model.exemptions.filter((e) => e.reason && String(e.reason).trim());
  return findings.filter((f) => f.rule === 10 || !valid.some((e) => e.rule === f.rule && e.path === f.path));
}
