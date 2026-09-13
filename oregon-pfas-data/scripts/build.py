#!/usr/bin/env python3
"""Rebuild Oregon PFAS tables from EPA snapshots; Python 3 standard library only."""
import csv, json, hashlib, io, zipfile, argparse, subprocess
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal
from collections import Counter, defaultdict
ROOT = Path(__file__).resolve().parents[1]
URLS = {
 'ucmr3': 'https://www.epa.gov/system/files/other-files/2024-04/ucmr3-occurrence-data-by-state.zip',
 'ucmr5': 'https://www.epa.gov/system/files/other-files/2023-08/ucmr5-occurrence-data-by-state.zip',
}
PFAS3 = {'PFOA','PFOS','PFNA','PFHxS','PFHpA','PFBS'}
def write_csv(path, rows):
 path.parent.mkdir(parents=True,exist_ok=True)
 with path.open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]) if rows else []); w.writeheader(); w.writerows(rows)
def sample_key(r):
 return tuple(r[k] for k in ['program','pws_id','facility_id','sample_point_id','collection_date','sample_id'])
def summarize(rows):
 dates=[r['collection_date'] for r in rows]
 return dict(analytical_records=len(rows),systems=len({r['pws_id'] for r in rows}),sample_keys=len({sample_key(r) for r in rows}),point_date_groups=len({(r['pws_id'],r['facility_id'],r['sample_point_id'],r['collection_date']) for r in rows}),analytes=len({r['analyte'] for r in rows}),detected_records=sum(r['result_status']=='detected' for r in rows),systems_with_detections=len({r['pws_id'] for r in rows if r['result_status']=='detected'}),first_collection=min(dates),last_collection=max(dates))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--download',action='store_true',help='Fetch current EPA files and replace raw Oregon extracts'); args=ap.parse_args()
 manifest_path=ROOT/'data/source_manifest.json'
 manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
 allrows=[]
 for program,url in URLS.items():
  raw=ROOT/f'data/raw/epa/{program}-oregon-all-analytes.csv'
  if args.download or not raw.exists():
   archive=ROOT/f'.cache/{program}-by-state.zip';archive.parent.mkdir(exist_ok=True)
   if args.download or not archive.exists():
    subprocess.run(['curl','--fail','--location','--retry','2','--max-time','180','--output',str(archive),url],check=True)
   z=zipfile.ZipFile(archive); members=[n for n in z.namelist() if '_All_' in n and n.endswith('.txt')]
   extracted=[]
   for member in members:
    reader=csv.DictReader(io.TextIOWrapper(z.open(member),encoding='cp1252'),delimiter='\t')
    extracted.extend(r for r in reader if r['State'].strip()=='OR')
   write_csv(raw,extracted)
   docs=[]
   for member in z.namelist():
    if member.endswith('.pdf'):
     dest=ROOT/'data/reference'/program/member;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(member));docs.append(str(dest.relative_to(ROOT)))
   manifest[program]={'url':url,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'extraction_recorded_utc':datetime.now(timezone.utc).isoformat(),'members':members,'filter':"State.strip() == 'OR'; all analytes preserved in raw extract; no PWSID prefix restriction",'encoding_original':'cp1252','raw_file':str(raw.relative_to(ROOT)),'raw_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'raw_rows':len(extracted),'reference_documents':docs}
  assert hashlib.sha256(raw.read_bytes()).hexdigest()==manifest[program]['raw_sha256'], 'Raw snapshot changed; investigate provenance'
  rows=list(csv.DictReader(raw.open(encoding='utf-8')))
  for lineno,r in enumerate(rows,2):
   analyte=r['Contaminant'].strip()
   if (program=='ucmr3' and analyte not in PFAS3) or (program=='ucmr5' and analyte.lower()=='lithium'): continue
   assert r['Units']=='µg/L',r['Units']
   assert r['AnalyticalResultsSign'] in {'<','='},r
   nd=r['AnalyticalResultsSign']=='<'
   assert bool(r['AnalyticalResultValue']) != nd,r
   mrl=Decimal(r['MRL'])*1000; value='' if nd else str(Decimal(r['AnalyticalResultValue'])*1000)
   assert mrl>0 and (nd or Decimal(value)>=mrl),r
   dt=datetime.strptime(r['CollectionDate'],'%m/%d/%Y').date().isoformat()
   allrows.append(dict(program=program.upper(),pws_id=r['PWSID'],pws_name=r['PWSName'],size_class=r['Size'],facility_id=r['FacilityID'],facility_name=r['FacilityName'],water_type=r['FacilityWaterType'],sample_point_id=r['SamplePointID'],sample_point_type=r['SamplePointType'],collection_date=dt,sample_id=r['SampleID'],sample_event_code=r['SampleEventCode'],analyte=analyte,method=r['MethodID'],result_status='below_mrl' if nd else 'detected',result_sign=r['AnalyticalResultsSign'],result_ng_l=value,mrl_ng_l=str(mrl),original_result=r['AnalyticalResultValue'],original_units=r['Units'],original_mrl=r['MRL'],source_file=str(raw.relative_to(ROOT)),source_csv_line=lineno))
 manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
 write_csv(ROOT/'data/processed/oregon-pfas-results.csv',allrows)
 groups=defaultdict(list)
 for r in allrows:groups[(r['program'],r['pws_id'])].append(r)
 systems=[]
 for (p,pws),rows in sorted(groups.items()):
  s=summarize(rows);systems.append(dict(program=p,pws_id=pws,pws_name=rows[0]['pws_name'],**s))
 write_csv(ROOT/'data/processed/system-summary.csv',systems)
 groups=defaultdict(list)
 for r in allrows:groups[(r['program'],r['analyte'],r['method'],r['mrl_ng_l'])].append(r)
 panels=[]
 for (p,a,m,l),rows in sorted(groups.items()):panels.append(dict(program=p,analyte=a,method=m,mrl_ng_l=l,**summarize(rows)))
 write_csv(ROOT/'data/processed/analyte-method-limits.csv',panels)
 # Comparable threshold sensitivity: retain all results, classify whether an old-limit detection is demonstrable.
 comparisons=[]
 for a in sorted(PFAS3):
  old=[r for r in allrows if r['program']=='UCMR3' and r['analyte']==a];new=[r for r in allrows if r['program']=='UCMR5' and r['analyte']==a]
  limits={Decimal(r['mrl_ng_l']) for r in old};assert len(limits)==1
  threshold=next(iter(limits)); unknown=[r for r in new if r['result_status']=='below_mrl' and Decimal(r['mrl_ng_l'])>threshold]
  comparisons.append(dict(analyte=a,ucmr3_mrl_ng_l=str(threshold),ucmr3_records=len(old),ucmr5_records=len(new),ucmr5_detected_at_own_mrl=sum(r['result_status']=='detected' for r in new),ucmr5_at_or_above_ucmr3_mrl=sum(r['result_status']=='detected' and Decimal(r['result_ng_l'])>=threshold for r in new),ucmr5_indeterminate_at_ucmr3_mrl=len(unknown)))
 write_csv(ROOT/'data/processed/common-analyte-threshold-comparison.csv',comparisons)
 keycounts=Counter(sample_key(r)+(r['analyte'],r['method']) for r in allrows)
 collisions=[{'key':list(k),'rows':n} for k,n in keycounts.items() if n>1]
 audit={'scope':'State=OR in both EPA archive partitions; PFAS only in processed tables; public drinking water only. Not all Oregon monitoring.', 'programs':{p:summarize([r for r in allrows if r['program']==p]) for p in ['UCMR3','UCMR5']},'unique_systems_across_programs':len({r['pws_id'] for r in allrows}),'ucmr5_records_after_2025':sum(r['program']=='UCMR5' and r['collection_date']>'2025-12-31' for r in allrows),'duplicate_candidate_keys':collisions,'below_mrl_with_numeric_values':sum(r['result_status']=='below_mrl' and r['result_ng_l']!='' for r in allrows),'checks_passed':['Raw snapshot SHA-256','Original unit is micrograms/L; conversion factor 1000','All signs are < or =','Nondetect values remain blank','Detected values are at or above MRL','Dates parse','All PFAS records retained without deduplication'],'threshold_comparison':comparisons}
 (ROOT/'data/processed/audit.json').write_text(json.dumps(audit,indent=2)+'\n')
 print(json.dumps(audit,indent=2))
if __name__=='__main__':main()
