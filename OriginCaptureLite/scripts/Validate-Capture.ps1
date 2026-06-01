Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$requiredFiles = @(
    'Capture-OriginLite.cmd',
    'Capture-OriginLite.ps1',
    'origin_config.json'
)

$requiredSchoolColumns = 'SERIAL_NUMBER,MANUFACTURER,MODEL,CAPTURE_TIME,STATION_ID,OPERATOR_ID,PO_NUMBER,LOT_NUMBER,PALLET_ID,STATUS'
$requiredAuditColumns = 'CAPTURE_TIME,SCRIPT_VERSION,STATION_ID,OPERATOR_ID,PO_NUMBER,LOT_NUMBER,PALLET_ID,SERIAL_NUMBER,MANUFACTURER,MODEL,UUID,IDENTIFYING_NUMBER,PRODUCT_NAME,VENDOR,BIOS_VERSION,STATUS,RESULT,ERROR_MESSAGE'

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

$auditCsv = Join-Path $root 'origin_capture_audit_log.csv'
if (Test-Path -LiteralPath $auditCsv) {
    $header = Get-Content -LiteralPath $auditCsv -TotalCount 1
    if ($header -ne $requiredAuditColumns) {
        throw 'origin_capture_audit_log.csv header does not match required columns.'
    }
    Write-Host 'OK: origin_capture_audit_log.csv header'
}

Write-Host 'Validation complete.'

