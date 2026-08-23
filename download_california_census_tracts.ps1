$ErrorActionPreference = 'Stop'

$endpoint = 'https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_ACS2024/MapServer/8/query'
$output = Join-Path $PSScriptRoot 'california-census-tracts.geojson'
$pageSize = 1000
$expected = (Invoke-RestMethod "${endpoint}?where=STATE%3D%2706%27&returnCountOnly=true&f=json").count
$writer = [IO.StreamWriter]::new($output,$false,[Text.UTF8Encoding]::new($false),1MB)
$written = 0
try {
    $writer.Write('{"type":"FeatureCollection","source":{"agency":"U.S. Census Bureau","service":"TIGERweb ACS 2024","state_fips":"06"},"features":[')
    for($offset=0;$offset -lt $expected;$offset += $pageSize){
        $body=@{
            where="STATE='06'"; outFields='GEOID,STATE,COUNTY,TRACT,BASENAME,NAME,AREALAND,AREAWATER,CENTLAT,CENTLON'
            returnGeometry='true'; outSR='4326'; resultOffset=[string]$offset; resultRecordCount=[string]$pageSize
            orderByFields='OBJECTID'; f='geojson'
        }
        $response=Invoke-WebRequest -Method Post -Uri $endpoint -Body $body -UseBasicParsing
        $json=if($response.Content -is [byte[]]){[Text.Encoding]::UTF8.GetString($response.Content)}else{[string]$response.Content}
        $start=$json.IndexOf('['); $end=$json.LastIndexOf(']')
        if($start -lt 0 -or $end -le $start){throw "Invalid GeoJSON response at offset $offset"}
        $inner=$json.Substring($start+1,$end-$start-1)
        if($inner.Length){if($written){$writer.Write(',')};$writer.Write($inner);$pageCount=([regex]::Matches($inner,'"type":"Feature"')).Count;$written += $pageCount}
    }
    $writer.Write(']}')
} finally {$writer.Dispose()}
if($written -ne $expected){throw "Expected $expected features but wrote $written"}
[pscustomobject]@{file=$output;features=$written;bytes=(Get-Item $output).Length;source=$endpoint} | Format-List
