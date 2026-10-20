"""Verifies a frozen code state: runs the test tiers through tools/run_suite.py and prints a short verdict.

Usage:
    python tools/verify.py [--ref <commit>] [--tiers fast,foundation,slow] [--auto] [--base <commit>] [--json]

    python tools/verify.py                      # HEAD, all three tiers
    python tools/verify.py --auto               # only the tests that the change since the last green state needs
    python tools/verify.py --tiers fast         # one tier

Tiers (the pytest arguments that run_suite.py gets after --):
    fast        tests -q
    foundation  tests -q --foundation
    slow        tests -q --all -m "slow and not gui"
    select      tests -q --changed-from <base>      (only with --auto; the groups of doc/TEST-GROUPS.md)

What it does:
  * resolves --ref to a full sha. Every run tests that sha in its own worktree (tools/run_suite.py --ref <sha>), never
    the working tree. The selected tiers start at the same time; run_suite and the admission limit the load.
  * --auto: the change is git diff --name-only --no-renames <base>..<ref>, where base is --base or the sha of the last
    green state. tests/support/groups.py maps the paths to the tests that need to run (doc/TEST-GROUPS.md). Paths that
    no test reads (work_items/, .claude/, NEEDS-ATTENTION.md) need no run: if only such paths changed, or nothing did,
    nothing runs: "skipped (not read by any test)" or "skipped (no change)". A change that selects everything (a hub
    file such as Errors.ahk, test infrastructure, an unknown path) and a run without a last green state and without
    --base run all three tiers. Any other change runs the one tier "select": the tests of the selected groups, slow and
    foundation ones included, plus the smoke tests of the users of a shared module, plus the cheap docs and
    architecture checks.
  * per run it reads the result folder of run_suite (output.txt, status.json): run id, exit code, the summary line,
    INTERNALERROR in the output, and the names of the failed tests (at most 10 per run). A run is green only with exit
    0, no INTERNALERROR, a summary that contains "passed", and a result folder that names the sha (its first 8 hex
    digits).
  * the last green state goes to temp/verify/last.json of the main checkout (sha, tree hashes of src, tests and tools,
    tiers, run ids, time; the file is git-ignored). It is written only when the verdict is green, the sha is v2-port or
    an ancestor of it ("not recorded (not on v2-port)" otherwise), and the run was either --auto without --base or a
    run of all three tiers ("not recorded (partial run)" otherwise). A manual --tiers run or --auto --base never writes.

Exit code: 0 green or skipped, 1 red (a tier is not green, could not run, or shows INTERNALERROR), 2 usage or git
error. A last green state that cannot be written is a note in the output, not a failure.

Not covered: the checks outside pytest. The architecture check, the requirements index check and the element include
check are tests of the groups architecture, docs and element-units (tests/test_architecture.py,
tests/test_requirements.py, tests/test_element_includes.py); they run in every selection.
tests/test_open_items_ids.py skips itself in a worktree, so verify.py only prints a note about provisional finding IDs
in doc/OPEN-ITEMS.md; it does not fail on them (agents' branches have them on purpose). The gui tier is never run here.
"""

import argparse
import concurrent.futures
import functools
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

from support import groups, history  # noqa: E402

import run_suite  # noqa: E402  (tools/ is the folder of this script)

TIERS = ("fast", "foundation", "slow")
SELECT = "select"             # the run of --auto that the groups chose; its pytest arguments need the base commit
ORDER = TIERS + (SELECT,)
TIER_ARGS = {
    "fast": ["tests", "-q"],
    "foundation": ["tests", "-q", "--foundation"],
    "slow": ["tests", "-q", "--all", "-m", "slow and not gui"],
}

# The trees that the record keeps to show what was verified (documentation is not one of them).
TREE_DIRS = ("src", "tests", "tools")

RECORD_BRANCH = "v2-port"       # only states on this branch (or its ancestors) become the last green state
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
    out = git(repo, "diff", "--name-only", "--no-renames", "%s..%s" % (base, sha))
    return [line for line in out.splitlines() if line]


def removed_paths(repo, base, sha):
    """The paths that the change between base and sha deletes (a rename's old path included, --no-renames)."""
    out = git(repo, "diff", "--name-only", "--diff-filter=D", "--no-renames", "%s..%s" % (base, sha))
    return [line for line in out.splitlines() if line]


def on_record_branch(repo, sha):
    """True when sha is RECORD_BRANCH or one of its ancestors. A run of a branch is never the base of --auto."""
    proc = subprocess.run(["git", "merge-base", "--is-ancestor", sha, RECORD_BRANCH], cwd=str(repo),
                          capture_output=True)
    return proc.returncode == 0


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

def select_tiers(changed, removed=()):
    """The tiers for a list of changed paths, or ([], reason) when nothing has to run. removed: the deleted paths."""
    if not changed:
        return [], "no change"
    sel = groups.select(changed, removed)
    if sel.is_empty():
        return [], "not read by any test"
    if sel.everything:
        return list(TIERS), None
    return [SELECT], None


def decide(changed, removed=()):
    """(tiers to run, skip reason or None). changed None means: no base known, run everything."""
    if changed is None:
        return list(TIERS), None
    return select_tiers(changed, removed)


def selection_note(changed, base, removed=()):
    """One line for the output that says what the groups chose."""
    sel = groups.select(changed, removed)
    names = sorted(sel.groups - set(groups.ALWAYS_GROUPS))
    text = "selection: groups %s" % (", ".join(names) or "-")
    if sel.files:
        text += "; %d test files by name" % len(sel.files)
    if sel.smoke_areas:
        text += "; smoke tests for %s" % ", ".join(sorted(sel.smoke_areas))
    return text + " (python tools/select_tests.py --from %s explains it)" % base[:8]


# --- reading the results of run_suite -------------------------------------------------------------

def run_outcome(tier, code, text, sha):
    """What one run_suite call produced. text is its stdout (it names the result folder of the run)."""
    # the last line: pytest output echoed by run_suite (a failing test of the run_suite tests) may contain the same text
    found = OUTPUT_LINE.findall(text or "")
    match = found[-1] if found else None
    if code in (EXIT_TOOL_FAILED, EXIT_ADMISSION) or match is None:
        note = "not run (run_suite exit %d)" % code if code else "not run (no result folder)"
        return {"tier": tier, "exit": code, "run": None, "folder": None, "summary": "", "failed": [],
                "failedCount": 0, "internalError": False, "note": note, "problem": note}
    folder = Path(match).parent          # the line names output.txt, the folder is its parent
    info = parse_folder(folder)
    problem = ""
    if sha[:8] not in folder.name:
        problem = "result folder %s does not name the sha %s" % (folder.name, sha[:8])
    elif "passed" not in info["summary"]:
        problem = "summary has no 'passed': %s" % (info["summary"] or "(empty)")
    return dict(info, tier=tier, exit=code, problem=problem)


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
    return (outcome["run"] is not None and outcome["exit"] == 0 and not outcome["internalError"]
            and not outcome["problem"])


def provisional_ids(repo, sha):
    text = git(repo, "show", "%s:doc/OPEN-ITEMS.md" % sha, check=False)
    return sorted(set(PROVISIONAL_HEADING.findall(text or "")))


# --- running ----------------------------------------------------------------------------------------

def pytest_args(tier, base=None):
    if tier == SELECT:
        return ["tests", "-q", "--changed-from", base]
    return TIER_ARGS[tier]


def run_suite_runner(tier, sha, base=None):
    """Runs tools/run_suite.py for one tier and returns (exit code, stdout and stderr). base: the commit that the
    select tier compares with (the frozen worktree is at sha, so the diff is base..sha)."""
    cmd = [sys.executable, str(REPO / "tools" / "run_suite.py"), "--ref", sha, "--", *pytest_args(tier, base)]
    proc = subprocess.run(cmd, capture_output=True, stdin=subprocess.DEVNULL)
    return proc.returncode, (proc.stdout + proc.stderr).decode("utf-8", "replace")


def run_tiers(tiers, sha, runner):
    """Starts the tiers at the same time and returns their outcomes in TIERS order."""
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(tiers)) as pool:
        futures = {tier: pool.submit(runner, tier, sha) for tier in tiers}
        outcomes = []
        for tier in ORDER:
            if tier in futures:
                code, text = futures[tier].result()
                outcomes.append(run_outcome(tier, code, text, sha))
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
        if o["problem"]:
            lines.append("    problem: %s" % o["problem"])
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
    parser.add_argument("--auto", action="store_true", help="run only the tests the change since the last green state "
                                                            "needs (doc/TEST-GROUPS.md); nothing for changes that no "
                                                            "test reads")
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
        skip_reason = None
        base = None
        removed = []
        if args.auto:
            base = args.base or (state or {}).get("sha")
            changed = changed_paths(repo, base, sha) if base else None
            removed = removed_paths(repo, base, sha) if base else []
            tiers, skip_reason = decide(changed, removed)
        notes = []
        if tiers == [SELECT]:
            notes.append(selection_note(changed, base, removed))
        provisional = provisional_ids(repo, sha)
        if provisional:
            notes.append("provisional finding IDs in doc/OPEN-ITEMS.md: %s (renumber before integration)"
                         % ", ".join(provisional))
    except (VerifyError, groups.UnknownPathError) as e:
        # an unclassified path is an error, not a green run and not a run of everything (doc/TEST-GROUPS.md, section 6)
        if args.json:
            print(json.dumps({"ref": args.ref, "verdict": "error", "detail": str(e), "exit": EXIT_ERROR,
                              "tiers": [], "notes": []}, indent=2))
        else:
            print("verify: %s" % e, file=sys.stderr)
            print("VERDICT: error (a changed path is not classified by any test rule, see stderr)")
        return EXIT_ERROR

    short = sha[:8]
    if skip_reason is not None or not tiers:
        reason = skip_reason or "no tier selected"
        if args.json:
            print(json.dumps({"ref": args.ref, "sha": sha, "verdict": "skipped", "detail": reason, "exit": EXIT_GREEN,
                              "tiers": [], "notes": notes}, indent=2))
        else:
            for line in report_lines(short, subject, [], "skipped", reason, notes):
                say(line)
        return EXIT_GREEN

    outcomes = run_tiers(tiers, sha, runner or functools.partial(run_suite_runner, base=base))
    verdict, detail = verdict_of(outcomes)
    code = EXIT_GREEN if verdict == "green" else EXIT_RED
    if verdict == "green":
        full_run = set(tiers) == set(TIERS)
        if not (full_run or (args.auto and not args.base)):
            notes.append("not recorded (partial run)")
        elif not on_record_branch(repo, sha):
            notes.append("not recorded (not on %s)" % RECORD_BRANCH)
        else:
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
