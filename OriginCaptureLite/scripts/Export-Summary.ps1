Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$schoolCsv = Join-Path $root 'surface_release_capture.csv'

if (-not (Test-Path -LiteralPath $schoolCsv)) {
    throw "No school-facing CSV found at $schoolCsv"
}

$rows = Import-Csv -LiteralPath $schoolCsv
$total = @($rows).Count
$duplicates = $rows | Group-Object SERIAL_NUMBER | Where-Object { $_.Count -gt 1 }

Write-Host 'Origin Capture Lite Summary'
Write-Host "CSV: $schoolCsv"
Write-Host "Total captured rows: $total"
Write-Host "Duplicate serial groups: $(@($duplicates).Count)"
