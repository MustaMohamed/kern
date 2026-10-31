import { readFileSync } from 'node:fs';

export const totals = () => JSON.parse(readFileSync('data/invoices.json', 'utf8')).map((invoice) => invoice.total);
