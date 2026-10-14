"""Oracle of the expression language: native AutoHotkey v2 against the evaluator (work item WI-44, E35).

Usage:
    python tools/expr_oracle.py                      # fixed corpus (tests/oracle/corpus.jsonl)
    python tools/expr_oracle.py --seed 7 --count 20000   # random run; a failing seed is printed
    python tools/expr_oracle.py --write-corpus [--seed N --count N]   # regenerate the checked-in corpus
    python tools/expr_oracle.py --show TEXT          # run one expression on both sides and print the result
    python tools/expr_oracle.py --classes            # the list of deliberate deviations

Expressions are generated from the grammar of doc/EXPRESSION-LANGUAGE.md with a seed (reproducible). Every case
runs twice: as real AutoHotkey v2 code (a script written by this tool, one function per case, the variables as
parameters, wrapped in try/catch) and in the evaluator (tests/oracle/eval_harness.ahk, src/expr/). The result is
the type (Type()), the text form (String()) and, for a failing case, the error class and message.

The results may differ only by the deliberate deviations of CLASSES (doc/EXPRESSION-LANGUAGE.md section 14,
doc/TEST-STRATEGY.md section 8). Where a deviation changes the value, the case also has a *model*: the same
expression with the deviation applied in native code (`/` as the function D, which gives an Integer for an exact
division of integers; a decimal literal beyond 63 bits as a Float). The evaluator must agree with the model, so a
deviation cannot hide a second, unlisted difference. A case without an entry in CLASSES fails (exit code 1).

Both sides get the same variables (ENV): numbers, texts that look like numbers, the empty text, edge values and a
Map. A case may assign to the variables of its own copy.
"""

import argparse
import json
import os
import random
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import ahkrun  # noqa: E402

ORACLE_DIR = os.path.join(ROOT, "tests", "oracle")
HARNESS = os.path.join(ORACLE_DIR, "eval_harness.ahk")
CORPUS = os.path.join(ORACLE_DIR, "corpus.jsonl")
BATCH = 1500          # cases per native script (a script of this size loads in about a second)
MIN_INT = -2 ** 63

# ------------------------------------------------------------------------------------------------ variables

# name -> typed value. Names ignore case on both sides, so no two names differ only in case.
ENV = {
    "i0": ("int", "0"), "i1": ("int", "1"), "i2": ("int", "2"), "i3": ("int", "3"), "i7": ("int", "7"),
    "i16": ("int", "16"), "ineg": ("int", "-3"), "imax": ("int", "9223372036854775807"),
    "imin": ("int", "-9223372036854775808"), "ibig": ("int", "3037000500"),
    "f05": ("float", "0.5"), "f15": ("float", "1.5"), "fneg": ("float", "-2.5"), "f3": ("float", "3.0"),
    "fz": ("float", "0.0"), "fnz": ("float", "-0.0"), "fhuge": ("float", "1e300"), "ftiny": ("float", "1e-300"),
    "sint": ("str", "5"), "sneg": ("str", "-7"), "sflt": ("str", "2.5"), "shex": ("str", "0x10"),
    "sexp": ("str", "1e3"), "ssp": ("str", " 5 "), "szero": ("str", "0"), "sdot": ("str", "1.0"),
    "sone": ("str", "1"), "sabc": ("str", "abc"), "shello": ("str", "Hello"), "supper": ("str", "ABC"),
    "smix": ("str", "5abc"), "sempty": ("str", ""),
    "w1": ("int", "0"), "w2": ("str", ""), "w3": ("int", "1"),     # targets of nested assignments
    "m": ("map", {"k": ("int", "1"), "s": ("str", "x"), "f": ("float", "2.5")}),
}
NESTED_TARGETS = ["w1", "w2", "w3"]
NUMERIC_VARS = ["i0", "i1", "i2", "i3", "i7", "i16", "ineg", "f05", "f15", "fneg", "f3", "fz", "fnz", "sint", "sneg",
                "sflt", "shex", "sexp", "ssp", "szero", "sone", "sdot", "ibig", "fhuge", "ftiny"]
EDGE_VARS = ["imax", "imin"]
TEXT_VARS = ["sabc", "shello", "supper", "smix", "sempty"]
BIG_VARS = {"imax", "imin", "ibig"}
# Floats whose text becomes a number outside the range of Float when digits are appended (F-284*): not used where a text or
# a truth value is made of them
RANGE_VARS = {"ftiny", "fhuge"}
KEYS = ["k", "s", "f", "K", "k", "s", "f", "zz"]       # "zz" does not exist
MISSING_VAR = "nothere"            # not in ENV: a variable that does not exist

# ------------------------------------------------------------------------------------------------ deviations

# class -> description. A case that differs from native AutoHotkey v2 and has no entry here fails.
CLASSES = {
    "E25": "A calculation or function call that throws in AutoHotkey (TypeError, ZeroDivisionError, ValueError) gives "
           "a warning and the empty text for that part; the evaluation goes on. Strict mode (E34) turns the warning "
           "into an error of the element. The message of the warning contains the message of AutoHotkey. The value "
           "of the whole expression is not compared (the evaluator goes on after the failed part).",
    "E29": "`/` of two integers (or texts that look like integers) that divide exactly gives an Integer (4/2 is 2, "
           "AutoHotkey: 2.0). Model: `/` as the function D.",
    "literal beyond 63 bits": "A decimal integer literal that does not fit into 63 bits is a Float in the evaluator "
           "(AutoHotkey wraps it around: 9223372036854775808 is -9223372036854775808). Model: the literal with `.0`.",
    "missing": "A variable or Map key that does not exist gives the empty text, an f0 log entry and an entry in "
               "`missing` (AutoHotkey: UnsetError, UnsetItemError). It is not a warning. The value of the whole "
               "expression is not compared.",
}

# ------------------------------------------------------------------------------------------------ syntax tree

PREC = {"||": 2, "&&": 3, "=": 5, "==": 5, "!=": 5, "!==": 5, "<": 6, ">": 6, "<=": 6, ">=": 6, ".": 7,
        "+": 8, "-": 8, "*": 9, "/": 9, "//": 9}
PREC_NOT, PREC_UNARY, PREC_ATOM, PREC_ASSIGN = 4, 10, 11, 1


class Node:
    def __init__(self, kind, **kw):
        self.kind = kind
        self.__dict__.update(kw)

    def prec(self):
        k = self.kind
        if k == "bin":
            return PREC[self.op]
        if k == "un":
            return PREC_NOT if self.op == "not" else PREC_UNARY
        if k == "asg":
            return PREC_ASSIGN
        return PREC_ATOM


def render(n, model=False):
    """The text of a tree. model=True applies the deviations (E29 and literal beyond 63 bits) as native code."""
    k = n.kind
    if k == "lit":
        if model and n.big:
            return n.text + ".0"
        return n.text
    if k == "var":
        return n.name
    if k == "paren":
        return "(" + render(n.x, model) + ")"
    if k == "idx":
        return n.name + '["' + n.key + '"]'
    if k == "call":
        return n.name + "(" + ", ".join(render(a, model) for a in n.args) + ")"
    if k == "un":
        inner = render(n.x, model)
        if n.x.prec() < n.prec():
            inner = "(" + inner + ")"
        if n.op == "not":
            return "not " + inner
        if inner.startswith("-") or inner.startswith("!"):
            return n.op + " " + inner           # `- -5`, never `--5`
        return n.op + inner
    if k == "bin":
        p = n.prec()
        left, right = render(n.l, model), render(n.r, model)
        if n.l.prec() < p:
            left = "(" + left + ")"
        if n.r.prec() <= p:
            right = "(" + right + ")"
        if model and n.op == "/":
            return "D(%s, %s)" % (left, right)
        return "%s %s %s" % (left, n.op, right)
    if k == "asg":
        inner = render(n.x, model)
        if model and n.op == "/=":
            return "%s := D(%s, %s)" % (n.name, n.name, inner)
        return "%s %s %s" % (n.name, n.op, inner)
    raise ValueError(k)


def walk(n):
    yield n
    for attr in ("x", "l", "r"):
        child = getattr(n, attr, None)
        if isinstance(child, Node):
            yield from walk(child)
    for a in getattr(n, "args", []):
        yield from walk(a)


def has_divide(n):
    return any((m.kind == "bin" and m.op == "/") or (m.kind == "asg" and m.op == "/=") for m in walk(n))


def has_big_literal(n):
    return any(m.kind == "lit" and m.big for m in walk(n))


def uses_big(n):
    """An operand near the limits of Integer: `//` and mod() would be able to end the AutoHotkey process
    (MinInt // -1), so they are not combined with it."""
    for m in walk(n):
        if m.kind == "var" and m.name in BIG_VARS:
            return True
        if m.kind == "lit" and m.value_abs >= 2 ** 30:
            return True
    return False


def has_unsafe_divide(n):
    return any((m.kind == "bin" and m.op == "//") or (m.kind == "asg" and m.op == "//=")
               or (m.kind == "call" and m.name == "Mod") for m in walk(n))


# ------------------------------------------------------------------------------------------------ generator

NUM_LITERALS = [("0", 0), ("1", 1), ("2", 2), ("7", 7), ("10", 10), ("100", 100), ("0x10", 16), ("0xFF", 255),
                ("007", 7), ("1e3", 1000), ("1.5e-3", 0), ("3.14", 3), ("0.5", 0), ("2.0", 2), ("1.0", 1),
                ("123456789", 123456789), ("2147483648", 2 ** 31), ("4294967296", 2 ** 32),
                ("9223372036854775807", 2 ** 63), ("0x7FFFFFFFFFFFFFFF", 2 ** 63), ("1e308", 0), ("0.1", 0),
                ("0.2", 0)]
BIG_LITERALS = ["9223372036854775808", "12345678901234567890", "99999999999999999999"]
STR_LITERALS = ['""', '"abc"', '"a"', '"B"', '"5"', '" 5 "', '"1.0"', '"0x10"', '"1e3"', '"x y"', '"10"', '"9"',
                "'single'"]
BINOPS = ["+", "-", "*", "/", "//", ".", "=", "==", "!=", "!==", "<", ">", "<=", ">=", "&&", "||"]
BINOP_WEIGHTS = [10, 8, 8, 7, 4, 8, 5, 4, 4, 3, 5, 4, 3, 3, 4, 4]
ARITH = {"+", "-", "*", "/", "//"}
ASSIGN_OPS = [":=", "+=", "-=", "*=", "/=", "//=", ".="]


class Gen:
    def __init__(self, seed):
        self.rnd = random.Random(seed)

    def pick_var(self, kind):
        r = self.rnd
        if kind == "num":
            roll = r.random()
            if roll < 0.80:
                return r.choice(NUMERIC_VARS)
            if roll < 0.90:
                return r.choice(EDGE_VARS)
            return r.choice(TEXT_VARS + ["m"])
        roll = r.random()
        if roll < 0.55:
            return r.choice([v for v in NUMERIC_VARS if v not in RANGE_VARS])
        if roll < 0.65:
            return r.choice(EDGE_VARS)
        if roll < 0.95:
            return r.choice(TEXT_VARS)
        return "m"

    def literal(self, strings_allowed):
        r = self.rnd
        roll = r.random()
        if roll < 0.04:
            return Node("lit", text="true" if r.random() < 0.5 else "false", big=False, value_abs=1)
        if roll < 0.08:
            return Node("lit", text=r.choice(BIG_LITERALS), big=True, value_abs=2 ** 64)
        if strings_allowed and roll < 0.40:
            return Node("lit", text=r.choice(STR_LITERALS), big=False, value_abs=0)
        text, mag = r.choice(NUM_LITERALS)
        return Node("lit", text=text, big=False, value_abs=mag)

    def operand(self, depth, kind):
        """kind: "num" (an arithmetic operand: no string literal, AutoHotkey refuses `"a" + 1` at load time) or "any"."""
        r = self.rnd
        if depth <= 0 or r.random() < 0.35:
            roll = r.random()
            if roll < 0.45:
                return Node("var", name=self.pick_var(kind))
            if roll < 0.50 and kind == "any":
                return Node("var", name=MISSING_VAR)
            if roll < 0.57:
                return Node("idx", name="m", key=r.choice(KEYS))
            return self.literal(kind == "any")
        return self.expr(depth - 1, kind)

    def expr(self, depth, kind="any"):
        r = self.rnd
        roll = r.random()
        if roll < 0.12:
            op = r.choice(["-", "!", "not", "!"])
            sub = self.operand(depth - 1, "num" if (op == "-" or kind == "num") else "any")   # `!"a" * 2` is a load error
            return Node("un", op=op, x=sub)
        if roll < 0.20:
            name = r.choice(["Round", "Round", "Mod"])
            if name == "Round":
                args = [self.operand(depth - 1, "num")]
                if r.random() < 0.4:
                    args.append(Node("lit", text=r.choice(["0", "1", "2", "-1", "-2", "3"]), big=False, value_abs=3))
            else:
                args = [self.operand(depth - 1, "num"), self.operand(depth - 1, "num")]
            return Node("call", name=name, args=args)
        if roll < 0.23:
            return Node("paren", x=self.expr(depth - 1, kind))
        op = r.choices(BINOPS, BINOP_WEIGHTS)[0]
        sub_kind = "num" if op in ARITH else "any"
        left = self.operand(depth - 1, sub_kind)
        right = self.operand(depth - 1, sub_kind)
        return Node("bin", op=op, l=left, r=right)

    def top(self):
        r = self.rnd
        depth = r.choice([1, 2, 2, 3, 3, 4])
        roll = r.random()
        if roll < 0.10:
            op = r.choice(ASSIGN_OPS)
            target = r.choice(list(NUMERIC_VARS) + ["w1", "w2", "w3"])
            if op != ":=" and target in ("sabc",):
                target = "w1"
            return Node("asg", op=op, name=target, x=self.operand(depth - 1, "any" if op in (":=", ".=") else "num"))
        if roll < 0.14:
            # an assignment inside an expression: the target is a variable that nothing else reads
            inner = Node("asg", op=r.choice(ASSIGN_OPS), name=r.choice(NESTED_TARGETS),
                         x=self.operand(depth - 1, "num"))
            other = self.operand(depth - 1, "num")
            if r.random() < 0.5:
                return Node("bin", op=r.choice(["+", ".", "*", "-"]), l=Node("paren", x=inner), r=other)
            return Node("bin", op=r.choice(["+", ".", "-"]), l=other, r=Node("paren", x=inner))
        return self.expr(depth)

    def case(self):
        """A tree that is safe to run natively (see uses_big) and its texts."""
        while True:
            tree = self.top()
            if uses_big(tree) and has_unsafe_divide(tree):
                continue
            return tree


def case_of(tree):
    text = render(tree)
    rules = []
    if has_divide(tree):
        rules.append("E29")
    if has_big_literal(tree):
        rules.append("literal beyond 63 bits")
    out = {"t": text}
    if rules:
        model = render(tree, model=True)
        if model != text:
            out["m"] = model
            out["r"] = rules
    return out


def generate(seed, count):
    g = Gen(seed)
    seen, cases = set(), []
    guard = 0
    while len(cases) < count and guard < count * 20:
        guard += 1
        c = case_of(g.case())
        if c["t"] in seen:
            continue
        seen.add(c["t"])
        cases.append(c)
    return cases


# Hand-written cases: every deviation class, edge values, the forms the generator does not reach.
HAND = [
    # numbers and literals
    "0x10 + 0", "1e3", "1e3 + 0", "-0", "-0.0", "- -5", "5 - -3", "007 + 1", "0xFF * 2", "0.5 + 0.5",
    "9223372036854775807 + 1", "imax + 1", "imin - 1", "-imin", "imax * 2", "ibig * ibig", "imin * -1",
    "9223372036854775807", "0x7FFFFFFFFFFFFFFF", "1e308 * 10", "fhuge * fhuge", "-fhuge * fhuge", "ftiny * ftiny",
    "0.1 + 0.2", "1 / 3", "2 / 3", "10 / 4", "0.1 * 3",
    # literal beyond 63 bits
    "9223372036854775808", "12345678901234567890", "12345678901234567890 + 1", "-9223372036854775809",
    "99999999999999999999 . \"\"", "12345678901234567890 = 12345678901234567890.0",
    # E29
    "4 / 2", "-8 / -2", "7 / 2", "i16 / i2", "i7 / i2", "sint / sone", "sflt / f05", "i16 / i2 . \"\"", "imin / -1", "imax / imax", "i0 / i7", "i16 / ineg", "(i16 / i2) / i2", "i16 / i2 * i2",
    "sdot / sone", "f3 / i3", "shex / i2", "i3 / i3 + 0.5",
    # E25
    "sempty + 1", "1 + sempty", "sabc + 1", "1 - sabc", "sabc * 2", "-sempty", "-sabc", "m + 1", "m . \"x\"",
    "i1 / i0", "i1 // i0", "i1 / fz", "i7 // f3", "f15 // i1", "Mod(i1, i0)", "Mod(7, 0.0)", "Round(sabc)",
    "Round(m)", "sabc < i1", "sabc < shello", "shello > supper", "\"a\" < \"B\"", "sempty < i1",
    "smix + 1", "1 + 4 / i0", "sint + sabc . \"x\"", "sabc + 1 . \"x\"", "(sabc + 1) . \"x\"",
    "!sabc", "not sempty", "sabc && i1", "sempty || sabc", "i0 && sabc + 1", "i1 || sabc + 1",
    # missing
    "nothere", "nothere . \"x\"", "nothere + 1", "m[\"zz\"]", "m[\"zz\"] . \"x\"", "m[\"k\"]", "m[\"K\"]",
    "m[\"k\"] + 1", "m[\"s\"] . m[\"f\"]",
    # text and number comparisons
    "sdot = sone", "sdot == sone", "sint = 5", "sint == 5", "ssp = 5", "supper = shello", "sabc = \"ABC\"",
    "sabc == \"ABC\"", "i1 = 1.0", "i1 == 1.0", "szero = 0", "szero == 0", "sint < sneg", "\"10\" < \"9\"",
    "i1 != sone", "i1 !== sone", "sempty = 0", "fnz = fz", "fnz == fz", "imax = imax + 0", "f15 != 1.5",
    # logic returns the operand
    "sabc || 0", "0 && sabc", "sabc && \"x\"", "i0 || sempty || i2", "i1 && i2 && i3", "false || false",
    "not 1 = 2", "!1 = 2", "not i0 && not i0", "!(i1 && i0)", "true + true", "true . false", "not not sabc",
    # precedence and concatenation
    "1 + 2 * 3", "(1 + 2) * 3", "10 - 4 - 3", "2 * 3 + 4 * 5", "\"a\" . 1 + 2", "1 + 2 . \"a\"", "1 . 2 . 3",
    "i1 . i2 + i3", "i1 < i2 . i3", "i1 + i2 = i3", "i1 < 2 < 3", "3 > 2 > 1", "i1 = i1 = i1", "i1 < i2 = 1",
    "i1 && i0 || i2", "i1 || i0 && i0", "i2 * -i3", "-i2 * i3", "!i0 + 1", "- i2 + 3", "-(i2 + 3)",
    # assignments
    "i1 := 5", "i1 += 2", "i1 -= 5", "i2 *= 3", "i7 /= 2", "i16 /= 2", "i7 //= 2", "w1 := 1",
    "sabc .= \"x\"", "sempty .= 5", "sint += 1", "sabc += 1", "w1 := w2 := 3", "(w1 := 3) + 1", "1 + (w1 := 3)",
    "w1 := i1 + 1", "w3 := sabc . i1", "i1 := sabc + 1", "i1 += sempty", "w1 += 1 + (w2 := 2)",
    "i2 := i2 + i2", "imax += 1", "ineg //= 2", "fneg //= 1",
    # functions
    "Round(2.5)", "Round(-2.5)", "Round(2.567, 2)", "Round(1234, -2)", "Round(sflt)", "Round(sint, 1)", "Round(i7 / 2)",
    "Round(0.5)", "Round(1.5)", "Round(fhuge)", "Mod(7, 3)", "Mod(-7, 3)", "Mod(7, -3)", "Mod(7.5, 2)", "Mod(sint, 2)",
    "Round(4 / 2)", "Mod(16 / 2, 3)", "Round(i7)",
    # double and mixed
    "sexp + 0", "shex + 0", "ssp + 0", "sneg + 0", "-sint", "-sflt", "- -sint", "sint * sint", "sflt * 2",
    "shex . \"\"", "sint . sneg", "i7 // i2", "ineg // i2", "i7 // ineg", "fneg + f15",
]


def hand_cases():
    out, seen = [], set()
    for text in HAND:
        if text in seen:
            continue
        seen.add(text)
        out.append(text)
    return out


# ------------------------------------------------------------------------------------------------ native side

def ahk_string(s):
    out = []
    for ch in s:
        if ch == "`":
            out.append("``")
        elif ch == '"':
            out.append('`"')
        elif ch == "\n":
            out.append("`n")
        elif ch == "\r":
            out.append("`r")
        elif ch == "\t":
            out.append("`t")
        elif ch == ";":
            out.append("`;")
        elif ch == "%":
            out.append("`%")
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def ahk_value(v):
    t, x = v
    if t == "int":
        return "(-9223372036854775807 - 1)" if int(x) == MIN_INT else x
    if t == "float":
        return 'Float("%s")' % x
    if t == "str":
        return ahk_string(x)
    if t == "map":
        items = ", ".join("%s, %s" % (ahk_string(k), ahk_value(i)) for k, i in x.items())
        return "NewMap(%s)" % items
    raise ValueError(t)


NATIVE_PROLOGUE = r'''#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, Off
; Generated by tools/expr_oracle.py: the native side of the expression oracle. Do not edit.
NewMap(pairs*) {
    m := Map()
    m.CaseSense := "Off"
    loop pairs.Length // 2
        m[pairs[2 * A_Index - 1]] := pairs[2 * A_Index]
    return m
}

; E29: `/` of two integers that divide exactly gives an Integer, otherwise AutoHotkey's `/`.
D(a, b) {
    r := a / b
    if (r is Float && IsInteger(a) && IsInteger(b)) {
        ia := Integer(a)
        ib := Integer(b)
        if (ib = -1) {
            if (ia != (-9223372036854775807 - 1))
                return -ia
        } else if (Mod(ia, ib) = 0) {
            return ia // ib
        }
    }
    return r
}

Esc(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    return s
}

Main() {
    env := [%ENV%]
    lines := ""
    for entry in %CASES% {
        id := entry[1], fn := entry[2]
        try {
            v := fn(env*)
            lines .= id "`tok`t" Type(v) "`t" Esc(IsObject(v) ? "" : String(v)) "`n"
        } catch as e {
            lines .= id "`terr`t" Type(e) "`t" Esc(e.Message) "`n"
        }
    }
    FileAppend(lines, A_Args[1], "UTF-8-RAW")
    ExitApp(0)
}

Main()
'''


def native_script(entries):
    """entries: list of (id, expression text). Returns the text of the script."""
    names = list(ENV)
    params = ", ".join(names)
    funcs, refs = [], []
    for i, (cid, text) in enumerate(entries):
        funcs.append("F%d(%s) {\n    return (%s)\n}\n" % (i, params, text))
        refs.append('["%s", F%d]' % (cid, i))
    head = NATIVE_PROLOGUE.replace("%ENV%", ", ".join(ahk_value(ENV[n]) for n in names)) \
        .replace("%CASES%", "[" + ",\n        ".join(refs) + "]")
    return head + "\n" + "\n".join(funcs)


def unescape(s):
    return re.sub(r"\\(.)", lambda m: {"t": "\t", "n": "\n", "r": "\r"}.get(m.group(1), m.group(1)), s)


class NativeFailure(Exception):
    pass


def run_native_batch(entries, workdir, timeout=120):
    """Runs the entries natively. Returns {id: record}. Raises NativeFailure if the script does not load or the
    process ends without a result (for instance MinInt // -1, which ends AutoHotkey)."""
    script = os.path.join(workdir, "native.ahk")
    out = os.path.join(workdir, "native_out.txt")
    with open(script, "w", encoding="utf-8-sig") as f:
        f.write(native_script(entries))
    if os.path.exists(out):
        os.remove(out)
    code, stdout, stderr, dialogs = ahkrun.run(script, [out], timeout=timeout)
    if code != 0 or not os.path.exists(out):
        raise NativeFailure("exit code %s\n%s\n%s\n%s" % (code, stderr.strip()[:2000], stdout.strip()[:500], dialogs))
    result = {}
    with open(out, encoding="utf-8") as f:
        for line in f.read().split("\n"):
            if not line:
                continue
            cid, status, a, b = line.split("\t")
            if status == "ok":
                result[cid] = {"ok": True, "type": a, "text": unescape(b)}
            else:
                result[cid] = {"ok": False, "class": a, "message": unescape(b)}
    if len(result) != len(entries):
        raise NativeFailure("%d results for %d cases" % (len(result), len(entries)))
    return result


def run_native(entries, workdir):
    """Batches, and bisection when a batch fails: the case that ends the process is reported as a native crash."""
    result = {}
    for start in range(0, len(entries), BATCH):
        part = entries[start:start + BATCH]
        result.update(_run_native_safe(part, workdir))
    return result


def _run_native_safe(part, workdir):
    try:
        return run_native_batch(part, workdir)
    except NativeFailure as e:
        if len(part) == 1:
            return {part[0][0]: {"ok": False, "class": "NativeCrash", "message": str(e), "crash": True}}
        mid = len(part) // 2
        res = {}
        res.update(_run_native_safe(part[:mid], workdir))
        res.update(_run_native_safe(part[mid:], workdir))
        return res


# ------------------------------------------------------------------------------------------------ evaluator side

def run_evaluator(texts_by_id, workdir, timeout=120):
    """texts_by_id: list of (id, text). Returns {id: record}."""
    inp = os.path.join(workdir, "eval_in.json")
    out = os.path.join(workdir, "eval_out.jsonl")
    env = {}
    for name, v in ENV.items():
        env[name] = typed_json(v)
    with open(inp, "w", encoding="utf-8") as f:
        json.dump({"env": env, "cases": [{"id": i, "text": t} for i, t in texts_by_id]}, f)
    if os.path.exists(out):
        os.remove(out)
    code, stdout, stderr, dialogs = ahkrun.run(HARNESS, [out, inp], timeout=timeout)
    if code != 0 or not os.path.exists(out):
        raise RuntimeError("evaluator harness failed: exit code %s\n%s\n%s\n%s" % (code, stderr, stdout, dialogs))
    result = {}
    with open(out, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                rec = json.loads(line)
                result[rec["id"]] = rec
    return result


def typed_json(v):
    t, x = v
    if t == "map":
        return ["map", {k: typed_json(i) for k, i in x.items()}]
    return [t, x]


# ------------------------------------------------------------------------------------------------ comparison

def same_value(native, ev):
    return native["ok"] and not ev["errors"] and not ev["warnings"] and native["type"] == ev["type"] \
        and native["text"] == ev["text"]


def message_matches(native, ev):
    """The first warning of the evaluator carries the message of AutoHotkey ("'+' failed: <message>")."""
    return bool(ev["warnings"]) and not ev["errors"] and ev["warnings"][0].endswith(": " + native["message"])


def classify(case, raw, model, ev):
    """Returns (verdict, detail). verdict is "same", a class of CLASSES, or "OPEN" (a deviation without an entry)."""
    if ev.get("harness_failure"):
        return "OPEN", "harness failure: " + ev["harness_failure"]
    if raw.get("crash"):
        return "OPEN", "native crash: " + raw["message"][:200]
    if raw["ok"] and same_value(raw, ev):
        return "same", ""
    if not raw["ok"]:
        if raw["class"] in ("UnsetError", "UnsetItemError"):
            if ev["missing"] and not ev["errors"]:
                return "missing", ""
        elif message_matches(raw, ev):
            return "E25", raw["class"]
    if model is not None:
        if model["ok"] and same_value(model, ev):
            return " + ".join(case["r"]), ""
        if not model["ok"]:
            if model["class"] in ("UnsetError", "UnsetItemError") and ev["missing"] and not ev["errors"]:
                return "missing", ""
            if message_matches(model, ev):
                return "E25", model["class"]
    return "OPEN", "native: %s | model: %s | evaluator: %s" % (describe(raw), describe(model) if model else "-",
                                                                describe_ev(ev))


def describe(r):
    if r["ok"]:
        return "%s %r" % (r["type"], r["text"])
    return "%s %r" % (r["class"], r["message"][:80])


def describe_ev(ev):
    s = "%s %r" % (ev["type"], ev["text"])
    if ev["errors"]:
        s += " errors=%r" % ev["errors"]
    if ev["warnings"]:
        s += " warnings=%r" % ev["warnings"]
    if ev["missing"]:
        s += " missing=%r" % ev["missing"]
    return s


def run_cases(cases):
    """cases: list of {"t", "m"?, "r"?}. Returns a list of rows {"id", "text", "verdict", "detail", "native"...}."""
    with tempfile.TemporaryDirectory(prefix="ahf_oracle_") as workdir:
        entries = [("c%d" % i, c["t"]) for i, c in enumerate(cases)]
        models = [("m%d" % i, c["m"]) for i, c in enumerate(cases) if "m" in c]
        native = run_native(entries + models, workdir)
        ev = {}
        for start in range(0, len(entries), BATCH):
            ev.update(run_evaluator(entries[start:start + BATCH], workdir))
    rows = []
    for i, c in enumerate(cases):
        raw = native["c%d" % i]
        model = native.get("m%d" % i)
        verdict, detail = classify(c, raw, model, ev["c%d" % i])
        rows.append({"id": "c%d" % i, "text": c["t"], "model": c.get("m"), "verdict": verdict, "detail": detail,
                     "native": raw, "evaluator": ev["c%d" % i]})
    return rows


def summary(rows):
    counts = {}
    for r in rows:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    return counts


# ------------------------------------------------------------------------------------------------ corpus

def read_corpus(path=CORPUS):
    cases = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                cases.append(json.loads(line))
    return cases


def write_corpus(cases, path=CORPUS):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        for c in cases:
            f.write(json.dumps(c, ensure_ascii=False) + "\n")


def hand_cases_full():
    """The hand-written texts as corpus cases (the model is made by the same rules as for generated cases: the
    model of a hand-written text is made by replacing the deviations textually, see model_of_text)."""
    return [case_of_text(t) for t in hand_cases()]


def case_of_text(text):
    """A hand-written case: the text is parsed (parse_text) and the model is made from the tree, as for a generated case."""
    tree = parse_text(text)
    squeeze = lambda t: re.sub(r"\s+", "", t)
    if squeeze(render(tree)) != squeeze(text):
        raise ValueError("the parser of the oracle does not read %r as written (it renders %r)" % (text, render(tree)))
    out = case_of(tree)
    out["t"] = text
    return out


TOKEN = re.compile(r"""\s*(?:(?P<num>0[xX][0-9A-Fa-f]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)
    |(?P<str>"[^"]*"|'[^']*')|(?P<name>[A-Za-z_]\w*)|(?P<op>:=|\+=|-=|\*=|/=|//=|\.=|!==|!=|==|<=|>=|&&|\|\||//|[-+*/.=<>!(),\[\]]))""",
                   re.X)


def tokenize(text):
    pos, out = 0, []
    while pos < len(text):
        if not text[pos:].strip():
            break
        m = TOKEN.match(text, pos)
        if not m:
            raise ValueError("cannot read %r at %d" % (text, pos))
        out.append((m.lastgroup, m.group(m.lastgroup)))
        pos = m.end()
    return out


def parse_text(text):
    """A small parser for the hand-written cases: the subset of the language that the generator writes."""
    toks = tokenize(text)
    pos = [0]

    def peek():
        return toks[pos[0]] if pos[0] < len(toks) else (None, None)

    def take():
        t = peek()
        pos[0] += 1
        return t

    def is_op(v):
        k, x = peek()
        return k == "op" and x == v or (k == "name" and x.lower() == v and v in ("and", "or", "not"))

    def assign():
        left = binary(2)
        k, x = peek()
        if k == "op" and x in (":=", "+=", "-=", "*=", "/=", "//=", ".="):
            take()
            if left.kind != "var":
                raise ValueError("assignment target in %r" % text)
            return Node("asg", op=x, name=left.name, x=assign())
        return left

    def binary(level):
        # levels: 2 ||, 3 &&, 4 not, 5 =, 6 <, 7 ., 8 + -, 9 * / //
        if level == 4:
            if is_op("not"):
                take()
                return Node("un", op="not", x=binary(4))
            return binary(5)
        if level > 9:
            return unary()
        left = binary(level + 1)
        while True:
            k, x = peek()
            if k == "op" and x in PREC and PREC[x] == level:
                take()
                left = Node("bin", op=x, l=left, r=binary(level + 1))
            else:
                return left

    def unary():
        k, x = peek()
        if k == "op" and x in ("-", "!"):
            take()
            return Node("un", op=x, x=unary())
        return primary()

    def primary():
        k, x = take()
        if k == "num":
            digits = re.fullmatch(r"\d+", x)
            big = bool(digits) and int(x) > 2 ** 63 - 1
            try:
                mag = abs(int(x, 0)) if re.fullmatch(r"0[xX][0-9a-fA-F]+", x) else (int(x) if digits else 0)
            except ValueError:
                mag = 0
            return Node("lit", text=x, big=big, value_abs=mag)
        if k == "str":
            return Node("lit", text=x, big=False, value_abs=0)
        if k == "op" and x == "(":
            e = assign()
            if take() != ("op", ")"):
                raise ValueError("missing ) in %r" % text)
            return Node("paren", x=e)
        if k == "name":
            if x in ("true", "false"):
                return Node("lit", text=x, big=False, value_abs=1)
            if is_op("("):
                take()
                args = []
                while not is_op(")"):
                    args.append(assign())
                    if is_op(","):
                        take()
                take()
                return Node("call", name=x[0].upper() + x[1:].lower(), args=args)
            if is_op("["):
                take()
                key = take()
                take()
                if toks[pos[0] - 1] != ("op", "]"):
                    raise ValueError("index in %r" % text)
                return Node("idx", name=x, key=key[1][1:-1])
            return Node("var", name=x)
        raise ValueError("unexpected %r in %r" % (x, text))

    tree = assign()
    if pos[0] != len(toks):
        raise ValueError("rest of %r not read" % text)
    return tree


# ------------------------------------------------------------------------------------------------ main

def print_open(rows, limit=30):
    bad = [r for r in rows if r["verdict"] == "OPEN"]
    for r in bad[:limit]:
        print("OPEN %s: %s\n     %s" % (r["id"], r["text"], r["detail"]))
    if len(bad) > limit:
        print("... and %d more" % (len(bad) - limit))
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--seed", type=int, help="random run with this seed")
    ap.add_argument("--count", type=int, default=0, help="number of generated cases (default 20000 with --seed)")
    ap.add_argument("--write-corpus", action="store_true", help="regenerate tests/oracle/corpus.jsonl")
    ap.add_argument("--show", metavar="TEXT", help="run one expression on both sides")
    ap.add_argument("--classes", action="store_true", help="print the list of deliberate deviations")
    args = ap.parse_args()
    if args.classes:
        for name, text in CLASSES.items():
            print("%s: %s\n" % (name, text))
        return 0
    if args.show:
        rows = run_cases([case_of_text(args.show)])
        r = rows[0]
        print("verdict: %s %s\nnative:    %s\nevaluator: %s" % (r["verdict"], r["detail"], describe(r["native"]),
                                                                 describe_ev(r["evaluator"])))
        return 0 if r["verdict"] != "OPEN" else 1
    if args.write_corpus:
        seed = args.seed if args.seed is not None else 1
        count = args.count or 3500
        cases = hand_cases_full()
        seen = {c["t"] for c in cases}
        for c in generate(seed, count):
            if c["t"] not in seen:
                cases.append(c)
                seen.add(c["t"])
        write_corpus(cases)
        print("wrote %d cases (seed %d) to %s" % (len(cases), seed, CORPUS))
        return 0
    if args.seed is not None:
        count = args.count or 20000
        cases = hand_cases_full() + generate(args.seed, count)
        label = "random run, seed %d, %d cases" % (args.seed, len(cases))
    else:
        cases = read_corpus()
        label = "fixed corpus, %d cases" % len(cases)
    rows = run_cases(cases)
    bad = print_open(rows)
    print("%s: %s" % (label, ", ".join("%s: %d" % kv for kv in sorted(summary(rows).items()))))
    if bad:
        print("FAILED: %d deviations without an entry%s" % (len(bad), "; reproduce with --seed %d --count %d"
              % (args.seed, count) if args.seed is not None else ""))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
