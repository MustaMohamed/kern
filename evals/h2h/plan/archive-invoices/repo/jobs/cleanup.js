// Weekly: removes invoices that finance has written off for more than two years.
import { db } from '../src/db.js';

export function cleanup(now = new Date()) {
  const cutoff = new Date(now.getTime() - 2 * 365 * 24 * 3600 * 1000).toISOString();
  return db.run("DELETE FROM invoices WHERE status IN ('paid', 'void') AND paid_at < ?", [cutoff]);
}
