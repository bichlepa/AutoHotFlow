# Get drive information

The action **Get drive information** stores one piece of information about a drive or a folder in a variable.

## Settings

### Output variable name

The name of the variable that receives the value.

### Which information

Select the information that you want. The choices are described below. Each choice needs either a drive letter or a folder.

### Label

The volume label of a drive. Needs a drive letter. Empty when the drive has no label.

### Type

The type of the drive that contains the folder: `Unknown`, `Removable`, `Fixed`, `Network`, `CDROM` or `RAMDisk`. Needs a folder.

### Status

The status of the drive: `Unknown` (for example unformatted), `Ready`, `NotReady` (typical for a removable drive without media) or `Invalid`. Needs a drive letter (MIGRATION M-0144).

### Status of optical disc drive

The media status of an optical drive: `not ready`, `open`, `playing`, `paused`, `seeking` or `stopped`. Empty when the status cannot be read. Needs a drive letter.

### Capacity

The total capacity of the drive that contains the folder, in megabytes. Needs a folder.

### Free disk space

The free space of the drive that contains the folder, in megabytes. Needs a folder.

### File system

The file system of the drive, for example `FAT32`, `NTFS`, `CDFS` or `UDF`. Needs a drive letter.

### Serial number

The volume serial number as a decimal number. Needs a drive letter.

### Drive letter

A drive letter with its colon, for example `C:`. The letter alone (`C`) is accepted. An empty drive letter ends the element with an exception.

### Path

A folder, or a drive letter with its colon. The folder must exist. For Type, Capacity and Free disk space, the drive that contains the folder is used.

## Examples

Get the free space of the drive of the documents folder in megabytes.

| Parameter | Value |
| --- | --- |
| Output variable name | FreeMB |
| Which information | Free disk space |
| Path | `%A_MyDocuments%` |
