param([string]$InputCsv = "data/analysis/west-coast-tract-pfas-demographics.csv", [string]$OutputDir = "data/analysis/concentration")

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$stateNames = @{ "06" = "California"; "41" = "Oregon"; "53" = "Washington" }
$variables = [ordered]@{
    total_population = "Total population"
    people_of_color_pct = "People of color (%)"
    white_non_hispanic_pct = "White, non-Hispanic (%)"
    black_non_hispanic_pct = "Black, non-Hispanic (%)"
    aian_non_hispanic_pct = "American Indian/Alaska Native, non-Hispanic (%)"
    asian_non_hispanic_pct = "Asian, non-Hispanic (%)"
    nhpi_non_hispanic_pct = "Native Hawaiian/Pacific Islander, non-Hispanic (%)"
    other_race_non_hispanic_pct = "Other race, non-Hispanic (%)"
    multiracial_non_hispanic_pct = "Multiracial, non-Hispanic (%)"
    hispanic_or_latino_pct = "Hispanic/Latino, any race (%)"
    median_household_income = "Median household income ($)"
}

function Number($value) { if ([string]::IsNullOrWhiteSpace([string]$value)) { return $null }; return [double]$value }
function Correlation($x, $y) {
    if ($x.Count -lt 3) { return $null }
    $mx = ($x | Measure-Object -Average).Average; $my = ($y | Measure-Object -Average).Average
    $num = 0.0; $dx = 0.0; $dy = 0.0
    for ($i=0; $i -lt $x.Count; $i++) { $a=$x[$i]-$mx; $b=$y[$i]-$my; $num += $a*$b; $dx += $a*$a; $dy += $b*$b }
    if ($dx -eq 0 -or $dy -eq 0) { return $null }; return $num/[math]::Sqrt($dx*$dy)
}
function Ranks($values) {
    $pairs = for ($i=0; $i -lt $values.Count; $i++) { [pscustomobject]@{ Index=$i; Value=[double]$values[$i] } }
    $sorted = @($pairs | Sort-Object Value); $ranks = New-Object double[] $values.Count; $i=0
    while ($i -lt $sorted.Count) { $j=$i; while ($j+1 -lt $sorted.Count -and $sorted[$j+1].Value -eq $sorted[$i].Value) { $j++ }; $rank=(($i+1)+($j+1))/2; for ($k=$i;$k -le $j;$k++) {$ranks[$sorted[$k].Index]=$rank}; $i=$j+1 }
    return $ranks
}
function Stats($rows, $field, $scope, $sensitivity) {
    $valid = @($rows | Where-Object { (Number $_.$field) -ne $null -and (Number $_.pfoa_average) -ne $null })
    $x=@($valid | ForEach-Object { Number $_.$field }); $y=@($valid | ForEach-Object { Number $_.pfoa_average }); $ly=@($y | ForEach-Object { [math]::Log10($_+1) })
    [pscustomobject]@{ scope=$scope; sensitivity=$sensitivity; variable=$field; variable_label=$variables[$field]; n=$valid.Count; pearson_raw=Correlation $x $y; pearson_log10_pfoa=Correlation $x $ly; spearman=Correlation (Ranks $x) (Ranks $y) }
}

$all = @(Import-Csv $InputCsv | Where-Object { [int]$_.pfoa_observation_count -gt 0 -and -not [string]::IsNullOrWhiteSpace($_.pfoa_average) } | ForEach-Object {
    $_ | Add-Member state_name $stateNames[$_.state_fips] -PassThru
})
$results = @()
foreach ($field in $variables.Keys) {
    $results += Stats $all $field "West Coast pooled" "All monitored tracts"
    foreach ($fips in $stateNames.Keys | Sort-Object) { $results += Stats @($all | Where-Object state_fips -eq $fips) $field $stateNames[$fips] "State-specific" }
    $results += Stats @($all | Where-Object { [int]$_.pfoa_observation_count -eq 1 }) $field "West Coast pooled" "One-PFOA-observation tracts only"
    $demeaned = @($all | Where-Object { (Number $_.$field) -ne $null } | Group-Object state_fips | ForEach-Object { $g=@($_.Group); $mx=($g | ForEach-Object {Number $_.$field}|Measure-Object -Average).Average; $my=($g|ForEach-Object {Number $_.pfoa_average}|Measure-Object -Average).Average; $g | ForEach-Object {[pscustomobject]@{x=(Number $_.$field)-$mx;y=(Number $_.pfoa_average)-$my}} })
    $results += [pscustomobject]@{scope="West Coast pooled";sensitivity="Within-state demeaned";variable=$field;variable_label=$variables[$field];n=$demeaned.Count;pearson_raw=Correlation @($demeaned.x) @($demeaned.y);pearson_log10_pfoa=$null;spearman=$null}
}
$results | Export-Csv "$OutputDir/correlation-results.csv" -NoTypeInformation
$all | Select-Object tract_geoid,state_fips,state_name,pfoa_average,pfoa_observation_count,station_count,total_population,people_of_color_pct,white_non_hispanic_pct,black_non_hispanic_pct,aian_non_hispanic_pct,asian_non_hispanic_pct,nhpi_non_hispanic_pct,other_race_non_hispanic_pct,multiracial_non_hispanic_pct,hispanic_or_latino_pct,median_household_income | Export-Csv "$OutputDir/monitored-tracts-analysis.csv" -NoTypeInformation

$coverage = $all | Group-Object state_fips | ForEach-Object { $g=@($_.Group); [pscustomobject]@{state=$stateNames[$_.Name];monitored_tracts=$g.Count;stations=($g|Measure-Object station_count -Sum).Sum;pfoa_observations=($g|Measure-Object pfoa_observation_count -Sum).Sum;median_pfoa=($g|Sort-Object {[double]$_.pfoa_average})[[math]::Floor($g.Count/2)].pfoa_average;minimum_pfoa=($g|Measure-Object pfoa_average -Minimum).Minimum;maximum_pfoa=($g|Measure-Object pfoa_average -Maximum).Maximum} }
$coverage | Export-Csv "$OutputDir/coverage-by-state.csv" -NoTypeInformation

$key = @('total_population','people_of_color_pct','asian_non_hispanic_pct','median_household_income')
$plotData = $all | Select-Object (@('tract_geoid','state_name','pfoa_average','station_count') + @($key))
$json = $plotData | ConvertTo-Json -Compress
$cards = ($key | ForEach-Object { "<section><h2>$($variables[$_])</h2><svg class='plot' data-field='$_' viewBox='0 0 640 390'></svg></section>" }) -join "`n"
$html = @"
<!doctype html><html><head><meta charset="utf-8"><title>West Coast PFAS concentration analysis</title><style>body{font:15px system-ui;margin:0;background:#f5f7fa;color:#172033}main{max-width:1380px;margin:auto;padding:28px}h1{margin-bottom:4px}.note{max-width:950px;color:#526174}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:18px}section{background:white;border:1px solid #dce3eb;border-radius:10px;padding:14px}.plot{width:100%;height:auto}.axis{stroke:#8795a5;stroke-width:1}.tick{font-size:11px;fill:#526174}.label{font-size:12px;fill:#26364a}.CA{fill:#2563eb}.OR{fill:#ea580c}.WA{fill:#16a34a}.legend{display:flex;gap:18px;margin:12px 0}.dot{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:5px}</style></head><body><main><h1>PFAS concentration in monitored West Coast Census tracts</h1><p class="note">Only tracts with one or more PFOA measurements are plotted (n=$($all.Count)). The vertical axis is log10(average PFOA + 1) because the concentration distribution is highly right-skewed. Point radius increases with station count; overlapping points expose uneven monitoring density.</p><div class="legend"><span><i class="dot CA"></i>California</span><span><i class="dot OR"></i>Oregon</span><span><i class="dot WA"></i>Washington</span></div><div class="grid">$cards</div></main><script>const data=$json;const labels=$(($variables | ConvertTo-Json -Compress));const ns='http://www.w3.org/2000/svg';document.querySelectorAll('.plot').forEach(svg=>{const f=svg.dataset.field,w=640,h=390,m={l:62,r:22,t:18,b:52};const rows=data.filter(d=>d[f]!==null&&d[f]!==''&&d.pfoa_average!==null);const xs=rows.map(d=>+d[f]),ys=rows.map(d=>Math.log10(+d.pfoa_average+1));const lo=Math.min(...xs),hi=Math.max(...xs),ly=Math.min(...ys),hy=Math.max(...ys);const X=v=>m.l+(v-lo)/(hi-lo||1)*(w-m.l-m.r),Y=v=>h-m.b-(v-ly)/(hy-ly||1)*(h-m.t-m.b);function el(n,a,t){const e=document.createElementNS(ns,n);Object.entries(a).forEach(([k,v])=>e.setAttribute(k,v));if(t)e.textContent=t;svg.appendChild(e)};el('line',{x1:m.l,y1:h-m.b,x2:w-m.r,y2:h-m.b,class:'axis'});el('line',{x1:m.l,y1:m.t,x2:m.l,y2:h-m.b,class:'axis'});for(let i=0;i<=4;i++){const xv=lo+(hi-lo)*i/4,yv=ly+(hy-ly)*i/4;el('text',{x:X(xv),y:h-m.b+18,'text-anchor':'middle',class:'tick'},xv.toLocaleString(undefined,{maximumFractionDigits:1}));el('text',{x:m.l-8,y:Y(yv)+4,'text-anchor':'end',class:'tick'},yv.toFixed(1))}rows.forEach(d=>el('circle',{cx:X(+d[f]),cy:Y(Math.log10(+d.pfoa_average+1)),r:Math.min(8,2.3+Math.sqrt(+d.station_count)),class:d.state_name==='California'?'CA':d.state_name==='Oregon'?'OR':'WA',opacity:.56}));el('text',{x:(m.l+w-m.r)/2,y:h-9,'text-anchor':'middle',class:'label'},labels[f]);el('text',{x:15,y:(m.t+h-m.b)/2,transform:'rotate(-90 15 '+((m.t+h-m.b)/2)+')','text-anchor':'middle',class:'label'},'log10 average PFOA + 1')})</script></body></html>
"@
Set-Content "$OutputDir/scatter-plots.html" $html -Encoding UTF8

$summary = [ordered]@{created_utc=(Get-Date).ToUniversalTime().ToString('o');measure='PFOA';unit_note='Source values are not harmonized across all source datasets; interpret magnitude cautiously.';inclusion_rule='pfoa_observation_count > 0 and nonmissing pfoa_average';monitored_tracts=$all.Count;coverage=$coverage;concentration_station_count_correlation=(Correlation @($all|ForEach-Object{[double]$_.station_count}) @($all|ForEach-Object{[double]$_.pfoa_average}));concentration_observation_count_correlation=(Correlation @($all|ForEach-Object{[double]$_.pfoa_observation_count}) @($all|ForEach-Object{[double]$_.pfoa_average}))}
$summary | ConvertTo-Json -Depth 5 | Set-Content "$OutputDir/analysis-summary.json" -Encoding UTF8
Write-Host "Analyzed $($all.Count) monitored tracts; wrote results to $OutputDir"
