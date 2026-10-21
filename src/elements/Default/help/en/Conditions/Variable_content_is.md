# Variable content is

The condition **Variable content is** checks the kind of the content of a variable and decides between **Yes** and **No**.

## Settings

### Variable name or expression

The name of the variable to check. Next to the field, you can choose an **expression** instead: its result is checked. A variable that does not exist is checked as an empty text.

### Expected content type

The kind of content that the condition expects:

- **List**: the variable holds a list (an object, see [Variables and expressions](../../../../../../assets/help/en/Variables.md)).
- **Time**: a timestamp in the form `YYYYMMDDHH24MISS`, checked like the AutoHotkey function `IsTime`.
- **Number**, **Integer**, **Floating point number**: the text is a number of the given kind.
- **Decimal digits**, **Hexadecimal digits**: the text consists of these digits only.
- **Alphanumeric string**, **Alphabetic string**: letters, or letters and digits, only.
- **String with only uppercase characters**, **String with only lowercase characters**: only upper or only lower case letters.
- **Whitespaces**: only spaces, tabs and line breaks.

The check uses the text of the value: the number `0.5` is a floating point number.
