"""The flow of the manual check 3 (tests/data/manual/dpi_dialogs.json, doc/MANUAL-CHECKS.md section 3) loads in the
engine, and every element class it uses is an element of its package. No element runs and no window opens: the flow
is only loaded (cmd.flow.get). The owner starts it in the manager.
"""

import json
from pathlib import Path

import manual_check
from support.flowrun import flows  # noqa: F401  (fixture)

ELEMENTS = Path(__file__).resolve().parents[2] / "src" / "elements"
DIALOG_CLASSES = {"Action_Message_Box", "Condition_Confirmation_Dialog", "Condition_Debug_Dialog", "Action_Tooltip"}


def element_classes(data):
    return sorted((el["package"], el["class"]) for el in data["allElements"].values())


def test_the_dpi_check_flow_loads_and_its_elements_are_in_their_packages(flows):
    source = Path(manual_check.flow_source("dpi_dialogs"))
    classes = element_classes(json.loads(source.read_text(encoding="utf-8")))
    assert DIALOG_CLASSES <= {cls for _, cls in classes}, "the four dialog elements of the check"
    for package, cls in classes:
        assert list(ELEMENTS.glob("%s/**/%s.ahk" % (package, cls))), "%s.%s is no element file" % (package, cls)

    flow_id = flows.add_file(source, "dpi_dialogs")
    flows.start()
    definition = flows.request_ok("engine", "cmd.flow.get", {"flowId": flow_id})["definition"]
    assert element_classes(definition) == classes
    assert definition["flowSettings"]["strictTypes"] is True


CHECK12 = {"check12_system": 11, "check12_dialogs": 5, "check12_shortcut": 2, "check12_input": 7}


def test_the_flows_of_manual_check_12_name_only_element_files():
    """WI-0135: the flows of manual check 12 (sound, speech, volume, screen, screenshot and input block; dialogs; shortcut;
    keys and mouse). Only their files are tested: the owner runs them (the elements act on the real system, a headless run
    would beep, speak and click)."""
    for name, count in CHECK12.items():
        data = json.loads(Path(manual_check.flow_source(name)).read_text(encoding="utf-8"))
        classes = element_classes(data)
        assert len(classes) == count, name
        for package, cls in classes:
            assert list(ELEMENTS.glob("%s/**/%s.ahk" % (package, cls))), "%s: %s.%s is no element file" % (name, package, cls)
    system = json.loads(Path(manual_check.flow_source("check12_system")).read_text(encoding="utf-8"))
    states = [el["pars"].get("blockState") for el in system["allElements"].values() if el["class"] == "Action_Block_User_Input"]
    assert sorted(states) == ["Block", "Unblock"]          # a block is always followed by its unblock
    state = json.loads(Path(manual_check.FLOWS_DIR, "check12_shortcut.state.json").read_text(encoding="utf-8"))
    shortcut = json.loads(Path(manual_check.flow_source("check12_shortcut")).read_text(encoding="utf-8"))
    assert state["enabled"] == [i for i, el in shortcut["allElements"].items() if el["class"] == "Trigger_Shortcut"]
