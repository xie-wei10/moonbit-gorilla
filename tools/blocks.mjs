import { readFileSync, writeFileSync, statSync } from 'node:fs';
import { compress_text, decompress_text } from '../web/engine.mjs';
const [mode, input, output, end, ...extra] = process.argv.slice(2);
try {
  if (!input || extra.length || !['encode', 'decode', 'range'].includes(mode) ||
      (mode === 'encode' && (!output || end !== undefined)) ||
      (mode === 'decode' && output !== undefined) || (mode === 'range' && end === undefined)) {
    throw new Error('Usage: encode samples.txt output.gor1 | decode input.gor1 | range input.gor1 START END');
  }
  if (statSync(input).size > (mode === 'encode' ? 5000000 : 2000000)) throw new Error('Input size limit exceeded');
  if (mode === 'encode') {
    const hex = compress_text(new TextDecoder('utf-8', { fatal: true }).decode(readFileSync(input)));
    if (hex.startsWith('ERROR:')) throw new Error(hex);
    const data = Buffer.from(hex, 'hex');
    writeFileSync(output, data, { flag: 'wx' });
    console.log(JSON.stringify({ bytes: data.length, output }));
  } else {
    const text = decompress_text(readFileSync(input).toString('hex'), mode === 'range' ? output : '0', mode === 'range' ? end : '9007199254740991');
    if (text.startsWith('ERROR:')) throw new Error(text);
    process.stdout.write(text);
  }
} catch (error) { console.error(error.message); process.exitCode = 1; }
