"""Data folder and start of the application for the manual checks of the project owner (doc/MANUAL-CHECKS.md).

    python tools/manual_check.py prepare [--flow <name>] a fresh data folder with the skeleton flow
    python tools/manual_check.py start [--fresh] [--flow <name>] [-- <options of AutoHotFlow.ahk>]

The manual checks run in their own data folder (default %TEMP%\\ahf_manual_check) and their own session
("manual"), so they neither touch the default folder %APPDATA%\\AutoHotFlow v2 nor meet an instance that runs
for something else. "prepare" empties the folder and copies tests/data/skeleton_flow.json to Flows\\skeleton.json.
It deletes only a folder that it created itself (marker file .ahf_manual_check) or an empty one.

"--flow <name>" copies the manual-check flow tests/data/manual/<name>.json to Flows\\<name>.json. It implies a fresh
folder (prepared as above, then the flow is copied in). A companion `<name>.state.json` next to it is copied to
FlowStates\<name>.json, which enables the triggers of the flow at the start. The tool does not start the flow: the
owner starts it in the manager (Run button), where the flow is listed under its name.

"start" starts src/AutoHotFlow.ahk with --session=manual --data=<folder> and the given options, waits without a
timeout until the application ends, and prints its exit code (the VS Code task terminal does not show an exit code
of 0). With --fresh it prepares the folder first; a missing folder is always prepared. A second start with
"-- --command=debug" reaches the running manual session.

This is a tool for the owner, who operates the windows: there is no dialog guard and no timeout (AGENTS.md
rule 10). Agents start AutoHotkey scripts with tools/ahkrun.py.

Exit codes: the exit code of the application for "start"; 0 done, 1 refused (the reason is printed),
2 usage error, 99 no interpreter.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tests", "support"))

from ahk import find_ahk_exe  # noqa: E402

SESSION = "manual"
MARKER = ".ahf_manual_check"
SKELETON = os.path.join(ROOT, "tests", "data", "skeleton_flow.json")
FLOWS_DIR = os.path.join(ROOT, "tests", "data", "manual")
PRODUCT = os.path.join(ROOT, "src", "AutoHotFlow.ahk")


class Refused(Exception):
    pass


def default_dir():
    return os.path.join(os.environ.get("TEMP") or os.path.expanduser("~"), "ahf_manual_check")


def flow_source(name):
    """Path of the manual-check flow `name` (tests/data/manual/<name>.json). Refused for a name that is not a plain
    word or that has no file."""
    if not re.fullmatch(r"[a-z0-9_]+", name or ""):
        raise Refused("flow name '%s' must be lower case letters, digits or underscores" % name)
    path = os.path.join(FLOWS_DIR, name + ".json")
    if not os.path.isfile(path):
        known = sorted(f[:-5] for f in os.listdir(FLOWS_DIR)
                       if f.endswith(".json") and not f.endswith(".state.json")) if os.path.isdir(FLOWS_DIR) else []
        raise Refused("no manual-check flow '%s' (known: %s)" % (name, ", ".join(known) or "none"))
    return path


def prepare(folder, flow=None):
    """Empties the folder (only one of ours or an empty one) and puts the skeleton flow into Flows\\skeleton.json, and
    the flow `flow` (a name, see flow_source) into Flows\\<flow>.json."""
    source = flow_source(flow) if flow else None
    if os.path.isdir(folder) and os.listdir(folder):
        if not os.path.isfile(os.path.join(folder, MARKER)):
            raise Refused("%s is not empty and was not made by this tool (no %s); not deleted" % (folder, MARKER))
        shutil.rmtree(folder)
    elif os.path.exists(folder) and not os.path.isdir(folder):
        raise Refused("%s is a file, not a folder" % folder)
    os.makedirs(os.path.join(folder, "Flows"), exist_ok=True)
    with open(os.path.join(folder, MARKER), "w", encoding="utf-8") as f:
        f.write("Data folder of the manual checks (tools/manual_check.py). It is deleted by 'prepare'.\n")
    shutil.copyfile(SKELETON, os.path.join(folder, "Flows", "skeleton.json"))
    if source:
        shutil.copyfile(source, os.path.join(folder, "Flows", flow + ".json"))
        # An optional companion <name>.state.json holds the enabled triggers of the flow (FlowStates, E0063), so that
        # the flow is enabled at the start without a click.
        state = os.path.join(FLOWS_DIR, flow + ".state.json")
        if os.path.isfile(state):
            os.makedirs(os.path.join(folder, "FlowStates"), exist_ok=True)
            shutil.copyfile(state, os.path.join(folder, "FlowStates", flow + ".json"))


def command_line(exe, folder, options):
    return [exe, "/ErrorStdOut=UTF-8", PRODUCT, "--session=" + SESSION, "--data=" + folder, *options]


def main(argv):
    options = []
    if "--" in argv:
        cut = argv.index("--")
        argv, options = argv[:cut], argv[cut + 1:]
    ap = argparse.ArgumentParser(description="Data folder and start of the application for the manual checks.")
    ap.add_argument("action", choices=["prepare", "start"])
    ap.add_argument("--dir", default=default_dir(), help="data folder (default: %%TEMP%%\\ahf_manual_check)")
    ap.add_argument("--fresh", action="store_true", help="start: prepare a fresh data folder first")
    ap.add_argument("--flow", help="copy the manual-check flow <name> (tests/data/manual/<name>.json) into a fresh folder")
    args = ap.parse_args(argv)
    if args.action == "prepare" and options:
        ap.error("prepare takes no options of AutoHotFlow.ahk")
    folder = os.path.abspath(args.dir)
    try:
        if args.action == "prepare" or args.fresh or args.flow or not os.path.isdir(folder):
            prepare(folder, args.flow)
            print("fresh data folder: %s (skeleton flow in Flows\\skeleton.json%s)" % (
                folder, ", flow %s in Flows\\%s.json" % (args.flow, args.flow) if args.flow else ""))
    except Refused as e:
        print("refused: %s" % e, file=sys.stderr)
        return 1
    if args.action == "prepare":
        return 0
    exe, reason = find_ahk_exe()
    if exe is None:
        print(reason, file=sys.stderr)
        return 99
    print("starting AutoHotFlow: session %s, data folder %s, options %s" % (SESSION, folder, " ".join(options) or "-"))
    sys.stdout.flush()
    code = subprocess.run(command_line(exe, folder, options), cwd=ROOT).returncode
    print("AutoHotFlow ended with exit code %d" % code)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
