# New list

The action **New list** creates a list in a variable. The list can be empty, or it can start with one or more elements.

## Settings

### Variable name

The name of the variable that receives the list. An existing variable with this name is replaced.

### Number of elements

- **Empty list**: the list has no elements.
- **Initialize with one element**: one element is added. Its value is the text or the expression of **Initial content**.
- **Initialize with multiple elements**: the elements are the lines (or the parts) of the multiline field, see **Initial content**.

### Initial content

For one element, a text or an expression (choose next to the field, see [Variables and expressions](../../../../../../assets/help/en/Variables.md)).

For several elements, the text is split at the delimiters that are checked below the field: **Use linefeed as delimiter** (one element per line, the default), **Use comma as delimiter**, **Use semicolon as delimiter** and **Use space as delimiter**. With no delimiter checked, the whole text is one element.

### Key

- **Numerically as first element**: the elements get the keys 1, 2, ... in the order given.
- **Following key**: the elements get the given key, and the following keys if there are several elements. A single element can get any key name.
