import fs from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {archive_json,codec_json} from '../web/engine.mjs';

export class ArchiveError extends Error {constructor(message,code='ARCHIVE_ERROR'){super(message);this.name='ArchiveError';this.code=code;}}
const json=value=>JSON.stringify(value,(_,v)=>typeof v==='bigint'?v.toString():v);
function bridge(request){const result=JSON.parse(archive_json(json(request)));if(!result.ok)throw new ArchiveError(result.error);return result.result;}
const abort=signal=>{if(signal?.aborted)throw new ArchiveError('Operation aborted','ABORT_ERR');};
function decimal(value,name,signed=true){
  if(typeof value==='number'&&!Number.isSafeInteger(value))throw new TypeError(`${name} must be an exact integer, BigInt or decimal string`);
  const text=String(value);if(!/^-?\d+$/.test(text))throw new TypeError(`${name} must be decimal`);
  const n=BigInt(text);if(n<(signed?-(1n<<63n):0n)||n>(signed?(1n<<63n)-1n:(1n<<64n)-1n))throw new RangeError(`${name} out of range`);return n.toString();
}
function canonical(sample){return {timestamp:decimal(sample.timestamp,'timestamp'),bits:decimal(sample.bits,'bits',false)};}
export function encodeXor(samples){const result=JSON.parse(codec_json(json({operation:'encode',format:'xor',samples:samples.map(canonical)})));if(!result.ok)throw new ArchiveError(result.error);return Buffer.from(result.result.hex,'hex');}
export function decodeXor(bytes,{strict=true}={}){const result=JSON.parse(codec_json(json({operation:'decode',format:'xor',hex:Buffer.from(bytes).toString('hex'),strict})));if(!result.ok)throw new ArchiveError(result.error);return result.result.samples;}

async function writeAll(handle,bytes){let pos=0;while(pos<bytes.length){const {bytesWritten}=await handle.write(bytes,pos,bytes.length-pos);if(!bytesWritten)throw new ArchiveError('Short write');pos+=bytesWritten;}}
async function readExact(handle,position,length){const bytes=Buffer.alloc(length);let offset=0;while(offset<length){const {bytesRead}=await handle.read(bytes,offset,length-offset,position+offset);if(!bytesRead)throw new ArchiveError('Truncated file');offset+=bytesRead;}return bytes;}

/** Stream an async iterable into a complete GOR2 archive. A same-directory
 * temporary file is synced before atomic no-overwrite hard-link publication. */
export async function writeArchive(filename,samples,{blockSize=4096,signal}={}){
  abort(signal);const output=path.resolve(filename),temporary=path.join(path.dirname(output),`.${path.basename(output)}.${randomUUID()}.tmp`);
  const opened=bridge({operation:'encoder',blockSize});let handle;let count=0n,bytes=0,published=false,created=false;
  try{
    handle=await fs.open(temporary,'wx');created=true;const put=async data=>{abort(signal);await writeAll(handle,data);bytes+=data.length;};await put(Buffer.from(opened.hex,'hex'));
    let batch=[];const flush=async()=>{if(!batch.length)return;for(const hex of bridge({operation:'append',session:opened.session,samples:batch}))await put(Buffer.from(hex,'hex'));count+=BigInt(batch.length);batch=[];};
    for await(const sample of samples){abort(signal);batch.push(canonical(sample));if(batch.length>=512)await flush();}
    await flush();await put(Buffer.from(bridge({operation:'finish',session:opened.session}),'hex'));await handle.sync();await handle.close();handle=undefined;abort(signal);
    await fs.link(temporary,output);published=true;return {output,samples:count.toString(),bytes};
  }finally{
    bridge({operation:'close',session:opened.session});await handle?.close();if(created)await fs.unlink(temporary).catch(error=>{if(error.code!=='ENOENT'&&!published)throw error;});
  }
}

/** Read samples with bounded compressed input and per-block validation.
 * Completion proves the final index/trailer. Early iterator return closes input
 * but deliberately does not claim to have verified the unread suffix. */
export async function* readArchive(filename,{signal}={}){
  abort(signal);const {session}=bridge({operation:'decoder'});const stream=createReadStream(filename,{highWaterMark:8192,signal});
  try{for await(const bytes of stream){abort(signal);for(const sample of bridge({operation:'feed',session,hex:bytes.toString('hex')}))yield sample;}bridge({operation:'finish',session});}
  finally{stream.destroy();bridge({operation:'close',session});}
}

export class ArchiveFile {
  #handle;#session;#entries;#closed=false;#active=0;
  constructor(handle,session,entries,size){this.#handle=handle;this.#session=session;this.#entries=entries;this.size=size;this.bytesRead=20+entries.length*36+12;}
  static async open(filename){
    const handle=await fs.open(filename,'r');let session;
    try{
      const stat=await handle.stat();if(!stat.isFile()||stat.size<32||!Number.isSafeInteger(stat.size))throw new ArchiveError('Invalid archive file size');
      if(!(await readExact(handle,0,8)).equals(Buffer.from('474f523201000000','hex')))throw new ArchiveError('Invalid archive header/version');
      const trailer=await readExact(handle,stat.size-12,12),length=bridge({operation:'indexLength',hex:trailer.toString('hex')});
      if(length+20>stat.size)throw new ArchiveError('Index extends before archive data');
      const index=await readExact(handle,stat.size-12-length,length);const opened=bridge({operation:'index',hex:index.toString('hex'),fileSize:String(stat.size)});session=opened.session;
      return new ArchiveFile(handle,session,opened.entries,stat.size);
    }catch(error){if(session!==undefined)bridge({operation:'close',session});await handle.close();throw error;}
  }
  get entries(){return this.#entries.map(x=>({...x}));}
  async *range(start,end,{verifyAll=false,signal}={}){
    if(this.#closed)throw new ArchiveError('Archive is closed','CLOSED');abort(signal);start=decimal(start,'start');end=decimal(end,'end');
    const selected=bridge({operation:'select',session:this.#session,start,end}),wanted=new Set(selected),indices=verifyAll?this.#entries.map((_,i)=>i):selected;this.#active++;
    try{
      for(const index of indices){abort(signal);const entry=this.#entries[index],bytes=await readExact(this.#handle,Number(entry.offset),entry.length);this.bytesRead+=bytes.length;
        const samples=bridge({operation:'block',session:this.#session,index,hex:bytes.toString('hex')});
        if(wanted.has(index))for(const sample of samples){const time=BigInt(sample.timestamp);if(time>=BigInt(start)&&time<=BigInt(end))yield sample;}
      }
    }finally{this.#active--;}
  }
  async verify(options={}){let count=0n;for await(const _ of this.range(-(1n<<63n),(1n<<63n)-1n,{...options,verifyAll:true}))count++;return {samples:count.toString(),blocks:this.#entries.length,bytesRead:this.bytesRead};}
  async close(){if(this.#closed)return;if(this.#active)throw new ArchiveError('Close active iterators before closing the archive','BUSY');this.#closed=true;bridge({operation:'close',session:this.#session});await this.#handle.close();}
}

/** Strict UTF-8 text input, without loading the entire source file. */
export async function* textSamples(filename,{signal}={}){
  const stream=filename==='-'?process.stdin:createReadStream(filename,{highWaterMark:65536,signal});const decoder=new TextDecoder('utf-8',{fatal:true});let buffer='',line=0;
  function parse(text){line++;if(text.length>4096)throw new ArchiveError('Input line length limit');text=text.trim();if(!text)return;const fields=text.split(/\s+/);if(fields.length!==2)throw new ArchiveError(`Line ${line}: expected timestamp raw_uint64_bits`);return canonical({timestamp:fields[0],bits:fields[1]});}
  try{for await(const bytes of stream){abort(signal);buffer+=decoder.decode(bytes,{stream:true});let end;while((end=buffer.indexOf('\n'))>=0){const value=parse(buffer.slice(0,end));buffer=buffer.slice(end+1);if(value)yield value;}if(buffer.length>4096)throw new ArchiveError('Input line length limit');}buffer+=decoder.decode();if(buffer){const value=parse(buffer);if(value)yield value;}}
  finally{if(filename!=='-')stream.destroy();}
}
