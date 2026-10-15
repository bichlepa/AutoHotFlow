# Golden data: findings about the v1 expression code

Result of work item WI-0036, task 7 (`work_items/phase3/README.md`, section "Findings from the v1 code"). The suspected v1 bugs were confirmed or refuted by running the unchanged v1 code in the v1 interpreter. Every case ID names an entry in `tests/golden/expected/`. `tests/golden/test_golden_format.py` checks that all IDs exist.

Interpreter: AutoHotkey_H 1.1.32.00, 32 bit (`v1/AutoHotKey/AutoHotFlow.exe`).

Verdicts: **confirmed** = the suspicion is right; **refuted** = wrong; **not checked** = not covered by the harness.

## Suspicions

### S0001: Function calls with arguments always fail

Source suspicion: `Code parser.ahk:594`, inverted condition. **Verdict: confirmed.**

Every call with an argument gives the parse error `Expecting punctuation: ")"`. Calls without arguments fail too, with `Unexpected token in expression`. In script mode v1 ignores the parse error: `x := round(2.5)` stores the text `02.5`, and `foo(1)` reaches the evaluator (`unknown function foo called`). `round`, `object` and `print` can never be called in v1.

Cases: `functions.round.int`, `functions.round.half`, `functions.round.frac`, `functions.print.arg`, `functions.unknown.arg`, `functions.round.empty`, `functions.object.noargs`, `functions.print.noargs`, `functions.unknown.noargs`, `assignment.script.func`, `functions.script.call.unknown`, `functions.script.call.object.assign`

### S0002: Escape sequences in strings are lost

Source suspicion: `:718` compares with the empty variable name. **Verdict: confirmed.**

The escape character (backtick) is dropped and the next character is kept: `` "a`nb" `` gives `anb` (no line feed), `` "a`b" `` gives `ab`. An escaped quote ends in the error `Linefeed inside a string`. A doubled quote `"a""b"` gives `ab`, not `a"b`.

Cases: `strings.escape.n`, `strings.escape.t`, `strings.escape.r`, `strings.escape.backtick`, `strings.escape.unknown`, `strings.escape.quote`, `strings.doubled.quote`, `strings.doubled.quote.only`

### S0003: `%` (modulo) is not known to the evaluator

**Verdict: confirmed.** Evaluation error `Can't apply operator %`. The parser knows `%` (precedence 20), the evaluator does not.

Cases: `division.modulo`, `division.modulo.nospace`, `division.modulo.var`, `division.modulo.float`

### S0004: `!` and `not` at the start of an expression fail

**Verdict: confirmed, and wider.**

`!` is a parse error at the start and after `and` or `||`. `not` does not fail, but does not negate: at the start it is read as a variable named `not` and concatenated (`not 0` gives the text `0`, `not abc` gives `abc`). After `and` the value is wrong (`1 and not 0` gives 0). Only as an operator behind an operand does it negate the right side (`not not 1` gives 0). Inside `if`, `if not a` behaves like `if a`.

Cases: `logic.bang.0`, `logic.bang.paren`, `logic.var.bang`, `logic.bang.in.middle`, `logic.bang.after.or`, `logic.var.a.and.bang.b`, `logic.not.0`, `logic.not.1`, `logic.not.text`, `logic.var.not`, `logic.not.in.middle`, `logic.var.a.and.not.b`, `logic.not.not`, `script.var.if.not.var`

### S0005: ` ;` (space, semicolon) cuts off a string

Source suspicion: `Code tokenizer.ahk:24`. **Verdict: confirmed.**

`"a ;b"` and a tab before the semicolon give the parse error `Linefeed inside a string`. `"a;b"` and `"a;"` are fine.

Cases: `strings.semicolon.space`, `strings.semicolon.tab`, `strings.semicolon.nospace`, `strings.semicolon.end`

### S0006: `this.input.croak` does not exist; errors are swallowed

**Verdict: confirmed.** `else` without `if`: the parser records no error and skips the keyword. Only the evaluator reports the unspecific `Unexpected error during evaluation`, and the next statement still runs.

Cases: `script.else.alone`

### S0007: The evaluator uses v1 operators

Suspicion: `"" + 1` is the empty text, `4/2` is `2.000000`, `<` compares text alphabetically. **Verdict: confirmed.**

`"" + 1` is the empty text, `4/2` is the number 2.000000. `"a" < "B"` is 1 (case-insensitive alphabetical), `"10" < "9"` is 0 (both look like numbers: numeric), `"10" < "9a"` is 1. `=` ignores case, `==` does not. Case folding is ASCII only (`"ä" = "Ä"` is 0).

Cases: `arithmetic.text.empty.left`, `arithmetic.text.nonnumeric`, `division.exact`, `division.inexact`, `division.third`, `comparison.lt.text.upper`, `comparison.lt.text.alpha`, `comparison.lt.numstr`, `comparison.lt.numstr.alpha`, `comparison.eq.case`, `comparison.eqeq.case`, `comparison.eq.unicode`, `comparison.lt.unicode`

### S0008: The location of a variable follows from its name

Source suspicion: `Variables.ahk:219`, `:253`. **Verdict: confirmed.**

`A_` needs the location thread or loop, other names never. The `global_` and `static_` prefixes are compared case-insensitively. Loop wins over thread. A variable with a `global_` name in the instance store is invisible.

Cases: `names.dest.plain`, `names.dest.a.none`, `names.dest.a.thread`, `names.dest.plain.thread`, `names.dest.global.case`, `variables.loop`, `variables.thread`, `variables.global`, `variables.static`, `variables.loop.and.thread.same.name`, `variables.global.name.in.instance.store`

### S0009: Hidden variables per scope; `global` and `static` are read from disk on every access

**Verdict: not checked** (hidden variables); the disk access is visible only indirectly. The harness does not set hidden variables. Global values come back from the file as text (`5`, `0.500000`); objects come back as objects.

Cases: `varaccess.get.global.number`, `varaccess.get.global.float`, `varaccess.get.global.object`

### S0010: Built-in variables: 55 from AHK and 14 of its own

**Verdict: partly checked.** Fixed-value built-ins and 29 machine- or time-dependent ones (volatile, only the type is stored) are covered. `a_vt`, `A_VerticalTab`, `a_ff`, `A_Formfeed` are handled by `BuiltInVariable_Get`, but are in neither name list, so the variable does not exist and the value is empty.

Cases: `builtin.vt`, `builtin.vt.long`, `builtin.ff`, `builtin.ff.long`, `builtin.space`, `builtin.lf`, `builtin.flowname`

## Further observations

### Variable values are text

A value that went through `Var_Get` (it returns a clone) is text in v1, even if it was a number before (a stored 0.5 reads `0.500000`). Only the result of arithmetic is a pure number. Global and static variables come back from their file as text.

Cases: `variables.instance.number`, `variables.instance.float`, `varaccess.set.number`, `varaccess.set.global.number`

### Operator characters glue together

`2*-3` becomes the unknown operator `*-`: the right operand is silently dropped and the result is 2. The same for `5--3` (5), `7/-2` (7), `-8/-2` (-8), `7//-2`, `1<>2` (1). With a space (`5 - -3`) it works. The corpus has no such value.

Cases: `arithmetic.mul.neg`, `arithmetic.minus.minus.joined`, `arithmetic.minus.minus.spaced`, `division.neg.right`, `division.both.neg`, `division.int.div.neg.right`, `comparison.not.equal.sql`

### Unary minus only in front of a number literal

`-x`, `-(2+3)` and `- 5` are parse errors `Number expected`.

Cases: `arithmetic.neg.var`, `arithmetic.neg.paren`, `arithmetic.neg.space`, `arithmetic.neg.literal`

### Division by zero and integer division

Division by zero gives the empty text, no error. `//` truncates towards zero for negative integers (`-7//2` is -3) and gives the float format for floats (`7.0//2` is 3.000000).

Cases: `division.zero.divisor`, `division.int.div.zero`, `division.var.zero`, `division.int.div.neg.left`, `division.int.div.float`

### Number format

Floats have 6 decimals (`0.1+0.2` is 0.300000), also for big values (333333333333.333313). Integers wrap at 64 bit. `'0x10'+0` is 16; `'1e3'+0` and `'5abc'+1` are empty.

Cases: `arithmetic.float.sum`, `division.big`, `arithmetic.int64.max`, `arithmetic.text.hex`, `arithmetic.text.exp`

### Hangs of the script parser

The parser never ends (the harness stops it after 8 s, outcome `timeout`) for a script line that starts with `;`, for an unknown character at the start of a statement, and for the assignment operators `//=`, `^=`, `%=` in script mode. As an expression the same operators are an unknown operator: the right operand is dropped and the result is the left value (`x //= 2` returns x, nothing is assigned).

Cases: `script.comment.line`, `script.comment.only`, `script.statement.unknown.char`, `assignment.script.intdiv.eq`, `assignment.script.pow.eq`, `assignment.script.mod.eq`, `assignment.expr.intdiv.eq`

### Paths into objects: readable, not writable

`Var_Set` calls `Var_CheckName`, which refuses a dot. So `a.b := 5` only logs f0 `Setting variable a.b failed. It contains forbidden characters.` and changes nothing. Whole objects can be assigned.

Cases: `variables.object.dot`, `variables.object.dot.number`, `variables.object.bracket.number`, `variables.object.bracket.expr`, `variables.object.bracket.nested`, `assignment.script.path.dot`, `objects.set.new.key`, `objects.set.list.append`, `varaccess.set.path.new`, `objects.set.global.whole`, `objects.set.object.over.text`

### Dereferences in names do not work

`%` starts an operator token, so `a%i%` and `%n%` give parse errors or `Can't apply operator %`.

Cases: `variables.deref.suffix`, `variables.deref.whole`, `variables.deref.middle`, `variables.deref.path`, `variables.deref.unclosed`, `assignment.expr.deref.name`

### Paths into global and static objects

`global_o.a` is empty: the existence check looks for the file `global_o.a.ahfvd`.

Cases: `variables.global.object.path`, `varaccess.get.global.path`, `objects.global.roundtrip.number.in.object`

### Objects: key case, integer keys, order, JSON text

Keys are case-insensitive (`c` and `C` are one key, the spelling of the first insertion is kept). A key that looks like an integer is an integer (`01` and `1` are the same key, the later value wins). Enumeration order: integers ascending, then text sorted case-insensitively. `liste.1`, `liste[1]` and `liste["1"]` are the same; index 0 and out-of-range read empty. The JSON text of an object (`ConvertObjectToString`) is indented by 2 spaces and escapes `/` as `\/`; a float inside an object comes out as text.

Cases: `objects.dict.key.lower`, `objects.dict.key.upper`, `objects.dict.key.number.leading.zero`, `objects.dict.whole`, `objects.convert.mixed`, `objects.list.dot.one`, `objects.list.bracket.one`, `objects.list.string.one`, `objects.convert.special.chars`, `objects.convert.list.mixed.types`

### An assignment has no value and no short circuit

`Var_Set` returns nothing, so `(x := 3) + 1` is not a sum, `x := y := 3` is an error, and `x := (y := 3)` stores the empty text in x. `and` and `or` evaluate both sides: `0 and (x := 5)` still sets x.

Cases: `assignment.expr.result.plus`, `assignment.expr.chain`, `assignment.script.chain.paren`, `logic.var.nocut.assign`

### A_ names cannot be set without a location

Setting an `A_` name from a script logs f0 `No permission.`. Reading an unknown `A_` name gives the empty text and only the f0 log `Retrieving variable ... failed`.

Cases: `assignment.script.name.a.underscore`, `assignment.script.name.a.underscore.thread`, `builtin.script.assign.builtin.name`, `variables.a_unknown`

### Variable name check

Refused: empty (`Empty`), a leading digit (`StartsWithNumber`, also `1.5`), and every character the interpreter rejects in `asdf%name%` (space, dot, minus, comma, semicolon, colon, brackets, question mark, parenthesis, quote, percent, backtick, operators, control characters), and names longer than 253 characters. Accepted: letters including umlauts, digits, underscore, `@`, `$`, `#`, emoji, and reserved words (`if`, `A_Index`).

Cases: `names.check.plain`, `names.check.empty`, `names.check.start.digit`, `names.check.float`, `names.check.negative`, `names.check.space.inside`, `names.check.dot`, `names.check.umlaut`, `names.check.at`, `names.check.emoji`, `names.check.keyword.if`, `names.check.long`

### Script mode

A parse error in a script is not looked at by `var_evaluateScript`; the evaluator runs anyway (outcomes `parse_error_ignored` / `eval_error`). `if` works without braces for one statement, with `else`, `else if` and nesting. A statement that is not a name (`1 + 1`, `"abc"`) is an error; two assignments on one line fail; there is no line continuation.

Cases: `script.if.else.false`, `script.else.chain`, `script.if.no.body`, `script.statement.expression`, `script.statement.two.on.line`, `script.continuation.operator`, `script.value.of.if`

## Corpus: what the flows use

Source: the 22 example flows of `v1/AppData/Saved Flows` (group `corpus_flows`).

- Parameters with a value: 4071.
- Generated cases: 931.
- Distinct expressions: 227. Distinct substitution strings: 284. Distinct variable names: 102.
- Operators in the distinct expressions: `=` 74, string literal 45, `and` 29, `-` 13, `<=` 7, `/` 6, `+` 6, `!=` 4, `>=` 3, `>` 3, `or` 3, `&&` 2, `||` 2, `(` 2, `*` 2, `<` 2, `[` 1, `==` 1.
- Not used by the flows: assignments (`:=`, `+=` ...), `not`, `!`, function calls, `//`, `.`, modulo, escapes, ` ;` comments, operators glued to a minus sign.
- Substitution strings with `%`: 22.
- Unclear content type: 79 cases, 20 distinct values.
- Failing in v1: one distinct value, `%a_windowID%`, run as an expression (3 cases). It is a parameter whose content type could not be determined, so it also runs as a substitution, where it works. All other expressions, substitutions and names run without a parser or evaluator error. Real flows use the part of the language that works: comparisons, `and`/`or`, literals, variable reads, read-only paths.
- Note: the variants give every variable a distinct small number or a `t<n>` text, so most conditions evaluate to 0. They check the type handling, not every branch; the hand-written groups cover the branches.

## Not covered

- `evalparam` (`x_AutoEvaluateOneParameter`) is not in the harness. It lives in the API file next to about a hundred functions that need the whole application, and `#Include` cannot take one function. Options if WI-0042 wants golden data for the post-checks: a copy in the harness (no longer v1 code) or stubs for all callees. Decision needed then.
- The editor and manager variants `xx_replaceVariables`, `xx_EvaluateExpression`, `xx_CheckVariableName` in `v1/Source_Common/Multithreading/API for Elements.ahk` pass the variables `String`, `pars`, `VarName` (empty there; the parameters are called `p_String` ...). Read from the source, not executed. The cases with `common=true` test the `_Common` functions themselves.
- Hidden variables, the loop-variable stack, `Var_GetListOf*`, deleting variables.
- `lang()` is a stand-in that fills in the numbered arguments; error texts read `line 1, col 4`. The real texts depend on the UI language.
- The path through which an element reaches the evaluator (`x_AutoEvaluateParameters`) was read, not run.
