import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';import assert from 'node:assert/strict';
import {ArchiveFile,readArchive,writeArchive,textSamples} from './archive.mjs';
const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'gorilla-archive-'));const cases=[],checks=[];
const golden=process.argv.includes('--golden');const collect=async iterable=>{const out=[];for await(const x of iterable)out.push(x);return out;};
function make(count){return Array.from({length:count},(_,i)=>({timestamp:String(Math.floor(i/3)-100),bits:BigInt.asUintN(64,BigInt(i)*0x1edc6f41n^0x7ff80000000000ffn).toString()}));}
try{
  for(const [count,blockSize] of [[0,4],[1,1],[19,3],[301,17],[1000,1000]]){
    const filename=path.join(temporary,`${count}.gor2`),samples=make(count);await writeArchive(filename,samples,{blockSize});const bytes=await fs.readFile(filename);cases.push({samples,blockSize,hex:bytes.toString('hex')});
    assert.deepEqual(await collect(readArchive(filename)),samples);const file=await ArchiveFile.open(filename);
    try{assert.deepEqual(await collect(file.range(-98,-94)),samples.filter(s=>BigInt(s.timestamp)>=-98n&&BigInt(s.timestamp)<=-94n));assert.equal((await file.verify()).samples,String(count));}finally{await file.close();}
  }
  let reference;
  if(golden){const saved=JSON.parse(await fs.readFile(new URL('../evidence/archive-reference-vectors.json',import.meta.url),'utf8'));assert.deepEqual(saved.cases,cases);reference=saved.reference;}
  else{const run=spawnSync(process.env.PYTHON||'python',[fileURLToPath(new URL('./archive_oracle.py',import.meta.url))],{input:JSON.stringify(cases),encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:16*1024*1024});if(run.error||run.status!==0)throw Error(String(run.error||run.stderr));reference=JSON.parse(run.stdout);}
  for(let i=0;i<cases.length;i++){
    assert.equal(cases[i].hex,reference.results[i].hex);assert.deepEqual(cases[i].samples,reference.results[i].samples);
    const file=path.join(temporary,`reference-${i}.gor2`);await fs.writeFile(file,Buffer.from(reference.results[i].hex,'hex'));assert.deepEqual(await collect(readArchive(file)),cases[i].samples);
  }
  if(!golden)await fs.writeFile(new URL('../evidence/archive-reference-vectors.json',import.meta.url),JSON.stringify({cases,reference})+'\n');checks.push('5 independent container cases: exact bytes and bidirectional samples');
  const filename=path.join(temporary,'large.gor2');let emitted=0;
  async function* source(){for(let i=0;i<100000;i++){emitted++;yield {timestamp:BigInt(i)*1000n,bits:0x7ff800000000007bn};}}
  const written=await writeArchive(filename,source(),{blockSize:1024});assert.equal(emitted,100000);assert.equal(written.samples,'100000');
  const indexed=await ArchiveFile.open(filename);const initial=indexed.bytesRead;
  try{const found=await collect(indexed.range(99000000n,99001000n));assert.equal(found.length,2);assert.equal(found[0].timestamp,'99000000');assert.ok(indexed.bytesRead-initial<indexed.size/10);checks.push('100000-sample async input and index reads less than 10% of archive for narrow query');}finally{await indexed.close();}
  let count=0;for await(const _ of readArchive(filename))count++;assert.equal(count,100000);checks.push('100000-sample bounded stream decoding');
  const before=await fs.readFile(filename);await assert.rejects(writeArchive(filename,make(2)),{code:'EEXIST'});assert.deepEqual(await fs.readFile(filename),before);checks.push('existing output is byte-identical after rejected publication');
  const aborted=path.join(temporary,'aborted.gor2'),controller=new AbortController();async function* cancel(){yield {timestamp:0n,bits:0n};controller.abort();yield {timestamp:1n,bits:1n};}
  await assert.rejects(writeArchive(aborted,cancel(),{signal:controller.signal}),{code:'ABORT_ERR'});await assert.rejects(fs.stat(aborted),{code:'ENOENT'});assert.equal((await fs.readdir(temporary)).filter(x=>x.endsWith('.tmp')).length,0);checks.push('abort removes only owned temporary file and publishes no output');
  const bad=path.join(temporary,'bad.gor2');async function* unordered(){yield {timestamp:10,bits:1};yield {timestamp:9,bits:2};}
  await assert.rejects(writeArchive(bad,unordered()));await assert.rejects(fs.stat(bad),{code:'ENOENT'});checks.push('invalid input cannot publish an archive');
  const damaged=Buffer.from(before);damaged[40]^=1;await fs.writeFile(bad,damaged);const partial=await ArchiveFile.open(bad);
  try{assert.equal((await collect(partial.range(99000000n,99001000n))).length,2);await assert.rejects(collect(partial.range(99000000n,99001000n,{verifyAll:true})));await assert.rejects(collect(readArchive(bad)));checks.push('range excludes unread corruption; verifyAll and full stream detect it');}finally{await partial.close();}
  for(let i=0;i<70;i++){const it=readArchive(filename);await it.next();await it.return();const file=await ArchiveFile.open(filename);await file.close();}checks.push('early iterator return and repeated opens release bridge/file resources');
  const utf8=path.join(temporary,'input.txt');await fs.writeFile(utf8,'-1 18446744073709551615\r\n0 0\n');assert.deepEqual(await collect(textSamples(utf8)),[{timestamp:'-1',bits:'18446744073709551615'},{timestamp:'0',bits:'0'}]);await fs.writeFile(utf8,Buffer.from([0xff]));await assert.rejects(collect(textSamples(utf8)));
  const longLine='0'.repeat(4094)+' 0';await fs.writeFile(utf8,longLine+'\n');assert.deepEqual(await collect(textSamples(utf8)),[{timestamp:'0',bits:'0'}]);
  for(const text of [longLine+'0\n',longLine+'0','\n'.repeat(65530)+longLine+'0\n']){await fs.writeFile(utf8,text);await assert.rejects(collect(textSamples(utf8)),/Input line length limit/);}
  checks.push('strict UTF-8, exact integer text input and fragment-independent line limits');
  const cli=fileURLToPath(new URL('./archive-cli.mjs',import.meta.url));
  function run(args,input='',status=0){const result=spawnSync(process.execPath,[cli,...args],{input,encoding:'utf8',windowsHide:true,timeout:10000});assert.equal(result.status,status,result.stderr);return result;}
  const cliOut=path.join(temporary,'cli.gor2');run(['encode','-',cliOut,'--block-size','2'],'-1 18446744073709551615\n0 0\n');assert.equal(run(['decode',cliOut]).stdout,'-1 18446744073709551615\n0 0\n');assert.equal(run(['range',cliOut,'-1','-1']).stdout,'-1 18446744073709551615\n');assert.equal(JSON.parse(run(['verify',cliOut]).stdout).samples,'2');assert.equal(JSON.parse(run(['info',cliOut]).stdout).blocks,1);run(['decode',bad],'',1);checks.push('actual CLI encode/stdin/decode/range/verify/info and failure exit');
  const report={utc:new Date().toISOString(),referenceMode:golden?'saved independent container vectors':'live independent Python container / Go payload',passed:checks.length,checks,samplesInStreamingCase:100000};await fs.writeFile(new URL('../evidence/archive-validation.json',import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(`${checks.length} archive integration groups passed`);
}finally{if(path.dirname(path.resolve(temporary))!==path.resolve(os.tmpdir())||!path.basename(temporary).startsWith('gorilla-archive-'))throw Error('Unsafe cleanup path');await fs.rm(temporary,{recursive:true,force:true});}
