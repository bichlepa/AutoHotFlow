"""tools/verify.py: the choice of tiers (the groups of doc/TEST-GROUPS.md decide in --auto), the reading of run_suite results and the verdict flow, on a temporary git
repository with a fake runner (no pytest run, no AHK process)."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import verify  # noqa: E402
from support import groups  # noqa: E402

SHA = "abcdef12" + "3" * 32          # a fake full sha for the run folder names (its first 8 digits are "abcdef12")


# --- choice of tiers ----------------------------------------------------------------------------------

ALL = ["fast", "foundation", "slow"]


@pytest.mark.parametrize("changed, expected", [
    # a change that the groups can narrow down: the one tier "select"
    (["src/core/GuiLayout.ahk"], ["select"]),
    (["src/engine/Executor.ahk"], ["select"]),
    (["src/supervisor/x.ahk"], ["select"]),
    (["src/elements/Default/Actions/Action_Sleep.ahk"], ["select"]),
    (["tests/test_x.py", "src/expr/y.ahk"], ["select"]),
    (["doc/OPEN-ITEMS.md"], ["select"]),                  # documents: the cheap docs and architecture checks
    ([".vscode/tasks.json"], ["select"]),
    (["README.md"], ["select"]),
    # a change that selects everything: all tiers
    (["src/AhfBoot.ahk"], ALL),
    (["src/core/Errors.ahk"], ALL),
    (["tools/ahkrun.py"], ALL),
    (["tests/conftest.py"], ALL),
    (["tests/support/procs.py"], ALL),
    (["tests/support/x.py"], ALL),                        # shared test infrastructure (explicit rule)
    (["pytest.ini"], ALL),
])
def test_tiers_follow_the_changed_paths(changed, expected):
    assert verify.select_tiers(changed) == (expected, None)


@pytest.mark.parametrize("changed", [
    ["assets/x.png"],                                     # no rule for the path: an error, never a full run
    ["src/new_folder/x.ahk"],                             # no area for the file
    ["tests/integration/helpers/x.py"],                   # no rule for a helper of the tests
])
def test_a_path_no_rule_knows_is_an_error(changed):
    with pytest.raises(groups.UnknownPathError):
        verify.select_tiers(changed)


@pytest.mark.parametrize("changed, reason", [
    (["work_items/phase3/README.md"], "not read by any test"),
    (["work_items/a.md", ".claude/x.md", "NEEDS-ATTENTION.md"], "not read by any test"),
    ([], "no change"),
])
def test_paths_no_test_reads_run_nothing(changed, reason):
    assert verify.select_tiers(changed) == ([], reason)


def test_unread_paths_do_not_hide_a_source_change():
    assert verify.decide(["work_items/x.md", "src/supervisor/s.ahk"]) == (["select"], None)
    assert verify.decide(["work_items/x.md", "src/core/Errors.ahk"]) == (ALL, None)


def test_decide_without_a_base_runs_all_tiers():
    assert verify.decide(None) == (ALL, None)


def test_decide_skips_only_when_nothing_a_test_reads_changed():
    assert verify.decide(["work_items/x.md"]) == ([], "not read by any test")
    assert verify.decide(["tests/test_x.py"]) == (["select"], None)


def test_the_select_tier_compares_with_the_base_commit():
    assert verify.pytest_args("select", "abc123") == ["tests", "-q", "--changed-from", "abc123"]
    assert verify.pytest_args("fast") == ["tests", "-q"]


def test_the_note_names_the_groups_the_change_chose():
    note = verify.selection_note(["src/core/GuiLayout.ahk"], "0123456789abcdef")
    assert "groups ui" in note and "smoke tests for ui" in note and "0123456789"[:8] in note


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
    outcome = verify.run_outcome("fast", 0, text, SHA)
    assert outcome["run"] == "20261016-100001-abcdef12"
    assert verify.is_green(outcome)


def test_run_outcome_takes_the_last_output_line(tmp_path):
    # the output of a failing test may echo a "[run_suite] output:" line of another run before the real one
    folder = fake_folder(tmp_path, "20261016-100002-abcdef12-real", "1 passed in 1.0s", ["ok"])
    lines = ["[run_suite] output: %s" % (tmp_path / "other-9" / "output.txt"),
             "[run_suite] output: %s" % (folder / "output.txt")]
    text = chr(10).join(lines) + chr(10)
    assert verify.run_outcome("fast", 0, text, SHA)["run"] == "20261016-100002-abcdef12-real"


def test_run_outcome_without_a_result_folder_is_not_run():
    outcome = verify.run_outcome("slow", verify.EXIT_ADMISSION, "[run_suite] admission: timeout", SHA)
    assert outcome["run"] is None and outcome["note"].startswith("not run")
    assert not verify.is_green(outcome)


def test_a_green_exit_with_internal_error_is_red(tmp_path):
    folder = fake_folder(tmp_path, "20261016-100003-abcdef12", "1 passed in 1.0s", ["INTERNALERROR> boom"])
    outcome = verify.run_outcome("fast", 0, "[run_suite] output: %s" % (folder / "output.txt"), SHA)
    assert not verify.is_green(outcome)


def test_a_result_folder_must_name_the_sha(tmp_path):
    folder = fake_folder(tmp_path, "20261016-100004-99999999", "1 passed in 1.0s", ["ok"])
    outcome = verify.run_outcome("fast", 0, "[run_suite] output: %s" % (folder / "output.txt"), SHA)
    assert not verify.is_green(outcome)
    assert "does not name the sha abcdef12" in outcome["problem"]


def test_a_summary_without_passed_is_red(tmp_path):
    folder = fake_folder(tmp_path, "20261016-100005-abcdef12", "no tests ran in 0.1s", ["ok"])
    outcome = verify.run_outcome("fast", 0, "[run_suite] output: %s" % (folder / "output.txt"), SHA)
    assert not verify.is_green(outcome)
    assert "summary has no 'passed'" in outcome["problem"]


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
        folder = fake_folder(self.base, "20261016-000000-%s-%s-%d" % (sha[:8], tier, self.n), summary, lines)
        return code, "[run_suite] output: %s\n" % (folder / "output.txt")


def state_of(repo):
    return json.loads((repo / "temp" / "verify" / "last.json").read_text(encoding="utf-8"))


def test_full_green_run_writes_the_last_green_state(repo, tmp_path, capsys):
    runner = FakeRunner(tmp_path / "runs")
    assert verify.main([], runner=runner, repo=repo) == 0
    sha = verify.resolve(repo, "HEAD")
    state = state_of(repo)
    assert state["sha"] == sha
    assert state["tiers"] == list(verify.TIERS)
    assert set(state["runs"]) == set(verify.TIERS)
    assert all(sha[:8] in run for run in state["runs"].values())
    assert set(state["trees"]) == {"src", "tests", "tools"}
    assert "VERDICT: green  sha %s" % sha[:8] in capsys.readouterr().out


def test_a_manual_partial_run_writes_nothing(repo, tmp_path, capsys):
    assert verify.main(["--tiers", "fast"], runner=FakeRunner(tmp_path / "runs"), repo=repo) == 0
    assert not (repo / "temp" / "verify" / "last.json").exists()
    assert "not recorded (partial run)" in capsys.readouterr().out


def test_auto_with_base_writes_nothing(repo, tmp_path):
    runner = FakeRunner(tmp_path / "runs")
    verify.main([], runner=runner, repo=repo)
    base_sha = state_of(repo)["sha"]
    commit(repo, {"tests/test_t2.py": "t2"}, "test change")
    assert verify.main(["--auto", "--base", base_sha], runner=runner, repo=repo) == 0
    assert state_of(repo)["sha"] == base_sha


def test_auto_skips_changes_that_no_test_reads(repo, tmp_path, capsys):
    runner = FakeRunner(tmp_path / "runs")
    verify.main([], runner=runner, repo=repo)
    commit(repo, {"work_items/w.md": "w"}, "work item text")
    runner.calls.clear()
    assert verify.main(["--auto"], runner=runner, repo=repo) == 0
    assert runner.calls == []
    assert "VERDICT: skipped (not read by any test)" in capsys.readouterr().out


def test_auto_with_a_path_no_rule_knows_is_an_error_and_runs_nothing(repo, tmp_path, capsys):
    runner = FakeRunner(tmp_path / "runs")
    verify.main([], runner=runner, repo=repo)
    before = state_of(repo)
    commit(repo, {"assets/unknown.png": "x"}, "a file no rule knows")
    runner.calls.clear()
    assert verify.main(["--auto"], runner=runner, repo=repo) == verify.EXIT_ERROR
    assert runner.calls == []
    assert "VERDICT: error" in capsys.readouterr().out
    assert state_of(repo) == before           # no green state for it


def test_auto_without_base_writes_and_picks_tiers_from_the_change(repo, tmp_path):
    runner = FakeRunner(tmp_path / "runs")
    assert verify.main(["--auto"], runner=runner, repo=repo) == 0        # no record yet: all tiers
    assert [tier for tier, _ in runner.calls] == list(verify.TIERS)
    assert state_of(repo)["tiers"] == list(verify.TIERS)
    commit(repo, {"tests/test_t2.py": "t2"}, "test change")
    runner.calls.clear()
    assert verify.main(["--auto"], runner=runner, repo=repo) == 0
    assert [tier for tier, _ in runner.calls] == ["select"]
    assert state_of(repo)["tiers"] == ["select"]
    commit(repo, {"src/core/Errors.ahk": "e"}, "a hub file changes")
    runner.calls.clear()
    assert verify.main(["--auto"], runner=runner, repo=repo) == 0
    assert [tier for tier, _ in runner.calls] == ["fast", "foundation", "slow"]


def test_a_green_run_on_a_branch_is_not_recorded(repo, tmp_path, capsys):
    git(repo, "checkout", "-q", "-b", "wip")
    commit(repo, {"src/a.ahk": "branch change"}, "branch change")
    assert verify.main([], runner=FakeRunner(tmp_path / "runs"), repo=repo) == 0
    assert not (repo / "temp" / "verify" / "last.json").exists()
    out = capsys.readouterr().out
    assert "not recorded (not on v2-port)" in out and "VERDICT: green" in out


def test_a_green_run_of_an_ancestor_of_v2_port_is_recorded(repo, tmp_path):
    base_sha = verify.resolve(repo, "HEAD")
    commit(repo, {"doc/e.md": "e"}, "v2-port moves on")
    assert verify.main(["--ref", base_sha], runner=FakeRunner(tmp_path / "runs"), repo=repo) == 0
    assert state_of(repo)["sha"] == base_sha


def test_a_run_folder_of_another_sha_is_red_with_a_reason(repo, tmp_path, capsys):
    folder = fake_folder(tmp_path / "runs", "20261016-000000-deadbeef-fast-1", "1 passed in 1.0s", ["ok"])

    def wrong_sha(tier, sha):
        return 0, "[run_suite] output: %s\n" % (folder / "output.txt")

    assert verify.main(["--tiers", "fast"], runner=wrong_sha, repo=repo) == 1
    assert "does not name the sha" in capsys.readouterr().out


def test_red_run_exits_1_names_the_failed_tests_and_keeps_the_old_state(repo, tmp_path, capsys):
    verify.main([], runner=FakeRunner(tmp_path / "runs"), repo=repo)
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


def test_each_tier_reports_its_start_and_its_end(repo, tmp_path, capsys):
    assert verify.main(["--tiers", "fast,slow"], runner=FakeRunner(tmp_path / "runs"), repo=repo) == 0
    out = capsys.readouterr().out
    for tier in ("fast", "slow"):
        started = [line for line in out.splitlines() if line.endswith("%s: started" % tier)]
        finished = [line for line in out.splitlines() if line.endswith("%s: finished (exit 0)" % tier)]
        assert len(started) == 1 and len(finished) == 1
        assert started[0].startswith("[") and "] " in started[0]          # with the time
    assert "VERDICT: green" in out                                       # the verdict line is unchanged


def test_progress_goes_to_stderr_when_the_output_is_json(repo, tmp_path, capsys):
    assert verify.main(["--tiers", "fast", "--json"], runner=FakeRunner(tmp_path / "runs"), repo=repo) == 0
    captured = capsys.readouterr()
    assert json.loads(captured.out)["verdict"] == "green"                # stdout is still one JSON object
    assert "fast: started" in captured.err and "fast: finished (exit 0)" in captured.err


def test_auto_and_tiers_exclude_each_other(repo, capsys):
    assert verify.main(["--auto", "--tiers", "fast"], runner=FakeRunner(repo), repo=repo) == 2


def test_unknown_tier_is_a_usage_error(repo):
    assert verify.main(["--tiers", "fast,gui"], runner=FakeRunner(repo), repo=repo) == 2


def test_unknown_ref_is_a_tool_error(repo, capsys):
    assert verify.main(["--ref", "no-such-ref"], runner=FakeRunner(repo), repo=repo) == 2


def test_provisional_ids_are_a_note_not_a_failure(repo, tmp_path, capsys):
    commit(repo, {"doc/OPEN-ITEMS.md": "### %s*: a finding\n" % ("F-" + "9001")}, "branch finding")
    runner = FakeRunner(tmp_path / "runs")
    assert verify.main(["--tiers", "fast"], runner=runner, repo=repo) == 0
    assert "note: provisional finding IDs" in capsys.readouterr().out
