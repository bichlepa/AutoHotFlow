"""WI-0111, PROTOCOL 4.12: the role help (the help window and its viewers), headless.

The window itself is not created by a test run (--headless). These tests check what the role decides: the file of a page
in a language, the fallback to English, a missing page, the viewer of the setting helpViewer, a page asked before the
settings are known, and the rule of the supervisor who may ask for a page (manager and editors only). The look of the
window and the classic control are gui tests (tests/fault/test_help_window_gui.py), run by the project owner.
"""

import pytest

from faultkit import HEADLESS_OPTS, request_ok, wait_until
from support import snapshotschema
from support.timing import scaled

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

READY_S = 20.0
GENERATED_SLEEP = "src\\elements\\Default\\help\\en\\Actions\\Sleep.html"
GENERATED_INDEX = "assets\\help\\en\\Welcome.html"


def resolve(chain, page, language=None):
    payload = {"item": "resolve", "page": page}
    if language is not None:
        payload["language"] = language
    return request_ok(chain.obs, "help", "cmd.test.command", payload)


def refusal(answer):
    """The error code of a refused answer (the envelope of a failed request)."""
    assert answer["payload"].get("ok") is False, answer
    return answer["payload"]["error"]["code"]


def test_resolve_names_the_generated_page_of_an_element(chains):
    chain = chains("storage,help", HEADLESS_OPTS)
    chain.wait_ready(["storage", "help"], timeout=READY_S)
    ans = resolve(chain, "Actions/Sleep", "en")
    assert ans["found"] is True
    assert ans["viewer"] == "classic"           # the setting is not known yet: auto, and auto is classic in this version
    assert ans["path"].endswith(GENERATED_SLEEP), ans["path"]
    assert ans["language"] == "en"


def test_a_page_without_a_translation_is_the_english_one(chains):
    chain = chains("storage,help", HEADLESS_OPTS)
    chain.wait_ready(["storage", "help"], timeout=READY_S)
    ans = resolve(chain, "Actions/Sleep", "de")
    assert ans["found"] is True and ans["language"] == "en"
    assert ans["path"].endswith(GENERATED_SLEEP), ans["path"]


def test_a_missing_page_is_resolved_to_the_index(chains):
    chain = chains("storage,help", HEADLESS_OPTS)
    chain.wait_ready(["storage", "help"], timeout=READY_S)
    ans = resolve(chain, "Actions/No_such_element")
    assert ans["found"] is False
    assert ans["path"].endswith(GENERATED_INDEX), ans["path"]


def test_a_page_id_that_is_not_valid_is_refused(chains):
    chain = chains("storage,help", HEADLESS_OPTS)
    chain.wait_ready(["storage", "help"], timeout=READY_S)
    answer = chain.obs.request("help", "cmd.test.command", {"item": "resolve", "page": "../secret"}, timeout=scaled(5.0))
    assert refusal(answer) == "bad_payload"
    answer = chain.obs.request("help", "cmd.help.show", {"page": "Actions/Sleep/x"}, timeout=scaled(5.0))
    assert refusal(answer) == "bad_payload"


def test_a_page_asked_before_the_settings_are_known_waits_for_them(chains):
    chain = chains("storage,help", HEADLESS_OPTS)
    chain.wait_ready(["storage", "help"], timeout=READY_S)
    ans = request_ok(chain.obs, "help", "cmd.help.show", {"page": "Variables"})
    assert ans["viewer"] == ""                  # no engine, no settings: the page waits for them


def test_the_supervisor_lets_only_the_manager_and_the_editors_ask_for_a_page(chains):
    chain = chains("storage,help", HEADLESS_OPTS)
    chain.wait_ready(["storage", "help"], timeout=READY_S)
    answer = chain.obs.request("supervisor", "cmd.help.show", {"page": ""}, timeout=scaled(5.0))
    assert refusal(answer) == "denied"


def test_the_setting_chooses_the_viewer_and_a_shown_page_is_in_the_snapshot(chains):
    chain = chains("storage,engine,help", HEADLESS_OPTS)
    chain.wait_ready(["storage", "engine", "help"], timeout=READY_S)
    def set_browser():
        answer = chain.obs.request("engine", "cmd.settings.set", {"settings": {"helpViewer": "browser"}}, timeout=scaled(5.0))
        return answer["payload"].get("ok") is True     # busy while the engine loads its settings: asked again

    assert wait_until(set_browser, timeout=scaled(15.0))
    assert wait_until(lambda: resolve(chain, "")["viewer"] == "browser", timeout=scaled(10.0))
    shown = request_ok(chain.obs, "help", "cmd.help.show", {"page": "Variables"})
    assert shown["viewer"] == "browser"         # headless: nothing is opened, the viewer is the one of the setting
    snap = request_ok(chain.obs, "help", "cmd.diag.snapshot", {})["snapshot"]
    snapshotschema.check_snapshot(snap, "help")
    assert snap["info"]["page"] == "Variables" and snap["info"]["viewer"] == "browser"
    assert snap["info"]["shown"] == 1
