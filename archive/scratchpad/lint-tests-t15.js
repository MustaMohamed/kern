// M2a rules: 5 (Skill-tool and agent Read paths), 9 (required sections and Red flags), 16 (contract drift).
const manual = (desc = 'd') => `description: ${desc}\ndisable-model-invocation: true`;
const agentDoc = (body) => `---\nname: r\ndescription: d\n---\n${body}`;
const flags = (n) => `\n## Red flags\n\n| Thought | Reality |\n|---|---|\n${Array.from({ length: n }, (_, i) => `| t${i} | r${i} |`).join('\n')}\n`;

test('rule 5: Skill tool references name auto or built-in skills', () => {
  const caller = (target) => skill('c', manual(), `\n# c\n\n## Steps\n\n1. Call the Skill tool with \`${target}\`.\n`);
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': caller('nope') })), [5]);
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': caller('code-review') })), []);
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': caller('kern:a'), 'skills/a/SKILL.md': skill('a', 'description: Use when x.') })), []);
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': caller('p'), 'skills/p/SKILL.md': skill('p', manual()) })), [5]);
});

test('rule 5: agent Read paths resolve', () => {
  const body = '## Report\n\nRead `${CLAUDE_PLUGIN_ROOT}/skills/missing/SKILL.md`.\n';
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc(body) })), [5]);
  const ok = { 'agents/r.md': agentDoc('## Report\n\nRead `${CLAUDE_PLUGIN_ROOT}/skills/a/SKILL.md`.\n'), 'skills/a/SKILL.md': skill('a', 'description: Use when x.') };
  assert.deepEqual(rules(lint(ok)), []);
});

test('rule 9: auto skills need Steps; slash skills need Steps first', () => {
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', '\n# a\n\n## Notes\n\nx\n') })), [9]);
  assert.deepEqual(rules(lint({ 'skills/s/SKILL.md': skill('s', manual(), '\n# s\n\n## Inputs\n\nx\n\n## Steps\n\n1. a\n') })), [9]);
  assert.deepEqual(rules(lint({ 'skills/s/SKILL.md': skill('s', manual(), '\n# s\n\nRules only.\n') })), [9]);
  assert.deepEqual(rules(lint({ 'skills/s/SKILL.md': skill('s', manual()) })), []);
});

test('rule 9: a slash skill without Steps passes with an exemption', () => {
  const files = {
    'skills/s/SKILL.md': skill('s', manual(), '\n# s\n\nRules only.\n'),
    'scripts/lint-exemptions.json': '[{"rule":9,"path":"skills/s/SKILL.md","reason":"rule document, not a procedure"}]',
  };
  assert.deepEqual(rules(lint(files)), []);
});

test('rule 9: agents need an output contract section', () => {
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc('Just do it.\n') })), [9]);
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc('## Output\n\nVerdict first.\n') })), []);
});

test('rule 9: a discipline skill needs a Red flags table of 2 to 6 rows', () => {
  const body = (extra) => `\n# implement\n\n## Steps\n\n1. a\n${extra}`;
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body('')) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(1))) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(7))) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(3))) })), []);
  assert.deepEqual(rules(lint({ 'skills/other/SKILL.md': skill('other', manual(), body('')) })), [], 'only discipline skills need the table');
});

test('rule 16: scripts, WORK folders and ledger lines a skill names have a producer in the contract', () => {
  const contract = '| `wt-snap` | x |\n- `WORK/plans/`\n- `Task N: start tree=<id> at=<iso>`\n';
  const body = (s) => `\n# c\n\n## Steps\n\n1. ${s}\n`;
  const ok = body('Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>` and read WORK/plans; then `Task N: start tree=<id> at=<iso>`.');
  assert.deepEqual(rules(lint({ 'docs/plans/contract.md': contract, 'skills/c/SKILL.md': skill('c', manual(), ok), 'scripts/wt-snap': '' })), []);
  const bad = body('Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-gone <wt>`, read WORK/drafts and write `Task N: done`.');
  const f = lint({ 'docs/plans/contract.md': contract, 'skills/c/SKILL.md': skill('c', manual(), bad), 'scripts/wt-gone': '' }).filter((x) => x.rule === 16);
  assert.deepEqual(f.map((x) => x.message.split(':')[0]), ['scripts/wt-gone', 'WORK/drafts', 'Task N']);
});
