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

