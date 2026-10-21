# Delete from list

The action **Delete from list** deletes a value from an existing list.

## Settings

### Variable name

Name of the variable which contains the list.

### Which element

Either one or multiple elements can be added to the list.

If **First position** is selected, the first value (usually with the key 1) will be deleted.

If **Last position** is selected, the first value with the highest key will be deleted.

If **Following position or key** is selected, the specified key will be deleted. If you specify an integer position, you can decide whether higher positions should be decremented after the deletion (to maintain a gapless array).

### Deleted value

You may write the deleted value to a new variable.
