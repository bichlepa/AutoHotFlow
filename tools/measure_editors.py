"""WI-0092 task 3 (REQ-PRF-030, E0040, MS-0006): memory of five open editors, and of the background processes with the
editors open. The editors are outside the budget (E0040); the numbers are recorded, and the background processes must not
grow when editors are open.

  python tools/measure_editors.py [--variants default,synthetic] [--runs 3] [--gap 20] [--out FILE]

Variants:
  default    the product editor (src/entry/editor.ahk): the element classes of the Default package.
  synthetic  the same editor entry plus the 150 synthetic element classes of MS-0033 (measure_r3.write_synthetic, the mode
             mix of synthetic_mode), so the editor parses 150 more classes, as in the role measurement.

Each run: a supervisor with storage, engine, triggerhost and manager (all headless, the manager without window), then five
editors started with the command line the supervisor gives an editor, plus --headless, on five flows: skeleton (3
elements), Flow 464187831 (3), Flow 2052424815 (6), Flow 1384439262 (129) and a generated flow of 300 elements (a trigger
and 299 actions). Private bytes of the editor processes and of the background processes are sampled 3 s after all five
editors answered their state (sample 1), and again --gap seconds later (sample 2). The background processes are sampled
once more before the editors start, so the growth with open editors is visible.

Results are printed as JSON lines (`MEM5 {...}`) and, with --out, appended to FILE. Run it alone on the machine: the numbers
are measurements. Headless only: the window of an editor adds its own cost, measured by the owner (manual check 9).
"""

import argparse
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
sys.path.insert(0, str(Path(__file__).resolve().parent))

import measure_r3 as r3  # noqa: E402  (synthetic classes, memory and statistics helpers of WI-0046)
from faultkit import AHKRUN, HEADLESS_OPTS, Chain  # noqa: E402
from support.flowbuilder import FlowBuilder  # noqa: E402
from support.procs import ProcessTracker  # noqa: E402

V1_FLOWS = ROOT / "tests" / "data" / "flows" / "v1_examples"
EDITOR_ENTRY = ROOT / "src" / "entry" / "editor.ahk"
BACKGROUND = ["storage", "engine", "triggerhost", "manager"]
EDITOR_FLOWS = ["skeleton", "Flow 464187831", "Flow 2052424815", "Flow 1384439262", "editors300"]
GENERATED = "editors300"
SYNTHETIC_COUNT = 150
SETTLE_S = 3.0


def write_flows(datadir):
    """The five flows of a run: three v1 examples (copied), the generated flow of 300 elements. skeleton comes with the
    chain (tests/data/skeleton_flow.json)."""
    flows = Path(datadir) / "Flows"
    flows.mkdir(parents=True, exist_ok=True)
    for name in ("Flow 464187831", "Flow 2052424815", "Flow 1384439262"):
        (flows / (name + ".json")).write_bytes((V1_FLOWS / (name + ".json")).read_bytes())
    fb = FlowBuilder("editors 300", flow_settings={})
    previous = fb.trigger()
    for _ in range(299):
        nxt = fb.action("Action_Do_nothing")
        fb.connect(previous, nxt)
        previous = nxt
    fb.write(datadir, GENERATED)


def editor_entry(variant, folder):
    """The entry of the editors: the product entry, or a copy of it with the synthetic classes included."""
    if variant == "default":
        return EDITOR_ENTRY
    Path(folder).mkdir(parents=True, exist_ok=True)
    files = [path for _, path in r3.write_synthetic(folder, SYNTHETIC_COUNT, mixed=True)]
    includes = r3.synthetic_includes(folder, files)
    lines = ["#Requires AutoHotkey v2.0", "#SingleInstance Off", "#NoTrayIcon",
             "#Include %s" % (ROOT / "src" / "AhfBoot.ahk"),
             "#Include %s" % (ROOT / "src" / "editor" / "Editor.ahk"),
             "#Include %s" % (ROOT / "src" / "entry" / "generated" / "Elements_editor.ahk"),
             *includes, 'RoleRegistry.Register("editor", Editor)', "AhfMain()", ""]
    entry = Path(folder) / "EditorSynthetic.ahk"
    entry.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return entry


def editor_state(obs, flow):
    try:
        ans = obs.request("editor:" + flow, "cmd.test.state", {}, timeout=5)
    except Exception:
        return None
    payload = ans["payload"]
    return payload["state"] if payload.get("ok") else None


def ahk_process_of(popen, flow):
    """The AutoHotkey process of one editor: the child of the ahkrun wrapper whose command line names the flow."""
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        try:
            kids = psutil.Process(popen.pid).children(recursive=True)
        except psutil.Error:
            kids = []
        for kid in kids:
            try:
                if ("--flow=" + flow) in " ".join(kid.cmdline()):
                    return kid.pid
            except psutil.Error:
                pass
        time.sleep(0.1)
    raise RuntimeError("no AutoHotkey process found for editor %s" % flow)


def sample(background_pids, editor_pids):
    """Private bytes (MB) of the background processes and of each editor process."""
    background = {name: r3.mem(pid)["private_mb"] for name, pid in background_pids.items()}
    editors = {flow: r3.mem(pid)["private_mb"] for flow, pid in editor_pids.items()}
    return {"background": background, "background_sum": round(sum(background.values()), 2),
            "editors": editors, "editors_sum": round(sum(editors.values()), 2)}


def one_run(variant, entry, procs, datadir, gap):
    session = "me" + uuid.uuid4().hex[:10]
    write_flows(datadir)
    chain = Chain(procs, datadir, session, ",".join(BACKGROUND), HEADLESS_OPTS, run_timeout=600)
    result = {"variant": variant}
    try:
        chain.wait_ready(BACKGROUND, timeout=120)
        time.sleep(SETTLE_S)
        states = chain.states()
        background_pids = {"supervisor": chain.sup.ahk_pid()}
        background_pids.update({name: states[name]["pid"] for name in BACKGROUND})
        result["before"] = sample(background_pids, {})
        popens = {}
        for flow in EDITOR_FLOWS:
            popens[flow] = procs.start([sys.executable, str(AHKRUN), "--timeout", "600", str(entry),
                                        "--role=editor", "--flow=" + flow, "--session=" + session,
                                        "--hub=" + chain.sup.pipe, "--data=" + str(datadir), "--headless"],
                                       stdout=None, stderr=None)
        deadline = time.monotonic() + 120
        loaded = {}  # flow -> state of the editor when it first answered with its document
        for flow in EDITOR_FLOWS:
            while time.monotonic() < deadline:
                st = editor_state(chain.obs, flow)
                if st and st.get("rev", -1) >= 1 and st.get("elements", 0) > 0:
                    loaded[flow] = st
                    break
                time.sleep(0.2)
        assert set(loaded) == set(EDITOR_FLOWS), "editors not loaded: %s" % sorted(set(EDITOR_FLOWS) - set(loaded))
        result["elements"] = {flow: loaded[flow]["elements"] for flow in EDITOR_FLOWS}
        time.sleep(SETTLE_S)
        editor_pids = {flow: ahk_process_of(popens[flow], flow) for flow in EDITOR_FLOWS}
        result["sample1"] = sample(background_pids, editor_pids)
        time.sleep(gap)
        result["sample2"] = sample(background_pids, editor_pids)
        result["background_pids_unchanged"] = {n: chain.states()[n]["pid"] for n in BACKGROUND} == {
            n: background_pids[n] for n in BACKGROUND}
        return result
    finally:
        chain.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--variants", default="default,synthetic")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--gap", type=float, default=20.0)
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    base = Path(tempfile.mkdtemp(prefix="ahf-measure-editors-"))
    for run in range(args.runs):
        for variant in args.variants.split(","):
            procs = ProcessTracker()
            try:
                folder = base / ("%s-%d" % (variant, run))
                folder.mkdir(parents=True)
                entry = editor_entry(variant, folder / "entry")
                result = one_run(variant, entry, procs, folder / "data", args.gap)
                r3.emit(args.out, {"run": run, **result})
            finally:
                procs.close()


if __name__ == "__main__":
    main()
