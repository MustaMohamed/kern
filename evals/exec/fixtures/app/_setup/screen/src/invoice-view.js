// The invoice screen: the HTML the app shows for one invoice.
export const invoiceView = (invoice) => [
  '<main class="invoice">',
  `  <h1>Invoice ${invoice.id}</h1>`,
  `  <p class="total">Total: ${invoice.total}</p>`,
  '</main>',
].join('\n');
