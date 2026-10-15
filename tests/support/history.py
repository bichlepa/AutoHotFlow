"""Run history (WI-0059 part C): one JSON file per pytest run, <timestamp>_<run id>.json.

Location: temp/history/ of the main checkout (the parent folder of `git rev-parse --git-common-dir`), so every
worktree of the repository writes to the same place. Fallback when there is no main checkout or it is not
writable: <AHF_RUNS_DIR>/history/. Override: AHF_HISTORY_DIR. Writing is atomic (temp file, rename); one file per
run needs no lock between parallel runs. tools/test_history.py and tools/recheck.py read these files.
"""

import json
import os
import subprocess
import time
from pathlib import Path

from support import admission

SCHEMA = 1
RED = ("failed", "error")


def git_info(cwd):
    """(commit, branch, top level, common dir) of the checkout at cwd; None fields when git fails."""
    try:
        proc = subprocess.run(["git", "rev-parse", "--show-toplevel", "--git-common-dir", "HEAD", "--abbrev-ref",
                               "HEAD"], cwd=str(cwd), capture_output=True, timeout=20)
        lines = proc.stdout.decode("utf-8", "replace").splitlines()
        if proc.returncode != 0 or len(lines) < 4:
            return None, None, None, None
        top, common, sha, branch = lines[:4]
        common_path = Path(common)
        if not common_path.is_absolute():
            common_path = Path(cwd) / common_path
        return sha, branch, str(Path(top)), str(common_path.resolve())
    except (OSError, subprocess.SubprocessError):
        return None, None, None, None


def git_dirty(cwd):
    """True when the checkout has uncommitted changes (tracked or untracked, not ignored); None when unknown."""
    try:
        proc = subprocess.run(["git", "status", "--porcelain"], cwd=str(cwd), capture_output=True, timeout=30)
        if proc.returncode != 0:
            return None
        return bool(proc.stdout.strip())
    except (OSError, subprocess.SubprocessError):
        return None


def _writable(folder):
    try:
        folder.mkdir(parents=True, exist_ok=True)
        probe = folder / (".probe-%d" % os.getpid())
        probe.write_bytes(b"")
        probe.unlink()
        return True
    except OSError:
        return False


def history_dir(cwd=None, common_dir=None):
    """The history folder for a checkout (see the module docstring). Creates it."""
    override = os.environ.get("AHF_HISTORY_DIR")
    if override:
        folder = Path(override)
        folder.mkdir(parents=True, exist_ok=True)
        return folder
    if common_dir is None and cwd is not None:
        common_dir = git_info(cwd)[3]
    if common_dir:
        common = Path(common_dir)
        if common.name == ".git" and common.parent.is_dir():     # a bare repository has no checkout to write into
            folder = common.parent / "temp" / "history"
            if _writable(folder):
                return folder
    folder = admission.runs_dir() / "history"
    folder.mkdir(parents=True, exist_ok=True)
    return folder


def file_name(record):
    run = record["run"]
    stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime(run.get("startEpoch") or time.time()))
    return "%s_%s.json" % (stamp, run["id"])


def write_record(folder, record):
    path = Path(folder) / file_name(record)
    admission.write_json_atomic(path, record)
    return path


def load_records(folder):
    """All readable records of a folder, oldest first. Broken files are skipped."""
    records = []
    for path in sorted(Path(folder).glob("*.json")):
        try:
            record = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if isinstance(record, dict) and isinstance(record.get("run"), dict):
            record["_path"] = str(path)
            records.append(record)
    records.sort(key=lambda r: r["run"].get("startEpoch") or 0)
    return records
