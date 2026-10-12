// Adapted from addyosmani/agent-skills scripts/run-evals.js (MIT): the tier 2 text pipeline.

const STOP = new Set([
  'a', 'an', 'and', 'any', 'are', 'as', 'at', 'be', 'before', 'by', 'for',
  'from', 'in', 'into', 'is', 'it', 'its', 'my', 'need', 'needs', 'of', 'on',
  'or', 'our', 'so', 'that', 'the', 'them', 'this', 'to', 'use', 'want',
  'we', 'when', 'with', 'you', 'your', 'help', 'me', 'i',
]);

function stem(t) {
  // Light suffix stripping so "conflicts"/"conflict", "branching"/"branch",
  // "architectural"/"architecture" cluster together. Not a real stemmer.
  for (const suf of ['ally', 'ing', 'ed', 'es', 'al']) {
    if (t.length > suf.length + 3 && t.endsWith(suf)) {
      t = t.slice(0, -suf.length);
      break;
    }
  }
  if (t.length > 3 && t.endsWith('s') && !t.endsWith('ss')) t = t.slice(0, -1);
  if (t.length > 4 && t.endsWith('e')) t = t.slice(0, -1);
  // Collapse doubled trailing consonant left by -ing/-ed ("committ" -> "commit").
  if (t.length > 4 && t[t.length - 1] === t[t.length - 2] && !'aeiou'.includes(t[t.length - 1])) {
    t = t.slice(0, -1);
  }
  // Normalize trailing y so "simplify" and "simplifies"/"simplified" cluster.
  if (t.length > 3 && t.endsWith('y')) t = t.slice(0, -1) + 'i';
  return t;
}

export function tokenize(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, ' ')
    .split(/[\s-]+/)
    .filter((t) => t.length > 2 && !STOP.has(t))
    .map(stem);
}

export function termFreq(tokens) {
  const tf = new Map();
  for (const t of tokens) tf.set(t, (tf.get(t) || 0) + 1);
  return tf;
}

export function vec(tf, idf) {
  const v = new Map();
  for (const [term, f] of tf) v.set(term, f * idf(term));
  return v;
}

export function cosine(a, b) {
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (const [t, w] of a) {
    na += w * w;
    const bw = b.get(t);
    if (bw) dot += w * bw;
  }
  for (const w of b.values()) nb += w * w;
  if (!na || !nb) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

export function buildCorpus(docs) {
  const map = new Map();
  for (const d of docs) {
    const nameTokens = tokenize(d.name.replace(/-/g, ' '));
    map.set(d.name, termFreq([...nameTokens, ...nameTokens, ...tokenize(d.text)]));
  }
  const df = new Map();
  for (const tf of map.values()) for (const term of tf.keys()) df.set(term, (df.get(term) || 0) + 1);
  const n = map.size;
  const idf = (term) => Math.log(1 + n / (1 + (df.get(term) || 0)));
  return { docs: map, idf };
}

export function rank(prompt, corpus) {
  const pv = vec(termFreq(tokenize(prompt)), corpus.idf);
  const scores = [];
  for (const [name, tf] of corpus.docs) scores.push({ name, score: cosine(pv, vec(tf, corpus.idf)) });
  scores.sort((a, b) => b.score - a.score);
  return scores;
}

export function similarity(a, b, corpus) {
  return cosine(vec(corpus.docs.get(a), corpus.idf), vec(corpus.docs.get(b), corpus.idf));
}
