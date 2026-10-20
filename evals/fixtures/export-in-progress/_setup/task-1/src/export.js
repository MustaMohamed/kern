// toCsv(rows): CSV text, a header line from the first row's keys, then one line per row.
export const toCsv = (rows) => {
  const keys = Object.keys(rows[0]);
  return [keys, ...rows.map((row) => keys.map((k) => row[k]))].map((line) => line.join(',')).join('\n') + '\n';
};
