import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {parsePromtoolDump} from './query-archive.mjs';
import {importPromtoolDump} from './import-promtool.mjs';
const temp=await fs.mkdtemp(path.join(os.tmpdir(),'gorilla-import-'));
try {
  assert.throws(()=>parsePromtoolDump(null),/text/);
  assert.throws(()=>parsePromtoolDump('x'.repeat(4_000_001)),/4M/);
  assert.throws(()=>parsePromtoolDump('{__name__="m",x="'+'x'.repeat(17000)+'"} 1 0'),/bounded/);
  const excessive=Array.from({length:100001},(_,i)=>`{__name__="m"} 1 ${i}`).join('\n');
  assert.throws(()=>parsePromtoolDump(excessive),/aggregate sample limit/);
  const bad=path.join(temp,'bad.txt'),output=path.join(temp,'bad-output');
  for(const data of [Buffer.from([0xff]),Buffer.from('{__name__="m"} NaN 0'),Buffer.from('')]){
    await fs.writeFile(bad,data);await assert.rejects(importPromtoolDump(bad,output));
    await assert.rejects(fs.stat(output),{code:'ENOENT'});
  }
  await fs.writeFile(bad,'{__name__="m"} 1 0');
  const failed=path.join(temp,'failed-write');await assert.rejects(importPromtoolDump(bad,failed,{blockSize:0}));
  await assert.rejects(fs.stat(path.join(failed,'manifest.json')),{code:'ENOENT'});
  const imported=await importPromtoolDump(bad,output);
  assert.equal(imported.manifest.complete,true);assert.equal(imported.manifest.samples,1);
  await assert.rejects(importPromtoolDump(bad,output),{code:'EEXIST'});
  console.log('promtool import: text/sample/line budgets, invalid UTF8/nonfinite/empty, completion manifest, no overwrite passed');
} finally {
  assert.equal(path.dirname(path.resolve(temp)),path.resolve(os.tmpdir()));
  assert(path.basename(temp).startsWith('gorilla-import-'));await fs.rm(temp,{recursive:true,force:true});
}
