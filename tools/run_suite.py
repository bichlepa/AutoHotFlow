"""Runs the pytest suite on a frozen code state in its own git worktree, so you can keep working meanwhile.

Usage:
    python tools/run_suite.py [options] [-- pytest arguments]

    python tools/run_suite.py                           # HEAD, default arguments: tests -q
    python tools/run_suite.py --with-changes            # HEAD plus the uncommitted changes of the working tree
    python tools/run_suite.py --ref v2-phase2-final -- tests/integration -q --all
    python tools/run_suite.py -- tests -q --all -m "stress"      # measurement: waits until nothing else runs

What it does:
  * creates a detached worktree of the commit (and, with --with-changes, applies the tracked changes of the working
    tree and copies the untracked files that are not ignored), runs pytest there and removes the worktree again.
    A file that is neither in the commit nor in the changes is not there: a test that needs it fails here, not
    only on someone else's machine,
  * limits the load through the machine-wide admission (tests/support/admission.py, shared with direct pytest runs):
    pytest gets --workers N (default 4) worker processes, fewer when the other runs hold the free worker slots
    (AHF_MAX_WORKERS), at most --max-runs (default 2) runs of run_suite go at the same time, a run that asks for
    stress, soak or idle tests (-m stress / -m soak / -m idle; admission.selects_exclusive) waits until no other run is
    active and blocks the start of others while it measures. The pytest run inside registers no second time
    (AHF_ADMITTED),
  * keeps the result in <temp>\\ahf_runs\\<id>\\: output.txt (everything pytest printed), status.json, and
    pytest-log\\ (the run log of tests/conftest.py: summary, failures, data of failed tests). The last 20 runs are kept.

  * watches for a stalled run: when neither the output nor live.log of the run log (written by tests/conftest.py at
    every test phase) grows for --stall-timeout seconds (default 300; 1800 for stress/soak/idle runs; 0 = off), the
    tool writes stall.txt (process tree, last line of every worker, end of live.log), kills the process tree and
    exits with 76. This covers hangs outside a test too (collection, start of the workers, teardown, end of the run).
    A test that legitimately needs longer without any phase change must carry a higher --stall-timeout.
  * does not wait for the pipe of pytest after pytest has ended: an orphaned child process that inherited it would
    keep it open for ever. Processes that still run from the worktree are killed.

Exit code: the one of pytest (0 = all passed), 70 = the tool itself failed (git, worktree, patch), 75 = the admission
gave up (AHF_ADMISSION_TIMEOUT), 76 = the run stalled and was killed.
Not covered: runs of different checkouts share the machine (pipe names, CPU), and timing tests (scaled()) can
become flaky when the machine is loaded; use --max-runs 1 for a clean comparison.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

import psutil

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tests"))

from support.admission import (Admission, AdmissionError, AdmissionTimeout, EXIT_ADMISSION_TIMEOUT,  # noqa: E402,F401
                               _alive, active_runs, admission_timeout, admit, is_exclusive, read_status,
                               runs_dir, write_status)

KEEP_RUNS = 20
EXIT_TOOL_FAILED = 70
EXIT_STALLED = 76
STALL_DEFAULT = 300             # seconds without new output or live.log lines
STALL_DEFAULT_EXCLUSIVE = 1800  # stress, soak and idle tests run long without phase changes


class ToolError(Exception):
    pass


def git(*args, cwd=REPO, check=True, input_bytes=None):
    proc = subprocess.run(["git", *args], cwd=str(cwd), input=input_bytes, capture_output=True)
    if check and proc.returncode != 0:
        raise ToolError("git %s failed (%d): %s" % (" ".join(args), proc.returncode,
                                                  proc.stderr.decode("utf-8", "replace").strip()))
    return proc.stdout


# --- worktree -----------------------------------------------------------------------------------------

def make_worktree(tree, sha, with_changes):
    git("worktree", "add", "--detach", "--quiet", str(tree), sha)
    if not with_changes:
        return
    patch = git("diff", "--binary", "HEAD")
    if patch.strip():
        proc = subprocess.run(["git", "apply", "--whitespace=nowarn", "-"], cwd=str(tree), input=patch,
                              capture_output=True)
        if proc.returncode != 0:
            raise ToolError("the changes do not apply to the worktree: " + proc.stderr.decode("utf-8", "replace"))
    names = git("ls-files", "--others", "--exclude-standard", "-z").split(b"\0")
    for raw in names:
        if not raw:
            continue
        rel = raw.decode("utf-8", "surrogateescape")
        src, dst = REPO / rel, tree / rel
        if src.is_file():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)


def remove_worktree(tree):
    for attempt in range(5):
        proc = subprocess.run(["git", "worktree", "remove", "--force", str(tree)], cwd=str(REPO), capture_output=True)
        if proc.returncode == 0 or not tree.exists():
            break
        time.sleep(1.0)
    if tree.exists():
        shutil.rmtree(tree, ignore_errors=True)
    subprocess.run(["git", "worktree", "prune"], cwd=str(REPO), capture_output=True)
    return not tree.exists()


def prune_old_runs(base, keep_dir):
    runs = sorted((p for p in base.iterdir() if p.is_dir() and (p / "status.json").exists()), key=lambda p: p.name)
    running = {Path(i["dir"]) for i in active_runs(base)}
    for old in runs[:-KEEP_RUNS]:
        if old != keep_dir and old not in running:
            shutil.rmtree(old, ignore_errors=True)


# --- run ----------------------------------------------------------------------------------------------

def kill_tree(pid):
    try:
        parent = psutil.Process(pid)
        for p in parent.children(recursive=True) + [parent]:
            try:
                p.kill()
            except psutil.Error:
                pass
    except psutil.Error:
        pass


def kill_leftovers(tree):
    """Kills processes that still run from the worktree (command line contains its path): orphans of the test run
    hold the pipe of pytest and block the removal of the worktree."""
    marker = str(tree).lower()
    killed = 0
    for p in psutil.process_iter(["pid", "cmdline"]):
        try:
            if p.pid != os.getpid() and marker in " ".join(p.info["cmdline"] or []).lower():
                p.kill()
                killed += 1
        except psutil.Error:
            pass
    return killed


def live_logs(log_dir):
    return list(log_dir.glob("*/live.log")) if log_dir.is_dir() else []


def last_activity(log_dir, seen):
    """Newest of: the last output of pytest (`seen`) and the modification time of live.log."""
    latest = seen
    for f in live_logs(log_dir):
        try:
            latest = max(latest, f.stat().st_mtime)
        except OSError:
            pass
    return latest


def stall_report(pid, log_dir, idle):
    lines = ["no output and no live.log line for %d s" % idle, "", "process tree of pytest (pid %d):" % pid]
    try:
        root = psutil.Process(pid)
        for p in [root] + root.children(recursive=True):
            try:
                lines.append("  %6d  %s" % (p.pid, " ".join(p.cmdline())[:200]))
            except psutil.Error:
                pass
    except psutil.Error:
        lines.append("  (gone)")
    for f in live_logs(log_dir):
        text = f.read_text(encoding="utf-8", errors="replace").splitlines()
        last = {}
        for line in text:
            parts = line.split(None, 2)
            if len(parts) == 3:
                last[parts[1]] = line
        lines += ["", "last line of every process (%s):" % f] + ["  " + v for v in last.values()]
        lines += ["", "end of live.log:"] + ["  " + t for t in text[-30:]]
    return "\n".join(lines) + "\n"


def summary_line(output_path):
    """The last line of the pytest output that looks like '12 passed, 1 failed in 3.4s'."""
    try:
        lines = output_path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    for line in reversed(lines[-40:]):
        if re.search(r"\b(passed|failed|error|errors|no tests ran|deselected)\b.*\bin\b [\d.]+s", line):
            return line.strip("= ").strip()
    return ""


def show_status(base):
    if not base.is_dir():
        print("no runs yet (%s)" % base)
        return 0
    for status in sorted(base.glob("*/status.json"))[-15:]:
        try:
            info = json.loads(status.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        state = info.get("state")
        if state == "running" and not _alive(info):
            state = "aborted"
        print("%-34s %-8s exit=%-4s %s" % (status.parent.name, state, info.get("exitCode", "-"),
                                            info.get("summary", "")))
    return 0


def new_run_dir(base, stem):
    """Creates the folder of a new run and returns (run id, folder). Two runs of the same commit started in the same
    second would get the same id; the second then found the worktree of the first, failed, and removed that worktree
    in its cleanup, so the first ran no tests. The folder is created exclusively; a taken id gets a suffix -2, -3..."""
    base.mkdir(parents=True, exist_ok=True)
    n = 1
    while True:
        run_id = stem if n == 1 else "%s-%d" % (stem, n)
        run_dir = base / run_id
        try:
            run_dir.mkdir()
            return run_id, run_dir
        except FileExistsError:
            n += 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0], add_help=True)
    parser.add_argument("--ref", default="HEAD", help="commit, branch or tag to test (default HEAD)")
    parser.add_argument("--with-changes", action="store_true",
                        help="HEAD plus the uncommitted changes (tracked) and the untracked, not ignored files")
    parser.add_argument("--workers", type=int, default=4, help="pytest-xdist workers (default 4; 0 = serial)")
    parser.add_argument("--max-runs", type=int, default=2, help="runs at the same time on this machine (default 2)")
    parser.add_argument("--stall-timeout", type=int, default=None, metavar="S",
                        help="kill the run when neither its output nor its live.log grows for S seconds (default "
                             "%d, %d for stress/soak/idle runs, 0 = off)" % (STALL_DEFAULT, STALL_DEFAULT_EXCLUSIVE))
    parser.add_argument("--keep", action="store_true", help="keep the worktree (for debugging, remove it yourself)")
    parser.add_argument("--status", action="store_true", help="list the last runs and exit")
    parser.add_argument("pytest_args", nargs="*", help="after --: arguments for pytest (default: tests -q)")
    args = parser.parse_args(argv)

    base = runs_dir()
    if args.status:
        return show_status(base)
    pytest_args = args.pytest_args or ["tests", "-q"]
    if args.with_changes and args.ref != "HEAD":
        print("--with-changes only works with --ref HEAD", file=sys.stderr)
        return EXIT_TOOL_FAILED

    try:
        sha = git("rev-parse", "--verify", args.ref + "^{commit}").decode().strip()
        label = git("log", "-1", "--format=%h %s", sha).decode().strip()
    except ToolError as e:
        print("tool error: %s" % e, file=sys.stderr)
        return EXIT_TOOL_FAILED

    run_id, run_dir = new_run_dir(base, "%s-%s%s" % (time.strftime("%Y%m%d-%H%M%S"), sha[:8],
                                                     "-wc" if args.with_changes else ""))
    tree = run_dir / "tree"
    log_dir = run_dir / "pytest-log"
    output = run_dir / "output.txt"
    exclusive = is_exclusive(pytest_args)

    def say(text):
        print("[run_suite] " + text, flush=True)

    info = {"id": run_id, "tool": "run_suite", "ref": args.ref, "sha": sha, "withChanges": args.with_changes,
            "pytestArgs": pytest_args, "started": time.strftime("%Y-%m-%d %H:%M:%S")}
    say("%s%s  (%s)" % (label, " + uncommitted changes" if args.with_changes else "", run_id))
    exit_code = EXIT_TOOL_FAILED
    child = None
    try:
        workers, _ = admit(base, run_dir, info, requested=args.workers, exclusive=exclusive, say=say,
                           max_runs=args.max_runs, timeout=admission_timeout())
        make_worktree(tree, sha, args.with_changes)
        env = dict(os.environ)
        env["AHF_TEST_LOGS"] = str(log_dir)
        env["PYTHONUNBUFFERED"] = "1"
        env["AHF_ADMITTED"] = run_id            # the conftest inside registers no second time
        cmd = [sys.executable, "-m", "pytest", "-n", str(workers), *pytest_args]
        say("pytest %s  (workers %d, cwd %s)" % (" ".join(cmd[3:]), workers, tree))
        stall_limit = args.stall_timeout
        if stall_limit is None:
            stall_limit = STALL_DEFAULT_EXCLUSIVE if exclusive else STALL_DEFAULT
        with open(output, "wb") as out:
            child = subprocess.Popen(cmd, cwd=str(tree), env=env, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            seen = [time.time()]

            def pump():
                for chunk in iter(child.stdout.readline, b""):
                    seen[0] = time.time()
                    out.write(chunk)
                    out.flush()
                    sys.stdout.write(chunk.decode("utf-8", "replace"))
                    sys.stdout.flush()

            reader = threading.Thread(target=pump, daemon=True)
            reader.start()
            stalled = False
            while child.poll() is None:
                time.sleep(1.0)
                idle = time.time() - last_activity(log_dir, seen[0])
                if stall_limit and idle > stall_limit:
                    stalled = True
                    report = stall_report(child.pid, log_dir, idle)
                    (run_dir / "stall.txt").write_text(report, encoding="utf-8")
                    say("STALLED: %s" % report.splitlines()[0])
                    say("details: %s" % (run_dir / "stall.txt"))
                    kill_tree(child.pid)
                    break
            exit_code = EXIT_STALLED if stalled else child.wait()
            reader.join(5.0)        # pytest has ended: only an orphan that holds the pipe can keep it open
            if reader.is_alive():
                say("the output pipe is still open after pytest ended (an orphaned child process holds it)")
            leftovers = kill_leftovers(tree)
            if leftovers:
                say("killed %d process(es) that still ran from the worktree" % leftovers)
    except KeyboardInterrupt:
        say("interrupted")
        if child is not None:
            kill_tree(child.pid)
        exit_code = 130
    except AdmissionTimeout as e:
        say("admission: %s" % e)
        exit_code = EXIT_ADMISSION_TIMEOUT
    except (ToolError, AdmissionError) as e:
        say("tool error: %s" % e)
        exit_code = EXIT_TOOL_FAILED
    finally:
        removed = True
        if tree.exists() and not args.keep:
            removed = remove_worktree(tree)
        text = summary_line(output)
        try:
            write_status(run_dir, state="finished", exitCode=exit_code, summary=text,
                         finished=time.strftime("%Y-%m-%d %H:%M:%S"), worktreeKept=tree.exists())
            prune_old_runs(base, run_dir)
        except OSError:
            pass
    say("result: exit %d  %s" % (exit_code, text))
    say("output: %s" % output)
    if log_dir.exists():
        say("run log (summary, failures, data of failed tests): %s" % log_dir)
    history_file = read_status(run_dir).get("historyFile")
    if history_file:
        say("history: %s" % history_file)
    if tree.exists():
        say("worktree kept: %s%s" % (tree, "" if args.keep else "  (could not be removed, remove it by hand)"))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
