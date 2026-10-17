"""WI-0074: the flow tree and the operations of the manager (src/manager/ManagerOps.ahk), headless, through the test driver.

Every operation and every question of the manager is run through cmd.test.op (ManagerDriver): the questions are answered by
the test (op "answers"), the engine answers the commands for real. The model's state comes from cmd.test.state, the
events of the manager from cmd.test.trace. The window and its drag and drop are tested in tests/fault/test_manager_window.py
(gui tier).

Questions and their two answers (PROTOCOL 4.2, E0056, E0063, E0066, E0067):
  independent   a flow that is not enabled, with enabled independent triggers: yes disables them too (all), no changes nothing
  force         a switch that the engine refuses because the state file cannot be read: yes writes the state of the session, no
                changes nothing
  delete        yes removes the flow (final), no keeps it
  categoryDelete, categoryMove  yes deletes the category and moves its flows to the chosen category, no changes nothing
  rename, categoryNew, categoryRename: the name the dialog gives; Cancel (no text) changes nothing
"""

import ctypes
import json
import time

import pytest

from test_manager import FLOW, SKELETON_SRC, Sup, connect_obs, engine_snapshot, finish, flow_data, managed  # noqa: F401
from test_manager import trace, wait_flow_loaded, wait_ready, wait_until

from support.timing import scaled

INDEPENDENT = "independent"
MANUAL = "element0000000001"
GENERIC_READ_WRITE = 0xC0000000
OPEN_EXISTING = 3


def op(obs, op_name, **args):
    """Runs a manager operation through cmd.test.op and returns its result payload (ok, sent, answer)."""
    ans = obs.request("manager", "cmd.test.op", dict(op=op_name, **args), timeout=scaled(10))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def answers(obs, **kinds):
    """The answers of the next questions (kind -> "yes"/"no", a text or a choice number). Questions not given: no, Cancel."""
    op(obs, "answers", answers=kinds)


def state(obs):
    return obs.request("manager", "cmd.test.state", {}, timeout=5)["payload"]["state"]


def flow(obs, flow_id=FLOW):
    for f in state(obs)["flows"]:
        if f["flowId"] == flow_id:
            return f
    return None


def named_categories(obs):
    """The names of the categories without the uncategorized group (listed last, with the name "")."""
    return [c for c, _ in categories(obs) if c != ""]


def categories(obs):
    """The categories of the model in their order: [(name, [flowId, ..]), ..] (the uncategorized group is named "")."""
    return [(c["name"], c["flows"]) for c in state(obs)["categories"]]


def category_flows(obs, name):
    for cat, flows in categories(obs):
        if cat == name:
            return flows
    return None


def wait_state(obs, check, timeout=10):
    return wait_until(lambda: check(state(obs)), scaled(timeout))


def ok_answer(payload):
    return payload["sent"] is True and payload["answer"]["ok"] is True


def sole_other_flow(obs):
    others = [f for f in state(obs)["flows"] if f["flowId"] != FLOW]
    assert len(others) == 1, others
    return others[0]


def write_flow(datadir, change=None):
    """The skeleton as the flow FLOW; change(flow_dict) edits it first (an independent trigger, a missing package)."""
    flows = datadir / "Flows"
    flows.mkdir(exist_ok=True)
    data = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    if change is not None:
        change(data)
    (flows / (FLOW + ".json")).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def add_independent_trigger(data):
    """A second trigger that does not follow the flow (followsFlow false), as in tests/integration/test_trigger_state.py."""
    other = dict(data["allElements"][MANUAL])
    other.pop("DefaultTrigger", None)
    other["ID"] = INDEPENDENT
    other["name"] = "Manual - independent"
    other["followsFlow"] = False
    data["allElements"][INDEPENDENT] = other


def start(procs, datadir, session_id, setup=None, extra_args=()):
    """Supervisor with storage, engine and the headless manager, the flow in place (setup runs before the start)."""
    if setup is not None:
        setup(datadir)
    else:
        flow_data(datadir)
    sup = Sup(procs, datadir, session_id, ["--start=storage,engine,manager", "--headless", *extra_args])
    obs = connect_obs(sup.pipe)
    wait_ready(obs, ["storage", "engine", "manager"])
    wait_flow_loaded(obs)
    # the model of the manager has the flows once its first snapshot is in (the operations need them)
    assert wait_until(lambda: any(f["flowId"] == FLOW for f in state(obs)["flows"]), scaled(10)), "no snapshot"
    return sup, obs


LOCKS = []      # handles of the locked state files of the running test; closed by the fixture


@pytest.fixture
def started(procs, datadir, session_id):
    """Opens a supervisor with the given setup; closes it and the locks at the end."""
    running = []

    def make(setup=None, extra_args=()):
        sup, obs = start(procs, datadir, session_id, setup, extra_args)
        running.append((sup, obs))
        return sup, obs

    yield make
    for sup, obs in running:
        obs.close()
        sup.close_files()
    kernel = ctypes.WinDLL("kernel32")
    for handle in LOCKS:
        kernel.CloseHandle(handle)
    LOCKS.clear()


def _lock_state_file():
    """A setup that opens FlowStates/<flow>.json without sharing: the storage cannot read it (a read error, E0063)."""
    def setup(d):
        flow_data(d)
        (d / "FlowStates").mkdir(exist_ok=True)
        path = d / "FlowStates" / (FLOW + ".json")
        path.write_text(json.dumps({"formatVersion": 1, "enabled": []}), encoding="utf-8")
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.restype = ctypes.c_void_p
        kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p,
                                       ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
        handle = kernel.CreateFileW(str(path), GENERIC_READ_WRITE, 0, None, OPEN_EXISTING, 0, None)
        assert handle not in (None, 0, ctypes.c_void_p(-1).value), "could not lock the state file"
        LOCKS.append(handle)
    return setup


def _independent_state():
    def setup(d):
        write_flow(d, add_independent_trigger)
        (d / "FlowStates").mkdir(exist_ok=True)
        (d / "FlowStates" / (FLOW + ".json")).write_text(json.dumps({"formatVersion": 1, "enabled": [INDEPENDENT]}),
                                                         encoding="utf-8")
    return setup


# --- switches: enable, disable, the questions of the independent triggers and of an unknown state -----------------------

def test_enable_and_disable_switch_the_flow_and_the_buttons_follow(managed):
    sup, obs = managed
    assert wait_until(lambda: flow(obs) is not None, scaled(10)), "the model has no flows"
    op(obs, "select", flowId=FLOW)                        # the Enable button shows the focused flow
    assert ok_answer(op(obs, "enable", flowIds=[FLOW]))
    assert wait_state(obs, lambda s: flow(obs)["enabled"] is True)
    assert state(obs)["enableIsDisable"] is True
    assert ok_answer(op(obs, "disable", flowIds=[FLOW]))
    assert wait_state(obs, lambda s: not flow(obs)["enabled"])
    assert finish(sup, obs) == 0


def test_disable_of_an_inactive_flow_with_independent_triggers_yes_disables_them(started):
    sup, obs = started(_independent_state())
    assert wait_state(obs, lambda s: flow(obs) is not None and flow(obs)["independentActive"] == 1)
    assert flow(obs)["enabled"] is False
    answers(obs, independent="yes")
    assert ok_answer(op(obs, "disable", flowIds=[FLOW]))
    assert wait_state(obs, lambda s: flow(obs)["independentActive"] == 0), flow(obs)


def test_disable_of_an_inactive_flow_with_independent_triggers_no_changes_nothing(started):
    sup, obs = started(_independent_state())
    answers(obs, independent="no")
    payload = op(obs, "disable", flowIds=[FLOW])
    assert payload["sent"] is False                       # no command was sent
    time.sleep(scaled(0.5))
    assert flow(obs)["independentActive"] == 1 and flow(obs)["enabled"] is False


def test_a_switch_refused_for_an_unknown_state_asks_for_the_force_no_changes_nothing(started):
    sup, obs = started(_lock_state_file())
    assert wait_state(obs, lambda s: flow(obs) is not None and flow(obs)["stateError"] != ""), flow(obs)
    answers(obs, force="no")
    payload = op(obs, "enable", flowIds=[FLOW])
    assert payload["sent"] is True and payload["answer"]["ok"] is False
    assert "cannot be read" in payload["answer"]["message"], payload
    assert flow(obs)["enabled"] is False


def test_a_switch_refused_for_an_unknown_state_yes_writes_the_state_of_the_session(started):
    sup, obs = started(_lock_state_file())
    assert wait_state(obs, lambda s: flow(obs) is not None and flow(obs)["stateError"] != ""), flow(obs)
    answers(obs, force="yes")
    payload = op(obs, "enable", flowIds=[FLOW])
    assert ok_answer(payload), payload
    assert wait_state(obs, lambda s: flow(obs)["enabled"] is True and flow(obs)["stateError"] == "")


def test_enabling_a_flow_with_a_missing_package_reports_the_trigger(started):
    def missing(d):
        def change(data):
            data["allElements"][MANUAL]["package"] = "NoSuchPackage"
        write_flow(d, change)
    sup, obs = started(missing)
    assert ok_answer(op(obs, "enable", flowIds=[FLOW]))
    notice = wait_until(lambda: [e for e in trace(obs) if e["type"] == "manager.notice"], scaled(10))
    assert notice, [(e["type"], e["payload"]) for e in trace(obs) if "trigger" in e["type"] or "notice" in e["type"]]
    assert notice[0]["payload"]["elementId"] == MANUAL and notice[0]["payload"]["message"] != ""


# --- flows: create, duplicate, delete, rename, move ---------------------------------------------------------------------

def test_new_flow_is_added_to_the_list_and_another_client_sees_its_flow_too(started):
    sup, obs = started()
    payload = op(obs, "create", category="")
    assert ok_answer(payload) and payload["answer"]["payload"]["flowId"]
    assert wait_state(obs, lambda s: len(s["flows"]) == 2)
    other = obs.request("engine", "cmd.flow.create", {"name": "From another client"}, timeout=scaled(10))
    assert other["payload"]["ok"] is True, other
    assert wait_state(obs, lambda s: any(f["name"] == "From another client" for f in s["flows"]))


def test_duplicate_makes_a_copy_with_the_next_name(started):
    sup, obs = started()
    assert ok_answer(op(obs, "duplicate", flowId=FLOW))
    assert wait_state(obs, lambda s: any(f["name"] == "Skeleton 2" for f in s["flows"]))


def test_delete_answered_no_keeps_the_flow(started):
    sup, obs = started()
    answers(obs, delete="no")
    payload = op(obs, "delete", flowIds=[FLOW])
    assert payload["sent"] is False
    time.sleep(scaled(0.3))
    assert flow(obs) is not None


def test_delete_answered_yes_removes_the_flow_for_good(started):
    sup, obs = started()
    answers(obs, delete="yes")
    assert ok_answer(op(obs, "delete", flowIds=[FLOW]))
    assert wait_state(obs, lambda s: all(f["flowId"] != FLOW for f in s["flows"]))
    engine = engine_snapshot(obs)
    assert all(f["flowId"] != FLOW for f in engine["flows"])


def test_rename_with_the_dialog_accepts_a_new_name(started):
    sup, obs = started()
    answers(obs, rename="Renamed flow")
    assert ok_answer(op(obs, "rename", flowId=FLOW))
    assert wait_state(obs, lambda s: flow(obs)["name"] == "Renamed flow")


def test_rename_with_the_dialog_refuses_a_taken_name_before_the_engine(started):
    sup, obs = started()
    assert op(obs, "create", category="")["sent"] is True
    assert wait_state(obs, lambda s: len(s["flows"]) == 2)
    taken = sole_other_flow(obs)["name"]
    answers(obs, rename=taken)
    payload = op(obs, "rename", flowId=FLOW)
    assert payload["sent"] is False                       # the dialog's check refused the name: nothing was sent
    assert flow(obs)["name"] == "Skeleton"


def test_rename_refused_by_the_engine_is_answered_bad_payload(started):
    sup, obs = started()
    payload = op(obs, "rename", flowId=FLOW, name="bad|name")
    assert payload["sent"] is True and payload["answer"]["ok"] is False
    assert payload["answer"]["code"] == "bad_payload", payload
    assert flow(obs)["name"] == "Skeleton"


def test_move_puts_a_flow_into_a_category_before_another_flow(started):
    sup, obs = started()
    answers(obs, categoryNew="Work")
    assert ok_answer(op(obs, "catNew"))
    assert wait_state(obs, lambda s: any(c["name"] == "Work" for c in s["categories"]))
    assert ok_answer(op(obs, "create", category="Work"))
    assert ok_answer(op(obs, "create", category="Work"))
    assert wait_state(obs, lambda s: len(category_flows(obs, "Work") or []) == 2)
    first, second = category_flows(obs, "Work")
    assert ok_answer(op(obs, "move", flowIds=[second], category="Work", before=first))
    assert wait_state(obs, lambda s: category_flows(obs, "Work") == [second, first])


def test_move_of_a_flow_to_another_category_removes_it_from_the_old_one(started):
    sup, obs = started()
    answers(obs, categoryNew="Work")
    op(obs, "catNew")
    assert wait_state(obs, lambda s: any(c["name"] == "Work" for c in s["categories"]))
    assert ok_answer(op(obs, "move", flowIds=[FLOW], category="Work"))
    assert wait_state(obs, lambda s: flow(obs)["category"] == "Work")
    assert FLOW not in (category_flows(obs, "Skeleton") or [])
    assert FLOW in category_flows(obs, "Work")


# --- categories ---------------------------------------------------------------------------------------------------------

def test_new_category_rename_and_the_delete_answered_no(started):
    sup, obs = started()
    answers(obs, categoryNew="Office")
    assert ok_answer(op(obs, "catNew"))
    assert wait_state(obs, lambda s: any(c["name"] == "Office" for c in s["categories"]))
    answers(obs, categoryRename="Work")
    assert ok_answer(op(obs, "catRename", name="Office"))
    assert wait_state(obs, lambda s: any(c["name"] == "Work" for c in s["categories"]))
    answers(obs, categoryDelete="no")
    assert op(obs, "catDelete", name="Work")["sent"] is False
    assert any(c["name"] == "Work" for c in state(obs)["categories"])


def test_delete_category_yes_moves_its_flows_to_the_chosen_category(started):
    sup, obs = started()
    answers(obs, categoryDelete="yes", categoryMove=1)    # choice 1 is Uncategorized
    assert ok_answer(op(obs, "catDelete", name="Skeleton"))
    assert wait_state(obs, lambda s: all(c["name"] != "Skeleton" for c in s["categories"]))
    assert flow(obs)["category"] == ""


def test_delete_category_cancelled_in_the_choice_changes_nothing(started):
    sup, obs = started()
    answers(obs, categoryDelete="yes", categoryMove=0)
    assert op(obs, "catDelete", name="Skeleton")["sent"] is False
    assert any(c["name"] == "Skeleton" for c in state(obs)["categories"])
    assert flow(obs)["category"] == "Skeleton"


def test_sort_alphabetically_orders_the_categories_and_the_uncategorized_group_is_last(started):
    sup, obs = started()
    for name in ("Zeta", "alpha"):
        answers(obs, categoryNew=name)
        op(obs, "catNew")
    assert wait_state(obs, lambda s: len(named_categories(obs)) == 3)
    assert ok_answer(op(obs, "catSort"))
    names = [c for c, _ in categories(obs) if c != ""]
    assert names == sorted(names, key=str.lower), names


def test_a_category_can_be_moved_before_another(started):
    sup, obs = started()
    for name in ("Alpha", "Beta"):
        answers(obs, categoryNew=name)
        op(obs, "catNew")
    assert wait_state(obs, lambda s: len(named_categories(obs)) == 3)
    assert ok_answer(op(obs, "catMove", name="Beta", before="Skeleton"))
    assert wait_state(obs, lambda s: [c["name"] for c in s["categories"]].index("Beta")
                      < [c["name"] for c in s["categories"]].index("Skeleton"))
    names = [c["name"] for c in state(obs)["categories"]]
    assert names.index("Beta") < names.index("Skeleton"), names


# --- selection --------------------------------------------------------------------------------------------------------------

def test_ctrl_click_selects_several_flows_and_the_operations_act_on_them(started):
    sup, obs = started()
    assert op(obs, "create", category="")["sent"] is True
    assert wait_state(obs, lambda s: len(s["flows"]) == 2)
    other = sole_other_flow(obs)["flowId"]
    op(obs, "select", flowId=FLOW)
    payload = op(obs, "selectToggle", flowId=other)
    assert sorted(payload["selectedFlows"]) == sorted([FLOW, other])
    st = state(obs)
    assert len(st["selectedFlows"]) == 2 and st["buttons"]["Enable"] is True and st["buttons"]["Run"] is True
    answers(obs, delete="no")
    assert op(obs, "delete", flowIds=st["selectedFlows"])["sent"] is False


# --- the state of a running flow, live ----------------------------------------------------------------------------------------

def test_a_running_flow_is_shown_as_running_while_it_runs(started):
    sup, obs = started()
    assert ok_answer(op(obs, "run", flowId=FLOW))
    assert wait_until(lambda: any(e["type"] == "evt.flow.state" and e["payload"].get("executing")
                                  for e in trace(obs)), scaled(10)), "no running state in the manager's record"
    assert wait_state(obs, lambda s: flow(obs)["executing"] is False, timeout=15)


def slow_parallel(d):
    """The skeleton with a sleep of 3 s and the policy parallel: two instances can run at the same time."""
    def change(data):
        data["flowSettings"]["ExecutionPolicy"] = "parallel"
        data["allElements"]["element0000000002"]["pars"]["Duration"] = "3000"
    write_flow(d, change)


def test_the_running_instances_are_counted_in_the_snapshot_and_the_state(started):
    sup, obs = started(slow_parallel)
    for _ in range(2):
        ans = obs.request("engine", "cmd.flow.start", {"flowId": FLOW}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
    assert wait_state(obs, lambda s: flow(obs)["instances"] == 2, timeout=10), flow(obs)
    snap = obs.request("engine", "cmd.engine.snapshot", {}, timeout=scaled(5))["payload"]
    assert [f["instances"] for f in snap["flows"] if f["flowId"] == FLOW] == [2]
    assert any(e["type"] == "evt.flow.state" and e["payload"].get("instances") == 2 for e in trace(obs))
    obs.request("engine", "cmd.flow.stop", {"flowId": FLOW}, timeout=scaled(5))
    assert wait_state(obs, lambda s: flow(obs)["instances"] == 0 and flow(obs)["executing"] is False, timeout=10)


def test_a_flow_with_a_missing_package_of_an_action_is_marked_with_the_package(started):
    """E0080: the package of an element that is no trigger is reported too (the trigger case is above)."""
    def action_missing(d):
        def change(data):
            data["allElements"]["element0000000002"]["package"] = "NoSuchPackage"
        write_flow(d, change)
    sup, obs = started(action_missing)
    assert wait_state(obs, lambda s: flow(obs)["missingPackages"] == ["NoSuchPackage"], timeout=10), flow(obs)
    snap = obs.request("engine", "cmd.engine.snapshot", {}, timeout=scaled(5))["payload"]
    assert [f["missingPackages"] for f in snap["flows"] if f["flowId"] == FLOW] == [["NoSuchPackage"]]
    assert flow(obs)["triggerMessages"] == []        # the trigger itself is available
