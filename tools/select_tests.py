"""Shows which tests a change selects, and what that costs (doc/TEST-GROUPS.md).

Usage:
    python tools/select_tests.py [--from REF | PATH ...] [--time]
    python tools/select_tests.py --simulate

    python tools/select_tests.py src/core/GuiLayout.ahk        # a hypothetical change: areas, groups, smoke tests
    python tools/select_tests.py --from v2-port --time         # what your working tree changed since v2-port
    python tools/select_tests.py --time src/engine/Executor.ahk
    python tools/select_tests.py --simulate                    # the table of EXAMPLES below

Without --time it prints the area of every path, the selected test groups, test files and smoke tests. With --time
it also lets pytest collect the selected tests (nothing runs) and adds their number and the summed time. The time of a
test is its median over the newest 15 passed runs in the test history (temp/history, tests/support/history.py); the
sum is the work of all tests added up, not the wall clock time (xdist runs several tests at the same time). The full
set for the percentages is every test of `--all` except gui, stress, soak and idle tests. A test without history counts
as 0 s (the output says how many).
--simulate runs the EXAMPLES (hypothetical changes) through the same steps and prints one table; keep EXAMPLES
current when you add a kind of source file.
"""

import argparse
import collections
import os
import statistics
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tests"))

from support import groups, history  # noqa: E402

HISTORY_RECORDS = 600       # newest records to read
OBSERVATIONS = 15           # passed runs per test that the median is taken from
FULL_SET = ["--all", "-m", "not gui and not stress and not soak and not idle"]

# Hypothetical changes for --simulate: (label, paths). One typical file per kind of source file.
EXAMPLES = [
    ("GuiLayout.ahk (ui)", ["src/core/GuiLayout.ahk"]),
    ("UiWindow.ahk (ui)", ["src/ui_common/UiWindow.ahk"]),
    ("new element without COVERS entry", ["src/elements/Default/Triggers/Trigger_Manual.ahk"]),
    ("Action_Sleep.ahk (action)", ["src/elements/Default/Actions/Action_Sleep.ahk"]),
    ("Action_Message_Box.ahk (action, dialog)", ["src/elements/Default/Actions/Action_Message_Box.ahk"]),
    ("Action_Add_To_List.ahk (action, list)", ["src/elements/Default/Actions/Action_Add_To_List.ahk"]),
    ("Condition_List_Contains_Element.ahk", ["src/elements/Default/Conditions/Condition_List_Contains_Element.ahk"]),
    ("Loop_SimpleLoop.ahk (loop)", ["src/elements/Default/Loops/Loop_SimpleLoop.ahk"]),
    ("Loop_Parse_A_String.ahk (loop)", ["src/elements/Default/Loops/Loop_Parse_A_String.ahk"]),
    ("Trigger_Periodic_Timer.ahk (trigger)", ["src/elements/Default/Triggers/Trigger_Periodic_Timer.ahk"]),
    ("Trigger_Hotkey.ahk (trigger)", ["src/elements/Default/Triggers/Trigger_Hotkey.ahk"]),
    ("ListOps.ahk (element library)", ["src/elements/Default/lib/ListOps.ahk"]),
    ("LoopOps.ahk (element library)", ["src/elements/Default/lib/LoopOps.ahk"]),
    ("ElementRunner.ahk (elements-base)", ["src/elements/base/ElementRunner.ahk"]),
    ("_includes_engine.ahk (element package)", ["src/elements/Default/_includes_engine.ahk"]),
    ("ExprEvaluator.ahk (expr)", ["src/expr/ExprEvaluator.ahk"]),
    ("Executor.ahk (engine)", ["src/engine/Executor.ahk"]),
    ("VarWriter.ahk (variables)", ["src/engine/vars/VarWriter.ahk"]),
    ("WorkerBridge.ahk (workers)", ["src/engine/WorkerBridge.ahk"]),
    ("Frame.ahk (transport)", ["src/core/ipc/Frame.ahk"]),
    ("Hub.ahk (supervisor)", ["src/supervisor/Hub.ahk"]),
    ("Stall.ahk (recovery)", ["src/supervisor/Stall.ahk"]),
    ("DiagReport.ahk (diagnosis)", ["src/supervisor/DiagReport.ahk"]),
    ("Storage.ahk (storage)", ["src/storage/Storage.ahk"]),
    ("TriggerHost.ahk (triggers)", ["src/triggerhost/TriggerHost.ahk"]),
    ("ManagerOps.ahk (manager)", ["src/manager/ManagerOps.ahk"]),
    ("Tray.ahk (tray)", ["src/tray/Tray.ahk"]),
    ("Lang.ahk (lang)", ["src/core/Lang.ahk"]),
    ("Ids.ahk (util)", ["src/core/Ids.ahk"]),
    ("Errors.ahk (base-hub)", ["src/core/Errors.ahk"]),
    ("tools/verify.py", ["tools/verify.py"]),
    ("tools/ahkrun.py", ["tools/ahkrun.py"]),
    ("doc/REQUIREMENTS.md", ["doc/REQUIREMENTS.md"]),
    ("GuiLayout.ahk + Executor.ahk", ["src/core/GuiLayout.ahk", "src/engine/Executor.ahk"]),
]


def collect(args):
    """The ids of the tests that `pytest tests --collect-only -q` finds with the given extra arguments."""
    cmd = [sys.executable, "-m", "pytest", "tests", "--collect-only", "-q", "-n", "0", *args]
    env = dict(os.environ, AHF_NO_ADMISSION="1")
    out = subprocess.run(cmd, cwd=str(REPO), capture_output=True, env=env).stdout.decode("utf-8", "replace")
    return [line.strip() for line in out.splitlines() if "::" in line]


def medians():
    """Test id -> median duration over the newest passed runs of the history."""
    folder = history.history_dir_to_read(REPO)
    seen = collections.defaultdict(list)
    for record in reversed(history.load_records(folder)[-HISTORY_RECORDS:]):
        for test in record.get("tests", []):
            durations = seen[test["id"].split("@")[0]]
            if len(durations) < OBSERVATIONS and test.get("outcome") == "passed":
                durations.append(test["duration"])
    return {key: statistics.median(values) for key, values in seen.items() if values}


def cost(ids, known):
    return sum(known.get(i, 0.0) for i in ids), sum(1 for i in ids if i not in known)


def selected_ids(paths):
    return collect(["--changed-paths", ",".join(paths)])


def simulate(examples):
    known = medians()
    if not known:
        print("no test history found (%s): the table has no times" % history.history_dir_to_read(REPO))
    full = collect(FULL_SET)
    total, unknown = cost(full, known)
    print("full set: %d tests, %.0f s summed (%d without history); history of %d tests" % (
        len(full), total, unknown, len(known)))
    print("%-44s %6s %8s %7s" % ("change", "tests", "sum s", "% full"))
    for label, paths in examples:
        ids = selected_ids(paths)
        seconds, _ = cost(ids, known)
        print("%-44s %6d %8.0f %6.1f%%" % (label, len(ids), seconds, 100.0 * seconds / total if total else 0))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("paths", nargs="*", help="repo-relative paths of a hypothetical change")
    parser.add_argument("--from", dest="ref", default=None, help="the files that differ from REF in the working tree")
    parser.add_argument("--time", action="store_true", help="collect with pytest and add the number and cost of the tests")
    parser.add_argument("--simulate", action="store_true", help="print the table of the EXAMPLES")
    args = parser.parse_args(argv)
    if args.simulate:
        simulate(EXAMPLES)
        return 0
    if bool(args.paths) == bool(args.ref):
        parser.error("give paths, --from REF or --simulate")
    paths = groups.changed_paths(args.ref) if args.ref else [p.replace("\\", "/") for p in args.paths]
    if not paths:
        print("no changed files")
        return 0
    try:
        sel = groups.select(paths)
    except groups.UnknownPathError as e:       # an error, not a full run: the message says what to add
        print("select_tests: %s" % e, file=sys.stderr)
        return 2
    print("\n".join(groups.describe(sel)))
    if args.time:
        known = medians()
        ids = selected_ids(paths)
        seconds, unknown = cost(ids, known)
        print("pytest: %d tests, %.0f s summed (%d without history)" % (len(ids), seconds, unknown))
    return 0


if __name__ == "__main__":
    sys.exit(main())
