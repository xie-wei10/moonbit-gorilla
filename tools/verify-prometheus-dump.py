"""Independent Python text/IEEE754/window oracle for the upstream fixture.

The label parser here covers only this fixed upstream fixture; MoonBit's parser
has separate escaped-label and invalid-input tests. Query execution is upstream
MoonPromQL, while this finite mean is calculated directly from the source rows.
"""
from pathlib import Path
import hashlib
import json
import re
import struct
import subprocess
import tempfile
import argparse

ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--evidence',default='evidence/public-prometheus.json');args=parser.parse_args()
    source=ROOT/'examples/prometheus/dump-test-1.prom';data=source.read_bytes()
    meta=json.loads((source.parent/'SOURCE.json').read_text(encoding='utf-8'))
    assert hashlib.sha256(data).hexdigest()==meta['sha256']
    groups={}
    for line in data.decode().splitlines():
        match=re.fullmatch(r'\{(.+)\}\s+([^ ]+)\s+(-?\d+)',line);assert match
        pairs=re.findall(r'(\w+)="([^"\\]*)"',match[1])
        assert ', '.join(f'{k}="{v}"' for k,v in pairs)==match[1]
        labels=dict(pairs);metric=labels.pop('__name__');labels=sorted(labels.items());key=(metric,tuple(labels))
        bits=struct.unpack('<Q',struct.pack('<d',float(match[2])))[0]
        groups.setdefault(key,[]).append(dict(timestamp=match[3],bits=str(bits)))
    with tempfile.TemporaryDirectory(prefix='gorilla-prometheus-') as temporary:
        output=Path(temporary)/'archive'
        run=subprocess.run(['node','examples/run-prometheus-dump.mjs',str(output)],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        assert run.returncode==0,run.stderr
        imported=json.loads((output/'imported.json').read_text(encoding='utf-8'))
        assert len(imported)==len(groups)
        for series in imported:assert series['samples']==groups[(series['metric'],tuple(map(tuple,series['labels'])))]
        report=json.loads((output/'query.json').read_text(encoding='utf-8'))
        expected_samples=groups[('heavy_metric',(('foo','bar'),))]
        values=[struct.unpack('<d',struct.pack('<Q',int(x['bits'])))[0] for x in expected_samples if 60000<int(x['timestamp'])<=180000]
        assert len(values)==2 and sum(values)/len(values)==2.5
        assert len(report['result']['points'])==1 and float(report['result']['points'][0]['value'])==2.5
        assert report['window']=={'start':'60000','end':'180000'} and report['samplesLoaded']==9
    receipt=dict(source=meta,rows=15,series=3,bitValuesCompared=15,window='(60000,180000]',expectedMean=2.5,loadedSamples=9,
                 oracle='Python text/struct and explicit source-row mean; actual GOR2 file roundtrip and pinned MoonPromQL',
                 limits=['tiny upstream synthetic fixture, not production telemetry','no general performance claim','query engine belongs to MoonPromQL'])
    out=Path(args.evidence);out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(json.dumps(receipt,indent=2))
if __name__=='__main__':main()
