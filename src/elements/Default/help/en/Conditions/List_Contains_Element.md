# List contains element

The condition **List contains element** checks whether a list has an element. It decides between **Yes** and **No**.

## Settings

### Input list

The list to check: the name of a variable that holds the list, or an expression that gives a list.

### Search for what

- **Search for a position or key**: the condition checks whether the list has an element with the key given below.
- **Search for an element with a specified content**: the condition checks whether an element has the value given below. If several elements have it, the first one counts.

### Key or position

Only used with **Search for a position or key**: the key (or the integer position) to look for.

### Seeked content

Only used with **Search for an element with a specified content**: the value to look for.

## Supplied Variables

### `A_FoundKey`

Only set with **Search for an element with a specified content**, when the condition is **Yes**: the key of the element that has the content (the first one, if there are several).
