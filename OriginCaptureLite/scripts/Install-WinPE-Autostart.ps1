param(
    [Parameter(Mandatory = $true)]
    [string]$UsbDrive
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Resolve-DriveRoot {
    param([string]$Drive)

    if ($Drive.Length -eq 1) {
        return "$Drive`:\"
    }

    if ($Drive.Length -eq 2 -and $Drive.EndsWith(':')) {
        return "$Drive\"
    }

    return $Drive
}

$usbRoot = Resolve-DriveRoot -Drive $UsbDrive
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$runtimeRoot = Join-Path $usbRoot 'OriginCapture'
$bootWim = Join-Path $usbRoot 'sources\boot.wim'
$mountRoot = Join-Path $env:TEMP 'OriginCapture_WinPE_Mount'

if (-not (Test-Path -LiteralPath $bootWim)) {
    throw "Could not find WinPE boot image at $bootWim"
}

Write-Host "Preparing runtime folder at $runtimeRoot"
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeRoot 'logs') | Out-Null
Copy-Item -LiteralPath (Join-Path $scriptRoot 'Capture-OriginLite.cmd') -Destination (Join-Path $runtimeRoot 'Capture-OriginLite.cmd') -Force
Copy-Item -LiteralPath (Join-Path $scriptRoot 'Capture-OriginLite.ps1') -Destination (Join-Path $runtimeRoot 'Capture-OriginLite.ps1') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'config\origin_config.json') -Destination (Join-Path $runtimeRoot 'origin_config.json') -Force

if (Test-Path -LiteralPath $mountRoot) {
    throw "Mount folder already exists: $mountRoot. Remove it only after confirming no DISM mount is active."
}

New-Item -ItemType Directory -Force -Path $mountRoot | Out-Null

try {
    Write-Host "Mounting $bootWim"
    & dism.exe /Mount-Image /ImageFile:$bootWim /Index:1 /MountDir:$mountRoot | Write-Host

    $targetStartnet = Join-Path $mountRoot 'Windows\System32\Startnet.cmd'
    Write-Host "Installing auto-launch Startnet.cmd"
    Copy-Item -LiteralPath (Join-Path $scriptRoot 'Startnet.cmd') -Destination $targetStartnet -Force

    Write-Host 'Committing WinPE boot image'
    & dism.exe /Unmount-Image /MountDir:$mountRoot /Commit | Write-Host
} catch {
    Write-Warning "Install failed: $($_.Exception.Message)"
    if (Test-Path -LiteralPath $mountRoot) {
        Write-Warning 'Attempting to discard mounted image changes.'
        & dism.exe /Unmount-Image /MountDir:$mountRoot /Discard | Write-Host
    }
    throw
}

Write-Host ''
Write-Host 'Origin Capture Lite USB is ready.'
Write-Host 'On boot, WinPE will locate \OriginCapture and launch Capture-OriginLite.cmd automatically.'

