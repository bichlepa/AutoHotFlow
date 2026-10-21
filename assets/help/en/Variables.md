# Variables and expressions

Many elements take a value from a **variable** or from an **expression**: a number, a text or a list that is worked out when the element runs. This page explains the names of variables, the built-in variables and the expression language of AutoHotFlow. Since version 2 the expression language follows AutoHotkey v2; flows made with AutoHotkey v1 are converted when they are loaded (see the end of this page).

## Variables

### Names

A variable name starts with a letter or an underscore and continues with letters, digits and underscores. Names are not case sensitive: `Count`, `count` and `COUNT` are the same variable.

A variable that has never been given a value is **empty**: reading it gives an empty text.

### Kinds of variables

The first letters of a name decide where the variable lives:

| Name | Example | Lives |
|---|---|---|
| no prefix | `count`, `customer` | as long as one run of the flow (instance). All threads of the run see it. |
| `global_` | `global_total` | always. It is kept when the flow stops and when AutoHotFlow restarts. |
| `static_` | `static_last` | always, but only for this flow. |
| `A_` | `A_Index`, `A_Now` | built-in variables (see below) and the variables that the elements of a loop or a trigger set for the run. |

Built-in variables cannot be set. A few `A_` variables are set during a run by the elements that need them (see below). The element **New variable** refuses a name that starts with `A_` and ends with an exception.

### Built-in variables

Some examples. The names are those of AutoHotkey v2.

| Variable | Contains |
|---|---|
| `A_Index` | the index of the current repetition of a loop (starts with 1) |
| `A_LoopField`, `A_LoopKey` | the current field or element and its key, in the loops that go through a text or a list |
| `A_Now` | the current date and time, as `YYYYMMDDHH24MISS` text |
| `A_TickCount` | milliseconds since the start of Windows |
| `A_UserName`, `A_ComputerName` | the name of the user and of the computer |
| `A_Desktop`, `A_MyDocuments` | the folders of the desktop and of the documents |
| `A_WorkingDir` | the working directory of the flow |
| `A_LF`, `A_CR`, `A_Tab`, `A_Space` | line feed, carriage return, tab and space, as text (useful in expressions and in text fields) |
| `A_AhfVersion` | the version of AutoHotFlow |

Variables that elements set during a run: `A_UserAction` (the message box and the confirmation dialog), `A_FoundKey` (the condition **List contains element**), `A_ManualTriggerID` (a manual trigger), `A_TriggerTime` and `A_TriggerID` (a trigger that starts the run). The help page of each element says which variables it sets.

### Values

A variable holds a **text**, a **number** or a **list**. A number is a whole number (for example `42`) or a number with a decimal point (for example `0.75`). A number keeps its type when it is stored and read again.

A **list** is a variable with keys: the elements of a list have the keys `1`, `2`, `3` and so on, and may also have text keys. Use the elements **New list**, **Add to list** and **Get list info** to work with lists, and the loop **Work through a list** to go through them.

## Expressions

An expression computes a value from numbers, texts, variables and functions. Examples:

- `count + 1`
- `price * count`
- `round(price * count, 2)`
- `name = "Paul"`
- `count >= 10 and name = "Paul"`

### Numbers

- Whole numbers: `42`, `0`, `-5` (the minus is an operator, not part of the number).
- Numbers with a decimal point: `3.14`, `.5`.
- Hexadecimal numbers: `0x1F`.
- The result of a division keeps the exact form: `/` gives a whole number when the division is exact (`4 / 2` is `2`), otherwise a number with a decimal point (`7 / 2` is `3.5`). `//` always gives the whole part (`7 // 2` is `3`).
- A number is written in its short form: `0.75`, not `0.750000`.

### Texts

A text is written in double quotes: `"Hello"`. Single quotes also work: `'Hello'`.

Some characters need an escape with the backtick (the key above the Tab key): `` `n `` is a line break, `` `t `` a tab, and `` `" `` a double quote inside a text. The percent sign is an ordinary character in a text: `"50%"` is the text `50%`.

To join texts, write ` . ` with a space on both sides: `"Total: " . sum`. Two operands that stand side by side are joined too (`"Total: " sum`), but the dot makes the intention clear.

### Operators

From the strongest to the weakest binding:

| Operators | Meaning |
|---|---|
| `( )`, `f(x)`, `list[1]`, `list.1` | brackets, function call, element of a list |
| `-x`, `!x` | negation |
| `*`, `/`, `//` | multiplication, division, whole-number division |
| `+`, `-` | addition, subtraction |
| concatenation: ` . ` or two operands side by side | joins texts; binds weaker than `+` |
| `<`, `>`, `<=`, `>=` | comparison of numbers |
| `=`, `!=` | equal, not equal (texts are compared without case) |
| `==`, `!==` | equal, not equal (texts are compared with case) |
| `not x` | negation, weaker than the comparisons: `not a = b` is `not (a = b)` |
| `and`, `&&` | true if both sides are true |
| `or` (also written with two vertical bars) | true if one side is true |

`and` and `or` give one of their operands as the result, as in AutoHotkey v2. Parentheses change the order: `(a + b) * c`.

Two texts that look like numbers are compared as texts: `"1.0" = "1"` is false. A number compared with a text that looks like a number is compared as a number: `count = "5"` is true when `count` is 5.

### Functions

| Function | Result |
|---|---|
| `round(number)`, `round(number, digits)` | the number rounded; `round(2.567, 2)` is `2.57` |
| `mod(a, b)` | the remainder of `a` divided by `b`, with the sign of `a` |
| `object()` | a new empty list; `object("name", "Paul")` is a list with one text key |
| `print(value)` | writes the value to the log and returns an empty text |

Function names are not case sensitive.

### Lists

A list element is read as `list[1]` or `list.1`, and set in an expression as `list[1] := "x"`. The keys `"1"` and `1` are the same element. A missing element is empty.

## Text fields

A field that takes plain text (for example the message of the action **Message box**) replaces `%name%` by the value of the variable: `Hello %name%` shows the name.

In an expression, `%` does not replace text. It builds a variable name: `item%i%` is the variable whose name is `item` followed by the value of `i`. With `i` = 2 that is `item2`. A plain name in an expression is written without percent signs: `count + 1`.

## Flows from AutoHotkey v1

Expressions of flows that were made with AutoHotFlow 1 are converted when the flow is loaded. The conversion puts spaces around the dot that joins texts and rewrites the escapes of texts that the new language knows. Syntax that the new language does not have, for example `%` as the remainder (use `mod(a, b)`), stays as it was written. Such an element is marked and the log names the expression. Check it before you rely on its result.
