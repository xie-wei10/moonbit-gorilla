import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {writeArchive,readArchive} from '../tools/archive.mjs';
import {queryArchives,querySamples} from '../tools/query-archive.mjs';

// Actual measurements of this example process, not claimed customer telemetry.
const output=await fs.mkdtemp(path.join(os.tmpdir(),'gorilla-metrics-'));
const bits=value=>{const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);return bytes.readBigUInt64LE().toString();};
const data={rss:[],heap:[]};
for(let i=0;i<24;i++){
  const timestamp=String(Date.now()),memory=process.memoryUsage();
  data.rss.push({timestamp,bits:bits(memory.rss)});data.heap.push({timestamp,bits:bits(memory.heapUsed)});
  await new Promise(resolve=>setTimeout(resolve,10));
}
const files=[],raw=[],writes=[];
for(const [kind,samples] of Object.entries(data)){
  const file=path.join(output,`${kind}.gor2`),metric='process_memory_bytes',labels=[['kind',kind]];
  writes.push(await writeArchive(file,samples,{blockSize:8}));files.push({file,metric,labels});raw.push({metric,labels,samples});
  const restored=[];for await(const sample of readArchive(file))restored.push(sample);
  assert.deepEqual(restored,samples);
}
const query='avg_over_time(process_memory_bytes[1s])',at=data.rss.at(-1).timestamp;
const report=await queryArchives({series:files,query,at,verifyAll:true});
assert.deepEqual(report.result,querySamples({series:raw,query,at}));
assert.equal(report.result.points.length,2);
await fs.writeFile(path.join(output,'manifest.json'),JSON.stringify({timestampUnit:'milliseconds',source:'this Node process memoryUsage()',series:files.map(item=>({...item,file:path.basename(item.file)}))},null,2)+'\n');
await fs.writeFile(path.join(output,'report.json'),JSON.stringify({measurementSource:'this process only; no external user claim',samples:48,writes,bitExactRoundtrip:true,equalsUncompressedQuery:true,...report},null,2)+'\n');
console.log(JSON.stringify({output,samples:48,bitExactRoundtrip:true,equalsUncompressedQuery:true,result:report.result}));
