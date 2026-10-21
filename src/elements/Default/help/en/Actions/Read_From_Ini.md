# Read from ini

The action **Read from ini** reads a value from a standard format .ini file.

## Settings

### Output variable name

Name of the variable which will contain the result.

### Path of .ini file

Path of the file.

The file path is assumed to be in the working directory if an absolute path isn't specified.

### Action

If **Read a key** is checked, only one key will be read and its value will be stored to the output variable.

If **Read the entire section** is checked, the entire section will be stored to the output variable. Comments and empty lines are omitted. Only the first 65,533 characters of the section are retrieved.

If **Read the section names** is checked, a list of all section names will be stored to the output variable.

### Section *and* Key

The section and the key that contain the value.

One or both of the options may be disabled, depending on the choice in Action.

### Behavior on error

This option is only available if **Read a key** is checked. If the file, section or key won't be found, the action could throw an exception or write a default value in the variable.

## Remarks

A standard ini file looks like this:

```
[SectionName]
Key=Value
```
