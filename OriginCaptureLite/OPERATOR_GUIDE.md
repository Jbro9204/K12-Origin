# Operator Guide

## Daily Workflow

1. Insert the Origin Capture Lite USB.
2. Power off the Surface.
3. Hold Volume Down.
4. Press and release Power.
5. Keep holding Volume Down until the Surface logo or spinning dots appear.
6. Wait for Origin Capture Lite to launch.
7. Do not type anything.
8. Wait for capture to complete.
9. Confirm the screen shows `ORIGIN INFO GATHERED`.
10. Move the device to Captured - Pending MDM Release.
11. Repeat with the next device.

## Capture Screen

The tool displays:

```text
ORIGIN CAPTURE LITE
Surface / Windows Device Release Capture
No internal drive boot required
No wipe, no bypass, capture only
```

## Captured Fields

Auditors do not enter anything at the device. The output CSV contains only serial number, manufacturer, and device info.

Each completed device is saved as its own row in `surface_release_capture.csv`.

## Successful Capture

The screen shows:

```text
ORIGIN INFO GATHERED
Capture log saved.
Serial: [SERIAL_NUMBER]
Manufacturer: [MANUFACTURER]
Device Info: [DEVICE_INFO]
```

The default action is to leave the success message on screen so the auditor can confirm the CSV was saved.

## Duplicate Serial

If `DUPLICATE SERIAL DETECTED` appears, do not append another row unless a supervisor confirms that the duplicate is expected.

## Failed Capture

If capture fails, choose the retry option once. If it fails again, move the unit to exception review and notify a lead.
