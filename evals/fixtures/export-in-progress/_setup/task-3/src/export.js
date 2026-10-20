// toCsv(rows): CSV text, a header line from the first row's keys, then one line per row. A value
// holding a comma or a quote is quoted, each quote inside it doubled. No rows give an empty string.
const cell = (value) => {
  const s = String(value);
  return /[",]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

export const toCsv = (rows) => {
  if (!rows) return '';
  const keys = Object.keys(rows[0]);
  return [keys, ...rows.map((row) => keys.map((k) => row[k]))].map((line) => line.map(cell).join(',')).join('\n') + '\n';
};
