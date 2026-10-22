# Read from ini

The action **Read from ini** reads from an ini file (`[section]` and `key=value` lines) into a variable. It can read one key, a whole section or the names of all sections.

## Settings

### Output Variable name

The variable that gets the result.

### Path of .ini file

The ini file. The file must exist. A relative path is taken from the working directory of the flow.

### Action

- **Read a key**: the value of one key of a section, as text.
- **Read the entire section**: the keys and values of a section, as a map of key to value. The keys are not case sensitive.
- **Read the section names**: the names of all sections, as a list.

### Section and Key

The section and the key that the action reads. Both are required for a key; the section is required for a whole section. An empty name ends the element with an exception.

### Behavior on error

- **Insert default value in the variable**: a missing key gives the default value below.
- **Throw exception**: a missing key ends the element with an exception.

### Default value on failure

The text that is stored when the key is missing and the behavior is the default value. An empty text stores an empty text.

## Behavior

- A section that does not exist gives an empty map when the whole section is read.
- The ini files of Windows can be UTF-16 (with a byte order mark, as written by the action Write to ini) or ANSI.

## Examples

Read the key `name` of the section `user`. If the key is missing, the variable gets `unknown`.

| Parameter | Value |
| --- | --- |
| Output Variable name | `name` |
| Path of .ini file | `%A_MyDocuments%\settings.ini` |
| Action | Read a key |
| Section | `user` |
| Key | `name` |
| Behavior on error | Insert default value in the variable |
| Default value on failure | `unknown` |
