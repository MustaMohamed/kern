const cache = new Map();

export function lineTotal(sku, qty, unitPrice) {
  if (cache.has(sku)) return cache.get(sku);
  const total = Math.round(qty * unitPrice * 100) / 100;
  cache.set(sku, total);
  return total;
}
