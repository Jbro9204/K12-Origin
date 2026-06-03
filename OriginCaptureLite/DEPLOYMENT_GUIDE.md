# Deployment Guide

## Purpose

Deploy Origin Capture Lite as a Windows PE USB workflow for lawful identity capture on authorized Surface Go 2 and similar Windows devices.

## Deployment Model

Origin Capture Lite runs entirely from USB in Windows PE. It does not rely on internet access, does not boot the internal drive, and does not write to the internal drive.

## Runtime Folder

The USB must contain:

```text
OriginCapture/
  Capture-OriginLite.cmd
  Capture-OriginLite.ps1
  origin_config.json
  logs/
```

CSV outputs are created in the same folder.

## Station Setup

Each station should have:

- One known-good Origin Capture Lite USB
- A printed operator quick guide
- A visible station ID
- A defined location for Captured - Pending MDM Release devices
- A daily process for copying CSV files to secure storage

## Production Controls

- Use a unique `STATION_ID` per workstation.
- For unattended capture, set `defaultStationId`, `defaultOperatorId`, `defaultPoNumber`, `defaultLotNumber`, and `defaultPalletId` in `origin_config.json` before making each USB.
- Review `logs\exceptions.csv` daily.
- Preserve `origin_capture_audit_log.csv` for internal traceability.
- Send only `surface_release_capture.csv` to the school/client unless otherwise requested.

## Data Handling

The school-facing CSV contains only the required release fields. The audit log contains extended hardware identity details for internal review.

## Versioning

The script version is stored in `origin_config.json` and written into `origin_capture_audit_log.csv`.

## Updating USBs

1. Replace `Capture-OriginLite.cmd`.
2. Replace `Capture-OriginLite.ps1`.
3. Replace `origin_config.json` if configuration changed.
4. Keep existing CSV files only when intentionally continuing the same production batch.
5. Run `Validate-Capture.ps1` from the USB runtime folder when PowerShell is available.
