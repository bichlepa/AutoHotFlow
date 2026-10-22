# Eject drive

The action **Eject drive** ejects a drive, or retracts the tray of an optical drive.

## Settings

### Drive letter

A drive letter with its colon, for example `E:`. The letter alone (`E`) is accepted. An empty drive letter ends the element with an exception.

### Action

- **Eject drive**: the drive is ejected. For an optical drive the tray opens; for a removable drive the media is dismissed, as the Eject item of the Explorer does. Open files on the drive are not checked: the eject goes on even while a program uses the drive. **Warning: this may cause a loss of data.**
- **Retract the tray of a optical disc drive**: the tray of an optical drive closes.

### Method

The three methods of v1 are kept in the flow. All of them eject the drive with the same call of Windows (AutoHotkey `DriveEject`). The method 1 of v1 ("safely remove the removable drive", through a library that removes USB storage devices) is not available in AutoHotFlow 2, so a USB stick may not be removed as safely as with v1 (MIGRATION M-0145). The method has no effect on retracting the tray.

## Examples

Eject the optical drive `E:`.

| Parameter | Value |
| --- | --- |
| Drive letter | `E:` |
| Action | Eject drive |
