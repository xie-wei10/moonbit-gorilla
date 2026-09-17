"""Fetch public research inputs on request and preserve exact source fingerprints.
Raw datasets remain in the specified local directory, not in the library package.
"""
from pathlib import Path
import argparse,csv,json,hashlib,struct,datetime,urllib.request,math,random
parser=argparse.ArgumentParser();parser.add_argument('directory');parser.add_argument('--download',action='store_true');args=parser.parse_args()
directory=Path(args.directory);directory.mkdir(parents=True,exist_ok=True)
sources={
 'noaa-co2.csv':('https://gml.noaa.gov/webdata/ccgg/trends/co2/co2_daily_mlo.csv','NOAA GML / Xin Lan and Scripps / Ralph Keeling; https://gml.noaa.gov/ccgg/trends/data.html'),
 'usgs-quakes.csv':('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2025-01-01&endtime=2025-02-01&minmagnitude=2.5&orderby=time-asc','USGS Earthquake Catalog; https://earthquake.usgs.gov/fdsnws/event/1/'),
}
metadata={}
for name,(url,credit) in sources.items():
    file=directory/name
    if args.download:
        data=urllib.request.urlopen(url,timeout=60).read(5000001)
        if len(data)>5000000:raise ValueError('source size limit')
        file.write_bytes(data)
    data=file.read_bytes();metadata[name]={'url':url,'credit':credit,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
epoch=datetime.datetime(1970,1,1,tzinfo=datetime.timezone.utc)
def millis(dt):
    delta=dt-epoch;return delta.days*86400000+delta.seconds*1000+delta.microseconds//1000
def sample(t,value):return {'timestamp':str(t),'bits':str(struct.unpack('>Q',struct.pack('>d',value))[0])}
datasets=[];rows=[]
with (directory/'noaa-co2.csv').open(encoding='utf-8') as stream:
    for row in csv.reader(line for line in stream if not line.startswith('#')):
        if not row:continue
        year,month,day=map(int,row[:3]);value=float(row[4])
        if value>=0:rows.append(sample(millis(datetime.datetime(year,month,day,tzinfo=datetime.timezone.utc)),value))
datasets.append({'name':'NOAA Mauna Loa daily CO2','source':'noaa-co2.csv','kind':'observed','samples':rows,'conversion':'UTC midnight milliseconds and float64 ppm; missing negative values excluded'})
with (directory/'usgs-quakes.csv').open(encoding='utf-8') as stream:events=list(csv.DictReader(stream))
for field in ['mag','depth']:
    rows=[sample(millis(datetime.datetime.fromisoformat(row['time'].replace('Z','+00:00'))),float(row[field])) for row in events if row[field]]
    datasets.append({'name':'USGS January 2025 '+field,'source':'usgs-quakes.csv','kind':'observed','samples':rows,'conversion':'UTC event milliseconds; float64 '+field+'; empty values excluded'})
rng=random.Random(1749)
for name,values in [('regular counter',(float(i) for i in range(20000))),('periodic signal',(math.sin(i/100) for i in range(20000))),('uniform noise',(rng.random() for _ in range(20000)))]:
    datasets.append({'name':name,'kind':'synthetic','samples':[sample(1700000000000+i*15000,value) for i,value in enumerate(values)]})
for dataset in datasets:
    assert 0<len(dataset['samples'])<=65535
    assert all(int(a['timestamp'])<=int(b['timestamp']) for a,b in zip(dataset['samples'],dataset['samples'][1:]))
result={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sources':metadata,'datasets':datasets}
(directory/'datasets.json').write_text(json.dumps(result),encoding='utf-8')
print(json.dumps({dataset['name']:len(dataset['samples']) for dataset in datasets}))
