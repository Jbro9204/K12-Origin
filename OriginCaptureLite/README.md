# Origin Capture Lite

Origin Capture Lite is a bootable Windows PE-based device identity capture system for high-volume ITAD production environments. It boots from USB, captures only the required device identity fields, and writes clean CSV output.

## Security And Compliance Scope

Origin Capture Lite does not bypass MDM, Autopilot, Intune, Entra ID, BIOS passwords, BitLocker, Secure Boot, or any security control.

Origin Capture Lite only captures device identity data for lawful ITAD release coordination on owned or authorized devices received through legitimate ITAD channels.

Origin Capture Lite does not wipe drives, access user data, boot into the internal Windows installation, or modify the internal drive.

## Required Captured Fields

The output CSV includes only:

```text
SERIAL_NUMBER,MANUFACTURER,DEVICE_INFO
```

Each successful device capture appends one new row to `surface_release_capture.csv`.

## Project Layout

```text
OriginCaptureLite/
README.md
BUILD_WINPE_USB.md
DEPLOYMENT_GUIDE.md
OPERATOR_GUIDE.md
TROUBLESHOOTING.md
scripts/
  Capture-OriginLite.cmd
  Capture-OriginLite.hta
  Capture-OriginLite.ps1
  Capture-OriginLite.vbs
  Startnet.cmd
  Validate-Capture.ps1
  Export-Summary.ps1
  assets/
    New Origin Trans.png
config/
  origin_config.json
output/
  placeholder.txt
logs/
  placeholder.txt
```

## Runtime USB Layout

Copy the runtime files to a USB folder named `OriginCapture`:

```text
USB_ROOT/
  OriginCapture/
  Capture-OriginLite.cmd
  Capture-OriginLite.hta
  Capture-OriginLite.ps1
  Capture-OriginLite.vbs
  origin_config.json
  assets/
    New Origin Trans.png
  surface_release_capture.csv
  logs/
    exceptions.csv
```

The CSV files are created automatically if they do not exist.

## Production Workflow

1. Build a Windows PE USB using the Microsoft ADK and Windows PE add-on.
2. Copy the Origin Capture Lite runtime files into `OriginCapture` on the USB.
3. Configure WinPE `Startnet.cmd` to locate and launch `OriginCapture\Capture-OriginLite.cmd`.
4. Boot the target Surface Go 2 from USB.
5. Origin Capture Lite automatically captures serial number, manufacturer, and device info.
6. Confirm the screen shows `ORIGIN INFO GATHERED`.
7. Send `surface_release_capture.csv` to the school/client for release processing.

By default, the tool runs in unattended mode. Auditors do not type PO, lot, pallet, station, or operator values at the device. Those CSV fields are filled from `origin_config.json`.

## Data Capture

The production script prefers WMIC because it has been validated in the target Windows USB environment:

```cmd
wmic bios get serialnumber
wmic computersystem get manufacturer,model
```

The launcher prefers the branded HTA interface when WinPE includes HTA support, then falls back to the Windows Script Host console interface, then to native CMD plus WMIC capture. No internet access, database, Python, Node, npm, or external package is required. The model is saved as `DEVICE_INFO`.
