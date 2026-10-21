# Variable content is

The condition **Variable content is** checks whether a variable contains a value of a certain type.

## Settings

### Variable name or expression

Enter either a variable name or an expression.

### Expected content type

The expected type.

**List** (may also be called **Object**): True if value is a list, which may be empty. A list may contain an array or some key-value pairs.

**Time**: True if value contains a valid date-time stamp, which can be all or just the leading part of the `YYYYMMDDHH24MISS` format. For example, a 4-digit string such as `2004` is considered valid. Years less than `1601` are not considered valid because the operating system generally does not support them. The maximum year considered valid is `9999`. Example: `20201231235959`

**Number**: True if value is either an **Integer** or a **Floating point number**

**Integer**: True if value is non-empty and contains a purely numeric string (decimal or hexadecimal) without a decimal point. Leading and trailing spaces and tabs are allowed. The string may start with a plus or minus sign.

**Floating point number**: True if value is non-empty and contains a floating point number; that is, a purely numeric string containing a decimal point. Leading and trailing spaces and tabs are allowed. The string may start with a plus sign, minus sign, or decimal point.

**Decimal digits**: True if value is empty or contains only digits, which consist of the characters 0 through 9. Other characters such as the following are not allowed: spaces, tabs, plus signs, minus signs, decimal points, hexadecimal digits, and the 0x prefix.

**Hexadecimal digits**: Same as **Decimal digits** except the characters A through F (uppercase or lowercase) are also allowed. A prefix of 0x is tolerated if present.

**Alphanumeric string**: Same as **Alphabetic string** except that characters 0 through 9 are also allowed.

**Alphabetic string**: True if value is empty or contains only alphabetic characters. False if there are any digits, spaces, tabs, punctuation, or other non-alphabetic characters anywhere in the string. For example, if value contains a space followed by a letter, it is not considered to be an alphabetic string.

**String with only uppercase characters**: True if value is empty or contains only uppercase characters. False if there are any digits, spaces, tabs, punctuation, or other non-uppercase characters anywhere in the string.

**String with only lowercase characters**: True if value is empty or contains only lowercase characters. False if there are any digits, spaces, tabs, punctuation, or other non-lowercase characters anywhere in the string.

**Whitespaces**: True if value is empty or contains only whitespace, which consists of the following characters: space (`%A_Space%`), tab (`%A_Tab%`), linefeed (`%A_Linefeed%`), return (`%A_CarriageReturn%`), vertical tab (`%A_VerticalTab%`), and formfeed (`%A_Formfeed%`).
