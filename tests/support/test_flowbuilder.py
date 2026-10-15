"""WI-0049: unit tests of the flow builder (no process)."""

import json

import pytest

from support.flowbuilder import FlowBuilder, kind_of_class


def conns(fb):
    return list(fb.to_dict()["allConnections"].values())


def test_a_flow_has_the_root_keys_of_the_v2_format():
    fb = FlowBuilder("My flow", strict_types=True)
    fb.trigger()
    d = json.loads(fb.to_text())
    assert d["name"] == "My flow" and d["formatVersion"] == 2
    assert d["flowSettings"]["strictTypes"] is True
    assert d["ElementIDCounter"] == "1"
    (el,) = d["allElements"].values()
    assert el["class"] == "Trigger_Manual" and el["type"] == "trigger" and el["DefaultTrigger"] == "1"


def test_an_element_names_its_package_and_its_class():
    # E0045, WI-0047: "Package.Class", a plain test class is in Test, any other plain class in Default
    fb = FlowBuilder("pkg")
    els = [fb.trigger(), fb.action("Action_Sleep"), fb.action("Action_TestThrow"), fb.action("TestTwin.Action_TestPackageName"),
           fb.action("default.Action_Do_nothing")]
    els += fb.linear("Action_Do_nothing -> Test.Action_TestSetVar")
    got = [(e["package"], e["class"]) for e in fb.to_dict()["allElements"].values()]
    assert got == [("Default", "Trigger_Manual"), ("Default", "Action_Sleep"), ("Test", "Action_TestThrow"),
                   ("TestTwin", "Action_TestPackageName"), ("default", "Action_Do_nothing"),
                   ("Default", "Action_Do_nothing"), ("Test", "Action_TestSetVar")]
    assert [e.package for e in els][3] == "TestTwin" and els[3].cls == "Action_TestPackageName"


def test_the_v1_format_has_neither_the_version_nor_the_type_mode():
    fb = FlowBuilder("old", v2=False, strict_types=True)
    t = fb.trigger()
    a = fb.action("Action_Do_nothing")
    c = fb.condition("Condition_Expression", Expression="x = 1")
    fb.connect(t, a)
    fb.connect(a, c)
    fb.connect(c, a, "yes")
    d = fb.to_dict()
    assert "formatVersion" not in d and "strictTypes" not in d["flowSettings"]
    assert [e["type"] for e in d["allElements"].values()] == ["trigger", "Action", "Condition"]
    assert [c["ConnectionType"] for c in conns(fb)] == ["normal", "normal", "Yes"]


def test_strict_types_none_leaves_the_key_out():
    fb = FlowBuilder("x", strict_types=None)
    assert "strictTypes" not in fb.to_dict()["flowSettings"]
    assert FlowBuilder("x", strict_types=False).to_dict()["flowSettings"]["strictTypes"] is False


def test_parameters_keep_their_json_type_and_ids_are_unique():
    fb = FlowBuilder("t")
    a = fb.action("Action_Sleep", Duration=10, Unit="Milliseconds", Ratio=0.5)
    b = fb.action("Action_Sleep")
    pars = fb.to_dict()["allElements"][a.id]["pars"]
    assert pars == {"Duration": 10, "Unit": "Milliseconds", "Ratio": 0.5}
    assert isinstance(pars["Duration"], int) and isinstance(pars["Ratio"], float)
    assert a.id != b.id and str(a) == a.id
    assert fb.to_dict()["allElements"][b.id]["pars"] == {}


def test_a_loop_has_its_parts_and_the_bar_height():
    fb = FlowBuilder("loop")
    t, loop = fb.trigger(), fb.loop("Loop_SimpleLoop", repeatCount=3)
    body, check, after = fb.action("Action_Do_nothing"), fb.condition("Condition_Expression"), fb.action("Action_Do_nothing")
    fb.connect(t, loop)
    fb.connect(loop, body, "head")
    fb.connect(body, check)
    fb.connect(check, loop, "yes", into="break")
    fb.connect(check, loop, "no", into="tail")
    fb.connect(loop, after, "tail")
    c = conns(fb)
    assert (c[0].get("toPart"), c[0]["ConnectionType"]) == ("HEAD", "normal")
    assert (c[1].get("fromPart"), c[1]["ConnectionType"]) == ("HEAD", "normal")
    assert (c[3]["toPart"], c[3]["ConnectionType"]) == ("BREAK", "yes")
    assert (c[4]["toPart"], c[4]["ConnectionType"]) == ("TAIL", "no")
    assert c[5]["fromPart"] == "TAIL"
    assert fb.to_dict()["allElements"][loop.id]["HeightOfVerticalBar"]


def test_wrong_connections_are_refused():
    fb = FlowBuilder("bad")
    t, a, loop = fb.trigger(), fb.action("Action_Do_nothing"), fb.loop("Loop_SimpleLoop")
    with pytest.raises(ValueError):
        fb.connect(t, a, "head")        # a part of a loop on an element that is no loop
    with pytest.raises(ValueError):
        fb.connect(t, a, into="tail")   # a loop part into an element that is no loop
    with pytest.raises(ValueError):
        fb.connect(t, loop, "maybe")
    with pytest.raises(KeyError):
        fb.connect(t, "element9999999999")
    with pytest.raises(ValueError):
        kind_of_class("Strange_Class")


def test_the_text_form_builds_a_linear_flow():
    fb = FlowBuilder("lin")
    els = fb.linear("Trigger_Manual -> Action_Sleep(Duration=10, Unit='Milliseconds') -> "
                    "Condition_Expression(Expression=\"x = 1, y\") yes-> Action_Do_nothing exception-> Action_TestThrow")
    assert [e.cls for e in els] == ["Trigger_Manual", "Action_Sleep", "Condition_Expression", "Action_Do_nothing",
                                    "Action_TestThrow"]
    pars = fb.to_dict()["allElements"]
    assert pars[els[1].id]["pars"] == {"Duration": 10, "Unit": "Milliseconds"}
    assert pars[els[2].id]["pars"] == {"Expression": "x = 1, y"}
    assert [(c["from"], c["to"], c["ConnectionType"]) for c in conns(fb)] == [
        (els[0].id, els[1].id, "normal"), (els[1].id, els[2].id, "normal"),
        (els[2].id, els[3].id, "yes"), (els[3].id, els[4].id, "exception")]


def test_the_text_form_reports_a_syntax_error():
    for text in ("Trigger_Manual ->", "Trigger_Manual Action_X", "Action_X(Duration)", "Action_X(a=1"):
        with pytest.raises(ValueError):
            FlowBuilder("e").linear(text)


def test_probe_adds_the_test_element_and_remembers_the_names():
    fb = FlowBuilder("p")
    p = fb.probe("x", "A_thread")
    assert fb.probed == ["x", "A_thread"]
    steps = json.loads(fb.to_dict()["allElements"][p.id]["pars"]["Steps"])
    assert steps == [{"op": "probe", "name": "x"}, {"op": "probe", "name": "A_thread"}]


def test_write_makes_a_utf8_file_without_bom(tmp_path):
    fb = FlowBuilder("Flow ä")
    fb.trigger()
    flow_id = fb.write(tmp_path)
    raw = (tmp_path / "Flows" / "Flow ä.json").read_bytes()
    assert flow_id == "Flow ä" and not raw.startswith(b"\xef\xbb\xbf")
    assert json.loads(raw.decode("utf-8"))["name"] == "Flow ä"
