import fs from 'node:fs';import {spawnSync} from 'node:child_process';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {codec_json} from '../web/engine.mjs';
const cases=[];const signed=n=>BigInt.asIntN(64,n).toString();const sample=(time,bits)=>({timestamp:signed(time),bits:BigInt.asUintN(64,bits).toString()});
const add=(name,samples)=>cases.push({name,samples});
add('empty',[]);
const times=[0n,-1n,1n,63n,64n,-64n,-65n,8192n,1700000000000n,-9223372036854775808n,9223372036854775807n];
const bits=[0n,1n,0x8000000000000000n,0x3ff0000000000000n,0x7ff0000000000000n,0xfff0000000000000n,0x7ff8000000000001n,0x7ff0000000000001n,0xffffffffffffffffn];
for(const t of times)for(const v of bits)add(`first ${t} ${v}`,[sample(t,v)]);
for(const dd of [-9223372036854775808n,-524288n,-524287n,-65536n,-65535n,-8192n,-8191n,-1n,0n,1n,8191n,8192n,8193n,65535n,65536n,65537n,524287n,524288n,524289n,9223372036854775807n])for(const value of [0n,1n,0x8000000000000000n])add(`delta bucket ${dd}/${value}`,[sample(0n,0n),sample(1000000n,0n),sample(2000000n+dd,value),sample(3000000n+2n*dd,value)]);
for(let bit=0n;bit<64n;bit++)add(`xor window ${bit}`,[sample(0n,0n),sample(1n,1n<<bit),sample(2n,0n),sample(3n,(1n<<bit)|1n),sample(4n,0xffffffffffffffffn)]);
add('timestamp wrap and reverse',times.map((t,i)=>sample(t,bits[i%bits.length])));
let seed=0x123456789abcdefn;function random(){seed^=seed<<13n;seed^=seed>>7n;seed^=seed<<17n;seed=BigInt.asUintN(64,seed);return seed;}
for(let i=0;i<40;i++){let t=BigInt.asIntN(64,random()),value=random();const samples=[];for(let j=0;j<1+i*7;j++){t+=BigInt.asIntN(64,random())%1000000n;if(j%5)value^=random();samples.push(sample(t,value));}add(`seeded irregular ${i}`,samples);}
for(const count of [2,3,7,8,9,63,64,65,127,128,1024,65535])add(`constant count ${count}`,Array.from({length:count},(_,i)=>sample(BigInt(i)*15000n,0x7ff800000000007bn)));
function core(request){const result=JSON.parse(codec_json(JSON.stringify(request)));if(!result.ok)throw Error(result.error);return result.result;}
const actual=cases.map(test=>core({operation:'encode',format:'xor',samples:test.samples}).hex);
const golden=process.argv.includes('--golden');let reference,decoded,binarySha256;
function oracle(requests){const binary=process.env.GORILLA_ORACLE;if(!binary)throw Error('Set GORILLA_ORACLE to the executable built from tools/oracle');const run=spawnSync(binary,[],{input:requests.map(x=>JSON.stringify(x)).join('\n')+'\n',encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:64*1024*1024});if(run.error||run.status!==0)throw Error(String(run.error||run.stderr));return run.stdout.trim().split('\n').map(JSON.parse);}
if(golden){const saved=JSON.parse(fs.readFileSync(new URL('../evidence/xor-reference-vectors.json',import.meta.url),'utf8'));assert.deepEqual(saved.cases,cases);({reference,decoded,binarySha256}=saved);}
else{reference=oracle(cases.map(test=>({operation:'encode',samples:test.samples})));decoded=oracle(actual.map(hex=>({operation:'decode',hex})));binarySha256=createHash('sha256').update(fs.readFileSync(process.env.GORILLA_ORACLE)).digest('hex');}
const failures=[];
for(let i=0;i<cases.length;i++){
  try{
    const r=reference[i];assert.equal(r.ok,true);assert.equal(actual[i],r.hex,'exact encoded bytes');assert.deepEqual(r.samples??[],cases[i].samples,'reference self-decoding');
    assert.deepEqual(core({operation:'decode',format:'xor',hex:r.hex}).samples,cases[i].samples,'MoonBit reads reference');
    if(golden){assert.equal(decoded[i].hex,actual[i]);}assert.equal(decoded[i].ok,true);assert.deepEqual(decoded[i].samples??[],cases[i].samples,'reference reads MoonBit');
  }catch(error){failures.push({name:cases[i].name,error:error.message.slice(0,700),actual:actual[i].slice(0,100),reference:reference[i]?.hex?.slice(0,100)});}
}
if(!golden&&!failures.length)fs.writeFileSync(new URL('../evidence/xor-reference-vectors.json',import.meta.url),JSON.stringify({cases,reference,decoded,binarySha256})+'\n');
const report={utc:new Date().toISOString(),mode:golden?'saved reference vectors':'live unmodified Prometheus chunkenc',reference:reference[0].module,runtime:reference[0].runtime,binarySha256,engineSha256:createHash('sha256').update(fs.readFileSync(new URL('../web/engine.mjs',import.meta.url))).digest('hex'),total:cases.length,passed:cases.length-failures.length,failed:failures.length,failures};
fs.writeFileSync(new URL(`../evidence/xor-reference-${golden?'replay':'validation'}.json`,import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(`${report.passed}/${report.total} exact Prometheus XOR bytes and bidirectional sample cases passed`);for(const f of failures.slice(0,10))console.log(JSON.stringify(f));if(failures.length)process.exitCode=1;
