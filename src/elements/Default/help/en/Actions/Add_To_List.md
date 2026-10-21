# Add to list

The action **Add to list** adds one or more values to a list. If the variable does not exist yet, it is created as a list.

## Settings

### Variable name

The name of the variable that holds the list.

### Number of elements

- **Add one element**: one value is added. Its value is the text or the expression of **Content to add**.
- **Add multiple elements**: the values are the lines (or the parts) of the multiline field, see **Content to add**.

### Content to add

For one element, a text or an expression (choose next to the field, see [Variables and expressions](../../../../../../assets/help/en/Variables.md)).

For several elements, the text is split at the delimiters that are checked below the field: **Use linefeed as delimiter** (one value per line, the default), **Use comma as delimiter**, **Use semicolon as delimiter** and **Use space as delimiter**. With no delimiter checked, the whole text is one value.

### Key

- **First integer position**: the values are added at the start, with the keys 1, 2, ... in the order given. The keys of the other elements move up by the number of values.
- **Last integer position**: the values are added at the end, after the highest integer key.
- **Following position or key**: the values are added at the given key. For an integer key, **Insert and increment all other positions** moves the elements at this and the higher positions up; **Overwrite value** replaces the element at the key. With several values, the second value goes to the next key, and so on.
