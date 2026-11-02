"""WI-0134: the demonstration flows in the manager, headless (ManagerOps and ManagerModel through cmd.test.op): the three
flows are shown, a demo cannot be deleted or renamed, the question offers to hide all of them (v1), and the setting
HideDemoFlows hides the group. The window (the group, the tree) is checked by the owner (manual check 12).
"""

from test_manager import FLOW, wait_until
from test_manager_editor import finish, start_manager
from test_manager_flows import answers, op, state, wait_state
from support.timing import scaled

DEMO = "Flow 806132298"          # Joke teller
DEMOS = ["Flow 1369089307", "Flow 1428714744", "Flow 806132298"]


def demo_flows(obs):
    return sorted(f["flowId"] for f in state(obs)["flows"] if f["demo"] is True)


def test_the_demonstration_flows_are_listed_and_kept_out_of_the_categories(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert wait_until(lambda: demo_flows(obs) == sorted(DEMOS), scaled(10)), demo_flows(obs)
        listed = [i for c in state(obs)["categories"] for i in c["flows"]]
        assert not set(DEMOS) & set(listed)
        assert state(obs)["hideDemos"] is False
    finally:
        finish(sup, obs)


def test_delete_of_a_demo_answered_no_keeps_it(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert wait_until(lambda: demo_flows(obs) == sorted(DEMOS), scaled(10))
        answers(obs, hideDemosDelete="no")
        payload = op(obs, "delete", flowIds=[DEMO])
        assert payload["sent"] is False
        assert DEMO in demo_flows(obs)
        assert state(obs)["hideDemos"] is False
    finally:
        finish(sup, obs)


def test_delete_of_a_demo_answered_yes_hides_all_demos_and_deletes_nothing(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert wait_until(lambda: demo_flows(obs) == sorted(DEMOS), scaled(10))
        answers(obs, hideDemosDelete="yes")
        op(obs, "delete", flowIds=[DEMO])
        assert wait_state(obs, lambda s: s["hideDemos"] is True and s["settings"].get("HideDemoFlows") in (True, 1))
        assert demo_flows(obs) == sorted(DEMOS)              # the engine keeps them loaded (M-0186)
    finally:
        finish(sup, obs)


def test_rename_of_a_demo_is_not_sent_and_the_question_offers_to_hide_them(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert wait_until(lambda: demo_flows(obs) == sorted(DEMOS), scaled(10))
        answers(obs, hideDemosRename="yes")
        payload = op(obs, "rename", flowId=DEMO)
        assert payload["sent"] is False
        assert wait_state(obs, lambda s: s["hideDemos"] is True)
        name = [f["name"] for f in state(obs)["flows"] if f["flowId"] == DEMO][0]
        assert name == "Joke teller"
    finally:
        finish(sup, obs)


def test_a_demo_is_moved_to_no_category(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert wait_until(lambda: demo_flows(obs) == sorted(DEMOS), scaled(10))
        op(obs, "move", flowIds=[DEMO], category="")
        listed = [i for c in state(obs)["categories"] for i in c["flows"]]
        assert DEMO not in listed
        assert DEMO in demo_flows(obs)
    finally:
        finish(sup, obs)


def test_the_user_flow_is_not_a_demo(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        assert wait_until(lambda: demo_flows(obs) == sorted(DEMOS), scaled(10))
        assert FLOW not in demo_flows(obs)
    finally:
        finish(sup, obs)
