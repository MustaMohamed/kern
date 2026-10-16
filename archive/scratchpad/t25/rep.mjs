import fs from 'node:fs';
const [f,o,n]=process.argv.slice(2);
const s=fs.readFileSync(f,'utf8'); const c=s.split(o).length-1;
if(c!==1){console.error('count',c,o);process.exit(1);}
fs.writeFileSync(f,s.replace(o,()=>n));
