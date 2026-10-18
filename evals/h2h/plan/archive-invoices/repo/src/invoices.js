import { db } from './db.js';

export function listInvoices() {
  return db.all('SELECT * FROM invoices ORDER BY paid_at DESC');
}

export function markPaid(id, at = new Date()) {
  return db.run('UPDATE invoices SET status = ?, paid_at = ? WHERE id = ?', ['paid', at.toISOString(), id]);
}
