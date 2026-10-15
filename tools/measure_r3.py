"""WI-0046: R0003 measurement (cost of parsing many element classes in every process) and the load-phase baseline (F-0282).

Three modes (parse, load, roles). They run on the real chain with an entry script that is generated in a temporary folder (nothing is
written into src/): the entry includes src/AhfBoot.ahk and, after it, the generated element files.

  python tools/measure_r3.py parse [--counts 0,50,150,300] [--runs 7] [--out FILE]
      Per element count N and per run: (a) parse time of one process (a process with an unknown role: it parses
      everything, then ends with exit 2), (b) start of supervisor, storage and engine until ready, and the memory of
      each process, (c) start of workers (request to ready) and their memory. The element files are synthetic
      (about 160 lines, 10 parameters). Rounds alternate over the counts, so a drift of the machine hits all counts.

  python tools/measure_r3.py load [--runs 3] [--flows 200] [--variants plain,stubs] [--out FILE]
      The load phase of the engine over N big v1 flows (the flows and the probe of tests/stress/test_big_flows.py):
      per flow the parse time, the conversion time (FlowExprConvert.Run) and the cost of the answer handler, the
      time from the first flow list to the last flow loaded, the variable phase until evt.engine.ready, and the
      latency of cmd.engine.snapshot during the load. Variant `plain` has the element classes of the product,
      variant `stubs` additionally registers a stub class for every class that occurs in the big flows, and every
      parameter of such a class counts as an expression (the worst case after S0002 and S0008). The timings come from
      tools/measure_r3_hooks.ahk, which wraps methods of the engine at run time (src/ stays unchanged).

  python tools/measure_r3.py roles [--counts 0,150] [--runs 5] [--layout auto|legacy|entries] [--out FILE]
      (WI-0047-PREP, M-0032/M-0033) Private bytes of each role process in a normal session: supervisor, storage,
      engine, manager (stub, headless), debug (headless), one worker, and a triggerhost stand-in (the role is a
      placeholder that ends at once, so a process with the same includes that idles is measured). The classes are
      synthetic with a mode mix (synthetic_mode). `legacy` is the entry before WI-0047-PREP (every process parses
      everything), `entries` copies the real role entries and inserts the classes by Mode. The output has the sums
      (supervisor, storage, engine, manager, triggerhost plus 1, 3 and 16 workers) as the sum of the medians.

Run it alone on the machine (no other tests, no other agents): the numbers are timings. Results are printed as
JSON lines (`R0003 {...}`) and, with --out, appended to FILE. `summary` below each mode prints median/min/max.
"""

import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

import psutil

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "tests" / "fault"))
sys.path.insert(0, str(ROOT / "tests" / "stress"))

import faultkit  # noqa: E402
from faultkit import Chain, Sup, connect, wait_until  # noqa: E402
from support.procs import ProcessTracker  # noqa: E402

AHKRUN = ROOT / "tools" / "ahkrun.py"
HOOKS = ROOT / "tools" / "measure_r3_hooks.ahk"
SRC_BOOT = ROOT / "src" / "AhfBoot.ahk"
BIG_FLOWS_DIR = ROOT / "tests" / "data" / "flows" / "v1_examples"
SETTLE_S = 1.5


# --- generated sources -------------------------------------------------------------------------------------------

def synthetic_element(n, mode="inline"):
    """AHK source of one element class of realistic size: about 160 lines, 10 parameters, GenerateName,
    CheckSettings, a Run with some logic and language keys. `mode` is the literal static Mode."""
    name = "Action_Synth_%04d" % n
    out = ["#Requires AutoHotkey v2.0", "#Include %s" % (ROOT / "src" / "elements" / "base" / "AhfElement.ahk"),
           "#Include %s" % (ROOT / "src" / "elements" / "base" / "ElementRegistry.ahk"), "",
           "; Synthetic element for the R0003 measurement (WI-0046). Not part of the product.",
           "class %s extends AhfElement {" % name,
           '    static Mode := "%s"' % mode, '    static Level := "Beginner"', '    static Stability := "Stable"',
           '    static Icon := "synth.ico"', "",
           '    static Name() => Lang("Synthetic action %d")' % n,
           '    static Category() => Lang("Synthetic")', "",
           "    static Parameters(ctx) {", "        parametersToEdit := []"]
    kinds = ["Expression", "String", "Checkbox", "Radio", "Number", "Expression", "String", "Integer", "String",
             "Expression"]
    for i, kind in enumerate(kinds):
        out += ['        parametersToEdit.Push(Map("type", "Label", "label", Lang("Parameter %d of action %d")))' % (i, n),
                '        parametersToEdit.Push(Map("id", "Par%d", "type", "%s", "default", %d,' % (i, kind, i),
                '            "label", Lang("Parameter %d"), "content", "%s"))' % (i, kind)]
    out += ["        return parametersToEdit", "    }", "",
            "    static GenerateName(data, ctx) {",
            '        name := Lang("Synthetic action %d")' % n,
            '        if (data.HasProp("Par0") && data.Par0 != "")',
            '            name .= " - " data.Par0',
            '        if (data.HasProp("Par1") && data.Par1 != "")',
            '            name .= " (" data.Par1 ")"',
            "        return name", "    }", "",
            "    static CheckSettings(form, params, staticValues) {"]
    for i in range(0, 10, 2):
        out += ['        if (params.HasProp("Par%d") && params.Par%d = "") {' % (i, i),
                '            form.Disable("Par%d")' % (i + 1),
                "        } else {",
                '            form.Enable("Par%d")' % (i + 1),
                "        }"]
    out += ["    }", "",
            "    static Run(ctx, params) {",
            "        total := 0",
            "        text := \"\"",
            "        loop 5 {",
            "            idx := A_Index - 1",
            "            if (!params.HasProp(\"Par\" idx))",
            "                continue",
            "            value := params.%\"Par\" idx%",
            "            if (IsNumber(value))",
            "                total += value",
            "            else if (value != \"\")",
            "                text .= value \";\"",
            "        }",
            "        if (total < 0)",
            '            throw ElementError(Lang("Parameter is out of range"))',
            "        parts := StrSplit(text, \";\")",
            "        result := Map()",
            "        for part in parts {",
            "            if (part = \"\")",
            "                continue",
            "            if (result.Has(part))",
            "                result[part] += 1",
            "            else",
            "                result[part] := 1",
            "        }",
            "        summary := \"\"",
            "        for key, count in result",
            '            summary .= key "=" count ","',
            "        ctx.Finish(\"normal\")",
            "    }", ""]
    # helper methods up to about 160 lines
    k = 0
    while len(out) < 154:
        out += ["    static Helper%d(a, b := 0) {" % k,
                "        if (a is Number && b is Number)",
                "            return a * %d + b" % (k + 1),
                "        c := String(a) . String(b)",
                "        return StrLen(c) > %d ? SubStr(c, 1, %d) : c" % (10 + k, 10 + k),
                "    }", ""]
        k += 1
    out += ["}", "", "ElementRegistry.Register(%s)" % name, ""]
    return name, "\n".join(out)


def synthetic_mode(n):
    """Mode mix of the synthetic classes for the role measurement (WI-0047-PREP): v1 has 16 triggers in 152
    classes, so every 10th class is a trigger; the share of worker classes (about one third) is a guess, because
    the modes of the ported elements are not decided yet (ELEMENT-API-V2 section 7, heuristic). At 150 classes:
    15 triggers, 45 workers, 90 inline."""
    if n % 10 == 0:
        return "trigger"
    return "worker" if n % 3 == 1 else "inline"


def write_synthetic(folder, count, mixed=False):
    """Writes `count` element files and returns the #Include lines. With mixed=True the classes get the modes of
    synthetic_mode and the result is a list of (mode, #Include line)."""
    includes = []
    for n in range(count):
        mode = synthetic_mode(n) if mixed else "inline"
        name, text = synthetic_element(n, mode)
        path = Path(folder) / (name + ".ahk")
        path.write_text(text, encoding="utf-8", newline="\n")
        line = "#Include %s" % path
        includes.append((mode, line) if mixed else line)
    return includes


def registered_ids():
    """Lower-case class ids that the product registers already (the element files of src/elements)."""
    found = set()
    for path in (ROOT / "src" / "elements").rglob("*.ahk"):
        for m in re.finditer(r"^class\s+(\w+)\s+extends\s+AhfElement", path.read_text(encoding="utf-8"), re.M):
            found.add(m.group(1).lower())
    return found


def big_flow_names():
    sys.path.insert(0, str(ROOT / "tests" / "stress"))
    import test_big_flows
    return test_big_flows


def write_stubs(path):
    """One file with a stub class for every element class in the big flows that the product does not register. Every
    parameter that occurs in a flow with that class is declared as content Expression (worst case). Returns
    (number of classes, number of parameters)."""
    tbf = big_flow_names()
    classes = {}
    for flow in tbf.BIG_FLOWS:
        data = json.loads(flow.read_text(encoding="utf-8"))
        for el in data["allElements"].values():
            cls = el.get("class", "")
            if not re.fullmatch(r"\w+", cls):
                continue
            pars = classes.setdefault(cls.lower(), (cls, set()))[1]
            pars.update(k for k in (el.get("pars") or {}) if re.fullmatch(r"\w+", k))
    have = registered_ids()
    lines = ["#Requires AutoHotkey v2.0", "#Include %s" % (ROOT / "src" / "elements" / "base" / "AhfElement.ahk"),
             "#Include %s" % (ROOT / "src" / "elements" / "base" / "ElementRegistry.ahk"), ""]
    n_cls = n_par = 0
    for low, (cls, pars) in sorted(classes.items()):
        if low in have:
            continue
        n_cls += 1
        n_par += len(pars)
        mode = "trigger" if low.startswith("trigger_") else "inline"
        entries = ", ".join('Map("id", "%s", "content", "Expression")' % p for p in sorted(pars))
        lines += ["class %s extends AhfElement {" % cls, '    static Mode := "%s"' % mode,
                  "    static Parameters(ctx) => [%s]" % entries, "}", "ElementRegistry.Register(%s)" % cls, ""]
    Path(path).write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return n_cls, n_par


def write_entry(folder, includes, hooks=False):
    entry = Path(folder) / "MeasureEntry.ahk"
    lines = ["#Requires AutoHotkey v2.0", "#SingleInstance Off", "#Include %s" % SRC_BOOT, *includes]
    if hooks:
        lines.append("#Include %s" % HOOKS)
    lines += ["AhfMain()", ""]
    entry.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return entry


# --- helpers -----------------------------------------------------------------------------------------------------

def mem(pid):
    p = psutil.Process(pid)
    mi = p.memory_info()
    return {"wset_mb": round(mi.wset / 2**20, 2), "private_mb": round(mi.private / 2**20, 2)}


def stats(values):
    values = list(values)
    return {"median": round(statistics.median(values), 3), "min": round(min(values), 3),
            "max": round(max(values), 3), "n": len(values)}


def emit(out, record):
    line = "R0003 " + json.dumps(record)
    print(line, flush=True)
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write(line + "\n")


def machine_load():
    return psutil.cpu_percent(interval=1.0)


def new_session():
    return "r3" + uuid.uuid4().hex[:10]


# --- mode parse --------------------------------------------------------------------------------------------------

def bare_parse(entry):
    """Wall time of a process that parses all files and ends at once (exit 2, unknown role), including the
    start of ahkrun.py and of the interpreter. The difference between element counts is the parse cost."""
    t0 = time.perf_counter()
    r = subprocess.run([sys.executable, str(AHKRUN), "--timeout", "60", str(entry), "--role=none"],
                       capture_output=True, text=True, cwd=str(ROOT))
    dt = time.perf_counter() - t0
    if r.returncode != 2:
        raise RuntimeError("bare parse: exit %s: %s" % (r.returncode, (r.stdout + r.stderr)[-500:]))
    return dt * 1000


def chain_start(entry, procs, datadir):
    """Supervisor with storage and engine (the engine requests one warm worker). Returns the times in ms from the
    launch and the memory of each process."""
    faultkit.ENTRY = Path(entry)
    chain = Chain(procs, datadir, new_session(), "storage,engine", [], run_timeout=60)
    result = {}
    try:
        t_hub = (time.perf_counter() - chain.sup.t0) * 1000
        result["hub_up_ms"] = round(t_hub, 1)
        wanted = ["storage", "engine", "worker:1"]
        seen = {}
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline and len(seen) < len(wanted):
            st = chain.states()
            for name in wanted:
                if name not in seen and st.get(name, {}).get("state") == "ready":
                    seen[name] = (time.perf_counter() - chain.sup.t0) * 1000
            time.sleep(0.003)
        for name in wanted:
            result[name.replace(":", "") + "_ready_ms"] = round(seen[name], 1) if name in seen else None
        time.sleep(SETTLE_S)
        st = chain.states()
        result["mem"] = {n: mem(st[n]["pid"]) for n in ["storage", "engine", "worker:1"] if n in st and st[n]["pid"]}
        result["mem"]["supervisor"] = mem(chain.sup.ahk_pid())
    finally:
        chain.close()
    return result


def worker_start(entry, procs, datadir, count=3):
    """Supervisor alone; a client named engine requests workers one after the other. Returns the time from the
    request to ready (polling of cmd.process.list, every 3 ms) and the memory of the last worker."""
    faultkit.ENTRY = Path(entry)
    session = new_session()
    sup = Sup(procs, datadir, session, ["--start=storage"], run_timeout=60)
    engine = connect(sup.pipe, "engine")
    times, last = [], None
    try:
        for _ in range(count):
            t0 = time.perf_counter()
            answer = engine.request("supervisor", "cmd.process.spawn", {"role": "worker"}, timeout=5)["payload"]
            name = answer["name"]

            def ready():
                lst = engine.request("supervisor", "cmd.process.list", {}, timeout=5)["payload"]["processes"]
                for p in lst:
                    if p["name"] == name and p["state"] == "ready":
                        return p["pid"]
                return None
            pid = wait_until(ready, 20, step=0.003)
            times.append((time.perf_counter() - t0) * 1000)
            last = pid
            time.sleep(0.3)
        time.sleep(SETTLE_S)
        result = {"worker_start_ms": [round(t, 1) for t in times], "worker_mem": mem(last)}
        engine.request("supervisor", "cmd.app.exit", {}, timeout=5)
    finally:
        try:
            engine.close()
        except Exception:
            pass
        if sup.wait_exit(10) is None:
            procs.kill(sup.proc)
        sup.close()
    return result


def mode_parse(args):
    counts = [int(c) for c in args.counts.split(",")]
    entries, work = {}, tempfile.mkdtemp(prefix="ahf-r3-")
    for n in counts:
        folder = Path(work) / ("n%d" % n)
        folder.mkdir()
        entries[n] = write_entry(folder, write_synthetic(folder, n))
    print("synthetic element files in %s" % work, flush=True)
    print("machine load before: %.1f %%" % machine_load(), flush=True)
    rows = {n: {"bare_ms": [], "hub_up_ms": [], "storage_ready_ms": [], "engine_ready_ms": [], "worker1_ready_ms": [],
                "worker_start_ms": [], "mem": {}} for n in counts}
    procs = ProcessTracker()
    try:
        for rnd in range(args.runs):
            order = counts if rnd % 2 == 0 else list(reversed(counts))
            for n in order:
                row = rows[n]
                row["bare_ms"].append(bare_parse(entries[n]))
                datadir = Path(tempfile.mkdtemp(prefix="ahf-r3d-"))
                c = chain_start(entries[n], procs, datadir)
                for key in ("hub_up_ms", "storage_ready_ms", "engine_ready_ms", "worker1_ready_ms"):
                    if c.get(key) is not None:
                        row[key].append(c[key])
                for proc, m in c["mem"].items():
                    row["mem"].setdefault(proc, {"wset_mb": [], "private_mb": []})
                    row["mem"][proc]["wset_mb"].append(m["wset_mb"])
                    row["mem"][proc]["private_mb"].append(m["private_mb"])
                datadir2 = Path(tempfile.mkdtemp(prefix="ahf-r3d-"))
                w = worker_start(entries[n], procs, datadir2)
                row["worker_start_ms"] += w["worker_start_ms"]
                row["mem"].setdefault("worker(spawned)", {"wset_mb": [], "private_mb": []})
                row["mem"]["worker(spawned)"]["wset_mb"].append(w["worker_mem"]["wset_mb"])
                row["mem"]["worker(spawned)"]["private_mb"].append(w["worker_mem"]["private_mb"])
                print("round %d N=%d done" % (rnd + 1, n), flush=True)
    finally:
        procs.close()
    print("machine load after: %.1f %%" % machine_load(), flush=True)
    for n in counts:
        row = rows[n]
        summary = {"mode": "parse", "elements": n, "runs": args.runs}
        for key in ("bare_ms", "hub_up_ms", "storage_ready_ms", "engine_ready_ms", "worker1_ready_ms",
                    "worker_start_ms"):
            if row[key]:
                summary[key] = stats(row[key])
        summary["mem"] = {p: {k: stats(v) for k, v in d.items()} for p, d in row["mem"].items()}
        emit(args.out, summary)


# --- mode load ---------------------------------------------------------------------------------------------------

def mode_load(args):
    import test_big_flows as tbf
    from support import metrics
    work = tempfile.mkdtemp(prefix="ahf-r3-")
    entries = {}
    folder = Path(work) / "plain"
    folder.mkdir()
    entries["plain"] = write_entry(folder, [], hooks=True)
    folder = Path(work) / "stubs"
    folder.mkdir()
    n_cls, n_par = write_stubs(folder / "Stubs.ahk")
    entries["stubs"] = write_entry(folder, ["#Include %s" % (folder / "Stubs.ahk")], hooks=True)
    print("stub classes: %d, parameters declared as expression: %d" % (n_cls, n_par), flush=True)
    print("machine load before: %.1f %%" % machine_load(), flush=True)
    variants = args.variants.split(",")
    results = {v: [] for v in variants}
    procs = ProcessTracker()
    try:
        for rnd in range(args.runs):
            for v in (variants if rnd % 2 == 0 else list(reversed(variants))):
                datadir = Path(tempfile.mkdtemp(prefix="ahf-r3d-"))
                loadfile = datadir / "load.jsonl"
                os.environ["AHF_R3_LOADFILE"] = str(loadfile)
                faultkit.ENTRY = Path(entries[v])
                result = tbf.load_chain_and_probe(procs, datadir, new_session(), args.flows)
                chain = result["chain"]
                try:
                    lat = metrics.Dist([x * 1000 for x in result["latencies"]]) if result["latencies"] else None
                    loaded = len(chain.snapshot_ok(timeout=10)["flows"])
                    time.sleep(0.5)
                finally:
                    result["probe"].close()
                    chain.close()
                lines = [json.loads(x) for x in loadfile.read_text(encoding="utf-8").splitlines()] \
                    if loadfile.exists() else []
                flows = [x for x in lines if x["type"] == "flow"]
                phase = next((x for x in lines if x["type"] == "phase"), {})
                vars_ = next((x for x in lines if x["type"] == "vars"), {})
                rec = {"mode": "load", "variant": v, "run": rnd + 1, "flows": args.flows, "loaded": loaded,
                       "ready_s": round(result["t_ready"], 2) if result["t_ready"] else None,
                       "timeouts": result["timeouts"], "snapshot_ms": lat.as_dict() if lat else None,
                       "files_ms": phase.get("files_ms"), "vars_phase_ms": phase.get("vars_ms"),
                       "var_handlers_ms": vars_.get("handler_ms"), "var_answers": vars_.get("answers")}
                if flows:
                    for key in ("parse_ms", "convert_ms", "handler_ms"):
                        vals = [f[key] for f in flows]
                        rec[key] = {"sum": round(sum(vals), 1), "mean": round(statistics.mean(vals), 2),
                                    "max": round(max(vals), 2)}
                    rec["pending_elements"] = sum(f["pending"] for f in flows)
                    by_flow = {}
                    for f in flows:
                        by_flow.setdefault(f["chars"], []).append(f["convert_ms"])
                    rec["convert_ms_by_flow_chars"] = {str(k): round(statistics.mean(v), 2)
                                                       for k, v in sorted(by_flow.items())}
                results[v].append(rec)
                emit(args.out, rec)
    finally:
        procs.close()
    print("machine load after: %.1f %%" % machine_load(), flush=True)
    for v in variants:
        recs = results[v]
        if not recs:
            continue
        summary = {"mode": "load-summary", "variant": v, "runs": len(recs),
                   "ready_s": stats(r["ready_s"] for r in recs if r["ready_s"]),
                   "snapshot_max_ms": stats(r["snapshot_ms"]["max"] for r in recs if r["snapshot_ms"]),
                   "snapshot_median_ms": stats(r["snapshot_ms"]["median"] for r in recs if r["snapshot_ms"])}
        for key in ("parse_ms", "convert_ms", "handler_ms"):
            vals = [r[key]["sum"] for r in recs if key in r]
            if vals:
                summary[key + "_sum"] = stats(vals)
        for key in ("files_ms", "vars_phase_ms", "var_handlers_ms"):
            vals = [r[key] for r in recs if r.get(key) is not None]
            if vals:
                summary[key] = stats(vals)
        emit(args.out, summary)


# --- mode roles --------------------------------------------------------------------------------------------------

SRC_ENTRY_DIR = ROOT / "src" / "entry"
SRC_PRODUCT_ENTRY = ROOT / "src" / "AutoHotFlow.ahk"


def layout_of(requested):
    """`entries` when src/entry exists (WI-0047-PREP and later), else `legacy` (one entry, every process parses
    everything)."""
    if requested != "auto":
        return requested
    return "entries" if SRC_ENTRY_DIR.is_dir() else "legacy"


def rewrite_entry(src, dest, includes, replace_main=None):
    """Copies the entry script `src` to `dest`: relative #Include paths become absolute (they are relative to the
    folder of the including file) and `includes` (lines) are inserted before the call AhfMain(). With
    `replace_main` that call is replaced by this text (a stand-in for a role that cannot be measured at rest)."""
    out = []
    done = False
    for line in Path(src).read_text(encoding="utf-8").splitlines():
        m = re.match(r"#Include\s+(.+?)\s*$", line)
        if m and not os.path.isabs(m.group(1)):
            line = "#Include %s" % (Path(src).parent / m.group(1)).resolve()
        if line.strip().startswith("AhfMain("):
            out += includes
            out.append(replace_main if replace_main is not None else line)
            done = True
            continue
        out.append(line)
    if not done:
        raise RuntimeError("%s has no AhfMain() line" % src)
    Path(dest).parent.mkdir(parents=True, exist_ok=True)
    Path(dest).write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")


def role_modes(role):
    """The modes of the element classes a role includes (tools/gen_element_includes.py, E0041)."""
    sys.path.insert(0, str(ROOT / "tools"))
    import gen_element_includes
    return gen_element_includes.ROLE_MODES.get(role, ())


def build_role_entries(folder, count, layout):
    """Builds the entry scripts for one element count in `folder` and returns (supervisor entry, triggerhost
    stand-in or None).
    legacy: one entry (src/AhfBoot.ahk plus all synthetic classes), as before WI-0047-PREP.
    entries: copies of the real entries (src/AutoHotFlow.ahk and src/entry/<role>.ahk) with the synthetic classes
    inserted according to the Mode of each class and the table of the role. The supervisor starts the other roles
    from entry/ next to its own script, so the copy folder is a complete installation."""
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    synth_dir = folder / "elements"
    synth_dir.mkdir(exist_ok=True)
    mixed = write_synthetic(synth_dir, count, mixed=True)
    if layout == "legacy":
        return write_entry(folder, [line for _, line in mixed]), None
    sup = folder / "MeasureEntry.ahk"
    rewrite_entry(SRC_PRODUCT_ENTRY, sup, [])
    for path in sorted(SRC_ENTRY_DIR.glob("*.ahk")):
        modes = role_modes(path.stem)
        rewrite_entry(path, folder / "entry" / path.name, [line for mode, line in mixed if mode in modes])
    standin = folder / "entry" / "triggerhost_standin.ahk"
    rewrite_entry(SRC_ENTRY_DIR / "triggerhost.ahk", standin,
                  [line for mode, line in mixed if mode in role_modes("triggerhost")], replace_main="Persistent()")
    return sup, standin


def standin_mem(entry, procs):
    """Private bytes of a process that parses the entry and then idles (for a role that is a placeholder and ends
    at once). Started through ahkrun like every test process; ended by killing the tree."""
    proc = procs.start([sys.executable, str(AHKRUN), "--timeout", "30", str(entry)], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, cwd=str(ROOT))
    try:
        # wait until an AutoHotkey child exists and has been up for the settle time; the biggest one counts (a
        # child that is still being created shows a few hundred KB)
        deadline = time.monotonic() + 15
        best = None
        while time.monotonic() < deadline:
            time.sleep(SETTLE_S + 0.5)
            kids = [c for c in psutil.Process(proc.pid).children(recursive=False) if "autohotkey" in c.name().lower()]
            if kids:
                best = max((mem(c.pid) for c in kids), key=lambda m: m["private_mb"])
                if best["private_mb"] > 3:
                    return best
        raise RuntimeError("stand-in process not measurable: %s" % best)
    finally:
        procs.kill(proc)


def roles_chain(entry, procs, datadir):
    """Supervisor with storage, engine (one warm worker), manager (stub, headless) and debug (headless). Returns
    the memory of each process."""
    faultkit.ENTRY = Path(entry)
    chain = Chain(procs, datadir, new_session(), "storage,engine,manager,debug", ["--ui=stub", "--headless"],
                  run_timeout=90)
    try:
        chain.wait_ready(["storage", "engine", "manager", "debug", "worker:1"], timeout=40)
        time.sleep(SETTLE_S)
        st = chain.states()
        result = {n.replace(":1", ""): mem(st[n]["pid"]) for n in ["storage", "engine", "manager", "debug", "worker:1"]}
        result["supervisor"] = mem(chain.sup.ahk_pid())
    finally:
        chain.close()
    return result


def mode_roles(args):
    counts = [int(c) for c in args.counts.split(",")]
    layout = layout_of(args.layout)
    work = tempfile.mkdtemp(prefix="ahf-r3r-")
    entries = {n: build_role_entries(Path(work) / ("n%d" % n), n, layout) for n in counts}
    print("layout %s, entry scripts in %s" % (layout, work), flush=True)
    print("machine load before: %.1f %%" % machine_load(), flush=True)
    procs = ProcessTracker()
    rows = {n: {} for n in counts}
    try:
        for rnd in range(args.runs):
            for n in (counts if rnd % 2 == 0 else list(reversed(counts))):
                entry, standin = entries[n]
                datadir = Path(tempfile.mkdtemp(prefix="ahf-r3d-"))
                result = roles_chain(entry, procs, datadir)
                if standin is None:      # legacy: the same entry, a process that idles after the parse
                    standin = Path(entry).parent / "standin.ahk"
                    text = Path(entry).read_text(encoding="utf-8").replace("AhfMain()", "Persistent()")
                    standin.write_text(text, encoding="utf-8", newline="\n")
                result["triggerhost"] = standin_mem(standin, procs)
                for proc, m in result.items():
                    rows[n].setdefault(proc, []).append(m["private_mb"])
                print("round %d N=%d done" % (rnd + 1, n), flush=True)
    finally:
        procs.close()
    print("machine load after: %.1f %%" % machine_load(), flush=True)
    for n in counts:
        med = {p: statistics.median(v) for p, v in rows[n].items()}
        background = sum(med[p] for p in ("supervisor", "storage", "engine", "manager", "triggerhost"))
        sums = {"w%d" % k: round(background + k * med["worker"], 1) for k in (1, 3, 16)}
        summary = {"mode": "roles", "layout": layout, "elements": n, "runs": args.runs,
                   "private_mb": {p: stats(v) for p, v in rows[n].items()},
                   "background_without_workers_mb": round(background, 1), "sum_private_mb": sums}
        emit(args.out, summary)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="mode", required=True)
    p = sub.add_parser("parse")
    p.add_argument("--counts", default="0,50,150,300")
    p.add_argument("--runs", type=int, default=7)
    p.add_argument("--out", default="")
    p = sub.add_parser("load")
    p.add_argument("--runs", type=int, default=3)
    p.add_argument("--flows", type=int, default=200)
    p.add_argument("--variants", default="plain,stubs")
    p.add_argument("--out", default="")
    p = sub.add_parser("roles")
    p.add_argument("--counts", default="0,150")
    p.add_argument("--runs", type=int, default=5)
    p.add_argument("--layout", default="auto", choices=["auto", "legacy", "entries"])
    p.add_argument("--out", default="")
    p = sub.add_parser("gen")
    p.add_argument("folder")
    p.add_argument("--count", type=int, default=3)
    args = ap.parse_args()
    if args.mode == "parse":
        mode_parse(args)
    elif args.mode == "load":
        mode_load(args)
    elif args.mode == "roles":
        mode_roles(args)
    else:
        Path(args.folder).mkdir(parents=True, exist_ok=True)
        inc = write_synthetic(args.folder, args.count)
        print(write_entry(args.folder, inc))


if __name__ == "__main__":
    main()
