// money(cents): an amount in cents as the decimal string an invoice prints, two places.
export const money = (cents) => (cents / 10).toFixed(2);
