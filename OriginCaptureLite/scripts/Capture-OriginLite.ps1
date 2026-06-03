Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$SchoolColumns = @('SERIAL_NUMBER','MANUFACTURER','MODEL','CAPTURE_TIME','STATION_ID','OPERATOR_ID','PO_NUMBER','LOT_NUMBER','PALLET_ID','STATUS')
$AuditColumns = @('CAPTURE_TIME','SCRIPT_VERSION','STATION_ID','OPERATOR_ID','PO_NUMBER','LOT_NUMBER','PALLET_ID','SERIAL_NUMBER','MANUFACTURER','MODEL','UUID','IDENTIFYING_NUMBER','PRODUCT_NAME','VENDOR','BIOS_VERSION','STATUS','RESULT','ERROR_MESSAGE')
$ExceptionColumns = @('CAPTURE_TIME','STATION_ID','OPERATOR_ID','PO_NUMBER','LOT_NUMBER','PALLET_ID','ERROR_TYPE','SERIAL_NUMBER','MANUFACTURER','MODEL','ERROR_MESSAGE')

function Get-DefaultConfig {
    [pscustomobject]@{
        scriptVersion = '1.0.0'
        defaultStatus = 'PENDING MDM AUTOPILOT RELEASE'
        schoolFacingCsv = 'surface_release_capture.csv'
        auditLogCsv = 'origin_capture_audit_log.csv'
        exceptionsCsv = 'logs\exceptions.csv'
        unattendedMode = $true
        defaultPoNumber = 'UNASSIGNED'
        defaultLotNumber = 'UNASSIGNED'
        defaultPalletId = 'UNASSIGNED'
        defaultStationId = 'AUTO-STATION'
        defaultOperatorId = 'AUTO-CAPTURE'
        requireOperatorId = $false
        requirePoNumber = $false
        requireLotNumber = $false
        requirePalletId = $false
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

    [pscustomobject]$ordered | Export-Csv -LiteralPath $Path -NoTypeInformation -Append -Encoding ASCII
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
        UUID = Get-FirstValue @((Get-WmicValue -Arguments @('csproduct','get','uuid','/value') -Key 'UUID'), (Get-WmiObjectValue -Class 'Win32_ComputerSystemProduct' -Property 'UUID'))
        IdentifyingNumber = Get-FirstValue @((Get-WmicValue -Arguments @('csproduct','get','identifyingnumber','/value') -Key 'IdentifyingNumber'), (Get-WmiObjectValue -Class 'Win32_ComputerSystemProduct' -Property 'IdentifyingNumber'))
        ProductName = Get-FirstValue @((Get-WmicValue -Arguments @('csproduct','get','name','/value') -Key 'Name'), (Get-WmiObjectValue -Class 'Win32_ComputerSystemProduct' -Property 'Name'))
        Vendor = Get-FirstValue @((Get-WmicValue -Arguments @('csproduct','get','vendor','/value') -Key 'Vendor'), (Get-WmiObjectValue -Class 'Win32_ComputerSystemProduct' -Property 'Vendor'))
        BiosVersion = Get-FirstValue @((Get-WmicValue -Arguments @('bios','get','smbiosbiosversion','/value') -Key 'SMBIOSBIOSVersion'), (Get-WmiObjectValue -Class 'Win32_BIOS' -Property 'SMBIOSBIOSVersion'))
    }
}

function Read-RequiredValue {
    param([string]$Label, [bool]$Required)

    do {
        $value = Read-Host $Label
        $value = $value.Trim()
        if (-not $Required -or -not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
        Write-Host "$Label is required." -ForegroundColor Yellow
    } while ($true)
}

function Get-ConfigValue {
    param([object]$Config, [string]$PropertyName, [string]$Fallback)

    $property = $Config.PSObject.Properties[$PropertyName]
    if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        return ([string]$property.Value).Trim()
    }

    return $Fallback
}

function New-OriginSession {
    param([object]$Config)

    if ([bool]$Config.unattendedMode) {
        return @{
            PO_NUMBER = Get-ConfigValue -Config $Config -PropertyName 'defaultPoNumber' -Fallback 'UNASSIGNED'
            LOT_NUMBER = Get-ConfigValue -Config $Config -PropertyName 'defaultLotNumber' -Fallback 'UNASSIGNED'
            PALLET_ID = Get-ConfigValue -Config $Config -PropertyName 'defaultPalletId' -Fallback 'UNASSIGNED'
            STATION_ID = Get-ConfigValue -Config $Config -PropertyName 'defaultStationId' -Fallback 'AUTO-STATION'
            OPERATOR_ID = Get-ConfigValue -Config $Config -PropertyName 'defaultOperatorId' -Fallback 'AUTO-CAPTURE'
        }
    }

    return @{
        PO_NUMBER = Read-RequiredValue -Label 'PO Number' -Required ([bool]$Config.requirePoNumber)
        LOT_NUMBER = Read-RequiredValue -Label 'Lot Number' -Required ([bool]$Config.requireLotNumber)
        PALLET_ID = Read-RequiredValue -Label 'Pallet ID' -Required ([bool]$Config.requirePalletId)
        STATION_ID = Read-RequiredValue -Label 'Station ID' -Required $true
        OPERATOR_ID = Read-RequiredValue -Label 'Operator ID' -Required ([bool]$Config.requireOperatorId)
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
        [hashtable]$Session,
        [string]$ErrorType,
        [object]$Device,
        [string]$Message
    )

    try {
        Add-CsvRow -Path $Path -Columns $ExceptionColumns -Values @{
            CAPTURE_TIME = (Get-Date).ToString('s')
            STATION_ID = $Session['STATION_ID']
            OPERATOR_ID = $Session['OPERATOR_ID']
            PO_NUMBER = $Session['PO_NUMBER']
            LOT_NUMBER = $Session['LOT_NUMBER']
            PALLET_ID = $Session['PALLET_ID']
            ERROR_TYPE = $ErrorType
            SERIAL_NUMBER = $(if ($Device) { $Device.SerialNumber } else { '' })
            MANUFACTURER = $(if ($Device) { $Device.Manufacturer } else { '' })
            MODEL = $(if ($Device) { $Device.Model } else { '' })
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

function Invoke-PostCaptureMenu {
    param([string]$DefaultAction)

    Write-Host ''
    Write-Host '1. Shut down device'
    Write-Host '2. Re-run capture'
    Write-Host '3. Open command prompt'
    Write-Host '4. Exit'
    $choice = Read-Host 'Select action [1]'
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }

    switch ($choice) {
        '1' {
            Write-Host 'Shutting down...'
            try { wpeutil shutdown } catch { shutdown.exe /s /t 0 }
            return 'exit'
        }
        '2' { return 'rerun' }
        '3' { cmd.exe; return 'rerun' }
        '4' { return 'exit' }
        default { return 'rerun' }
    }
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
$AuditCsv = Resolve-OriginPath -Root $Root -Path $Config.auditLogCsv
$ExceptionsCsv = Resolve-OriginPath -Root $Root -Path $Config.exceptionsCsv

Ensure-Csv -Path $SchoolCsv -Columns $SchoolColumns
Ensure-Csv -Path $AuditCsv -Columns $AuditColumns
Ensure-Csv -Path $ExceptionsCsv -Columns $ExceptionColumns

Write-Banner
$Session = New-OriginSession -Config $Config

do {
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
            Write-OriginException -Path $ExceptionsCsv -Session $Session -ErrorType 'CAPTURE_VALIDATION_FAILED' -Device $device -Message $message
            Write-Host ''
            Write-Host 'CAPTURE FAILED' -ForegroundColor Red
            Write-Host $message
            if ([bool]$Config.unattendedMode) {
                Invoke-FinalAction -Action $Config.defaultPostCaptureAction -Message 'Capture failed. Exception log was saved if the USB was writable.'
                exit 1
            }
            $action = Invoke-PostCaptureMenu -DefaultAction $Config.defaultPostCaptureAction
            continue
        }

        if ([bool]$Config.enableDuplicateDetection -and (Test-DuplicateSerial -CsvPath $SchoolCsv -SerialNumber $device.SerialNumber)) {
            Write-OriginException -Path $ExceptionsCsv -Session $Session -ErrorType 'DUPLICATE_SERIAL' -Device $device -Message 'Duplicate serial detected before append.'
            Write-Host ''
            Write-Host 'DUPLICATE SERIAL DETECTED' -ForegroundColor Yellow
            Write-Host "Serial: $($device.SerialNumber)"
            if ([bool]$Config.unattendedMode) {
                Invoke-FinalAction -Action $Config.defaultPostCaptureAction -Message 'Duplicate attempt logged. No duplicate row was added.'
                exit 2
            }
            $confirm = Read-Host 'Append duplicate row anyway? Type YES to confirm'
            if ($confirm -ne 'YES') {
                $action = Invoke-PostCaptureMenu -DefaultAction $Config.defaultPostCaptureAction
                continue
            }
        }

        $captureTime = (Get-Date).ToString('s')
        $status = [string]$Config.defaultStatus

        Add-CsvRow -Path $SchoolCsv -Columns $SchoolColumns -Values @{
            SERIAL_NUMBER = $device.SerialNumber
            MANUFACTURER = $device.Manufacturer
            MODEL = $device.Model
            CAPTURE_TIME = $captureTime
            STATION_ID = $Session['STATION_ID']
            OPERATOR_ID = $Session['OPERATOR_ID']
            PO_NUMBER = $Session['PO_NUMBER']
            LOT_NUMBER = $Session['LOT_NUMBER']
            PALLET_ID = $Session['PALLET_ID']
            STATUS = $status
        }

        Add-CsvRow -Path $AuditCsv -Columns $AuditColumns -Values @{
            CAPTURE_TIME = $captureTime
            SCRIPT_VERSION = $Config.scriptVersion
            STATION_ID = $Session['STATION_ID']
            OPERATOR_ID = $Session['OPERATOR_ID']
            PO_NUMBER = $Session['PO_NUMBER']
            LOT_NUMBER = $Session['LOT_NUMBER']
            PALLET_ID = $Session['PALLET_ID']
            SERIAL_NUMBER = $device.SerialNumber
            MANUFACTURER = $device.Manufacturer
            MODEL = $device.Model
            UUID = $device.UUID
            IDENTIFYING_NUMBER = $device.IdentifyingNumber
            PRODUCT_NAME = $device.ProductName
            VENDOR = $device.Vendor
            BIOS_VERSION = $device.BiosVersion
            STATUS = $status
            RESULT = 'SUCCESS'
            ERROR_MESSAGE = ''
        }

        Write-Host ''
        Write-Host '========================================' -ForegroundColor Green
        Write-Host 'ORIGIN INFO GATHERED' -ForegroundColor Green
        Write-Host 'Capture log saved.' -ForegroundColor Green
        Write-Host '========================================' -ForegroundColor Green
        Write-Host "Serial: $($device.SerialNumber)"
        Write-Host "Manufacturer: $($device.Manufacturer)"
        Write-Host "Model: $($device.Model)"
        Write-Host "Release CSV: $SchoolCsv"
        Write-Host "Audit Log: $AuditCsv"
        if ([bool]$Config.unattendedMode) {
            Invoke-FinalAction -Action $Config.defaultPostCaptureAction -Message 'Capture complete. Logs are saved on the USB.'
            exit 0
        }
    } catch {
        $message = $_.Exception.Message
        Write-OriginException -Path $ExceptionsCsv -Session $Session -ErrorType 'UNEXPECTED_FAILURE' -Device $device -Message $message
        Write-Host ''
        Write-Host 'CAPTURE FAILED' -ForegroundColor Red
        Write-Host $message
        if ([bool]$Config.unattendedMode) {
            Invoke-FinalAction -Action $Config.defaultPostCaptureAction -Message 'Capture failed. Exception log was saved if the USB was writable.'
            exit 1
        }
    }

    $action = Invoke-PostCaptureMenu -DefaultAction $Config.defaultPostCaptureAction
} while ($action -eq 'rerun')

exit 0
