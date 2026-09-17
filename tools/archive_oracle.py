"""Independent GOR2 container adapter: Python struct/zlib + official Go XOR codec.
The framing and index are assembled/verified here without calling MoonBit code.
"""
import sys,os,json,struct,zlib,subprocess
sys.stdin.reconfigure(encoding='utf-8');sys.stdout.reconfigure(encoding='utf-8')
request=json.load(sys.stdin)
def xor(requests):
    run=subprocess.run([os.environ['GORILLA_ORACLE']],input='\n'.join(map(json.dumps,requests))+'\n',capture_output=True,text=True,encoding='utf-8',timeout=30)
    if run.returncode:raise RuntimeError(run.stderr)
    out=[json.loads(line) for line in run.stdout.splitlines()]
    for row in out:
        if not row['ok']:raise ValueError(row['error'])
    return out
def encode(samples,block_size):
    groups=[samples[i:i+block_size] for i in range(0,len(samples),block_size)]
    payloads=xor([{'operation':'encode','samples':group} for group in groups]) if groups else []
    out=bytearray(b'GOR2\x01\0\0\0');entries=[]
    for group,result in zip(groups,payloads):
        data=bytes.fromhex(result['hex']);first=int(group[0]['timestamp']);last=int(group[-1]['timestamp'])
        frame=struct.pack('>4sIIqq',b'BLK2',len(group),len(data),first,last)+data
        checksum=zlib.crc32(frame);frame+=struct.pack('>I',checksum)
        entries.append((len(out),len(frame),len(group),first,last,checksum));out+=frame
    index=struct.pack('>4sI',b'IDX2',len(entries))+b''.join(struct.pack('>QIIqqI',*entry) for entry in entries)
    index+=struct.pack('>I',zlib.crc32(index));out+=index+struct.pack('>Q4s',len(index),b'END2');return bytes(out)
def decode(data):
    assert data[:8]==b'GOR2\x01\0\0\0';index_length,magic=struct.unpack('>Q4s',data[-12:]);assert magic==b'END2'
    index=data[-12-index_length:-12];assert zlib.crc32(index[:-4])==struct.unpack('>I',index[-4:])[0]
    marker,count=struct.unpack('>4sI',index[:8]);assert marker==b'IDX2' and len(index)==12+36*count
    previous=8;payloads=[];entries=[]
    for at in range(count):
        offset,length,num,first,last,checksum=struct.unpack('>QIIqqI',index[8+36*at:44+36*at]);assert offset==previous;previous=offset+length
        frame=data[offset:offset+length];assert len(frame)==length and zlib.crc32(frame[:-4])==checksum==struct.unpack('>I',frame[-4:])[0]
        marker,count_,payload_len,first_,last_=struct.unpack('>4sIIqq',frame[:28]);assert marker==b'BLK2' and (count_,first_,last_)==(num,first,last) and payload_len==length-32
        payloads.append({'operation':'decode','hex':frame[28:-4].hex()});entries.append((num,first,last))
    assert previous==len(data)-12-index_length
    samples=[]
    for result,(count,first,last) in zip(xor(payloads) if payloads else [],entries):
        rows=result.get('samples',[]);assert len(rows)==count and int(rows[0]['timestamp'])==first and int(rows[-1]['timestamp'])==last;samples.extend(rows)
    assert all(int(a['timestamp'])<=int(b['timestamp']) for a,b in zip(samples,samples[1:]));return samples
results=[]
for case in request:
    encoded=encode(case['samples'],case['blockSize']);decoded=decode(bytes.fromhex(case['hex']));results.append({'hex':encoded.hex(),'samples':decoded})
json.dump({'reference':'Python struct/zlib container + unmodified Prometheus XOR payload codec','results':results},sys.stdout)
