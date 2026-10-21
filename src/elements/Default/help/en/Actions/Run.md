# Run

The action **Run** runs an external program.

## Settings

### Command

The name of a single file, document, URL that will be opened.

If an absolute path isn't specified, the file path is assumed to be in the working directory.

### Working directory

The working directory of the executed application.

If an absolute path isn't specified, the file path is assumed to be in the working directory.

In many cases this parameter does not make a difference.

### Run mode

Some applications can be started in a specific mode. This can be selected here.

## Supplied Variables

### `A_PID`

Process ID of the launched process.

## Examples

Run Notepad.

| Parameter | Value |
| --- | --- |
| Command | `notepad` |

Run VLC media player.

| Parameter | Value |
| --- | --- |
| Command | `C:\Program Files\VideoLAN\VLC\vlc.exe (The VLC Media player may be installed in an other location)` |

Open a document.

| Parameter | Value |
| --- | --- |
| Command | `%A_MyDocuments%\exampleDocument.odt` |

Open a website.

| Parameter | Value |
| --- | --- |
| Command | `http://www.autohotkey.com` |
