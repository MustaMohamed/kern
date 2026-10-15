// Kernel routing rows: "| <when> | Read {KERN}/<skill>/SKILL.md |" or "| <when> | Read {ROOT}/kernel/<name>.md |".
// The rows live in kernel/kernel.md and in kernel/routes.md, the routed file the kernel points to.
export function kernelRows(text) {
  const rows = [];
  for (const line of (text || '').split(/\r?\n/)) {
    const m = line.match(/^\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*$/);
    if (!m) continue;
    const target = m[2].match(/\{KERN\}\/([a-z0-9-]+)\/SKILL\.md/) || m[2].match(/kernel\/([a-z0-9-]+)\.md/);
    if (target) rows.push({ when: m[1], route: target[1] });
  }
  return rows;
}

// routeText(model): the kernel and its routed file, joined; every check that reads rows reads this.
export const routeText = (model) => `${model.kernelText}\n${model.routesText || ''}`;
