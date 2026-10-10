"""Frame and envelope rules of PROTOKOLL 1 (pure Python, no process needed)."""

import json
import struct

import pytest

from support.ahfclient import (MAX_FRAME, FrameDecoder, ProtocolError, dumps, encode_frame,
                               make_envelope)


def test_frame_is_little_endian_length_plus_utf8():
    frame = encode_frame('{"a":"ä"}')
    body = '{"a":"ä"}'.encode("utf-8")
    assert frame[:4] == struct.pack("<I", len(body))
    assert frame[4:] == body


def test_decoder_handles_split_and_multiple_frames():
    data = encode_frame('{"n":1}') + encode_frame('{"n":2}')
    dec = FrameDecoder()
    out = []
    for i in range(len(data)):           # one byte at a time
        out.extend(dec.feed(data[i:i + 1]))
    assert out == [{"n": 1}, {"n": 2}]


def test_json_types_survive_round_trip():
    """Strings stay strings and numbers stay numbers (flow files mix both)."""
    text = dumps(make_envelope("a", "a#1", "b", "cmd.x", None, 5000,
                               {"ElementIDCounter": "5", "zoomFactor": "0.700000", "DelimiterComma": 1, "x": 7}))
    (env,) = FrameDecoder().feed(encode_frame(text))
    assert env["payload"]["ElementIDCounter"] == "5"
    assert isinstance(env["payload"]["ElementIDCounter"], str)
    assert env["payload"]["DelimiterComma"] == 1
    assert isinstance(env["payload"]["DelimiterComma"], int)


def test_envelope_head_fields_come_first():
    text = dumps(make_envelope("engine", "engine#3", "editor:x", "evt.flow.state", None, None, {"ok": True}))
    assert list(json.loads(text).keys()) == ["to", "from", "id", "type", "corr", "payload"]
    assert text.index('"to"') < text.index('"payload"')


def test_timeout_only_when_given():
    env = make_envelope("a", "a#1", "b", "cmd.x", None, 1500)
    assert list(env.keys()) == ["to", "from", "id", "type", "corr", "timeoutMs", "payload"]


def test_oversized_frame_is_rejected_on_send():
    with pytest.raises(ProtocolError):
        encode_frame("x" * (MAX_FRAME + 1))


def test_oversized_length_is_rejected_on_receive():
    with pytest.raises(ProtocolError):
        FrameDecoder().feed(struct.pack("<I", MAX_FRAME + 1))


def test_invalid_json_is_a_protocol_error():
    with pytest.raises(ProtocolError):
        FrameDecoder().feed(encode_frame("{not json"))
