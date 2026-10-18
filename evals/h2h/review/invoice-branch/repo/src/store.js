const invoices = new Map();

export function save(invoice) {
  invoices.set(invoice.id, structuredClone(invoice));
  return invoice.id;
}

export function load(id) {
  const invoice = invoices.get(id);
  if (!invoice) throw new Error(`invoice ${id} not found`);
  return structuredClone(invoice);
}
