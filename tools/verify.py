"""Verifies a frozen code state: runs the test tiers through tools/run_suite.py and prints a short verdict.

Usage:
    python tools/verify.py [--ref <commit>] [--tiers fast,foundation,slow] [--auto] [--base <commit>] [--json]

    python tools/verify.py                      # HEAD, all three tiers
    python tools/verify.py --auto               # only the tiers that the change since the last green state needs
    python tools/verify.py --tiers fast         # one tier

Tiers (the pytest arguments that run_suite.py gets after --):
    fast        tests -q
    foundation  tests -q --foundation
    slow        tests -q --all -m "slow and not gui"

What it does:
  * resolves --ref to a full sha. Every run tests that sha in its own worktree (tools/run_suite.py --ref <sha>), never
    the working tree. The selected tiers start at the same time; run_suite and the admission limit the load.
  * --auto: the change is git diff --name-only <base>..<ref>, where base is --base or the sha of the last green state.
    - Only documentation changed (doc/, work_items/, .vscode/, .claude/, *.md): nothing runs, "skipped (documentation
      only)".
    - Otherwise fast always, foundation when a path is in FOUNDATION_DIRS / FOUNDATION_FILES / FOUNDATION_GLOBS, slow
      when a path is in SLOW_DIRS / SLOW_FILES.
    - When the trees src, tests and tools of <ref> equal those of the last green state, and that state was green for
      the tiers needed now, nothing runs: "skipped (trees equal to verified <sha>)".
    - Without a last green state and without --base, all three tiers run.
  * per run it reads the result folder of run_suite (output.txt, status.json): run id, exit code, the summary line,
    INTERNALERROR in the output, and the names of the failed tests (at most 10 per run).
  * when every selected tier is green, it writes the last green state to temp/verify/last.json of the main checkout
    (sha, tree hashes of src, tests and tools, tiers, run ids, time). The file is git-ignored.

Exit code: 0 green or skipped, 1 red (a tier is not green, could not run, or shows INTERNALERROR), 2 usage or git
error. A last green state that cannot be written is a note in the output, not a failure.

Not covered: the checks outside pytest. The architecture check, the requirements index check and the element include
check are tests of the fast tier (tests/test_architecture.py, tests/test_requirements.py, tests/test_element_includes.py).
tests/test_open_items_ids.py skips itself in a worktree, so verify.py only prints a note about provisional finding IDs
in doc/OPEN-ITEMS.md; it does not fail on them (agents' branches have them on purpose). The gui tier is never run here.
"""

import argparse
import concurrent.futures
import fnmatch
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tests"))
sys.path.insert(0, str(REPO / "tools"))

from support import history  # noqa: E402

import run_suite  # noqa: E402  (tools/ is the folder of this script)

TIERS = ("fast", "foundation", "slow")
TIER_ARGS = {
    "fast": ["tests", "-q"],
    "foundation": ["tests", "-q", "--foundation"],
    "slow": ["tests", "-q", "--all", "-m", "slow and not gui"],
}

# --auto: which changed paths need which tier. Keep the foundation and slow lists in step with AGENTS.md (the paragraph on tests).
DOC_DIRS = ("doc/", "work_items/", ".vscode/", ".claude/")
DOC_SUFFIXES = (".md",)
FOUNDATION_DIRS = ("src/core/", "src/supervisor/", "src/debugview/", "tests/support/", "tests/integration/helpers/")
FOUNDATION_FILES = ("tests/conftest.py", "tools/ahkrun.py", "doc/PROTOCOL.md")
FOUNDATION_GLOBS = ("src/Ahf*.ahk",)
SLOW_DIRS = ("src/supervisor/", "src/worker/", "src/storage/")
SLOW_FILES = ("tests/support/timing.py",)
# The trees that decide whether two code states are the same (documentation is not one of them).
TREE_DIRS = ("src", "tests", "tools")

MAX_FAILED_SHOWN = 10
EXIT_GREEN = 0
EXIT_RED = 1
EXIT_ERROR = 2
EXIT_TOOL_FAILED = run_suite.EXIT_TOOL_FAILED          # run_suite could not start the run
EXIT_ADMISSION = run_suite.EXIT_ADMISSION_TIMEOUT      # run_suite gave up waiting for worker slots

OUTPUT_LINE = re.compile(r"^\[run_suite\] output: (.+?)\s*$", re.MULTILINE)
FAILED_LINE = re.compile(r"^(?:FAILED|ERROR) (\S+)", re.MULTILINE)
PROVISIONAL_HEADING = re.compile(r"^### (F-9\d{3})\*?:", re.MULTILINE)


class VerifyError(Exception):
    pass


def say(text=""):
    print(text, flush=True)


# --- git ----------------------------------------------------------------------------------------------

def git(repo, *args, check=True):
    proc = subprocess.run(["git", *args], cwd=str(repo), capture_output=True)
    if check and proc.returncode != 0:
        raise VerifyError("git %s failed: %s" % (" ".join(args), proc.stderr.decode("utf-8", "replace").strip()))
    return proc.stdout.decode("utf-8", "replace") if proc.returncode == 0 else None


def resolve(repo, ref):
    return git(repo, "rev-parse", "--verify", ref + "^{commit}").strip()


def tree_hashes(repo, sha):
    return {d: git(repo, "rev-parse", "%s:%s" % (sha, d)).strip() for d in TREE_DIRS}


def changed_paths(repo, base, sha):
    out = git(repo, "diff", "--name-only", "%s..%s" % (base, sha))
    return [line for line in out.splitlines() if line]


def state_path(repo):
    """temp/verify/last.json of the main checkout, next to temp/history (see tests/support/history.py)."""
    common = history.git_info(repo)[3]
    if common and Path(common).name == ".git":
        return Path(common).parent / "temp" / "verify" / "last.json"
    return run_suite.runs_dir() / "verify" / "last.json"


def read_state(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) and data.get("sha") else None


def write_state(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


# --- deciding what to run ---------------------------------------------------------------------------

def is_doc(path):
    # doc/PROTOCOL.md is documentation, but a change of an interface runs the foundation tier: it is not "doc only"
    if path in FOUNDATION_FILES:
        return False
    return path.startswith(DOC_DIRS) or path.endswith(DOC_SUFFIXES)


def needs_foundation(path):
    return (path.startswith(FOUNDATION_DIRS) or path in FOUNDATION_FILES
            or any(fnmatch.fnmatchcase(path, glob) for glob in FOUNDATION_GLOBS))


def needs_slow(path):
    return path.startswith(SLOW_DIRS) or path in SLOW_FILES


def select_tiers(changed):
    """The tiers for a list of changed paths, or ([], reason) when nothing has to run."""
    if not changed:
        return [], "no change"
    if all(is_doc(p) for p in changed):
        return [], "documentation only"
    tiers = ["fast"]
    if any(needs_foundation(p) for p in changed):
        tiers.append("foundation")
    if any(needs_slow(p) for p in changed):
        tiers.append("slow")
    return tiers, None


def decide(changed, trees_equal, verified_tiers):
    """(tiers to run, skip reason or None). changed None means: no base known, run everything."""
    if changed is None:
        return list(TIERS), None
    tiers, reason = select_tiers(changed)
    if not tiers:
        return [], reason
    if trees_equal and set(tiers) <= set(verified_tiers):
        return [], "trees equal to verified"
    return tiers, None


# --- reading the results of run_suite -------------------------------------------------------------

def run_outcome(tier, code, text):
    """What one run_suite call produced. text is its stdout (it names the result folder of the run)."""
    match = OUTPUT_LINE.search(text or "")
    if code in (EXIT_TOOL_FAILED, EXIT_ADMISSION) or match is None:
        note = "not run (run_suite exit %d)" % code if code else "not run (no result folder)"
        return {"tier": tier, "exit": code, "run": None, "folder": None, "summary": "", "failed": [],
                "failedCount": 0, "internalError": False, "note": note}
    folder = Path(match.group(1)).parent          # the line names output.txt, the folder is its parent
    return dict(parse_folder(folder), tier=tier, exit=code)


def parse_folder(folder):
    """run id, summary, failed test names and INTERNALERROR of a run_suite result folder (output.txt, status.json)."""
    folder = Path(folder)
    try:
        status = json.loads((folder / "status.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        status = {}
    try:
        output = (folder / "output.txt").read_text(encoding="utf-8", errors="replace")
    except OSError:
        output = ""
    summary = status.get("summary") or run_suite.summary_line(folder / "output.txt")
    failed = []
    for name in FAILED_LINE.findall(output):
        if name not in failed:
            failed.append(name)
    return {"run": folder.name, "folder": str(folder), "summary": summary, "failed": failed,
            "failedCount": len(failed), "internalError": "INTERNALERROR" in output, "note": ""}


def is_green(outcome):
    return outcome["run"] is not None and outcome["exit"] == 0 and not outcome["internalError"]


def provisional_ids(repo, sha):
    text = git(repo, "show", "%s:doc/OPEN-ITEMS.md" % sha, check=False)
    return sorted(set(PROVISIONAL_HEADING.findall(text or "")))


# --- running ----------------------------------------------------------------------------------------

def run_suite_runner(tier, sha):
    """Runs tools/run_suite.py for one tier and returns (exit code, stdout and stderr)."""
    cmd = [sys.executable, str(REPO / "tools" / "run_suite.py"), "--ref", sha, "--", *TIER_ARGS[tier]]
    proc = subprocess.run(cmd, capture_output=True, stdin=subprocess.DEVNULL)
    return proc.returncode, (proc.stdout + proc.stderr).decode("utf-8", "replace")


def run_tiers(tiers, sha, runner):
    """Starts the tiers at the same time and returns their outcomes in TIERS order."""
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(tiers)) as pool:
        futures = {tier: pool.submit(runner, tier, sha) for tier in tiers}
        outcomes = []
        for tier in TIERS:
            if tier in futures:
                code, text = futures[tier].result()
                outcomes.append(run_outcome(tier, code, text))
    return outcomes


# --- output -------------------------------------------------------------------------------------------

def verdict_of(outcomes):
    red = [o["tier"] for o in outcomes if not is_green(o)]
    if red:
        return "red", ", ".join(red)
    return "green", ""


def report_lines(short, subject, outcomes, verdict, detail, notes):
    lines = ["verify %s  %s" % (short, subject)]
    for o in outcomes:
        if o["run"] is None:
            lines.append("%-10s %s" % (o["tier"], o["note"]))
            continue
        lines.append("%-10s run %s  exit %d  %s" % (o["tier"], o["run"], o["exit"], o["summary"]))
        for name in o["failed"][:MAX_FAILED_SHOWN]:
            lines.append("    FAILED %s" % name)
        if o["failedCount"] > MAX_FAILED_SHOWN:
            lines.append("    ... %d more" % (o["failedCount"] - MAX_FAILED_SHOWN))
        if o["internalError"]:
            lines.append("    INTERNALERROR in %s" % (Path(o["folder"]) / "output.txt"))
        if not is_green(o):
            lines.append("    output: %s" % (Path(o["folder"]) / "output.txt"))
    lines.extend("note: " + n for n in notes)
    if verdict == "skipped":
        lines.append("VERDICT: skipped (%s)  sha %s" % (detail, short))
    elif verdict == "green":
        lines.append("VERDICT: green  sha %s" % short)
    else:
        lines.append("VERDICT: red (%s)  sha %s" % (detail, short))
    return lines


def main(argv=None, runner=None, repo=REPO):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--ref", default="HEAD", help="commit, branch or tag to verify (default HEAD)")
    parser.add_argument("--tiers", default=None, help="comma-separated tiers: fast,foundation,slow (default all)")
    parser.add_argument("--auto", action="store_true", help="run only the tiers the change since the last green state "
                                                            "needs; nothing for documentation only")
    parser.add_argument("--base", default=None, help="base commit for --auto (default: the last green state)")
    parser.add_argument("--json", action="store_true", help="print one JSON object instead of the text")
    args = parser.parse_args(argv)

    if args.auto and args.tiers:
        print("--auto and --tiers exclude each other", file=sys.stderr)
        return EXIT_ERROR
    tiers = list(TIERS)
    if args.tiers:
        tiers = [t.strip() for t in args.tiers.split(",") if t.strip()]
        if not tiers or any(t not in TIER_ARGS for t in tiers):
            print("unknown tier in --tiers (use %s)" % ",".join(TIERS), file=sys.stderr)
            return EXIT_ERROR
        tiers = [t for t in TIERS if t in tiers]

    try:
        sha = resolve(repo, args.ref)
        subject = git(repo, "log", "-1", "--format=%s", sha).strip()
        state_file = state_path(repo)
        state = read_state(state_file)
        verified_tiers = list((state or {}).get("tiers") or [])
        skip_reason = None
        if args.auto:
            base = args.base or (state or {}).get("sha")
            changed = changed_paths(repo, base, sha) if base else None
            trees_equal = bool(state) and tree_hashes(repo, sha) == state.get("trees")
            tiers, skip_reason = decide(changed, trees_equal, verified_tiers)
        notes = []
        provisional = provisional_ids(repo, sha)
        if provisional:
            notes.append("provisional finding IDs in doc/OPEN-ITEMS.md: %s (renumber before integration)"
                         % ", ".join(provisional))
    except VerifyError as e:
        print("verify: %s" % e, file=sys.stderr)
        return EXIT_ERROR

    short = sha[:8]
    if skip_reason is not None or not tiers:
        reason = skip_reason or "no tier selected"
        if reason == "trees equal to verified":
            reason = "trees equal to verified %s" % (state["sha"][:8])
        if args.json:
            print(json.dumps({"ref": args.ref, "sha": sha, "verdict": "skipped", "detail": reason, "exit": EXIT_GREEN,
                              "tiers": [], "notes": notes}, indent=2))
        else:
            for line in report_lines(short, subject, [], "skipped", reason, notes):
                say(line)
        return EXIT_GREEN

    outcomes = run_tiers(tiers, sha, runner or run_suite_runner)
    verdict, detail = verdict_of(outcomes)
    code = EXIT_GREEN if verdict == "green" else EXIT_RED
    if verdict == "green":
        try:
            write_state(state_file, {
                "sha": sha, "trees": tree_hashes(repo, sha), "tiers": tiers,
                "runs": {o["tier"]: o["run"] for o in outcomes}, "verified": time.strftime("%Y-%m-%d %H:%M:%S"),
                "tool": "verify.py"})
        except OSError as e:
            notes.append("last green state not written: %s" % e)
    if args.json:
        print(json.dumps({"ref": args.ref, "sha": sha, "verdict": verdict, "detail": detail, "exit": code,
                          "tiers": outcomes, "notes": notes}, indent=2))
    else:
        for line in report_lines(short, subject, outcomes, verdict, detail, notes):
            say(line)
    return code


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
