@echo off
wpeinit

echo.
echo Locating Origin Capture Lite USB folder...

for %%D in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if exist "%%D:\OriginCapture\Capture-OriginLite.cmd" (
        echo Found Origin Capture Lite on %%D:
        cd /d "%%D:\OriginCapture"
        call "%%D:\OriginCapture\Capture-OriginLite.cmd"
        exit /b %ERRORLEVEL%
    )
)

echo.
echo ERROR: OriginCapture folder was not found on any mounted drive.
echo Expected: USB_ROOT\OriginCapture\Capture-OriginLite.cmd
echo.
echo A command prompt is open for troubleshooting.
cmd

