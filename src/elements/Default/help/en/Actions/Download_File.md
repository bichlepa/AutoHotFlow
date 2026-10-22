# Download file

The action **Download file** downloads the file of an URL and writes it to a file.

## Settings

### URL

The URL of the file to download, for example `http://someorg.org/file.zip`. The download uses the proxy of the Internet settings of the user.

### File path

The name and the path of the file that the download writes. A relative path is taken from the working directory of the flow. An existing file of that name is replaced. The folder must exist, and the path must not be a folder or the root of a drive.

## Remarks

The download waits for the server. A download that takes longer than 10 minutes ends with the exception "worker timeout" (MIGRATION M-0141); the part that was written stays in the file. An error page of the server is saved as well: the element does not check the status of the answer, as in v1.

## Examples

Download a file to the desktop.

| Parameter | Value |
| --- | --- |
| URL | `http://www.example.com/index.html` |
| File path | `%A_Desktop%\index.html` |
