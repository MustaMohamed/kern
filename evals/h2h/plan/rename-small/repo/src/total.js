export const calcTotal = (lines) => lines.reduce((sum, l) => sum + l.qty * l.price, 0);
