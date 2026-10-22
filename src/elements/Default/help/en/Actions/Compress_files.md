# Compress files

The action **Compress files** packs one file, or one folder with all its contents, into an archive.

## Settings

### Source file

The file or the folder to pack. A wildcard pattern such as `*.txt` is not allowed. A relative path is taken from the working directory of the flow.

### Destination archive

The path of the archive to write. An archive that already exists at this path is replaced. The folder that contains the archive must exist, and the path must not be a folder or the root of a drive.

### Format

- **zip**: a zip archive.
- **7z**: a 7z archive.
- **tar**: a tar archive without compression.
- **gzip**, **BZIP2**, **xz**: a tar archive compressed with gzip, bzip2 or xz (the usual `.tar.gz`, `.tar.bz2` or `.tar.xz`). A single file is packed as a tar archive too: the compression of one file alone without tar is not available in AutoHotFlow 2 (MIGRATION M-0141).

The archive is written by the `tar.exe` of Windows. Its entries keep the name of the source: packing the folder `Reports` gives the entries `Reports/...`.

## Errors

The element ends with an exception when the source does not exist, when the destination is a folder, when its folder does not exist, when it is the root of a drive, or when a path contains a percent sign, a quote or a line break (these cannot be passed to `tar.exe`). A failure of `tar.exe` ends the element with its message.

## Examples

Pack the folder of the documents into a zip file.

| Parameter | Value |
| --- | --- |
| Source file | `%A_MyDocuments%\Reports` |
| Destination archive | `%A_Desktop%\Reports.zip` |
| Format | zip |

Pack one file into a compressed tar archive.

| Parameter | Value |
| --- | --- |
| Source file | `C:\Logs\app.log` |
| Destination archive | `C:\Backup\app.log.tar.gz` |
| Format | gzip |
