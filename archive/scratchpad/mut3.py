import sys, subprocess, shutil
S = sys.argv[1]; root = S + '/mut'; orig = S + '/mut-orig'
muts = [
  ('SKILL.md', "; this run's `wave` rows feed step 4", '', 'step 2 wave rows from this run'),
  ('SKILL.md', ', each round opening with its `Status:` line', '', 'delegate REPORT status line'),
  ('SKILL.md', 'Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`', 'Once, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`', 'reintroduce Once in step 2'),
  ('SKILL.md', ' only when the ledger lacks that exact line', '', 'step 2 add-only-missing'),
  ('SKILL.md', 'record the answer, or a mechanical call, as a `Decision:` line', 'a mechanical call gets a `Decision:` line', 'step 3 answer not recorded'),
  ('references/resume.md', ' (under autopilot, parked once)', '', 'resume parked once'),
  ('references/resume.md', ' (step and inline: finish the change first)', '', 'resume step/inline finish first'),
  ('SKILL.md', 'Line formats and how to append them: `references/ledger-format.md`. ', '', 'step 1 ledger-format pointer'),
]
for f, s, new, name in muts:
    shutil.rmtree(root + '/skills/execute-plan'); shutil.copytree(orig, root + '/skills/execute-plan')
    p = root + '/skills/execute-plan/' + f; t = open(p).read()
    if t.count(s) != 1: print(f'{name}: SKIP (count {t.count(s)})'); continue
    open(p, 'w').write(t.replace(s, new, 1))
    r = subprocess.run(['node', '--test', 'tests/skills/execute-plan.test.mjs'], cwd=root, capture_output=True, text=True)
    print(f'{name}: {"KILLED" if r.returncode else "SURVIVED"}')
shutil.rmtree(root + '/skills/execute-plan'); shutil.copytree(orig, root + '/skills/execute-plan')
