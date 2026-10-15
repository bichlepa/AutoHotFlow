"""Deviation classes of the comparison of v1 and v2: the new expression language (work item WI-0039) and the variable
model (WI-0040).

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
CLASSES = {
    "v1 error": ("accept", "v1 reports an error or hangs; nothing to reproduce (E0022)"),
    "number format": ("accept", "the same number in the text form of v2 (E0024, E0032)"),
    "unsupported syntax": ("unsupported", "% as modulo, ^=, %=, <> and \"a\"\"b\": reported, not converted"),
    "script result value": ("accept", "the value of a script is the value of its last statement (v1: unspecific)"),
    "assignment value": ("accept", "an assignment has a value in v2; in v1 it has none (the empty text)"),
    "assignment to a path": ("accept", "v1 cannot assign to a path (a.b := 1 only logs an error); v2 can"),
    "text comparison": ("accept", "comparison with a text that is not a number: false in v2, alphabetical in v1 (E0030, E0025)"),
    "operand as result": ("accept", "and/or return an operand in v2, 1 or 0 in v1; the same as a condition (E0031)"),
    "no short circuit": ("accept", "v1 evaluates both sides of and/or, v2 stops at the first that decides (E0031)"),
    "not": ("accept", "not and ! do not negate at the start of an expression in v1 (bug); v2 negates"),
    "number-like texts": ("accept", "v1 compares two texts that look like numbers as numbers, v2 as texts"),
    "escape sequence": ("accept", "v1 drops the backtick in a string, v2 reads the escape (E0022)"),
    "true and false": ("accept", "keywords with the values 1 and 0 in v2; ordinary (missing) variables in v1"),
    "keyword as name": ("accept", "if, else, and, or, not cannot be variable names in v2"),
    "integer overflow": ("accept", "v1 wraps integers at 64 bit; v2 continues with a float"),
    "integer division with float": ("accept", "// with a float operand is a type error in AutoHotkey v2 (E0025); v1 divided"),
    "number literal forms": ("accept", "v1 reads only digits (0x10 is 0, 1e3 is 1); v2 reads hexadecimal and exponent"),
    "v1 ignores text": ("accept", "v1 stops at a token it cannot use and ignores the rest (glued operators like *-, "
                                  "a stray ), unknown operators, a second line)"),
    "number literal spelling": ("rewrite", "v1 passes a number literal on as text (1.50, 007); v2 reads it as a number"),
    "concatenation dot": ("rewrite", "v1 reads \"a\".\"b\" as concatenation; v2 needs spaces around the dot"),
    "backtick": ("rewrite", "a backtick in front of a character that v2 does not know as an escape"),
    # variable model (WI-0040)
    "assignment refused": ("accept", "an assignment that v1 refuses with an f0 log (an A_ name, no permission) is an "
                                     "error of the expression in v2, with the same text"),
    "built-in value": ("accept", "A_PtrSize is 8 (64 bit only, E0004); A_LanguageName is the name of the language, "
                                 "v1 always gave the empty text"),
    "path into global or static": ("accept", "v1 cannot read a member of a global or static object (it looks for "
                                             "a file of that name); v2 can"),
    "object as text": ("accept", "an object in a concatenation is a type error in v2 (empty text and a warning, "
                                 "E0025); v1 used the empty text for the object"),
    "json text": ("accept", "the JSON text of an object (ConvertObjectToString) writes / without a backslash and a "
                            "float inside an object as a number; v1 wrote \\/ and a text"),
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


def classify_access(case, r1, r2):
    """The kinds of the variable model (WI-0040): replace, checkname, destination, varget, varset."""
    if r2["outcome"] != "ok":
        return "open", "; ".join(r2.get("errors", []))[:100]
    v1v = gc.v1_plain(r1.get("value"))
    v2v = gc.v2_plain(r2.get("value"))
    detail = "v1 %r, v2 %r" % (r1.get("value", {}).get("text", r1.get("value")), r2["value"].get("text", r2["value"]))
    if case["kind"] == "checkname":
        return ("same", "") if gc.text_of(v1v) == gc.text_of(v2v) else ("open", detail)
    if case["kind"] == "destination":
        # v1 returns the location as the caller spelled it ("Thread"), v2 in lower case
        return ("same", "") if gc.text_of(v1v).lower() == gc.text_of(v2v).lower() else ("open", detail)
    vars_same = same_vars(r1, r2)
    if gc.same_value(v1v, v2v) and vars_same:
        if gc.text_of(v1v) == gc.text_of(v2v) or not gc.numberish(v1v, v2v):
            return "same", ""
        return "number format", detail
    if vars_same and isinstance(v1v, str) and isinstance(v2v, str):
        if case["kind"] == "replace" and case.get("convertObjects") and same_json_text(v1v, v2v):
            return "json text", detail
        if numbers_in_text(v1v) == numbers_in_text(v2v):
            return "number format", detail
    if vars_same and SCOPE_PATH.search(case["text"]) and v1v == "":
        return "path into global or static", detail
    return "open", detail


SCOPE_PATH = re.compile(r"(?<![\w.])(global|static)_\w+(\.|\[)", re.I)
FLOAT_TEXT = re.compile(r"\d+\.\d+")


def numbers_in_text(text):
    """The text with every decimal number in one form (0.500000 and 0.5 are the same)."""
    return FLOAT_TEXT.sub(lambda m: repr(float(m.group(0))), text)


def same_json_text(a, b):
    """True if two JSON texts differ only in an escaped slash and in floats written as text or as number."""
    def norm(t):
        t = t.replace("\\/", "/")
        return re.sub(r'"(-?\d+\.\d+)"', r"\1", t)
    return numbers_in_text(norm(a)) == numbers_in_text(norm(b))


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
    if case.get("volatile"):
        # only the type of the v1 value is stored: the v2 value must exist (built-in variables)
        if r2["outcome"] == "ok" and not any(BUILTIN.match(m) for m in r2.get("missing", [])):
            return "same", ""
        return "open", "volatile value: %r" % (r2.get("errors") or r2.get("missing"),)
    if kind not in ("expression", "script"):
        return classify_access(case, r1, r2)
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

    # variable model (WI-0040)
    errs = " ".join(r2.get("errors", []))
    if v2err and "failed. No permission." in errs and vars_same:
        return "assignment refused", errs[:100]
    if re.fullmatch(r"\s*(a_ptrsize|a_languagename)\s*", text, re.I):
        return "built-in value", "v1 %r, v2 %r" % (r1["value"].get("text", ""), r2["value"]["text"])
    if SCOPE_PATH.search(bare) and not v2err and v1v == "" and not ASSIGN.search(bare):
        return "path into global or static", ""
    if has_object(case) and any(w.startswith("'.' failed") for w in r2.get("warnings", [])):
        return "object as text", ""
    if has_object(case) and re.search(r"\]\s*[\[.]", bare) and not v2err:
        return "v1 ignores text", "v1 reads only the first index of a chain"

    if kind == "script" and not v2err and vars_same:
        return "script result value", ""
    if LOGIC.search(bare) and not v2err and gc.same_value(v1v, v2v) and not vars_same:
        return "no short circuit", ""
    if ASSIGN.search(bare) and re.search(r"\(\s*[\w.]+\s*(:=|\+=|-=|\*=|/=|\.=)", bare):
        return "assignment value", "assignment inside an expression"
    if PATH_ASSIGN.search(bare):
        return "assignment to a path", ""
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
