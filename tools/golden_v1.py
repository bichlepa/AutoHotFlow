"""Generates the golden data of the v1 expression and variable code (work item WI-36, doc/TEST-STRATEGY.md L6).

Usage:
    python tools/golden_v1.py [--check] [--private] [--group NAME ...] [--keep-temp]

Reads the cases from tests/golden/cases/*.json, runs them with the unchanged v1 code in the v1 interpreter
(v1/AutoHotKey/AutoHotFlow.exe, through tools/ahkrun.py --interpreter, so a dialog or a hang cannot block the
run) and writes the results to tests/golden/expected/<group>.json. The harness is tests/golden/v1/harness.ahk.

  --check      generate, but do not write; list the groups whose result differs from the checked-in file
               (exit 1 if any). Use it to show that the generation is reproducible.
  --private    use tests/golden/private/{cases,expected} (the project owner's own flows, never checked in)
  --group      only these case files (by group name)
  --keep-temp  keep the temp folder (input, raw harness output, working directory)
  --show ID    debugging: run only the cases whose id contains ID, print the results, write nothing

Case file format (JSON): {"group": "<name, = file name>", "description": "...", "cases": [ case, ... ]}
  case: {"id": "<unique id>", "kind": "expression|script|replace|checkname|destination|varget|varset",
         "text": "...",                      the expression, the script, the string, the variable name
         "vars": {"<scope>": {"<name>": value}},    optional. scope: instance|thread|loop|global|static
         "common": true,                     optional: the functions of the editor/manager (Var_*_Common)
         "location": "thread"|"loop",        optional: for kind destination and varset
         "convertObjects": true,             optional: for kind replace ("ConvertObjectToString")
         "value": value,                     for kind varset
         "volatile": true,                   optional: the result changes from run to run (A_Now ...); only
                                             the type is recorded
         "note": "...", "sources": [...]}    optional, free text / provenance (corpus)
  value: JSON number = number, JSON string = text, JSON object or array = object. (A float is passed as text and
         converted to a pure number in the harness, because Jxon would make it a text.)

Result file format: see check_result_file() and doc/TEST-STRATEGY.md section 7.
Outcomes: ok | parse_error | eval_error | parse_error_ignored (script: the parser reported an error, v1 does not
look at it) | uncaught_error (v1 raises an error that nothing catches; "detail" has the dialog text) | timeout
(v1 does not return within 8 s) | unknown_kind | harness_failure (a defect of the harness, never checked in).
"""

import argparse
import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import ahkrun  # noqa: E402

GOLDEN = os.path.join(ROOT, "tests", "golden")
HARNESS = os.path.join(GOLDEN, "v1", "harness.ahk")
V1_EXE = os.path.join(ROOT, "v1", "AutoHotKey", "AutoHotFlow.exe")
PUBLIC = (os.path.join(GOLDEN, "cases"), os.path.join(GOLDEN, "expected"))
PRIVATE = (os.path.join(GOLDEN, "private", "cases"), os.path.join(GOLDEN, "private", "expected"))

KINDS = ("expression", "script", "replace", "checkname", "destination", "varget", "varset")
SCOPES = ("instance", "thread", "loop", "global", "static")
OUTCOMES = ("ok", "parse_error", "eval_error", "parse_error_ignored", "unknown_kind", "uncaught_error", "timeout",
            "harness_failure")
VOLATILE = "<volatile>"
BASE_TIMEOUT_S = 120      # backup limit of one harness run: this plus PER_CASE_TIMEOUT_S for every case still to run.
PER_CASE_TIMEOUT_S = 1.0  # The harness has its own watchdog of 8 s per case; a run ends by this limit only if that fails.


# ---------------------------------------------------------------------------------------------------------
# cases
# ---------------------------------------------------------------------------------------------------------

def load_case_files(cases_dir):
    """Returns {group: {"description": ..., "cases": [...]}} sorted by group; checks format and unique ids."""
    groups = {}
    seen = {}
    if not os.path.isdir(cases_dir):
        return groups
    for name in sorted(os.listdir(cases_dir)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(cases_dir, name)
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        group = data.get("group")
        if group != name[:-5]:
            raise ValueError("%s: \"group\" must be the file name without .json, got %r" % (name, group))
        for case in data.get("cases", []):
            check_case(case, name)
            if case["id"] in seen:
                raise ValueError("%s: duplicate case id %r (also in %s)" % (name, case["id"], seen[case["id"]]))
            seen[case["id"]] = name
        groups[group] = data
    return groups


def check_case(case, where):
    """Raises ValueError when the case does not follow the format."""
    cid = case.get("id")
    if not isinstance(cid, str) or not cid:
        raise ValueError("%s: case without id: %r" % (where, case))
    ctx = "%s: %s" % (where, cid)
    if case.get("kind") not in KINDS:
        raise ValueError("%s: kind must be one of %s" % (ctx, ", ".join(KINDS)))
    if not isinstance(case.get("text"), str):
        raise ValueError("%s: text must be a string" % ctx)
    for scope, variables in case.get("vars", {}).items():
        if scope not in SCOPES:
            raise ValueError("%s: unknown scope %r" % (ctx, scope))
        if not isinstance(variables, dict):
            raise ValueError("%s: vars.%s must be an object" % (ctx, scope))
        for name, value in variables.items():
            check_value(value, "%s: vars.%s.%s" % (ctx, scope, name))
    if case["kind"] == "varset":
        check_value(case.get("value"), ctx + ": value")
    for key in case:
        if key not in ("id", "kind", "text", "vars", "common", "location", "convertObjects", "value", "volatile",
                       "note", "sources"):
            raise ValueError("%s: unknown field %r" % (ctx, key))


def check_value(value, ctx):
    if isinstance(value, bool) or value is None:
        raise ValueError("%s: booleans and null are not allowed (v1 has no such values)" % ctx)
    if not isinstance(value, (int, float, str, list, dict)):
        raise ValueError("%s: unsupported value %r" % (ctx, value))


def typed(value):
    """The form the harness reads: {"t": "n"|"s"|"o", "v": ...}; a number goes as text (see the module doc)."""
    if isinstance(value, (int, float)):
        return {"t": "n", "v": repr(value)}
    if isinstance(value, str):
        return {"t": "s", "v": value}
    return {"t": "o", "v": value}


def harness_case(case):
    out = {"id": case["id"], "kind": case["kind"], "text": case["text"]}
    if case.get("common"):
        out["common"] = 1
    if case.get("location"):
        out["location"] = case["location"]
    if case.get("convertObjects"):
        out["convertObjects"] = 1
    if "value" in case:
        out["value"] = typed(case["value"])
    if case.get("vars"):
        out["vars"] = {scope: {name: typed(v) for name, v in variables.items()}
                       for scope, variables in case["vars"].items()}
    return out


# ---------------------------------------------------------------------------------------------------------
# running v1
# ---------------------------------------------------------------------------------------------------------

def read_jsonl(path):
    """Complete JSON lines of the harness output (a line cut off by a kill is dropped)."""
    records = []
    if not os.path.isfile(path):
        return records
    with open(path, encoding="utf-8") as f:
        for line in f:
            if not line.endswith("\n"):
                break
            try:
                records.append(json.loads(line))
            except ValueError:
                break
    return records


def scrub(text, temp):
    """Removes machine specific paths from a dialog text, so the result is the same on every machine."""
    for path, name in ((temp, "<temp>"), (ROOT, "<repo>")):
        for variant in (path, path.replace("\\", "/")):
            text = text.replace(variant, name)
    return text.replace("\r", "")


def run_cases(cases, temp):
    """Runs all cases in the v1 interpreter. Returns ({id: raw result}, header). A case that crashes the harness or
    hangs gets the outcome crash/timeout and the run continues with the next case."""
    if not os.path.isfile(V1_EXE):
        raise SystemExit("v1 interpreter not found: %s" % V1_EXE)
    input_path = os.path.join(temp, "input.json")
    out_path = os.path.join(temp, "output.jsonl")
    workdir = os.path.join(temp, "work")
    with open(input_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"cases": [harness_case(c) for c in cases]}, f, ensure_ascii=True)
    results = {}
    header = {}
    ids = [c["id"] for c in cases]
    first = 1
    while first <= len(cases):
        if os.path.isfile(out_path):
            os.remove(out_path)
        code, out, err, dialogs = ahkrun.run(
            HARNESS, [input_path, out_path, workdir, first],
            timeout=BASE_TIMEOUT_S + PER_CASE_TIMEOUT_S * (len(cases) - first + 1), interpreter=V1_EXE)
        done = 0
        watchdog = False
        for record in read_jsonl(out_path):
            if "harness" in record:
                header = record["harness"]
                continue
            expected_id = ids[first - 1 + done]
            if record.get("id") != expected_id:
                raise SystemExit("harness output out of order: got %r, expected %r" % (record.get("id"), expected_id))
            results[expected_id] = record
            watchdog = record.get("outcome") == "timeout"
            done += 1
        first += done
        if first > len(cases):
            break
        if watchdog:
            continue    # the harness ended the hanging case itself and exited; go on with the next case
        # the harness ended before the last case: the next case is the culprit (or the run was cut off)
        culprit = ids[first - 1]
        detail = (err.strip() or out.strip())[:400]
        if dialogs:
            detail = " | ".join(" | ".join(d.texts) for d in dialogs)
        detail = scrub(detail, temp)
        # exit 97: v1 raised an error that nothing catches (a dialog in the real application)
        outcome = "timeout" if code == 98 else "uncaught_error" if code == 97 else "harness_failure"
        results[culprit] = {"id": culprit, "outcome": outcome, "detail": detail}
        print("  %s: %s (exit %s) %s" % (culprit, outcome, code, detail[:200]), file=sys.stderr)
        first += 1
    return results, header


# ---------------------------------------------------------------------------------------------------------
# results
# ---------------------------------------------------------------------------------------------------------

def finish_result(case, raw):
    """Normalizes one harness record; volatile cases keep only the type of the value."""
    result = {"id": case["id"], "kind": case["kind"], "outcome": raw.get("outcome", "crash")}
    if case.get("volatile"):
        result["volatile"] = True
        value = raw.get("value")
        if value:
            result["value"] = {"type": value.get("type"), "value": VOLATILE}
        return result
    for key in ("value", "errors", "errorText", "boolResult", "varType", "location", "exception", "variables", "log",
                "exitCode", "detail"):
        if key in raw:
            result[key] = raw[key]
    return result


def dump_result_file(group, description, header, results):
    """One result per line, so a change shows up as a small diff."""
    lines = ["{", '  "group": %s,' % json.dumps(group), '  "description": %s,' % json.dumps(description),
             '  "interpreter": %s,' % json.dumps(header, sort_keys=True), '  "results": {']
    items = list(results.items())
    for i, (cid, result) in enumerate(items):
        lines.append("    %s: %s%s" % (json.dumps(cid), json.dumps(result, ensure_ascii=True),
                                       "," if i + 1 < len(items) else ""))
    lines += ["  }", "}", ""]
    return "\n".join(lines)


def differs_from_checked_in(target, text):
    """True when the file at target is missing or its content differs from the generated text (read only).
    Line endings do not count: git stores the files with LF, a Windows working copy (* text=auto) has CRLF, and the
    generator writes LF. Only the checked-in side is normalized; the generated text is LF already."""
    if not os.path.isfile(target):
        return True
    with open(target, encoding="utf-8", newline="") as f:
        old = f.read().replace("\r\n", "\n")
    return old != text


def check_result_file(data, case_data):
    """Returns a list of problems of one result file against its case file (empty = fine)."""
    problems = []
    group = case_data["group"]
    if data.get("group") != group:
        problems.append("group is %r, expected %r" % (data.get("group"), group))
    results = data.get("results")
    if not isinstance(results, dict):
        return problems + ["results is not an object"]
    ids = [c["id"] for c in case_data["cases"]]
    for cid in ids:
        if cid not in results:
            problems.append("no result for case %s" % cid)
    for cid in results:
        if cid not in ids:
            problems.append("result without case: %s" % cid)
    kinds = {c["id"]: c["kind"] for c in case_data["cases"]}
    for cid, result in results.items():
        if result.get("id") != cid:
            problems.append("%s: id inside the result is %r" % (cid, result.get("id")))
        if result.get("outcome") not in OUTCOMES:
            problems.append("%s: unknown outcome %r" % (cid, result.get("outcome")))
        if cid in kinds and result.get("kind") != kinds[cid]:
            problems.append("%s: kind differs from the case" % cid)
        if result.get("outcome") == "harness_failure":
            problems.append("%s: harness_failure (the harness itself failed): %s" % (cid, result.get("detail")))
            continue
        if result.get("outcome") in ("timeout", "uncaught_error"):
            continue    # v1 hangs or raises an error nobody catches: that is the v1 behavior, no further fields
        if result.get("volatile"):
            continue
        value = result.get("value")
        if result.get("outcome") in ("ok", "parse_error_ignored", "eval_error") and result.get("kind") != "expression":
            problems += check_typed(value, cid + ": value")
        if result.get("outcome") == "ok":
            problems += check_typed(value, cid + ": value")
        variables = result.get("variables")
        if not isinstance(variables, dict) or set(variables) != set(SCOPES):
            problems.append("%s: variables must have the scopes %s" % (cid, ", ".join(SCOPES)))
        else:
            for scope, items in variables.items():
                for name, item in items.items():
                    problems += check_typed(item, "%s: variables.%s.%s" % (cid, scope, name))
        if not isinstance(result.get("errors"), list):
            problems.append("%s: errors must be a list" % cid)
        if not isinstance(result.get("log"), list):
            problems.append("%s: log must be a list" % cid)
    return problems


def check_typed(item, ctx):
    if not isinstance(item, dict) or item.get("type") not in ("number", "text", "object") or "value" not in item:
        return ["%s: not a typed value: %r" % (ctx, item)]
    if item["type"] == "number" and not isinstance(item.get("text"), str):
        return ["%s: number without text form" % ctx]
    if item["type"] == "text" and not isinstance(item["value"], str):
        return ["%s: text value is not a string" % ctx]
    return []


# ---------------------------------------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------------------------------------

def main(argv):
    parser = argparse.ArgumentParser(description="Generates the golden data of the v1 expression code.")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--private", action="store_true")
    parser.add_argument("--group", action="append", default=[])
    parser.add_argument("--keep-temp", action="store_true")
    parser.add_argument("--show", action="append", default=[], metavar="ID",
                        help="run only the cases whose id contains ID and print the results; writes nothing")
    args = parser.parse_args(argv)

    cases_dir, expected_dir = PRIVATE if args.private else PUBLIC
    groups = load_case_files(cases_dir)
    if args.group:
        missing = [g for g in args.group if g not in groups]
        if missing:
            print("unknown group(s): %s" % ", ".join(missing), file=sys.stderr)
            return 2
        groups = {g: groups[g] for g in args.group}
    if not groups:
        print("no case files in %s" % cases_dir, file=sys.stderr)
        return 2

    cases = [c for g in groups.values() for c in g["cases"]]
    if args.show:
        cases = [c for c in cases if any(part in c["id"] for part in args.show)]
        raw, header = run_cases(cases, tempfile.mkdtemp(prefix="ahf_golden_"))
        for c in cases:
            print(json.dumps(finish_result(c, raw[c["id"]]), indent=1, ensure_ascii=False))
        return 0
    temp = tempfile.mkdtemp(prefix="ahf_golden_")
    differing = []
    try:
        print("running %d cases of %d groups in the v1 interpreter ..." % (len(cases), len(groups)))
        raw, header = run_cases(cases, temp)
        if not args.check:
            os.makedirs(expected_dir, exist_ok=True)
        for group, data in groups.items():
            results = {c["id"]: finish_result(c, raw[c["id"]]) for c in data["cases"]}
            text = dump_result_file(group, data.get("description", ""), header, results)
            target = os.path.join(expected_dir, group + ".json")
            if differs_from_checked_in(target, text):
                differing.append(group)
            if not args.check:
                with open(target, "w", encoding="utf-8", newline="\n") as f:
                    f.write(text)
            odd = [r["id"] for r in results.values() if r["outcome"] in ("timeout", "uncaught_error", "harness_failure")]
            print("  %-24s %5d cases%s" % (group, len(results), ("   uncaught/timeout: %d" % len(odd)) if odd else ""))
    finally:
        if args.keep_temp:
            print("temp folder kept: %s" % temp)
        else:
            shutil.rmtree(temp, ignore_errors=True)

    if args.check:
        if differing:
            print("DIFFERENT from the checked-in results: %s" % ", ".join(differing))
            return 1
        print("identical to the checked-in results")
    else:
        print("written: %s" % ", ".join(differing) if differing else "written, no change")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
