export const DEFAULTS = { currency: 'USD', symbol: '$' };

export function formatPrice(amount, opts = {}) {
  const o = Object.assign(DEFAULTS, opts);
  return `${o.symbol}${amount.toFixed(2)}`;
}
