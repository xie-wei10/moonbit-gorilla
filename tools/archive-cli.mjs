#!/usr/bin/env node
import fs from 'node:fs/promises';import {once} from 'node:events';import {parseArgs} from 'node:util';
import {ArchiveFile,readArchive,writeArchive,textSamples,encodeXor,decodeXor} from './archive.mjs';
const help=`Usage:
  encode INPUT.txt OUTPUT.gor2 [--block-size 4096]  Stream ordered samples to GOR2
  decode INPUT.gor2                              Stream all samples to stdout
  range INPUT.gor2 START END [--verify-all]        Indexed closed-interval query
  info INPUT.gor2                                Read the checksummed index
  verify INPUT.gor2                              Validate every indexed block
  xor-encode INPUT.txt OUTPUT.xor                Raw Prometheus XOR chunk
  xor-decode INPUT.xor                           Raw XOR samples to stdout
Input text: signed_int64_timestamp unsigned_int64_raw_value_bits; '-' uses stdin.
GOR2 writes use a same-directory temporary file and no-overwrite publication.
Range validates the index and selected blocks; --verify-all also checks others.
Streaming decode stdout is provisional until successful process exit.
`;
async function output(samples){for await(const sample of samples){if(!process.stdout.write(`${sample.timestamp} ${sample.bits}\n`))await once(process.stdout,'drain');}}
async function main(){
  // NUL cannot occur in OS argv; use it internally to distinguish signed
  // timestamp positionals from options while retaining strict option checking.
  const args=process.argv.slice(2).map(s=>/^-\d+$/.test(s)?'\0'+s:s);
  const parsed=parseArgs({args,options:{help:{type:'boolean'},'block-size':{type:'string'},'verify-all':{type:'boolean'}},allowPositionals:true});
  const values=parsed.values,positionals=parsed.positionals.map(s=>s.startsWith('\0')?s.slice(1):s);
  if(values.help){process.stdout.write(help);return;}
  const [command,input,...rest]=positionals;if(!input)throw Error(help);
  if(command==='encode'||command==='xor-encode'){
    if(rest.length!==1)throw Error(help);
    if(command==='encode'){const blockSize=values['block-size']===undefined?4096:Number(values['block-size']);if(!Number.isInteger(blockSize)||blockSize<1||blockSize>65535)throw Error('block-size must be 1..65535');console.log(JSON.stringify(await writeArchive(rest[0],textSamples(input),{blockSize})));}
    else{const samples=[];for await(const sample of textSamples(input)){if(samples.length>=65535)throw Error('XOR chunk sample limit');samples.push(sample);}const bytes=encodeXor(samples);await fs.writeFile(rest[0],bytes,{flag:'wx'});console.log(JSON.stringify({bytes:bytes.length,samples:samples.length,output:rest[0]}));}return;
  }
  if(command==='xor-decode'){if(rest.length)throw Error(help);if((await fs.stat(input)).size>2000000)throw Error('XOR byte limit');await output(decodeXor(await fs.readFile(input)));return;}
  if(command==='decode'){if(rest.length)throw Error(help);await output(readArchive(input));return;}
  if(!['range','info','verify'].includes(command)||(command==='range'?rest.length!==2:rest.length!==0))throw Error(help);
  const file=await ArchiveFile.open(input);
  try{
    if(command==='range')await output(file.range(rest[0],rest[1],{verifyAll:values['verify-all']}));
    else if(command==='verify')console.log(JSON.stringify(await file.verify()));
    else console.log(JSON.stringify({size:file.size,blocks:file.entries.length,entries:file.entries,bytesRead:file.bytesRead}));
  }finally{await file.close();}
}
main().catch(error=>{process.stderr.write(JSON.stringify({error:error.message,code:error.code})+'\n');process.exitCode=1;});
