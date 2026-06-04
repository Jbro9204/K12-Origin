# Build WinPE USB

This guide builds a Microsoft Windows PE USB for Origin Capture Lite.

## Requirements

- Windows technician workstation
- Microsoft Windows ADK
- Microsoft Windows PE add-on for the ADK
- USB drive, 8 GB or larger
- Administrator Command Prompt from Deployment and Imaging Tools Environment

Important: `MakeWinPEMedia /UFD` erases the target USB drive.

## 1. Install Microsoft ADK

Install the Windows ADK from Microsoft and include Deployment Tools.

## 2. Install Windows PE Add-On

Install the matching Windows PE add-on for the ADK.

## 3. Create WinPE Working Files

Open Deployment and Imaging Tools Environment as Administrator:

```cmd
copype amd64 C:\WinPE_OriginCapture
```

## 4. Mount boot.wim

```cmd
Dism /Mount-Image /ImageFile:"C:\WinPE_OriginCapture\media\sources\boot.wim" /index:1 /MountDir:"C:\WinPE_OriginCapture\mount"
```

## 5. Add Startup Script

Replace the WinPE startup script with the Origin Capture Lite startup script:

```cmd
copy /Y "C:\Path\To\K12-Origin\OriginCaptureLite\scripts\Startnet.cmd" "C:\WinPE_OriginCapture\mount\Windows\System32\Startnet.cmd"
```

## 6. Commit WinPE Image Changes

```cmd
Dism /Unmount-Image /MountDir:"C:\WinPE_OriginCapture\mount" /Commit
```

## 7. Create Bootable USB

Confirm the USB drive letter before running this command. The command below assumes `E:` is the USB drive.

```cmd
MakeWinPEMedia /UFD C:\WinPE_OriginCapture E:
```

Warning: this erases drive `E:`.

## 8. Add Origin Capture Lite Runtime Files

Create the runtime folder:

```cmd
mkdir E:\OriginCapture
mkdir E:\OriginCapture\logs
mkdir E:\OriginCapture\assets
```

Copy runtime files:

```cmd
copy /Y "C:\Path\To\K12-Origin\OriginCaptureLite\scripts\Capture-OriginLite.cmd" "E:\OriginCapture\Capture-OriginLite.cmd"
copy /Y "C:\Path\To\K12-Origin\OriginCaptureLite\scripts\Capture-OriginLite.hta" "E:\OriginCapture\Capture-OriginLite.hta"
copy /Y "C:\Path\To\K12-Origin\OriginCaptureLite\scripts\Capture-OriginLite.ps1" "E:\OriginCapture\Capture-OriginLite.ps1"
copy /Y "C:\Path\To\K12-Origin\OriginCaptureLite\scripts\Capture-OriginLite.vbs" "E:\OriginCapture\Capture-OriginLite.vbs"
copy /Y "C:\Path\To\K12-Origin\OriginCaptureLite\scripts\assets\New Origin Trans.png" "E:\OriginCapture\assets\New Origin Trans.png"
copy /Y "C:\Path\To\K12-Origin\OriginCaptureLite\config\origin_config.json" "E:\OriginCapture\origin_config.json"
```

The capture CSV files are created automatically on first run:

- `E:\OriginCapture\surface_release_capture.csv`
- `E:\OriginCapture\logs\exceptions.csv`

## Faster Option For An Existing WinPE USB

If the WinPE USB already exists, run this from an elevated PowerShell prompt. Replace `E:` with the USB drive letter:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
& "C:\Path\To\K12-Origin\OriginCaptureLite\scripts\Install-WinPE-Autostart.ps1" -UsbDrive E:
```

This does two things:

1. Copies the runtime files into `E:\OriginCapture`.
2. Mounts `E:\sources\boot.wim`, adds `WinPE-WMI`, `WinPE-Scripting`, and `WinPE-HTA` when available, installs `Startnet.cmd`, and commits the image so Origin Capture Lite launches automatically when WinPE boots.

`WinPE-WMI` and `WinPE-Scripting` are required because the capture runtime uses Windows Script Host plus WMI to pull serial number, manufacturer, and device info. A default WinPE image may not include PowerShell or WMIC.

`WinPE-HTA` enables the branded Origin kiosk-style interface with the transparent logo. If it is unavailable, the launcher falls back to the polished console interface without changing capture or CSV behavior.

## 9. Test On Surface Go 2

1. Power off the Surface Go 2.
2. Insert the Origin Capture Lite USB.
3. Hold Volume Down.
4. Press and release Power.
5. Keep holding Volume Down until the Surface logo or spinning dots appear.
6. Confirm Origin Capture Lite launches automatically.
7. Confirm no typing is required after the tool launches.
8. Confirm serial number, manufacturer, and device info are captured.
9. Confirm the screen shows `ORIGIN INFO GATHERED`.
10. Confirm CSV files are written under `OriginCapture` on the USB.

## 10. Confirm CSV Output

Open `surface_release_capture.csv` in Excel and confirm the columns are exactly:

```text
SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO
```

The file is ready to send to the school/client when all rows are reviewed.
