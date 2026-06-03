Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$CaptureColumns = @('SERIAL_NUMBER','MANUFACTURER','DEVICE_INFO')
$ExceptionColumns = @('ERROR_TYPE','SERIAL_NUMBER','MANUFACTURER','DEVICE_INFO','ERROR_MESSAGE')

function Get-DefaultConfig {
    [pscustomobject]@{
        scriptVersion = '1.0.0'
        schoolFacingCsv = 'surface_release_capture.csv'
        exceptionsCsv = 'logs\exceptions.csv'
        unattendedMode = $true
        enableDuplicateDetection = $true
        defaultPostCaptureAction = 'wait'
    }
}

function Read-OriginConfig {
    param([string]$Root)

    $config = Get-DefaultConfig
    $candidates = @(
        (Join-Path $Root 'origin_config.json'),
        (Join-Path $Root 'config\origin_config.json')
    )

    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            try {
                $loaded = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
                foreach ($property in $loaded.PSObject.Properties) {
                    $config | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force
                }
            } catch {
                Write-Warning "Could not read config file $path. Defaults will be used. $($_.Exception.Message)"
            }
            break
        }
    }

    return $config
}

function Resolve-OriginPath {
    param([string]$Root, [string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path $Root $Path)
}

function Ensure-Csv {
    param([string]$Path, [string[]]$Columns)

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        ($Columns -join ',') | Set-Content -LiteralPath $Path -Encoding ASCII
    }
}

function Add-CsvRow {
    param([string]$Path, [string[]]$Columns, [hashtable]$Values)

    Ensure-Csv -Path $Path -Columns $Columns
    $ordered = [ordered]@{}
    foreach ($column in $Columns) {
        if ($Values.ContainsKey($column) -and $null -ne $Values[$column]) {
            $ordered[$column] = [string]$Values[$column]
        } else {
            $ordered[$column] = ''
        }
    }

    $csvLines = [pscustomobject]$ordered | ConvertTo-Csv -NoTypeInformation
    Add-Content -LiteralPath $Path -Value $csvLines[1] -Encoding ASCII
}

function Get-WmicValue {
    param([string[]]$Arguments, [string]$Key)

    try {
        $wmic = Get-Command wmic.exe -ErrorAction SilentlyContinue
        if (-not $wmic) { return '' }
        $output = & $wmic.Source @Arguments 2>$null
        foreach ($line in $output) {
            if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*)$") {
                return ($Matches[1]).Trim()
            }
        }
    } catch {
        return ''
    }

    return ''
}

function Get-WmiObjectValue {
    param([string]$Class, [string]$Property)

    try {
        $command = Get-Command Get-CimInstance -ErrorAction SilentlyContinue
        if ($command) {
            $item = Get-CimInstance -ClassName $Class -ErrorAction Stop | Select-Object -First 1
            return ([string]$item.$Property).Trim()
        }
    } catch {}

    try {
        $command = Get-Command Get-WmiObject -ErrorAction SilentlyContinue
        if ($command) {
            $item = Get-WmiObject -Class $Class -ErrorAction Stop | Select-Object -First 1
            return ([string]$item.$Property).Trim()
        }
    } catch {}

    return ''
}

function Get-FirstValue {
    param([string[]]$Values)

    foreach ($value in $Values) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }
    return ''
}

function Get-DeviceIdentity {
    $serial = Get-FirstValue @(
        (Get-WmicValue -Arguments @('bios','get','serialnumber','/value') -Key 'SerialNumber'),
        (Get-WmiObjectValue -Class 'Win32_BIOS' -Property 'SerialNumber')
    )
    $manufacturer = Get-FirstValue @(
        (Get-WmicValue -Arguments @('computersystem','get','manufacturer','/value') -Key 'Manufacturer'),
        (Get-WmiObjectValue -Class 'Win32_ComputerSystem' -Property 'Manufacturer')
    )
    $model = Get-FirstValue @(
        (Get-WmicValue -Arguments @('computersystem','get','model','/value') -Key 'Model'),
        (Get-WmiObjectValue -Class 'Win32_ComputerSystem' -Property 'Model')
    )

    [pscustomobject]@{
        SerialNumber = $serial
        Manufacturer = $manufacturer
        Model = $model
    }
}

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host 'ORIGIN CAPTURE LITE' -ForegroundColor Cyan
    Write-Host 'Surface / Windows Device Release Capture'
    Write-Host 'No internal drive boot required'
    Write-Host 'No wipe, no bypass, capture only'
    Write-Host ''
}

function Write-OriginException {
    param(
        [string]$Path,
        [string]$ErrorType,
        [object]$Device,
        [string]$Message
    )

    try {
        Add-CsvRow -Path $Path -Columns $ExceptionColumns -Values @{
            ERROR_TYPE = $ErrorType
            SERIAL_NUMBER = $(if ($Device) { $Device.SerialNumber } else { '' })
            MANUFACTURER = $(if ($Device) { $Device.Manufacturer } else { '' })
            DEVICE_INFO = $(if ($Device) { $Device.Model } else { '' })
            ERROR_MESSAGE = $Message
        }
    } catch {
        Write-Warning "Could not write exception log. $($_.Exception.Message)"
    }
}

function Test-DuplicateSerial {
    param([string]$CsvPath, [string]$SerialNumber)

    if (-not (Test-Path -LiteralPath $CsvPath)) { return $false }
    try {
        $rows = Import-Csv -LiteralPath $CsvPath
        foreach ($row in $rows) {
            if (($row.SERIAL_NUMBER).Trim().ToUpperInvariant() -eq $SerialNumber.Trim().ToUpperInvariant()) {
                return $true
            }
        }
    } catch {
        return $false
    }
    return $false
}

function Invoke-FinalAction {
    param([string]$Action, [string]$Message)

    $normalized = ([string]$Action).Trim().ToLowerInvariant()
    switch ($normalized) {
        'shutdown' {
            Write-Host ''
            Write-Host $Message
            Start-Sleep -Seconds 5
            try { wpeutil shutdown } catch { shutdown.exe /s /t 0 }
            return
        }
        'exit' {
            Write-Host ''
            Write-Host $Message
            Start-Sleep -Seconds 5
            return
        }
        default {
            Write-Host ''
            Write-Host $Message
            Write-Host 'It is safe to power off this device or move to the next unit.' -ForegroundColor Cyan
            while ($true) { Start-Sleep -Seconds 3600 }
        }
    }
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Config = Read-OriginConfig -Root $Root
$SchoolCsv = Resolve-OriginPath -Root $Root -Path $Config.schoolFacingCsv
$ExceptionsCsv = Resolve-OriginPath -Root $Root -Path $Config.exceptionsCsv

Ensure-Csv -Path $SchoolCsv -Columns $CaptureColumns
Ensure-Csv -Path $ExceptionsCsv -Columns $ExceptionColumns

Write-Banner
if ($true) {
    Write-Banner
    Write-Host 'Capturing hardware identity...'
    $device = $null

    try {
        $device = Get-DeviceIdentity
        $errors = @()
        if ([string]::IsNullOrWhiteSpace($device.SerialNumber)) { $errors += 'Serial number is blank.' }
        if ([string]::IsNullOrWhiteSpace($device.Manufacturer)) { $errors += 'Manufacturer is blank.' }
        if ([string]::IsNullOrWhiteSpace($device.Model)) { $errors += 'Model is blank.' }

        if ($errors.Count -gt 0) {
            $message = ($errors -join ' ')
            Write-OriginException -Path $ExceptionsCsv -ErrorType 'CAPTURE_VALIDATION_FAILED' -Device $device -Message $message
            Write-Host ''
            Write-Host 'CAPTURE FAILED' -ForegroundColor Red
            Write-Host $message
            Invoke-FinalAction -Action $Config.defaultPostCaptureAction -Message 'Capture failed. Exception log was saved if the USB was writable.'
            exit 1
        }

        if ([bool]$Config.enableDuplicateDetection -and (Test-DuplicateSerial -CsvPath $SchoolCsv -SerialNumber $device.SerialNumber)) {
            Write-OriginException -Path $ExceptionsCsv -ErrorType 'DUPLICATE_SERIAL' -Device $device -Message 'Duplicate serial detected before append.'
            Write-Host ''
            Write-Host 'DUPLICATE SERIAL DETECTED' -ForegroundColor Yellow
            Write-Host "Serial: $($device.SerialNumber)"
            Invoke-FinalAction -Action $Config.defaultPostCaptureAction -Message 'Duplicate attempt logged. No duplicate row was added.'
            exit 2
        }

        Add-CsvRow -Path $SchoolCsv -Columns $CaptureColumns -Values @{
            SERIAL_NUMBER = $device.SerialNumber
            MANUFACTURER = $device.Manufacturer
            DEVICE_INFO = $device.Model
        }

        Write-Host ''
        Write-Host '========================================' -ForegroundColor Green
        Write-Host 'ORIGIN INFO GATHERED' -ForegroundColor Green
        Write-Host 'Capture log saved.' -ForegroundColor Green
        Write-Host '========================================' -ForegroundColor Green
        Write-Host "Serial: $($device.SerialNumber)"
        Write-Host "Manufacturer: $($device.Manufacturer)"
        Write-Host "Device Info: $($device.Model)"
        Write-Host "Output CSV: $SchoolCsv"
        Invoke-FinalAction -Action $Config.defaultPostCaptureAction -Message 'Capture complete. Log is saved on the USB.'
        exit 0
    } catch {
        $message = $_.Exception.Message
        Write-OriginException -Path $ExceptionsCsv -ErrorType 'UNEXPECTED_FAILURE' -Device $device -Message $message
        Write-Host ''
        Write-Host 'CAPTURE FAILED' -ForegroundColor Red
        Write-Host $message
        Invoke-FinalAction -Action $Config.defaultPostCaptureAction -Message 'Capture failed. Exception log was saved if the USB was writable.'
        exit 1
    }
}

exit 0
