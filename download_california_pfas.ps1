$ErrorActionPreference = 'Stop'

$destination = Join-Path $PSScriptRoot 'california-pfas-data'
New-Item -ItemType Directory -Force -Path $destination | Out-Null

$downloads = @(
    [pscustomobject]@{ File='ca-ddw-pfas-ordered-monitoring-2019-q1-q4.xlsx'; Url='https://water.waterboards.ca.gov/pfas/docs/pfas_monitoring_Q1Q2Q3Q4.xlsx'; Category='drinking water'; Note='2019 ordered monitoring near airports and landfills' },
    [pscustomobject]@{ File='ca-ucmr3-pfos-pfoa-summary.xlsx'; Url='https://water.waterboards.ca.gov/drinking_water/certlic/drinkingwater/documents/pfos_and_pfoa/UCMR3_CA_Summary_Data_for_PFOS_and_PFOA%20.xlsx'; Category='drinking water'; Note='California UCMR3 PFOS/PFOA summary, 2013-2015' },
    [pscustomobject]@{ File='ca-gama-pfas-statewide.csv'; Url='https://data.ca.gov/dataset/81d1347c-891d-4f09-abc5-6eeb521b55d2/resource/c7cd50a2-2a68-44a1-8d40-4e767f363964/download/pfas.csv'; Category='groundwater'; Note='GAMA statewide PFAS results, all included datasets' },
    [pscustomobject]@{ File='ca-swp-pfas.csv'; Url='https://data.cnra.ca.gov/dataset/307f4156-8f97-4f8f-be17-61a0dfd0d8db/resource/d6ddd605-65b4-43a1-b3d8-d5a2b4613ed1/download/compiled-swp-pfas-data.csv'; Category='surface/raw water'; Note='State Water Project PFAS results since 2020' },
    [pscustomobject]@{ File='ca-swp-water-quality-sampling-sites.csv'; Url='https://data.cnra.ca.gov/dataset/307f4156-8f97-4f8f-be17-61a0dfd0d8db/resource/57b30dbe-ebb7-46f0-8030-572b0d4eaacd/download/swp-wq-sampling-sites.csv'; Category='locations'; Note='Location lookup for State Water Project samples' },
    [pscustomobject]@{ File='ca-swp-data-flags-and-qualifiers.csv'; Url='https://data.cnra.ca.gov/dataset/307f4156-8f97-4f8f-be17-61a0dfd0d8db/resource/b54f65a5-af20-45a9-bd9c-46c87deac999/download/swp-compiled-data-flags-and-qualifiers.csv'; Category='documentation'; Note='Flags and qualifiers used in compiled State Water Project data' }
)

$manifest = foreach ($item in $downloads) {
    $target = Join-Path $destination $item.File
    try {
        & curl.exe -L --fail --retry 3 --connect-timeout 30 -A 'Mozilla/5.0' -o $target $item.Url
        if ($LASTEXITCODE -ne 0) { throw "curl exited $LASTEXITCODE" }
        $fileInfo = Get-Item -LiteralPath $target
        [pscustomobject]@{
            file=$item.File; category=$item.Category; description=$item.Note; source_url=$item.Url
            downloaded_utc=(Get-Date).ToUniversalTime().ToString('o'); bytes=$fileInfo.Length
            sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant(); status='downloaded'
        }
    } catch {
        Remove-Item -LiteralPath $target -ErrorAction SilentlyContinue
        [pscustomobject]@{
            file=$item.File; category=$item.Category; description=$item.Note; source_url=$item.Url
            downloaded_utc=(Get-Date).ToUniversalTime().ToString('o'); bytes=0; sha256=''; status=('failed: ' + $_.Exception.Message)
        }
    }
}

$manifest | Export-Csv -LiteralPath (Join-Path $destination 'manifest.csv') -NoTypeInformation -Encoding UTF8
$manifest | Format-Table file, status, bytes -AutoSize
