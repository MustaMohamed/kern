
test('mode documents the switch phrases the hook accepts', () => {
  const { body } = read('mode');
  assert.match(body, /only when it stands alone on the prompt's first non-blank line/);
  assert.match(body, /a line over 200 characters never does\./);
  assert.match(body, /^- terse voice: .*"terse on", "terse voice", "terse mode on"/m);
});
