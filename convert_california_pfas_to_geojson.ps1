$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceDir = Join-Path $PSScriptRoot 'data\california\pfas'
$outputDir = Join-Path $sourceDir 'geojson'
$tempDir = Join-Path $outputDir '_conversion_temp'
New-Item -ItemType Directory -Force -Path $outputDir,$tempDir | Out-Null

Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using Microsoft.VisualBasic.FileIO;

public static class CsvGeoJsonConverter {
    static string J(string s) {
        if (s == null) return "null";
        var b = new StringBuilder(s.Length + 8); b.Append('"');
        foreach (char c in s) {
            switch(c) {
                case '"': b.Append("\\\""); break; case '\\': b.Append("\\\\"); break;
                case '\b': b.Append("\\b"); break; case '\f': b.Append("\\f"); break;
                case '\n': b.Append("\\n"); break; case '\r': b.Append("\\r"); break; case '\t': b.Append("\\t"); break;
                default: if (c < 32) b.Append("\\u" + ((int)c).ToString("x4")); else b.Append(c); break;
            }
        }
        return b.Append('"').ToString();
    }
    public static long Convert(string input, string output, string latName, string lonName, string sourceName) {
        long count=0; using(var p=new TextFieldParser(input)) using(var w=new StreamWriter(output,false,new UTF8Encoding(false),1<<20)) {
            p.TextFieldType=FieldType.Delimited; p.SetDelimiters(","); p.HasFieldsEnclosedInQuotes=true;
            string[] h=p.ReadFields(); var index=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);
            for(int i=0;i<h.Length;i++) index[h[i]]=i;
            int lati=index.ContainsKey(latName)?index[latName]:-1, loni=index.ContainsKey(lonName)?index[lonName]:-1;
            w.Write("{\"type\":\"FeatureCollection\",\"features\":["); bool first=true;
            while(!p.EndOfData) {
                string[] f; try { f=p.ReadFields(); } catch(MalformedLineException) { continue; }
                if(f.Length!=h.Length) continue; double lat=0,lon=0; bool located=lati>=0 && loni>=0 &&
                    double.TryParse(f[lati],System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out lat) &&
                    double.TryParse(f[loni],System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out lon) &&
                    lat>=-90 && lat<=90 && lon>=-180 && lon<=180;
                if(!first) w.Write(','); first=false; count++;
                w.Write("{\"type\":\"Feature\",\"geometry\":");
                if(located) w.Write("{\"type\":\"Point\",\"coordinates\":["+lon.ToString("R",System.Globalization.CultureInfo.InvariantCulture)+","+lat.ToString("R",System.Globalization.CultureInfo.InvariantCulture)+"]}");
                else w.Write("null");
                w.Write(",\"properties\":{\"source_dataset\":"+J(sourceName));
                for(int i=0;i<h.Length;i++) w.Write(","+J(h[i])+":"+J(f[i]));
                w.Write("}}");
            }
            w.Write("]}");
        } return count;
    }
}
'@ -ReferencedAssemblies Microsoft.VisualBasic

function Get-ColumnIndex([string]$reference) {
    $letters = ([regex]::Match($reference,'^[A-Z]+')).Value; $n=0
    foreach($c in $letters.ToCharArray()){ $n=$n*26+([int]$c-[int][char]'A'+1) }; $n-1
}

function Export-XlsxSheetsToCsv([string]$xlsx,[int[]]$sheets,[int]$headerRow,[string]$csv) {
    $zip=[IO.Compression.ZipFile]::OpenRead($xlsx)
    try {
        $shared=@(); $entry=$zip.GetEntry('xl/sharedStrings.xml')
        if($entry){$reader=[IO.StreamReader]::new($entry.Open());[xml]$xml=$reader.ReadToEnd();$reader.Dispose();foreach($si in $xml.sst.si){$shared += (($si.SelectNodes('.//*[local-name()="t"]')|ForEach-Object{$_.InnerText}) -join '')}}
        $writer=[IO.StreamWriter]::new($csv,$false,[Text.UTF8Encoding]::new($false))
        try {
            $headers=$null
            foreach($sheetNo in $sheets){
                $entry=$zip.GetEntry("xl/worksheets/sheet$sheetNo.xml"); if(-not $entry){continue}
                $reader=[IO.StreamReader]::new($entry.Open());[xml]$xml=$reader.ReadToEnd();$reader.Dispose()
                foreach($row in $xml.worksheet.sheetData.row){
                    if([int]$row.r -lt $headerRow){continue}; $map=@{}; $max=-1
                    foreach($cell in $row.c){$i=Get-ColumnIndex $cell.r;$v=[string]$cell.v;if($cell.t -eq 's' -and $v -ne ''){$v=$shared[[int]$v]};$map[$i]=$v;$max=[Math]::Max($max,$i)}
                    if([int]$row.r -eq $headerRow){if(-not $headers){$headers=0..$max|ForEach-Object{[string]$map[$_]};$writer.WriteLine(($headers|ForEach-Object{'"'+($_ -replace '"','""')+'"'})-join ',')};continue}
                    $values=0..($headers.Count-1)|ForEach-Object{if($map.ContainsKey($_)){[string]$map[$_]}else{''}}
                    $writer.WriteLine(($values|ForEach-Object{'"'+($_ -replace '"','""')+'"'})-join ',')
                }
            }
        } finally {$writer.Dispose()}
    } finally {$zip.Dispose()}
}

$results=@()
$gamaOut=Join-Path $outputDir 'ca-gama-pfas-statewide.geojson'
$n=[CsvGeoJsonConverter]::Convert((Join-Path $sourceDir 'ca-gama-pfas-statewide.csv'),$gamaOut,'gm_latitude','gm_longitude','California GAMA statewide PFAS')
$results += [pscustomobject]@{file=(Split-Path $gamaOut -Leaf);features=$n;geometry='Point'}

$ddwCsv=Join-Path $tempDir 'ddw-ordered-monitoring.csv'
Export-XlsxSheetsToCsv (Join-Path $sourceDir 'ca-ddw-pfas-ordered-monitoring-2019-q1-q4.xlsx') @(1,2,3,4) 3 $ddwCsv
$ddwOut=Join-Path $outputDir 'ca-ddw-pfas-ordered-monitoring-2019-q1-q4.geojson'
$n=[CsvGeoJsonConverter]::Convert($ddwCsv,$ddwOut,'Latitude','Longitude','California DDW ordered PFAS monitoring 2019-2020')
$results += [pscustomobject]@{file=(Split-Path $ddwOut -Leaf);features=$n;geometry='Point'}

$sites=@{}; Import-Csv (Join-Path $sourceDir 'ca-swp-water-quality-sampling-sites.csv') | ForEach-Object {$sites[$_.SiteNumber]=$_}
$swpCsv=Join-Path $tempDir 'swp-pfas-with-coordinates.csv'
Import-Csv (Join-Path $sourceDir 'ca-swp-pfas.csv') | ForEach-Object {$s=$sites[$_.SiteNumber];$_|Add-Member Latitude $s.Latitude;$_|Add-Member Longitude $s.Longitude;$_} | Export-Csv $swpCsv -NoTypeInformation -Encoding UTF8
$swpOut=Join-Path $outputDir 'ca-swp-pfas.geojson'
$n=[CsvGeoJsonConverter]::Convert($swpCsv,$swpOut,'Latitude','Longitude','California State Water Project PFAS')
$results += [pscustomobject]@{file=(Split-Path $swpOut -Leaf);features=$n;geometry='Point where site matched'}

$ucmrCsv=Join-Path $tempDir 'ucmr3.csv'
Export-XlsxSheetsToCsv (Join-Path $sourceDir 'ca-ucmr3-pfos-pfoa-summary.xlsx') @(1,2,3) 1 $ucmrCsv
$ucmrOut=Join-Path $outputDir 'ca-ucmr3-pfos-pfoa-summary.geojson'
$n=[CsvGeoJsonConverter]::Convert($ucmrCsv,$ucmrOut,'__no_latitude__','__no_longitude__','California UCMR3 PFOS/PFOA summary')
$results += [pscustomobject]@{file=(Split-Path $ucmrOut -Leaf);features=$n;geometry='null (source has no coordinates)'}

$results | Export-Csv (Join-Path $outputDir 'conversion-report.csv') -NoTypeInformation -Encoding UTF8
$generatedTemp = (Resolve-Path $tempDir).Path
if ($generatedTemp.StartsWith((Resolve-Path $outputDir).Path, [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $generatedTemp -Recurse -Force
}
$results | Format-Table -AutoSize
