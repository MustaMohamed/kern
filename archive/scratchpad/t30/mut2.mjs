import {readFileSync,writeFileSync} from 'node:fs';import {spawnSync} from 'node:child_process';
const M=[
['scripts/lib/lint-rules.mjs','R6 routes-not-a-row (parseRow)',"scripts/lib/kernel-rows.mjs","if (base === 'ROOT' && path === 'kernel/routes.md') return","if (false) return"],
['scripts/lib/lint-rules.mjs','R7 git init',null,"if (init.status !== 0) out.push","if (false) out.push"],
['scripts/lib/lint-rules.mjs','R12 invalid json msg',null,"if (c.parseError) {","if (false) {"],
['scripts/route-eval.mjs','floor max',null,"Math.max(baseline.min_rank1, floors.rank1)","baseline.min_rank1"],
['scripts/route-eval.mjs','heldout floor',null,"minHeldout: floors.heldout_rank1","minHeldout: null"],
['scripts/route-eval.mjs','heldout unknown owner',null,"errors.push(`heldout: no owner","void (`heldout: no owner"],
['scripts/route-eval.mjs','finite check',null,"!Number.isFinite(data?.[k])","false"],
['scripts/route-eval.mjs','setup exit',null,"process.exit(1);\n  }\n  const minRank1","}\n  const minRank1"],
['scripts/route-eval.mjs','no positives guard',null,"if (minRank1 !== null && !positives) errors.push","if (false) errors.push"],
['scripts/route-eval.mjs','heldout array guard',null,"!Array.isArray(held) || !held.length","false"],
['scripts/route-eval.mjs','heldout entry guard',null,"if (bad >= 0) {","if (false) {"],
['scripts/route-eval.mjs','ownerOf by kind',null,"kinds.get(name) === 'row'","true"],
['scripts/route-eval.mjs','sort',null,".filter((f) => f.endsWith('.json')).sort()",".filter((f) => f.endsWith('.json'))"],
['scripts/lib/lint-rules.mjs','R7 header check',null,"r.status === 0 && (r.stdout || '').split('\\n').some((l) => l.startsWith(header))","r.status === 0 && (r.stdout||'').trim()!==''"],
['scripts/lib/lint-rules.mjs','R7 fixture missing',null,"if (!settings.length) out.push","if (false) out.push"],
['scripts/lib/lint-rules.mjs','R12 flagged positive',null,"if (flagged) out.push","if (false) out.push"],
['scripts/lib/lint-rules.mjs','routed via parseRow',null,"const routed = routedSkills(`${kernelText}\\n${routesText}`);","const routed = new Set([...`${kernelText}\\n${routesText}`.matchAll(/Read \\{KERN\\}\\/([a-z0-9-]+)\\/SKILL\\.md/g)].map((m) => m[1]));"],
['scripts/route-eval.mjs','unknown grader err',null,"if (n.grader !== undefined && !modelGraded(n)) errors.push","if (false) errors.push"],
];
for (const [f,name,alt,a,b] of M){const p=alt||f;const s=readFileSync(p,'utf8');if(!s.includes(a)){console.log('NOMATCH',name);continue}
writeFileSync(p,s.replace(a,b));const r=spawnSync('node',['--test','tests/lint-rules.test.mjs','tests/route-eval-rows.test.mjs','tests/route-eval.test.mjs'],{encoding:'utf8'});
const f2=r.stdout.split('\n').filter(l=>l.startsWith('not ok')).length;console.log(f2?'KILLED':'SURVIVED',name,f2);writeFileSync(p,s)}
