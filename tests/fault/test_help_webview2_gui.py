"""WI-0115 (gui): the help window with WebView2 on the screen. The project owner runs it; agents never do (doc/TEST-STRATEGY.md
section 6).

The test sets the setting helpViewer to webview2, starts the help role without --headless (a real window opens, the view is
the WebView2 control) and shows the same three pages as the classic gui test of WI-0111: the index, an element page and a
general page. Each page is held on the screen for a while, so the owner can look at the text, the buttons Back and Contents,
and the scaling: run it at 100 % and at 225 % (set the Windows scaling before the run; the control must fill the window).
A missing loader DLL or runtime shows the classic viewer instead; the role's snapshot cannot tell the difference, the owner
does (the window has the look of the browser control). The look is not checked by the test, it is the owner's.
"""

import time

import pytest

from faultkit import request_ok, wait_until
from support.timing import scaled

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = [pytest.mark.fault, pytest.mark.gui]

READY_S = 30.0
PAGES = ["Welcome", "Actions/Sleep", "Variables"]
HOLD_S = 6.0


def set_setting(chain, settings):
    def attempt():
        answer = chain.obs.request("engine", "cmd.settings.set", {"settings": settings}, timeout=scaled(5.0))
        return answer["payload"].get("ok") is True     # busy while the engine loads its settings: asked again

    assert wait_until(attempt, timeout=scaled(15.0))


def show_until(chain, page, viewer):
    """Asks for the page until the role answers with the viewer of the setting (empty until the settings are known)."""
    def attempt():
        return request_ok(chain.obs, "help", "cmd.help.show", {"page": page})["viewer"] == viewer

    assert wait_until(attempt, timeout=scaled(15.0))


def test_the_webview2_viewer_shows_three_pages_in_a_window(chains):
    chain = chains("storage,engine,help", [])          # not headless: the window opens
    chain.wait_ready(["storage", "engine", "help"], timeout=READY_S)
    set_setting(chain, {"helpViewer": "webview2"})
    for page in PAGES:
        show_until(chain, page, "webview2")
        info = request_ok(chain.obs, "help", "cmd.diag.snapshot", {})["snapshot"]["info"]
        assert info["viewer"] == "webview2" and info["page"] == page
        time.sleep(scaled(HOLD_S))                      # the owner looks at the page and at the buttons
