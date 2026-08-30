$ErrorActionPreference = 'Stop'

$endpointRoot = 'https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_ACS2024/MapServer'
$pageSize = 500

function Export-TigerWebGeoJson {
    param([int]$Layer,[string]$Where,[string]$OutFields,[string]$Output)
    $endpoint = "$endpointRoot/$Layer/query"
    $parent = Split-Path -Parent $Output
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $encodedWhere = [Uri]::EscapeDataString($Where)
    $expected = (Invoke-RestMethod "${endpoint}?where=$encodedWhere&returnCountOnly=true&f=json").count
    $writer = [IO.StreamWriter]::new($Output,$false,[Text.UTF8Encoding]::new($false),1MB)
    $written = 0
    try {
        $writer.Write('{"type":"FeatureCollection","source":{"agency":"U.S. Census Bureau","service":"TIGERweb ACS 2024","coordinate_system":"EPSG:4326"},"features":[')
        for($offset=0;$offset -lt $expected;$offset += $pageSize){
            $body=@{where=$Where;outFields=$OutFields;returnGeometry='true';outSR='4326';resultOffset=[string]$offset;resultRecordCount=[string]$pageSize;orderByFields='OBJECTID';f='geojson'}
            $response=Invoke-WebRequest -Method Post -Uri $endpoint -Body $body -UseBasicParsing
            $json=if($response.Content -is [byte[]]){[Text.Encoding]::UTF8.GetString($response.Content)}else{[string]$response.Content}
            $start=$json.IndexOf('[');$end=$json.LastIndexOf(']')
            if($start -lt 0 -or $end -le $start){throw "Invalid GeoJSON response for layer $Layer at offset $offset"}
            $inner=$json.Substring($start+1,$end-$start-1)
            if($inner.Length){if($written){$writer.Write(',')};$writer.Write($inner);$written += ([regex]::Matches($inner,'"type":"Feature"')).Count}
        }
        $writer.Write(']}')
    } finally {$writer.Dispose()}
    if($written -ne $expected){throw "Expected $expected features but wrote $written to $Output"}
    [pscustomobject]@{output=$Output;features=$written;bytes=(Get-Item $Output).Length}
}

$tractFields='GEOID,STATE,COUNTY,TRACT,BASENAME,NAME,AREALAND,AREAWATER,CENTLAT,CENTLON'
$stateFields='GEOID,STATE,BASENAME,NAME,STUSAB,AREALAND,AREAWATER,CENTLAT,CENTLON'
$results=@(
    Export-TigerWebGeoJson -Layer 8 -Where "STATE='41'" -OutFields $tractFields -Output (Join-Path $PSScriptRoot 'data\oregon\oregon-census-tracts.geojson')
    Export-TigerWebGeoJson -Layer 8 -Where "STATE='53'" -OutFields $tractFields -Output (Join-Path $PSScriptRoot 'data\washington\washington-census-tracts.geojson')
    Export-TigerWebGeoJson -Layer 80 -Where "STATE IN ('06','41','53')" -OutFields $stateFields -Output (Join-Path $PSScriptRoot 'data\west-coast-state-boundaries.geojson')
)
$results | Format-Table -AutoSize
