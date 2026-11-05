import { readFileSync } from 'node:fs';

// The invoice screen: the page views/invoice.html, filled in for one invoice.
const PAGE = readFileSync(new URL('../views/invoice.html', import.meta.url), 'utf8');

// fill(text, name, value): text with every {{name}} replaced by value.
const fill = (text, name, value) => text.split(`{{${name}}}`).join(value);

export const invoiceView = (invoice) => fill(fill(PAGE, 'id', String(invoice.id)), 'total', String(invoice.total));
