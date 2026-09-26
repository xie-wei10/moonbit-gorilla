import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parsePromtoolDump} from './query-archive.mjs';
import {writeArchive} from './archive.mjs';

/** Batch ingress for a stable, trusted finite-sample dump. A manifest is written
 * last, so a failed import must not be consumed as a completed archive set. */
export async function importPromtoolDump(input,output,{blockSize=256}={}){
  const handle=await fs.open(input,'r');let bytes;
  try {
    const stat=await handle.stat();
    if(!stat.isFile()||stat.size>4_000_000)throw Error('dump must be a regular file <=4MB');
    // Allocate only the declared cap plus one sentinel byte, even if it grows.
    const buffer=Buffer.alloc(stat.size+1);let offset=0;
    while(offset<buffer.length){const {bytesRead}=await handle.read(buffer,offset,buffer.length-offset,null);if(!bytesRead)break;offset+=bytesRead;}
    if(offset!==stat.size)throw Error('dump changed during read');bytes=buffer.subarray(0,offset);
  } finally {await handle.close();}
  const text=new TextDecoder('utf-8',{fatal:true}).decode(bytes),raw=parsePromtoolDump(text);
  if(!raw.length)throw Error('dump contains no samples');
  await fs.mkdir(output,{recursive:false});
  const files=[];
  for(const [i,item] of raw.entries()){
    const filename=`series-${i}.gor2`,file=path.join(output,filename);
    await writeArchive(file,item.samples,{blockSize});
    files.push({file:filename,metric:item.metric,labels:item.labels,samples:item.samples.length});
  }
  const manifest={format:'GOR2 finite promtool dump import',timestampUnit:'milliseconds',sourceSha256:createHash('sha256').update(bytes).digest('hex'),
    series:files,samples:raw.reduce((n,s)=>n+s.samples.length,0),complete:true,
    scope:'finite decimal samples with braced equality labels; no histograms, stale markers or full OpenMetrics/TSDB compatibility'};
  await fs.writeFile(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
  return {manifest,series:files.map(item=>({...item,file:path.join(output,item.file)})),raw};
}
