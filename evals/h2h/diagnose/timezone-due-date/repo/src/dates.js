const pad = (n) => String(n).padStart(2, '0');

export function dueLabel(iso) {
  const d = new Date(iso);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
