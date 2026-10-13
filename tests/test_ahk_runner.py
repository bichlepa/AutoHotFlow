"""Runs the AutoHotkey unit tests in tests/ahk/*.test.ahk and maps every case to a pytest result.

Cases are found by scanning the source for TestRun.Case("...") and TestRun.Skip("...") at
collection time, so each case is its own pytest item. A file is executed once and cached;
its results are then looked up per case. Missing results count as failures, never as passes:
a case that is not reported, or a file without a summary line, fails.
"""

import re
from pathlib import Path

import pytest
import psutil

from conftest import TESTS_DIR, read_records

AHK_DIR = TESTS_DIR / "ahk"
ASSERT_LIB = AHK_DIR / "lib" / "Assert.ahk"
CASE_RE = re.compile(r'TestRun\.(?:Case|Skip)\(\s*"((?:[^"\\]|\\.)*)"')
CACHE_KEY = pytest.StashKey()


def _scan_cases(path):
    """Case names in source order. Duplicate names are a collection error."""
    text = path.read_text(encoding="utf-8-sig")
    names = [m.group(1).replace('\\"', '"') for m in CASE_RE.finditer(text)]
    dupes = {n for n in names if names.count(n) > 1}
    if dupes:
        raise ValueError("%s: duplicate case names %s" % (path.name, sorted(dupes)))
    return names


AHK_FILES = sorted(AHK_DIR.glob("*.test.ahk"))
CASES = [(f, name) for f in AHK_FILES for name in _scan_cases(f)]


def _file_results(path, run_ahk, request):
    """Runs the file once per session and caches the parsed result."""
    cache = request.config.stash.setdefault(CACHE_KEY, {})
    if path not in cache:
        cache[path] = run_ahk(path, timeout=60)
    return cache[path]


def _grouped(ahk_file, *values):
    """All items of one file form one xdist group: the file runs once, on one worker (the cache is per process).
    Without the group every worker that gets a case of the file would run the whole file again."""
    return pytest.param(ahk_file, *values, marks=pytest.mark.xdist_group(ahk_file.name))


@pytest.mark.parametrize("ahk_file", [_grouped(f) for f in AHK_FILES], ids=lambda p: p.name)
def test_ahk_file_completes(ahk_file, run_ahk, request):
    """The whole file ran to its summary line, exited 0, and had no failed or errored case."""
    res = _file_results(ahk_file, run_ahk, request)
    assert not res.timed_out, "AutoHotkey run did not finish within 60 s"
    fatal = [r for r in res.records if r.get("type") == "fatal"]
    assert not fatal, "unhandled error: " + fatal[0]["message"]
    summaries = [r for r in res.records if r.get("type") == "summary"]
    assert summaries, "no summary line: the script did not reach TestRun.Finish() (stderr: %r)" % res.stderr
    assert res.returncode == 0, "exit code %s, summary %s" % (res.returncode, summaries[-1])


@pytest.mark.parametrize("ahk_file,case_name", [_grouped(f, name) for f, name in CASES],
                         ids=lambda v: v.name if isinstance(v, Path) else v)
def test_ahk_case(ahk_file, case_name, run_ahk, request):
    res = _file_results(ahk_file, run_ahk, request)
    records = [r for r in res.records if r.get("type") == "case" and r.get("name") == case_name]
    if not records:
        pytest.fail("case not reported by %s (timed_out=%s, exit=%s)" % (ahk_file.name, res.timed_out, res.returncode),
                    pytrace=False)
    rec = records[-1]
    status, message = rec["status"], rec.get("message", "")
    if status == "pass":
        return
    if status == "skip":
        pytest.skip(message or "skipped in AutoHotkey")
    pytest.fail("%s: %s" % (status, message), pytrace=False)


# --- checks of the runner itself -------------------------------------------------

def _write_script(datadir, name, body):
    """Writes a test script next to a copy of the assert library path (absolute include)."""
    path = datadir / name
    header = '#Requires AutoHotkey v2.0\n#Include "%s"\n' % ASSERT_LIB
    path.write_text(header + body, encoding="utf-8")
    return path


def test_failing_and_erroring_cases_are_reported_red(datadir, run_ahk):
    script = _write_script(datadir, "red.test.ahk", (
        "TestRun.Init()\n"
        'TestRun.Case("assertion fails", () => Assert.Equal(1, 2, "my message"))\n'
        'TestRun.Case("runtime error", () => Boom())\n'
        'TestRun.Case("green", () => Assert.True(1))\n'
        "TestRun.Finish()\n"
        "Boom() {\n    throw ValueError(\"boom\")\n}\n"
    ))
    res = run_ahk(script, timeout=60)
    assert res.returncode == 1
    cases = {r["name"]: r for r in res.records if r.get("type") == "case"}
    assert cases["assertion fails"]["status"] == "fail"
    assert "my message" in cases["assertion fails"]["message"]
    assert "expected 2 (Integer) but got 1 (Integer)" in cases["assertion fails"]["message"]
    assert cases["runtime error"]["status"] == "error"
    assert "ValueError: boom" in cases["runtime error"]["message"]
    assert cases["green"]["status"] == "pass"
    summary = [r for r in res.records if r.get("type") == "summary"][0]
    assert summary == {"type": "summary", "passed": 1, "failed": 1, "errors": 1, "skipped": 0}


def test_unhandled_error_ends_run_without_dialog(datadir, run_ahk):
    script = _write_script(datadir, "fatal.test.ahk", (
        "TestRun.Init()\n"
        'throw ValueError("top level")\n'
    ))
    res = run_ahk(script, timeout=30)
    assert not res.timed_out
    assert res.returncode == 2
    fatal = [r for r in res.records if r.get("type") == "fatal"]
    assert fatal and "top level" in fatal[0]["message"]


def test_script_without_finish_has_no_summary(datadir, run_ahk):
    """Exit code 0 alone is not enough: the file-level test requires the summary line."""
    script = _write_script(datadir, "nofinish.test.ahk", (
        "TestRun.Init()\n"
        'TestRun.Case("only case", () => Assert.Equal(1, 1))\n'
    ))
    res = run_ahk(script, timeout=30)
    assert res.returncode == 0
    assert not [r for r in res.records if r.get("type") == "summary"]


@pytest.mark.slow
@pytest.mark.timeout(60)
def test_hung_script_is_killed_at_timeout(datadir, run_ahk, session_id):
    marker = "hang-" + session_id  # unique in the command line, so only this process matches
    script = _write_script(datadir, marker + ".test.ahk", "Sleep(120000)\n")
    res = run_ahk(script, timeout=3)
    assert res.timed_out
    left = []
    for p in psutil.process_iter(["name", "cmdline"]):
        try:
            if p.info["name"] and "AutoHotkey" in p.info["name"] and any(marker in a for a in (p.info["cmdline"] or [])):
                left.append(p.pid)
        except psutil.Error:
            pass
    assert not left, "hung AutoHotkey process still running: %s" % left
