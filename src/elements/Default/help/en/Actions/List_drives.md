# List drives

The action **List drives** stores the letters of the drives of the computer in a list variable. Each member of the list is one drive letter, without colon, for example `C`.

## Settings

### Output variable name

The name of the list variable that receives the drives.

### Drive type

- **Find all drives**: every drive of the computer is listed.
- **Get only a specified type of drive**: only the drives of the chosen type are listed: optical disk drives, removable drives, fixed drives, network drives, RAM disk drives or unknown drives.

### If no drive can be found

- **Normal - Make output variable empty**: the element ends normal with the text "No drives found" and the variable is not written.
- **Throw exception**: the element ends with the exception "No drives found".
