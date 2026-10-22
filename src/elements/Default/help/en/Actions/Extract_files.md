# Extract files

The action **Extract files** unpacks an archive into a folder.

The formats that the `tar.exe` of Windows reads are supported: zip, 7z, tar, and tar archives compressed with gzip (`.tar.gz`), bzip2 (`.tar.bz2`), xz (`.tar.xz`) or lzma (`.tar.lzma`). A single file compressed with gzip, bzip2, xz or lzma without tar is not an archive for this element (MIGRATION M-0136).

## Settings

### Source archive

The path of the archive file. A wildcard pattern is not allowed.

### Destination folder

The folder where the files of the archive are extracted. It must exist. The root of a drive is not allowed.

### Format

**\***: the format is found from the archive itself. This is the default. The other choices are kept so that flows of v1 load; they do not change the way the archive is read (MIGRATION M-0137).

## Safety

Before anything is written, every entry of the archive is checked. The whole archive is refused, and nothing is extracted, when an entry:

- has an absolute path or a drive letter (for example `C:\Windows\file.txt`),
- contains `..` to leave the destination folder (for example `..\file.txt`),
- is a link or a device.

Files with the same name in the destination folder are replaced by the files of the archive.

## Examples

Extract a zip file into a folder.

| Parameter | Value |
| --- | --- |
| Source archive | `%A_Desktop%\Reports.zip` |
| Destination folder | `%A_Desktop%\Reports` |
| Format | * |
