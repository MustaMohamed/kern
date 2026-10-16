  { id: 5, check(model) {
    const BUILTIN_SKILLS = new Set(['code-review', 'security-review', 'simplify']);
    const out = [];
    const auto = new Set(model.skills.filter((s) => s.tier === 'auto').map((s) => s.name));
    const docs = [...model.skills, ...model.agents].filter((d) => !d.error).map((d) => ({ file: d.file, body: d.body }));
    if (model.kernelText) docs.push({ file: join(model.root, 'kernel', 'kernel.md'), body: model.kernelText });
    if (model.routesText) docs.push({ file: join(model.root, 'kernel', 'routes.md'), body: model.routesText });
    for (const d of docs) {
      for (const m of d.body.matchAll(/Skill tool with `([a-z0-9:-]+)`/g)) {
        const name = m[1].replace(/^kern:/, '');
        if (!auto.has(name) && !BUILTIN_SKILLS.has(name)) {
          out.push(err(5, rel(model, d.file), `Skill tool reference "${m[1]}" names neither a kern auto skill nor a built-in skill; path and slash skills are reached by Read or typed by the user`));
        }
      }
    }
    for (const a of model.agents.filter((x) => !x.error)) {
      for (const m of a.body.matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/([\w./-]+)/g)) {
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
    const h2 = (body) => {
      let fence = false;
      return body.split('\n').filter((l) => {
        if (/^\s{0,3}(```|~~~)/.test(l)) { fence = !fence; return false; }
        return !fence && /^## /.test(l);
      }).map((l) => l.trim());
    };
    const section = (body, heading) => {
      const lines = body.split('\n');
      const i = lines.findIndex((l) => l.trim() === heading);
      if (i < 0) return '';
      const rest = [];
      for (const l of lines.slice(i + 1)) { if (/^## /.test(l)) break; rest.push(l); }
      return rest.join('\n');
    };
    for (const s of model.skills.filter((x) => !x.error)) {
      const heads = h2(s.body);
      const p = rel(model, s.file);
      if (DISCIPLINE.has(s.name)) {
        const rows = section(s.body, '## Red flags').split('\n').filter((l) => /^\|/.test(l));
        if (!heads.includes('## Red flags')) out.push(err(9, p, 'discipline skill has no "## Red flags" section'));
        else if (rows[0]?.replace(/\s/g, '') !== '|Thought|Reality|' || rows.length - 2 < 2 || rows.length - 2 > 6) out.push(err(9, p, '"## Red flags" needs a | Thought | Reality | table of 2 to 6 rows'));
      }
      if (s.tier === 'path') continue; // rule 6 (M1) checks that route files open with ## Steps
      if (s.tier === 'auto') {
        if (!heads.includes('## Steps')) out.push(err(9, p, 'auto skill has no "## Steps" section'));
      } else if (heads[0] !== '## Steps') {
        out.push(err(9, p, heads.includes('## Steps') ? '"## Steps" must be the first H2 of a slash skill' : 'slash skill has no "## Steps" section; add one or record a rule-9 exemption with a reason'));
      }
    }
    for (const a of model.agents.filter((x) => !x.error)) {
      if (!h2(a.body).some((h) => /^## (Report|Output|Return|Status)\b/.test(h))) {
        out.push(err(9, rel(model, a.file), 'agent has no output contract section (## Report, ## Output, ## Return or ## Status)'));
      }
    }
    return out;
  } },
  { id: 16, check(model) {
    // Contract drift: every script, WORK subfolder and ledger line a shipped skill or agent names has its
    // producer in docs/plans/contract.md (adapted from addy scripts/validate-artifact-paths.js, MIT).
    const cf = join(model.root, 'docs', 'plans', 'contract.md');
    if (!existsSync(cf)) return [];
    const contract = readFileSync(cf, 'utf8');
    const out = [];
    const files = [...model.skills, ...model.agents].filter((d) => !d.error).map((d) => d.file);
    for (const s of model.skills) files.push(...walk(join(model.root, 'skills', s.dir, 'references')).filter((f) => f.endsWith('.md')));
    const seen = new Set();
    for (const f of files) {
      const text = readFileSync(f, 'utf8');
      const p = rel(model, f);
      const flag = (token, why) => { if (!seen.has(`${p}\0${token}`)) { seen.add(`${p}\0${token}`); out.push(err(16, p, `${token}: ${why}`)); } };
      for (const m of text.matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/scripts\/([a-z0-9-]+)/g)) {
        if (!contract.includes(`| \`${m[1]}\` |`)) flag(`scripts/${m[1]}`, 'no row in the Scripts table of docs/plans/contract.md');
      }
      for (const m of text.matchAll(/\bWORK\/([a-z]+)/g)) {
        if (!contract.includes(`\`WORK/${m[1]}/\``)) flag(`WORK/${m[1]}`, 'not listed under "Working directory" in docs/plans/contract.md');
      }
      for (const m of text.matchAll(/`((?:Task N|parked|Decision|Worktree|Main|Wave|Applied|Preflight):[^`]*)`/g)) {
        if (!contract.includes(`\`${m[1]}\``)) flag(m[1], 'ledger line format not in docs/plans/contract.md');
      }
    }
    return out;
  } },
