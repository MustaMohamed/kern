import { listInvoices } from './invoices.js';

export async function sendDueReminders() {
  const today = Date.now();
  for (const inv of listInvoices()) {
    if (inv.status === 'open' && new Date(inv.dueAt).getTime() < today) {
      await fetch('https://mail.internal/send', { method: 'POST', body: JSON.stringify({ to: inv.email, template: 'overdue' }) });
    }
  }
}
