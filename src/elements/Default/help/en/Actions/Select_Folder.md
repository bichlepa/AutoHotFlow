# Select folder

The action **Select folder** shows the standard folder dialog. The user chooses a folder, and its path goes into the output variable.

## Settings

### Output variable name

The name of the variable that receives the full path of the chosen folder.

### Prompt

The text the dialog shows to tell the user what to choose.

### Root directory

The folder that is preselected when the dialog appears. A relative path is taken from the working directory of AutoHotFlow.

### Options

- **Permit to navigate upward**: the user may go up from the root folder to its parent folders. When it is not checked, the user can only choose the root folder or a folder inside it.
- **Show a button to create a new folder**: the dialog has a button that creates a folder.
- **Show an edit field to type in the folder name**: the dialog has an edit field in which the user can type a folder name.

## Results

- The user chooses a folder: the output variable holds its path, and the action ends normally.
- The user cancels the dialog: the action ends with the exception "User dismissed the dialog without selecting a folder or system refused to show the dialog."

The output variable is not changed in that case.
