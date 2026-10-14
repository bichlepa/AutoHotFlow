# Expression language of AutoHotFlow v2

Specification of the language that parameters and scripts are written in, and of the library `src/expr/` that reads it.

Status: complete for step S1 (WI-43 checked the document against the code). Tokenizer, parser, evaluator and converter are implemented and tested (`tests/ahk/expr_*.test.ahk`). Section 17 describes the evaluator; section 14 lists the differences from AutoHotkey v2; section 15 is the deviation catalog and the converter of old expressions (WI-39). The variables (scopes, objects, built-in variables, `%var%` substitution) are not part of this library: they belong to the engine (`src/engine/vars/`, WI-40) and are described in section 18. The use in the parameters of elements (content types, the flow option `strictTypes`) is described in doc/ELEMENT-API-V2.md section 3.1 (WI-42).

The language follows AutoHotkey v2 (decision E22) as far as that makes sense in AutoHotFlow. Where it deviates, section 14 says so.

## 1. Overview

Two forms, same syntax and same parser:

| Form | Input | Use | Result of the parser |
|---|---|---|---|
| **expression** | one expression | a parameter whose content type is `Expression` | one expression node (`Empty` for an empty text) |
| **script** | several lines | `Action_Script` and similar (v1: `var_evaluateScript`) | a `Script` node with a list of statements |

```
res := Expr.ParseExpression(text)       ; or Expr.ParseScript(text)
if (res["ok"])  ... res["ast"] ...      ; syntax tree, section 9
else            msg := Expr.FormatErrors(res)   ; errors with line, column and the marked line, section 10
```

The parser knows nothing about variables or functions: whether `foo(1)` names a function that exists, or what a variable contains, is decided at evaluation.

## 2. Lexical elements

- **Whitespace:** space, tab, carriage return, vertical tab, form feed. Line breaks are whitespace in the expression form and separate statements in the script form (section 8).
- **Comments:** `;` up to the end of the line. A `;` must have whitespace (or the start of the line) in front of it, as in AutoHotkey; `x;y` is an error. A `;` inside a string is text. No block comments `/* */` (section 13).
- **Numbers:** `42`, `007` (the value is 7; the spelling is kept in the node), `0x1F` (hexadecimal, at most 63 bits), `3.14`, `.5`, `1e3`, `1.5E-3`. A number without point and exponent is an Integer, any other a Float. A decimal integer literal that does not fit into 63 bits becomes a Float. Not valid: `5.` (a dot needs digits behind it), `1_000`, `1,000`, `1.2.3`, `12abc`, `0x` (all errors). There is no sign in a literal: `-5` is the unary minus applied to `5`.
- **Strings:** `"..."` or `'...'`, no line break inside. The escape character is the backtick:

  | Escape | Meaning |
  |---|---|
  | `` `n `` `` `r `` `` `t `` | line feed, carriage return, tab |
  | `` `b `` `` `v `` `` `a `` `` `f `` | backspace, vertical tab, bell, form feed |
  | `` `" `` `` `' `` ` `` `` | a quote, an apostrophe, a backtick |
  | `` `; `` `` `% `` `` `, `` `` `: `` `` `{ `` `` `} `` | that character |

  Any other escape (`` `x ``, `` `1 ``, `` `N `` - the letters are case sensitive) is an error. Two strings that touch (`"a""b"`) are an error with a hint: v1 wrote a quote inside a string as `""`; here it is `` `" ``. With a space between them they are concatenated. Percent signs in strings are text (`"50%"`, `"%x%"`); there is no `%var%` substitution inside strings.
- **Keywords** (ignore case): `and`, `or`, `not`, `if`, `else`, `true`, `false`. `true` and `false` are the numbers 1 and 0 (the node keeps the spelling). The others are operators or statement words and cannot be variable names. A word that only starts like a keyword (`andy`, `iffy`, `trueish`) is a name. After a dot a keyword is a plain name (`a.and`).

## 3. Names

A name consists of ASCII letters and digits, `_`, and any character above U+007F (umlauts, Cyrillic, emoji...). It must not start with a digit. Names ignore case (`ABC` = `abc`); the node keeps the spelling as written. Variable names are not limited to the names built into the language; where a variable lives is decided by its name (`A_`, `global_`, `static_`; section 18).

Rules for variable names in general (`ExprNames.Check`, the same answers as v1 `Var_CheckName(name, true)`): `"Empty"`, `"StartsWithNumber"`, `"ForbiddenCharacter"` or `"OK"`. In addition to the characters above, `#`, `@` and `$` are valid in a name (v1 accepted them), and a name has at most 253 characters. The expression language itself cannot write `#`, `@`, `$`; such variables can be reached through a dynamic name (section 4) or as parameter of type `VariableName`.

## 4. Paths and dynamic names

| Written | Meaning | Node |
|---|---|---|
| `a.b` | member `b` of `a` | `Index` with `dot = 1`, key `String "b"` |
| `a.1`, `list.0` | member with a number as key | `Index`, key `Number` |
| `a[expr]` | key computed from an expression | `Index` with `dot = 0` |
| `a.%k%` | key is the value of `k` | `Index`, key is the expression `k` |
| `a.x%i%` | key is `"x"` joined with the value of `i` | `Index`, key is a concatenation |
| `a%i%`, `%n%`, `ro%x%nd`, `a%i+1%b` | the **name** of a variable is assembled from text and values | `DynVar` |

A dot is the member operator only when it touches the value in front of it and a name (or `%`) behind it. A key of digits only is a `Number` if it has no leading zero (`a.007` has the key `"007"`). `%expr%` can contain any expression; the closing `%` ends it, so a `%` inside needs parentheses. Parts of a dynamic name must touch each other (`a %i%` is a concatenation of `a` and `%i%`). Digits directly behind `%` belong to the name (`a%i%1`).

Paths can be assigned to (`a.b := 5`, `a[i] := 9`, `a%i% := 5`) and called (`a.b(1)` is a method call, section 7).

## 5. Operators and precedence

From **low** to **high** binding (the order of AutoHotkey v2, verified against its documentation):

| Level | Operators | Associativity |
|---|---|---|
| 1 | `:=` `+=` `-=` `*=` `/=` `//=` `.=` | right; left side must be a variable or a path |
| 2 | `\|\|` `or` | left |
| 3 | `&&` `and` | left |
| 4 | `not` (same as `!` with a low precedence: `not 1 = 2` is `not (1 = 2)`) | right |
| 5 | `=` `==` `!=` `!==` (`=`/`!=` ignore case, `==`/`!==` do not) | left |
| 6 | `<` `>` `<=` `>=` | left |
| 7 | concatenation: ` . ` and two operands next to each other | left |
| 8 | `+` `-` | left |
| 9 | `*` `/` `//` | left |
| 10 | unary `-`, `!` (`!1 = 2` is `(!1) = 2`) | right |
| 11 | call `f(...)`, index `a[...]`, member `a.b` | left |

- Comparisons chain to the left: `1 < 2 < 3` is `(1 < 2) < 3`.
- `&&` and `||` are also written `and` and `or`. In the tree they are always `&&`, `||` and `!`.
- **Concatenation:** ` . ` needs whitespace on both sides (a dot without space on both sides is a member operator or an error). Without a dot, two operands next to each other are concatenated: `"a" x "b"`, `x " " y`, `"Sum: " (a + b)`. A `-` is always subtraction (`x -1` is `x - 1`). A `(` after whitespace starts a new operand (`round (2.5)` is `round` concatenated with `2.5`); without whitespace it is a call. Concatenation binds weaker than `+`: `"a" 1 + 2` is `"a" (1 + 2)`.
- An assignment is an expression and has a value (`x := y := 3`, `(x := 3) + 1`, `if (x := f())`). Parentheses are not a node; the node inside gets the span including the parentheses.

## 6. Grammar

```
expression-form  = [ expr ]                                  empty is allowed
script-form      = { statement }
statement        = block | if | expr                         expr must be an assignment or a call
block            = "{" { statement } "}"
if               = "if" expr statement [ "else" statement ]
expr             = or [ assign-op expr ]                     left side: name, dynamic name or path
or               = and { ("||" | "or") and }
and              = not { ("&&" | "and") not }
not              = "not" not | equality
equality         = relational { ("=" | "==" | "!=" | "!==") relational }
relational       = concat { ("<" | ">" | "<=" | ">=") concat }
concat           = add { "." add | add }                     second form: operand next to operand
add              = mul { ("+" | "-") mul }
mul              = unary { ("*" | "/" | "//") unary }
unary            = ("-" | "!") unary | postfix
postfix          = primary { "(" [ args ] ")" | "[" expr "]" | "." member }
primary          = number | string | "true" | "false" | name | "(" expr ")"
name             = part { part }                             parts touch each other, at least one word or %expr%
part             = word | "%" expr "%"
args             = expr { "," expr }
```

## 7. Function calls

`name(arg, ...)` and `obj.method(arg, ...)` are parsed for **any** name. Arguments are expressions (also assignments); an empty argument or a trailing comma is an error. Only a name, a dynamic name or a path can be called; `"a"(1)`, `5(1)`, `f(1)(2)` are errors.

Which functions exist is decided by the evaluator; calling an unknown function is an evaluation error with position, not a syntax error. v1 knew `round`, `object` and `print` (they could never be called there, because of a parser bug). The functions of v2:

| Function | Result |
|---|---|
| `round(number [, digits])` | AutoHotkey `Round`: `round(2.5)` is `3`, `round(-2.5)` is `-3`, `round(2.567, 2)` is `2.57`, a negative `digits` rounds left of the point (`round(1234, -2)` is `1200`). A text that is not a number gives the empty text and a warning |
| `object([key, value, ...])` | a new `Map` that ignores case in its keys (E28). An odd number of arguments is a warning |
| `print(value, ...)` | writes the values, separated by a space, to the log (level `f1`, text `print: ...`); an object is written as `<Map>`. Result is the empty text |
| `mod(a, b)` | remainder with the sign of `a`, as AutoHotkey `Mod`; the replacement for the missing operator `%` (section 13). Division by zero is a warning |

Names are case-insensitive. The table is extensible (`ExprFunctions.Register`, section 17). Methods (`a.b(1)`) cannot be called: they are an evaluation error.

## 8. Script form

One statement per line. An empty line or a comment line is skipped.

- **Statements:** an assignment (`x := 1`, `a.b += 2`), a function or method call (`print("hi")`), a block, an `if`. A line that is anything else (`1 + 1`, `x`, `x y`, `loop 3`, `return`) is an error; the language has no other statements (section 13).
- **`if expr`** followed by a statement on the next line, or by a block `{ ... }` (the brace may be on the same line as the condition). An optional `else` follows: on the same line after `}`, or on its own line; it takes a statement or block, or another `if` (`else if`). An `else` belongs to the nearest `if`. A statement on the same line as the condition without braces is not possible.
- **Blocks:** `{` and `}` may be on their own lines or on one line (`{ x := 1 }`). Blocks nest.
- **Continuation:** a statement goes on in the next line when the line ends with an operator (`x := 1 +`), or inside `( )`, `[ ]` and call parentheses. An operator at the **start** of the next line does not continue the previous line (unlike AutoHotkey): `x := 1` followed by `+ 2` is an error.
- Line breaks `\n` and `\r\n` are both accepted.

## 9. Syntax tree

Nodes are `Map`s. Absent children are the empty string `""`. Trees are never changed after parsing; the parse cache hands out the same tree again.

**Common fields of every node**

| Field | Meaning |
|---|---|
| `type` | the node type, below |
| `pos` | 1-based index of the first character in the source text |
| `end` | index of the first character after the node (`end - pos` is the length) |
| `line`, `col` | 1-based position of the first character (columns count UTF-16 code units, a tab is one column) |
| `depth` | height of the tree from this node down; a leaf has 1. At most 200 (section 11) |

**Expression nodes**

| `type` | Extra fields | Notes |
|---|---|---|
| `Number` | `value` (Integer or Float), `text` (spelling) | also `true`/`false` (`value` 1/0, `text` as written) |
| `String` | `value` (decoded text) | the span includes the quotes |
| `Var` | `name` | spelling as written |
| `DynVar` | `parts` (Array of nodes) | the values of the parts are joined as text and give the name; literal parts are `String` nodes |
| `Unary` | `op` (`"-"` or `"!"`), `operand` | `not` is `"!"` |
| `Binary` | `op`, `left`, `right` | `op`: `+ - * / // . = == != !== < > <= >= && \|\|`; `.` is concatenation, explicit or implicit |
| `Assign` | `op` (`:= += -= *= /= //= .=`), `target`, `value` | `target` is `Var`, `DynVar` or `Index` |
| `Index` | `object`, `key` (expression), `dot` (1 if written with a dot, else 0) | `a.b` has the key `String "b"`; `a.1` the key `Number 1` |
| `Call` | `callee` (`Var`, `DynVar` or `Index`), `args` (Array) | function call if the callee is a name, method call if it is an `Index` |
| `Empty` | | whole input of the expression form is empty (only whitespace and comments) |

**Statement nodes (script form)**

| `type` | Extra fields |
|---|---|
| `Script` | `body` (Array of statements) |
| `Block` | `body` |
| `If` | `cond` (expression), `then` (statement), `else` (statement, or `""`) |
| `ExprStmt` | `expr` (an `Assign` or a `Call`) |

**Result of a parse** (a `Map`): `ok` (1 or 0), `kind` (`"expression"` or `"script"`), `ast` (root node; `""` if there are errors), `errors` (Array, empty if `ok`). Partial trees are not returned.

## 10. Errors

The parser never throws for bad input. (`Expr.Parse` throws a `ValueError` for an unknown `kind` - a programming error.) Every error is a `Map`:

| Field | Meaning |
|---|---|
| `message` | text for the user, English, not translated |
| `line`, `col`, `pos` | position of the error (1-based); `pos` is the index in the text |
| `length` | number of characters marked (0 at the end of the input) |
| `lineText` | the source line without its line break |
| `marked` | the line with the marked part between `-> ` and ` <-`, like v1 `wholelinehighlighted`: `x := 1 + -> * <- 2` |

`Expr.FormatErrors(res)` gives `line 1, column 10: unexpected '*'; an operand is expected` and the marked line, for every error.

**Several errors are collected:** the tokenizer reports all text it cannot read (bad characters, unclosed strings, bad escapes, bad numbers) and goes on; in the script form the parser skips the rest of a line after a syntax error and reads the next line; in the expression form only the first syntax error is reported. Errors are sorted by position, never reported twice for the same position, and at most 50 are collected. Operators that exist in AutoHotkey but not here get their own message (`the modulo operator '%' is not supported`).

## 11. Limits

AutoHotkey ends the whole process (not just the call) when its call stack is full (about 2000 calls; verified). The parser and every later walk over the tree must stay far below that, so the language has limits. Hitting one is a normal error.

| Limit | Value | Error |
|---|---|---|
| nesting of parentheses, brackets, calls, unary operators, `%...%`, blocks and `if` | 50 | `nested too deeply` |
| height of the tree (`depth`), e.g. a chain `1 + 1 + ... + 1` | 200 (about 200 terms) | `the expression is too long or too deeply built` |
| errors collected | 50 | the rest is dropped |
| length of a name | 253 (variable name rule); the expression parser itself accepts longer names | - |

No limit on the length of strings, comments, the number of statements or arguments (tested with a string of one million characters, 5000 statements, 5000 arguments). The evaluator (WI-38) may walk the tree recursively up to the height limit.

## 12. Parse cache

`Expr.Parse` caches results by (form, text): the engine evaluates the same parameter texts over and over. At most 2000 entries; when full, the oldest entry is removed (first in, first out; reading does not renew it). Results with errors are cached too. Texts longer than 20000 characters are not cached. `useCache := false` skips the cache. The result `Map` and the tree in it are shared: **do not change them.**

Measurement (`tests/ahk/helpers/expr_bench.ahk`, 2000 rounds each, one run on the development PC, AutoHotkey v2 64 bit):

| Input | Parse without cache | Cache hit |
|---|---|---|
| `x + 1` (5 characters) | 170 us | 1.5 us |
| `round(a.b * 2.5, 2) . " units"` | 455 us | 1.5 us |
| `(count >= 10 and name = "abc") or not done` | 496 us | 1.5 us |
| `A_Index // 2 + list[i + 1].width * (offset - 3)` | 597 us | 1.5 us |
| script of 7 lines (101 characters) | 1051 us | 1.7 us |

Average 554 us uncached, 1.6 us cached (about 300 times faster). Filling the cache with 3000 different texts (the first 1000 are removed again) took 504 ms, so about 170 us per new text. The parser is not fast (many small objects and calls); the cache is what keeps repeated evaluation cheap. Not measured: memory use of 2000 cached trees.

## 13. Deliberately missing (possible later)

| Missing | Why / note |
|---|---|
| `%` as modulo | `%` delimits dynamic names; `mod(a, b)` is the replacement (section 7) |
| `**` power, bitwise `& \| ^ ~ << >> >>>`, `~=`, `??`, `?:` ternary | not used by v1 flows |
| `++`, `--`, unary `+` | write `x += 1` |
| `x ^= 2`, `x %= 2` and other compound assignments beyond section 5 | `^=` was accepted by the v1 tokenizer only |
| comma operator, several expressions in one statement | |
| `[ ]` array literals, `{ }` object literals, `=>` functions | objects come from `object()` (section 7) |
| `is`, `in`, `contains` | |
| `loop`, `while`, `for`, `return`, `break`, `try`, `throw`, `switch`, `class`, `global`/`local`/`static` declarations | the script form is `if`/`else`, blocks and assignments only; variable scope comes from the name prefix (section 18.2) |
| block comments `/* */`, line continuation sections `( ... )` | |
| `<>` for not equal | write `!=` |

## 14. Differences from AutoHotkey v2

Decided by the project owner (2026-10-13) and implemented by the evaluator (WI-38, tests in `tests/ahk/expr_eval_operators.test.ahk`):

- **E29: `/` with two integers** returns an Integer if the division is exact (`4/2` is `2`, `-8/-2` is `4`), else a Float (`7/2` is `3.5`). AutoHotkey v2 gives `2.0` for `4/2`. This is a rule of the language. `//` is the integer division as in AutoHotkey v2 (`7//2` is `3`, `-7//2` is `-3`; a Float operand is a `TypeError` there, handled as E25).
- **E30: `<` `>` `<=` `>=` follow AutoHotkey v2.** A comparison with a text that is not a number throws a `TypeError` in AutoHotkey (`"a" < "B"`); in AutoHotFlow the evaluator catches it (E25): the result is the empty text (false) plus an `f1` log entry. A text comparison that v1 did alphabetically is therefore false. `"10" < "9"` compares numbers (false). `=` and `==` compare as in AutoHotkey.
- **E31: `&&` and `||` return the operand** as AutoHotkey v2 does (`"a" || 0` is `"a"`, `0 && "x"` is `0`), not 1/0 as in v1. Evaluation is short-circuit (`0 and (x := 5)` does not assign). As a condition both behave the same.
- **E32: text form of floats** is the AutoHotkey v2 form, without own formatting (`0.1+0.2` is `0.30000000000000004`, `1/3` is `0.33333333333333331`).
- **E34: type errors per flow.** E25 is the behavior of the *compatibility mode* (`flowSettings.strictTypes` false, the mode of every migrated flow). In the *strict mode* (`strictTypes` true, new flows) the evaluator reports the same cases as before, but the caller turns every warning into an error of the element (section 17, doc/ELEMENT-API-V2.md section 3.1, MIGRATION M-47). The language itself is the same in both modes.
- **E25: type errors** while calculating (`"" + 1`, `"abc" + 1`) are caught; the result is the empty text and an `f1` log entry (in AutoHotkey v2 they throw a `TypeError`). The same holds for a division by zero (`1/0`, `1//0`, `mod(1, 0)`; `ZeroDivisionError` in AutoHotkey) and for any other calculation or function that fails. The entry is also a warning in the result (section 17).

Smaller points of the evaluator that follow from these rules or from v1:

- **A variable that does not exist** gives the empty text and an `f0` log entry (`Retrieving variable 'x' failed. It does not exist`), as in v1. The result lists it under `missing`; it is not a warning. Used in a calculation, the empty text is then a type error: `y + 1` with a missing `y` gives the empty text.
- **Compound assignment** (`x += 1`) reads `x` first. If `x` does not exist, that is a missing variable and `"" + 1` is a type error: `x` becomes the empty text. `x .= "a"` works on a missing variable. If the calculation of a compound assignment fails, the variable gets the empty text, as the calculation did in v1.
- **`mod(a, b)`** replaces the missing operator `%`.
- **`MinInt // -1`** (the smallest Integer divided by -1) would end the AutoHotkey process, not just the call; the evaluator refuses it as a calculation error (warning, empty text). `MinInt / -1` gives a Float.
- **`/` with texts:** a text that looks like an integer counts as an integer for E29 (`"4"/"2"` is `2`), as in all arithmetic; `"4.0"/2` is `2.0`.
- **Script result:** the value of the last statement, as in v1. A script without statements gives the empty text; an `if` without `else` whose condition is false, and an empty block, give `0` (v1 gave `false`).

Differences in the **syntax** (implemented and tested):

- Only the operators of section 5 exist; the rest of AutoHotkey's operators are errors with an explanatory message (section 13).
- Strings: the escape set of section 2 (no `` `s ``, `` `0 ``, `` `u+XXXX ``); no line break inside a string; touching strings (`"a""b"`) are an error.
- Dynamic names have the v1 form `a%i%`, `a%i%b`, `%n%` (AutoHotkey v2 only has `%expr%` as a deref). Parts must touch each other.
- Implicit concatenation does not need whitespace between operands that cannot be confused (`x"-"y`, `"a"1`); AutoHotkey requires whitespace. `-` is always subtraction.
- `5.`, `1_000` and numbers followed by letters are errors; an integer literal beyond 63 bits becomes a Float (own rule, not checked against AutoHotkey).
- `true` and `false` are keywords with the values 1 and 0 and cannot be variable names.
- Statements: only assignments, calls, blocks and `if` (section 8). An operator at the start of a line does not continue the previous line.
- `a.b` with the numeric member `a.1` is accepted (v1 list access); AutoHotkey writes `a[1]`.
- Not checked: the exact behaviour of AutoHotkey for escapes `` `, `` and `` `: ``, and for `;` directly after a closing quote.

## 15. Differences from v1 and conversion

What the new language does with the expressions of v1, checked against the golden data of v1 (WI-36: the result of the unchanged v1 code, run in the v1 interpreter). The language follows AutoHotkey v2 (E22); the converter rewrites an old text only where that is needed for the same result, and the rest is a known, documented deviation.

### 15.1 Deviation catalog

Reproduce with `python tools/golden_compare.py --plain` (list of the classes; `--list CLASS` shows the cases of one class). The check is `tests/golden/test_golden_v2.py`: every case in `tests/golden/cases/` (2161 cases) is run by the harness `tests/golden/v2/harness.ahk` with the variable model of the engine (section 18) and compared with v1: the 1418 expressions and scripts with the unchanged text (`--plain`, the column "Cases") and with the converted text (the column "After conversion"), and the cases of the variable model (WI-40): `%var%` substitution (`replace`, 392), name rule (`checkname`, 151), scope of a name (`destination`, 52), reading and setting a variable through the element API (`varget`, 67, `varset`, 81). The value and the variables afterwards (per scope) are compared. A case either agrees with v1 (`same`; numbers are compared as numbers, so `2.000000` and `2` agree) or gets exactly one class. A case without a class fails the test.

Handling: **accept** = decided, the converter does not rewrite it (entry in `doc/MIGRATION.md`); **rewrite** = the converter rewrites the text so that the result agrees (section 15.2); **unsupported** = syntax that the converter reports and does not convert (section 15.3). The column "After conversion" is the number of cases that still have the class when the converted text is evaluated.

| Class | Cases | After conversion | Example | v1 | v2 | Handling |
|---|---|---|---|---|---|---|
| assignment refused | 7 | 7 | `A_Index := 5` | (empty) | error: Setting variable 'A_Index' failed. No permission. | accept: an assignment that v1 refuses with an f0 log (an A_ name, no permission) is an error of the expression in v2, with the same text |
| assignment to a path | 31 | 31 | `a.b := 5` | (empty) | `5` | accept: v1 cannot assign to a path (a.b := 1 only logs an error); v2 can |
| assignment value | 36 | 36 | `x := 5` | (empty) | `5` | accept: an assignment has a value in v2; in v1 it has none (the empty text) |
| built-in value | 2 | 2 | `A_PtrSize` | `4` | `8` | accept: A_PtrSize is 8 (64 bit only, E4); A_LanguageName is the name of the language, v1 always gave the empty text |
| escape sequence | 11 | 11 | ``"a`nb"`` | `anb` | `a\nb` | accept: v1 drops the backtick in a string, v2 reads the escape (E22) |
| integer division with float | 3 | 3 | `7.0//2` | `3.000000` | (empty) | accept: // with a float operand is a type error in AutoHotkey v2 (E25); v1 divided |
| integer overflow | 1 | 1 | `12345678901234567890+1` | `-9223372036854775808` | `1.2345678901234567e+19` | accept: v1 wraps integers at 64 bit; v2 continues with a float |
| json text | 2 | 2 | `%o%` | `{\n  "k": "q\"uote\\back\/slash\nnl\ttab"\n}` | `{\n  "k": "q\"uote\\back/slash\nnl\ttab"\n}` | accept: the JSON text of an object (ConvertObjectToString) writes / without a backslash and a float inside an object as a number; v1 wrote \/ and a text |
| keyword as name | 8 | 8 | `if` | (empty) | error: 'if' is only valid at the start of a line of a script | accept: if, else, and, or, not cannot be variable names in v2 |
| no short circuit | 2 | 2 | `1 or (x := 5)` | `1` | `1` | accept: v1 evaluates both sides of and/or, v2 stops at the first that decides (E31) |
| not | 16 | 16 | `not 0` | `0` | `1` | accept: not and ! do not negate at the start of an expression in v1 (bug); v2 negates |
| number format | 22 | 21 | `x` | `0.500000` | `0.5` | accept: the same number in the text form of v2 (E24, E32) |
| number literal forms | 9 | 9 | `1e3` | `1` | `1000.0` | accept: v1 reads only digits (0x10 is 0, 1e3 is 1); v2 reads hexadecimal and exponent |
| number-like texts | 3 | 3 | `"1.0"="1"` | `1` | `0` | accept: v1 compares two texts that look like numbers as numbers, v2 as texts |
| object as text | 3 | 3 | `a . "x"` | `x` | (empty) | accept: an object in a concatenation is a type error in v2 (empty text and a warning, E25); v1 used the empty text for the object |
| operand as result | 34 | 34 | `5 && 6` | `1` | `6` | accept: and/or return an operand in v2, 1 or 0 in v1; the same as a condition (E31) |
| path into global or static | 6 | 6 | `global_o.a` | (empty) | `1` | accept: v1 cannot read a member of a global or static object (it looks for a file of that name); v2 can |
| script result value | 79 | 79 | `x := 5` | (empty) | `5` | accept: the value of a script is the value of its last statement (v1: unspecific) |
| text comparison | 26 | 26 | `"a"<"B"` | `1` | (empty) | accept: comparison with a text that is not a number: false in v2, alphabetical in v1 (E30, E25) |
| true and false | 2 | 2 | `true` | (empty) | `1` | accept: keywords with the values 1 and 0 in v2; ordinary (missing) variables in v1 |
| v1 error | 189 | 189 | `round(2.5)` | error: Expecting punctuation: ")" | `3` | accept: v1 reports an error or hangs; nothing to reproduce (E22) |
| v1 ignores text | 62 | 62 | `2*-3` | `2` | `-6` | accept: v1 stops at a token it cannot use and ignores the rest (glued operators like *-, a stray ), unknown operators, a second line) |
| backtick | 3 | 0 | ``"a`xb"`` | `axb` | error: unknown escape sequence `x | rewrite: a backtick in front of a character that v2 does not know as an escape |
| concatenation dot | 3 | 0 | `"a"."b"` | `ab` | error: the concatenation operator '.' needs a space before and after it | rewrite: v1 reads "a"."b" as concatenation; v2 needs spaces around the dot |
| number literal spelling | 3 | 0 | `1.50` | `1.50` | `1.5` | rewrite: v1 passes a number literal on as text (1.50, 007); v2 reads it as a number |
| unsupported syntax | 8 | 8 | `1<>2` | `1` | error: '<>' is not valid; write '!=' for not equal | unsupported: % as modulo, ^=, %=, <> and "a""b": reported, not converted |

**Result (all 2161 cases, converted text):** 1600 agree with v1. Of the 1418 expressions and scripts, 867 agree, 543 deviate in a class with the handling "accept" (189 of them are cases where v1 itself fails or hangs), 8 use syntax that is reported (section 15.3); no case is without a class. The name rules (`checkname`, `destination`) and setting variables (`varset`) agree in every case; reading variables (`varget`, 67) has 7 deviations (a member of a global or static object, the number format), the substitution (`replace`, 392) has 3 (number format, JSON text). The same check without the conversion (`--plain`) has 9 cases in the classes "backtick", "concatenation dot" and "number literal spelling" (3 each); the converter fixes these.

**In the example flows** (group `corpus_flows`, from 22 flows): of 519 expressions, 473 agree, 23 are `and`/`or` used as a value in a condition (same truth value), 6 differ in the number format only (`pi / 6`), 14 are comparisons of a missing or non-numeric variable with a number (`a_index <= 3` in the variants where `A_Index` is missing or a text, `countShuffleTries < 3`, `myIndex <= 5`: true in v1, false in v2; finding F-105), 3 are v1 errors (`%a_windowID%`). All 310 substitutions and all 102 variable names agree. Eleven distinct literals such as `4.9990` and `5.000000001` are converted to strings.

Notes on the classes:

- **v1 error** also contains the calls of functions (`round(2.5)` never worked in v1, S1 of the findings), `%` as modulo, `!` at the start, unary minus in front of a variable or a parenthesis, and every script that hangs the v1 parser. v2 evaluates these texts as written (`round(2.5)` is `3`); nothing is reproduced.
- **v1 ignores text** are cases where v1 stops reading at a token it cannot use and returns what it had until then (`2*-3` is `2` because `*-` is read as one unknown operator; `m[1][2]` and `m[1].x` give `m[1]`). The text was never meant to work that way; v2 reads it as written (`-6`). Not rewritten, because reproducing it would mean to cut off the text.
- **text comparison**, **operand as result**, **no short circuit**, **not**, **true and false**, **number format**, **integer division with float** are the decisions E30, E31, E25, E32 and E29 (section 14); **number-like texts** is the consequence of E30 for `=` with two texts that look like numbers.
- **escape sequence**: in v1 a backtick in a string is dropped (S2); v2 reads `` `n `` as a line feed. Only escapes that v2 does not know (`` `x ``, `` `1 ``) are rewritten (the backtick is dropped, as v1 did), because without that the text would not load.
- **assignment value**, **script result value**: an assignment has a value in v2 (`(x := 3) + 1` is `4`). The value of a script is only used by tests; the variables afterwards agree in all these cases.
- **assignment to a path**: `a.b := 5` only logged an error in v1 (variable names must not contain a dot); v2 sets the member.
- **assignment refused**, **built-in value**, **path into global or static**, **object as text**, **json text**: the variable model (section 18; MIGRATION M-38 and M-40 to M-43).

### 15.2 Conversion

The converter is `V1ExprConverter.Convert(text, kind)` in `src/expr/V1ExprConverter.ahk` (`kind` is `expression` or `script`). It reads the v1 text with the v1 rules at the token level (strings, comments, numbers, names with paths, runs of operator characters) and changes only the places of the rules below; everything else, including the spaces and comments, stays as the user wrote it. The result is a status, the text and the list of changes:

| Status | Meaning | Text |
|---|---|---|
| `unchanged` | nothing to change | the input |
| `converted` | at least one rule applied | the converted text |
| `unsupported` | the new language does not have a syntax the text uses (section 15.3) | the input |
| `failed` | the new language cannot read the text (v1 could not read most of them either) | the input |

Rules (classes with the handling "rewrite"):

| Rule | v1 text | converted | Why |
|---|---|---|---|
| backtick | ``"a`xb"`` | `"axb"` | v1 drops every backtick in a string. Where v2 knows the escape (`` `n ``, `` `t ``, `` `" `` ...) the text is not changed (class "escape sequence"); an unknown one would be an error |
| concatenation dot | `"a"."b"`, `x ."b"` | `"a" . "b"`, `x . "b"` | v1 reads a single dot that is not part of a number or a path (`a.b`, `m[1].x`) as the concatenation operator; v2 needs spaces around it, and `(1).x` would be a member access |
| number literal spelling | `1.50`, `007`, `5.`, `3.14` | `"1.50"`, `"007"`, `"5."`, `"3.14"` | v1 passes a number literal on as text. v2 writes a number from its value, and most decimals with 17 digits (`3.14` is `3.1400000000000001`). Only where the text form counts: the whole expression, the right side of `:=` and `.=`, an operand of the concatenation, an argument of a function. In a calculation or comparison, behind a unary minus, as an index and as an operand of `and`/`or` the number stays a number (`x = 1.50` compares numbers) |

The rules work on the text only. Which texts of a flow are converted, and when, is decided by the loader of the engine (`FlowExprConvert`, doc/ARCHITECTURE.md section 7): only parameters with an expression content type or named in `V1Syntax` of the element class, once per text. The text `%var%` in `String` parameters is not expression syntax and is not touched. Every conversion is in the log at level `f2` (flow, element, parameter, old and new text), every text that stays in v1 syntax at level `f1`.

The conversion is idempotent (checked for all golden texts: converting the result changes nothing). Not rewritten on purpose, with an entry in `doc/MIGRATION.md`: `/` (E29), the comparison of texts with `<` and the like (E30), `&&`/`||` as a value (E31), the text form of floats (E32), the escapes that v2 knows, the start of an expression with `not`, assignments as values, and everything that v1 ignored (class "v1 ignores text": a second line, glued operators such as `*-`, a stray `)`).

### 15.3 Syntax that is not converted

A text that uses one of these forms keeps its text and gets the status `unsupported` with a message that is logged at level `f1` (`unsupported syntax: <message> (line L, column C)`). It is then read by the new parser as it stands and fails at the first use with an error that names the same place.

| Form | v1 | New language | In the golden data |
|---|---|---|---|
| `%` as modulo | error at evaluation: `Can't apply operator %` (S3); never worked | not supported; `mod(a, b)` is the replacement | counted as "v1 error" |
| `^=` | the right operand and the assignment are ignored: `x ^= 2` returns x and sets nothing | not supported | `assignment.expr.pow.eq`, `assignment.script.pow.eq` (the v1 parser hangs on it in a script) |
| `%=` | like `^=` | not supported | `assignment.expr.mod.eq`, `assignment.script.mod.eq` |
| `<>` | one unknown operator, the right operand is ignored: `1<>2` is `1` | error with the hint to write `!=` | `comparison.not.equal.sql*` |
| `"a""b"` | two strings that touch: `ab`; the doubled quote was never an escape | error with the hint to write a quote as `` `" `` | `strings.doubled.*`, `strings.two.strings.touching` |

**Decided (project owner, 2026-10-14, WI-39):** these forms stay unsupported. None of them occurs in the expressions of the example flows (the corpus has only `%a_windowID%`, a text of unclear content type that the golden corpus also ran as an expression). All five are reported (`f1`) and left alone; they fail at the first use with an error that names the place. Possible later answers, if a real flow needs one: convert to the v2 form that does what the author meant (`<>` to `!=`; `"a""b"` to `` "a`"b" ``), or to what v1 really did (`"a" "b"`, which is `ab`).

## 16. Tokens (for implementers)

`ExprTokenizer` produces `ExprToken` objects: `NUM` (with `value`), `STR` (with the decoded `value`), `WORD`, `OP`, `NL` (script form only; several in a row become one), `ERR` (unreadable text, already reported) and `EOF`. Each token has `pos`, `len`, `line`, `col` and `ws` (whitespace, comment or line break before it). A `.` that touches a value in front of it and a name or `%` behind it is marked `member`, and the name behind it is scanned as a plain word (so `a.1` and `a.and` work). The scan uses one `RegExMatch` per token part, not one call per character.

Library files (`src/expr/`, includes only `src/core/` and itself, no GUI, no file access): `Expr` (entry point and cache use), `ExprParser`, `ExprTokenizer`, `ExprToken`, `ExprNode` (node constructors, the single place of the schema), `ExprNames`, `ExprDiag` (error records), `ExprCache`, `ExprAbort` (internal, never leaves the parser), `ExprEvaluator`, `ExprFunctions` (function table) and `ExprResolveError` (evaluator, section 17).

## 17. Evaluation

```
res := Expr.Evaluate(text, resolver, logFn)          ; expression form; Expr.EvaluateScript(...) for the script form
res["value"]       ; Integer, Float, String or a Map ("" for an empty expression)
res["errors"]      ; Array of records (section 10 fields: message, line, col, pos, length; with lineText and marked)
res["warnings"]    ; Array of records of the same form
res["missing"]     ; Array of records for variables that were read and do not exist (plus "name")
```

`Expr.Evaluate` parses with the parse cache (section 12) and calls `ExprEvaluator(resolver, logFn).Run(parseResult, text)`. The evaluator walks the tree recursively, which is safe up to the height limit of section 11 (tested at the limit). It never throws because of what the user wrote. If the text has syntax errors, the parse errors are the errors of the result, the value is the empty text and nothing is evaluated.

**Errors and warnings.** Evaluation goes on after both; the failed part is the empty text.

| | Cause | Log |
|---|---|---|
| warning | a calculation or function call that fails: type error (E25), division by zero, `object("a")`, `round("abc")`, a failing compound assignment | `f1`, `Expression warning: '+' failed: <AutoHotkey message> (line L, column C)` |
| error | unknown function, wrong number of arguments, method call, a name built by `%...%` that is not a valid variable name, a member of a value that has none, assignment to something that is not a variable, a refusal by the resolver | `f1`, `Expression error: <message> (line L, column C)` |
| missing | a read of a variable that does not exist | `f0`, `Retrieving variable 'x' failed. It does not exist` (a member of a path: the dotted path as name) |

Whether a warning or a missing variable matters is decided by the caller. For parameters and `ctx.EvaluateExpression` (WI-42, doc/ELEMENT-API-V2.md section 3.1): an error is always an error of the element; a warning is one only in the strict mode of a flow (`strictTypes`, E34), in compatibility mode it stays the empty text plus the `f1` entry (E25); a missing variable is never one.

**Resolver.** The evaluator knows nothing about scopes. `resolver` is any object with

- `Has(path)`: 1 if the variable or member exists
- `Get(path)`: its value (called only after `Has` gave 1)
- `Set(path, value)`: assigns

`path` is an Array of the evaluated parts: `a.b[i]` gives `["a", "b", <value of i>]`, `x%n%` with `n = 1` gives `["x1"]`, `a.1` gives `["a", 1]` (an Integer). A resolver throws `ExprResolveError` for a request that fails because of the expression (a member of a text, a read-only variable); the evaluator records an error with position. Any other exception of the resolver is an internal error and leaves the evaluator. A member of a value that does not come from a variable (`object("a", 1).a`) is read directly from the `Map`; only reading is supported there.

**Log.** `logFn(level, text)` receives the entries of the table above and the output of `print`. Pass `""` for none. A `logFn` that throws is ignored.

**Functions.** `ExprFunctions.Register(name, fn, minArgs, maxArgs)`; `fn` is called as `fn(ctx, args*)` with the evaluator as `ctx` (`ctx.Log(level, text)`), and `maxArgs` -1 means any number. The number of arguments is checked before the call. A function reports a user error by throwing; that becomes a warning.

**Measurement** (`tests/ahk/helpers/expr_eval_bench.ahk`, 5000 rounds each, parse cache hit, a log function installed, the simple resolver of the tests, one run on the development PC, AutoHotkey v2 64 bit): `x` 17 us, `x + 1` 22 us, `count * price` 29 us, `count >= 10` 19 us, `name = "abc"` 22 us, `(count >= 10 and name = "abc") or not done` 42 us, `o.width * (offset - 3) + count // 2` 56 us, `round(price * count, 1) . " total"` 43 us; a script of 7 lines with an `if` 94 us. The average of the 9 expressions is **31 us**, far below the aim of 0.2 ms (ARCHITECTURE 2.3). The cost of the real resolver of the engine is in section 18.6.

## 18. Variables

The engine owns all variables (ARCHITECTURE section 4). The model ports the v1 functions of `v1/Source_Execution/Variables/Variables.ahk` and `v1/Source_Common/Variables/Global variables.ahk` (WI-40). Code in `src/engine/vars/`:

| Class | Content |
|---|---|
| `VarNames` | the scope of a name (`Destination`), the name rule (`Check`), paths (`Split`) |
| `VarValues` | values: copies, objects as `Map`, keys |
| `VarAccess` | the view of one element run: element API, `%var%` substitution, resolver of the evaluator (section 17), imports of a worker |
| `BuiltInVars` | the built-in variables (18.4), the working directory of a flow |
| `EngineVars` | global and static variables (working copy in memory; loading and writing: WI-41) |
| `VarJson` | JSON text of a value (substitution with `ConvertObjectToString`) |

### 18.1 Scopes

| Scope | Names | Owner | Lives |
|---|---|---|---|
| loop | `A_...` | the thread (`ThreadState.Loops`, the loop stack) | while the loop runs: entering a loop at `head` pushes the loop variables, leaving it (`tail`, `exception`) restores them (ARCHITECTURE 5.2) |
| thread | `A_...` | the thread (`ThreadState.Vars`) | as long as the thread; a branch (clone) gets a copy |
| instance | any name without prefix | the instance (`Instance.Vars`) | as long as the instance; shared by its threads |
| static | `static_...` | `EngineVars`, one table per flow | permanent (WI-41) |
| global | `global_...` | `EngineVars`, one table | permanent (WI-41) |
| built-in | 68 `A_` names (18.4) | - | read only |

Loop, thread and instance each have a **hidden** table (`LoopStack.Hidden`, `ThreadState.HiddenVars`, `Instance.HiddenVars`), for elements that protect a value from the user (in v1 the loop "work through a list" and the trace points). Only the element API with `hidden := true` reaches them; an expression, the substitution and `ListVars` never see them. Global and static variables cannot be hidden (`ElementError`, v1 threw an exception).

At the start of an instance the trigger thread gets the thread variables `A_TriggerTime` (`A_Now`) and `A_TriggerID` (the ID of the trigger element), as in v1 `newInstance`.

### 18.2 The name decides the scope

**Reading** (v1 `Var_GetLocation`): an `A_` name is looked up in the loop variables, then in the thread variables, then in the built-in variables; a `global_` name in the global table; a `static_` name in the static table of the flow; any other name in the instance table. The prefixes ignore case (`a_index`, `GLOBAL_x`). A variable is only found in the table that its name names: an instance variable called `global_x` (which v1 could not create either) is invisible.

**Setting** with the element API, `SetVar(name, value, location)` (v1 `Var_Set`, `Var_RetrieveDestination`):

| Name | location `""` | location `thread` or `loop` |
|---|---|---|
| `A_...` | refused: `Setting variable 'A_x' failed. No permission.` | thread or loop |
| `global_...`, `static_...` | global, static | refused: `Setting variable 'x' failed. It does not start with 'A_'.` |
| other | instance | refused (same text) |

Refused as well: an empty name (`Setting a variable failed. Its name is empty.`) and a name with a forbidden character (`Setting variable 'a.b' failed. It contains forbidden characters.`). A refusal is an `f0` log entry and the return value 0, as in v1. The name rule is that of section 3 (`ExprNames.Check`); as in v1, setting accepts a name that starts with a digit.

**Setting in an expression** (`x := 1`) follows the same rules without a location: an `A_` name cannot be assigned from an expression. v1 logged `No permission`; v2 reports the same text as an error of the expression (`f1`, MIGRATION M-38).

**The common place** is a view without instance and thread (v1 `*_Common`, used by the editor and the manager): only global, static and built-in variables are visible, only global and static can be set, any other name is `No permission`.

### 18.3 Values and objects (E28)

- A value is a text, a number (`Integer`, `Float`) or an object. A number keeps its type; v1 turned it into a text on the way through a variable (`0.5` came back as `0.500000`, M-39).
- **An object is a `Map` with `CaseSense "Off"`. There are no Arrays in variables** (decided in WI-40): a list is a `Map` with the keys 1..n, as in v1, where a list was an object with integer keys. An Array that comes in (a JSON array of a variable file in WI-41, a value set by an element, an export of a worker) becomes such a `Map` (`VarValues.Import`). Reason: one kind of object for paths, assignment and the JSON text; `list.1` and `list[1]` must be the same member.
- **Keys:** a key that is a text of decimal digits (an optional minus, at most 18 digits) is the `Integer`: `list.1`, `list[1]`, `list["1"]` and `list["01"]` are the same member, as in v1 (golden cases `objects.dict.key.*`). Every other key is a text and ignores case; the spelling of the first insertion stays.
- **Order:** an object enumerates its `Integer` keys in ascending order, then its texts sorted without case (`-3, 1, 2, 10, A, b`), which is the order of v1 (golden case `objects.dict.whole`). This is the order of an AutoHotkey `Map` (verified).
- **Copies:** a value is copied when it goes into a variable and when an element reads it. `b := a` gives `b` its own object; `b.k := 2` does not change `a` (as v1). A thread that is cloned and every level of the loop stack own their values.
- **Paths:** `a.b.1` in a name (element API, `%a.b.1%`; split at every dot as v1 `parseObjectPath`) and `a.b[i]` in an expression. A member that does not exist, or a member of a text, does not exist (`f0`, as a missing variable). Assigning to a member in an expression creates the variable and the members on the way as objects; a member of a text is an error of the expression (`'t' is not an object; its member 'k' cannot be set`). A member of a global or static object can be read and set (v1 looked for a file with the dotted name, M-40). `DeleteVar("a.b")` removes a member. A name with a dot cannot be set with `SetVar` (forbidden character, as in v1); members are set in an expression.

### 18.4 Built-in variables

55 variables of AutoHotkey and 13 of AutoHotFlow (v1 `global_AllBuiltInVars` and `global_AllCustomBuiltInVars`, `Global variables.ahk:2` and `:4`; the phase plan counted 14, the v1 list has 13). Names ignore case. A thread or loop variable with the same name hides a built-in variable. A getter that fails gives the empty text.

| Name | v1 | v2 | Deviation |
|---|---|---|---|
| `A_Space`, `A_Tab` | AutoHotkey | the AutoHotkey v2 variable | - |
| `A_YYYY`, `A_Year`, `A_MM`, `A_Mon`, `A_DD`, `A_MDay`, `A_MMMM`, `A_MMM`, `A_DDDD`, `A_DDD`, `A_WDay`, `A_YDay`, `A_Hour`, `A_Min`, `A_Sec`, `A_MSec`, `A_Now`, `A_NowUTC` | AutoHotkey | the AutoHotkey v2 variable | - |
| `A_TickCount`, `A_TimeIdle`, `A_TimeIdlePhysical` | AutoHotkey | the AutoHotkey v2 variable | - |
| `A_Temp`, `A_WinDir`, `A_ProgramFiles`, `A_AppData`, `A_AppDataCommon`, `A_Desktop`, `A_DesktopCommon`, `A_StartMenu`, `A_StartMenuCommon`, `A_Programs`, `A_ProgramsCommon`, `A_Startup`, `A_StartupCommon`, `A_MyDocuments` | AutoHotkey | the AutoHotkey v2 variable | - |
| `A_OSVersion`, `A_Is64bitOS`, `A_Language`, `A_ComputerName`, `A_UserName`, `A_IsAdmin`, `A_ScreenWidth`, `A_ScreenHeight`, `A_ScreenDPI`, `A_Cursor` | AutoHotkey | the AutoHotkey v2 variable | - |
| `A_PtrSize` | AutoHotkey (4, 32 bit) | 8 | 64 bit only (E4), M-41 |
| `A_ScriptDir` | AutoHotkey: the folder of the v1 program | `A_ScriptDir` of the engine: the folder of the v2 program (where `AutoHotFlow.ahk` is) | the folder, not the meaning |
| `A_IPAddress1` to `A_IPAddress4` | AutoHotkey v1 | `SysGetIPAddresses()` (v2 has no such variables); `0.0.0.0` if there are fewer adapters | not checked against v1 |
| `A_CaretX`, `A_CaretY` | AutoHotkey v1 | `CaretGetPos` with `CoordMode("Caret", "Window")` (relative to the active window, the v1 default); empty without a caret | not checked against v1 |
| `A_YWeek` | own: the last two characters of `A_YWeek` (only the week) | the same | - |
| `A_LineFeed`, `A_LF`, `A_CarriageReturn`, `A_CR` | own | line feed, carriage return | - |
| `A_WorkingDir` | own: `x_GetWorkingDir` (flow setting `WorkingDir` unless `DefaultWorkingDir`, else the setting `FlowWorkingDir`) | the same rule (`BuiltInVars.WorkingDirOf`); until the settings exist (S4) the default is `A_MyDocuments "\AutoHotFlow"` (E28) | - |
| `A_LanguageName` | own: always empty (a TODO in the v1 code) | the English name of the user's language (`A_Language` through `LCIDToLocaleName` and `GetLocaleInfoEx`, e.g. `German`) | M-41 |
| `A_NowString` | own: `FormatTime` of `A_Now` with the default format | `FormatTime(A_Now)` | - |
| `A_FlowName`, `A_ElementName` | own: read from the flow when the variable is read | from the revision of the flow the element started with | at most a rename during the element |
| `A_FlowID`, `A_ElementID` | own | the IDs of the element run | - |
| `A_AhfVersion` | own | `AhfVersion.Current` (`src/core/AhfVersion.ahk`) | the text of the version |
| `A_VerticalTab`, `A_VT`, `A_Formfeed`, `A_FF` | handled by `BuiltInVariable_Get`, but in neither name list: they do not exist (golden case `builtin.vt`) | they do not exist | - |

### 18.5 `%var%` substitution

`VarAccess.Replace(text, convertObjects)` is v1 `Var_replaceVariables`, step by step, with its odd cases (golden group `replace`): the first pair of percent signs is taken (`SU).*%(.+)%.*`), whatever is between them is the name (also `a b` or `x+1`, which do not exist); the first occurrence of `%name%` in the result is replaced by the value, and in the rest of the search text by `_`. So `50% off %x%` gives `50x%` (the name is ` off `), and a value that contains `%y%` is not replaced again. A variable that does not exist gives the empty text and the `f0` entry `Retrieving variable 'x' failed. It does not exist` (in the common place: `... It does not exist or is neither global nor static`); its name is added to the list `missing` if the caller passes one. An object gives the empty text, or with `convertObjects` its JSON text (`VarJson`: indented by 2 spaces, in the common place on one line, as v1). The JSON text writes `/` as it is and a float as a number; v1 wrote `\/` and a float inside an object as a text (M-42).

v1 wrote an `f3` entry for every variable that was read (`Retrieving instance variable 'x'`). v2 does not (a log call per read would cost more than the read itself); only missing variables are logged.

### 18.6 The resolver and the element API

`VarAccess` is the resolver of the evaluator (section 17): `Has(path)`, `Get(path)` (an object as a copy), `Set(path, value)` (the rules of 18.2 and 18.3; a refusal is an `ExprResolveError`, which the evaluator reports as an error with position).

Measured with `tests/ahk/helpers/expr_eval_bench.ahk` and `VarAccess` instead of the test resolver (5000 rounds each, one run on the development PC): the average of the 9 expressions is 50.6 us (24.5 us with the test resolver in the same session), `x` 23.6 us, `o.width * (offset - 3) + count // 2` 111.1 us. Still below the aim of 0.2 ms; the cost is the lookup by name and the record of the place for every read.

The element API (`ctx`, ELEMENT-API-V2 section 3) is `SetVar`, `GetVar` (a copy, or the default if it does not exist; no log), `DeleteVar`, `VarLocation` (`loop`, `thread`, `builtin`, `instance`, `static`, `global` or empty; v1 wrote `Loop`, `Thread`, `BuiltIn`) and `ListVars(scope)` (the visible variables of a scope, or of all scopes in the order loop, thread, instance, static, global; no hidden and no built-in variables, as v1 `Var_GetListOf*Vars`).

**A worker** gets copies of the visible loop, thread and instance variables as its imports (a loop variable hides a thread variable of the same name); global, static, hidden and built-in variables are not sent. Its exports come back as variables where their name says (an `A_` name as a thread variable). Both are provisional until variables in the worker are reached through `ctx.Request` (S2, R4).
