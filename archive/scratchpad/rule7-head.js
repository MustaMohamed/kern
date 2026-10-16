  { id: 7, check(model) {
    const out = [];
    if (model.routesText.length > 1500) out.push(err(7, 'kernel/routes.md', `routed file ${model.routesText.length} chars, limit 1,500; every routed task reads it`));
    if (!existsSync(join(model.root, 'hooks', 'session-start'))) return out;
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
      // Standing cost (design goal 4): the kernel with no project settings, plus every auto skill and agent
      // description, the text every session carries.
      for (const f of ['kern.local.yml', 'kern.yml']) rmSync(join(repo, '.claude', f), { force: true });
      const bare = norm(run('session-start', { session_id: 'lint', source: 'startup', cwd: repo, hook_event_name: 'SessionStart' }).stdout || '');
      const desc = [...model.skills.filter((s) => !s.error && s.tier === 'auto'), ...model.agents.filter((a) => !a.error)].reduce((n, d) => n + (d.data.description || '').length, 0);
      if (bare.length + desc > 4800) out.push(err(7, 'kernel/kernel.md', `standing cost ${bare.length + desc} chars (kernel with no settings ${bare.length}, auto and agent descriptions ${desc}), limit 4,800`));
