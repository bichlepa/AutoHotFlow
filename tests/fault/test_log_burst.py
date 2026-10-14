"""F-17 and F-85: a burst of log lines.

Both tests show a defect that is known and not fixed yet; they are marked xfail(strict=True) and turn loud when the
defect is fixed (remove the mark then).

* F-85: a role logs thousands of lines in a tight loop. The hub's send queue to "storage" holds 1000 frames; the
  overflow closes the link to storage (queue_overflow), storage is judged hung and restarted, and the lines are lost.
* F-17: the same burst while the supervisor stands still. The role's own send queue overflows, the role loses its
  connection and ends after the orphan deadline ("hub not reachable"), although it did nothing wrong.

The test role echo (tests/integration/helpers/EchoRole.ahk) writes the lines on request (cmd.test.log).
"""

import threading
import time

import psutil
import pytest

from faultkit import request_ok
from support.timing import scaled

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = [pytest.mark.fault, pytest.mark.slow]

BURST = 5000            # lines in one tight loop (3000 was enough in the first measurements)


def log_text(datadir):
    path = datadir / "Log" / "Log.txt"
    return path.read_bytes().decode("utf-8", "replace") if path.exists() else ""


@pytest.mark.xfail(strict=True, reason="F-85: a log burst overflows the hub's send queue to storage and closes the link")
def test_a_burst_of_log_lines_does_not_cost_the_storage_link_or_the_lines(chains, datadir):
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
    assert log_text(datadir).count("~echo~ entry ") == BURST


@pytest.mark.xfail(strict=True, reason="F-17: a chatty role gives up during a long stand-still of the supervisor")
def test_a_chatty_role_survives_a_long_stand_still_of_the_supervisor(chains):
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
    time.sleep(0.2)                 # the role is inside its loop
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
