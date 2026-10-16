"""Runs the red tests of one recorded test run again, once, serially and alone on the machine (WI-0059).

Usage:
    python tools/recheck.py <run id | latest> [--dry-run]

It takes the red tests (failed, error) of the run from the history (tools/test_history.py, temp/history/ of the main
checkout), waits for an idle machine (exclusive admission, as a -m stress run), and runs them in this checkout with
-n 0 and the tier options of the original run (--all, --foundation, -m). "latest" is the newest run with red tests that
is not a recheck itself.

Result per test: "green again" (consistent with a load-induced failure) or "red again" (a real defect or a problem of
the test: classify it as before). This is a defined second run under reference conditions, not a retry loop: the
first result stays in the history, and the recheck is a run of its own with its own record (field run.recheckOf).

Exit code: 0 every test green again, 1 a test red again or not run, 2 no such run / no red tests, 75 the admission
gave up (AHF_ADMISSION_TIMEOUT).
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tests"))

from support import admission, history  # noqa: E402

EXIT_RED_AGAIN = 1
EXIT_NOTHING = 2


def find_run(records, ref):
    if ref == "latest":
        for r in reversed(records):
            if not r["run"].get("recheckOf") and red_tests(r):
                return r
        return None
    matches = [r for r in records if r["run"].get("id") == ref]
    return matches[-1] if matches else None


def red_tests(record):
    return [i["id"] for i in record.get("tests") or [] if i["outcome"] in history.RED]


def tier_args(record):
    args = record["run"].get("args") or []
    out = [a for a in ("--all", "--foundation") if a in args]
    if record["run"].get("markexpr"):
        out += ["-m", record["run"]["markexpr"]]
    return out


def new_dir(base, stem):
    base.mkdir(parents=True, exist_ok=True)
    n = 1
    while True:
        run_id = stem if n == 1 else "%s-%d" % (stem, n)
        try:
            (base / run_id).mkdir()
            return run_id, base / run_id
        except FileExistsError:
            n += 1


def say(text):
    print("[recheck] " + text, flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("run", help="run id from the history, or 'latest'")
    parser.add_argument("--dry-run", action="store_true", help="only show what would run")
    args = parser.parse_args(argv)

    folder = history.history_dir_to_read(REPO)
    record = find_run(history.load_records(folder), args.run)
    if record is None:
        say("no run %s with red tests in %s" % (args.run, folder))
        return EXIT_NOTHING
    original = record["run"]["id"]
    tests = red_tests(record)
    if not tests:
        say("run %s has no red tests" % original)
        return EXIT_NOTHING
    say("run %s: %d red test(s), commit %s%s" % (original, len(tests), (record["code"].get("sha") or "-")[:8],
                                                 " + uncommitted changes" if record["code"].get("dirty") else ""))
    sha, _, _, _ = history.git_info(REPO)
    if sha != record["code"].get("sha") or history.git_dirty(REPO) or record["code"].get("dirty"):
        say("note: this checkout (%s%s) is not the clean code state of the run; the recheck tests this checkout"
            % ((sha or "-")[:8], " + uncommitted changes" if history.git_dirty(REPO) else ""))
    if args.dry_run:
        for t in tests:
            print("  " + t)
        return 0

    base = admission.runs_dir()
    run_id, run_dir = new_dir(base, "%s-recheck" % time.strftime("%Y%m%d-%H%M%S"))
    ids_file = run_dir / "nodeids.txt"
    ids_file.write_bytes(("\n".join(tests) + "\n").encode("utf-8"))
    info = {"id": run_id, "tool": "recheck", "recheckOf": original, "pytestArgs": tests,
            "started": time.strftime("%Y-%m-%d %H:%M:%S")}
    try:
        admission.admit(base, run_dir, info, requested=0, exclusive=True, say=say,
                        timeout=admission.admission_timeout())
    except admission.AdmissionTimeout as e:
        say(str(e))
        admission.finish(run_dir, exitCode=admission.EXIT_ADMISSION_TIMEOUT)
        return admission.EXIT_ADMISSION_TIMEOUT
    env = dict(os.environ, AHF_ADMITTED=run_id)
    cmd = [sys.executable, "-m", "pytest", "-n", "0", "-q", *tier_args(record), "@" + str(ids_file)]
    say("pytest %s" % " ".join(cmd[3:]))
    try:
        code = subprocess.run(cmd, cwd=str(REPO), env=env, stdin=subprocess.DEVNULL).returncode
    except KeyboardInterrupt:
        code = 130
    finally:
        admission.finish(run_dir)
    admission.write_status(run_dir, exitCode=code)

    folder = history.history_dir_to_read(REPO)        # the run may have created the default folder just now
    mine = [r for r in history.load_records(folder) if r["run"].get("id") == run_id]
    outcomes = {i["id"]: i["outcome"] for i in (mine[-1].get("tests") or [])} if mine else {}
    if not mine:
        say("the recheck wrote no history record (exit %d)" % code)
    worst = 0
    for t in tests:
        outcome = outcomes.get(t)
        if outcome == "passed":
            verdict = "green again (consistent with a load-induced failure)"
        elif outcome in history.RED:
            verdict = "red again (a real defect or a test problem: classify it as before)"
            worst = EXIT_RED_AGAIN
        else:
            verdict = "not run (%s)" % (outcome or "not selected")
            worst = EXIT_RED_AGAIN
        print("  %-60s %s" % (t, verdict))
    if mine:
        say("record: %s" % mine[-1]["_path"])
    return worst


if __name__ == "__main__":
    sys.exit(main())
