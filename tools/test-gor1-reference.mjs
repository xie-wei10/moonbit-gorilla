import fs from 'node:fs';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';import assert from 'node:assert/strict';import {codec_json} from '../web/engine.mjs';
const samples=(times,bits)=>times.map((t,i)=>({timestamp:String(t),bits:String(bits[i%bits.length])})),cases=[{samples:[]}];
const add=s=>cases.push({samples:s});
for(const difference of [-2048,-2047,-256,-255,-64,-63,-1,0,1,63,64,65,255,256,257,2047,2048,2049])for(const b of [0n,1n,0x8000000000000000n,0xffffffffffffffffn])add(samples([0,10000,20000+difference,30000+2*difference],[0n,b,0n,b]));
for(let i=0n;i<64n;i++)add(samples([0,1,2,3,4],[0n,1n<<i,0n,(1n<<i)|1n,0xffffffffffffffffn]));
add(samples([0,0,1,9007199254740991],[0x7ff800000000007bn,0x7ff0000000000001n]));
for(const count of [1,2,7,8,9,1024])add(samples(Array.from({length:count},(_,i)=>i*60000),[0x7ff800000000007bn]));
const core=r=>{const result=JSON.parse(codec_json(JSON.stringify(r)));if(!result.ok)throw Error(result.error);return result.result;};
for(const test of cases)test.hex=core({operation:'encode',format:'gor1',samples:test.samples}).hex;
const golden=process.argv.includes('--golden');let reference;
if(golden){const saved=JSON.parse(fs.readFileSync(new URL('../evidence/gor1-reference-vectors.json',import.meta.url),'utf8'));assert.deepEqual(cases,saved.cases);reference=saved.reference;}
else{const run=spawnSync(process.env.PYTHON||'python',[fileURLToPath(new URL('./gor1_oracle.py',import.meta.url))],{input:JSON.stringify(cases),encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:16*1024*1024});if(run.error||run.status!==0)throw Error(String(run.error||run.stderr));reference=JSON.parse(run.stdout);}
for(let i=0;i<cases.length;i++){assert.equal(cases[i].hex,reference[i].hex);assert.deepEqual(cases[i].samples,reference[i].samples);assert.deepEqual(core({operation:'decode',format:'gor1',hex:reference[i].hex}).samples,cases[i].samples);}
if(!golden)fs.writeFileSync(new URL('../evidence/gor1-reference-vectors.json',import.meta.url),JSON.stringify({cases,reference})+'\n');
fs.writeFileSync(new URL('../evidence/gor1-reference-validation.json',import.meta.url),JSON.stringify({utc:new Date().toISOString(),mode:golden?'saved vectors':'live independent Python specification model',passed:cases.length,scope:'GOR1 custom format; not upstream wire compatibility'},null,2)+'\n');console.log(`${cases.length} independent GOR1 exact-byte/bidirectional cases passed`);
