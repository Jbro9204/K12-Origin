@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Origin Capture Lite
color 0B
mode con: cols=100 lines=32 >nul 2>nul

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "CAPTURE_CSV=%SCRIPT_DIR%\surface_release_capture.csv"
set "EXCEPTION_CSV=%SCRIPT_DIR%\logs\exceptions.csv"
set "DEBUG_PATH=%SCRIPT_DIR%\logs\wmic_debug.txt"

call :ShowHeader "READY" "Ready to capture device identity."

if not exist "%SCRIPT_DIR%\logs" mkdir "%SCRIPT_DIR%\logs" >nul 2>nul
call :EnsureCsv "%CAPTURE_CSV%" "SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO"
call :EnsureCsv "%EXCEPTION_CSV%" "ERROR_TYPE,SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO,ERROR_MESSAGE"

if exist "%SystemRoot%\System32\mshta.exe" if exist "%SCRIPT_DIR%\Capture-OriginLite.hta" (
    "%SystemRoot%\System32\mshta.exe" "%SCRIPT_DIR%\Capture-OriginLite.hta"
    exit /b !ERRORLEVEL!
)

if exist "%SystemRoot%\System32\cscript.exe" if exist "%SCRIPT_DIR%\Capture-OriginLite.vbs" (
    cscript.exe //nologo "%SCRIPT_DIR%\Capture-OriginLite.vbs"
    set "VBS_EXIT=%ERRORLEVEL%"
    call :HoldScreen
    exit /b !VBS_EXIT!
)

call :ShowHeader "CAPTURING" "Capturing device information..."
call :WriteWmicDebug

call :GetWmicListValue "bios get serialnumber /value" "SerialNumber" SERIAL_NUMBER
if not defined SERIAL_NUMBER call :GetWmicTableValue "bios get serialnumber" "SerialNumber" SERIAL_NUMBER
if not defined SERIAL_NUMBER call :GetWmicListValue "csproduct get identifyingnumber /value" "IdentifyingNumber" SERIAL_NUMBER
if not defined SERIAL_NUMBER call :GetWmicTableValue "csproduct get identifyingnumber" "IdentifyingNumber" SERIAL_NUMBER

call :GetWmicListValue "computersystem get manufacturer /value" "Manufacturer" MANUFACTURER
if not defined MANUFACTURER call :GetWmicTableValue "computersystem get manufacturer" "Manufacturer" MANUFACTURER

call :GetWmicListValue "computersystem get model /value" "Model" DEVICE_INFO
if not defined DEVICE_INFO call :GetWmicTableValue "computersystem get model" "Model" DEVICE_INFO

if not defined SERIAL_NUMBER (
    call :LogException "CAPTURE_VALIDATION_FAILED" "" "!MANUFACTURER!" "!DEVICE_INFO!" "Serial number is blank."
    call :ShowFailure "Serial number is blank."
    exit /b 1
)

if not defined MANUFACTURER (
    call :LogException "CAPTURE_VALIDATION_FAILED" "!SERIAL_NUMBER!" "" "!DEVICE_INFO!" "Manufacturer is blank."
    call :ShowFailure "Manufacturer is blank."
    exit /b 1
)

if not defined DEVICE_INFO (
    call :LogException "CAPTURE_VALIDATION_FAILED" "!SERIAL_NUMBER!" "!MANUFACTURER!" "" "Device info is blank."
    call :ShowFailure "Device info is blank."
    exit /b 1
)

findstr /i /c:"!SERIAL_NUMBER!" "%CAPTURE_CSV%" >nul 2>nul
if not errorlevel 1 (
    call :LogException "DUPLICATE_SERIAL" "!SERIAL_NUMBER!" "!MANUFACTURER!" "!DEVICE_INFO!" "Duplicate serial detected before append."
    color 0E
    call :ShowHeader "DUPLICATE SERIAL" "This serial number already exists in the current capture output."
    call :ShowData "!SERIAL_NUMBER!" "!MANUFACTURER!" "!DEVICE_INFO!" "%CAPTURE_CSV%"
    echo.
    echo Review before proceeding. No duplicate row was added.
    call :HoldScreen
    exit /b 2
)

>> "%CAPTURE_CSV%" echo "!SERIAL_NUMBER!","!MANUFACTURER!","!DEVICE_INFO!"

color 0A
call :ShowHeader "SUCCESS" "ORIGIN INFO GATHERED"
echo Device identity captured and saved successfully.
echo.
call :ShowData "!SERIAL_NUMBER!" "!MANUFACTURER!" "!DEVICE_INFO!" "%CAPTURE_CSV%"
echo It is safe to power off this device or move to the next unit.
call :HoldScreen
exit /b 0

:GetWmicListValue
set "WMIC_ARGS=%~1"
set "WMIC_KEY=%~2"
set "WMIC_TARGET=%~3"
set "%WMIC_TARGET%="
for /f "tokens=1,* delims==" %%A in ('wmic %WMIC_ARGS% 2^>nul ^| findstr /i /b "%WMIC_KEY%="') do (
    set "WMIC_VALUE=%%B"
    call :CleanValue WMIC_VALUE
    if defined WMIC_VALUE set "%WMIC_TARGET%=!WMIC_VALUE!"
)
exit /b 0

:GetWmicTableValue
set "WMIC_ARGS=%~1"
set "WMIC_HEADER=%~2"
set "WMIC_TARGET=%~3"
set "%WMIC_TARGET%="
for /f "tokens=* delims=" %%A in ('wmic %WMIC_ARGS% 2^>nul ^| findstr /r /v "^$" ^| findstr /v /i "%WMIC_HEADER%"') do (
    set "WMIC_VALUE=%%A"
    call :CleanValue WMIC_VALUE
    if defined WMIC_VALUE (
        set "%WMIC_TARGET%=!WMIC_VALUE!"
        exit /b 0
    )
)
exit /b 0

:CleanValue
set "CLEAN_NAME=%~1"
for /f "tokens=* delims= " %%T in ("!%CLEAN_NAME%!") do set "%CLEAN_NAME%=%%T"
:CleanTail
if not defined %CLEAN_NAME% exit /b 0
if "!%CLEAN_NAME%:~-1!"==" " (
    set "%CLEAN_NAME%=!%CLEAN_NAME%:~0,-1!"
    goto :CleanTail
)
exit /b 0

:WriteWmicDebug
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
    echo COMMAND: wmic csproduct get identifyingnumber /value
    wmic csproduct get identifyingnumber /value
    echo.
    echo COMMAND: wmic computersystem get manufacturer
    wmic computersystem get manufacturer
    echo.
    echo COMMAND: wmic computersystem get manufacturer /value
    wmic computersystem get manufacturer /value
    echo.
    echo COMMAND: wmic computersystem get model
    wmic computersystem get model
    echo.
    echo COMMAND: wmic computersystem get model /value
    wmic computersystem get model /value
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
color 0C
call :ShowHeader "FAILED CAPTURE" "CAPTURE FAILED"
echo %~1
echo Exception log was saved if the USB was writable.
echo WMIC debug saved to: %DEBUG_PATH%
call :HoldScreen
exit /b 0

:ShowHeader
cls
echo.
echo  ================================================================================================
echo   ORIGIN CAPTURE LITE
echo   Device Identity ^& Serialization Capture
echo  ================================================================================================
echo.
echo   STATE: %~1
echo.
echo   %~2
echo.
echo  ------------------------------------------------------------------------------------------------
echo.
echo   Designed and developed by Jordan Brown ^| LDG Systems
echo.
exit /b 0

:ShowData
echo   Serial Number : %~1
echo   Manufacturer  : %~2
echo   Model         : %~3
echo   CSV Path      : %~4
echo   Timestamp     : %DATE% %TIME%
echo.
echo  ------------------------------------------------------------------------------------------------
echo.
exit /b 0

:HoldScreen
cmd /k
exit /b 0
