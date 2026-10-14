"""Deviation classes of the comparison of v1 and the new expression language (work item WI-39).

Used by tools/golden_compare.py. `classify(case, r1, r2)` gives the verdict of one golden case: `same`, the name
of a class from CLASSES, or `open` (a deviation without a class: a failure of the check).
"""

import re

import golden_compare as gc

# name -> (handling, description). Handling:
#   accept       the difference is known and decided (doc/MIGRATION.md has an entry), the converter does not rewrite
#   rewrite      the converter rewrites the text so that the result agrees; a verdict of this class in the converted
#                run is a defect of the converter
#   unsupported  syntax the converter reports and leaves unchanged; the owner has not decided (OPEN-ITEMS)
#   later        not part of the expression language (variable model WI-40, parameter evaluation WI-42): the case
#                is not compared here
CLASSES = {
    "v1 error": ("accept", "v1 reports an error or hangs; nothing to reproduce (E22)"),
    "number format": ("accept", "the same number in the text form of v2 (E24, E32)"),
    "built-in variable": ("later", "A_ names are provided by the variable model (WI-40)"),
    "scope prefix": ("later", "global_ and static_ names are provided by the variable model (WI-40, WI-41)"),
    "object model": ("later", "keys of objects (integer keys, order, copies) belong to the variable model (WI-40)"),
    "unsupported syntax": ("unsupported", "% as modulo, ^=, %=, <> and \"a\"\"b\": reported, not converted"),
    "script result value": ("accept", "the value of a script is the value of its last statement (v1: unspecific)"),
    "assignment value": ("accept", "an assignment has a value in v2; in v1 it has none (the empty text)"),
    "assignment to a path": ("accept", "v1 cannot assign to a path (a.b := 1 only logs an error); v2 can"),
    "text comparison": ("accept", "comparison with a text that is not a number: false in v2, alphabetical in v1 (E30, E25)"),
    "operand as result": ("accept", "and/or return an operand in v2, 1 or 0 in v1; the same as a condition (E31)"),
    "no short circuit": ("accept", "v1 evaluates both sides of and/or, v2 stops at the first that decides (E31)"),
    "not": ("accept", "not and ! do not negate at the start of an expression in v1 (bug); v2 negates"),
    "number-like texts": ("accept", "v1 compares two texts that look like numbers as numbers, v2 as texts"),
    "escape sequence": ("accept", "v1 drops the backtick in a string, v2 reads the escape (E22)"),
    "true and false": ("accept", "keywords with the values 1 and 0 in v2; ordinary (missing) variables in v1"),
    "keyword as name": ("accept", "if, else, and, or, not cannot be variable names in v2"),
    "integer overflow": ("accept", "v1 wraps integers at 64 bit; v2 continues with a float"),
    "integer division with float": ("accept", "// with a float operand is a type error in AutoHotkey v2 (E25); v1 divided"),
    "number literal forms": ("accept", "v1 reads only digits (0x10 is 0, 1e3 is 1); v2 reads hexadecimal and exponent"),
    "v1 ignores text": ("accept", "v1 stops at a token it cannot use and ignores the rest (glued operators like *-, "
                                  "a stray ), unknown operators, a second line)"),
    "number literal spelling": ("rewrite", "v1 passes a number literal on as text (1.50, 007); v2 reads it as a number"),
    "concatenation dot": ("rewrite", "v1 reads \"a\".\"b\" as concatenation; v2 needs spaces around the dot"),
    "backtick": ("rewrite", "a backtick in front of a character that v2 does not know as an escape"),
}

BUILTIN = re.compile(r"(?<![\w.])a_\w", re.I)
SCOPE = re.compile(r"(?<![\w.])(global|static)_\w", re.I)
ASSIGN = re.compile(r"(:=|\+=|-=|\*=|/=|\.=|//=)")
PATH_ASSIGN = re.compile(r"(?m)^[^\"'\n]*?[\w\]]\s*(\.\w|\[[^\]\n]*\])[^\"'\n]*?(:=|\+=|-=|\*=|/=|\.=)")
UNSUPPORTED = re.compile(r"\^=|%=|<>|(?<![\w%])%(?![\w%])|\s%\s|\d%\d|\w%\s*\d")
COMPARE = re.compile(r"<|>")
LOGIC = re.compile(r"\band\b|\bor\b|&&|\|\|", re.I)
NOT = re.compile(r"\bnot\b|!(?!=)", re.I)
KEYWORD_NAME = re.compile(r"^\s*(if|else|and|or|not)\s*$", re.I)
OVERFLOW = re.compile(r"\d{19,}")
LITERAL_FORMS = re.compile(r"\b0x[0-9a-f]+|\b\d+e[+-]?\d+|\d_\d|\d,\d|\d\.\s*$|\.\.|\b\d+[a-z_]", re.I)
SPELLING = re.compile(r"(?<![\w.])(0\d+|\d+\.\d*0|\d+\.)(?![\w.])")


def strip_strings(text):
    """The text without the contents of string literals (to look for operators and names)."""
    return re.sub(r'"[^"\n]*"', '""', text)


V1_OPERATORS = {":=", "+=", "-=", ".=", "/=", "*=", "||", "&&", "!", "<", ">", "<=", ">=", "=", "==", "!=", ".", "+",
                "-", "*", "/", "//", "%"}


def glued(text):
    """True if the text has a run of operator characters that v1 does not know as an operator (`*-`, `//=`, `<>`)."""
    for run in re.findall(r"[-+*/%=&|<>!:.]+", strip_strings(text)):
        if run not in V1_OPERATORS:
            return True
    return False


def truthy(v):
    if v is None or v == "":
        return False
    n = gc.to_number(v)
    return (n != 0) if n is not None else True


def has_object(case):
    return any(isinstance(v, (list, dict)) for v in gc.flat_vars(case).values())


def conv_status(conv):
    return conv["status"] if conv else ""


def same_vars(r1, r2):
    a = gc.vars_flat_v1(r1)
    b = gc.vars_flat_v2(r2)
    return a.keys() == b.keys() and all(gc.same_value(a[k], b[k]) for k in a)


def v1_error_detail(r1):
    if r1["outcome"] == "timeout":
        return "v1 hangs"
    if r1["outcome"] == "uncaught_error":
        return str(r1.get("detail", ""))[:80]
    errs = r1.get("errors") or []
    return errs[0]["description"][:80] if errs else r1["outcome"]


def classify(case, r1, r2):
    """Returns (verdict, detail). verdict: "same", a class name, or "open"."""
    text = case["text"]
    kind = case["kind"]
    bare = strip_strings(text)
    if r2["outcome"] == "harness_failure":
        return "open", "harness failure: " + r2.get("detail", "")
    conv = r2.get("conv")

    if r1["outcome"] in ("parse_error", "eval_error", "uncaught_error", "timeout", "parse_error_ignored"):
        return "v1 error", v1_error_detail(r1)
    if BUILTIN.search(text):
        return "built-in variable", ""
    v2err = r2["outcome"] != "ok"
    if UNSUPPORTED.search(bare) or (re.search(r'"[^"\n]*""', text) and v2err):
        if v2err or conv_status(conv) == "unsupported":
            return "unsupported syntax", "; ".join(r2.get("errors", []))[:100]

    v1v = gc.v1_plain(r1.get("value"))
    v2v = None if v2err else gc.v2_plain(r2.get("value"))
    vars_same = same_vars(r1, r2)
    if (not v2err) and gc.same_value(v1v, v2v) and vars_same:
        if gc.text_of(v1v) == gc.text_of(v2v) or not gc.numberish(v1v, v2v):
            return "same", ""
        detail = "v1 %r, v2 %r" % (r1["value"].get("text", ""), r2["value"]["text"])
        if r1["value"]["type"] == "text" and SPELLING.search(bare):
            return "number literal spelling", detail
        return "number format", detail

    if SCOPE.search(text):
        return "scope prefix", ""
    if kind == "script" and not v2err and vars_same:
        return "script result value", ""
    if LOGIC.search(bare) and not v2err and gc.same_value(v1v, v2v) and not vars_same:
        return "no short circuit", ""
    if ASSIGN.search(bare) and re.search(r"\(\s*[\w.]+\s*(:=|\+=|-=|\*=|/=|\.=)", bare):
        return "assignment value", "assignment inside an expression"
    if PATH_ASSIGN.search(bare):
        return "assignment to a path", ""
    if has_object(case):
        return "object model", ""
    if v2err:
        errs = " ".join(r2.get("errors", []))
        if "needs a space" in errs and not glued(text):
            return "concatenation dot", errs[:100]
        if KEYWORD_NAME.match(text):
            return "keyword as name", errs[:100]
        if "unknown escape" in errs:
            return "backtick", errs[:100]
        return "v1 ignores text", errs[:100]
    detail = "v1 %r, v2 %r" % (r1.get("value"), r2.get("value"))
    if ASSIGN.search(bare) and vars_same:
        return "assignment value", ""
    if re.search(r'(""|\))\.\S|\S\.""', bare) and not glued(text):
        return "concatenation dot", detail
    if "`" in text:
        return "escape sequence", detail
    if re.search(r"\b(true|false)\b", bare, re.I):
        return "true and false", ""
    if OVERFLOW.search(text):
        return "integer overflow", ""
    if "//" in text and r2.get("warnings"):
        return "integer division with float", ""
    if LITERAL_FORMS.search(text):
        return "number literal forms", ""
    if NOT.search(bare):
        return "not", ""
    num1 = r1["value"]["type"] == "number"
    if LOGIC.search(bare):
        if not vars_same:
            return "no short circuit", ""
        if v1v in (0, 1) and truthy(v2v) == bool(v1v):
            return "operand as result", ""
        if v1v in (0, 1) and v2v == "" and r2.get("warnings"):
            return "text comparison", ""
    if num1 and v1v in (0, 1) and v2v == "" and r2.get("warnings"):
        return "text comparison", ""
    if num1 and v1v in (0, 1) and v2v in (0, 1) and "=" in text:
        return "number-like texts", ""
    if glued(text) or re.search(r"[\"\w]\s+\(", bare) or kind == "script" or "\n" in text.strip():
        return "v1 ignores text", detail
    return "open", detail
