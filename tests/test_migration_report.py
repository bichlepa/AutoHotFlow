"""WI-0045: tools/migration_report.py (migration markers of loaded v1 flows, run through the loader of the engine)."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
TOOL = REPO / "tools" / "migration_report.py"
FLOWS = REPO / "tests" / "data" / "flows"


def report(target, *options):
    proc = subprocess.run([sys.executable, str(TOOL), str(target), *options], capture_output=True, text=True,
                          encoding="utf-8", timeout=120)
    return proc


@pytest.fixture(scope="module")
def example_report():
    proc = report(FLOWS, "--json")
    assert proc.returncode == 0, proc.stdout[-2000:] + proc.stderr[-2000:]
    return json.loads(proc.stdout)


def test_the_report_runs_for_every_example_flow(example_report):
    files = sorted(FLOWS.rglob("*.json"))
    assert len(example_report["flows"]) == len(files) > 0
    assert [Path(f["file"]).name for f in example_report["flows"]] == [p.name for p in files]
    for f in example_report["flows"]:
        assert "error" not in f, f
    summary = example_report["summary"]
    assert summary["failed"] == 0
    assert summary["elements"] > 0
    # the counts for the result of the work item (no contents of the private flows)
    print("\nmigration report of tests/data/flows: %s" % json.dumps(summary))


def test_a_flow_with_marked_places_is_reported_in_text_and_json(tmp_path):
    flow = {
        "name": "Report", "category": "Tests", "ElementIDCounter": "3",
        "allElements": {
            "e1": {"ID": "e1", "type": "action", "package": "Test", "class": "Action_TestExprParams",
                   "pars": {"Expr": 'x < "abc"', "Num": "7 % 3", "PosInt": "1 +"}},
            "e2": {"ID": "e2", "type": "action", "class": "Action_NotThereYet", "pars": {"Expr": 'x < "abc"'}},
        },
        "allConnections": {},
    }
    path = tmp_path / "Report.json"
    path.write_text(json.dumps(flow), encoding="utf-8")
    before = path.read_text(encoding="utf-8")

    proc = report(path, "--json")
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    [f] = data["flows"]
    assert f["elements"] == 2
    assert [u["element"] for u in f["unknownClass"]] == ["e2"]
    places = {(p["element"], p["par"]): p for p in f["places"]}
    assert places[("e1", "Expr")]["ids"] == ["M-0025"] and places[("e1", "Expr")]["v1"] == 'x < "abc"'
    assert places[("e1", "Num")]["ids"] == ["M-0037"]
    assert places[("e1", "PosInt")]["ids"] == ["M-0050"]
    assert not any(p["element"] == "e2" for p in f["places"])
    assert data["summary"]["places"] == 3 and data["summary"]["placesPerId"] == {"M-0025": 1, "M-0037": 1, "M-0050": 1}

    text = report(path).stdout
    assert "unknown class: 1 element(s): Default.Action_NotThereYet (1)" in text
    assert "e1 (Test.Action_TestExprParams) parameter Expr [M-0025] v1: x < \"abc\"" in text
    # the tool only reads
    assert path.read_text(encoding="utf-8") == before


def test_a_file_that_is_not_a_flow_is_reported_and_gives_exit_code_1(tmp_path):
    (tmp_path / "broken.json").write_text("{not json", encoding="utf-8")
    proc = report(tmp_path)
    assert proc.returncode == 1
    assert "NOT LOADED" in proc.stdout
