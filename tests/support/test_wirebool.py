"""Unit tests of the strict boolean check (WI-26)."""

from support import wirebool
from support.ahfclient import FrameDecoder, encode_frame


def test_is_bool_rejects_numbers():
    assert wirebool.is_bool(True) and wirebool.is_bool(False)
    assert not wirebool.is_bool(1) and not wirebool.is_bool(0) and not wirebool.is_bool("true")


def test_find_violations_reports_numbers_at_any_depth():
    payload = {"ok": 1, "flows": [{"enabled": True, "executing": 0}], "answer": {"waiting": False, "x": 1}}
    assert wirebool.find_violations(payload) == ["payload.ok = 1", "payload.flows[0].executing = 0"]


def test_find_violations_does_not_look_into_user_data():
    payload = {"definition": {"allElements": {"e1": {"enabled": "0"}}}, "params": {"enabled": 1}}
    assert wirebool.find_violations(payload) == []


def test_find_violations_accepts_real_booleans():
    assert wirebool.find_violations({"ok": True, "cancel": False, "flows": [{"enabled": False}]}) == []


def test_decoder_records_violations_and_take_clears_them():
    wirebool.take_violations()
    dec = FrameDecoder()
    dec.feed(encode_frame('{"to":"a","from":"b","id":"b#1","type":"res.x","corr":null,"payload":{"ok":1}}'))
    got = wirebool.take_violations()
    assert len(got) == 1 and "payload.ok = 1" in got[0]
    assert wirebool.take_violations() == []
