const SYMBOLS = { USD: '$', EUR: '€' };

export const formatCurrency = (amount, code) => `${SYMBOLS[code] ?? '?'}${amount.toFixed(2)}`;
