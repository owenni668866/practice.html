import {capacity,evidence,select,summary} from './planner-core.mjs';
const $=id=>document.getElementById(id),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let originals=[],custom=[],chosen=[],config=null,mapReady=false,snapshot='',excluded=new Set();
try{custom=JSON.parse(localStorage.getItem('pfas-planner-candidates')||'[]');if(!Array.isArray(custom))custom=[];}catch{custom=[];}
window.__plannerErrors=[];
const map=new maplibregl.Map({container:'map',style:'assets/basemap.json',center:[-120.4,44.1],zoom:5.6,attributionControl:false});window.plannerMap=map;
map.addControl(new maplibregl.NavigationControl({showCompass:false}),'top-right');map.addControl(new maplibregl.FullscreenControl(),'top-right');map.addControl(new maplibregl.AttributionControl({compact:true,customAttribution:'候选数据: US EPA'}));
map.on('error',e=>{window.__plannerErrors.push(String(e.error));$('status').textContent='部分地图资源未载入；预算和候选清单仍可使用。';});
function pool(){return [...originals,...custom].map(p=>({...p,excluded:excluded.has(p.id)}));}
function read(){
 const c={};for(const id of ['budget','price','rounds','other','blanks','duplicates','limit','horizon','wSignal','wGap','wDiversity','maxSites']){const v=$(id).value;if(v.trim()==='')throw Error('请填写全部预算与方案参数。');c[id]=Number(v);}
 c.analyte=$('analyte').value;c.date=$('date').value;c.seed='oregon-pfas-2026';
 if(!Number.isFinite(Date.parse(c.date))||c.limit<=0||c.horizon<=0||!Number.isInteger(c.maxSites)||c.maxSites<0)throw Error('请检查计划日期、报告限、更新周期和地点数。');
 const sum=c.wSignal+c.wGap+c.wDiversity;if(sum<=0)throw Error('至少一个选点目标的权重需要大于 0。');
 for(const [key,out] of [['wSignal','signal-value'],['wGap','gap-value'],['wDiversity','diversity-value']]){c[key]/=sum;$(out).textContent=Math.round(c[key]*100)+'%';}
 capacity(c);return c;
}
function reasons(p,c){const d=p.decision,e=evidence(p,c),a=p.analytes[c.analyte];return [e.signal?`历史 ${c.analyte} 有检出`:a?'历史结果低于报告限':'目标分析物记录待核实',e.missing?'需核实监测证据':`最近记录 ${Math.round(e.age)} 个月前${e.limitGap?'；MRL 高于目标':''}`,d.novel.length?'新增类型 '+d.novel.join('、'):'已覆盖类型中的补充点',p.coordinates?'系统代表位置，实际采样点待定':'无坐标，需现场位置核实'];}
function redraw(){
 if(!originals.length)return;
 try{config=read();$('status').classList.remove('error');}catch(e){chosen=[];config=null;$('status').classList.add('error');$('status').textContent=e.message;$('budget-result').textContent=e.message;$('selection').replaceChildren();$('comparison').replaceChildren();$('plan-summary').textContent='参数无效，未生成方案。';$('export').disabled=true;drawMap();return;}
 const b=capacity(config),ps=pool();chosen=select(ps,config);const s=summary(chosen,config);
 $('budget-result').innerHTML=b.affordable?`预算最多支持 <strong>${b.slots}</strong> 个地点<br><small>每点 ${config.rounds} 轮；另含 ${(config.blanks+config.duplicates)*config.rounds} 份质控样。每轮是一次到各入选地点采样。</small>`:'预算不足以覆盖当前质控样与其他费用，请调整参数。';
 const active=ps.filter(p=>!p.excluded).length;
 $('status').textContent=`${active} 个可选系统 / 地点 · ${custom.length} 个自建候选 · 费用为规划假设，非报价。`;
 $('plan-summary').textContent=s.n?`${s.n} 个地点 · ${s.n*config.rounds} 份现场样 + ${(config.blanks+config.duplicates)*config.rounds} 份质控样 · 预计 $${s.cost.toLocaleString()} / $${config.budget.toLocaleString()} · ${s.unlocated} 个无坐标`:'没有可执行的选点清单，请检查预算、地点数和候选范围。';
 $('export').disabled=!s.n;$('selection').replaceChildren();
 chosen.forEach((p,i)=>{const el=document.createElement('button');el.className='site';el.innerHTML=`<b>${i+1}. ${esc(p.name)}</b><span>${esc(p.id)} · ${esc(p.source)}</span><span>${reasons(p,config).map(esc).join('<br>')}</span>`;el.onclick=()=>focus(p);$('selection').append(el);});
 const alternatives=[['当前加权方案',chosen],['仅优先既有检出',select(ps,config,'detection')],['固定种子随机对照',select(ps,config,'random')]];
 $('comparison').innerHTML='<table><thead><tr><th>方案</th><th>地点</th><th>有历史检出</th><th>平均证据缺口 /100</th><th>水源组合+规模类别</th><th>预计费用</th></tr></thead><tbody>'+alternatives.map(([name,rows])=>{const s=summary(rows,config);return `<tr><td>${name}</td><td>${s.n}</td><td>${s.signals}</td><td>${s.gap}</td><td>${s.categories}</td><td>$${s.cost}</td></tr>`;}).join('')+'</tbody></table>';
 drawMap();window.plannerState={config,selected:chosen.map(p=>p.id),summary:s,budget:b};
}
function drawMap(){if(!mapReady)return;const selected=new Map(chosen.map((p,i)=>[p.id,i+1]));map.getSource('candidates').setData({type:'FeatureCollection',features:pool().filter(p=>p.coordinates&&!p.excluded).map(p=>({type:'Feature',geometry:{type:'Point',coordinates:p.coordinates},properties:{id:p.id,name:p.name,selected:selected.has(p.id),order:selected.get(p.id)||0}}))});}
function focus(p){const why=config?(chosen.find(x=>x.id===p.id)?reasons(chosen.find(x=>x.id===p.id),config).join('；'):'未进入当前方案，可调整权重或候选范围。'):'';
 if(!p.coordinates){$('status').textContent=`${p.name}：无官方/用户提供坐标，保留为待核实候选。`;return;}
 new maplibregl.Popup({maxWidth:'290px'}).setLngLat(p.coordinates).setHTML(`<b>${esc(p.name)}</b><p>${esc(why)}</p><small>${esc(p.manual?p.note:'EPA 系统代表位置，不是现场采样坐标。')}</small>`).addTo(map);map.easeTo({center:p.coordinates,zoom:7,padding:{top:130,bottom:innerHeight*.4,left:40,right:50},duration:650});}
function list(){const q=$('candidate-search').value.toLowerCase();$('candidate-list').replaceChildren();pool().filter(p=>(p.name+p.id).toLowerCase().includes(q)).forEach(p=>{const label=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.checked=!excluded.has(p.id);input.onchange=()=>{input.checked?excluded.delete(p.id):excluded.add(p.id);redraw();};label.append(input,document.createTextNode(p.name+(p.manual?' [自建待核实]':'')));$('candidate-list').append(label);});}
map.on('load',()=>{map.addSource('candidates',{type:'geojson',data:{type:'FeatureCollection',features:[]}});map.addLayer({id:'candidate-points',type:'circle',source:'candidates',layout:{'circle-sort-key':['case',['get','selected'],1,0]},paint:{'circle-radius':['case',['get','selected'],8,4],'circle-color':['case',['get','selected'],'#c86d32','#879b94'],'circle-stroke-color':'white','circle-stroke-width':1.5,'circle-opacity':['case',['get','selected'],1,.65]}});map.on('click','candidate-points',e=>focus(pool().find(p=>p.id===e.features[0].properties.id)));map.on('mouseenter','candidate-points',()=>map.getCanvas().style.cursor='pointer');map.on('mouseleave','candidate-points',()=>map.getCanvas().style.cursor='');mapReady=true;map.fitBounds([[-124.8,41.8],[-116.4,46.35]],{padding:{top:120,bottom:innerHeight*.4,left:40,right:50},duration:0});drawMap();});
$('fit').onclick=()=>map.fitBounds([[-124.8,41.8],[-116.4,46.35]],{padding:{top:120,bottom:innerHeight*.4,left:40,right:50},duration:600});
$('toggle').onclick=()=>document.body.classList.toggle('controls-open');
for(const id of ['budget','price','rounds','other','blanks','duplicates','limit','horizon','wSignal','wGap','wDiversity','maxSites','date','analyte'])$(id).addEventListener('input',redraw);
$('preset').onchange=()=>{const p={balanced:[40,35,25],gap:[15,60,25],signal:[70,15,15]}[$('preset').value];['wSignal','wGap','wDiversity'].forEach((id,i)=>$(id).value=p[i]);redraw();};
$('candidate-search').oninput=list;
function save(){try{localStorage.setItem('pfas-planner-candidates',JSON.stringify(custom));return true;}catch{$('manual-message').textContent='浏览器未允许本地保存，请导出备份；当前页面仍可使用。';return false;}}
$('add').onclick=()=>{
 const name=$('manual-name').value.trim(),note=$('manual-note').value.trim(),lon=$('lon').value,lat=$('lat').value;
 if(!name||!note){$('manual-message').textContent='请填写名称及可追溯的来源 / 缺口说明。';return;}
 if((!lon)!==(!lat)||(lon&&(!Number.isFinite(+lon)||!Number.isFinite(+lat)||Math.abs(+lon)>180||Math.abs(+lat)>90))){$('manual-message').textContent='经纬度须同时填写且范围有效，或同时留空。';return;}
 custom.push({id:'USER-'+Date.now(),name,source:'用户提供 / 待核实',manual:true,note,coordinates:lon?[+lon,+lat]:null,water_types:[$('manual-water').value],size_classes:[$('manual-size').value],analytes:{},n:0,detections:0});
 const persisted=save();list();redraw();$('manual-message').textContent=persisted?'已加入并保存在当前浏览器；入选后可随计划导出。':'已加入本次方案，但未能保存，请导出备份。';$('manual-name').value='';$('manual-note').value='';
};
$('clear-manual').onclick=()=>{custom=[];save();list();redraw();$('manual-message').textContent='已清除当前浏览器的自建候选。';};
function csv(v){let s=String(v??'');if(typeof v==='string'&&/^[=+\-@]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"';}
$('export').onclick=()=>{if(!chosen.length||!config)return;const rows=chosen.map((p,i)=>({rank:i+1,id:p.id,name:p.name,source:p.source,source_note:p.note||'EPA UCMR5 + EPA location metadata',longitude:p.coordinates?.[0]??'',latitude:p.coordinates?.[1]??'',coordinate_role:p.manual?'user_provided_unverified':'system_centroid_not_sample_site',analyte:config.analyte,history_signal:p.decision.signal,evidence_gap:p.decision.gap,water_types:p.water_types.join('|'),size_classes:p.size_classes.join('|'),selection_reason:reasons(p,config).join('；'),site_access:'待核实准入及具体采样点',snapshot,estimated_plan_cost:summary(chosen,config).cost,assumptions_json:JSON.stringify(config)}));const keys=Object.keys(rows[0]),text='\ufeff'+[keys,...rows.map(r=>keys.map(k=>r[k]))].map(r=>r.map(csv).join(',')).join('\r\n');const u=URL.createObjectURL(new Blob([text],{type:'text/csv;charset=utf-8'})),a=document.createElement('a');a.href=u;a.download='oregon-pfas-monitoring-plan.csv';a.click();setTimeout(()=>URL.revokeObjectURL(u),5000);};
fetch('data/processed/planner-candidates.json').then(r=>{if(!r.ok)throw Error(r.status);return r.json();}).then(d=>{originals=d.candidates;snapshot=d.snapshot;const names=[...new Set(originals.flatMap(p=>Object.keys(p.analytes)))].sort();names.forEach(n=>{const o=new Option(n,n);$('analyte').add(o);});$('analyte').value='PFOA';list();redraw();}).catch(e=>{$('status').textContent='候选数据读取失败，请刷新。';window.__plannerErrors.push(String(e));});
