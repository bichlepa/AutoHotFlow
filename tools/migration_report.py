"""Migration report of v1 flows (WI-45, E35): which elements have a class that v2 does not know yet, and which places of
the known classes behave differently in v2 and carry MIGRATION IDs (doc/MIGRATION.md) together with the v1 text.

    python tools/migration_report.py <flow file or folder> [--json]

The information comes from the loader of the engine (FlowTable, FlowExprConvert, V1ExprConverter), run through
tools/ahkrun.py by tools/migration_report.ahk; this file only collects the flow files and prints the result.
A folder is searched for *.json files (all levels). Exit code: 0, or 1 if a flow could not be loaded, 2 for bad
arguments.

Note: the texts of an element whose class v2 does not know yet cannot be examined (only its class knows which
parameters are expressions). Such elements are listed as "unknown class"; their places show up when the class exists.
"""

import argparse
import json
import os
import sys
import tempfile
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import ahkrun  # noqa: E402

WORKER = HERE / "migration_report.ahk"


def collect(target):
    target = Path(target).resolve()
    if target.is_file():
        return [target]
    if target.is_dir():
        return sorted(p for p in target.rglob("*.json") if p.is_file())
    raise SystemExit("no such flow file or folder: %s" % target)


def run_report(files, timeout=300):
    """Runs the AHK worker over the flow files. Returns the parsed result (a dict with the key "flows")."""
    with tempfile.TemporaryDirectory(prefix="ahf_migreport_") as tmp:
        listing = Path(tmp) / "files.txt"
        result = Path(tmp) / "result.json"
        listing.write_text("\n".join(str(f) for f in files), encoding="utf-8")
        code, stdout, stderr, dialogs = ahkrun.run(str(WORKER), [str(result), str(listing)], timeout=timeout)
        if code != 0 or not result.is_file():
            raise SystemExit("the report worker failed (exit %s): %s %s" % (code, stderr.strip(), dialogs or ""))
        return json.loads(result.read_text(encoding="utf-8"))


def summarize(report):
    flows = report["flows"]
    ok = [f for f in flows if "error" not in f]
    ids = Counter(i for f in ok for p in f["places"] for i in p["ids"])
    return {
        "flows": len(flows),
        "failed": len(flows) - len(ok),
        "elements": sum(f["elements"] for f in ok),
        "unknownClassElements": sum(len(f["unknownClass"]) for f in ok),
        "places": sum(len(f["places"]) for f in ok),
        "placesPerId": dict(sorted(ids.items())),
    }


def one_line(text, limit=100):
    text = text.replace("\r", "\\r").replace("\n", "\\n")
    return text if len(text) <= limit else text[:limit - 3] + "..."


def print_text(report):
    for f in report["flows"]:
        name = Path(f["file"]).name
        if "error" in f:
            print("%s: NOT LOADED: %s" % (name, f["error"]))
            continue
        print("%s (%s): %d elements" % (name, f.get("name", ""), f["elements"]))
        unknown = Counter(u["class"] for u in f["unknownClass"])
        if unknown:
            listed = ", ".join("%s (%d)" % (c, n) for c, n in sorted(unknown.items()))
            print("  unknown class: %d element(s): %s" % (len(f["unknownClass"]), listed))
        for p in f["places"]:
            print("  %s (%s) parameter %s [%s] v1: %s" % (p["element"], p["class"], p["par"], ", ".join(p["ids"]),
                                                          one_line(p["v1"])))
    s = summarize(report)
    print("total: %d flow(s), %d not loaded, %d elements, %d with unknown class, %d marked place(s) %s"
          % (s["flows"], s["failed"], s["elements"], s["unknownClassElements"], s["places"], s["placesPerId"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("target", help="a flow file (.json) or a folder of flow files")
    parser.add_argument("--json", action="store_true", help="print the report as JSON (with a summary)")
    args = parser.parse_args(argv)
    files = collect(args.target)
    if not files:
        print("no flow files in %s" % args.target, file=sys.stderr)
        return 2
    report = run_report(files)
    if args.json:
        report["summary"] = summarize(report)
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        print_text(report)
    return 1 if summarize(report)["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
