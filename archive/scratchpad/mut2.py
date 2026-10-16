import sys, subprocess, shutil
S = sys.argv[1]; root = S + '/mut'; orig = S + '/mut-orig'
muts = [
  ('references/resume.md', "A task a `parked:` line holds stays out, with every task blocked by it.", 'resume: parked stays out'),
  ('references/resume.md', " The next round gets that file.", 'resume: next round gets file'),
  ('references/resume.md', "   - an approving review: step 10.\n", 'resume: approving review -> step 10'),
  ('references/resume.md', "4. Every task complete and applied: step 12.\n", 'resume: case 4'),
  ('SKILL.md', " (SendMessage to its agent id, or `references/resume.md`'s fallback; inline and step: fix it yourself)", 'step 9 resume mechanism'),
  ('SKILL.md', "One commit per closed task when its checks pass, through `/kern:commit`; ", 'stops: autopilot commit'),
  ('SKILL.md', " Residual findings go to the user in step 13.", 'step 12 residual'),
  ('SKILL.md', " A refusal writes nothing and says why.", 'step 10 refusal'),
  ('SKILL.md', " Re-grade findings by effect.", 'step 12 re-grade'),
  ('SKILL.md', " `command exited 126` or `127`: stop.", 'step 10 126/127'),
  ('SKILL.md', " After fix rounds, remake `<package>` from `tree-before`.", 'step 10 remake'),
  ('SKILL.md', " Never re-dispatch unchanged.", 'step 7 never re-dispatch (global pin)'),
]
for f, s, name in muts:
    shutil.rmtree(root + '/skills/execute-plan'); shutil.copytree(orig, root + '/skills/execute-plan')
    p = root + '/skills/execute-plan/' + f; t = open(p).read()
    if t.count(s) != 1: print(f'{name}: SKIP (count {t.count(s)})'); continue
    open(p, 'w').write(t.replace(s, '', 1))
    r = subprocess.run(['node', '--test', 'tests/skills/execute-plan.test.mjs'], cwd=root, capture_output=True, text=True)
    print(f'{name}: {"KILLED" if r.returncode else "SURVIVED"}')
shutil.rmtree(root + '/skills/execute-plan'); shutil.copytree(orig, root + '/skills/execute-plan')
