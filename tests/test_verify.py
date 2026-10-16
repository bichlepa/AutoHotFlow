"""tools/verify.py: the choice of tiers, the reading of run_suite results and the verdict flow, on a temporary git
repository with a fake runner (no pytest run, no AHK process)."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import verify  # noqa: E402


# --- choice of tiers ----------------------------------------------------------------------------------

@pytest.mark.parametrize("changed, expected", [
    (["src/supervisor/x.py"], ["fast", "foundation", "slow"]),
    (["src/expr/x.ahk"], ["fast"]),
    (["src/core/x.ahk"], ["fast", "foundation"]),
    (["src/AhfBoot.ahk"], ["fast", "foundation"]),
    (["src/AutoHotFlow.ahk"], ["fast"]),                  # not in the AGENTS.md list (src/Ahf*.ahk only)
    (["tools/ahkrun.py"], ["fast", "foundation"]),
    (["doc/PROTOCOL.md"], ["fast", "foundation"]),
    (["tests/support/timing.py"], ["fast", "foundation", "slow"]),
    (["tests/support/elements.py"], ["fast", "foundation"]),
    (["tests/integration/helpers/x.py"], ["fast", "foundation"]),
    (["tests/conftest.py"], ["fast", "foundation"]),
    (["src/storage/x.ahk"], ["fast", "slow"]),
    (["src/worker/x.ahk"], ["fast", "slow"]),
    (["tests/test_x.py", "src/expr/y.ahk"], ["fast"]),
])
def test_tiers_follow_the_changed_paths(changed, expected):
    assert verify.select_tiers(changed) == (expected, None)


@pytest.mark.parametrize("changed, reason", [
    (["doc/OPEN-ITEMS.md", "work_items/phase3/README.md", ".vscode/tasks.json", ".claude/x.md"], "documentation only"),
    (["src/README.md"], "documentation only"),
    ([], "no change"),
])
def test_documentation_only_runs_nothing(changed, reason):
    assert verify.select_tiers(changed) == ([], reason)


def test_decide_without_a_base_runs_all_tiers():
    assert verify.decide(None, False, []) == (["fast", "foundation", "slow"], None)


def test_decide_skips_when_trees_are_equal_and_the_tiers_were_green():
    assert verify.decide(["tests/x.py"], True, ["fast"]) == ([], "trees equal to verified")


def test_decide_runs_tiers_the_verified_state_did_not_have():
    # same trees as a fast-only green state, but the change now needs foundation: not verified yet
    assert verify.decide(["src/core/x.ahk"], True, ["fast"]) == (["fast", "foundation"], None)


def test_decide_runs_when_the_trees_differ():
    assert verify.decide(["tests/x.py"], False, ["fast"]) == (["fast"], None)


def test_documentation_only_wins_over_equal_trees():
    assert verify.decide(["doc/x.md"], True, ["fast", "foundation", "slow"]) == ([], "documentation only")


# --- reading run_suite results ------------------------------------------------------------------------

def fake_folder(base, run_id, summary, output_lines, status_extra=None):
    folder = base / run_id
    folder.mkdir(parents=True)
    (folder / "output.txt").write_text("\n".join(output_lines) + "\n", encoding="utf-8")
    status = {"id": run_id, "state": "finished", "summary": summary}
    status.update(status_extra or {})
    (folder / "status.json").write_text(json.dumps(status), encoding="utf-8")
    return folder


def test_parse_folder_reads_summary_failures_and_internal_error(tmp_path):
    folder = fake_folder(tmp_path, "20261016-100000-abcdef12", "1 failed, 966 passed in 40.0s", [
        "tests/x.py F", "FAILED tests/a.py::test_one - assert 1 == 2", "FAILED tests/a.py::test_one - again",
        "ERROR tests/b.py::test_two - setup", "INTERNALERROR> Traceback (most recent call last):",
    ])
    info = verify.parse_folder(folder)
    assert info["run"] == "20261016-100000-abcdef12"
    assert info["summary"] == "1 failed, 966 passed in 40.0s"
    assert info["failed"] == ["tests/a.py::test_one", "tests/b.py::test_two"]
    assert info["failedCount"] == 2
    assert info["internalError"] is True


def test_run_outcome_reads_the_folder_named_in_the_output_line(tmp_path):
    folder = fake_folder(tmp_path, "20261016-100001-abcdef12", "967 passed, 1 skipped in 45.0s", ["ok"])
    text = "[run_suite] pytest tests -q\n[run_suite] output: %s\n[run_suite] result: exit 0" % (folder / "output.txt")
    outcome = verify.run_outcome("fast", 0, text)
    assert outcome["run"] == "20261016-100001-abcdef12"
    assert verify.is_green(outcome)


def test_run_outcome_without_a_result_folder_is_not_run():
    outcome = verify.run_outcome("slow", verify.EXIT_ADMISSION, "[run_suite] admission: timeout")
    assert outcome["run"] is None and outcome["note"].startswith("not run")
    assert not verify.is_green(outcome)


def test_a_green_exit_with_internal_error_is_red(tmp_path):
    folder = fake_folder(tmp_path, "r-1", "1 passed in 1.0s", ["INTERNALERROR> boom"])
    outcome = verify.run_outcome("fast", 0, "[run_suite] output: %s" % (folder / "output.txt"))
    assert not verify.is_green(outcome)


# --- the flow on a temporary repository -------------------------------------------------------------

def git(repo, *args):
    subprocess.run(["git", *args], cwd=str(repo), check=True, capture_output=True)


def commit(repo, files, message):
    for rel, text in files.items():
        path = repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    git(repo, "add", "-A")
    git(repo, "-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-q", "-m", message)


@pytest.fixture
def repo(tmp_path):
    root = tmp_path / "repo"
    root.mkdir()
    git(root, "init", "-q")
    git(root, "symbolic-ref", "HEAD", "refs/heads/v2-port")     # the record branch of verify.py
    commit(root, {".gitignore": "temp/\n", "src/a.ahk": "a", "tests/t.py": "t", "tools/x.py": "x", "doc/d.md": "d"},
           "base")
    return root


def test_a_green_run_on_a_branch_is_not_recorded(repo, tmp_path, capsys):
    git(repo, "checkout", "-q", "-b", "wip")
    commit(repo, {"src/a.ahk": "branch change"}, "branch change")
    assert verify.main(["--tiers", "fast"], runner=FakeRunner(tmp_path / "runs"), repo=repo) == 0
    assert not (repo / "temp" / "verify" / "last.json").exists()
    out = capsys.readouterr().out
    assert "not recorded (not on v2-port)" in out and "VERDICT: green" in out


def test_a_green_run_of_an_ancestor_of_v2_port_is_recorded(repo, tmp_path):
    """The base commit is an ancestor once v2-port has moved on: its green run is recorded."""
    base_sha = verify.resolve(repo, "HEAD")
    commit(repo, {"doc/e.md": "e"}, "v2-port moves on")
    assert verify.main(["--ref", base_sha, "--tiers", "fast"], runner=FakeRunner(tmp_path / "runs"), repo=repo) == 0
    state = json.loads((repo / "temp" / "verify" / "last.json").read_text(encoding="utf-8"))
    assert state["sha"] == base_sha


class FakeRunner:
    """Answers each tier with a result folder under its own base; fail maps a tier to its failed test names."""

    def __init__(self, base, fail=None, exit_codes=None):
        self.base = Path(base)
        self.fail = fail or {}
        self.exit_codes = exit_codes or {}
        self.calls = []
        self.n = 0

    def __call__(self, tier, sha):
        self.calls.append((tier, sha))
        self.n += 1
        code = self.exit_codes.get(tier, 1 if tier in self.fail else 0)
        lines = ["FAILED %s" % name for name in self.fail.get(tier, [])] or ["ok"]
        summary = "%d passed in 1.0s" % self.n if not code else "1 failed in 1.0s"
        folder = fake_folder(self.base, "run-%s-%d" % (tier, self.n), summary, lines)
        return code, "[run_suite] output: %s\n" % (folder / "output.txt")


def test_green_run_writes_the_last_green_state(repo, tmp_path, capsys):
    runner = FakeRunner(tmp_path / "runs")
    assert verify.main(["--tiers", "fast"], runner=runner, repo=repo) == 0
    state = json.loads((repo / "temp" / "verify" / "last.json").read_text(encoding="utf-8"))
    sha = verify.resolve(repo, "HEAD")
    assert state["sha"] == sha
    assert state["tiers"] == ["fast"]
    assert set(state["trees"]) == {"src", "tests", "tools"}
    assert state["runs"] == {"fast": "run-fast-1"}
    out = capsys.readouterr().out
    assert "VERDICT: green  sha %s" % sha[:8] in out


def test_auto_runs_nothing_for_documentation_only(repo, tmp_path, capsys):
    runner = FakeRunner(tmp_path / "runs")
    verify.main(["--tiers", "fast"], runner=runner, repo=repo)
    commit(repo, {"doc/e.md": "e"}, "docs")
    runner.calls.clear()
    assert verify.main(["--auto"], runner=runner, repo=repo) == 0
    assert runner.calls == []
    assert "VERDICT: skipped (documentation only)" in capsys.readouterr().out


def test_auto_picks_tiers_from_the_change_since_the_last_green_state(repo, tmp_path):
    runner = FakeRunner(tmp_path / "runs")
    verify.main(["--tiers", "fast"], runner=runner, repo=repo)
    commit(repo, {"tests/t2.py": "t2"}, "test change")
    runner.calls.clear()
    assert verify.main(["--auto"], runner=runner, repo=repo) == 0
    assert [tier for tier, _ in runner.calls] == ["fast"]
    commit(repo, {"src/supervisor/s.ahk": "s"}, "supervisor change")
    runner.calls.clear()
    assert verify.main(["--auto"], runner=runner, repo=repo) == 0
    assert [tier for tier, _ in runner.calls] == ["fast", "foundation", "slow"]


def test_red_run_exits_1_names_the_failed_tests_and_keeps_the_old_state(repo, tmp_path, capsys):
    runner = FakeRunner(tmp_path / "runs")
    verify.main(["--tiers", "fast"], runner=runner, repo=repo)
    old = (repo / "temp" / "verify" / "last.json").read_text(encoding="utf-8")
    commit(repo, {"src/a.ahk": "changed"}, "change")
    runner = FakeRunner(tmp_path / "runs2", fail={"fast": ["tests/t.py::test_a", "tests/t.py::test_b"]})
    assert verify.main(["--tiers", "fast"], runner=runner, repo=repo) == 1
    out = capsys.readouterr().out
    assert "    FAILED tests/t.py::test_a" in out
    assert "VERDICT: red (fast)" in out
    assert (repo / "temp" / "verify" / "last.json").read_text(encoding="utf-8") == old


def test_more_than_ten_failures_are_counted_not_listed(repo, tmp_path, capsys):
    names = ["tests/t.py::test_%02d" % i for i in range(12)]
    runner = FakeRunner(tmp_path / "runs", fail={"fast": names})
    assert verify.main(["--tiers", "fast"], runner=runner, repo=repo) == 1
    out = capsys.readouterr().out
    assert out.count("    FAILED ") == verify.MAX_FAILED_SHOWN
    assert "... 2 more" in out


def test_json_output_is_one_object(repo, tmp_path, capsys):
    runner = FakeRunner(tmp_path / "runs")
    assert verify.main(["--tiers", "fast,slow", "--json"], runner=runner, repo=repo) == 0
    data = json.loads(capsys.readouterr().out)
    assert data["verdict"] == "green"
    assert [t["tier"] for t in data["tiers"]] == ["fast", "slow"]
    assert data["sha"] == verify.resolve(repo, "HEAD")


def test_auto_and_tiers_exclude_each_other(repo, capsys):
    assert verify.main(["--auto", "--tiers", "fast"], runner=FakeRunner(repo), repo=repo) == 2


def test_unknown_tier_is_a_usage_error(repo):
    assert verify.main(["--tiers", "fast,gui"], runner=FakeRunner(repo), repo=repo) == 2


def test_unknown_ref_is_a_tool_error(repo, capsys):
    assert verify.main(["--ref", "no-such-ref"], runner=FakeRunner(repo), repo=repo) == 2


def test_provisional_ids_are_a_note_not_a_failure(repo, tmp_path, capsys):
    commit(repo, {"doc/OPEN-ITEMS.md": "### %s: a finding\n" % ("F-" + "9001*")}, "branch finding")
    runner = FakeRunner(tmp_path / "runs")
    assert verify.main(["--tiers", "fast"], runner=runner, repo=repo) == 0
    assert "note: provisional finding IDs" in capsys.readouterr().out
