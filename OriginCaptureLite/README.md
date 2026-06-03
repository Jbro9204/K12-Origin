# Origin Capture Lite

Origin Capture Lite is a bootable Windows PE-based device identity capture system for high-volume ITAD production environments. It boots from USB, captures approved device identity fields, and writes clean CSV output for school/client MDM, Intune, Autopilot, Entra ID, and asset-release coordination workflows.

## Security And Compliance Scope

Origin Capture Lite does not bypass MDM, Autopilot, Intune, Entra ID, BIOS passwords, BitLocker, Secure Boot, or any security control.

Origin Capture Lite only captures device identity data for lawful ITAD release coordination on owned or authorized devices received through legitimate ITAD channels.

Origin Capture Lite does not wipe drives, access user data, boot into the internal Windows installation, or modify the internal drive.

## Required Captured Fields

The school/client-facing CSV includes:

```text
SERIAL_NUMBER,MANUFACTURER,MODEL,CAPTURE_TIME,STATION_ID,OPERATOR_ID,PO_NUMBER,LOT_NUMBER,PALLET_ID,STATUS
```

The default status is:

```text
PENDING MDM AUTOPILOT RELEASE
```

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
  Capture-OriginLite.ps1
  Startnet.cmd
  Validate-Capture.ps1
  Export-Summary.ps1
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
  Capture-OriginLite.ps1
  origin_config.json
  surface_release_capture.csv
  origin_capture_audit_log.csv
  logs/
    exceptions.csv
```

The CSV files are created automatically if they do not exist.

## Production Workflow

1. Build a Windows PE USB using the Microsoft ADK and Windows PE add-on.
2. Copy the Origin Capture Lite runtime files into `OriginCapture` on the USB.
3. Configure WinPE `Startnet.cmd` to locate and launch `OriginCapture\Capture-OriginLite.cmd`.
4. Boot the target Surface Go 2 from USB.
5. Origin Capture Lite automatically captures serial number, manufacturer, and model.
6. Confirm the screen shows `ORIGIN INFO GATHERED`.
7. Send `surface_release_capture.csv` to the school/client for release processing.

By default, the tool runs in unattended mode. Auditors do not type PO, lot, pallet, station, or operator values at the device. Those CSV fields are filled from `origin_config.json`.

## Data Capture

The production script prefers WMIC because it has been validated in the target Windows USB environment:

```cmd
wmic bios get serialnumber
wmic computersystem get manufacturer,model
wmic csproduct get uuid,identifyingnumber,name,vendor
```

PowerShell WMI/CIM is used as a fallback when available. No internet access, database, Python, Node, npm, or external package is required.
