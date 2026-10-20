"""Guard of the test group table (tests/support/group_table.py, doc/TEST-GROUPS.md).

The table decides which tests a change needs. These tests keep it complete and true: every file under src/ has an
area, every test file has a group, every entry points at something that exists, and a few example changes select what
the rules promise. When one of them fails, the message says what to add to the table.
"""

import re
import subprocess
from pathlib import Path

import pytest

from support import groups
from support.group_table import COVERS, NODE_GROUPS, OWN_TEST_GROUPS, SMOKE_FOR, SOURCE_AREAS, TEST_GROUPS

REPO = Path(__file__).resolve().parents[1]
TESTS = REPO / "tests"

# Test groups that exist besides the ones that carry the name of a source area.
EXTRA_GROUPS = {"base", "element-units", "elements-e2e", "packages", "perf", "docs", "architecture", "tools",
                "test-support"}
NO_OWN_TESTS_NEEDED = {"base-hub", "element"}      # base-hub selects everything; element files use COVERS
AREA_NAMES = {area for area, _ in SOURCE_AREAS}
SMOKE_AREA_NAMES = (AREA_NAMES - {"base-hub"}) | {"element-trigger"}      # element-trigger: a change of a trigger element
GROUP_NAMES = (AREA_NAMES - NO_OWN_TESTS_NEEDED - {"elements-base", "elements-pkg", "elements-gen"}) | EXTRA_GROUPS


def source_files():
    return sorted(p.relative_to(REPO).as_posix() for p in (REPO / "src").rglob("*") if p.is_file())


def all_test_files():
    found = [p.relative_to(TESTS).as_posix() for p in TESTS.rglob("test_*.py")]
    found += ["ahk/" + p.name for p in (TESTS / "ahk").glob("*.test.ahk")]
    return sorted(found)


def entry_exists(entry):
    """True when a table entry names an existing test file, or an existing test function (`file::function`)."""
    file_key, _, func = entry.partition("::")
    path = TESTS / file_key
    if not path.is_file():
        return False
    return not func or bool(re.search(r"^(?:async )?def %s\(" % re.escape(func), path.read_text(encoding="utf-8"), re.M))


def test_every_source_file_has_an_area():
    missing = [p for p in source_files() if groups.area_of(p) is None]
    assert not missing, ("no area for %s: add a pattern to SOURCE_AREAS in tests/support/group_table.py "
                         "(doc/TEST-GROUPS.md, section 'New source code')" % ", ".join(missing))


def test_every_test_file_has_a_group():
    missing = [k for k in all_test_files() if k not in TEST_GROUPS]
    assert not missing, ("no test group for %s: add it to TEST_GROUPS in tests/support/group_table.py "
                         "(doc/TEST-GROUPS.md, section 'New tests'); without an entry it would always run" %
                         ", ".join(missing))


def test_every_table_entry_points_at_an_existing_test_file():
    gone = [k for k in TEST_GROUPS if not (TESTS / k).is_file()]
    assert not gone, "TEST_GROUPS names files that do not exist: %s" % ", ".join(gone)


def test_group_names_are_known():
    unknown = {(k, g) for k, values in TEST_GROUPS.items() for g in values if g not in GROUP_NAMES}
    assert not unknown, "unknown test group (typo?): %s" % sorted(unknown)
    empty = [k for k, values in TEST_GROUPS.items() if not values]
    assert not empty, "a test file without a group never gets selected by a group: %s" % empty
    bad_own = {g for values in OWN_TEST_GROUPS.values() for g in values} - GROUP_NAMES
    assert not bad_own, "OWN_TEST_GROUPS names unknown groups: %s" % sorted(bad_own)


def test_every_group_has_a_test_file():
    used = {g for values in TEST_GROUPS.values() for g in values} | {g for v in NODE_GROUPS.values() for g in v}
    unused = sorted(GROUP_NAMES - used)
    assert not unused, "groups without any test file (remove them or add the tests): %s" % ", ".join(unused)


def test_every_source_area_runs_some_test_group():
    for area in AREA_NAMES - NO_OWN_TESTS_NEEDED:
        for name in OWN_TEST_GROUPS.get(area, [area]):
            assert name in GROUP_NAMES, "area %s runs group %s, which does not exist" % (area, name)


def test_every_element_has_a_covers_entry():
    elements = [p for p in source_files() if groups.area_of(p) == "element"]
    missing = [p for p in elements if p not in COVERS]
    assert not missing, ("no COVERS entry for %s: list the tests of that element in COVERS, or [] when only the element "
                         "units should run (doc/TEST-GROUPS.md, section 'New source code')" % ", ".join(missing))
    stale = [p for p in COVERS if p not in elements]
    assert not stale, "COVERS names files that are no element files: %s" % ", ".join(stale)
    gone = [t for tests in COVERS.values() for t in tests if not entry_exists(t)]
    assert not gone, "COVERS names tests that do not exist: %s" % ", ".join(gone)


def test_every_node_group_names_an_existing_test_function_and_known_groups():
    gone = [k for k in NODE_GROUPS if not entry_exists(k)]
    assert not gone, "NODE_GROUPS names tests that do not exist: %s" % ", ".join(gone)
    unknown = {g for values in NODE_GROUPS.values() for g in values} - GROUP_NAMES
    assert not unknown, "NODE_GROUPS names unknown groups: %s" % sorted(unknown)


def test_every_smoke_test_exists_and_names_known_areas():
    problems = []
    for key, areas in SMOKE_FOR.items():
        if not entry_exists(key):
            problems.append("%s: no such test file or function" % key)
        for area in areas:
            if area not in SMOKE_AREA_NAMES:
                problems.append("%s: unknown or not usable area %s" % (key, area))
    assert not problems, "\n".join(problems)


# --- what the rules promise (examples; the reasons are in doc/TEST-GROUPS.md) ---------------------------------------

def test_a_ui_change_runs_the_ui_tests_and_not_the_supervisor_or_the_manager():
    sel = groups.select(["src/core/GuiLayout.ahk"])
    assert not sel.everything
    assert sel.accepts("ahk/core_gui_layout.test.ahk")
    assert sel.accepts("integration/test_core_e_dialogs.py")
    assert not sel.accepts("integration/test_supervisor.py", "test_required_roles_are_ready_within_3_seconds")
    assert not sel.accepts("fault/test_process_crash.py", "test_killed_engine_is_reported_restarted_and_the_others_are_untouched")
    assert not sel.accepts("e2e/test_manager_flows.py", "test_new_flow_is_added_to_the_list_and_another_client_sees_its_flow_too")
    assert not sel.accepts("integration/test_engine.py", "test_x")


def test_an_element_change_runs_its_own_tests_and_the_element_smoke_unit_only():
    path = "src/elements/Default/Actions/Action_Sleep.ahk"
    sel = groups.select([path])
    assert sel.accepts("ahk/element_sleep.test.ahk")
    assert sel.accepts("ahk/element_smoke.test.ahk")
    assert sel.accepts("integration/test_flowrun.py", "test_a_flow_runs_headless_and_shows_its_path_and_variables")
    assert not sel.accepts("integration/test_flowrun.py", "test_variables_are_preset_and_read_through_the_data_folder")
    assert not sel.accepts("e2e/test_manager_import.py", "test_x")
    assert not sel.accepts("integration/test_supervisor.py", "test_x")
    assert not sel.accepts("integration/test_pipe.py", "test_x")


def test_a_change_of_the_element_base_runs_the_smoke_tests_of_its_users():
    sel = groups.select(["src/elements/base/ElementRunner.ahk"])
    assert sel.accepts("ahk/element_runner.test.ahk")
    assert sel.accepts("integration/test_flowrun.py", "test_a_flow_runs_headless_and_shows_its_path_and_variables")
    assert sel.accepts("integration/test_worker.py", "test_throwing_element_is_reported_as_exception_and_the_worker_keeps_running")
    assert not sel.accepts("integration/test_worker.py", "test_run_is_accepted_at_once_and_the_result_comes_as_done")
    assert not sel.accepts("integration/test_core_c_loops.py", "test_x")


def test_a_hub_file_selects_everything():
    assert groups.select(["src/core/Errors.ahk"]).everything
    assert groups.select(["src/AhfBoot.ahk"]).everything


def test_a_shared_module_runs_the_smoke_test_of_each_user():
    sel = groups.select(["src/storage/Storage.ahk"])
    assert sel.accepts("integration/test_storage.py", "test_x")
    assert sel.accepts("e2e/test_manager_import.py", "test_every_flow_of_the_folder_is_imported_with_its_id_and_disabled")
    assert not sel.accepts("e2e/test_manager_import.py", "test_something_else")


def test_documentation_runs_only_the_cheap_checks():
    sel = groups.select(["doc/CONVENTIONS.md"])
    assert not sel.everything and sel.groups == {"docs", "architecture"}
    assert sel.accepts("test_doc_index.py")
    assert not sel.accepts("integration/test_supervisor.py")


def test_papers_that_no_test_reads_select_nothing():
    assert groups.select(["work_items/phase3/README.md", ".claude/x"]).is_empty()
    assert groups.select([]).is_empty()


def test_a_changed_test_selects_itself_and_a_test_without_entry_always_runs():
    sel = groups.select(["tests/integration/test_pipe.py"])
    assert sel.accepts("integration/test_pipe.py")
    assert not sel.accepts("integration/test_supervisor.py")
    assert sel.accepts("integration/test_not_in_the_table_yet.py")


def test_infrastructure_selects_everything():
    for path in ("tests/conftest.py", "tests/support/procs.py", "tests/integration/helpers/AutoHotFlowTest.ahk",
                 "tools/ahkrun.py", "pytest.ini", "tests/test_ahk_runner.py"):
        assert groups.select([path]).everything, path


def test_the_table_itself_runs_only_the_guard():
    sel = groups.select(["tests/support/group_table.py"])
    assert not sel.everything
    assert sel.accepts("test_groups.py")
    assert not sel.accepts("integration/test_supervisor.py")


def test_a_path_that_no_rule_knows_is_an_error_naming_the_file_and_the_fix():
    with pytest.raises(groups.UnknownPathError, match="something/new.bin") as info:
        groups.select(["something/new.bin"])
    assert "OTHER_RULES" in str(info.value) and "doc/TEST-GROUPS.md" in str(info.value)


def test_an_unknown_helper_or_data_file_is_an_error_not_a_full_run():
    for path in ("tests/integration/helpers/new_helper.ahk", "tests/data/flows/new/x.json", "assets/x.png",
                 "src/new_folder/x.ahk", "tests/ahk/helpers/new_bench.ahk"):
        assert not groups.classified(path), path
        with pytest.raises(groups.UnknownPathError):
            groups.select([path])


def test_a_deleted_file_without_rule_runs_everything_and_an_unknown_file_still_fails():
    """A path that the change deletes has no rule any more (WI-0088 removed src/core/PlaceholderRole.ahk): that is
    not an error, the deletion selects everything. A path that still exists and has no rule stays an error."""
    path = "src/core/PlaceholderRole.ahk"
    assert groups.select([path], [path]).everything
    with pytest.raises(groups.UnknownPathError):
        groups.select([path])


def test_a_deleted_file_with_a_rule_selects_by_its_rule():
    path = "src/storage/Storage.ahk"
    sel = groups.select([path], [path])
    assert not sel.everything and sel.accepts("integration/test_storage.py", "test_x")


def test_a_range_with_a_deletion_is_selected_from_git_not_refused(tmp_path):
    """The real case: a range of commits that deletes a source file. removed_paths lists the deletion, and the
    selection of the range runs (no UnknownPathError)."""
    def git(*args):
        return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *args], cwd=str(tmp_path),
                              capture_output=True, text=True, check=True).stdout
    git("init", "-q")
    (tmp_path / "src" / "core").mkdir(parents=True)
    (tmp_path / "src" / "core" / "Gone.ahk").write_text("x\n", encoding="utf-8", newline="")
    git("add", "-A")
    git("commit", "-q", "-m", "add")
    base = git("rev-parse", "HEAD").strip()
    git("rm", "-q", "src/core/Gone.ahk")
    git("commit", "-q", "-m", "delete")
    removed = groups.removed_paths("HEAD", tmp_path, base=base)
    assert removed == ["src/core/Gone.ahk"]
    sel = groups.select(["src/core/Gone.ahk"], removed)
    assert sel.everything


def test_the_editor_files_have_their_own_areas_render_and_editor_geometry():
    assert groups.area_of("src/editor/render/GdipFont.ahk") == "render"
    assert groups.area_of("src/editor/Scene.ahk") == "editor-geometry"
    sel = groups.select(["src/editor/render/GdipFont.ahk"])
    assert not sel.everything and "render" in sel.groups
    assert not sel.accepts("integration/test_supervisor.py", "test_required_roles_are_ready_within_3_seconds")


def test_every_tracked_file_is_classified_by_a_rule():
    """The table cannot rot silently: a tracked file that no rule knows would be an error for the first change that
    touches it, so this fails on the commit that adds it."""
    try:
        out = subprocess.run(["git", "ls-files"], cwd=str(REPO), capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        pytest.skip("not a git checkout")
    unknown = [p for p in out.splitlines() if p and not groups.classified(p)]
    assert not unknown, ("no rule for %s: add a rule to OTHER_RULES in tests/support/groups.py (or an area / a test "
                         "entry), doc/TEST-GROUPS.md section 6" % ", ".join(unknown))


def test_the_render_bench_helper_selects_its_groups_not_everything():
    sel = groups.select(["tests/ahk/helpers/render_bench.ahk"])
    assert not sel.everything
    assert {"render", "tools"} <= sel.groups


@pytest.mark.parametrize("path,area", [
    ("src/core/GuiLayout.ahk", "ui"), ("src/core/ipc/Frame.ahk", "transport"), ("src/supervisor/Stall.ahk", "recovery"),
    ("src/supervisor/Hub.ahk", "supervisor"), ("src/supervisor/DiagReport.ahk", "diagnosis"),
    ("src/engine/vars/VarWriter.ahk", "variables"), ("src/engine/WorkerBridge.ahk", "workers"),
    ("src/engine/TriggerArms.ahk", "triggers"), ("src/engine/Executor.ahk", "engine"),
    ("src/engine/core/FlowExprConvert.ahk", "expr"), ("src/engine/core/Scheduler.ahk", "engine"),
    ("src/elements/base/Dialogs.ahk", "ui"), ("src/elements/base/ElementRunner.ahk", "elements-base"),
    ("src/elements/Default/lib/ListOps.ahk", "element"), ("src/elements/Default/_includes_engine.ahk", "elements-pkg"),
    ("src/entry/generated/Elements_engine.ahk", "elements-gen"), ("src/tray/Tray.ahk", "tray"),
])
def test_areas_of_typical_files(path, area):
    assert (REPO / path).is_file(), path
    assert groups.area_of(path) == area


def test_a_loop_element_runs_its_own_tests_not_the_loop_logic_nor_the_scaling_measurements():
    sel = groups.select(["src/elements/Default/Loops/Loop_SimpleLoop.ahk"])
    assert sel.accepts("integration/test_core_c_loops.py", "test_simple_loop_counts")
    assert sel.accepts("ahk/element_loops.test.ahk")
    assert not sel.accepts("integration/test_core_c_loops.py", "test_parse_loop")
    assert not sel.accepts("integration/test_core_c_loops.py", "test_break_in_the_first_a_middle_and_the_last_pass")
    assert not sel.accepts("integration/test_core_c_loops.py", "test_a_long_loop_does_not_block_the_engine_and_costs_little_per_pass")


def test_the_loop_logic_runs_with_the_engine_and_the_scaling_measurements_only_in_full_runs():
    engine = groups.select(["src/engine/Executor.ahk"])
    assert engine.accepts("integration/test_core_c_loops.py", "test_break_in_the_first_a_middle_and_the_last_pass")
    assert not engine.accepts("integration/test_core_c_loops.py", "test_long_loops_do_not_scale_with_the_size_of_the_list_or_the_text")
    assert groups.select(["src/core/Errors.ahk"]).accepts(
        "integration/test_core_c_loops.py", "test_long_loops_do_not_scale_with_the_size_of_the_list_or_the_text")


def test_a_trigger_element_runs_its_own_tests_and_the_arming_smoke_test():
    sel = groups.select(["src/elements/Default/Triggers/Trigger_Periodic_Timer.ahk"])
    assert sel.accepts("integration/test_time_triggers.py", "test_the_periodic_timer_fires_about_every_interval")
    assert not sel.accepts("integration/test_time_triggers.py", "test_the_autohotflow_startup_trigger_fires_once_at_the_start")
    assert sel.accepts("integration/test_trigger_arming.py",
                       "test_an_enabled_trigger_is_armed_and_its_events_start_instances_with_their_variables")
    assert not sel.accepts("integration/test_triggerhost.py", "test_x")
    action = groups.select(["src/elements/Default/Actions/Action_Sleep.ahk"])
    assert not action.accepts("integration/test_trigger_arming.py",
                              "test_an_enabled_trigger_is_armed_and_its_events_start_instances_with_their_variables")
