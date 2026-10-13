"""WI-02: JSON round trip of the real v1 flow files and a 10,000-message measurement.

The AHK helper parses every flow file, writes it with indent 2, parses it again and writes it again.
Python's json is the reference: types must match (str, int, float), and the written file must be
UTF-8 without BOM and without CR, with the same layout as json.dumps(indent=2).
"""

import json
from pathlib import Path

import pytest

from conftest import TESTS_DIR

REPO = TESTS_DIR.parent
FLOW_DIRS = [
    REPO / "v1" / "AppData" / "Saved Flows",
    REPO / "v1" / "Saved Flows" / "demo flows",
]
FLOW_HELPER = TESTS_DIR / "ahk" / "helpers" / "json_flows.ahk"
BENCH_HELPER = TESTS_DIR / "ahk" / "helpers" / "json_bench.ahk"
BOM = b"\xef\xbb\xbf"


def flow_files():
    """Top-level *.json files of the v1 flow folders. backup/ folders are not part of the set."""
    files = []
    for d in FLOW_DIRS:
        files.extend(sorted(d.glob("*.json")))
    return files


def assert_same_types_and_values(original, written, path="$"):
    """Recursive comparison. Python's == alone would accept 1 == 1.0 and '1' != 1, types are checked too."""
    assert type(original) is type(written), "%s: type %s became %s" % (
        path, type(original).__name__, type(written).__name__)
    if isinstance(original, dict):
        assert set(original) == set(written), "%s: keys differ: %s" % (
            path, sorted(set(original) ^ set(written)))
        for key in original:
            assert_same_types_and_values(original[key], written[key], "%s.%s" % (path, key))
    elif isinstance(original, list):
        assert len(original) == len(written), "%s: length %d became %d" % (path, len(original), len(written))
        for i, (a, b) in enumerate(zip(original, written)):
            assert_same_types_and_values(a, b, "%s[%d]" % (path, i))
    else:
        assert original == written, "%s: %r became %r" % (path, original, written)


def run_flow_helper(run_ahk, out_dir):
    """Runs the helper over all v1 flow folders. Returns the RunResult after checking the run itself."""
    files = flow_files()
    assert files, "no v1 flow files found in %s" % FLOW_DIRS
    res = run_ahk(FLOW_HELPER, str(out_dir), *map(str, FLOW_DIRS), timeout=120)
    assert not res.timed_out, "helper did not finish: %s" % res.stderr
    assert res.returncode == 0, "helper exit %s, stderr: %s" % (res.returncode, res.stderr)
    summary = [r for r in res.records if r.get("type") == "summary"]
    assert summary and summary[0]["files"] == len(files), "no summary line: %r" % res.records
    return res


def test_all_v1_flow_files_round_trip(run_ahk, tmp_path):
    files = flow_files()
    out_dir = tmp_path / "out"
    res = run_flow_helper(run_ahk, out_dir)

    lines = {r["name"]: r for r in res.records if r.get("type") == "file"}
    assert sorted(lines) == sorted(f.name for f in files)

    bad = {name: r for name, r in lines.items() if r["status"] != "ok"}
    assert not bad, "files that failed: %s" % json.dumps(bad, indent=1, ensure_ascii=False)

    for f in files:
        original = json.loads(f.read_bytes().decode("utf-8-sig"))
        data = (out_dir / f.name).read_bytes()
        assert not data.startswith(BOM), "%s: BOM written" % f.name
        assert b"\r" not in data, "%s: CR in output" % f.name
        written = json.loads(data.decode("utf-8"))
        assert_same_types_and_values(original, written, f.name)


def test_written_files_have_v1_layout(run_ahk, tmp_path):
    """Layout check: the helper output equals json.dumps(indent=2, sort_keys=True) of the same data.

    That is 2 spaces per level, keys sorted, no trailing newline. The file names of differing
    output are listed in the failure message.
    """
    out_dir = tmp_path / "out"
    run_flow_helper(run_ahk, out_dir)
    mismatches = []
    for f in flow_files():
        original = json.loads(f.read_bytes().decode("utf-8-sig"))
        expected = json.dumps(original, indent=2, ensure_ascii=False, sort_keys=True)
        actual = (out_dir / f.name).read_bytes().decode("utf-8")
        if actual != expected:
            mismatches.append(f.name)
    assert not mismatches, "layout differs from json.dumps(indent=2) in: %s" % mismatches


@pytest.mark.slow
def test_ten_thousand_messages_are_measured(run_ahk, record_property):
    res = run_ahk(BENCH_HELPER, timeout=120)
    assert not res.timed_out, "benchmark did not finish: %s" % res.stderr
    assert res.returncode == 0, "benchmark exit %s, stderr: %s" % (res.returncode, res.stderr)
    bench = [r for r in res.records if r.get("type") == "bench"]
    assert bench, "no bench line in %r" % res.stdout
    b = bench[0]
    assert b["messages"] == 10000
    assert b["roundtrip_ok"] == 10000, "%d of 10000 messages came back identical" % b["roundtrip_ok"]
    record_property("parse_ms_10000", b["parse_ms"])
    record_property("stringify_ms_10000", b["stringify_ms"])
    record_property("chars_each", b["chars_each"])
    # Acceptance target of WI-02 is < 1000 ms per direction. Recorded only, no hard gate.
    print("\nJSON 10000 messages (%d chars each): parse %d ms, stringify %d ms (target < 1000 ms each)"
          % (b["chars_each"], b["parse_ms"], b["stringify_ms"]))
