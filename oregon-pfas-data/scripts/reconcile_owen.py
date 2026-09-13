#!/usr/bin/env python3
"""Compare Owen's public EPA detection subset with the complete EPA Oregon extract."""
import csv,json,sys,hashlib
from pathlib import Path
from collections import Counter
from datetime import datetime
from decimal import Decimal
R=Path(__file__).resolve().parents[1]
snapshot=R/'data/reference/owen-oregon-ucmr5-detections.json'
if len(sys.argv)>1:
 original=Path(sys.argv[1]);d=json.loads(original.read_text(encoding='utf-8-sig'))
 f=[x for x in d['features'] if str(x['properties'].get('State','')).strip()=='OR']
 snapshot.write_text(json.dumps({'source':'https://github.com/owenni668866/practice.html','commit':'6a47de9f4acea3ff049d85cd573ac931913cf7cb','path':'data/national/epa/epa-ucmr5-pfas-detections.geojson','original_file_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'features':f},ensure_ascii=False,indent=2)+'\n')
d=json.loads(snapshot.read_text());old=Counter()
for f in d['features']:
 p=f['properties'];old[(p['F_PWS_ID'],p['Facility_ID'],p['Sample_Point_ID'],datetime.strptime(p['Collection_Date'],'%m/%d/%Y').date().isoformat(),p['Sample_ID'],p['Contaminant'],Decimal(str(p['Analytical_Result_Value__ng_L_'])))]+=1
new=Counter()
for r in csv.DictReader((R/'data/processed/oregon-pfas-results.csv').open()):
 if r['program']=='UCMR5' and r['result_status']=='detected':new[(r['pws_id'],r['facility_id'],r['sample_point_id'],r['collection_date'],r['sample_id'],r['analyte'],Decimal(r['result_ng_l']))]+=1
report={'old_detected_records':sum(old.values()),'official_detected_records':sum(new.values()),'matched_records':sum((old&new).values()),'old_only':sum((old-new).values()),'official_only':sum((new-old).values()),'comparison_key':'PWSID, facility, point, date, SampleID, analyte, concentration ng/L','warning':'Inherited locations are service-area or ZIP centroids, not sampling coordinates; reference only. Do not append these duplicate detections to main results.'}
(R/'data/processed/owen-reconciliation.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
