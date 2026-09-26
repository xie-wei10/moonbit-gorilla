import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {importPromtoolDump} from '../tools/import-promtool.mjs';
import {queryArchives,querySamples} from '../tools/query-archive.mjs';
import {readArchive} from '../tools/archive.mjs';
import assert from 'node:assert/strict';
const output=process.argv[2];
if(!output)throw Error('Usage: node examples/run-prometheus-dump.mjs NEW_DIRECTORY');
const input=fileURLToPath(new URL('./prometheus/dump-test-1.prom',import.meta.url));
const {manifest,series,raw}=await importPromtoolDump(input,output,{blockSize:2});
for(const [i,item] of series.entries()){
  const samples=[];for await(const sample of readArchive(item.file))samples.push(sample);
  assert.deepEqual(samples,raw[i].samples);
}
const query='avg_over_time(heavy_metric{foo="bar"}[2m])',at=180000;
const selected=await queryArchives({series,query,at});
assert.deepEqual(selected.result,querySamples({series:raw,query,at}));
const report={source:'Prometheus upstream test fixture; no production data claim',
  inputSamples:manifest.samples,bitExactRoundtrip:true,...selected};
await fs.writeFile(path.join(output,'query.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
await fs.writeFile(path.join(output,'imported.json'),JSON.stringify(raw,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({samples:manifest.samples,series:series.length,result:selected.result,samplesLoaded:selected.samplesLoaded,output}));
