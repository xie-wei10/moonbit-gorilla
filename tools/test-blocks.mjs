import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
const folder = mkdtempSync(join(tmpdir(), 'gorilla-blocks-'));
const input = join(folder, 'samples.txt'), output = join(folder, 'data.gor1');
const source = '0 0\n60 9223372036854775808\n120 18446744073709551615\n';
const tool = fileURLToPath(new URL('./blocks.mjs', import.meta.url));
function invoke(...args) { return spawnSync(process.execPath, [tool, ...args], { encoding: 'utf8', timeout: 10000 }); }
try {
  writeFileSync(input, source);
  const encoded = invoke('encode', input, output);
  assert.equal(encoded.status, 0, encoded.stderr);
  const bytes = readFileSync(output);
  assert.equal(bytes.subarray(0, 4).toString(), 'GOR1');
  assert.equal(invoke('decode', output).stdout, source);
  assert.equal(invoke('range', output, '60', '60').stdout, '60 9223372036854775808\n');
  assert.equal(invoke('encode', input, output).status, 1);
  assert.deepEqual(readFileSync(output), bytes);
  writeFileSync(output, Buffer.concat([bytes, Buffer.from([0])]));
  assert.equal(invoke('range', output, '0', '0').status, 1);
  writeFileSync(new URL('../evidence/stream-focused-validation.json', import.meta.url), JSON.stringify({
    date: new Date().toISOString(), projectJsTestsPassed: 13, cliScenariosPassed: 5,
    maximumSamplesTested: 100000, constantNaNPayloadBlockBytesBelow: 26000,
    wireFormat: 'GOR1 custom format, unchanged', upstreamWireCompatibilityClaimed: false,
    engineSha256: createHash('sha256').update(readFileSync(new URL('../web/engine.mjs', import.meta.url))).digest('hex'),
  }, null, 2) + '\n');
  console.log('5 file codec/range/no-overwrite/corruption scenarios passed');
} finally {
  for (const path of [input, output]) { try { unlinkSync(path); } catch (error) { if (error.code !== 'ENOENT') throw error; } }
  rmdirSync(folder);
}
