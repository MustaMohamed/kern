// kern lint rules (design spec 11.2). Pure checks over a loaded model; the CLI is scripts/lint-skills.mjs.
// Rule set informed by addyosmani/agent-skills scripts/lib/skill-lint.js (MIT); the code is written for kern.
import { readFileSync, readdirSync, existsSync, statSync, mkdtempSync, mkdirSync, copyFileSync, rmSync, realpathSync } from 'node:fs';
import { join, relative } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { parseFrontmatter } from './frontmatter.mjs';
import { kernelRows, parseRow, routedSkills } from './kernel-rows.mjs';

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

// Markdown scan for heading structure (rule 9; rule 16 uses it only to report an unclosed fence in a reference):
// normalizes CRLF and blanks fenced lines (``` and ~~~), so a heading inside a code example is not read as real.
// Rules 5 and 16 do not scan with it: they read fenced text too, because skills keep script calls in fences.
// `unclosed` is true when a fence is left open; callers report it instead of treating the rest as scanned.
function scanMarkdown(text) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  let open = null;
  const kept = lines.map((l) => {
    const m = l.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);
    if (open) {
      if (m && m[1][0] === open[0] && m[1].length >= open.length && !m[2].trim()) open = null;
      return '';
    }
    if (m) { open = m[1]; return ''; }
    return l;
  });
  return { lines: kept, text: kept.join('\n'), unclosed: open !== null };
}
const h2Lines = (scan) => scan.lines.filter((l) => /^## /.test(l)).map((l) => l.trimEnd());

// Rule 7 renders the kernel in a repo whose real path has one fixed length: the settings block names the
// main worktree and keeps to 600 chars, so a longer path drops a Set: entry, and the measurement would
// move with the machine's temp dir.
export const RULE7_REPO_LEN = 120;
export function fixedLengthRepo(tmp) {
  const real = realpathSync(tmp);
  return join(real, 'r'.repeat(Math.max(1, RULE7_REPO_LEN - real.length - 1)));
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
  const routesPath = join(root, 'kernel', 'routes.md');
  const routesText = existsSync(routesPath) ? readFileSync(routesPath, 'utf8') : '';
  const routed = routedSkills(`${kernelText}\n${routesText}`);
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
  return { root, skills, agents, exemptions, shipped, kernelText, routesText, cases };
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
    const sources = [['kernel/kernel.md', model.kernelText], ['kernel/routes.md', model.routesText]];
    if (kernelRows(model.routesText).length && !model.kernelText.includes('{ROOT}/kernel/routes.md')) {
      out.push(err(6, 'kernel/kernel.md', 'kernel/routes.md holds route rows, but the kernel never names {ROOT}/kernel/routes.md, so no route there is reached'));
    }
    for (const [src, text] of sources) for (const line of text.split('\n')) {
      const row = parseRow(line);
      if (!row) continue;
      if (row.error) { out.push(err(6, src, row.error)); continue; }
      const target = row.base === 'KERN' ? join('skills', row.path) : row.path;
      const file = join(model.root, target);
      if (!existsSync(file)) { out.push(err(6, src, `route ${target} does not exist`)); continue; }
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
    const out = [];
    if (model.routesText.length > 1500) out.push(err(7, 'kernel/routes.md', `routed file ${model.routesText.length} chars, limit 1,500; every routed task reads it`));
    if (!existsSync(join(model.root, 'hooks', 'session-start'))) return out;
    const fixture = join(model.root, 'tests', 'fixtures', 'projects', 'long-settings');
    const settings = ['kern.local.yml', 'kern.yml'].filter((f) => existsSync(join(fixture, f)));
    if (!settings.length) out.push(err(7, 'tests/fixtures/projects/long-settings', 'no kern.local.yml or kern.yml, so the longest-settings render would be measured with defaults'));
    const tmp = mkdtempSync(join(tmpdir(), 'kern-rule7-'));
    try {
      const repo = fixedLengthRepo(tmp);
      mkdirSync(join(repo, '.claude'), { recursive: true });
      const init = spawnSync('git', ['init', '-q', repo]);
      if (init.status !== 0) out.push(err(7, 'hooks/session-start', `git init exited ${init.status}, so the kernel was not measured in a repository`));
      for (const f of settings) copyFileSync(join(fixture, f), join(repo, '.claude', f));
      const env = { ...process.env, HOME: join(tmp, 'home'), CLAUDE_PLUGIN_DATA: join(tmp, 'data') };
      const run = (name, payload) => spawnSync('bash', [join(model.root, 'hooks', name)], { input: JSON.stringify(payload), env, encoding: 'utf8' });
      const hook = (name, payload) => run(name, payload).stdout || '';
      const norm = (s) => s.split(model.root).join('/Users/someone/.claude/plugins/cache/kern/kern/0.1.0');
      // A render is the kernel only when it exits 0 and carries the header line that defines {ROOT}. "kern did not
      // load", or any other output, is not a kernel, and its length is not a measurement.
      const header = `kern at ${model.root}. `;
      const rendered = (r) => r.status === 0 && (r.stdout || '').split('\n').some((l) => l.startsWith(header));
      const failed = (r) => `exited ${r.status} with ${(r.stdout || '').length} chars of output${r.status === 0 ? ' and no "kern at <root>." header line' : ''}`;
      const start = run('session-start', { session_id: 'lint', source: 'startup', cwd: repo, hook_event_name: 'SessionStart' });
      if (!rendered(start)) out.push(err(7, 'hooks/session-start', `${failed(start)}, so the kernel was not measured`));
      const kernel = norm(start.stdout || '');
      const terse = existsSync(join(model.root, 'modes', 'terse.md')) ? readFileSync(join(model.root, 'modes', 'terse.md'), 'utf8').length : 0;
      if (kernel.length > 4000) out.push(warn(7, 'kernel/kernel.md', `rendered kernel ${kernel.length} chars with the longest fixture settings, target 4,000`));
      if (kernel.length + terse > 9000) out.push(err(7, 'kernel/kernel.md', `rendered kernel plus terse rules ${kernel.length + terse} chars, limit 9,000`));
      // Standing cost (design goal 4): the kernel with no project settings, plus every auto skill and agent
      // description, the text every session carries.
      for (const f of ['kern.local.yml', 'kern.yml']) rmSync(join(repo, '.claude', f), { force: true });
      const again = run('session-start', { session_id: 'lint', source: 'startup', cwd: repo, hook_event_name: 'SessionStart' });
      if (rendered(start) && !rendered(again)) out.push(err(7, 'hooks/session-start', `${failed(again)} with no project settings, so the standing cost was not measured`));
      const bare = norm(again.stdout || '');
      const desc = [...model.skills.filter((s) => !s.error && s.tier === 'auto'), ...model.agents.filter((a) => !a.error)].reduce((n, d) => n + (d.data.description || '').length, 0);
      if (bare.length + desc > 4800) out.push(err(7, 'kernel/kernel.md', `standing cost ${bare.length + desc} chars (kernel with no settings ${bare.length}, auto and agent descriptions ${desc}), limit 4,800`));
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
  { id: 5, check(model) {
    const BUILTIN_SKILLS = new Set(['code-review', 'security-review', 'simplify']);
    const out = [];
    const auto = new Set(model.skills.filter((s) => s.tier === 'auto').map((s) => s.name));
    const docs = [...model.skills, ...model.agents].filter((d) => !d.error).map((d) => ({ file: d.file, body: d.body }));
    if (model.kernelText) docs.push({ file: join(model.root, 'kernel', 'kernel.md'), body: model.kernelText });
    if (model.routesText) docs.push({ file: join(model.root, 'kernel', 'routes.md'), body: model.routesText });
    for (const d of docs) {
      for (const m of d.body.replace(/\r\n/g, '\n').matchAll(/Skill tool with `([a-z0-9:-]+)`/g)) {
        const name = m[1].replace(/^kern:/, '');
        if (!auto.has(name) && !BUILTIN_SKILLS.has(name)) {
          out.push(err(5, rel(model, d.file), `Skill tool reference "${m[1]}" names neither a kern auto skill nor a built-in skill; path and slash skills are reached by Read or typed by the user`));
        }
      }
    }
    for (const a of model.agents.filter((x) => !x.error)) {
      for (const m of a.body.replace(/\r\n/g, '\n').matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/([\w./-]+)/g)) {
        const r = m[1].replace(/[.,;:]+$/, '');
        if (!existsSync(join(model.root, r))) out.push(err(5, rel(model, a.file), `Read path does not resolve: \${CLAUDE_PLUGIN_ROOT}/${r}`));
      }
    }
    return out;
  } },
  { id: 9, check(model) {
    // Discipline skills carry a ## Red flags table of 2 to 6 rows: the thought that skips a step, and why
    // it is wrong (design gap 7, the goal-0 review).
    const DISCIPLINE = new Set(['prove-it', 'implement', 'diagnose', 'define', 'execute-plan', 'commit', 'finish-branch']);
    const out = [];
    // Body lines of the first `heading` H2, up to the next H2; null when there is none.
    const section = (scan, heading) => {
      const i = scan.lines.findIndex((l) => l.trimEnd() === heading);
      if (i < 0) return null;
      const rest = [];
      for (const l of scan.lines.slice(i + 1)) { if (/^## /.test(l)) break; rest.push(l.trim()); }
      return rest;
    };
    const redFlagsProblem = (scan) => {
      const sec = section(scan, '## Red flags');
      if (!sec) return 'discipline skill has no "## Red flags" H2 section';
      const at = sec.findIndex((l) => l.replace(/\s/g, '') === '|Thought|Reality|');
      const bad = '"## Red flags" needs a | Thought | Reality | table of 2 to 6 rows';
      if (at < 0 || !/^\|[\s:|-]*-[\s:|-]*\|$/.test(sec[at + 1] || '')) return bad;
      let n = 0;
      while (/^\|/.test(sec[at + 2 + n] || '')) n++;
      return n < 2 || n > 6 ? `${bad}, found ${n}` : null;
    };
    for (const s of model.skills.filter((x) => !x.error)) {
      const scan = scanMarkdown(s.body);
      const heads = h2Lines(scan);
      const p = rel(model, s.file);
      if (scan.unclosed) out.push(err(9, p, 'unclosed code fence; the lines after it were not checked'));
      if (DISCIPLINE.has(s.name)) {
        const problem = redFlagsProblem(scan);
        if (problem) out.push(err(9, p, problem));
      }
      if (s.tier === 'path') continue; // rule 6 (M1) checks that route files open with ## Steps
      if (s.tier === 'auto') {
        if (!heads.includes('## Steps')) out.push(err(9, p, 'auto skill has no "## Steps" section'));
      } else if (heads[0] !== '## Steps') {
        out.push(err(9, p, heads.includes('## Steps') ? '"## Steps" must be the first H2 of a slash skill' : 'slash skill has no "## Steps" section; add one or record a rule-9 exemption with a reason'));
      }
    }
    for (const a of model.agents.filter((x) => !x.error)) {
      const scan = scanMarkdown(a.body);
      const p = rel(model, a.file);
      if (scan.unclosed) out.push(err(9, p, 'unclosed code fence; the lines after it were not checked'));
      if (!h2Lines(scan).some((h) => /^## (Report|Output|Return|Status)\b/.test(h))) {
        out.push(err(9, p, 'agent has no output contract section (## Report, ## Output, ## Return or ## Status)'));
      }
    }
    return out;
  } },
  { id: 16, check(model) {
    // Contract drift: every script, WORK subfolder and ledger line a shipped skill or agent names has its
    // producer in docs/plans/contract.md (adapted from addy scripts/validate-artifact-paths.js, MIT).
    const cf = join(model.root, 'docs', 'plans', 'contract.md');
    if (!existsSync(cf)) return [];
    const contract = readFileSync(cf, 'utf8').replace(/\r\n/g, '\n');
    const out = [];
    const docs = [...model.skills, ...model.agents].filter((d) => !d.error).map((d) => ({ file: d.file, body: d.body }));
    for (const s of model.skills) {
      for (const f of walk(join(model.root, 'skills', s.dir, 'references')).filter((x) => x.endsWith('.md'))) docs.push({ file: f, body: readFileSync(f, 'utf8'), ref: true });
    }
    const seen = new Set();
    for (const d of docs) {
      const scan = scanMarkdown(d.body);
      const text = d.body.replace(/\r\n/g, '\n'); // fenced blocks are read: skills keep their script calls there
      const p = rel(model, d.file);
      if (d.ref && scan.unclosed) out.push(err(16, p, 'unclosed code fence; the lines after it were not checked'));
      const flag = (token, why) => { if (!seen.has(`${p}\0${token}`)) { seen.add(`${p}\0${token}`); out.push(err(16, p, `${token}: ${why}`)); } };
      // The whole name after scripts/ or WORK/, up to whitespace, a quote, a bracket or a path break; trailing
      // sentence punctuation is not part of it. A name cut at the first odd character would match the wrong row.
      for (const m of text.matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/scripts\/([^\s`'"()<>|]+)/g)) {
        const name = m[1].replace(/[.,;:]+$/, '');
        if (!contract.includes(`| \`${name}\` |`)) flag(`scripts/${name}`, 'no row in the Scripts table of docs/plans/contract.md');
      }
      for (const m of text.matchAll(/\bWORK\/([^\s/`'"()<>|,;:]+)/g)) {
        const sub = m[1].replace(/\.+$/, '');
        if (sub && !contract.includes(`\`WORK/${sub}/\``)) flag(`WORK/${sub}`, 'not listed under "Working directory" in docs/plans/contract.md');
      }
      // `Task <N>:` is the same line as `Task N:`, the contract's spelling.
      for (const m of text.matchAll(/`((?:Task N|Task <N>|parked|Decision|Worktree|Main|Wave|Applied|Preflight):[^`]*)`/g)) {
        if (!contract.includes(`\`${m[1].replace(/^Task <N>:/, 'Task N:')}\``)) flag(m[1], 'ledger line format not in docs/plans/contract.md');
      }
    }
    return out;
  } },
  { id: 12, check(model) {
    if (!existsSync(join(model.root, 'evals', 'cases'))) return [];
    const out = [];
    const need = (key, path) => {
      const c = model.cases[key];
      if (!c) { out.push(err(12, path, `no eval cases: evals/cases/${key}.json`)); return; }
      if (c.parseError) { out.push(err(12, path, `evals/cases/${key}.json is not valid JSON: ${c.parseError}`)); return; }
      const pc = c.trigger?.positive?.length ?? 0;
      // A negative marked "grader": "model" is checked by M2b's model-graded runner, not here; it does not count.
      const nc = c.trigger?.negative?.filter((n) => n.grader !== 'model').length ?? 0;
      const ec = c.evals?.length ?? 0;
      const flagged = (c.trigger?.positive || []).filter((x) => x.grader !== undefined).length;
      if (flagged) out.push(err(12, path, `evals/cases/${key}.json has ${flagged} positive prompt(s) with "grader"; only a negative can be model-graded`));
      if (pc < 3 || nc < 2 || ec < 1) out.push(err(12, path, `evals/cases/${key}.json has ${pc} positive, ${nc} negative, ${ec} behavioural; needs 3, 2, 1`));
    };
    for (const s of model.skills.filter((x) => !x.error && x.tier === 'auto')) need(s.name, rel(model, s.file));
    for (const [src, text] of [['kernel/kernel.md', model.kernelText], ['kernel/routes.md', model.routesText]]) {
      for (const r of kernelRows(text)) need(`row-${r.route}`, src);
    }
    return out;
  } },
];

export function runLint(model) {
  const findings = RULES.flatMap((r) => r.check(model));
  const valid = model.exemptions.filter((e) => e.reason && String(e.reason).trim());
  return findings.filter((f) => f.rule === 10 || !valid.some((e) => e.rule === f.rule && e.path === f.path));
}
