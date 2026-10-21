# Delete from ini

The action **Delete from ini** deletes a value from a standard format .ini file.

## Settings

### Path of an .ini file

Name and path of the file.

The file path is assumed to be in the working directory if an absolute path isn't specified.

### Action

If **Delete a key** is checked, only one key will be deleted.

If **Delete a section** is checked, the entire section with all its keys will be deleted.

### Section *and* Key

The section and the key which content will be deleted.

## Remarks

A standard ini file looks like this:

```
[SectionName]
Key=Value
```
