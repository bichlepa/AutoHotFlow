# Simple loop

The loop **Simple loop** repeats the elements that follow it in the flow a given number of times. The elements connected to the loop's **head** are repeated; the connection to **tail** continues after the loop.

## Settings

### Repeats

The number of repetitions, as an expression (see [Variables and expressions](../../../../../../assets/help/en/Variables.md)). A number that is 0 or less means no repetition.

If **Endless loop** is checked, the loop never ends by itself. It can still be left through a connection that leads to **break** (the loop's second exit).

## Supplied Variables

### `A_Index`

The index of the current repetition. It starts with 1 and increases with every repetition. It is removed after the last repetition.
