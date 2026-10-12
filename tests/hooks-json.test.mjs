// hooks/hooks.json: the shape the contract fixes, and every script it names exists and is executable.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = join(import.meta.dirname, '..');
const hooks = JSON.parse(readFileSync(join(root, 'hooks', 'hooks.json'), 'utf8')).hooks;

test('every M1 event is wired in exec form', () => {
  assert.deepEqual(Object.keys(hooks).sort(), ['PreToolUse', 'SessionStart', 'SubagentStart', 'UserPromptExpansion', 'UserPromptSubmit']);
  for (const [event, groups] of Object.entries(hooks)) {
    for (const g of groups) for (const h of g.hooks) {
      assert.equal(h.command, 'bash', `${event} uses exec form`);
      const script = h.args[0].replace('${CLAUDE_PLUGIN_ROOT}', root);
      assert.ok(statSync(script).mode & 0o111, `${script} is executable`);
    }
  }
});

test('the guard dispatcher fails closed and sees every guarded tool', () => {
  const pre = hooks.PreToolUse[0];
  assert.equal(pre.hooks[0].onFailure, 'block');
  for (const tool of ['Bash', 'Write', 'Edit', 'NotebookEdit', 'Skill', 'CronCreate', 'ScheduleWakeup', 'RemoteTrigger', 'SendMessage', 'mcp__claude_ai_Linear__save_issue']) {
    assert.match(tool, new RegExp(`^(${pre.matcher})$`), tool);
  }
});
