@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Origin Capture Lite

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CAPTURE_CSV=%SCRIPT_DIR%\surface_release_capture.csv"
set "EXCEPTION_CSV=%SCRIPT_DIR%\logs\exceptions.csv"

echo.
echo ORIGIN CAPTURE LITE
echo Surface / Windows Device Release Capture
echo No internal drive boot required
echo No wipe, no bypass, capture only
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 (
    call :RunBatchCapture
    exit /b %ERRORLEVEL%
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

:RunBatchCapture
echo PowerShell is not available. Using native WMIC capture mode.
echo.

if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" >nul 2>nul
call :EnsureCsv "%CAPTURE_CSV%" "SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO"
call :EnsureCsv "%EXCEPTION_CSV%" "ERROR_TYPE,SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO,ERROR_MESSAGE"

call :GetWmicValue "bios get serialnumber /value" "SerialNumber" SERIAL_NUMBER
call :GetWmicValue "computersystem get manufacturer /value" "Manufacturer" MANUFACTURER
call :GetWmicValue "computersystem get model /value" "Model" DEVICE_INFO

if not defined SERIAL_NUMBER call :GetWmicTableValue "bios get serialnumber" SERIAL_NUMBER
if not defined SERIAL_NUMBER call :GetWmicValue "csproduct get identifyingnumber /value" "IdentifyingNumber" SERIAL_NUMBER
if not defined SERIAL_NUMBER call :GetWmicTableValue "csproduct get identifyingnumber" SERIAL_NUMBER
if not defined MANUFACTURER call :GetWmicTableValue "computersystem get manufacturer" MANUFACTURER
if not defined DEVICE_INFO call :GetWmicTableValue "computersystem get model" DEVICE_INFO

if not defined SERIAL_NUMBER (
    call :WriteWmicDebug
    call :LogException "CAPTURE_VALIDATION_FAILED" "" "!MANUFACTURER!" "!DEVICE_INFO!" "Serial number is blank."
    call :ShowFailure "Serial number is blank."
    exit /b 1
)

if not defined MANUFACTURER (
    call :WriteWmicDebug
    call :LogException "CAPTURE_VALIDATION_FAILED" "!SERIAL_NUMBER!" "" "!DEVICE_INFO!" "Manufacturer is blank."
    call :ShowFailure "Manufacturer is blank."
    exit /b 1
)

if not defined DEVICE_INFO (
    call :WriteWmicDebug
    call :LogException "CAPTURE_VALIDATION_FAILED" "!SERIAL_NUMBER!" "!MANUFACTURER!" "" "Device info is blank."
    call :ShowFailure "Device info is blank."
    exit /b 1
)

findstr /i /c:"!SERIAL_NUMBER!" "%CAPTURE_CSV%" >nul 2>nul
if not errorlevel 1 (
    call :LogException "DUPLICATE_SERIAL" "!SERIAL_NUMBER!" "!MANUFACTURER!" "!DEVICE_INFO!" "Duplicate serial detected before append."
    echo.
    echo DUPLICATE SERIAL DETECTED
    echo Serial: !SERIAL_NUMBER!
    echo Duplicate attempt logged. No duplicate row was added.
    call :WaitForever
    exit /b 2
)

>> "%CAPTURE_CSV%" echo "!SERIAL_NUMBER!","!MANUFACTURER!","!DEVICE_INFO!"

echo.
echo ========================================
echo ORIGIN INFO GATHERED
echo Capture CSV saved.
echo ========================================
echo Serial: !SERIAL_NUMBER!
echo Manufacturer: !MANUFACTURER!
echo Device Info: !DEVICE_INFO!
echo Output CSV: %CAPTURE_CSV%
echo.
echo It is safe to power off this device or move to the next unit.
call :WaitForever
exit /b 0

:GetWmicValue
set "WMIC_ARGS=%~1"
set "WMIC_KEY=%~2"
set "WMIC_TARGET=%~3"
set "WMIC_OUT=%SCRIPT_DIR%\logs\wmic_value.tmp"
set "%WMIC_TARGET%="
wmic %WMIC_ARGS% > "%WMIC_OUT%" 2>nul
for /f "usebackq tokens=1,* delims==" %%A in ("%WMIC_OUT%") do (
    if /i "%%A"=="%WMIC_KEY%" (
        set "WMIC_VALUE=%%B"
        call :TrimValue WMIC_VALUE
        set "%WMIC_TARGET%=!WMIC_VALUE!"
    )
)
del "%WMIC_OUT%" >nul 2>nul
exit /b 0

:GetWmicTableValue
set "WMIC_ARGS=%~1"
set "WMIC_TARGET=%~2"
set "WMIC_OUT=%SCRIPT_DIR%\logs\wmic_table.tmp"
set "%WMIC_TARGET%="
wmic %WMIC_ARGS% > "%WMIC_OUT%" 2>nul
for /f "usebackq tokens=* delims=" %%A in ("%WMIC_OUT%") do (
    set "WMIC_VALUE=%%A"
    call :TrimValue WMIC_VALUE
    if defined WMIC_VALUE if /i not "!WMIC_VALUE!"=="SerialNumber" if /i not "!WMIC_VALUE!"=="IdentifyingNumber" if /i not "!WMIC_VALUE!"=="Manufacturer" if /i not "!WMIC_VALUE!"=="Model" (
        set "%WMIC_TARGET%=!WMIC_VALUE!"
        del "%WMIC_OUT%" >nul 2>nul
        exit /b 0
    )
)
del "%WMIC_OUT%" >nul 2>nul
exit /b 0

:TrimValue
set "TRIM_NAME=%~1"
for /f "tokens=* delims= " %%T in ("!%TRIM_NAME%!") do set "%TRIM_NAME%=%%T"
exit /b 0

:WriteWmicDebug
set "DEBUG_PATH=%SCRIPT_DIR%\logs\wmic_debug.txt"
(
    echo ORIGIN CAPTURE LITE WMIC DEBUG
    echo.
    echo COMMAND: wmic bios get serialnumber
    wmic bios get serialnumber
    echo.
    echo COMMAND: wmic bios get serialnumber /value
    wmic bios get serialnumber /value
    echo.
    echo COMMAND: wmic csproduct get identifyingnumber
    wmic csproduct get identifyingnumber
    echo.
    echo COMMAND: wmic computersystem get manufacturer
    wmic computersystem get manufacturer
    echo.
    echo COMMAND: wmic computersystem get model
    wmic computersystem get model
) > "%DEBUG_PATH%" 2>&1
exit /b 0

:EnsureCsv
set "CSV_PATH=%~1"
set "CSV_HEADER=%~2"
if exist "%CSV_PATH%" (
    set /p CURRENT_HEADER=<"%CSV_PATH%"
    if not "!CURRENT_HEADER!"=="%CSV_HEADER%" (
        ren "%CSV_PATH%" "%~nx1.old-format-%DATE:~-4%%DATE:~4,2%%DATE:~7,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.csv" >nul 2>nul
    )
)
if not exist "%CSV_PATH%" echo %CSV_HEADER%>"%CSV_PATH%"
exit /b 0

:LogException
call :EnsureCsv "%EXCEPTION_CSV%" "ERROR_TYPE,SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO,ERROR_MESSAGE"
>> "%EXCEPTION_CSV%" echo "%~1","%~2","%~3","%~4","%~5"
exit /b 0

:ShowFailure
echo.
echo CAPTURE FAILED
echo %~1
echo Exception log was saved if the USB was writable.
echo WMIC debug saved to: %SCRIPT_DIR%\logs\wmic_debug.txt
call :WaitForever
exit /b 0

:WaitForever
cmd /k
exit /b 0
