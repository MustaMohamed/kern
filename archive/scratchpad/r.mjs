import {targets} from '/Users/musta/Code/projects/kern/scripts/route-eval.mjs';
import {buildCorpus,rank} from '/Users/musta/Code/projects/kern/scripts/lib/rank.mjs';
const t=targets('/Users/musta/Code/projects/kern');const c=buildCorpus(t);
for(const q of ["Explain what 'verified' means in this commit message","What does a passing PR mean for subagent work","Explain what fixed and passing mean in this commit message","Summarize what each acceptance line in this PR says"]){
const r=rank(q,c,t);const i=r.findIndex(x=>x.name==='prove-it');console.log(q,'| prove-it',i+1,r[i]?.score,'| top',r[0].name,r[0].score)}
