"""F-0074: a second start of the product while a supervisor runs makes the manager show its window.

The second instance is the real command line without --command (PROTOCOL 4.1 cmd.app.command, 4.8 cmd.manager.show).
The headless manager stub records the request as a ui-event line `stub.show` (no window, so no gui test). The supervisor
logs `manager show requested by second start`. Both arrive on the topic log through storage.
"""

import json
import subprocess
import sys

import pytest

from faultkit import AHKRUN, ENTRY, ROOT, HEADLESS_OPTS, request_ok, wait_until
from support.timing import scaled

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

READY_S = 20.0


def second_start(chain, datadir):
    """The real command line of a second instance, without --command. Returns its exit code."""
    cmd = [sys.executable, str(AHKRUN), "--timeout", "60", str(ENTRY), "--session=" + chain.session,
           "--data=" + str(datadir)]
    return subprocess.run(cmd, cwd=str(ROOT), capture_output=True, timeout=90).returncode


def log_entries(chain):
    return [m["payload"] for t, m in chain.rec.find(lambda m: m.get("type") == "evt.log.entry")]


def manager_shows(chain):
    """The cmd.manager.show requests that the headless manager has seen (its trace, PROTOCOL 4.8)."""
    ans = request_ok(chain.obs, "manager", "cmd.test.trace", {})
    return [e for e in ans["entries"] if e["type"] == "manager.show"]


def supervisor_says(chain, needle):
    return [p for p in log_entries(chain) if p.get("source") == "supervisor" and needle in str(p.get("text", ""))]


def subscribe_log(chain):
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "log"})


def test_a_second_start_makes_the_running_manager_show_its_window(chains, datadir):
    chain = chains("storage,manager", HEADLESS_OPTS)
    chain.wait_ready(["storage", "manager"], timeout=READY_S)
    subscribe_log(chain)
    assert manager_shows(chain) == []
    assert second_start(chain, datadir) == 0
    assert wait_until(lambda: manager_shows(chain), scaled(10.0)), log_entries(chain)[-10:]
    assert wait_until(lambda: supervisor_says(chain, "manager show requested by second start"), scaled(10.0))
    # a second request is a second show: the manager does not remember the first one
    assert second_start(chain, datadir) == 0
    assert wait_until(lambda: len(manager_shows(chain)) == 2, scaled(10.0)), manager_shows(chain)


def test_a_second_start_starts_the_manager_if_it_is_not_running(chains, datadir):
    chain = chains("storage", HEADLESS_OPTS)
    chain.wait_ready(["storage"], timeout=READY_S)
    subscribe_log(chain)
    assert "manager" not in chain.states()
    assert second_start(chain, datadir) == 0
    chain.wait_ready(["manager"], timeout=READY_S)
    assert wait_until(lambda: supervisor_says(chain, "manager is not running"), scaled(10.0)), log_entries(chain)[-10:]
