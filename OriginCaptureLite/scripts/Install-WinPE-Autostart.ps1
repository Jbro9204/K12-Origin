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
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeRoot 'assets') | Out-Null
Copy-Item -LiteralPath (Join-Path $scriptRoot 'Capture-OriginLite.cmd') -Destination (Join-Path $runtimeRoot 'Capture-OriginLite.cmd') -Force
Copy-Item -LiteralPath (Join-Path $scriptRoot 'Capture-OriginLite.ps1') -Destination (Join-Path $runtimeRoot 'Capture-OriginLite.ps1') -Force
Copy-Item -LiteralPath (Join-Path $scriptRoot 'Capture-OriginLite.vbs') -Destination (Join-Path $runtimeRoot 'Capture-OriginLite.vbs') -Force
Copy-Item -LiteralPath (Join-Path $scriptRoot 'Capture-OriginLite.hta') -Destination (Join-Path $runtimeRoot 'Capture-OriginLite.hta') -Force
Copy-Item -LiteralPath (Join-Path $scriptRoot 'assets\New Origin Trans.png') -Destination (Join-Path $runtimeRoot 'assets\New Origin Trans.png') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'config\origin_config.json') -Destination (Join-Path $runtimeRoot 'origin_config.json') -Force

function Get-WinPeOcRoot {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs",
        "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Add-WinPeOptionalComponent {
    param(
        [string]$MountRoot,
        [string]$OcRoot,
        [string]$PackageName
    )

    $packagePath = Join-Path $OcRoot "$PackageName.cab"
    if (-not (Test-Path -LiteralPath $packagePath)) {
        throw "Required WinPE optional component was not found: $packagePath"
    }

    Write-Host "Adding $PackageName"
    & dism.exe /Image:$MountRoot /Add-Package /PackagePath:$packagePath | Write-Host

    $languagePackagePath = Join-Path $OcRoot "en-us\$($PackageName)_en-us.cab"
    if (Test-Path -LiteralPath $languagePackagePath) {
        Write-Host "Adding $PackageName en-us language package"
        & dism.exe /Image:$MountRoot /Add-Package /PackagePath:$languagePackagePath | Write-Host
    }
}

function Add-WinPeOptionalComponentIfAvailable {
    param(
        [string]$MountRoot,
        [string]$OcRoot,
        [string]$PackageName
    )

    $packagePath = Join-Path $OcRoot "$PackageName.cab"
    if (-not (Test-Path -LiteralPath $packagePath)) {
        Write-Warning "Optional visual component was not found: $packagePath"
        return
    }

    Add-WinPeOptionalComponent -MountRoot $MountRoot -OcRoot $OcRoot -PackageName $PackageName
}

if (Test-Path -LiteralPath $mountRoot) {
    $mountInfo = & dism.exe /Get-MountedWimInfo
    $mountText = ($mountInfo -join "`n")
    if ($mountText -match [regex]::Escape($mountRoot)) {
        throw "DISM still has an image mounted at $mountRoot. Run: dism /Unmount-Image /MountDir:`"$mountRoot`" /Discard"
    }

    Write-Host "Removing stale mount folder: $mountRoot"
    Remove-Item -LiteralPath $mountRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $mountRoot | Out-Null

try {
    Write-Host "Mounting $bootWim"
    & dism.exe /Mount-Image /ImageFile:$bootWim /Index:1 /MountDir:$mountRoot | Write-Host

    $ocRoot = Get-WinPeOcRoot
    if (-not $ocRoot) {
        throw 'Could not find ADK WinPE optional components. Install the Windows PE add-on for the Windows ADK.'
    }

    Add-WinPeOptionalComponent -MountRoot $mountRoot -OcRoot $ocRoot -PackageName 'WinPE-WMI'
    Add-WinPeOptionalComponent -MountRoot $mountRoot -OcRoot $ocRoot -PackageName 'WinPE-Scripting'
    Add-WinPeOptionalComponentIfAvailable -MountRoot $mountRoot -OcRoot $ocRoot -PackageName 'WinPE-HTA'

    $targetStartnet = Join-Path $mountRoot 'Windows\System32\Startnet.cmd'
    Write-Host "Installing auto-launch Startnet.cmd"
    Copy-Item -LiteralPath (Join-Path $scriptRoot 'Startnet.cmd') -Destination $targetStartnet -Force

    $installedStartnet = Get-Content -LiteralPath $targetStartnet -Raw
    if ($installedStartnet -notmatch 'OriginCapture\\Capture-OriginLite\.cmd') {
        throw 'Startnet.cmd verification failed. The mounted WinPE image does not contain the Origin Capture auto-launch command.'
    }

    Write-Host 'Verified Startnet.cmd contains Origin Capture auto-launch command.'

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
