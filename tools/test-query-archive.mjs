import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {writeArchive,ArchiveFile} from './archive.mjs';
import {queryArchives,querySamples,planQuery} from './query-archive.mjs';

const temp=await fs.mkdtemp(path.join(os.tmpdir(),'gorilla-query-test-'));
const bits=value=>{const b=Buffer.alloc(8);b.writeDoubleLE(value);return b.readBigUInt64LE().toString();};
const groups=[];const passed=name=>groups.push(name);
try{
  const files=[],raw=[];
  for(const [instance,increment] of [['a',3],['b',6]]){
    const samples=Array.from({length:2048},(_,i)=>({timestamp:String(i*60000),bits:bits(i*increment)}));
    const item={metric:'requests_total',labels:[['job','api'],['instance',instance]]},file=path.join(temp,instance+'.gor2');
    await writeArchive(file,samples,{blockSize:32});files.push({...item,file});raw.push({...item,samples});
  }
  const at='1800000';let evidence;
  for(const query of ['sum(rate(requests_total[5m]))','avg_over_time(requests_total[2m] offset 1m)','requests_total @ 600000','sum(requests_total) + sum(requests_total offset 1m)','count_over_time(requests_total[2m])']){
    const report=await queryArchives({series:files,query,at});
    assert.deepEqual(report.result,querySamples({series:raw,query,at}),query);
    assert.ok(report.reads.every(r=>r.bytesRead<r.archiveBytes/2));
    assert.ok(report.samplesLoaded<raw.reduce((n,s)=>n+s.samples.length,0)/10);
    if(query.startsWith('count_'))for(const point of report.result.points)assert.equal(Number(point.value),2);
    evidence??=report;passed('full-input parity and reduced reads: '+query);
  }
  assert.equal(planQuery('2 + 3',0),null);
  const scalar=await queryArchives({series:[{...files[0],file:path.join(temp,'missing.gor2')}],query:'2 + 3',at:0});
  assert.equal(Number(scalar.result.value),5);assert.equal(scalar.reads.length,0);passed('scalar query has no archive dependency');
  await assert.rejects(queryArchives({series:files,query:'requests_total[5m]',at,maxSamples:1}),/sample limit/);
  assert.deepEqual((await queryArchives({series:files,query:'requests_total',at})).result,querySamples({series:raw,query:'requests_total',at}));passed('sample cap releases file and rejects incomplete evaluation');
  await assert.rejects(queryArchives({series:[files[0],files[0]],query:'requests_total',at}),/duplicate series/);
  await assert.rejects(queryArchives({series:[{...files[0],labels:[['__name__','other']]}],query:'requests_total',at}),/labels/);
  assert.throws(()=>planQuery('requests_total',9007199254740992n),/precision/);passed('duplicate identities reserved labels and unsafe timestamps reject');
  const bad=path.join(temp,'nan.gor2');await writeArchive(bad,[{timestamp:'0',bits:'9221120237041090626'}]);
  await assert.rejects(queryArchives({series:[{file:bad,metric:'x',labels:[]}],query:'x',at:0}),/nonfinite/);passed('NaN payload remains storable but query adapter rejects rather than drops it');
  const corrupt=path.join(temp,'corrupt.gor2');await fs.copyFile(files[0].file,corrupt);
  const archive=await ArchiveFile.open(corrupt),last=archive.entries.at(-1);await archive.close();
  const h=await fs.open(corrupt,'r+');try{const b=Buffer.alloc(1),position=Number(last.offset)+last.length-1;await h.read(b,0,1,position);b[0]^=1;await h.write(b,0,1,position);}finally{await h.close();}
  const damaged=[{...files[0],file:corrupt}];
  await queryArchives({series:damaged,query:'requests_total',at});
  await assert.rejects(queryArchives({series:damaged,query:'requests_total',at,verifyAll:true}));
  await assert.rejects(queryArchives({series:damaged,query:'requests_total',at:last.last}));passed('selected-block validation versus explicit whole-archive validation');
  const controller=new AbortController();controller.abort();await assert.rejects(queryArchives({series:files,query:'requests_total',at,signal:controller.signal}),/aborted/);passed('cancel before I/O');
  const report={upstream:'Santa968/moonpromql@0.1.0',groups:groups.length,passed:groups,selectedQuery:evidence,sourceSamples:4096,source:'original deterministic fixtures; not production telemetry'};
  const flag=process.argv.indexOf('--output');if(flag>=0)await fs.writeFile(process.argv[flag+1],JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}finally{assert.equal(path.dirname(path.resolve(temp)),path.resolve(os.tmpdir()));assert.ok(path.basename(temp).startsWith('gorilla-query-test-'));await fs.rm(temp,{recursive:true,force:true});}
