"""WI-0028 step d: Debug.Dump (src/core/Debug.ahk), the replacement of the v1 function d().
doc/PROTOCOL.md 4.9. The test role echo calls it on request (cmd.test.dump).
"""

import json

import pytest

from faultkit import event, request_ok, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault


def dump(chain, **payload):
    return request_ok(chain.obs, "echo:a", "cmd.test.dump", payload)


def dumps(chain, title):
    return [m for _, m in chain.rec.find(event("evt.debug.dump", title=title))]


def echo_chain(chains):
    chain = chains("echo:a", ["--test-roles"])
    chain.wait_ready(["echo:a"])
    return chain


def test_without_a_subscriber_dump_neither_blocks_nor_throws(chains):
    chain = echo_chain(chains)
    answer = dump(chain, title="nobody listens", value={"a": 1}, count=50)
    assert answer["sentNow"] == 50 and answer["failed"] == 0, answer       # sent to the hub, which drops them
    # the role is fine and answers at once
    assert request_ok(chain.obs, "echo:a", "cmd.test.echo", {"x": 1})["echo"] == {"x": 1}
    assert not dumps(chain, "nobody listens")


def test_a_subscriber_gets_the_value_as_readable_json(chains):
    chain = echo_chain(chains)
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "debug"})
    dump(chain, title="state", value={"name": "x", "list": [1, "two", 3.5], "nested": {"ok": True}})
    got = chain.rec.wait(event("evt.debug.dump", title="state"), timeout=10)
    assert got is not None
    msg = got[1]
    assert msg["from"] == "echo:a" and msg["to"] == "topic:debug"
    payload = msg["payload"]
    assert payload["truncated"] is False
    assert payload["ts"][:2] == "20"
    value = json.loads(payload["json"])
    assert value == {"name": "x", "list": [1, "two", 3.5], "nested": {"ok": 1}}   # Json.Parse reads true as 1 in the role
    assert "\n" in payload["json"]                                              # indented: readable


def test_odd_values_do_not_throw_and_a_big_one_is_cut(chains):
    chain = echo_chain(chains)
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "debug"})
    for kind in ("cycle", "deep", "objects", "big"):
        answer = dump(chain, title=kind, kind=kind)
        assert answer["failed"] == 0, (kind, answer)
        assert chain.rec.wait(event("evt.debug.dump", title=kind), timeout=10) is not None, kind
    cycle = json.loads(dumps(chain, "cycle")[0]["payload"]["json"])
    assert cycle["self"] == "<cycle>"
    objects = json.loads(dumps(chain, "objects")[0]["payload"]["json"])
    assert objects["fn"] == "<Func>" and objects["role"] == "<EchoRole>" and objects["plain"]["b"] == [1, 2]
    assert "too deep" in dumps(chain, "deep")[0]["payload"]["json"]
    big = dumps(chain, "big")[0]["payload"]
    assert big["truncated"] is True and len(big["json"]) < 61000


def test_a_flood_is_limited_per_second_and_counted(chains):
    chain = echo_chain(chains)
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "debug"})
    answer = dump(chain, title="flood", value=1, count=400)
    # one second window: at most 100 are sent, the rest is dropped and counted (a slow machine may span two windows)
    assert 100 <= answer["sent"] <= 200 and answer["dropped"] == 400 - answer["sent"], answer
    assert wait_until(lambda: len(dumps(chain, "flood")) == answer["sent"], 10.0), len(dumps(chain, "flood"))
    assert request_ok(chain.obs, "echo:a", "cmd.test.echo", {"x": 2})["echo"] == {"x": 2}
