import fs from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {ArchiveFile,writeArchive} from './archive.mjs';
import {queryArchives} from './query-archive.mjs';

const EXPECTED_SOURCE_ROWS=2075259;
const EXPECTED_SOURCE_SHA256='4259c9d7ece5dbee9ab8d53682baac68d791c864f0f64a52b4043cb3b90894b7';
const MONTH_ROWS=30*24*60;
const WINDOW_MS=30*60*1000;
const HEADER='Date;Time;Global_active_power;Global_reactive_power;Voltage;Global_intensity;Sub_metering_1;Sub_metering_2;Sub_metering_3';
const SOURCE_URL='https://archive.ics.uci.edu/static/public/235/individual%2Bhousehold%2Belectric%2Bpower%2Bconsumption.zip';
const METRIC='household_global_active_power_kw';
const LABELS=[['dataset','uci-235'],['month','2007-04']];
const queries={
  count:`count_over_time(${METRIC}{dataset="uci-235",month="2007-04"}[30m])`,
  avg:`avg_over_time(${METRIC}{dataset="uci-235",month="2007-04"}[30m])`,
  min:`min_over_time(${METRIC}{dataset="uci-235",month="2007-04"}[30m])`,
  max:`max_over_time(${METRIC}{dataset="uci-235",month="2007-04"}[30m])`,
};

function usage(){throw new Error('usage: node tools/import-uci-household.mjs <household_power_consumption.txt> <new-output-directory>');}
function bitsOf(value){const bytes=Buffer.alloc(8);bytes.writeDoubleBE(value);return bytes.readBigUInt64BE().toString();}
function timestampOf(date,time,line){
  // UCI metadata describes dd/mm/yyyy; the distributed source also contains
  // valid single-digit day/month spellings such as 1/1/2007.
  const d=/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(date);
  const t=/^(\d{2}):(\d{2}):(\d{2})$/.exec(time);
  if(!d||!t)throw new Error(`line ${line}: invalid date/time field`);
  const day=Number(d[1]),month=Number(d[2]),year=Number(d[3]);
  const hour=Number(t[1]),minute=Number(t[2]),second=Number(t[3]);
  const stamp=Date.UTC(year,month-1,day,hour,minute,second);
  const check=new Date(stamp);
  if(check.getUTCFullYear()!==year||check.getUTCMonth()!==month-1||check.getUTCDate()!==day||hour>23||minute>59||second>59)throw new Error(`line ${line}: out-of-range date/time`);
  return {stamp,year,month,day,hour,minute,second};
}

async function* sourceSamples(filename,stats){
  const input=createReadStream(filename,{highWaterMark:65536});
  const decoder=new TextDecoder('utf-8',{fatal:true}),hash=createHash('sha256');
  let buffer='',line=0,headerSeen=false;
  const monthTail=[];
  const aprilStart=Date.UTC(2007,3,1,0,0,0),aprilEnd=Date.UTC(2007,4,1,0,0,0);
  const consume=text=>{
    line++;
    if(text.endsWith('\r'))text=text.slice(0,-1);
    if(!headerSeen){headerSeen=true;if(text!==HEADER)throw new Error(`line ${line}: unexpected UCI header`);return null;}
    if(text.length===0)throw new Error(`line ${line}: blank data row`);
    const fields=text.split(';');
    if(fields.length!==9)throw new Error(`line ${line}: expected 9 semicolon-separated fields, got ${fields.length}`);
    const when=timestampOf(fields[0],fields[1],line);
    stats.sourceRows++;
    const raw=fields[2].trim();
    const missing=raw===''||raw==='?';
    if(missing){
      if(raw==='?')stats.sourcePowerQuestionMissing++;
      else stats.sourcePowerBlankMissing++;
    }else if(!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(raw)||!Number.isFinite(Number(raw))){
      throw new Error(`line ${line}: invalid Global_active_power value`);
    }
    if(when.stamp>=aprilStart&&when.stamp<aprilEnd){
      const expected=stats.monthRows===0?aprilStart:stats.lastMonthTimestamp+60000;
      if(when.stamp!==expected)throw new Error(`line ${line}: April 2007 wall-clock rows are not one-minute contiguous`);
      stats.monthRows++;
      stats.lastMonthTimestamp=when.stamp;
      const value=missing?null:Number(raw);
      monthTail.push({timestamp:when.stamp,value,raw,date:fields[0],time:fields[1]});
      if(monthTail.length>31)monthTail.shift();
      if(when.stamp>=aprilStart+WINDOW_MS){
        const window=monthTail.filter(item=>item.timestamp>when.stamp-WINDOW_MS);
        const measured=window.filter(item=>item.value!==null).length;
        const left=monthTail[0];
        if(stats.queryAtMs===null&&window.length===30&&measured>0&&measured<30){
          stats.queryAtMs=String(when.stamp);
          stats.queryAtDate=fields[0];
          stats.queryAtTime=fields[1];
          stats.queryWindowRows=window.length;
          stats.queryWindowMissing=window.length-measured;
        }
        if(stats.boundaryAtMs===null&&window.length===30&&left.timestamp===when.stamp-WINDOW_MS&&left.value!==null&&value!==null){
          stats.boundaryAtMs=String(when.stamp);
          stats.boundaryAtDate=fields[0];
          stats.boundaryAtTime=fields[1];
          stats.boundaryRows=window.length;
          stats.boundarySamples={
            left:{date:left.date,time:left.time,timestampMs:String(left.timestamp),sourceValue:left.raw,bits:bitsOf(left.value)},
            right:{date:fields[0],time:fields[1],timestampMs:String(when.stamp),sourceValue:raw,bits:bitsOf(value)},
          };
        }
        if(stats.emptyQueryAtMs===null&&window.length===30&&measured===0){
          stats.emptyQueryAtMs=String(when.stamp);
          stats.emptyQueryAtDate=fields[0];
          stats.emptyQueryAtTime=fields[1];
          stats.emptyQueryRows=window.length;
        }
      }
      if(missing){
        if(raw==='?')stats.monthPowerQuestionMissing++;
        else stats.monthPowerBlankMissing++;
        return null;
      }
      const numeric=Number(raw),bits=bitsOf(numeric);
      stats.monthSamples++;
      if(stats.pointProbe===null){
        stats.pointProbe={date:fields[0],time:fields[1],timestampMs:String(when.stamp),sourceValue:raw,bits};
      }
      return {timestamp:String(when.stamp),bits};
    }
    return null;
  };
  try{
    for await(const bytes of input){
      hash.update(bytes);stats.sourceBytes+=bytes.length;
      buffer+=decoder.decode(bytes,{stream:true});
      if(buffer.length>8192&&!buffer.includes('\n'))throw new Error('source row exceeds 8192 decoded characters');
      let end;
      while((end=buffer.indexOf('\n'))>=0){const value=consume(buffer.slice(0,end));buffer=buffer.slice(end+1);if(value)yield value;}
    }
    buffer+=decoder.decode();
    if(buffer.length){const value=consume(buffer);if(value)yield value;}
  }finally{input.destroy();}
  if(!headerSeen)throw new Error('empty source file');
  stats.sourceSha256=hash.digest('hex');
  if(stats.sourceSha256!==EXPECTED_SOURCE_SHA256)throw new Error(`source SHA-256 differs from pinned UCI text: expected ${EXPECTED_SOURCE_SHA256}, got ${stats.sourceSha256}`);
  if(stats.sourceRows!==EXPECTED_SOURCE_ROWS)throw new Error(`expected ${EXPECTED_SOURCE_ROWS} source rows, got ${stats.sourceRows}`);
  if(stats.monthRows!==MONTH_ROWS)throw new Error(`expected ${MONTH_ROWS} April 2007 wall-clock rows, got ${stats.monthRows}`);
  if(stats.monthSamples+stats.monthPowerBlankMissing+stats.monthPowerQuestionMissing!==MONTH_ROWS)throw new Error('April sample and missing-value accounting does not sum to its calendar rows');
  if(!stats.pointProbe)throw new Error('April 2007 contains no non-missing Global_active_power sample');
  if(stats.queryAtMs===null)throw new Error('April 2007 has no 30-minute window with both measured and missing Global_active_power values');
  if(stats.boundaryAtMs===null)throw new Error('April 2007 has no 30-minute window with measured samples at both exact range endpoints');
  if(stats.emptyQueryAtMs===null)throw new Error('April 2007 has no fully missing 30-minute Global_active_power window');
}

async function fileSha256(filename){const hash=createHash('sha256');for await(const chunk of createReadStream(filename))hash.update(chunk);return hash.digest('hex');}
function pointValue(result,name){
  if(result.kind!=='instant'||result.points?.length!==1)throw new Error(`${name}: expected exactly one instant-vector point; got ${JSON.stringify(result)}`);
  const value=Number(result.points[0].value);if(!Number.isFinite(value))throw new Error(`${name}: non-finite result`);return value;
}

const [sourceArg,outputArg]=process.argv.slice(2);
if(!sourceArg||!outputArg||process.argv.length!==4)usage();
const source=path.resolve(sourceArg),output=path.resolve(outputArg);
await fs.mkdir(output,{recursive:false});
const archivePath=path.join(output,'global-active-power.gor2'),stagingArchivePath=path.join(output,'.global-active-power.gor2.partial');
let archiveCreated=false,success=false;
const stats={sourceRows:0,sourceBytes:0,sourceSha256:null,sourcePowerBlankMissing:0,sourcePowerQuestionMissing:0,monthRows:0,monthSamples:0,monthPowerBlankMissing:0,monthPowerQuestionMissing:0,lastMonthTimestamp:null,pointProbe:null,queryAtMs:null,queryAtDate:null,queryAtTime:null,queryWindowRows:0,queryWindowMissing:0,boundaryAtMs:null,boundaryAtDate:null,boundaryAtTime:null,boundaryRows:0,boundarySamples:null,emptyQueryAtMs:null,emptyQueryAtDate:null,emptyQueryAtTime:null,emptyQueryRows:0};
try{
  const sourceStat=await fs.stat(source);
  const write=await writeArchive(stagingArchivePath,sourceSamples(source,stats),{blockSize:512});
  await fs.rename(stagingArchivePath,archivePath);archiveCreated=true;
  if(sourceStat.size!==stats.sourceBytes)throw new Error('source byte count changed between initial stat and complete stream read');
  const archiveStat=await fs.stat(archivePath),archiveSha256=await fileSha256(archivePath);
  const pointFile=await ArchiveFile.open(archivePath);
  try{
    let restored=null;
    for await(const sample of pointFile.range(stats.pointProbe.timestampMs,stats.pointProbe.timestampMs))restored=sample;
    if(!restored||restored.bits!==stats.pointProbe.bits)throw new Error('GOR2 exact-point bit/timestamp probe failed');
  }finally{await pointFile.close();}
  const series=[{file:archivePath,metric:METRIC,labels:LABELS}];
  const queryResults={};
  for(const [name,query] of Object.entries(queries)){
    const report=await queryArchives({series,query,at:stats.queryAtMs,maxSamples:1000});
    const read=report.reads[0];
    if(!read)throw new Error(`${name}: no archive read was reported`);
    queryResults[name]={query,atMs:stats.queryAtMs,window:report.window,value:pointValue(report.result,name),samplesLoaded:report.samplesLoaded,bytesRead:read.bytesRead,archiveBytes:read.archiveBytes};
  }
  const boundaryQueries={};
  for(const [name,query] of Object.entries(queries)){
    const report=await queryArchives({series,query,at:stats.boundaryAtMs,maxSamples:1000}),read=report.reads[0];
    if(!read)throw new Error(`${name} boundary window: no archive read was reported`);
    boundaryQueries[name]={query,atMs:stats.boundaryAtMs,window:report.window,value:pointValue(report.result,name),samplesLoaded:report.samplesLoaded,bytesRead:read.bytesRead,archiveBytes:read.archiveBytes};
  }
  const emptyQueries={};
  for(const name of ['count','avg']){
    const query=queries[name],report=await queryArchives({series,query,at:stats.emptyQueryAtMs,maxSamples:1000}),read=report.reads[0];
    if(report.result.kind!=='instant'||report.result.points.length!==0)throw new Error(`all-missing ${name} window must return an empty instant vector, got ${JSON.stringify(report.result)}`);
    emptyQueries[name]={query,atMs:stats.emptyQueryAtMs,window:report.window,resultKind:report.result.kind,points:report.result.points.length,samplesLoaded:report.samplesLoaded,bytesRead:read.bytesRead,archiveBytes:read.archiveBytes};
  }
  const result={
    schemaVersion:'uci-household-gor2-v1',
    source:{url:SOURCE_URL,archiveName:'individual+household+electric+power+consumption.zip',license:'CC BY 4.0',expectedSha256:EXPECTED_SOURCE_SHA256,matchesPinnedSource:stats.sourceSha256===EXPECTED_SOURCE_SHA256,citation:'Hebrail, G. & Berard, A. (2006). Individual Household Electric Power Consumption [Dataset]. UCI Machine Learning Repository. DOI:10.24432/C58K54.',rows:stats.sourceRows,bytes:stats.sourceBytes,sha256:stats.sourceSha256,globalActivePowerMissing:{blank:stats.sourcePowerBlankMissing,questionMark:stats.sourcePowerQuestionMissing}},
    selection:{column:'Global_active_power',unit:'kW',month:'2007-04',rows:stats.monthRows,encodedSamples:stats.monthSamples,missing:{blank:stats.monthPowerBlankMissing,questionMark:stats.monthPowerQuestionMissing},timeCoordinate:'Gregorian wall-clock fields encoded as milliseconds using UTC calendar arithmetic; not a claim that the source data are UTC',firstMs:String(Date.UTC(2007,3,1,0,0,0)),lastMs:String(Date.UTC(2007,4,1,0,0,0)-60000),rowSpacingMs:60000,pointProbe:stats.pointProbe,queryWindowSelection:{policy:'first 30-minute April window containing both measured and missing Global_active_power rows',date:stats.queryAtDate,time:stats.queryAtTime,atMs:stats.queryAtMs,calendarRows:stats.queryWindowRows,missingRows:stats.queryWindowMissing},boundaryWindow:{policy:'first 30-minute April window with a measured sample at both exact range endpoints',date:stats.boundaryAtDate,time:stats.boundaryAtTime,atMs:stats.boundaryAtMs,calendarRows:stats.boundaryRows,boundaries:stats.boundarySamples},allMissingWindow:{date:stats.emptyQueryAtDate,time:stats.emptyQueryAtTime,atMs:stats.emptyQueryAtMs,calendarRows:stats.emptyQueryRows,expectedMeasuredSamples:0}},
    archive:{format:'GOR2',file:'global-active-power.gor2',blockSize:512,samples:write.samples,bytes:archiveStat.size,sha256:archiveSha256},
    query:{engine:'MoonPromQL 0.1.0 via tools/query-archive.mjs',rangeSemantics:'Prometheus range vector: (start, end]',offline:true,series:1,querySampleLimit:1000,queries:queryResults,boundaryWindow:boundaryQueries,allMissingWindow:emptyQueries},
  };
  await fs.writeFile(path.join(output,'run.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
  success=true;
  console.log(JSON.stringify({output,sourceRows:stats.sourceRows,sourceBytes:stats.sourceBytes,sourceSha256:stats.sourceSha256,monthRows:stats.monthRows,monthSamples:stats.monthSamples,monthMissing:stats.monthPowerBlankMissing+stats.monthPowerQuestionMissing,archiveBytes:archiveStat.size,archiveSha256,queryResults},null,2));
}finally{
  if(!success){
    await fs.unlink(stagingArchivePath).catch(()=>{});
    if(archiveCreated)await fs.unlink(archivePath).catch(()=>{});
    await fs.unlink(path.join(output,'run.json')).catch(()=>{});
    await fs.rmdir(output).catch(()=>{});
  }
}
