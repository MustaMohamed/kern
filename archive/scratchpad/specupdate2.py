exec(open('/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/specupdate.py').read().split("# ---------- A3 scripts")[0])
RF='Red flags: the skill ends with a `## Red flags` table (`| Thought | Reality |`, 2 to 6 rows); lint rule 9 requires it for discipline skills.'
# C1 define
steps_section('C1','define',{2:'DE define: no repo-answerable questions',3:'DE define: no existing flow is architectural',9:'G20; plan-check',10:'G20; plan-check'},
 tail='''Spec template sections: issue; Problem; intent block; Assumptions; Success criteria; Constraints (`- Always:`, `- Ask first:`, `- Never:` lines that plan copies verbatim into Global Constraints); numbered ACs; Decisions (modules, interfaces, schema, contracts; no file paths); Compatibility (existing data and consumers, writers of gated properties, stored shape, the regression test by name); Authorization (who may call or see what, and the scoping check); Rollout (base, promotion chain, flags, migration order); one line per extra `checklists` item; Test seams (the highest existing seam, the fewest seams, checked with the user); Not doing; Open questions. Frontmatter: `status`, `form: full | short`, `date`, `approved: <date>, "<quote>"`, `issue`. `form: short` keeps only Problem, Constraints, Acceptance criteria and Test seams. [MM-define 2; PO to-spec:15-17,55-57; AD spec-driven-development:138-142]

'''+RF+''' [SP brainstorming:98-108; AD spec-driven-development:225-246]''',
 gate_tag=[('Guard G20 denies an approval whose quote is not a line of the user\'s last message.','[SP brainstorming:38-56; G20]')])
rep("**3. Inputs.** `tracker`, `tracker.first` (`false`), `scope_threshold` (4), `checklists`, `base_branch`, `work_dir`.","**3. Inputs.** `tracker`, `tracker.first` (`false`), `scope_threshold` (4), `checklists`, `base_branch`, `work_dir`, `model.investigator` (`sonnet`).")
rep("- Project has `.claude/skills/define/`: defers in one line.\n","- Project has `.claude/skills/define/`: defers in one line.\n- An approval edit whose quote is not a whole line of the user's last message, or is \"sounds good\", is denied by G20; under autopilot every approval edit is denied.\n- A request with no existing flow to extend is classified architectural.\n- The full checklist is `tests/skills/define.acceptance.md`.\n",1)
rep("SKILL.md 6 KB; `references/spec-template.md` 2.5 KB, `interview.md` 3 KB, `spec-review.md` 1.2 KB, `capability-map.md` 1 KB.","SKILL.md at most 6,500 bytes; `references/spec-template.md` 2.5 KB, `interview.md` 3 KB, `spec-review.md` 1.2 KB, `capability-map.md` 1 KB.")
# C2 plan
steps_section('C2','plan',{4:'DE plan: spike through define step 8',7:'PO to-tickets:23,40',11:'PB check-plan.mjs:1-190; DE plan',12:'G20'})
rep("**3. Inputs.** `work_dir`, `base_branch`, `deploy.envs` (promotion path), `scope_threshold` (4), `test.*`, `typecheck`, `lint`, `build` (detected, source printed), `checklists`, `shared_services`, `tracker`.","**3. Inputs.** `work_dir`, `base_branch`, `deploy.envs` (promotion path), `scope_threshold` (4), `test.*`, `typecheck`, `lint`, `build` (detected, source printed), `checklists`, `shared_services`, `tracker`, `model.investigator` (`sonnet`).")
rep("- A PR slice exceeds `scope_threshold`: asks to confirm or split before writing.\n","- A PR slice exceeds `scope_threshold`: asks to confirm or split before writing.\n- `plan-check` reports a task that consumes a name before the task that produces it: the plan is fixed before it is presented.\n- The full checklist is `tests/skills/plan.acceptance.md`.\n",1)
rep("SKILL.md 6 KB; `references/plan-template.md` 2 KB, `task-template.md` 2 KB, `plan-review.md` 1.2 KB.","SKILL.md at most 6,500 bytes; `references/plan-template.md` 2 KB, `task-template.md` 2 KB, `plan-review.md` 1.2 KB.")
# C3 execute-plan
steps_section('C3','execute-plan',{1:'SP subagent-driven-development:131-154; SP executing-plans:115-141; SP subagent-driven-development:141-147; SP sdd-workspace:6-9',2:'PB check-plan.mjs:1-190; DE execute-plan',4:'SP subagent-driven-development:223-232',6:'SP subagent-driven-development:282',8:'DE execute-plan: task-review, wt-diff --allow-file',10:'DE execute-plan: task-done --probe',12:'SP subagent-driven-development:361-364,455,459-470,473-482'},
 remap={2:None},
 tail=RF+''' [SP subagent-driven-development:489-500]''')
rep("**3. Inputs.** `base_branch`, `branch.pattern`, `test.focused`, `test.full`, `typecheck`, `worktree.dir`, `worktree.setup`, `shared_services`, `scope_threshold`, `review.rules`, `generated_artifacts`, `parallel.max`, `model.*` (A10).","**3. Inputs.** `base_branch`, `branch.pattern`, `test.focused`, `test.full`, `typecheck`, `worktree.dir`, `worktree.setup`, `shared_services`, `scope_threshold`, `review.rules`, `generated_artifacts`, `parallel.max`, `model.*` (A10). In code, not prose: the approval gate and ledger identity (`ledger-open`), plan structure, ordering and waves (`plan-check`), the out-of-Files pause (`wt-diff --allow-file`, exit 4), the review stamp (`task-review`) and completion only on a reviewed, unchanged, proven tree (`task-done --probe`).")
# C4 parallel-work
steps_section('C4','parallel-work',{1:'PB orchestrate:62',3:'PB orchestrate:56',6:'SP subagent-driven-development:235-245; PB orchestrate:95-96; DE parallel-work'})
# C5 implement
steps_section('C5','implement',{4:'BV implement: a test that already passes is a finding',8:'BV implement: probe --mutate on a fork, probe --exclude-tests'})
# C6 diagnose
steps_section('C6','diagnose',{2:'pocock diagnosing-bugs loop list',3:'BV diagnose: loop-rate, original scenario kept',4:'PB trace-forensics:7-12',6:'SP systematic-debugging:233-242',7:'SP systematic-debugging defense-in-depth; BV diagnose: blind reproduction',8:'BV diagnose: original scenario, probe --exclude-tests'},
 tail=RF+''' [SP systematic-debugging:243-260; AD debugging-and-error-recovery:281-300]''')
rep("**3. Inputs.** `test.focused`, `test.full`, `verify.browser`, `protected_targets`, `evidence_agents` (project agents for read-only data, none by default).","**3. Inputs.** `test.focused`, `test.full`, `verify.browser`, `protected_targets`, `evidence_agents` (project agents for read-only data, none by default), `model.investigator` (`sonnet`).")
# C7 prove-it
steps_section('C7','prove-it',{3:'BV prove-it: zero tests ran is a fail',4:'BV prove-it: --exclude-tests'},
 gate_tag=[('and follow its steps.','[SE routing: the only natural-language path to commit and finish-branch]')],
 tail=RF+''' [SP verification-before-completion:110-124]''')
# C8 self-review
steps_section('C8','self-review',{4:'PO code-review:68-80; BV self-review',6:'PS blast-radius:35 (where grep stops)',8:'AD doubt-driven-development:215 (doubt theater)',9:'SP code-reviewer.md:43-48 (Declined to judge)'},
 remap={4:None,5:4,6:5,7:6,8:7,9:8,10:9})
rep("**3. Inputs.** `base_branch`, `verify.fast`, `test.focused`, `review.rules`, `review.taxonomy`, `review.builtin` (`on`), `review.builtin.self_effort` (`low`), `review.builtin.max_findings` (15), `lessons`, `scope_threshold`.","**3. Inputs.** `base_branch`, `verify.fast`, `test.focused`, `review.rules`, `review.taxonomy`, `review.builtin` (`on`), `review.builtin.self_effort` (`low`), `review.builtin.max_findings` (15), `lessons`, `scope_threshold`, `spec.source` and `model.reviewer` (`sonnet`) for the spec lane.")
# C9 commit
steps_section('C9','commit',{3:'SE commit: staged stat; one commit per complete ledger task',4:'SE commit: the proven tree is the committed tree',6:'SE commit: message file under kern-dir tmp'},
 tail=RF+''' [AD git-workflow-and-versioning:313-325]''')
# C10 finish-branch
steps_section('C10','finish-branch',{1:'SE finish-branch: worktree from the ledger, cd in its own call (G2 _g02_here); SP finishing-a-development-branch:44,67-76 (detached HEAD)',6:'SP finishing-a-development-branch:137-146 (discard listing)',8:'SE finish-branch: dedup on headRefOid',9:'SE finish-branch: push only the proven tree',10:'PB opening-a-pr:13,18; SE finish-branch: --title, body under kern-dir tmp'},
 tail=RF+''' [SP finishing-a-development-branch:216-225]''')
# C11 recall
steps_section('C11','recall',{3:'SE recall: tree-id rule for [verified, uncommitted]',4:'SE recall: recall-sessions',7:'SE recall'})
open(SPEC,'w').write(spec)
print('C done')
