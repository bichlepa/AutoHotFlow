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
