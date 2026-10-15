"""AhfClient against the Python hub (support/pyhub.py). Real named pipes, no AutoHotkey.

These tests cover the client, not the production hub: the hub is a stand-in.
Not covered here: wake() (PostMessageW to a NULL handle returns TRUE, so a missing-window
check needs a real stale handle); the wake-up of an AutoHotkey peer is covered by WI-0004.
"""

import threading
import time

import pytest

from support.ahfclient import AhfClient, AhfTimeout
from support.pyhub import PyHub


@pytest.fixture
def pipe_name(session_id):
    return "ahf.%s.hub" % session_id


@pytest.fixture
def hub(pipe_name):
    with PyHub(pipe_name) as h:
        yield h


def test_hello_gets_welcome_with_matching_corr(hub, pipe_name):
    with AhfClient(pipe_name, "editor:Flow1") as c:
        assert c.welcome["type"] == "sys.welcome"
        assert c.welcome["payload"]["ok"] is True
        assert c.welcome["corr"] == "editor:Flow1#1"
        assert hub.wait_for_peer("editor:Flow1")


def test_request_is_routed_and_answered(hub, pipe_name):
    with AhfClient(pipe_name, "a") as a, AhfClient(pipe_name, "b") as b:
        assert hub.wait_for_peer("b")
        answer = {}

        def ask():
            answer["env"] = a.request("b", "cmd.test.echo", {"x": "1"}, timeout=5)

        t = threading.Thread(target=ask)
        t.start()
        req = b.wait_event("cmd.test.echo", timeout=5)
        assert req["from"] == "a"          # set by the hub from the sender
        assert req["payload"] == {"x": "1"}
        b.reply(req, {"ok": True, "echo": req["payload"]["x"]})
        t.join(5)
        env = answer["env"]
        assert env["type"] == "res.test.echo"
        assert env["payload"] == {"ok": True, "echo": "1"}


def test_unknown_peer_gets_not_found(hub, pipe_name):
    with AhfClient(pipe_name, "a") as a:
        env = a.request("nobody", "cmd.test.none", {}, timeout=5)
        assert env["payload"]["ok"] is False
        assert env["payload"]["error"]["code"] == "not_found"


def test_silent_peer_gives_timeout_not_hang(hub, pipe_name):
    with AhfClient(pipe_name, "a") as a, AhfClient(pipe_name, "b"):
        start = time.monotonic()
        with pytest.raises(AhfTimeout):
            a.request("b", "cmd.test.silent", {}, timeout=0.5)
        assert time.monotonic() - start < 5


def test_ping_is_answered_by_the_client(hub, pipe_name):
    with AhfClient(pipe_name, "a") as a, AhfClient(pipe_name, "b") as b:
        assert hub.wait_for_peer("a")
        b.send("a", "sys.ping", {"n": 7})
        pong = b.wait_event("sys.pong", timeout=5)
        assert pong["payload"] == {"n": 7}


def test_topic_events_reach_subscribers(hub, pipe_name):
    with AhfClient(pipe_name, "engine") as eng, AhfClient(pipe_name, "ui") as ui:
        assert hub.wait_for_peer("ui")
        sub = ui.request("supervisor", "cmd.topic.subscribe", {"topic": "engine"}, timeout=5)
        assert sub["payload"]["ok"] is True
        eng.send("topic:engine", "evt.engine.ready", {"epoch": 1})
        got = list(ui.events(topic="engine", timeout=2))
        assert [m["type"] for m in got] == ["evt.engine.ready"]
        assert got[0]["payload"] == {"epoch": 1}


def test_closed_peer_is_removed(hub, pipe_name):
    a = AhfClient(pipe_name, "a")
    b = AhfClient(pipe_name, "b")
    assert hub.wait_for_peer("b")
    b.close()
    deadline = time.monotonic() + 5
    while "b" in hub.peers() and time.monotonic() < deadline:
        time.sleep(0.05)
    assert "b" not in hub.peers()
    env = a.request("b", "cmd.test.gone", {}, timeout=5)
    assert env["payload"]["error"]["code"] == "not_found"
    a.close()

