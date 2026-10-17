"""WI-0064: Trigger_Hotkey with real input (E0059) in a real session (storage, engine, triggerhost; ELEMENT-API-V2 5).

The keys are unassigned virtual keys (vk88 to vk8F, vkE8) without modifiers, sent with SendInput. Every input test holds the
machine-wide input lock (tests/support/inputlock.py), so two runs never send keys at the same time. A test is skipped
with a reason when there is no input desktop or when a probe key does not arrive. A test waits briefly when the user
holds a modifier, and skips when it stays held.

The gui tier (marker gui, run by the project owner only, never by an agent) sends key combinations with modifiers.
"""

import subprocess
import sys
import time
from pathlib import Path

import pytest

from support import inputlock
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled

pytestmark = pytest.mark.xdist_group("input")

HOST_ROLES = "storage,engine,triggerhost"
REPO = Path(__file__).resolve().parents[2]
AHKRUN = REPO / "tools" / "ahkrun.py"
HELPERS = Path(__file__).resolve().parent / "helpers"
WAIT_S = 10.0
QUIET_S = 1.5          # how long a trigger that must not fire is watched

# Unassigned keys, one per test. vk88 to vk8F and vkE8 reach every form of hotkey (plain, ~, up). vk97 to vk9F do not
# reach a plain hotkey (RegisterHotKey) when SendInput sends them, only a hotkey with the keyboard hook.
PROBE_VK = 0x88
PLAIN_VK = 0x89
TILDE_VK = 0x8A
BLOCK_VK = 0x8B
UP_VK = 0x8C
EXISTS_VK = 0x8D
NOT_EXISTS_VK = 0x8E
ACTIVE_VK = 0x8F
TWO_VK = 0xE8


class InputRunner(FlowRunner):
    """A flow runner whose session starts at the first enable: the flows of the test are added before that, together
    with a probe flow. The probe key must arrive, otherwise the test is skipped (the keys do not reach the desktop)."""

    def enable(self, *flow_ids):
        if self._sup is None:
            self._start_with_probe()
        super().enable(*flow_ids)

    def _start_with_probe(self):
        probe_fb, probe = hotkey_flow("Probe", "vk%X" % PROBE_VK)
        probe_id = self.add(probe_fb)
        self.start()
        super().enable(probe_id)
        assert wait_armed(self, probe_id, probe.id), (trigger_state(self, probe_id, probe.id), self.stderr_text())
        if inputlock.send_key(PROBE_VK) == 0:
            pytest.skip("SendInput refused the probe key: no input desktop")
        if not self.ended(probe_id, count=1, timeout=scaled(5.0)):
            pytest.skip("the probe key did not arrive: keys do not reach the hotkey (no input desktop?)")


@pytest.fixture
def input_session(procs, datadir, session_id):
    """A session with the trigger host (see InputRunner). Skips when there is no input desktop."""
    if not inputlock.input_desktop_open():
        pytest.skip("no input desktop (locked workstation or a secure desktop in front): keys cannot be sent")
    with inputlock.input_lock():
        runner = InputRunner(procs, datadir, session_id, roles=HOST_ROLES)
        try:
            yield runner
        finally:
            runner.close()


def hotkey_flow(name, hotkey, **pars):
    fb = FlowBuilder(name)
    trigger = fb.trigger("Trigger_Hotkey", hotkey=hotkey, **pars)
    done = fb.action("Action_Do_nothing")
    fb.chain(trigger, done)
    return fb, trigger


def trigger_state(runner, flow_id, element_id):
    try:
        answer = runner.request_ok("engine", "cmd.engine.snapshot", {})
    except Exception:
        return None
    for flow in answer["flows"]:
        if flow["flowId"] == flow_id:
            for t in flow.get("triggers", []):
                if t["elementId"] == element_id:
                    return t
    return None


def wait_armed(runner, flow_id, element_id, armed=True, timeout=WAIT_S):
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        state = trigger_state(runner, flow_id, element_id)
        if state is not None and state["armed"] is armed:
            return state
        time.sleep(0.05)
    return None


def press(vk, with_modifiers=()):
    """Sends the key once; returns the number of events, after the modifiers of the user were checked."""
    held = inputlock.wait_modifiers_released()
    if held:
        pytest.skip("a modifier is held by the user (VK %s): the key would be a combination" % held)
    return inputlock.send_key(vk, with_modifiers)


def expect_fires(runner, flow_id, vk, with_modifiers=()):
    since = runner.mark()
    assert press(vk, with_modifiers) > 0
    assert runner.ended(flow_id, since=since, count=1, timeout=scaled(WAIT_S)), runner.stderr_text()


def expect_silent(runner, flow_id, vk, with_modifiers=()):
    since = runner.mark()
    assert press(vk, with_modifiers) > 0
    time.sleep(scaled(QUIET_S))
    fired = runner.ended(flow_id, since=since, count=0, timeout=0)
    assert not fired, "the trigger fired although it must not: %r" % fired


@pytest.fixture
def hidden_window(tmp_path):
    """A hidden window of this test (a helper process); yields its title."""
    title = "AhfHotkeyTestWindow-%d" % time.time_ns()
    ready, stop = tmp_path / "window_ready.txt", tmp_path / "window_stop.txt"
    proc = subprocess.Popen([sys.executable, str(AHKRUN), "--timeout", "120",
                             str(HELPERS / "hotkey_window.ahk"), title, str(ready), str(stop)],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        deadline = time.monotonic() + scaled(10.0)
        while not ready.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        assert ready.exists(), "the hidden window did not start: %s" % proc.stderr.read()
        yield title
    finally:
        stop.write_text("stop", encoding="ascii")
        try:
            proc.wait(timeout=scaled(10.0))
        except subprocess.TimeoutExpired:
            proc.kill()


@pytest.fixture
def key_log(tmp_path):
    """An observer process that logs the key-down events reaching the keyboard hook chain; yields the log path."""
    log, ready, stop = tmp_path / "keys.txt", tmp_path / "ready.txt", tmp_path / "stop.txt"
    proc = subprocess.Popen([sys.executable, str(AHKRUN), "--timeout", "120",
                             str(HELPERS / "key_observer.ahk"), str(log), str(ready), str(stop)],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        deadline = time.monotonic() + scaled(10.0)
        while not ready.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        assert ready.exists(), "the key observer did not start: %s" % proc.stderr.read()
        yield log
    finally:
        stop.write_text("stop", encoding="ascii")
        try:
            proc.wait(timeout=scaled(10.0))
        except subprocess.TimeoutExpired:
            proc.kill()


def observed(log, vk):
    if not log.exists():
        return False
    return ("%X" % vk) in log.read_text(encoding="utf-8-sig").split()


# --- normal tier: unassigned keys, no modifier -----------------------------------------------------

def test_plain_hotkey_fires_its_flow(input_session):
    fb, trigger = hotkey_flow("Plain", "vk%X" % PLAIN_VK)
    fid = input_session.add(fb)
    input_session.enable(fid)
    assert wait_armed(input_session, fid, trigger.id), input_session.stderr_text()
    expect_fires(input_session, fid, PLAIN_VK)


def test_tilde_passes_the_key_on_and_fires(input_session, key_log):
    fb, trigger = hotkey_flow("Tilde", "vk%X" % TILDE_VK, BlockKey=0)
    fid = input_session.add(fb)
    input_session.enable(fid)
    assert wait_armed(input_session, fid, trigger.id), input_session.stderr_text()
    expect_fires(input_session, fid, TILDE_VK)
    time.sleep(scaled(0.5))
    assert observed(key_log, TILDE_VK), "the key with ~ did not reach the next hook"


def test_default_blocks_the_key(input_session, key_log):
    """Only a hook hotkey ($) blocks the key for the other hooks; a plain hotkey (RegisterHotKey) does not."""
    fb, trigger = hotkey_flow("Block", "$vk%X" % BLOCK_VK)
    fid = input_session.add(fb)
    input_session.enable(fid)
    assert wait_armed(input_session, fid, trigger.id), input_session.stderr_text()
    expect_fires(input_session, fid, BLOCK_VK)
    time.sleep(scaled(0.5))
    assert not observed(key_log, BLOCK_VK), "the blocked key reached the next hook"


def test_release_hotkey_fires_on_key_up(input_session):
    fb, trigger = hotkey_flow("Up", "vk%X" % UP_VK, WhenRelease=1)
    fid = input_session.add(fb)
    input_session.enable(fid)
    assert wait_armed(input_session, fid, trigger.id), input_session.stderr_text()
    expect_fires(input_session, fid, UP_VK)


def test_window_exists_fires_only_with_the_hidden_window(input_session, hidden_window):
    present = dict(UseWindow="WindowExists", Wintitle=hidden_window, FindHiddenWindow=1)
    absent = dict(UseWindow="WindowExists", Wintitle=hidden_window + "-absent", FindHiddenWindow=1)
    fb_p, trig_p = hotkey_flow("Exists present", "$vk%X" % EXISTS_VK, **present)
    fb_a, trig_a = hotkey_flow("Exists absent", "$vk%X" % EXISTS_VK, **absent)
    fid_p, fid_a = input_session.add(fb_p), input_session.add(fb_a)
    input_session.enable(fid_p, fid_a)
    assert wait_armed(input_session, fid_p, trig_p.id), input_session.stderr_text()
    assert wait_armed(input_session, fid_a, trig_a.id), input_session.stderr_text()
    expect_fires(input_session, fid_p, EXISTS_VK)
    expect_silent(input_session, fid_a, EXISTS_VK)


def test_window_not_exists_fires_only_without_the_window(input_session, hidden_window):
    present = dict(UseWindow="WindowNotExists", Wintitle=hidden_window, FindHiddenWindow=1)
    absent = dict(UseWindow="WindowNotExists", Wintitle=hidden_window + "-absent", FindHiddenWindow=1)
    fb_p, trig_p = hotkey_flow("Not exists present", "$vk%X" % NOT_EXISTS_VK, **present)
    fb_a, trig_a = hotkey_flow("Not exists absent", "$vk%X" % NOT_EXISTS_VK, **absent)
    fid_p, fid_a = input_session.add(fb_p), input_session.add(fb_a)
    input_session.enable(fid_p, fid_a)
    assert wait_armed(input_session, fid_p, trig_p.id), input_session.stderr_text()
    assert wait_armed(input_session, fid_a, trig_a.id), input_session.stderr_text()
    expect_silent(input_session, fid_p, NOT_EXISTS_VK)
    expect_fires(input_session, fid_a, NOT_EXISTS_VK)


def test_window_active_conditions_against_the_active_window(input_session):
    """The window that is active anyway (no focus change): the terminal of the test run."""
    active = inputlock.foreground_window()
    if not active:
        pytest.skip("no foreground window to test against")
    on = dict(UseWindow="WindowIsActive", ahk_id=str(active))
    off = dict(UseWindow="WindowIsNotActive", ahk_id=str(active))
    fb_on, trig_on = hotkey_flow("Active", "$vk%X" % ACTIVE_VK, **on)
    fb_off, trig_off = hotkey_flow("Not active", "$vk%X" % ACTIVE_VK, **off)
    fid_on, fid_off = input_session.add(fb_on), input_session.add(fb_off)
    input_session.enable(fid_on, fid_off)
    assert wait_armed(input_session, fid_on, trig_on.id), input_session.stderr_text()
    assert wait_armed(input_session, fid_off, trig_off.id), input_session.stderr_text()
    expect_fires(input_session, fid_on, ACTIVE_VK)
    expect_silent(input_session, fid_off, ACTIVE_VK)


def test_two_flows_on_one_key_both_fire(input_session):
    fb_a, trig_a = hotkey_flow("Two A", "vk%X" % TWO_VK)
    fb_b, trig_b = hotkey_flow("Two B", "vk%X" % TWO_VK)
    fid_a, fid_b = input_session.add(fb_a), input_session.add(fb_b)
    input_session.enable(fid_a, fid_b)
    assert wait_armed(input_session, fid_a, trig_a.id), input_session.stderr_text()
    assert wait_armed(input_session, fid_b, trig_b.id), input_session.stderr_text()
    since = input_session.mark()
    assert press(TWO_VK) > 0
    assert input_session.ended(fid_a, since=since, count=1, timeout=scaled(WAIT_S)), input_session.stderr_text()
    assert input_session.ended(fid_b, since=since, count=1, timeout=scaled(WAIT_S)), input_session.stderr_text()


def test_disabling_one_flow_keeps_the_other_on_the_key(input_session):
    fb_a, trig_a = hotkey_flow("Disable A", "vk%X" % PLAIN_VK)
    fb_b, trig_b = hotkey_flow("Disable B", "vk%X" % PLAIN_VK)
    fid_a, fid_b = input_session.add(fb_a), input_session.add(fb_b)
    input_session.enable(fid_a, fid_b)
    assert wait_armed(input_session, fid_a, trig_a.id), input_session.stderr_text()
    assert wait_armed(input_session, fid_b, trig_b.id), input_session.stderr_text()
    input_session.request_ok("engine", "cmd.flow.disable", {"flowId": fid_a})
    assert wait_armed(input_session, fid_a, trig_a.id, armed=False), input_session.stderr_text()
    expect_silent(input_session, fid_a, PLAIN_VK)
    expect_fires(input_session, fid_b, PLAIN_VK)


def test_an_error_of_one_trigger_does_not_stop_another(input_session):
    fb_bad, trig_bad = hotkey_flow("Bad key", "NoSuchKey!!")
    fb_ok, trig_ok = hotkey_flow("Good key", "vk%X" % UP_VK)
    fid_bad, fid_ok = input_session.add(fb_bad), input_session.add(fb_ok)
    input_session.enable(fid_bad, fid_ok)
    state = wait_armed(input_session, fid_bad, trig_bad.id, armed=False)
    assert state is not None and state["message"], input_session.stderr_text()
    assert wait_armed(input_session, fid_ok, trig_ok.id), input_session.stderr_text()
    expect_fires(input_session, fid_ok, UP_VK)


# --- gui tier: key combinations with modifiers (run by the owner) ----------------------------------

@pytest.mark.gui
def test_key_combination_with_ctrl_alt_shift_fires(input_session):
    vk = PLAIN_VK
    fb, trigger = hotkey_flow("Combination", "^!+vk%X" % vk)
    fid = input_session.add(fb)
    input_session.enable(fid)
    assert wait_armed(input_session, fid, trigger.id), input_session.stderr_text()
    expect_fires(input_session, fid, vk, with_modifiers=(inputlock.VK_CONTROL, inputlock.VK_MENU, inputlock.VK_SHIFT))


@pytest.mark.gui
def test_wildcard_fires_with_a_held_modifier_and_a_plain_hotkey_does_not(input_session):
    vk = TILDE_VK
    fb_w, trig_w = hotkey_flow("Wildcard", "$vk%X" % vk, Wildcard=1)
    fb_p, trig_p = hotkey_flow("Plain", "vk%X" % (vk + 1))
    fid_w, fid_p = input_session.add(fb_w), input_session.add(fb_p)
    input_session.enable(fid_w, fid_p)
    assert wait_armed(input_session, fid_w, trig_w.id), input_session.stderr_text()
    assert wait_armed(input_session, fid_p, trig_p.id), input_session.stderr_text()
    expect_fires(input_session, fid_w, vk, with_modifiers=(inputlock.VK_SHIFT,))
    expect_silent(input_session, fid_p, vk + 1, with_modifiers=(inputlock.VK_SHIFT,))


@pytest.mark.gui
def test_a_real_key_a_user_may_press_fires(input_session):
    vk = 0x7C      # F13: a key that keyboards have, unassigned by default
    fb, trigger = hotkey_flow("F13", "vk%X" % vk)
    fid = input_session.add(fb)
    input_session.enable(fid)
    assert wait_armed(input_session, fid, trigger.id), input_session.stderr_text()
    expect_fires(input_session, fid, vk)
