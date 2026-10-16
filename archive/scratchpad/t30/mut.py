import sys,subprocess,shutil
muts=[
('lint-rules.mjs','R6 drop routes source',"const sources = [['kernel/kernel.md', model.kernelText], ['kernel/routes.md', model.routesText]];","const sources = [['kernel/kernel.md', model.kernelText]];"),
('lint-rules.mjs','R6 drop kernel-names-routes check',"if (kernelRows(model.routesText).length && !model.kernelText.includes('{ROOT}/kernel/routes.md')) {","if (false) {"),
('lint-rules.mjs','R6 drop routes-not-a-row',"if (target === 'kernel/routes.md') {","if (false) {"),
('lint-rules.mjs','R7 drop routes cap',"if (model.routesText.length > 1500)","if (false)"),
('lint-rules.mjs','R7 drop git init check',"if (init.status !== 0) out.push","if (false) out.push"),
('lint-rules.mjs','R7 drop first-render check',"if (!ran(start)) out.push","if (false) out.push"),
('lint-rules.mjs','R7 drop second-render check',"if (ran(start) && !ran(again)) out.push","if (false) out.push"),
('lint-rules.mjs','R7 drop standing cost',"if (bare.length + desc > 4800)","if (false)"),
('lint-rules.mjs','R7 standing: skip rm settings',"for (const f of ['kern.local.yml', 'kern.yml']) rmSync(","for (const f of []) rmSync("),
('lint-rules.mjs','R7 loadModel routes in routed set',"`${kernelText}\\n${routesText}`.matchAll","kernelText.matchAll"),
('lint-rules.mjs','R12 nc ignores grader',"filter((n) => n.grader !== 'model').length","length"),
('lint-rules.mjs','R12 drop rows loop',"for (const r of kernelRows(text)) need(","for (const r of []) need("),
('lint-rules.mjs','R12 drop routes source',"['kernel/routes.md', model.routesText]];\n      for","];\n      for") ,
('lint-rules.mjs','R12 invalid json',"if (c.parseError) {","if (false) {"),
('lint-rules.mjs','R12 auto skills loop',"for (const s of model.skills.filter((x) => !x.error && x.tier === 'auto')) need","for (const s of []) need"),
('lint-rules.mjs','R12 missing',"if (!c) { out.push(err(12","if (false) { out.push(err(12"),
('route-eval.mjs','RE skip graded',"if (modelGraded(n)) { graded.push({ owner: expected, prompt: n.prompt }); continue; }","if (modelGraded(n)) { continue; }"),
('route-eval.mjs','RE graded not listed in main',"for (const m of r.modelGraded) console.log","for (const m of []) console.log"),
('route-eval.mjs','RE positive grader error',"if (p.grader !== undefined) errors.push","if (false) errors.push"),
('route-eval.mjs','RE unknown grader',"if (n.grader !== undefined && !modelGraded(n)) errors.push","if (false) errors.push"),
('route-eval.mjs','RE nc counts graded',"filter((n) => !modelGraded(n)).length;\n    const ec","length;\n    const ec"),
('route-eval.mjs','RE ownerOf identity',"const ownerOf = (name) => name.replace(/^row-/, '');","const ownerOf = (name) => name;"),
('route-eval.mjs','RE floor max',"Math.max(baseline.min_rank1, floors.rank1)","baseline.min_rank1"),
('route-eval.mjs','RE heldout floor',"minHeldout: floors.heldout_rank1","minHeldout: null"),
('route-eval.mjs','RE heldout unknown owner',"errors.push(`heldout: no owner","void (`heldout: no owner"),
('route-eval.mjs','RE rows in targets',"...skills, ...rows, ...distractors","...skills, ...distractors"),
('kernel-rows.mjs','KR when',"rows.push({ when: m[1], route: target[1] })","rows.push({ when: m[1], route: target[1]+'x' })"),
]
for f,name,a,b in muts:
    p='scripts/lib/'+f if f in('lint-rules.mjs','kernel-rows.mjs') else 'scripts/'+f
    src=open(p).read()
    if a not in src: print('NOMATCH',name); continue
    open(p,'w').write(src.replace(a,b,1))
    r=subprocess.run(['node','--test','tests/lint-rules.test.mjs','tests/route-eval-rows.test.mjs','tests/route-eval.test.mjs'],capture_output=True,text=True)
    fails=[l for l in r.stdout.splitlines() if l.startswith('not ok')]
    print('KILLED' if fails else 'SURVIVED',name,len(fails))
    open(p,'w').write(src)
