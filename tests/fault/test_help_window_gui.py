"""WI-0111 (gui): the help window on the screen. The project owner runs it; agents never do (doc/TEST-STRATEGY.md section 6).

Each test starts the help role without --headless, so a real window opens (the classic viewer, Shell.Explorer) or the
default browser (setting browser). The test shows the page and holds it on the screen for a while, so the owner can look:
the text of the page, the buttons Back and Contents, the scaling at 100 % and at 225 % (set the Windows scaling before the
run; the control must fill the window at both). The snapshot of the role is checked; the look is not, it is the owner's.
"""

import time

import pytest

from faultkit import request_ok, wait_until
from support.timing import scaled

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = [pytest.mark.fault, pytest.mark.gui]

READY_S = 30.0
HOLD_S = 12.0


def set_setting(chain, settings):
    def attempt():
        answer = chain.obs.request("engine", "cmd.settings.set", {"settings": settings}, timeout=scaled(5.0))
        return answer["payload"].get("ok") is True     # busy while the engine loads its settings: asked again

    assert wait_until(attempt, timeout=scaled(15.0))


def show_until(chain, page, viewer):
    """Asks for the page until the role shows it with the viewer (the answer's viewer is empty until the settings are known,
    and a setting that was just set reaches the role a moment later)."""
    def attempt():
        return request_ok(chain.obs, "help", "cmd.help.show", {"page": page})["viewer"] == viewer

    assert wait_until(attempt, timeout=scaled(15.0))
    return request_ok(chain.obs, "help", "cmd.diag.snapshot", {})["snapshot"]["info"]


def test_the_classic_viewer_shows_an_element_page_in_a_window(chains):
    chain = chains("storage,engine,help", [])          # not headless: the window opens
    chain.wait_ready(["storage", "engine", "help"], timeout=READY_S)
    show_until(chain, "Actions/Sleep", "classic")
    info = request_ok(chain.obs, "help", "cmd.diag.snapshot", {})["snapshot"]["info"]
    assert info["viewer"] == "classic" and info["page"] == "Actions/Sleep"
    time.sleep(scaled(HOLD_S))                          # the owner looks at the window: the page, Back, Contents


def test_the_browser_setting_opens_the_page_in_the_default_browser(chains):
    chain = chains("storage,engine,help", [])
    chain.wait_ready(["storage", "engine", "help"], timeout=READY_S)
    set_setting(chain, {"helpViewer": "browser"})
    show_until(chain, "Welcome", "browser")
    time.sleep(scaled(HOLD_S))                          # a browser window with the index page is open now
