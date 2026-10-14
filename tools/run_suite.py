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
  * limits the load: pytest gets --workers N (default 4) worker processes, at most --max-runs (default 2) runs go at
    the same time, a run that asks for stress or soak tests (-m stress / -m soak) waits until no other run is active
    and blocks the start of others while it measures,
  * keeps the result in <temp>\\ahf_runs\\<id>\\: output.txt (everything pytest printed), result.json, and
    pytest-log\\ (the run log of tests/conftest.py: summary, failures, data of failed tests). The last 20 runs are kept.

Exit code: the one of pytest (0 = all passed), 70 = the tool itself failed (git, worktree, patch).
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
import tempfile
import time
from pathlib import Path

import psutil

REPO = Path(__file__).resolve().parents[1]
KEEP_RUNS = 20
EXIT_TOOL_FAILED = 70
EXCLUSIVE_MARKERS = ("stress", "soak")


class ToolError(Exception):
    pass


def git(*args, cwd=REPO, check=True, input_bytes=None):
    proc = subprocess.run(["git", *args], cwd=str(cwd), input=input_bytes, capture_output=True)
    if check and proc.returncode != 0:
        raise ToolError("git %s failed (%d): %s" % (" ".join(args), proc.returncode,
                                                  proc.stderr.decode("utf-8", "replace").strip()))
    return proc.stdout


def runs_dir():
    return Path(os.environ.get("AHF_RUNS_DIR") or Path(tempfile.gettempdir()) / "ahf_runs")


def is_exclusive(pytest_args):
    """True when the run asks for stress or soak tests with -m (measurements need an idle machine)."""
    args = list(pytest_args)
    for i, arg in enumerate(args):
        expr = None
        if arg == "-m" and i + 1 < len(args):
            expr = args[i + 1]
        elif arg.startswith("-m") and len(arg) > 2:
            expr = arg[2:]
        if expr and any(re.search(r"\b%s\b" % m, expr) for m in EXCLUSIVE_MARKERS):
            return True
    return False


# --- registry of the runs (status.json per run folder) ------------------------------------------------

def _alive(info):
    try:
        proc = psutil.Process(info["pid"])
        return abs(proc.create_time() - info["pidCreated"]) < 1.0
    except (psutil.Error, KeyError, TypeError):
        return False


def active_runs(base, exclude=None):
    found = []
    for status in base.glob("*/status.json"):
        if exclude is not None and status.parent == exclude:
            continue
        try:
            info = json.loads(status.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if info.get("state") == "running" and _alive(info):
            info["dir"] = str(status.parent)
            found.append(info)
    return found


def write_status(run_dir, **fields):
    path = run_dir / "status.json"
    try:
        info = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        info = {}
    info.update(fields)
    path.write_text(json.dumps(info, indent=2), encoding="utf-8")


class Admission:
    """Check-and-register under a short lock file, so two starts cannot both pass the check."""

    def __init__(self, base):
        self.path = base / "admission.lock"

    def __enter__(self):
        deadline = time.time() + 15
        while True:
            try:
                self.fd = os.open(str(self.path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                return self
            except FileExistsError:
                try:
                    if time.time() - self.path.stat().st_mtime > 30:     # left behind by a crashed tool
                        self.path.unlink()
                        continue
                except OSError:
                    pass
                if time.time() > deadline:
                    raise ToolError("admission lock %s is held" % self.path)
                time.sleep(0.1)

    def __exit__(self, *exc):
        os.close(self.fd)
        try:
            self.path.unlink()
        except OSError:
            pass


def admit(base, run_dir, exclusive, max_runs, info, wait_log):
    """Waits until the run may start, then registers it as running."""
    last_msg = 0.0
    while True:
        with Admission(base):
            others = active_runs(base, exclude=run_dir)
            blocked = None
            if any(o.get("exclusive") for o in others):
                blocked = "a measurement run is active"
            elif exclusive and others:
                blocked = "%d other run(s) are active (a measurement needs an idle machine)" % len(others)
            elif len(others) >= max_runs:
                blocked = "%d run(s) are active (limit --max-runs %d)" % (len(others), max_runs)
            if blocked is None:
                write_status(run_dir, **info, state="running", pid=os.getpid(),
                             pidCreated=psutil.Process().create_time())
                return
        if time.time() - last_msg > 30:
            wait_log("waiting: " + blocked)
            last_msg = time.time()
        time.sleep(1.0)


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

    info = {"id": run_id, "ref": args.ref, "sha": sha, "withChanges": args.with_changes, "exclusive": exclusive,
            "pytestArgs": pytest_args, "workers": args.workers, "started": time.strftime("%Y-%m-%d %H:%M:%S")}
    say("%s%s  (%s)" % (label, " + uncommitted changes" if args.with_changes else "", run_id))
    exit_code = EXIT_TOOL_FAILED
    child = None
    try:
        admit(base, run_dir, exclusive, args.max_runs, info, say)
        make_worktree(tree, sha, args.with_changes)
        env = dict(os.environ)
        env["AHF_TEST_LOGS"] = str(log_dir)
        env["PYTHONUNBUFFERED"] = "1"
        cmd = [sys.executable, "-m", "pytest", "-n", str(args.workers), *pytest_args]
        say("pytest %s  (workers %d, cwd %s)" % (" ".join(cmd[3:]), args.workers, tree))
        with open(output, "wb") as out:
            child = subprocess.Popen(cmd, cwd=str(tree), env=env, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            for chunk in iter(child.stdout.readline, b""):
                out.write(chunk)
                out.flush()
                sys.stdout.write(chunk.decode("utf-8", "replace"))
                sys.stdout.flush()
            exit_code = child.wait()
    except KeyboardInterrupt:
        say("interrupted")
        if child is not None:
            kill_tree(child.pid)
        exit_code = 130
    except ToolError as e:
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
    if tree.exists():
        say("worktree kept: %s%s" % (tree, "" if args.keep else "  (could not be removed, remove it by hand)"))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
