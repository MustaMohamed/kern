// Kernel routing rows: "| <when> | Read {KERN}/<skill>/SKILL.md |" or "| <when> | Read {ROOT}/kernel/<name>.md |".
// The rows live in kernel/kernel.md and in kernel/routes.md, the routed file the kernel points to. Lint rule 6, rule 12,
// the path tier and route-eval all read rows through parseRow, so they agree on which lines are rows.
const ROW = /^\|([^|\n]*)\|\s*Read \{(KERN|ROOT)\}\/([^\s|]+)\s*\|\s*$/;

// parseRow(line): null for a line that is not a route row, { error } for a row in another form, else
// { when, base, path, route }. route is the skill or kernel file name, or null for a target with no route name.
export function parseRow(line) {
  if (!line.trimStart().startsWith('|') || !/\{(KERN|ROOT)\}\//.test(line)) return null;
  const m = line.match(ROW);
  if (!m) return { error: `a route row must end in a bare Read {KERN}/<path> or Read {ROOT}/<path> cell: ${line.trim()}` };
  const [, when, base, path] = m;
  if (base === 'ROOT' && path === 'kernel/routes.md') return { error: 'kernel/routes.md is named in the Routing rule, not routed by a row' };
  const name = base === 'KERN' ? path.match(/^([a-z0-9-]+)\/SKILL\.md$/) : path.match(/^kernel\/([a-z0-9-]+)\.md$/);
  return { when: when.trim(), base, path, route: name ? name[1] : null };
}

// A row in another form ({ error }) has no route, so it never counts as a row.
const routeRows = (text) => (text || '').split(/\r?\n/).map(parseRow).filter((r) => r && r.route);

export const kernelRows = (text) => routeRows(text).map((r) => ({ when: r.when, route: r.route }));

// routedSkills(text): the skills a row routes to by {KERN}; a Read in prose routes nothing.
export const routedSkills = (text) => new Set(routeRows(text).filter((r) => r.base === 'KERN').map((r) => r.route));

// routeText(model): the kernel and its routed file, joined; every check that reads rows reads this.
export const routeText = (model) => `${model.kernelText}\n${model.routesText || ''}`;
