"""Render measurement for risk R0002 (WI-0083, REQ-PRF-060, ARCHITECTURE 2.1).

Runs tests/ahk/helpers/render_bench.ahk for every case, one after the other, and prints mean, median, p95 and the
range of the frame times. The main set is the spec of WI-0083: 300 elements, 350 connections, 1920x1080 and 3840x2160,
the whole flow visible (whole) and zoom 1 with a part visible (zoom1), anti-aliasing on and off. The remedy set (only
with --set remedy or all) measures the remedies of ARCHITECTURE 2.1 at 1920x1080, whole, anti-aliasing on: names left
out, icons scaled in advance (a proxy: the small file Tooltip.png), a static layer with the running elements on top,
and the grid dots.

Run it alone on the machine (nothing else of the tests running, no other AutoHotkey script that redraws). The cases
run one after the other; a case that fails is reported and the others still run.

Usage:
    python tools/measure_render.py                       # main set, 100 frames after 10 warm-up frames
    python tools/measure_render.py --set all --out FILE  # main and remedy set, JSON lines appended to FILE
    python tools/measure_render.py --frames 5 --warmup 1 --only "1920x1080 whole aa-on"   # a short check
"""

import argparse
import json
import math
import re
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import psutil

ROOT = Path(__file__).resolve().parent.parent
BENCH = ROOT / "tests" / "ahk" / "helpers" / "render_bench.ahk"
AHKRUN = ROOT / "tools" / "ahkrun.py"

SIZES = [(1920, 1080), (3840, 2160)]
VIEWS = ["whole", "zoom1"]
AA = ["on", "off"]


def main_cases():
    """The spec cases: every size, view and anti-aliasing setting, the parts of v1 and big icons."""
    cases = []
    for w, h in SIZES:
        for view in VIEWS:
            for aa in AA:
                cases.append(dict(label=f"{w}x{h} {view} aa-{aa}", w=w, h=h, view=view, aa=aa, dots="auto",
                                  parts="eticl", icons="big", set="main"))
    return cases


def remedy_cases():
    """Remedies at 1920x1080, whole flow, anti-aliasing on (ARCHITECTURE 2.1 and WI-0083 task 4)."""
    base = dict(w=1920, h=1080, view="whole", aa="on", set="remedy")
    return [
        dict(base, label="remedy: names left out", dots="auto", parts="eicl", icons="big"),
        dict(base, label="remedy: icons scaled in advance (small file)", dots="auto", parts="eticl", icons="small"),
        dict(base, label="remedy: names left out, icons small", dots="auto", parts="eicl", icons="small"),
        dict(base, label="remedy: static layer, running elements on top", dots="auto", parts="breit", icons="big"),
        dict(base, label="remedy: static layer, running elements on top, icons small", dots="auto", parts="breit",
             icons="small"),
        dict(base, label="part only: BitBlt of a cached layer", dots="auto", parts="b", icons="big"),
        dict(base, label="grid dots on (above zoom 1 in v1)", dots="on", parts="eticl", icons="big"),
    ]


def parse_result(path):
    """The RESULT line of the bench: key=value pairs, the last key is times= (comma separated, milliseconds)."""
    text = Path(path).read_text(encoding="utf-8-sig") if Path(path).exists() else ""
    for line in text.splitlines():
        if line.startswith("ERROR"):
            return None, line
        if line.startswith("RESULT"):
            m = re.search(r" times=(.*)$", line)
            times = [float(x) for x in m.group(1).split(",")] if m else []
            head = line[:m.start()] if m else line
            fields = dict(p.split("=", 1) for p in head.split()[1:] if "=" in p)
            fields["times"] = times
            return fields, None
    return None, "no RESULT line"


def stats(times):
    ordered = sorted(times)
    rank = max(1, math.ceil(0.95 * len(ordered)))
    return {"n": len(times), "mean": statistics.mean(times), "median": statistics.median(times),
            "p95": ordered[rank - 1], "min": ordered[0], "max": ordered[-1]}


def run_case(case, frames, warmup, workdir):
    label = case["label"]
    out = Path(workdir) / (re.sub(r"[^A-Za-z0-9]+", "_", label) + ".txt")
    if out.exists():
        out.unlink()
    cmd = [sys.executable, str(AHKRUN), "--timeout", "900", str(BENCH), str(out), str(case["w"]), str(case["h"]),
           case["view"], case["aa"], str(frames), str(warmup), case["dots"], case["parts"], case["icons"]]
    started = time.time()
    proc = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)
    fields, error = parse_result(out)
    took = time.time() - started
    if fields is None:
        return dict(case, error=error or f"exit {proc.returncode}", seconds=round(took, 1))
    return dict(case, fields=fields, stats=stats(fields["times"]), seconds=round(took, 1))


def describe(result):
    if "error" in result:
        return f"{result['label']}: FAILED ({result['error']})"
    f = result["fields"]
    s = result["stats"]
    return (f"{result['label']:<62} mean {s['mean']:8.2f}  median {s['median']:8.2f}  p95 {s['p95']:8.2f}  "
            f"min {s['min']:7.2f}  max {s['max']:8.2f} ms  | zoom {f.get('zoom')} elements {f.get('elements')} "
            f"connections {f.get('connections')} labels {f.get('labels')} dots {f.get('dots_drawn')} "
            f"aa {result['aa']} parts {f.get('parts')} icons {f.get('icons')} | {result['seconds']} s")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Render measurement for R0002 (WI-0083). Run alone.")
    ap.add_argument("--set", choices=["main", "remedy", "all"], default="main")
    ap.add_argument("--frames", type=int, default=100, help="measured frames per case (default 100)")
    ap.add_argument("--warmup", type=int, default=10, help="warm-up frames per case (default 10)")
    ap.add_argument("--only", help="run only the cases whose label contains this text")
    ap.add_argument("--out", help="append one JSON line per case to this file")
    args = ap.parse_args(argv)

    cases = []
    if args.set in ("main", "all"):
        cases += main_cases()
    if args.set in ("remedy", "all"):
        cases += remedy_cases()
    if args.only:
        cases = [c for c in cases if args.only in c["label"]]
    if not cases:
        print("no case selected", file=sys.stderr)
        return 2

    load = psutil.cpu_percent(interval=2)
    others = [p.info["name"] for p in psutil.process_iter(["name"])
              if (p.info["name"] or "").lower().startswith(("autohotkey", "python"))]
    print(f"machine: {psutil.cpu_count()} logical CPUs, cpu load over 2 s before the start {load} %, "
          f"AutoHotkey and Python processes running: {len(others)}", flush=True)
    print(f"cases: {len(cases)}, frames {args.frames}, warm-up {args.warmup}", flush=True)

    workdir = Path(tempfile.gettempdir()) / "ahf_render_bench"
    workdir.mkdir(exist_ok=True)
    results = []
    for case in cases:
        result = run_case(case, args.frames, args.warmup, workdir)
        results.append(result)
        print(describe(result), flush=True)
        if args.out:
            record = {k: v for k, v in result.items() if k != "fields"}
            if "fields" in result:
                record["fields"] = {k: v for k, v in result["fields"].items() if k != "times"}
                record["times_ms"] = [round(t, 3) for t in result["fields"]["times"]]
            record["cpu_load_before_percent"] = load
            with open(args.out, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    failed = sum(1 for r in results if "error" in r)
    print(f"done: {len(results) - failed} measured, {failed} failed", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
