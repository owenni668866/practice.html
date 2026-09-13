#!/usr/bin/env python3
"""Build system/analyte map summaries and true grayscale CARTO vector style."""
import csv,json,collections,re,colorsys
from pathlib import Path
R=Path(__file__).resolve().parents[1]
locations=json.loads((R/'data/raw/epa/ucmr5-system-locations.json').read_text())
assert not locations.get('exceededTransferLimit')
loc={f['attributes']['F_PWS_ID']:f['attributes'] for f in locations['features']}
assert len(loc)==len(locations['features'])
groups=collections.defaultdict(list)
for r in csv.DictReader((R/'data/processed/oregon-pfas-results.csv').open()):
 if r['program']=='UCMR5':groups[r['pws_id']].append(r)
features=[];unlocated=[]
for pws,rs in sorted(groups.items()):
 point=loc.get(pws,{})
 by=collections.defaultdict(list)
 for r in rs:by[r['analyte']].append(r)
 analytes={}
 for a,ar in sorted(by.items()):
  values=[float(r['result_ng_l']) for r in ar if r['result_status']=='detected']
  analytes[a]={'n':len(ar),'detections':len(values),'max':max(values) if values else None,'mrl':sorted({float(r['mrl_ng_l']) for r in ar}),'methods':sorted({r['method'] for r in ar})}
 props={'pws_id':pws,'name':rs[0]['pws_name'],'n':len(rs),'detections':sum(x['detections'] for x in analytes.values()),'first':min(r['collection_date'] for r in rs),'last':max(r['collection_date'] for r in rs),'geolocation':point.get('UCMR_Geolocation_Method'),'analytes':analytes}
 lat,lon=point.get('Latitude'),point.get('Longitude')
 if lat is None or lon is None:unlocated.append(props);continue
 assert -125<float(lon)<-116 and 41<float(lat)<47,(pws,lat,lon)
 features.append({'type':'Feature','id':pws,'geometry':{'type':'Point','coordinates':[lon,lat]},'properties':props})
out={'type':'FeatureCollection','features':features,'unlocated':unlocated,'metadata':{'program':'UCMR5','system_count':len(groups),'located':len(features),'unlocated':len(unlocated),'record_count':sum(len(r) for r in groups.values()),'source':'EPA UCMR5 occurrence data + EPA PFAS Analytic Tools location metadata','snapshot_date':'2026-09-06'}}
(R/'data/processed/oregon-map.json').write_text(json.dumps(out,ensure_ascii=False,separators=(',',':'))+'\n')
def gray(x):
 if isinstance(x,dict):return {k:gray(v) for k,v in x.items()}
 if isinstance(x,list):return [gray(v) for v in x]
 if not isinstance(x,str):return x
 rgb=None;alpha=1
 if re.fullmatch(r'#[0-9a-fA-F]{3}|#[0-9a-fA-F]{6}',x):
  h=x[1:];h=''.join(c*2 for c in h) if len(h)==3 else h;rgb=[int(h[i:i+2],16) for i in (0,2,4)]
 elif re.match(r'^hsla?\(',x):
  vals=[float(v) for v in re.findall(r'[\d.]+',x)];rgb=[v*255 for v in colorsys.hls_to_rgb(vals[0]/360,vals[2]/100,vals[1]/100)];alpha=vals[3] if len(vals)>3 else 1
 elif re.match(r'^rgba?\(',x):
  vals=[float(v) for v in re.findall(r'[\d.]+',x)];rgb=vals[:3];alpha=vals[3] if len(vals)>3 else 1
 if rgb:
  y=round(sum(a*b for a,b in zip(rgb,[.2126,.7152,.0722])));return f'rgba({y},{y},{y},{alpha})'
 return x
style=json.loads((R/'data/reference/carto-positron-style.json').read_text())
for layer in style['layers']:
 for k,v in layer.get('paint',{}).items():
  if 'color' in k:layer['paint'][k]=gray(v)
style['name']='CARTO Positron — grayscale';style['metadata']={'source':'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json','modification':'Convert paint colors to luminance grayscale; retain vector tiles and attribution.'}
assert all(s['type']=='vector' for s in style['sources'].values())
(R/'assets/basemap.json').write_text(json.dumps(style,separators=(',',':'))+'\n')
print('Map:',len(features),'located;',len(unlocated),'unlocated;',out['metadata']['record_count'],'records')
