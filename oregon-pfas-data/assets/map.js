'use strict';
const $=id=>document.getElementById(id);
const escapeHTML=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let dataset,allSystems=[],selected=null,mapReady=false;
window.__mapErrors=[];
const map = new maplibregl.Map({container:'map',style:'assets/basemap.json',center:[-120.6,44.15],zoom:6.3,minZoom:3,maxZoom:16,attributionControl:false});
window.pfasMap=map;
map.addControl(new maplibregl.NavigationControl({showCompass:false}),'top-right');
map.addControl(new maplibregl.FullscreenControl({container:$('app')}),'top-right');
map.addControl(new maplibregl.AttributionControl({compact:true,customAttribution:'PFAS: US EPA'}),'bottom-right');
map.addControl(new maplibregl.ScaleControl({unit:'metric'}),'bottom-left');
function home(){map.fitBounds([[-124.8,41.8],[-116.4,46.35]],{padding:{left:innerWidth>800&&!document.body.classList.contains('panel-closed')?380:45,right:65,top:115,bottom:100},duration:700});}
$('reset').onclick=home;
if(innerWidth<=800)document.body.classList.add('panel-closed');
$('toggle-panel').setAttribute('aria-expanded',!document.body.classList.contains('panel-closed'));
$('toggle-panel').onclick=()=>{document.body.classList.toggle('panel-closed');$('toggle-panel').setAttribute('aria-expanded',!document.body.classList.contains('panel-closed'));};
$('close-detail').onclick=()=>{$('detail').hidden=true;selected=null;if(mapReady)map.setFilter('selected',['==',['get','pws_id'],'']);};
const stats=p=>{const a=$('analyte').value;return a==='all'?{n:p.n,detections:p.detections}:p.analytes[a]||{n:0,detections:0};};
function visible(p){const s=stats(p),state=$('status').value,q=$('search').value.trim().toLowerCase();return s.n>0&&(state==='all'||(state==='detected'?s.detections>0:s.detections===0))&&(!q||(p.name+' '+p.pws_id).toLowerCase().includes(q));}
function update(){
 if(!dataset)return;
 const shown=allSystems.filter(f=>visible(f.properties));
 const points=shown.filter(f=>f.geometry).map(f=>({...f,properties:{pws_id:f.properties.pws_id,name:f.properties.name,detected:stats(f.properties).detections>0}}));
 if(mapReady)map.getSource('systems').setData({type:'FeatureCollection',features:points});
 $('total').textContent=shown.length;$('detected').textContent=shown.filter(f=>stats(f.properties).detections>0).length;$('located').textContent=points.length;
 $('results-count').textContent=`${shown.length} 个系统 · ${shown.length-points.length} 个无坐标`;
 $('systems').replaceChildren();
 if(!shown.length)$('systems').innerHTML='<p class="empty">没有匹配的系统，请调整筛选。</p>';
 shown.sort((a,b)=>stats(b.properties).detections-stats(a.properties).detections||a.properties.name.localeCompare(b.properties.name)).forEach(f=>{
  const p=f.properties,s=stats(p),b=document.createElement('button');b.className='system';
  b.innerHTML=`<i class="dot ${f.geometry?(s.detections?'detected':'below'):'unlocated'}"></i><span><span class="name">${escapeHTML(p.name)}</span><span class="id">${escapeHTML(p.pws_id)} · ${s.detections?`${s.detections} 条检出`:'低于报告限'}${f.geometry?'':' · 无坐标'}</span></span><span class="arrow">↗</span>`;
  b.onclick=()=>showDetail(p.pws_id,true);$('systems').append(b);
 });
 if(selected){if(shown.some(f=>f.properties.pws_id===selected))showDetail(selected,false);else $('close-detail').click();}
 $('loading').hidden=true;
}
function showDetail(id,fly){
 const f=allSystems.find(f=>f.properties.pws_id===id);if(!f)return;
 selected=id;const p=f.properties,s=stats(p),a=$('analyte').value;
 const methods={'Estimated Water System Service Area Centroid':'估算服务区质心','Centroid of ZIP Code(s) served':'服务 ZIP 区域质心','Centroid of counties served':'服务县域质心'};
 const entries=Object.entries(p.analytes).filter(([name])=>a==='all'||a===name);
 $('detail-content').innerHTML=`<div class="eyebrow">SYSTEM PROFILE / UCMR5</div><h2>${escapeHTML(p.name)}</h2><div class="sub">${escapeHTML(id)}</div><div class="badge ${s.detections?'':'nd'}">${s.detections?'有检出记录':'结果低于报告限'} · ${a==='all'?'全部 PFAS':escapeHTML(a)}</div><p><b>${s.n.toLocaleString()}</b> 条分析记录，<b>${s.detections}</b> 条检出。</p><p class="sub">系统采样日期：${p.first} — ${p.last}</p><div class="meta">位置：${escapeHTML(methods[p.geolocation]||'官方未提供坐标')}。${f.geometry?'仅用于表示供水系统的大致位置，不是实际采样点。':'保留检测数据，不推测或编造位置。'}</div><table><thead><tr><th>分析物</th><th>检出/记录</th><th>最高检出<br>ng/L</th><th>MRL<br>ng/L</th></tr></thead><tbody>${entries.map(([name,r])=>`<tr><td>${escapeHTML(name)}</td><td>${r.detections}/${r.n}</td><td>${r.max===null?'—':r.max}</td><td>${r.mrl.join(' / ')}</td></tr>`).join('')}</tbody></table><p class="sub">— 表示无达到报告限的数值，不代表浓度为零。MRL 为最小报告限，表中数值不用于直接判断法规合规。</p><p class="sub">分析方法：${[...new Set(entries.flatMap(([,r])=>r.methods))].map(escapeHTML).join('、')}。每条记录是一个分析物结果，不是一个独立水样。</p><a href="data/processed/oregon-pfas-results.csv" download>下载完整结果 CSV ↓</a>`;
 $('detail').hidden=false;if(mapReady)map.setFilter('selected',['==',['get','pws_id'],id]);
 if(fly&&f.geometry){map.easeTo({center:f.geometry.coordinates,zoom:Math.max(map.getZoom(),8),duration:700,padding:{left:innerWidth>800&&!document.body.classList.contains('panel-closed')?340:0,right:innerWidth>800?390:0,top:80,bottom:50}});}
 if(innerWidth<=800){document.body.classList.add('panel-closed');$('toggle-panel').setAttribute('aria-expanded','false');}
}
['analyte','status'].forEach(id=>$(id).addEventListener('change',update));$('search').addEventListener('input',update);
map.on('error',e=>{window.__mapErrors.push(String(e.error));$('map-error').textContent='部分地图资源未能载入，请检查网络后刷新。检测数据仍可在侧栏和数据报告中查看。';$('map-error').hidden=false;});
map.on('load',()=>{
 map.addSource('systems',{type:'geojson',data:{type:'FeatureCollection',features:[]}});
 map.addLayer({id:'system-points',type:'circle',source:'systems',paint:{'circle-radius':['interpolate',['linear'],['zoom'],5,5,10,8],'circle-color':['case',['get','detected'],'#cb642e','#4f8580'],'circle-stroke-width':1.8,'circle-stroke-color':'#ffffff','circle-opacity':.95},layout:{'circle-sort-key':['case',['get','detected'],1,0]}});
 map.addLayer({id:'selected',type:'circle',source:'systems',filter:['==',['get','pws_id'],''],paint:{'circle-radius':12,'circle-color':'transparent','circle-stroke-color':'#203236','circle-stroke-width':2}});
 map.on('click','system-points',e=>showDetail(e.features[0].properties.pws_id,false));map.on('mouseenter','system-points',()=>map.getCanvas().style.cursor='pointer');map.on('mouseleave','system-points',()=>map.getCanvas().style.cursor='');
 mapReady=true;home();update();
});
fetch('data/processed/oregon-map.json').then(r=>{if(!r.ok)throw Error(r.status);return r.json();}).then(d=>{
 dataset=d;allSystems=[...d.features,...d.unlocated.map(p=>({properties:p,geometry:null}))];
 const analytes=[...new Set(allSystems.flatMap(f=>Object.keys(f.properties.analytes)))].sort();
 analytes.forEach(a=>{const o=document.createElement('option');o.value=a;o.textContent=a;$('analyte').append(o);});
 $('location-note').textContent=`${d.metadata.system_count} 个系统中 ${d.metadata.located} 个可定位，${d.metadata.unlocated} 个无官方坐标，仍保留在系统列表。实际记录含少量 2026 年采样。`;
 update();
}).catch(e=>{$('loading').hidden=true;$('map-error').textContent='检测数据读取失败，请刷新或打开数据报告。';$('map-error').hidden=false;window.__mapErrors.push(String(e));});
