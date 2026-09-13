// Transparent decision heuristics, not a calibrated pollution prediction model.
export function capacity(c){
 const vals=[c.budget,c.price,c.rounds,c.blanks,c.duplicates,c.other];
 if(vals.some(v=>!Number.isFinite(v))||c.budget<0||c.price<=0||c.rounds<1||!Number.isInteger(c.rounds)||c.blanks<0||!Number.isInteger(c.blanks)||c.duplicates<0||!Number.isInteger(c.duplicates)||c.other<0)throw Error('请输入有效预算；单价须大于 0，轮次和质控样数量须为整数。');
 const fixed=c.other+c.price*c.rounds*(c.blanks+c.duplicates);
 return {slots:Math.max(0,Math.floor((c.budget-fixed)/(c.price*c.rounds))),fixed,affordable:fixed<=c.budget};
}
export function evidence(p,c){
 const a=p.analytes[c.analyte];
 const age=a?Math.max(0,(Date.parse(c.date)-Date.parse(a.last))/86400000/30.4375):null;
 const ageGap=age===null?1:Math.min(1,age/c.horizon);
 const limitGap=a?Math.min(1,Math.max(...a.mrl)>c.limit?1:0):1;
 // Missing local records are uncertainty, NOT proof of absence of monitoring.
 return {signal:a?.detections>0?1:0,gap:a?.n?(ageGap+limitGap)/2:1,age,limitGap,missing:!a?.n};
}
function categories(p){const water=p.water_types.filter(v=>v!=='unknown').sort(),size=p.size_classes.filter(v=>v!=='unknown').sort();return [...(water.length?['水源组合:'+water.join('+')]:[]),...(size.length?['规模:'+size.join('+')]:[])];}
export function cost(n,c){return c.other+c.price*c.rounds*(n+c.blanks+c.duplicates);}
export function select(candidates,c,mode='balanced'){
 const b=capacity(c);if(!b.affordable)return [];
 const pool=candidates.filter(p=>!p.excluded),chosen=[],seen=new Set();
 if(mode==='random'){
  // Seeded ordering is reproducible and input-order independent.
  const hash=s=>{let h=2166136261;for(const ch of s){h^=ch.charCodeAt(0);h=Math.imul(h,16777619);}return h>>>0;};
  pool.sort((a,b)=>hash(c.seed+':'+a.id)-hash(c.seed+':'+b.id)||a.id.localeCompare(b.id));
 }
 while(chosen.length<Math.min(b.slots,c.maxSites,pool.length+chosen.length)){
  let best=0,bestScore=-Infinity,bestDetail;
  for(let i=0;i<pool.length;i++){
   const p=pool[i],e=evidence(p,c),novel=categories(p).filter(v=>!seen.has(v)),div=novel.length/Math.max(1,categories(p).length);
   const score=mode==='random'?-i:mode==='detection'?e.signal:c.wSignal*e.signal+c.wGap*e.gap+c.wDiversity*div;
   if(score>bestScore||(score===bestScore&&p.id<pool[best].id)){best=i;bestScore=score;bestDetail={...e,novel,div};}
  }
  const [p]=pool.splice(best,1);categories(p).forEach(v=>seen.add(v));chosen.push({...p,decision:{...bestDetail,score:bestScore}});
 }
 return chosen;
}
export function summary(ps,c){return {n:ps.length,cost:ps.length?cost(ps.length,c):0,signals:ps.filter(p=>evidence(p,c).signal).length,gap:ps.length?Math.round(ps.reduce((s,p)=>s+evidence(p,c).gap,0)/ps.length*100):0,categories:new Set(ps.flatMap(categories)).size,unlocated:ps.filter(p=>!p.coordinates).length};}
