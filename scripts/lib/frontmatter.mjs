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

// frontmatterYamlErrors(text): one message per frontmatter line that a strict YAML parser rejects and
// parseFrontmatter reads, since a host that parses frontmatter as YAML rejects the whole file: a tab in the
// indent, a quote that never closes, a top-level key set twice, and an unquoted value that opens with a YAML
// indicator or holds ": ". [] when there is no frontmatter block. Not a YAML parser: no kern frontmatter uses
// block scalars or multi-line values, and parseFrontmatter refuses them.
// Adapted from addyosmani/agent-skills scripts/lib/skill-lint.js lines 229-320 (MIT); the duplicate-key check is kern's.
export function frontmatterYamlErrors(text) {
  const m = text.replace(/\r\n/g, '\n').match(/^---[ \t]*\n([\s\S]*?)\n---[ \t]*(?:\n|$)/);
  if (!m) return [];
  const errors = [];
  const keys = new Map();
  m[1].split('\n').forEach((line, i) => {
    const n = i + 2; // the opening --- is line 1
    const at = `frontmatter line ${n}`;
    if (!line.trim() || /^\s*#/.test(line)) return;
    if (/^ *\t/.test(line)) {
      errors.push(`${at} indents with a tab; YAML forbids tabs in indentation, so a host that parses the frontmatter rejects the file`);
      return;
    }
    const colon = line.indexOf(':');
    if (colon === -1) return;
    if (!/^\s/.test(line)) {
      const key = line.slice(0, colon).trim();
      if (keys.has(key)) errors.push(`${at} sets key ${key} again, first set on line ${keys.get(key)}; YAML forbids a duplicate key, so a strict parser rejects the file`);
      else keys.set(key, n);
    }
    const value = line.slice(colon + 1).trim();
    if (!value) return;
    const quote = value[0] === '"' || value[0] === "'" ? value[0] : null;
    if (quote) {
      // endsWith is enough: no kern frontmatter puts a comment after a quoted value.
      if (value.length < 2 || !value.endsWith(quote)) {
        errors.push(`${at} opens a ${quote === '"' ? 'double' : 'single'} quote that never closes; a host that parses the frontmatter as YAML rejects the file`);
      }
      return;
    }
    // A plain scalar may not begin with these. Upstream measured the set against PyYAML and psych: a leading `:`
    // or `-` with no space after it, `#`, `&anchor`, `[` and `{` parse, so they pass.
    if (/^[`@%*,]/.test(value)) {
      errors.push(`${at} starts an unquoted value with '${value[0]}', which YAML reserves; wrap the value in quotes`);
      return;
    }
    // `|` or `>` alone opens a block scalar, which parseFrontmatter refuses; with text after it on the line, it is
    // a header that may not carry content.
    if (/^[|>]\S/.test(value)) {
      errors.push(`${at} starts an unquoted value with '${value[0]}' and text after it, which YAML reads as a block scalar header; wrap the value in quotes`);
      return;
    }
    if (/^[-?&](\s|$)/.test(value)) {
      errors.push(`${at} starts an unquoted value with '${value[0]} ', which YAML reads as an indicator; wrap the value in quotes`);
      return;
    }
    if (/:(\s|$)/.test(value)) {
      errors.push(`${at} has an unquoted value holding ': ', which YAML reads as a nested mapping; wrap the value in quotes`);
    }
  });
  return errors;
}
