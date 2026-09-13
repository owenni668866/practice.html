#!/usr/bin/env python3
"""Add source-backed system attributes to the existing map summaries."""
from pathlib import Path
from collections import defaultdict
import csv,json
R=Path(__file__).resolve().parents[1]
m=json.loads((R/'data/processed/oregon-map.json').read_text());groups=defaultdict(list)
for r in csv.DictReader((R/'data/processed/oregon-pfas-results.csv').open()):
 if r['program']=='UCMR5':groups[r['pws_id']].append(r)
candidates=[]
for f in m['features']+[{'geometry':None,'properties':p} for p in m['unlocated']]:
 p=f['properties'];rs=groups[p['pws_id']]
 p['water_types']=sorted({r['water_type'] for r in rs});p['size_classes']=sorted({r['size_class'] for r in rs});p['source']='EPA UCMR5';p['manual']=False
 for a,s in p['analytes'].items():s['last']=max(r['collection_date'] for r in rs if r['analyte']==a)
 candidates.append({'id':p['pws_id'],'coordinates':f['geometry']['coordinates'] if f['geometry'] else None,**p})
(R/'data/processed/planner-candidates.json').write_text(json.dumps({'snapshot':'2026-09-06','candidates':candidates},ensure_ascii=False,separators=(',',':'))+'\n')
print('Planner candidates:',len(candidates))
