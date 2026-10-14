"""Compares the golden data of v1 with the new expression language (work item WI-39, deviation catalog).

Usage:
    python tools/golden_compare.py [--plain] [--private] [--group NAME ...] [--list CLASS] [--unclassified]

For every case in tests/golden/cases the harness tests/golden/v2/harness.ahk (started through tools/ahkrun.py) runs
the v2 code with the variable model of the engine and the result is compared with the stored result of v1
(tests/golden/expected): expressions and scripts with the new evaluator, `replace` with the %var% substitution,
`checkname` and `destination` with the name rules, `varget` and `varset` with the variable access of elements
(WI-40). By default the text of an expression or script is converted first (V1ExprConverter); --plain evaluates the
unchanged text, which is the deviation catalog of doc/EXPRESSION-LANGUAGE.md section 15.

Every case gets a verdict: `same` or a deviation class (see CLASSES). A class has a handling: `accept` (the
difference is known and decided), `unsupported` (the converter reports the text, the owner decides) or `open`
(a deviation without a class: this is a failure of the check). The table of classes is printed; exit code 1 if any
case is `open`.

Variables are compared per scope (instance, thread, loop, global, static).
"""

import argparse
import json
import math
import os
import re
import sys
import tempfile
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import ahkrun  # noqa: E402

GOLDEN = os.path.join(ROOT, "tests", "golden")
HARNESS = os.path.join(GOLDEN, "v2", "harness.ahk")
PUBLIC = (os.path.join(GOLDEN, "cases"), os.path.join(GOLDEN, "expected"))
PRIVATE = (os.path.join(GOLDEN, "private", "cases"), os.path.join(GOLDEN, "private", "expected"))
KINDS = ("expression", "script", "replace", "checkname", "destination", "varget", "varset")
SCOPES = ("instance", "thread", "loop", "global", "static")


# ---------------------------------------------------------------------------------------------- loading

def load_cases(paths, groups=None):
    """Returns a list of (case, v1 result) for the compared kinds."""
    cases_dir, expected_dir = paths
    out = []
    for name in sorted(os.listdir(cases_dir)):
        if not name.endswith(".json"):
            continue
        group = name[:-5]
        if groups and group not in groups:
            continue
        with open(os.path.join(cases_dir, name), encoding="utf-8") as f:
            cases = json.load(f)["cases"]
        with open(os.path.join(expected_dir, name), encoding="utf-8") as f:
            results = json.load(f)["results"]
        for c in cases:
            if c["kind"] in KINDS and c["id"] in results:
                out.append((c, results[c["id"]]))
    return out


INT_KEY = re.compile(r"-?\d{1,18}")


def merge_keys(value):
    """Object keys ignore case (v1 and the new language): the first spelling stays, the last value wins. A key that
    looks like an integer is that integer ("01" and "1" are one key), as in v1 and in v2 (VarValues.NormKey). The
    order of the case file counts, so this is done here and not by the JSON parser of the harness (a Map)."""
    if isinstance(value, list):
        return [merge_keys(x) for x in value]
    if isinstance(value, dict):
        out, spelling = {}, {}
        for k, x in value.items():
            k = str(k)
            if INT_KEY.fullmatch(k):
                k = str(int(k))
            low = k.lower()
            out[spelling.setdefault(low, k)] = merge_keys(x)
        return out
    return value


def flat_vars(case):
    """The variables of all scopes in one table (used to see whether a case has an object)."""
    flat = {}
    for scope in SCOPES:
        for name, value in (case.get("vars") or {}).get(scope, {}).items():
            flat[name] = merge_keys(value)
    return flat


def scoped_vars(case):
    """The variables of a case per scope, keys of objects merged as both languages ignore their case."""
    out = {}
    for scope in SCOPES:
        entries = (case.get("vars") or {}).get(scope, {})
        if entries:
            out[scope] = {name: merge_keys(value) for name, value in entries.items()}
    return out


def run_harness(cases, mode, timeout=120):
    """Runs the harness and returns {id: v2 record}."""
    tmp = tempfile.mkdtemp(prefix="ahf_golden_v2_")
    try:
        src = os.path.join(tmp, "input.json")
        out = os.path.join(tmp, "result.jsonl")
        payload = []
        for c, _ in cases:
            item = {"id": c["id"], "kind": c["kind"], "text": c["text"], "vars": scoped_vars(c)}
            for key in ("common", "location", "value", "convertObjects"):
                if key in c:
                    item[key] = c[key]
            payload.append(item)
        with open(src, "w", encoding="utf-8") as f:
            json.dump(payload, f)
        rc, stdout, stderr, dialogs = ahkrun.run(HARNESS, [out, src, mode], timeout=timeout)
        if rc != 0 or not os.path.exists(out):
            raise RuntimeError("harness failed: exit %s\n%s\n%s\n%s" % (rc, stdout, stderr, [d.summary() for d in dialogs]))
        with open(out, encoding="utf-8") as f:
            return {r["id"]: r for r in map(json.loads, f.read().splitlines())}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------------------------------------- comparing

NUM_RE = re.compile(r"^\s*[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?\s*$")


def to_number(text):
    """The number a text stands for (decimal or hexadecimal), or None."""
    if isinstance(text, (int, float)) and not isinstance(text, bool):
        return text
    if not isinstance(text, str):
        return None
    t = text.strip()
    if re.fullmatch(r"[+-]?0[xX][0-9a-fA-F]+", t):
        return int(t, 16)
    if NUM_RE.match(t):
        try:
            return int(t) if re.fullmatch(r"[+-]?\d+", t) else float(t)
        except ValueError:
            return None
    return None


def v2_plain(v):
    """A v2 value from the harness as plain Python data."""
    if v is None:
        return None
    if v["type"] == "Map":
        return {k.lower(): v2_plain(x) for k, x in v["value"].items()}
    if v["type"] in ("Integer", "Float"):
        return to_number(v["text"])
    return v["text"]


def v1_plain(v):
    """A v1 value ({type, value, text}) as plain Python data. Objects: dicts with lower-case text keys."""
    if v is None:
        return None
    if v["type"] == "object":
        return obj_plain(v["value"])
    if v["type"] == "number":
        return v["value"]
    return v["value"]


def obj_plain(o):
    if isinstance(o, list):
        return {str(i + 1): obj_plain(x) for i, x in enumerate(o)}
    if isinstance(o, dict):
        return {str(k).lower(): obj_plain(x) for k, x in o.items()}
    return o


def text_of(x):
    if isinstance(x, float):
        return repr(x)
    return "" if x is None else str(x)


def same_value(a, b):
    """Equality up to the number format: 2 and 2.0 and "2.000000" are the same number."""
    if isinstance(a, dict) or isinstance(b, dict):
        if not (isinstance(a, dict) and isinstance(b, dict)) or a.keys() != b.keys():
            return False
        return all(same_value(a[k], b[k]) for k in a)
    if a == b:
        return True
    na, nb = to_number(a), to_number(b)
    if na is not None and nb is not None and isinstance(a, (int, float, str)) and isinstance(b, (int, float, str)):
        return na == nb or math.isclose(na, nb, rel_tol=1e-6, abs_tol=1e-6)
    return str(a) == str(b)


def numberish(a, b):
    na, nb = to_number(a), to_number(b)
    return na is not None and nb is not None


def vars_flat_v1(r1):
    """The variables after the run as {"scope:name": value} (names in lower case)."""
    out = {}
    for scope in SCOPES:
        for name, v in r1.get("variables", {}).get(scope, {}).items():
            out[scope + ":" + name.lower()] = v1_plain(v)
    return out


def vars_flat_v2(r2):
    out = {}
    for scope, entries in r2.get("vars", {}).items():
        for name, v in entries.items():
            out[scope + ":" + name.lower()] = v2_plain(v)
    return out


# ---------------------------------------------------------------------------------------------- classes

import golden_classes  # noqa: E402  (imports this module; used only after loading)


# ---------------------------------------------------------------------------------------------- main

def compare(paths=PUBLIC, mode="convert", groups=None):
    """Returns a list of dicts: id, text, verdict, detail, r1, r2, conv."""
    pairs = load_cases(paths, groups)
    results = run_harness(pairs, mode)
    rows = []
    for c, r1 in pairs:
        r2 = results[c["id"]]
        verdict, detail = golden_classes.classify(c, r1, r2)
        rows.append({"id": c["id"], "text": c["text"], "kind": c["kind"], "verdict": verdict, "detail": detail,
                     "r1": r1, "r2": r2, "conv": r2.get("conv")})
    return rows


def summary(rows):
    counts = {}
    for r in rows:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    return counts


# example case per class for the table (the first shortest case is taken when a class is not listed)
EXAMPLES = {
    "v1 error": "functions.round.half",
    "v1 ignores text": "arithmetic.mul.neg",
    "escape sequence": "strings.escape.n",
    "concatenation dot": "concat.dot.nospace",
    "number format": "arithmetic.add.float",
    "text comparison": "comparison.lt.text.upper",
    "backtick": "strings.escape.unknown",
    "number literal spelling": "numbers.trailing.zero",
}


def code(text):
    """A Markdown code span; control characters are written as escapes, a backtick gets a longer fence."""
    text = text.replace(chr(10), chr(92) + "n").replace(chr(13), chr(92) + "r").replace(chr(9), chr(92) + "t")
    text = text.replace("|", chr(92) + "|")
    if text == "":
        return "(empty)"
    fence = "``" if "`" in text else "`"
    pad = " " if text.startswith("`") or text.endswith("`") else ""
    return fence + pad + text + pad + fence


def show_v1(r):
    if r["r1"]["outcome"] != "ok":
        return "error: " + (r["detail"] or r["r1"]["outcome"])
    v = r["r1"]["value"]
    return code(v.get("text", "")) if v["type"] != "object" else "an object"


def show_v2(r):
    r2 = r["r2"]
    if r2["outcome"] != "ok":
        return "error: " + (r2["errors"][0] if r2["errors"] else "")
    v = r2["value"]
    return code(v["text"]) if v["type"] != "Map" else "an object"


def markdown(rows_plain, rows_conv=None):
    """The catalog as a Markdown table: class, number of cases (unchanged / converted text), example, v1, v2, handling."""
    conv_counts = summary(rows_conv) if rows_conv else {}
    plain_counts = summary(rows_plain)
    out = ["| Class | Cases | After conversion | Example | v1 | v2 | Handling |", "|---|---|---|---|---|---|---|"]
    for name in sorted(golden_classes.CLASSES, key=lambda n: (golden_classes.CLASSES[n][0], n)):
        handling, text = golden_classes.CLASSES[name]
        members = [r for r in rows_plain if r["verdict"] == name]
        if not members:
            continue
        ex = next((r for r in members if r["id"] == EXAMPLES.get(name)), None)
        if ex is None:
            simple = [r for r in members if chr(10) not in r["text"] and len(r["text"]) < 40] or members
            ex = min(simple, key=lambda r: len(r["text"]))
        out.append("| %s | %d | %s | %s | %s | %s | %s: %s |" % (
            name, plain_counts[name], conv_counts.get(name, 0) if rows_conv else "-",
            code(ex["text"]), show_v1(ex), show_v2(ex), handling, text.replace("|", chr(92) + "|")))
    return chr(10).join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--plain", action="store_true", help="evaluate the unchanged text (the deviation catalog)")
    ap.add_argument("--private", action="store_true", help="the private cases (counts only)")
    ap.add_argument("--group", action="append")
    ap.add_argument("--markdown", action="store_true", help="print the catalog as a table (runs both modes)")
    ap.add_argument("--list", metavar="CLASS", help="print the cases of a class (or `open`)")
    args = ap.parse_args(argv)
    if args.markdown:
        print(markdown(compare(PUBLIC, "plain", args.group), compare(PUBLIC, "convert", args.group)))
        return 0
    if args.private and not (os.path.isdir(PRIVATE[0]) and os.path.isdir(PRIVATE[1])):
        print("no private golden data: %s and %s are missing (see doc/TEST-STRATEGY.md section 7)" % PRIVATE)
        return 2
    rows = compare(PRIVATE if args.private else PUBLIC, "plain" if args.plain else "convert", args.group)
    counts = summary(rows)
    print("cases compared: %d" % len(rows))
    for verdict in sorted(counts, key=lambda v: (v != "same", v == "open", v)):
        handling = golden_classes.CLASSES.get(verdict, ("", ""))[0]
        print("  %-40s %5d  %s" % (verdict, counts[verdict], handling))
    converted = [r for r in rows if r["conv"]]
    if converted:
        stats = {}
        for r in converted:
            stats[r["conv"]["status"]] = stats.get(r["conv"]["status"], 0) + 1
        print("conversion: " + ", ".join("%s %d" % kv for kv in sorted(stats.items())))
        print("not idempotent: %d" % sum(1 for r in converted if not r["conv"]["idempotent"]))
    if args.list and not args.private:
        for r in rows:
            if r["verdict"] == args.list:
                print("%s\t%r\t%s" % (r["id"], r["text"], r["detail"]))
    return 1 if counts.get("open") else 0


if __name__ == "__main__":
    sys.exit(main())
