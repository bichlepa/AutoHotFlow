"""WI-23: diagnosis. Where do the messages of the supervisor, the stderr of the children and the unhandled
errors of the roles end up? (doc/ARCHITEKTUR.md 6.2, doc/PROTOKOLL.md 4.1 and 4.6)

All tests run a real supervisor with its real children (faultkit.Chain). The test role echo
(tests/integration/helpers/EchoRole.ahk) writes to stderr, to the log and throws errors on request.
The evidence is the common log file Log/Log.txt in the data directory (written by storage), read after
the session has ended or by polling: nothing here depends on a fixed time, only on events.
"""

import time

import psutil
import pytest

from faultkit import event, request_ok, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

HANDLE_SLACK = 6                # handles: noise of one-off allocations between two measurements


def log_text(datadir, name="Log.txt"):
    path = datadir / "Log" / name
    return path.read_bytes().decode("utf-8", "replace") if path.exists() else ""


def wait_for_log(datadir, needle, timeout=15.0, name="Log.txt"):
    return wait_until(lambda: needle in log_text(datadir, name), timeout)


def end_session(chain):
    """Ends the session cleanly (storage writes its queue last) and returns the supervisor's exit code."""
    chain.request_exit()
    return chain.sup.wait_exit(timeout=20)


def echo(chain, type_, payload=None):
    return request_ok(chain.obs, "echo:a", type_, payload or {})


def test_the_messages_of_the_supervisor_are_in_the_log_file(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    assert end_session(chain) == 0, chain.sup.text()
    text = log_text(datadir)
    # the entries written before storage was connected waited in the queue and were delivered afterwards
    assert "~supervisor~children~ started storage (pid " in text, text
    assert "~supervisor~children~ started echo:a (pid " in text, text
    assert "~supervisor~hub~ client 'echo:a' connected" in text, text


def test_a_line_on_stderr_of_a_child_becomes_a_log_line(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    echo(chain, "cmd.test.stderr", {"text": "last words of echo Ünïçöde ✓"})
    assert wait_for_log(datadir, "last words of echo Ünïçöde ✓"), chain.sup.text()
    assert end_session(chain) == 0, chain.sup.text()
    line = [ln for ln in log_text(datadir).split("\n") if "last words of echo" in ln][0]
    assert "[echo:a]" in line, line                      # the line says which child wrote it
    assert "~supervisor~echo~" in line, line             # source = role name, so it lands in Log_echo.txt
    assert "last words of echo" in log_text(datadir, "Log_echo.txt")


def test_a_child_that_fails_to_start_leaves_its_message_in_the_log(chains, datadir):
    # manager without --ui=stub ends at once with exit 3 and a message on stderr
    chain = chains("storage,manager")
    assert wait_for_log(datadir, "no UI selected"), chain.sup.text()
    # the event may come before the observer has subscribed, the log is the evidence
    assert wait_for_log(datadir, "manager ended unexpectedly (exited, exit 3"), chain.sup.text()
    assert end_session(chain) == 0, chain.sup.text()


def test_the_exit_of_a_killed_child_is_in_the_log(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    # a kill leaves nothing on stderr: the log must still say that the child ended and with which exit code
    psutil.Process(chain.pid("echo:a")).kill()
    assert chain.rec.wait(event("evt.process.crashed", name="echo:a"), timeout=10) is not None
    assert wait_for_log(datadir, "echo:a ended unexpectedly"), chain.sup.text()
    assert end_session(chain) == 0, chain.sup.text()


@pytest.mark.timeout(240)
def test_the_handles_of_the_supervisor_stay_flat_over_50_restarts(chains, datadir):
    """Every start opens a pipe, a process handle and a thread handle; every end must close them again."""
    chain = chains("storage,crasher", ["--test-roles", "--restart-max=100"])
    chain.wait_ready(["storage", "crasher"])
    sup_pid = chain.sup.ahk_pid()
    proc = psutil.Process(sup_pid)
    counts = []
    old = chain.pid("crasher")
    for n in range(1, 51):
        request_ok(chain.obs, "crasher", "cmd.test.arm", {})
        new, _ = chain.wait_restarted_ready("crasher", old, timeout=15)
        old = new
        if n in (5, 50):
            counts.append(proc.num_handles())
    print("\nMEASURE handles of the supervisor after 5 and 50 restarts: %s" % counts)
    assert counts[1] <= counts[0] + HANDLE_SLACK, counts
    assert end_session(chain) == 0, chain.sup.text()
