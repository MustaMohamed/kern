export function lineTotal(line) {
  return Math.round(line.qty * line.unitPrice * 100) / 100;
}

export function invoiceTotal(lines, taxRate) {
  const net = lines.reduce((sum, l) => sum + lineTotal(l), 0);
  return Math.round(net * (1 + taxRate) * 100) / 100;
}
