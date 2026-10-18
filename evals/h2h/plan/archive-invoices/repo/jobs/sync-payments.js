// Nightly: pulls settled payments from the processor and writes them back.
import { db } from '../src/db.js';

export function syncPayments(settled) {
  for (const p of settled) {
    db.run('UPDATE invoices SET status = ?, paid_at = ? WHERE id = ?', ['paid', p.settledAt, p.invoiceId]);
  }
}
