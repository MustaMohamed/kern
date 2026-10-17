import { lineTotal } from './pricing.js';

export const cartTotal = (lines) => lines.reduce((sum, l) => sum + lineTotal(l.sku, l.qty, l.price), 0);
