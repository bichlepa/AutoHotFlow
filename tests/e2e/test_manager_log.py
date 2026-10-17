"""WI-0080: the log of the manager, headless (PROTOCOL 4.8, 4.6 cmd.storage.log.tail).

The same stack as tests/e2e/test_manager.py: supervisor, storage, engine and the headless manager, started through
tools/ahkrun.py. The test writes log entries (evt.log.append to storage), opens the log with the test command
cmd.test.op and reads the model with cmd.test.state. The log window itself is only made without --headless; it is
not run by the agents (the owner's manual check, WI-0082).
"""

import threading
import time

import pytest

from support.ahfclient import AhfClient
from support.timing import scaled
from test_manager import FLOW, finish, managed, wait_until  # noqa: F401 (managed is a fixture)

BURST_LINES = 5000
PING_LIMIT_S = scaled(1.0)     # a request to the manager is answered within this time during the burst
LOG_KEEP = 1000                # ManagerModel.LOG_KEEP


def manager_state(obs):
    ans = obs.request("manager", "cmd.test.state", {}, timeout=5)
    assert ans["payload"]["ok"], ans
    return ans["payload"]["state"]


def log_op(obs, action, flow_id=""):
    ans = obs.request("manager", "cmd.test.op", {"op": "log", "action": action, "flowId": flow_id}, timeout=8)
    assert ans["payload"]["ok"], ans
    return ans["payload"]["log"]


def log_filter(obs, level, group, flow_id):
    ans = obs.request("manager", "cmd.test.op",
                      {"op": "logFilter", "level": level, "group": group, "flowId": flow_id}, timeout=5)
    assert ans["payload"]["ok"], ans
    return ans["payload"]["log"]


def send_entry(client, level, source, flow_id, text):
    payload = {"ts": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime()), "level": level, "source": source, "text": text}
    if flow_id:
        payload["flowId"] = flow_id
    client.send("storage", "evt.log.append", payload)


def hub_topics(obs, name):
    """The topics the hub has for a role (cmd.diag.snapshot of the supervisor, hub.links)."""
    snap = obs.request("supervisor", "cmd.diag.snapshot", {}, timeout=5)["payload"]["snapshot"]
    for link in snap["hub"]["links"]:
        if link["name"] == name:
            return set(link["topics"])
    return set()


@pytest.mark.slow
def test_log_opens_with_the_tail_takes_new_entries_and_filters_them(procs, datadir, session_id, managed):
    sup, obs = managed
    writer = AhfClient(sup.pipe, "writer", connect_timeout=5.0)
    send_entry(writer, "a0", "storage", None, "tail one")
    send_entry(writer, "f1", "Flow 369404488", FLOW, "tail two")
    send_entry(writer, "t3", "Flow 369404488", FLOW, "tail three")
    assert wait_until(lambda: (datadir / "Log" / "Log.txt").exists()
                      and "tail three" in (datadir / "Log" / "Log.txt").read_text("utf-8"), 5)

    assert manager_state(obs)["log"]["open"] is False
    assert log_op(obs, "open")["open"] is True
    assert wait_until(lambda: manager_state(obs)["log"]["tailOk"] and manager_state(obs)["log"]["entries"] >= 3, 10)

    # New entries arrive while the log is open.
    send_entry(writer, "f2", "Flow 369404488", FLOW, "live four")
    writer.close()
    # Wait for this very entry: "seen" also counts entries of other sources (storage, the manager) and is no proof.
    assert wait_until(lambda: log_filter(obs, "3", "all", FLOW)["visible"] == 3, 10)

    # Filters (level digit, group letter, flow). Each call sets all three.
    assert log_filter(obs, "3", "all", FLOW)["visible"] == 3      # tail two, tail three, live four
    assert log_filter(obs, "1", "all", FLOW)["visible"] == 1      # f1 only: digit 2 and 3 are above 1
    assert log_filter(obs, "3", "a", FLOW)["visible"] == 0        # no app entry of this flow
    # E0081: there is no "thread" group; the t entry is shown with "all" only
    no_thread = obs.request("manager", "cmd.test.op", {"op": "logFilter", "group": "t"}, timeout=5)["payload"]
    assert no_thread["ok"] is False, no_thread
    assert log_filter(obs, "3", "all", FLOW)["visible"] == 3
    assert log_filter(obs, "0", "all", "")["visible"] >= 1        # tail one (a0) is among the errors

    bad = obs.request("manager", "cmd.test.op", {"op": "logFilter", "level": "9"}, timeout=5)["payload"]
    assert bad["ok"] is False, bad
    log_op(obs, "close")
    assert finish(sup, obs) == 0


@pytest.mark.slow
def test_closing_the_log_ends_the_subscription_and_its_entries(procs, datadir, session_id, managed):
    sup, obs = managed
    log_op(obs, "open", FLOW)
    assert wait_until(lambda: "log" in hub_topics(obs, "manager"), 10), hub_topics(obs, "manager")
    log_op(obs, "close")
    assert wait_until(lambda: "log" not in hub_topics(obs, "manager"), 10), hub_topics(obs, "manager")
    state = manager_state(obs)["log"]
    assert state["open"] is False and state["entries"] == 0
    seen = state["seen"]
    writer = AhfClient(sup.pipe, "writer", connect_timeout=5.0)
    send_entry(writer, "f1", "Flow 369404488", FLOW, "after the close")
    writer.close()
    time.sleep(scaled(0.5))
    assert manager_state(obs)["log"]["seen"] == seen      # nothing of topic log arrives while closed
    assert finish(sup, obs) == 0


@pytest.mark.slow
def test_a_burst_of_5000_lines_does_not_stall_the_manager_and_the_model_keeps_the_limit(procs, datadir, session_id,
                                                                                         managed):
    sup, obs = managed
    log_op(obs, "open")
    assert wait_until(lambda: manager_state(obs)["log"]["tailOk"], 10)
    before = manager_state(obs)["log"]["entries"]

    burst = AhfClient(sup.pipe, "burst", connect_timeout=5.0)

    def send_all():
        for i in range(BURST_LINES):
            send_entry(burst, "a2", "burst", None, "burst line %05d" % i)

    thread = threading.Thread(target=send_all, name="burst", daemon=True)
    worst = 0.0
    max_entries = 0
    thread.start()
    while thread.is_alive():             # the manager is asked while the lines are sent
        t0 = time.monotonic()
        state = manager_state(obs)["log"]
        worst = max(worst, time.monotonic() - t0)
        max_entries = max(max_entries, state["entries"])
        time.sleep(0.01)
    thread.join(timeout=30)
    burst.close()

    # The storage may drop lines above its send limit (PROTOCOL 4.1, F-0016): the count of what arrived is taken as it is.
    # It is final when it has not changed for one second.
    seen = -1
    stable_since = time.monotonic()
    deadline = time.monotonic() + scaled(30)
    while time.monotonic() < deadline:
        now_seen = manager_state(obs)["log"]["seen"]
        if now_seen != seen:
            seen = now_seen
            stable_since = time.monotonic()
        elif time.monotonic() - stable_since >= 1.0:
            break
        time.sleep(0.1)
    final = manager_state(obs)["log"]
    print("\nmanager requests during the burst: slowest %.1f ms, entries at most %d, lines seen %d of %d"
          % (worst * 1000, max_entries, final["seen"], BURST_LINES))
    assert final["seen"] > 0
    assert worst < PING_LIMIT_S, worst
    assert max_entries <= LOG_KEEP
    assert final["entries"] == min(LOG_KEEP, before + final["seen"]), (before, final)
    # E0082: the drop of lines in the hub stays, so not all 5000 lines arrive. The model must show what storage wrote:
    # its newest entries are the newest lines of Log.txt (the tail reads the current file only, so it may hold fewer
    # lines than the model keeps; the model's newest entries must then be the same).
    tail = obs.request("storage", "cmd.storage.log.tail", {"limit": LOG_KEEP}, timeout=scaled(10))["payload"]
    assert tail["ok"], tail
    written = ["%s|%s|%s" % (e["ts"], e["source"], e["text"]) for e in tail["entries"]]
    assert written, "storage has no entries"
    assert final["keys"][-len(written):] == written, (len(written), final["keys"][-3:], written[-3:])
    log_op(obs, "close")
    assert finish(sup, obs) == 0
