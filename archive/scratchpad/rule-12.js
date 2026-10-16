  { id: 12, check(model) {
    if (!existsSync(join(model.root, 'evals', 'cases'))) return [];
    const out = [];
    const need = (key, path) => {
      const c = model.cases[key];
      if (!c) { out.push(err(12, path, `no eval cases: evals/cases/${key}.json`)); return; }
      if (c.parseError) return;
      const pc = c.trigger?.positive?.length ?? 0;
      const nc = c.trigger?.negative?.length ?? 0;
      const ec = c.evals?.length ?? 0;
      if (pc < 3 || nc < 2 || ec < 1) out.push(err(12, path, `evals/cases/${key}.json has ${pc} positive, ${nc} negative, ${ec} behavioural; needs 3, 2, 1`));
    };
    for (const s of model.skills.filter((x) => !x.error && x.tier === 'auto')) need(s.name, rel(model, s.file));
    for (const [src, text] of [['kernel/kernel.md', model.kernelText], ['kernel/routes.md', model.routesText]]) {
      for (const r of kernelRows(text)) need(`row-${r.route}`, src);
    }
    return out;
  } },
