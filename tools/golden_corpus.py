"""Collects the golden cases for the parameter values of real v1 flows (work item WI-36, task 5).

FROZEN since E35 (2026-10-14): no new cases against v1 (see tools/golden_v1.py); the oracle of the expression language
is native AutoHotkey v2 (tools/expr_oracle.py).

Usage:
    python tools/golden_corpus.py [--flows DIR] [--out FILE] [--stats]
    python tools/golden_corpus.py --report [--expected FILE]

Default: the example flows in v1/AppData/Saved Flows -> tests/golden/cases/corpus_flows.json (checked in).
The project owner's own flows are processed the same way, but locally only:
    python tools/golden_corpus.py --flows <folder with Flow *.json> --out tests/golden/private/cases/corpus_private.json
(tests/golden/private/ is in .gitignore). Then run `python tools/golden_v1.py --private`.

How a parameter value becomes a case. The content type of a parameter comes from the v1 element files
(Element_getParametrizationDetails_*, entries with `content:`), found by the class name of the element:
  - String, file/folder parameters -> kind replace (substitution of %var%)
  - Expression, number, positiveNumber, integer, positiveInteger, positiveIntegerOrZero -> kind expression
  - VariableName -> kind replace, plus kind checkname when the value has no %
  - RawString, or no content at all -> nothing (v1 does not evaluate it)
  - content is a list (the user selects: contentID names the parameter that holds the choice, "String" or
    "Expression") -> the choice stored in the flow; if it is missing, both kinds
  - parameter or class not found in the element files -> both kinds (unclear)
Variables read by a value get initial values in three variants: "missing" (none), "num" (numbers 2, 3, 4 ...),
"txt" (text t1, t2 ...). A value without variables gets one case ("plain"). Variables with a path (a.b, a[1]) become
objects with the used keys. A_ names are loop variables unless they are built-in; global_ and static_ names go to
those scopes.
"""

import argparse
import collections
import glob
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
V1 = os.path.join(ROOT, "v1")
DEFAULT_FLOWS = os.path.join(V1, "AppData", "Saved Flows")
DEFAULT_OUT = os.path.join(ROOT, "tests", "golden", "cases", "corpus_flows.json")
DEFAULT_EXPECTED = os.path.join(ROOT, "tests", "golden", "expected", "corpus_flows.json")

EXPRESSION_CONTENT = {"expression", "number", "positivenumber", "integer", "positiveinteger", "positiveintegerorzero"}
KEYWORDS = {"and", "or", "not", "if", "else"}
# built-in variables whose value is the same on every run and machine; all other built-ins make the case volatile
STABLE_BUILTINS = {"a_space", "a_tab", "a_lf", "a_linefeed", "a_cr", "a_carriagereturn", "a_flowname", "a_flowid",
                   "a_elementname", "a_elementid", "a_ahfversion", "a_workingdir", "a_languagename", "a_ptrsize"}


# ---------------------------------------------------------------------------------------------------------
# the element files of v1
# ---------------------------------------------------------------------------------------------------------

def builtin_names():
    """Names of the built-in variables, from the two lists in v1/Source_Common/Variables/Global variables.ahk."""
    with open(os.path.join(V1, "Source_Common", "Variables", "Global variables.ahk"), encoding="utf-8-sig") as f:
        text = f.read()
    names = set()
    for match in re.finditer(r'global\s+global_All\w*BuiltInVars\s*:=\s*"([^"]*)"', text):
        names.update(n.lower() for n in match.group(1).split())
    return names


def _strings(blob):
    return re.findall(r'"([^"]*)"', blob)


def element_specs():
    """{lowercase element class: [spec, ...]} with spec = {ids, type, content (list), contentID}."""
    specs = {}
    for path in glob.glob(os.path.join(V1, "Source_Elements", "**", "*.ahk"), recursive=True):
        with open(path, encoding="utf-8-sig", errors="replace") as f:
            lines = f.read().splitlines()
        current = None
        for line in lines:
            header = re.match(r"\s*Element_getParametrizationDetails_(\w+)\s*\(", line)
            if header:
                current = header.group(1).lower()
                specs.setdefault(current, [])
                continue
            if re.match(r"\s*Element_\w+\s*\(", line):
                current = None
                continue
            if current is None or "parametersToEdit.push" not in line:
                continue
            body = line[line.index("parametersToEdit.push") :]
            kind = re.search(r'type:\s*"([^"]*)"', body)
            ident = re.search(r'(?<![A-Za-z])id:\s*("([^"]*)"|\[([^\]]*)\])', body)
            if not kind or not ident:
                continue
            content = re.search(r'content:\s*("([^"]*)"|\[([^\]]*)\])', body)
            content_id = re.search(r'contentID:\s*"([^"]*)"', body)
            ids = [ident.group(2)] if ident.group(2) is not None else _strings(ident.group(3))
            if content is None:
                contents = []
            else:
                contents = [content.group(2)] if content.group(2) is not None else _strings(content.group(3))
            specs[current].append({"ids": ids, "type": kind.group(1).lower(),
                                   "content": [c.lower() for c in contents],
                                   "contentID": content_id.group(1) if content_id else None})
    return specs


# ---------------------------------------------------------------------------------------------------------
# what a value is used for
# ---------------------------------------------------------------------------------------------------------

def decide_kinds(spec, pars, selector_ids):
    """Returns (kinds, reason): kinds is a subset of ("expression", "replace", "checkname")."""
    if spec is None:
        return ["expression", "replace"], "unclear"
    if spec["type"] in ("file", "folder"):
        return ["replace"], "file"
    contents = spec["content"]
    if not contents:
        return [], "no content"
    if len(contents) > 1 or spec["contentID"]:
        choice = pars.get(spec["contentID"]) if spec["contentID"] else None
        choice = str(choice).lower() if choice is not None else None
        if choice in contents:
            contents = [choice]
        else:
            contents = contents  # the choice is missing or not usable: both
    kinds = []
    for content in contents:
        if content == "string":
            kinds.append("replace")
        elif content in EXPRESSION_CONTENT:
            kinds.append("expression")
        elif content == "variablename":
            kinds += ["replace", "checkname"]
    return sorted(set(kinds)), "content"


def strip_strings(text):
    """Expression text without string literals and comments (rough)."""
    text = re.sub(r'"(?:[^"`]|`.)*"', '""', text)
    return re.sub(r"\s;.*", "", text)


def references(kind, text):
    """Variable references of a value: {root: set of keys used below it, or None if used plain}."""
    found = collections.OrderedDict()
    if kind == "replace":
        pieces = re.findall(r"%([^%\n]+)%", text)
    elif kind == "expression":
        pieces = [strip_strings(text)]
    else:
        return found
    for piece in pieces:
        for match in re.finditer(r"(?<![\w.])([A-Za-z_\u0080-￿][\w\u0080-￿]*)((?:\.[\w\u0080-￿]+|\[[^\]]*\])*)(\s*\()?", piece):
            name, path, call = match.group(1), match.group(2), match.group(3)
            if call and not path:
                continue
            if name.lower() in KEYWORDS and kind == "expression":
                continue
            keys = found.setdefault(name, set())
            for key in re.findall(r"\.([\w\u0080-￿]+)|\[([^\]]*)\]", path):
                piece_key = key[0] or key[1].strip().strip('"')
                keys.add(piece_key if re.fullmatch(r"[\w\u0080-￿]+", piece_key or "") else "1")
    return found


def scope_of(name, builtins):
    lower = name.lower()
    if lower.startswith("a_"):
        return "builtin" if lower in builtins else "loop"
    if lower.startswith("global_"):
        return "global"
    if lower.startswith("static_"):
        return "static"
    return "instance"


def variants(kind, text, builtins):
    """Returns [(variant name, vars, volatile)] for one value."""
    refs = references(kind, text)
    volatile = any(scope_of(n, builtins) == "builtin" and n.lower() not in STABLE_BUILTINS for n in refs)
    settable = {n: k for n, k in refs.items() if scope_of(n, builtins) != "builtin"}
    if not settable:
        return [("plain", {}, volatile)]
    out = [("missing", {}, volatile)]
    for variant in ("num", "txt"):
        values = {}
        for index, (name, keys) in enumerate(sorted(settable.items()), start=2):
            def leaf(i, suffix=""):
                return (index + i) if variant == "num" else "t%d%s" % (index + i, suffix)
            if keys:
                obj = {key: leaf(n) for n, key in enumerate(sorted(keys))}
                for n in (1, 2, 3):
                    obj.setdefault(str(n), leaf(n))
                values[name] = obj
            else:
                values[name] = leaf(0)
        scoped = {}
        for name, value in values.items():
            scoped.setdefault(scope_of(name, builtins), {})[name] = value
        out.append((variant, scoped, volatile))
    return out


# ---------------------------------------------------------------------------------------------------------
# flows
# ---------------------------------------------------------------------------------------------------------

def collect(flows_dir, specs, builtins):
    """Returns (cases, stats)."""
    by_key = collections.OrderedDict()
    stats = collections.Counter()
    unknown_classes = collections.Counter()
    for path in sorted(glob.glob(os.path.join(flows_dir, "Flow *.json"))):
        with open(path, encoding="utf-8-sig") as f:
            flow = json.load(f)
        flow_name = os.path.splitext(os.path.basename(path))[0]
        for element in flow.get("allElements", {}).values():
            pars = element.get("pars") or {}
            cls = str(element.get("class", ""))
            class_specs = specs.get(cls.lower())
            if class_specs is None:
                unknown_classes[cls] += 1
            selectors = {s["contentID"] for s in (class_specs or []) if s["contentID"]}
            for key, value in pars.items():
                if isinstance(value, (dict, list)) or value is None or isinstance(value, bool):
                    continue
                text = value if isinstance(value, str) else json.dumps(value)
                stats["parameters"] += 1
                if key in selectors:
                    continue
                spec = None
                for s in class_specs or []:
                    if key in s["ids"]:
                        spec = s
                        break
                if spec is not None and not isinstance(value, str) and spec["content"] == []:
                    continue
                kinds, reason = decide_kinds(spec, pars, selectors)
                if reason == "unclear" and not isinstance(value, str):
                    continue
                for kind in kinds:
                    if kind == "checkname" and "%" in text:
                        continue
                    stats["kind:" + kind] += 1
                    source = "%s/%s/%s (%s)" % (flow_name, element.get("ID", "?"), key, cls)
                    for variant, variables, volatile in variants(kind, text, builtins):
                        digest = hashlib.sha1(text.encode("utf-8")).hexdigest()[:8]
                        cid = "corpus.%s.%s.%s" % (kind, digest, variant)
                        entry = by_key.get(cid)
                        if entry is None:
                            case = {"id": cid, "kind": kind, "text": text}
                            if variables:
                                case["vars"] = variables
                            if volatile:
                                case["volatile"] = True
                            if reason == "unclear":
                                case["note"] = "content type unclear: run as expression and as substitution"
                            entry = by_key[cid] = (case, [])
                        elif entry[0]["text"] != text:
                            raise SystemExit("hash collision for %s" % cid)
                        entry[1].append(source)
    cases = []
    for case, sources in by_key.values():
        unique = sorted(set(sources))
        case["sources"] = unique[:6] + (["... and %d more" % (len(unique) - 6)] if len(unique) > 6 else [])
        cases.append(case)
    cases.sort(key=lambda c: (c["kind"], c["text"], c["id"]))
    stats["flows"] = len(glob.glob(os.path.join(flows_dir, "Flow *.json")))
    stats["cases"] = len(cases)
    for cls, count in unknown_classes.items():
        stats["unknown class: " + cls] = count
    return cases, stats


def write_cases(path, cases, group, description):
    lines = ["{", '"group": %s,' % json.dumps(group), '"description": %s,' % json.dumps(description), '"cases": [']
    for i, case in enumerate(cases):
        lines.append(json.dumps(case, ensure_ascii=True) + ("," if i + 1 < len(cases) else ""))
    lines += ["]", "}", ""]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


OPERATORS = [(":=", r":="), ("+=", r"\+="), ("-=", r"-="), ("*=", r"\*="), ("/=", r"/="), (".=", r"\.="),
             ("and", r"\band\b"), ("or", r"\bor\b"), ("not", r"\bnot\b"), ("&&", r"&&"), ("||", r"\|\|"),
             ("!=", r"!="), ("<=", r"<="), (">=", r">="), ("==", r"=="), ("=", r"(?<![:<>!=+\-*/.])=(?!=)"),
             ("<", r"<(?![=>])"), (">", r">(?!=)"), ("+", r"\+(?!=)"), ("-", r"-(?!=)"), ("*", r"\*(?!=)"),
             ("//", r"//"), ("/", r"/(?![/=])"), ("%", r"%"), ("[", r"\["), ("(", r"\("), ('"', r'"'), ("!", r"!(?!=)"),
             (", ", r",")]


def print_stats(cases, stats):
    print("flows: %d, parameters with a value: %d, cases: %d" % (stats["flows"], stats["parameters"], stats["cases"]))
    for key in sorted(stats):
        if key.startswith(("kind:", "unknown class")):
            print("  %-60s %d" % (key, stats[key]))
    seen = {}
    for case in cases:
        seen.setdefault((case["kind"], case["text"]), case)
    print("distinct values by kind:", dict(collections.Counter(k for k, _ in seen)))
    counter = collections.Counter()
    for (kind, text), _ in seen.items():
        if kind != "expression":
            continue
        plain = strip_strings(text)
        for name, pattern in OPERATORS:
            if re.search(pattern, plain):
                counter[name] += 1
    print("operators and patterns in the %d distinct expressions (a value counts once per operator):"
          % sum(1 for k, _ in seen if k == "expression"))
    for name, count in counter.most_common():
        print("  %-6s %d" % (name, count))
    percent = sum(1 for k, t in seen if k == "replace" and "%" in t)
    print("distinct substitution values with %%: %d of %d" % (percent, sum(1 for k, _ in seen if k == "replace")))


def report(expected_path):
    """What the v1 results of the corpus show: outcomes and the values that already fail in v1."""
    with open(expected_path, encoding="utf-8") as f:
        data = json.load(f)
    cases_path = expected_path.replace(os.sep + "expected" + os.sep, os.sep + "cases" + os.sep)
    with open(cases_path, encoding="utf-8") as f:
        cases = {c["id"]: c for c in json.load(f)["cases"]}
    outcomes = collections.Counter()
    failing = collections.OrderedDict()
    for cid, result in data["results"].items():
        outcomes[(result["kind"], result["outcome"])] += 1
        case = cases[cid]
        if result["outcome"] != "ok" and not case.get("volatile"):
            failing.setdefault((result["kind"], case["text"], result["outcome"]), []).append(cid)
        elif result["outcome"] == "ok" and result["kind"] == "expression" and result.get("errors"):
            failing.setdefault((result["kind"], case["text"], "errors"), []).append(cid)
    print("outcomes (kind, outcome): count")
    for key, count in sorted(outcomes.items()):
        print("  %-14s %-22s %d" % (key[0], key[1], count))
    print("values that fail in v1: %d" % len(failing))
    for (kind, text, outcome), ids in failing.items():
        print("  %-10s %-14s %r   (%d cases, e.g. %s)" % (kind, outcome, text[:100], len(ids), ids[0]))


def main(argv):
    parser = argparse.ArgumentParser(description="Collects golden cases from the parameter values of v1 flows.")
    parser.add_argument("--flows", default=DEFAULT_FLOWS)
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--stats", action="store_true", help="print statistics, write nothing")
    parser.add_argument("--report", action="store_true", help="print what the v1 results of the corpus show")
    parser.add_argument("--expected", default=DEFAULT_EXPECTED)
    args = parser.parse_args(argv)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")   # values contain Cyrillic text
    if args.report:
        report(args.expected)
        return 0
    specs = element_specs()
    cases, stats = collect(args.flows, specs, builtin_names())
    if args.stats:
        print_stats(cases, stats)
        return 0
    group = os.path.splitext(os.path.basename(args.out))[0]
    write_cases(args.out, cases, group, "parameter values of the flows in %s (generated by tools/golden_corpus.py)"
                % ("v1/AppData/Saved Flows" if os.path.abspath(args.flows) == os.path.abspath(DEFAULT_FLOWS)
                   else "a local folder"))
    print("%d cases written to %s" % (len(cases), args.out))
    print_stats(cases, stats)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
