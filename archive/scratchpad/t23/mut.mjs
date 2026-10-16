import fs from 'node:fs'; import {spawnSync} from 'node:child_process';
const f='skills/self-review/SKILL.md'; const orig=fs.readFileSync(f,'utf8');
const needles=['report "base not refreshed"','Exit 3 is an empty diff','any other non-zero exit is a failed check','probe exit 3','never as a pass','names a path the package also changed','never rebases','parked: <question>; default: <choice>; why: <one line>','Never pass `--comment`','where does this artifact fail this contract?','never your claim or reasoning','lessons are not written','`kern:investigator` on model `model.reviewer`','git -C <wt> diff --name-only <merge-base> origin/<base>','never guess a command','the first that applies','scope_threshold','two highest classes','Declined to judge','Else `ready`','a finding in an earlier self-review round','`split`: more changed paths','probe exit 1','unresolved hit'];
for (const n of needles){ const c=orig.split(n).length-1; fs.writeFileSync(f,orig.split(n).join(''));
 const r=spawnSync('node',['--test','tests/skills/self-review.test.mjs'],{encoding:'utf8'});
 console.log(r.status!==0?'CAUGHT':'MISSED', c, JSON.stringify(n)); }
fs.writeFileSync(f,orig);
