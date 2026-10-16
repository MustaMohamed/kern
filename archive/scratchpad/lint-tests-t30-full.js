// M2a rules 6, 7 and 12 read kernel/routes.md.
test('rule 6: rows in kernel/routes.md resolve, and the kernel must name the routed file', () => {
  const files = {
    'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |']) + 'Then Read {ROOT}/kernel/routes.md.\n',
    'kernel/routes.md': '| Bug | Read {KERN}/d/SKILL.md |\n',
    'skills/tw/SKILL.md': skill('tw', manual()),
    'skills/d/SKILL.md': skill('d', manual()),
  };
  assert.deepEqual(rules(lint(files)), []);
  assert.equal(loadModel(repo(files)).skills.find((s) => s.name === 'd').tier, 'path', 'a skill routed from routes.md is a path skill');
  assert.deepEqual(rules(lint({ ...files, 'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |']) })), [6]);
  assert.deepEqual(rules(lint({ ...files, 'kernel/routes.md': '| Bug | Read {KERN}/gone/SKILL.md |\n' })), [6]);
});

test('rule 7: the routed file has its own cap, and the standing cost has a combined budget', () => {
  assert.deepEqual(rules(lint({ 'kernel/routes.md': `| x | Read {KERN}/a/SKILL.md |\n${'y'.repeat(1500)}` })).filter((r) => r === 7), [7]);
  const sub = '#!/usr/bin/env bash\nprintf \'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"k"}}\'\n';
  const start = (n) => `#!/usr/bin/env bash\nhead -c ${n} /dev/zero | tr "\\0" x\n`;
  const desc = `description: Use when ${'w'.repeat(280)}.`;
  const files = (n) => ({ 'hooks/session-start': start(n), 'hooks/subagent-start': sub, 'skills/a/SKILL.md': skill('a', desc) });
  assert.deepEqual(rules(lint(files(4400))).filter((r) => r === 7), []);
  const big = lint(files(4600)).filter((f) => f.rule === 7 && f.level === 'error');
  assert.equal(big.length, 1);
  assert.match(big[0].message, /^standing cost 48\d\d chars/);
});


const caseJson = (name, p = 3, n = 2, e = 1) => JSON.stringify({
  skill_name: name,
  trigger: { positive: Array.from({ length: p }, (_, i) => ({ prompt: `p${i}` })), negative: Array.from({ length: n }, (_, i) => ({ prompt: `n${i}` })) },
  evals: Array.from({ length: e }, (_, i) => ({ id: i + 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] })),
});

test('rule 12: auto skills and the rows of both kernel files need eval cases once evals/cases exists', () => {
  const base = { 'skills/a/SKILL.md': skill('a', 'description: Use when x.') };
  assert.deepEqual(rules(lint(base)), [], 'no evals/cases folder: rule 12 is silent');
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/other.json': caseJson('other') })), [12]);
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/a.json': caseJson('a', 2) })), [12]);
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/a.json': caseJson('a') })), []);
  const routed = { ...base, 'evals/cases/a.json': caseJson('a'), 'kernel/kernel.md': 'Then Read {ROOT}/kernel/routes.md.\n', 'kernel/routes.md': '| Bug | Read {KERN}/d/SKILL.md |\n', 'skills/d/SKILL.md': skill('d', 'description: d\ndisable-model-invocation: true') };
  assert.deepEqual(rules(lint(routed)), [12]);
  assert.deepEqual(rules(lint({ ...routed, 'evals/cases/row-d.json': caseJson('row-d') })), []);
});
