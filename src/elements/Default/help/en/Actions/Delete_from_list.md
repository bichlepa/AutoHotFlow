# Delete from list

The action **Delete from list** deletes one element from a list.

## Settings

### Variable name

The name of the variable that holds the list.

### Which element

- **First integer position**: the element with the lowest integer key is deleted.
- **Last integer position**: the element with the highest integer key is deleted.
- **Following position or key**: the element with the given key is deleted. A key that is not an integer is simply removed; nothing else moves.

### Delete method

Only for an integer position:

- **Delete and decrement all higher positions**: the elements at higher positions move down, so that the keys stay without a gap.
- **Delete and keep the gap**: the other keys stay as they are.

### Write deleted value to variable

If checked, the value that was deleted is written into the variable named below.
