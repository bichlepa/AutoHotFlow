# Get list info

The action **Get list info** writes one piece of information about a list into a variable.

## Settings

### Output variable name

The name of the variable that receives the information.

### Input list

The name of the variable that holds the list (or an expression that gives a list).

### Which info

- **Minimum index**: the lowest integer key. Empty if the list has no integer key.
- **Maximum index**: the highest integer key. Empty if the list has no integer key.
- **Array length**: the highest integer key, or 0 if the list has none. For a list whose keys are 1, 2, 3, this is 3.
- **Element count**: the number of elements, whatever their keys.
