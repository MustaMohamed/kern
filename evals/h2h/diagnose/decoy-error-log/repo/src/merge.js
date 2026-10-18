import { push } from './metrics.js';

export async function mergeCustomers(a, b) {
  const byId = new Map();
  for (const c of [...a, ...b]) {
    if (!c.id) continue;
    byId.set(c.id, { ...byId.get(c.id), ...c });
    await push('customer.merged');
  }
  return [...byId.values()];
}
