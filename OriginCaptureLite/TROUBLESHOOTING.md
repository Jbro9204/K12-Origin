# Troubleshooting

## Surface Boots Internal Windows Instead Of USB

- Fully shut down the Surface.
- Insert the USB.
- Hold Volume Down.
- Press and release Power.
- Keep holding Volume Down until the Surface logo or spinning dots appear.
- Confirm the USB was created with `MakeWinPEMedia /UFD`.

## Surface Does Not See USB

- Try another USB port or adapter.
- Recreate the USB with `MakeWinPEMedia`.
- Confirm the USB is formatted by the WinPE build process.
- Test the USB on another Surface.

## CSV Not Saving

- Confirm the USB is writable.
- Confirm `OriginCapture` exists on the USB root.
- Confirm `logs` exists or can be created.
- Check whether the CSV is open in Excel on another computer.
- Review `logs\exceptions.csv`.

## Serial Number Blank

- Retry capture once.
- Open command prompt and run:

```cmd
wmic bios get serialnumber
```

- If still blank, move the device to exception review.

## Duplicate Serial Detected

- Do not append unless a supervisor confirms.
- Check whether the unit was already captured.
- Review `surface_release_capture.csv` and `logs\exceptions.csv`.

## Aiken Does Not Boot But Windows USB Does

This tool is intentionally built around Microsoft Windows PE because Surface Go 2 devices may boot Microsoft Windows installation media when other boot environments fail.

## WinPE Boots But Capture Script Does Not Start

- Confirm `Startnet.cmd` was copied to `Windows\System32` inside the mounted WinPE image.
- Confirm the image was unmounted with `/Commit`.
- For an already-created USB, run `scripts\Install-WinPE-Autostart.ps1 -UsbDrive E:` from an elevated PowerShell prompt, replacing `E:` with the USB drive letter.
- At the command prompt, run:

```cmd
dir C:\OriginCapture
dir D:\OriginCapture
dir E:\OriginCapture
```

Then run:

```cmd
E:\OriginCapture\Capture-OriginLite.cmd
```

Use the actual USB drive letter.

## Wrong USB Drive Letter

WinPE drive letters can change. `Startnet.cmd` scans common drive letters for `OriginCapture\Capture-OriginLite.cmd`.

## Operator Entered Wrong PO, Lot, Or Pallet

- Stop processing on that boot session.
- Correct the affected rows in `surface_release_capture.csv` only after supervisor approval.
- Record the correction in internal production notes.
- Restart capture so the correct values are used for new devices.

## Manually Run From Command Prompt

If the script did not auto-launch:

```cmd
X:
dir C:\OriginCapture
dir D:\OriginCapture
dir E:\OriginCapture
E:\OriginCapture\Capture-OriginLite.cmd
```

Replace `E:` with the correct USB drive letter.
