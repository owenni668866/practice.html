$ErrorActionPreference = 'Stop'

$inputs=@(
    @{State='California';Path='data\california\pfas-sites-california.geojson'},
    @{State='Oregon';Path='data\oregon\pfas-sites-oregon.geojson'},
    @{State='Washington';Path='data\washington\pfas-sites-washington.geojson'}
)
$features=[Collections.Generic.List[object]]::new()
foreach($input in $inputs){
    $data=Get-Content (Join-Path $PSScriptRoot $input.Path) -Raw | ConvertFrom-Json
    foreach($feature in $data.features){
        $level=0.0;$hasLevel=[double]::TryParse(([string]$feature.properties.pfas_level -replace ',',''),[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$level)
        $feature.properties | Add-Member -NotePropertyName map_state -NotePropertyValue $input.State -Force
        $feature.properties | Add-Member -NotePropertyName concentration_available -NotePropertyValue $hasLevel -Force
        $feature.properties | Add-Member -NotePropertyName concentration_numeric -NotePropertyValue $(if($hasLevel){$level}else{$null}) -Force
        $features.Add($feature)
    }
}
$collection=[ordered]@{type='FeatureCollection';crs=@{type='name';properties=@{name='EPSG:4326'}};features=$features}
$output=Join-Path $PSScriptRoot 'data\west-coast-pfas-stations.geojson'
$collection | ConvertTo-Json -Depth 20 -Compress | Set-Content $output -Encoding UTF8
$features | Group-Object {$_.properties.map_state} | Select-Object Name,Count | Format-Table -AutoSize
