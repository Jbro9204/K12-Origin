@echo off
setlocal EnableExtensions
title Origin Capture Lite

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo.
echo ORIGIN CAPTURE LITE
echo Surface / Windows Device Release Capture
echo No internal drive boot required
echo No wipe, no bypass, capture only
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: PowerShell is not available in this WinPE image.
    echo Origin Capture Lite requires PowerShell for safe CSV writing and duplicate detection.
    echo Rebuild WinPE with PowerShell support or use a Windows PE image that includes PowerShell.
    echo.
    if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" >nul 2>nul
    >> "%SCRIPT_DIR%\logs\exceptions.csv" echo ERROR_TYPE,SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO,ERROR_MESSAGE
    >> "%SCRIPT_DIR%\logs\exceptions.csv" echo "POWERSHELL_UNAVAILABLE","","","","PowerShell was not available; capture did not run."
    cmd /k
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Capture-OriginLite.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo Capture script exited with code %EXIT_CODE%.
    echo A command prompt will remain open for troubleshooting.
    cmd /k
)

exit /b %EXIT_CODE%
