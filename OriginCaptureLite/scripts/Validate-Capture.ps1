Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$requiredFiles = @(
    'Capture-OriginLite.cmd',
    'Capture-OriginLite.ps1',
    'origin_config.json'
)

$requiredSchoolColumns = 'SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO'

Write-Host 'Origin Capture Lite validation'
Write-Host "Runtime folder: $root"

foreach ($file in $requiredFiles) {
    $path = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required runtime file: $file"
    }
    Write-Host "OK: $file"
}

$schoolCsv = Join-Path $root 'surface_release_capture.csv'
if (Test-Path -LiteralPath $schoolCsv) {
    $header = Get-Content -LiteralPath $schoolCsv -TotalCount 1
    if ($header -ne $requiredSchoolColumns) {
        throw 'surface_release_capture.csv header does not match required columns.'
    }
    Write-Host 'OK: surface_release_capture.csv header'
}

Write-Host 'Validation complete.'
