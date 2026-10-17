"""WI-0072, E0075: the role tray (tray icon and tray menu of the application) as a process of the supervisor.

The test entry does not start the role tray unless a test asks (--tray; Supervisor.TrayDefault is false there), and a
headless tray keeps its icon hidden, so these tests show no icon. The menu entries are run through the test driver
(cmd.test.command {item}, PROTOCOL 4.10), which calls the same methods as a click. The one test that needs a real icon
and a real menu is marked gui (it opens the menu of the tray role and holds it longer than the pong timeout); an agent
runs it only when the project owner allows it.
"""

import json
import time

import psutil
import pytest

from faultkit import EXIT_OK, STUB_OPTS, event, request_ok, wait_until
from support import inputlock, snapshotschema
from support.timing import scaled

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

READY_S = 20.0
UI_PREFIX = "ui-event "
TRAY_OPTS = ["--tray", "--headless"]


def log_entries(chain):
    return [m["payload"] for t, m in chain.rec.find(lambda m: m.get("type") == "evt.log.entry")]


def stub_shows(chain):
    out = []
    for p in log_entries(chain):
        text = str(p.get("text", ""))
        if p.get("source") == "manager" and text.startswith(UI_PREFIX):
            if json.loads(text[len(UI_PREFIX):]).get("type") == "stub.show":
                out.append(p)
    return out


def click(chain, item):
    """The test driver of the headless tray: runs the menu entry as if it had been clicked."""
    return request_ok(chain.obs, "tray", "cmd.test.command", {"item": item})


def test_the_test_entry_starts_no_tray_role_unless_asked(chains):
    chain = chains("storage", STUB_OPTS)
    chain.wait_ready(["storage"], timeout=READY_S)
    assert "tray" not in chain.states()


def test_the_supervisor_starts_the_tray_role_with_the_menu_built_and_the_icon_hidden_when_headless(chains):
    chain = chains("storage", TRAY_OPTS)
    chain.wait_ready(["storage", "tray"], timeout=READY_S)
    snap = request_ok(chain.obs, "tray", "cmd.diag.snapshot", {})["snapshot"]
    snapshotschema.check_snapshot(snap, "tray")
    assert snap["name"] == "tray"
    assert snap["info"]["items"] == ["Show manager", "Exit"]
    assert snap["info"]["tip"] == "AutoHotFlow"
    assert snap["info"]["iconHidden"] is True


def test_a_start_list_that_names_tray_does_not_start_it_twice(chains):
    chain = chains("storage,tray", TRAY_OPTS)
    chain.wait_ready(["storage", "tray"], timeout=READY_S)
    assert [n for n in chain.states() if n.startswith("tray")] == ["tray"]


def test_a_killed_tray_role_is_started_again_so_the_icon_comes_back(chains):
    chain = chains("storage", TRAY_OPTS)
    old = chain.wait_ready(["storage", "tray"], timeout=READY_S)["tray"]
    psutil.Process(old).kill()
    new_pid, _ = chain.wait_restarted_ready("tray", old)
    assert new_pid != old
    assert chain.rec.find(event("evt.process.crashed", name="tray")), "the kill was not reported"
    assert chain.rec.find(event("evt.process.restarted", name="tray"))
    # the new process has its menu again
    snap = request_ok(chain.obs, "tray", "cmd.diag.snapshot", {})["snapshot"]
    assert snap["pid"] == new_pid and snap["info"]["items"] == ["Show manager", "Exit"]


def test_the_exit_entry_ends_the_supervisor_with_exit_0_and_leaves_no_process(chains):
    chain = chains("storage,engine,manager,tray", [*TRAY_OPTS, "--ui=stub"])
    chain.wait_ready(["storage", "engine", "manager", "tray"], timeout=READY_S)
    click(chain, "exit")
    assert chain.sup.wait_exit(timeout=scaled(15.0)) == EXIT_OK, chain.sup.text()
    # the fixture checks at teardown that no process of the session is left, the tray role included.
    # Not checked here: that storage saved its data before the end (the shutdown tests cover the order).


def test_the_tray_role_ends_when_the_supervisor_is_killed(chains):
    chain = chains("storage", TRAY_OPTS)
    pids = chain.wait_ready(["storage", "tray"], timeout=READY_S)
    psutil.Process(chain.sup.ahk_pid()).kill()
    # orphan guard of Role: the hub is gone, the role ends after Role.ORPHAN_MS
    assert wait_until(lambda: not psutil.pid_exists(pids["tray"]), 3.0 + scaled(10.0)), "the tray role is still alive"


def test_the_tray_role_always_comes_back_after_a_growing_pause(chains):
    # Owner decision (E0075): no restart limit for the tray; the pause before the restart doubles (1 s, 2 s, 4 s, 8 s ...).
    # Four kills within 60 s would stop an ordinary role (Children.RESTART_MAX = 3). The order of the delays is asserted, not their size.
    chain = chains("storage", TRAY_OPTS)
    pid = chain.wait_ready(["storage", "tray"], timeout=READY_S)["tray"]
    delays = []
    for _ in range(4):
        t_kill = time.perf_counter()
        psutil.Process(pid).kill()
        pid, t_ready = chain.wait_restarted_ready("tray", pid, timeout=30.0)
        delays.append(t_ready - t_kill)
    # Startup time under load blurs neighbours (1 s against 2 s), so only pairs two steps apart are compared.
    assert delays[2] > delays[0] and delays[3] > delays[1] and delays[3] > delays[0] + 3.0, delays
    assert not chain.rec.find(event("evt.process.crashed", name="tray", restart=False))
    assert chain.states()["tray"]["state"] == "ready" and chain.sup.proc.poll() is None


def test_the_show_manager_entry_makes_the_running_manager_show_its_window(chains):
    chain = chains("storage,manager,tray", [*TRAY_OPTS, "--ui=stub"])
    chain.wait_ready(["storage", "manager", "tray"], timeout=READY_S)
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "log"})
    assert stub_shows(chain) == []
    click(chain, "show")
    assert wait_until(lambda: stub_shows(chain), scaled(10.0)), log_entries(chain)[-10:]
    click(chain, "show")                    # a second click is a second request
    assert wait_until(lambda: len(stub_shows(chain)) == 2, scaled(10.0)), stub_shows(chain)


def test_the_show_manager_entry_starts_a_manager_that_is_not_running(chains):
    chain = chains("storage,tray", [*TRAY_OPTS, "--ui=stub"])
    chain.wait_ready(["storage", "tray"], timeout=READY_S)
    assert "manager" not in chain.states()
    click(chain, "show")
    chain.wait_ready(["manager"], timeout=READY_S)


def test_a_crashed_manager_is_opened_again_by_the_show_manager_entry(chains):
    chain = chains("storage,manager,tray", [*TRAY_OPTS, "--ui=stub"])
    pids = chain.wait_ready(["storage", "manager", "tray"], timeout=READY_S)
    psutil.Process(pids["manager"]).kill()
    assert wait_until(lambda: chain.states().get("manager", {}).get("state") in ("crashed", "exited"), scaled(10.0)), \
        chain.states()
    time.sleep(0.5)                          # the manager is not restarted by itself (E0014, REQ-ROB-120)
    assert chain.states()["manager"]["state"] in ("crashed", "exited")
    click(chain, "show")
    new_pid, _ = chain.wait_restarted_ready("manager", pids["manager"])
    assert new_pid != pids["manager"]


def test_the_test_driver_refuses_an_unknown_menu_entry(chains):
    chain = chains("storage", TRAY_OPTS)
    chain.wait_ready(["storage", "tray"], timeout=READY_S)
    answer = chain.obs.request("tray", "cmd.test.command", {"item": "reload"}, timeout=5)
    assert not answer["payload"].get("ok"), answer
    assert answer["payload"]["error"]["code"] == "bad_payload", answer


# --- gui: the real icon and a real open menu -----------------------------------------------------------------------

MENU_HOLD_S = 8.0                   # longer than Heartbeat.PONG_TIMEOUT_MS (6 s): a menu open this long must not make the role hung
WM_RBUTTONUP = 0x0205
AHK_NOTIFYICON = 0x404              # the tray callback message of an AutoHotkey script


@pytest.mark.gui
def test_the_real_icon_opens_its_menu_and_a_menu_open_for_8_seconds_does_not_make_the_role_hung(chains):
    """Shows the real icon of the tray role for about 15 s (not headless). The menu is opened with the tray message to the
    script window, held longer than the pong timeout and closed with Esc. Needs the input desktop (skips on a locked PC)."""
    import ctypes
    from ctypes import wintypes

    reason = inputlock.session_skip_reason(inputlock.input_desktop_open(), inputlock.logonui_running())
    if reason:
        pytest.skip(reason)
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
    user32.FindWindowW.restype = wintypes.HWND
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    enum_proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows.argtypes = [enum_proc, wintypes.LPARAM]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]

    chain = chains("storage", ["--tray"])
    pid = chain.wait_ready(["storage", "tray"], timeout=READY_S)["tray"]
    snap = request_ok(chain.obs, "tray", "cmd.diag.snapshot", {})["snapshot"]
    assert snap["info"]["iconHidden"] is False

    found = []

    def cb(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        cls = ctypes.create_unicode_buffer(64)
        user32.GetClassNameW(hwnd, cls, 64)
        if owner.value == pid and cls.value == "AutoHotkey":
            found.append(hwnd)
        return True

    user32.EnumWindows(enum_proc(cb), 0)
    assert found, "no main window of the tray process"
    with inputlock.input_lock():
        user32.PostMessageW(found[0], AHK_NOTIFYICON, 1, WM_RBUTTONUP)
        assert wait_until(lambda: user32.FindWindowW("#32768", None), 5.0), "the menu did not open"
        t0 = time.monotonic()
        while time.monotonic() - t0 < MENU_HOLD_S:
            assert chain.states()["tray"]["state"] == "ready", chain.states()["tray"]     # still answers pings
            time.sleep(0.5)
        assert not chain.rec.find(event("evt.process.hung", name="tray"))
        inputlock.send_key(0x1B)                  # Esc closes the menu
        assert wait_until(lambda: not user32.FindWindowW("#32768", None), 5.0), "Esc did not close the menu"
    assert chain.states()["tray"]["pid"] == pid, "the tray role was restarted while its menu was open"
