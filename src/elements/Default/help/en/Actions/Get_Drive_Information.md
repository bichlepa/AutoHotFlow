# Get drive information

The action **Get drive information** retrieves some information about the connected drives.

## Settings

### Output variable name

Name of the variable which will contain the value.

### Which information

Select an information type which you want to retrieve. There are following options:

### Label

Retrieves a drive's volume label

### Type

Retrieves the drive type, which is one of the following words:

- `Unknown`
- `Removable`
- `Fixed`
- `Network`
- `CDROM`
- `RAMDisk`

### Status

Retrieves the drive status, which is one of the following words:

- `Unknown` (might indicate unformatted/RAW)
- `Ready`
- `NotReady` (typical for removable drives that don't contain media)
- `Invalid` (Path does not exist or is a network drive that is presently inaccessible, etc.)

### Status of optical disc drive

Retrieves the media status of an optical drive. Output variable is made blank if the status cannot be determined. Otherwise, it will contain one of the following words:

- `not ready` - The drive is not ready to be accessed, perhaps due to being engaged in a write operation. Known limitation: "not ready" also occurs when the drive contains a DVD rather than a CD.
- `open` - The drive contains no disc, or the tray is ejected.
- `playing` - The drive is playing a disc.
- `paused` - The previously playing audio or video is now paused.
- `seeking` - The drive is seeking.
- `stopped` - The drive contains a CD but is not currently accessing it.

### Capacity

Retrieves the total capacity of a path or drive, in Megabytes.

### Free disk space

Retrieves the free disk space of a path or drive, in Megabytes.

### File system

Retrieves the type of drive's file system, which is one of the following words:

- `FAT`
- `FAT32`
- `NTFS`
- `CDFS` (typically indicates a CD)
- `UDF` (typically indicates a DVD)

### Serial number

Retrieves drive's volume serial number expressed as decimal integer.

### Drive letter or UNC name

Specify a drive letter, followed by a colon and an optional backslash. In some cases a UNC name (such as `\\server1\share1`) might work.

### Path

Name of the directory or a drive letter, followed by a colon and an optional backslash.

Since NTFS supports mounted volumes and directory junctions, different values might result in different folders of the same "drive" in some cases.
