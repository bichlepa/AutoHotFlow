# Run

The action **Run** starts a program, opens a document or opens a web address with the program that Windows uses for it.

## Settings

### Command

The program, document or URL to start, for example `notepad`, `%A_MyDocuments%\exampleDocument.odt` or `https://www.autohotkey.com`. A relative path is taken from the working directory that you select below.

### Working directory

- **Working directory of the flow**: the working directory of the flow (see the flow settings).
- **Following working directory**: the folder that you select. It must exist, otherwise the action ends with an exception.

In many cases the working directory makes no difference.

### Run mode

- **Run normally**: the usual window.
- **Run maximized**: the window is opened maximized.
- **Run minimized**: the window is opened minimized.
- **Run hidden**: no window is shown. A program that has no hidden mode shows its window anyway.

If the command cannot be started, the action ends with an exception that names the command.

## Supplied variables

### `A_Pid`

The process ID of the started program. For a document or a web address that Windows opens in a program that is already running, no new process starts and the value is 0.

## Examples

Run Notepad.

| Parameter | Value |
| --- | --- |
| Command | `notepad` |

Open a document in the documents folder, maximized.

| Parameter | Value |
| --- | --- |
| Command | `%A_MyDocuments%\exampleDocument.odt` |
| Run mode | Run maximized |

Open a website.

| Parameter | Value |
| --- | --- |
| Command | `https://www.autohotkey.com` |
