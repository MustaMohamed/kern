// Minimal frontmatter reader for kern files: single-line `key: value` pairs only.
export function parseFrontmatter(src) {
  const text = src.replace(/\r\n/g, '\n');
  const m = text.match(/^---\n([\s\S]*?)\n---[ \t]*(?:\n|$)/);
  if (!m) return { data: {}, body: text, error: 'no frontmatter block' };
  const data = {};
  for (const line of m[1].split('\n')) {
    if (!line.trim() || line.trimStart().startsWith('#')) continue;
    const kv = line.match(/^([A-Za-z][A-Za-z0-9_-]*):[ \t]*(.*)$/);
    if (!kv) return { data, body: text.slice(m[0].length), error: `unparsed frontmatter line (use single-line values): ${line}` };
    let value = kv[2].trim();
    if (value === '>' || value === '|' || value === '>-' || value === '|-') {
      return { data, body: text.slice(m[0].length), error: `key ${kv[1]} uses a block scalar; use single-line values` };
    }
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
    data[kv[1]] = value;
  }
  return { data, body: text.slice(m[0].length), error: null };
}
