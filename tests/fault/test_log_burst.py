"""F-17 and F-275: a burst of log lines.

Both tests guard the fix: log entries are droppable. Above a soft limit of the send queue the entry is dropped and
counted, and one line "n log lines dropped" is written when there is room again (Hub.LOG_SOFT_LIMIT,
Role.LOG_SEND_SOFT). The link and the role survive; the burst itself may lose lines, but never silently.

* F-275: a role logs thousands of lines in a tight loop. The hub's send queue to "storage" holds 1000 frames; the
  overflow closes the link to storage (queue_overflow), storage is judged hung and restarted, and the lines are lost.
* F-17: the same burst while the supervisor stands still. The role's own send queue overflows, the role loses its
  connection and ends after the orphan deadline ("hub not reachable"), although it did nothing wrong.

The test role echo (tests/integration/helpers/EchoRole.ahk) writes the lines on request (cmd.test.log).
"""

import re
import threading
import time

import psutil
import pytest

from faultkit import request_ok
from support.timing import scaled

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = [pytest.mark.fault, pytest.mark.slow]

BURST = 5000            # lines in one tight loop (3000 was enough in the first measurements)


def log_text(datadir, name="Log.txt"):
    path = datadir / "Log" / name
    return path.read_bytes().decode("utf-8", "replace") if path.exists() else ""


def test_a_burst_of_log_lines_does_not_cost_the_storage_link(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    pids = chain.wait_ready(["storage", "echo:a"])
    request_ok(chain.obs, "echo:a", "cmd.test.setlogtarget", {"to": "storage"})
    answer = request_ok(chain.obs, "echo:a", "cmd.test.log", {"count": BURST, "text": ""}, timeout=scaled(20))
    assert answer["logged"] == BURST
    time.sleep(scaled(3))
    chain.request_exit()
    assert chain.sup.wait_exit(timeout=40) == 0, chain.sup.text()
    sup_text = chain.sup.text()
    assert "queue_overflow" not in sup_text, sup_text[:2000]
    # Log.txt rotates into Log_old.txt (one old file). The drop notes are in the files of their sources.
    written = sum(log_text(datadir, name).count("~echo~ entry ") for name in ("Log.txt", "Log_old.txt"))
    dropped = sum(int(n) for source in ("hub", "role", "storage") for suffix in ("", "_old")
                  for n in re.findall(r"(\d+) log lines dropped", log_text(datadir, f"Log_{source}{suffix}.txt")))
    # No line is lost silently: every line is in the file or counted in a "n log lines dropped" line.
    assert written > 0
    assert written + dropped == BURST, (written, dropped)


def test_a_chatty_role_survives_a_long_stand_still_of_the_supervisor(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    pids = chain.wait_ready(["storage", "echo:a"])
    request_ok(chain.obs, "echo:a", "cmd.test.setlogtarget", {"to": "storage"})
    result = {}

    def ask():
        try:
            result["answer"] = chain.obs.request("echo:a", "cmd.test.log", {"count": 100000, "text": ""}, timeout=60)
        except Exception as e:      # the observer may lose its answer, that is not what this test is about
            result["error"] = repr(e)

    thread = threading.Thread(target=ask)
    thread.start()
    # Precondition: the role is inside its loop. A fixed sleep was not enough (F-276): on a loaded machine the request
    # may reach the role after the suspension began, the role then stays quiet and the test passes by accident.
    # The first lines in the log file prove that the loop is running; 100000 lines last far longer than the suspension.
    deadline = time.monotonic() + scaled(20)
    while "~echo~ entry " not in log_text(datadir):
        if time.monotonic() > deadline:     # not an assert: xfail would swallow it and hide the broken precondition
            pytest.skip("the role did not start logging, the precondition of the test is not met")
        time.sleep(0.02)
    sup = psutil.Process(chain.sup.ahk_pid())
    sup.suspend()
    try:
        time.sleep(6.0)             # longer than Role.ORPHAN_MS (3 s)
    finally:
        sup.resume()
    thread.join(70)
    time.sleep(scaled(5))
    crashed = chain.rec.find(lambda m: m.get("type") in ("evt.process.hung", "evt.process.crashed"))
    after = chain.states()
    assert not crashed, [m["payload"] for _, m in crashed]
    assert after["echo:a"]["pid"] == pids["echo:a"] and after["echo:a"]["state"] == "ready", after["echo:a"]
