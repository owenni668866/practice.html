$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName Microsoft.VisualBasic

$inputFile = Join-Path $PSScriptRoot 'california-pfas-data\ca-gama-pfas-statewide.csv'
$outputDir = Join-Path $PSScriptRoot 'analysis-output'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($inputFile)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(',')
$parser.HasFieldsEnclosedInQuotes = $true
$header = $parser.ReadFields()
$column = @{}
for ($i=0; $i -lt $header.Count; $i++) { $column[$header[$i]] = $i }

$wells = [Collections.Generic.HashSet[string]]::new()
$locations = [Collections.Generic.HashSet[string]]::new()
$chemicals = @{}
$sources = @{}
$years = @{}
$modifiers = @{}
$rows = 0L; $numeric = 0L; $detections = 0L; $nondetects = 0L; $uncertainResults = 0L; $missingResult = 0L
$validCoords = 0L; $invalidCoords = 0L
$minLat = [double]::PositiveInfinity; $maxLat = [double]::NegativeInfinity
$minLon = [double]::PositiveInfinity; $maxLon = [double]::NegativeInfinity
$detMin = [double]::PositiveInfinity; $detMax = [double]::NegativeInfinity
$detSum = 0.0; $detValues = [Collections.Generic.List[double]]::new()

while (-not $parser.EndOfData) {
    $f = $parser.ReadFields(); $rows++
    if ($f.Count -ne $header.Count) { continue }
    $well = $f[$column['gm_well_id']]; if ($well) { [void]$wells.Add($well) }
    $chem = $f[$column['gm_chemical_vvl']]; if (-not $chemicals.ContainsKey($chem)) {$chemicals[$chem]=0L}; $chemicals[$chem]++
    $source = $f[$column['gm_data_source']]; if (-not $sources.ContainsKey($source)) {$sources[$source]=0L}; $sources[$source]++
    $modifier = $f[$column['gm_result_modifier']]; if (-not $modifiers.ContainsKey($modifier)) {$modifiers[$modifier]=0L}; $modifiers[$modifier]++
    $dateText = $f[$column['gm_samp_collection_date']]
    if ($dateText -match '^(\d{4})') { $year=$Matches[1]; if (-not $years.ContainsKey($year)) {$years[$year]=0L}; $years[$year]++ }
    $lat=0.0; $lon=0.0
    if ([double]::TryParse($f[$column['gm_latitude']], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$lat) -and
        [double]::TryParse($f[$column['gm_longitude']], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$lon) -and
        $lat -ge 32 -and $lat -le 43 -and $lon -ge -125 -and $lon -le -113) {
        $validCoords++; [void]$locations.Add(('{0:F5},{1:F5}' -f $lat,$lon))
        $minLat=[Math]::Min($minLat,$lat); $maxLat=[Math]::Max($maxLat,$lat); $minLon=[Math]::Min($minLon,$lon); $maxLon=[Math]::Max($maxLon,$lon)
    } else { $invalidCoords++ }
    $value=0.0
    if ([double]::TryParse($f[$column['gm_result']], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
        $numeric++
        if ($modifier -in @('<','<=','ND','DN')) { $nondetects++ }
        elseif ($modifier -in @('=','>','J')) { $detections++; $detSum += $value; $detMin=[Math]::Min($detMin,$value); $detMax=[Math]::Max($detMax,$value); $detValues.Add($value) }
        else { $uncertainResults++ }
    } else { $missingResult++ }
}
$parser.Close()
$detValues.Sort()
function Quantile([Collections.Generic.List[double]]$values,[double]$p) { if($values.Count -eq 0){return $null}; $values[[Math]::Min($values.Count-1,[Math]::Floor(($values.Count-1)*$p))] }

$summary = [ordered]@{
    analyzed_utc=(Get-Date).ToUniversalTime().ToString('o'); input_file='ca-gama-pfas-statewide.csv'; analyte_records=$rows
    unique_wells=$wells.Count; unique_coordinate_locations_5dp=$locations.Count; unique_chemicals=$chemicals.Count
    valid_coordinate_records=$validCoords; invalid_coordinate_records=$invalidCoords
    coordinate_bbox=@{min_longitude=$minLon; min_latitude=$minLat; max_longitude=$maxLon; max_latitude=$maxLat}
    numeric_results=$numeric; detection_records=$detections; nondetect_records=$nondetects; uncertain_modifier_records=$uncertainResults; missing_or_nonnumeric_results=$missingResult
    detection_rate_among_classified=if(($detections+$nondetects)){$detections/($detections+$nondetects)}else{$null}
    detected_result_summary=@{minimum=$detMin; p25=(Quantile $detValues .25); median=(Quantile $detValues .5); p75=(Quantile $detValues .75); p95=(Quantile $detValues .95); maximum=$detMax; mean=if($detections){$detSum/$detections}else{$null}}
    records_by_source=$sources; records_by_year=$years; records_by_result_modifier=$modifiers; records_by_chemical=$chemicals
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outputDir 'california-pfas-coverage-summary.json') -Encoding UTF8
$summary | ConvertTo-Json -Depth 3
