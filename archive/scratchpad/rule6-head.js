  { id: 6, check(model) {
    const out = [];
    const sources = [['kernel/kernel.md', model.kernelText], ['kernel/routes.md', model.routesText]];
    if (kernelRows(model.routesText).length && !model.kernelText.includes('{ROOT}/kernel/routes.md')) {
      out.push(err(6, 'kernel/kernel.md', 'kernel/routes.md holds route rows, but the kernel never names {ROOT}/kernel/routes.md, so no route there is reached'));
    }
    for (const [src, text] of sources) for (const line of text.split('\n')) {
      if (!line.trimStart().startsWith('|') || !/\{(KERN|ROOT)\}\//.test(line)) continue;
      const m = line.match(/^\|[^|\n]*\|\s*Read \{(KERN|ROOT)\}\/([^\s|]+)\s*\|\s*$/);
      if (!m) { out.push(err(6, src, `a route row must end in a bare Read {KERN}/<path> or Read {ROOT}/<path> cell: ${line.trim()}`)); continue; }
      const target = m[1] === 'KERN' ? join('skills', m[2]) : m[2];
      if (target === 'kernel/routes.md') { out.push(err(6, src, 'kernel/routes.md is named in the Routing rule, not routed by a row')); continue; }
      const file = join(model.root, target);
      if (!existsSync(file)) { out.push(err(6, src, `route ${target} does not exist`)); continue; }
      const body = parseFrontmatter(readFileSync(file, 'utf8')).body.replace(/\r\n/g, '\n');
      const firstH2 = body.split('\n').find((l) => l.startsWith('## '));
      if (firstH2 !== '## Steps') out.push(err(6, target, 'a route file must open with ## Steps'));
      else if (!/^## Steps\n+\d+\. /m.test(body)) out.push(err(6, target, '## Steps must open with a numbered list'));
    }
