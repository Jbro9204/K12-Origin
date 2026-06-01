# Operator Guide

## Daily Workflow

1. Insert the Origin Capture Lite USB.
2. Power off the Surface.
3. Hold Volume Down.
4. Press and release Power.
5. Keep holding Volume Down until the Surface logo or spinning dots appear.
6. Wait for Origin Capture Lite to launch.
7. Enter PO number, lot number, pallet ID, station ID, and operator ID.
8. Wait for capture to complete.
9. Confirm the screen shows `CAPTURE COMPLETE`.
10. Let the device shut down.
11. Move the device to Captured - Pending MDM Release.
12. Repeat with the next device.

## Capture Screen

The tool displays:

```text
ORIGIN CAPTURE LITE
Surface / Windows Device Release Capture
No internal drive boot required
No wipe, no bypass, capture only
```

## Required Session Values

- PO Number
- Lot Number
- Pallet ID
- Station ID
- Operator ID

These values are reused for every capture during the same boot session.

## Successful Capture

The screen shows:

```text
CAPTURE COMPLETE
Serial: [SERIAL_NUMBER]
Manufacturer: [MANUFACTURER]
Model: [MODEL]
```

The default action is shutdown.

## Duplicate Serial

If `DUPLICATE SERIAL DETECTED` appears, do not append another row unless a supervisor confirms that the duplicate is expected.

## Failed Capture

If capture fails, choose the retry option once. If it fails again, move the unit to exception review and notify a lead.

