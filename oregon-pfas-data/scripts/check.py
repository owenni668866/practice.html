#!/usr/bin/env python3
"""Independent row-level lineage, unit, censoring and aggregation validation."""
import csv,json,hashlib
from decimal import Decimal
from pathlib import Path
from collections import Counter
R=Path(__file__).resolve().parents[1]
raw={}
for p,m in json.loads((R/'data/source_manifest.json').read_text()).items():
 f=R/m['raw_file']; assert hashlib.sha256(f.read_bytes()).hexdigest()==m['raw_sha256'];raw[m['raw_file']]=list(csv.DictReader(f.open()))
rows=list(csv.DictReader((R/'data/processed/oregon-pfas-results.csv').open()))
expected={(f,i) for f,rs in raw.items() for i,r in enumerate(rs,2) if r['Contaminant'] in {'PFOA','PFOS','PFNA','PFHxS','PFHpA','PFBS'} or ('ucmr5' in f and r['Contaminant'].lower()!='lithium')}
seen=set();keys=set()
for r in rows:
 lineage=(r['source_file'],int(r['source_csv_line']));assert lineage not in seen;seen.add(lineage);o=raw[lineage[0]][lineage[1]-2]
 assert o['State'].strip()=='OR' and o['Units']=='µg/L'
 assert r['pws_id']==o['PWSID'] and r['analyte']==o['Contaminant'] and r['method']==o['MethodID']
 assert r['pws_id'] and r['sample_id'] and r['sample_point_id']
 assert Decimal(r['mrl_ng_l'])==Decimal(o['MRL'])*1000
 if o['AnalyticalResultsSign']=='<':assert r['result_status']=='below_mrl' and r['result_ng_l']==''
 else:assert r['result_status']=='detected' and Decimal(r['result_ng_l'])==Decimal(o['AnalyticalResultValue'])*1000
 key=tuple(r[k] for k in ['program','pws_id','facility_id','sample_point_id','collection_date','sample_id','analyte','method']);assert key not in keys;keys.add(key)
assert seen==expected,'Dropped, extra or duplicate source rows'
systems=list(csv.DictReader((R/'data/processed/system-summary.csv').open()))
assert Counter({(r['program'],r['pws_id']):int(r['analytical_records']) for r in systems})==Counter((r['program'],r['pws_id']) for r in rows)
for r in systems:
 actual=[x for x in rows if x['program']==r['program'] and x['pws_id']==r['pws_id']]
 assert int(r['detected_records'])==sum(x['result_status']=='detected' for x in actual)
a=json.loads((R/'data/processed/audit.json').read_text());assert not a['duplicate_candidate_keys']
assert sum(x['analytical_records'] for x in a['programs'].values())==len(rows)
for p,x in a['programs'].items():
 assert x['systems']==len({r['pws_id'] for r in rows if r['program']==p})
for r in csv.DictReader((R/'data/processed/common-analyte-threshold-comparison.csv').open()):
 matched=[x for x in rows if x['program']=='UCMR5' and x['analyte']==r['analyte'] and x['result_status']=='detected' and Decimal(x['result_ng_l'])>=Decimal(r['ucmr3_mrl_ng_l'])]
 assert len(matched)==int(r['ucmr5_at_or_above_ucmr3_mrl'])
report=json.loads((R/'data/processed/owen-reconciliation.json').read_text());assert report['old_only']==0,'Historical detections no longer present; investigate EPA revisions'
print(f'PASS: {len(rows):,} source-linked PFAS rows; censoring, units, uniqueness, summaries and thresholds validated.')
# Map summaries retain all UCMR5 systems, including those without coordinates.
m=json.loads((R/'data/processed/oregon-map.json').read_text())
features=m['features'];props=[f['properties'] for f in features]+m['unlocated']
assert len({p['pws_id'] for p in props})==len(props)
source5=[r for r in rows if r['program']=='UCMR5']
assert {p['pws_id'] for p in props}=={r['pws_id'] for r in source5}
for p in props:
 for analyte,s in p['analytes'].items():
  ar=[r for r in source5 if r['pws_id']==p['pws_id'] and r['analyte']==analyte]
  values=[float(r['result_ng_l']) for r in ar if r['result_status']=='detected']
  assert s['n']==len(ar) and s['detections']==len(values)
  assert s['max']==(max(values) if values else None)
  assert s['mrl']==sorted({float(r['mrl_ng_l']) for r in ar})
assert sum(p['n'] for p in props)==len(source5)
locmeta=json.loads((R/'data/location-source.json').read_text())
assert hashlib.sha256((R/locmeta['file']).read_bytes()).hexdigest()==locmeta['sha256']
style=json.loads((R/'assets/basemap.json').read_text())
assert all(s['type']=='vector' for s in style['sources'].values())
print(f'PASS: map covers {len(props)} systems ({len(features)} located); all analyte summaries reconcile to source rows; vector basemap verified.')
