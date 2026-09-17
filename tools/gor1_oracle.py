"""Independent GOR1 specification model in Python, not an upstream format.
Uses Python bit strings and arbitrary-precision arithmetic instead of MoonBit's
packed-byte state machine. The format contract is documented in FORMAT.md.
"""
import json,sys
sys.stdin.reconfigure(encoding='utf-8');sys.stdout.reconfigure(encoding='utf-8')
MASK=(1<<64)-1
def encode(samples):
    parts=['01000111010011110101001000110001',format(len(samples),'032b')]
    def put(n,width):parts.append(format(n&((1<<width)-1),'0%db'%width))
    previous=0;time=0;delta=0;window=None
    for i,row in enumerate(samples):
        t=int(row['timestamp']);value=int(row['bits'])
        if not 0<=t<=(1<<53)-1 or i and t<time:raise ValueError('timestamp range/order')
        if i==0:put(t,64);put(value,64)
        else:
            difference=t-time-delta
            if difference==0:parts.append('0')
            else:
                for low,high,prefix,width in [(-63,64,'10',7),(-255,256,'110',9),(-2047,2048,'1110',12)]:
                    if low<=difference<=high:parts.append(prefix);put(difference-low,width);break
                else:parts.append('1111');put(difference,64)
            changed=value^previous
            if not changed:parts.append('0')
            else:
                leading=64-changed.bit_length();trailing=(changed&-changed).bit_length()-1
                if window and leading>=window[0] and trailing>=window[1]:parts.append('10');put(changed>>window[1],64-sum(window))
                else:parts.append('11');window=(leading,trailing);put(leading,6);put((64-leading-trailing)%64,6);put(changed>>trailing,64-leading-trailing)
            delta=t-time
        time=t;previous=value
    bits=''.join(parts);bits+='0'*((-len(bits))%8);return int(bits,2).to_bytes(len(bits)//8,'big')
def decode(data):
    bits=''.join(format(b,'08b') for b in data);position=0
    def get(width):
        nonlocal position
        if position+width>len(bits):raise ValueError('truncated')
        text=bits[position:position+width];position+=width;return int(text,2) if text else 0
    assert get(32)==0x474f5231;count=get(32);assert count<=100000
    samples=[];time=delta=value=0;window=None
    for i in range(count):
        if i==0:time=get(64);value=get(64)
        else:
            ones=0
            while ones<4 and get(1):ones+=1
            if ones==0:difference=0
            elif ones<4:width,bias=[(7,63),(9,255),(12,2047)][ones-1];difference=get(width)-bias
            else:difference=get(64);difference=difference-(1<<64) if difference>>63 else difference
            delta+=difference;assert delta>=0;time+=delta
            if get(1):
                if get(1):leading=get(6);width=get(6) or 64;trailing=64-leading-width;assert trailing>=0;window=(leading,trailing)
                assert window is not None;value^=get(64-sum(window))<<window[1]
        assert 0<=time<=(1<<53)-1;samples.append({'timestamp':str(time),'bits':str(value)})
    assert len(bits)-position<8 and '1' not in bits[position:];return samples
result=[]
for case in json.load(sys.stdin):result.append({'hex':encode(case['samples']).hex(),'samples':decode(bytes.fromhex(case['hex']))})
json.dump(result,sys.stdout)
