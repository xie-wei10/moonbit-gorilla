import {ArchiveFile} from './archive.mjs';
import {query_json} from '../web/moonpromql-engine.mjs';

const call=request=>{const response=JSON.parse(query_json(JSON.stringify(request)));if(!response.ok)throw Error(response.error);return response.result;};
function exactTime(value){if(!['number','bigint','string'].includes(typeof value)||(typeof value==='number'&&!Number.isSafeInteger(value))||(typeof value==='string'&&!/^-?\d+$/.test(value)))throw TypeError('at must be an exact integer millisecond timestamp');const n=BigInt(value);if(n < -9007199254740991n || n > 9007199254740991n)throw RangeError('at loses Double precision');return n.toString();}
/** Pure MoonBit import of bounded finite-sample promtool tsdb dump text. */
export function parsePromtoolDump(source){if(typeof source!=='string')throw TypeError('source must be text');return call({action:'import-dump',source});}
export function planQuery(query,at){return call({action:'plan',query,at:exactTime(at)});}
/** Query an explicitly supplied set of per-series GOR2 files. Reads the complete
 * conservative union planned from the pinned upstream AST, with no label pushdown.
 * This is an archive adapter, not a discovery service or TSDB server. */
export async function queryArchives({series,query,at,verifyAll=false,maxSamples=100000,signal}){
  at=exactTime(at);
  if(!Array.isArray(series)||series.length>64)throw RangeError('at most 64 series');
  if(!Number.isInteger(maxSamples)||maxSamples<1||maxSamples>100000)throw RangeError('maxSamples must be 1..100000');
  const identities=new Set();
  for(const item of series){
    if(typeof item.metric!=='string'||!item.metric.length||item.metric.length>256||typeof item.file!=='string'||!Array.isArray(item.labels)||item.labels.length>64)throw TypeError('invalid series metadata');
    const seen=new Set();
    for(const pair of item.labels){if(!Array.isArray(pair)||pair.length!==2||pair.some(x=>typeof x!=='string')||!pair[0]||pair[0]==='__name__'||pair[0].length>256||pair[1].length>1024||seen.has(pair[0]))throw TypeError('invalid/duplicate/reserved labels');seen.add(pair[0]);}
    const key=JSON.stringify([item.metric,[...item.labels].sort((a,b)=>a[0]<b[0]?-1:a[0]>b[0]?1:0)]);
    if(identities.has(key))throw TypeError('duplicate series identity');identities.add(key);
  }
  if(signal?.aborted)throw Error('query aborted');
  const window=planQuery(query,at),loaded=[],reads=[];let count=0;
  if(window)for(const item of series){
    const file=await ArchiveFile.open(item.file);
    try {
      const samples=[];
      for await(const sample of file.range(window.start,window.end,{verifyAll,signal})){
        if(++count>maxSamples)throw RangeError('aggregate sample limit');samples.push(sample);
      }
      loaded.push({metric:item.metric,labels:item.labels,samples});
      reads.push({file:item.file,archiveBytes:file.size,bytesRead:file.bytesRead,samples:samples.length,allBlocksVerified:verifyAll});
    } finally {await file.close();}
  }
  if(signal?.aborted)throw Error('query aborted');
  return {query,at,window,result:call({action:'evaluate',query,at,series:loaded}),samplesLoaded:count,reads};
}
/** Independent full-input baseline for examples/tests, using the same upstream
 * evaluator, without Gorilla storage or pruning. Values remain raw bit strings. */
export function querySamples({series,query,at}){return call({action:'evaluate',query,at:exactTime(at),series});}
