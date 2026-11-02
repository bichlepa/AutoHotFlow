"""Compares the parameter schema of the v2 element classes with the v1 schema (WI-0116, doc/TEST-STRATEGY.md 8c).

The v1 side is tests/data/v1_schema.json (written by tools/v1_schema.py from the unchanged v1 code, regenerated on
purpose). The v2 side is written now by tests/schema/v2_schema.ahk for every registered class. Per class and parameter
id the test compares type (without case), default, content (without case), contentID, choices, enum and result. A
class is compared by its name without case, because v1 names are compared without case, too.

A difference is accepted only with an entry in ALLOWED, with the MIGRATION ID that describes it (doc/MIGRATION.md).
An entry that no longer matches is a failure as well, so the list stays true. Values that v1 writes volatile (a random
phrase in a default) are compared by their fixed parts.
"""

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

import ahkrun  # noqa: E402

DATA = REPO / "tests" / "data" / "v1_schema.json"
V2_SCRIPT = REPO / "tests" / "schema" / "v2_schema.ahk"
MIGRATION = REPO / "doc" / "MIGRATION.md"

# The core set of WI-0116 task 4: the 34 classes that existed before the schema check. Each must be compared.
CORE_SET = [
    "Action_Add_To_List", "Action_Delete_from_list", "Action_Do_nothing", "Action_Execute_Flow",
    "Action_Get_List_Info", "Action_Get_index_of_element_in_list", "Action_Message_Box", "Action_New_List",
    "Action_New_variable", "Action_Set_Flow_Status", "Action_Shuffle_list", "Action_Sleep", "Action_Stop_Flow",
    "Action_Tooltip", "Action_Trace_Point", "Action_Trace_Point_Check",
    "Condition_Confirmation_Dialog", "Condition_Debug_Dialog", "Condition_Do_nothing", "Condition_Expression",
    "Condition_Flow_Enabled", "Condition_Flow_Running", "Condition_List_Contains_Element", "Condition_NumberIs",
    "Condition_Variable_Is_Empty", "Condition_Variable_content_is",
    "Loop_Condition", "Loop_Parse_A_String", "Loop_SimpleLoop", "Loop_Work_through_a_list",
    "Trigger_Hotkey", "Trigger_Manual", "Trigger_Periodic_Timer", "Trigger_Start_up",
]

# The parameter fields that are compared, besides the type (and the id, which is the key).
FIELDS = ("default", "content", "contentID", "choices", "enum", "result")

# The marker that tools/v1_schema.py writes for a random phrase of a default (a volatile value).
RANDOM_PHRASE = "<randomPhrase>"

# The accepted differences: (class ID without case, parameter id or "" for a flag of the class, field) -> MIGRATION ID.
ALLOWED = {
    # M-0099: a radio default that v1 writes as a position (1) and v2 as the enum value of that position
    ("default.action_execute_flow", "WhichTrigger", "default"): "M-0099",
    ("default.action_set_flow_status", "Enable", "default"): "M-0099",
    ("default.action_set_flow_status", "WhichTrigger", "default"): "M-0099",
    ("default.condition_flow_enabled", "WhichTrigger", "default"): "M-0099",
    ("default.action_time_calculation", "Unit", "default"): "M-0099",
    ("default.action_time_difference", "Unit", "default"): "M-0099",
    # WI-0127 (screen and images): the enum radios of Get pixel color have the enum value of the first choice (M-0168);
    # the default names of the green and blue output of v1 are swapped (M-0171)
    ("default.action_get_pixel_color", "CoordMode", "default"): "M-0168",
    ("default.action_get_pixel_color", "Method", "default"): "M-0168",
    ("default.action_get_pixel_color", "Method", "result"): "M-0168",
    ("default.action_get_pixel_color", "varnameG", "default"): "M-0171",
    ("default.action_get_pixel_color", "varnameB", "default"): "M-0171",
    # WI-0127: the window identification of Action_Screenshot is the one of the window elements (M-0102); its method
    # texts are formatted by Lang (M-0151); the flag updateOnEdit is not used (M-0101)
    ("default.action_screenshot", "TitleMatchMode", "enum"): "M-0102",
    ("default.action_screenshot", "TitleMatchMode", "result"): "M-0102",
    ("default.action_screenshot", "Method", "choices"): "M-0151",
    ("default.action_screenshot", "Method", "default"): "M-0099",
    ("default.action_screenshot", "GetWindowInformation", "id"): "M-0102",
    ("default.action_get_screen_settings", "", "updateOnEdit"): "M-0101",
    # M-0173: the choice 11500 K. of the colour temperature is written 115000 K. by v1 (WI-0127)
    ("default.action_set_screen_settings", "ColorTemperature", "choices"): "M-0173",
    # M-0107: the default time of New time is the time of the element's creation (v1 writes the marker <A_Now>)
    ("default.action_new_time", "Time", "default"): "M-0107",
    # M-0164: the default time of Time of day is the time of the element's creation (v1 writes the marker <A_Now>)
    ("default.trigger_time_of_day", "Time", "default"): "M-0164",
    # M-0165: the texts of the choices of User idle time are the translations of the v1 keys (the v1 "MilliSeconds" key
    # is shown as "Milliseconds", the method choices are "Method: <text>" with the argument filled in)
    ("default.trigger_user_idle_time", "Unit", "choices"): "M-0165",
    ("default.trigger_user_idle_time", "Method", "choices"): "M-0165",
    # M-0103: the spelling of an enum value (v1 example flows contain both)
    ("default.action_execute_flow", "WhichTrigger", "enum"): "M-0103",
    # M-0072, M-0073: the choices of the trigger selection of the flow status elements (WI-0065)
    ("default.action_set_flow_status", "WhichTrigger", "choices"): "M-0072",
    ("default.action_set_flow_status", "WhichTrigger", "enum"): "M-0072",
    ("default.condition_flow_enabled", "WhichTrigger", "choices"): "M-0073",
    ("default.condition_flow_enabled", "WhichTrigger", "enum"): "M-0073",
    # M-0100: the default ID of a new manual trigger is empty in v2 (the editor gives it)
    ("default.trigger_manual", "ID", "default"): "M-0100",
    # M-0101: the flag updateOnEdit of the description
    ("default.action_trace_point", "", "updateOnEdit"): "M-0101",
    ("default.action_trace_point_check", "", "updateOnEdit"): "M-0101",
    ("default.trigger_manual", "", "updateOnEdit"): "M-0101",
    # M-0102: the window identification of Trigger_Hotkey
    ("default.trigger_hotkey", "GetWindowInformation", "id"): "M-0102",
    ("default.trigger_hotkey", "TitleMatchMode", "enum"): "M-0102",
    ("default.trigger_hotkey", "TitleMatchMode", "result"): "M-0102",
    # M-0099: radio defaults that v1 writes as a position (1, 3) and v2 as the enum value of that position (WI-0119)
    ("default.action_get_from_list", "WhichPosition", "default"): "M-0099",
    ("default.condition_string_contains_text", "WhereToBegin", "default"): "M-0099",
    ("default.condition_string_contains_text", "CaseSensitive", "default"): "M-0099",
    # M-0108: the new text mode (plain or regular expression) of Replace in a string (WI-0119)
    ("default.action_replace_in_a_string", "TextMode", "id"): "M-0108",
    # WI-0124 (sound and speech): Play sound has the option "Wait until the sound has finished", no Preview buttons, and
    # the editor fills its list of system sounds; Set volume and Speech output use number fields for the ranges that the
    # slider does not show (M-0132); the default voice of Speech output is the system default (M-0135)
    ("default.action_play_sound", "", "updateOnEdit"): "M-0101",
    ("default.action_play_sound", "WaitUntilFinished", "id"): "M-0130",
    ("default.action_play_sound", "startSoundNow", "id"): "M-0130",
    ("default.action_play_sound", "stopSoundNow", "id"): "M-0130",
    ("default.action_play_sound", "systemSound", "choices"): "M-0130",
    ("default.action_set_volume", "Action", "default"): "M-0099",
    ("default.action_set_volume", "Mute", "result"): "M-0134",
    ("default.action_set_volume", "volumeRelative", "type"): "M-0132",
    ("default.action_speech_output", "TTSEngine", "default"): "M-0135",
    ("default.action_speech_output", "TTSEngine", "choices"): "M-0135",
    ("default.action_speech_output", "speed", "type"): "M-0132",
    ("default.action_speech_output", "speed", "content"): "M-0132",
    ("default.action_speech_output", "pitch", "type"): "M-0132",
    ("default.action_speech_output", "pitch", "content"): "M-0132",
    # WI-0130 (AutoHotkey script action and trigger): the default code is AHK v2 (M-0159); the v1 default is v1 syntax
    ("default.trigger_autohotkey_script", "Script", "default"): "M-0159",
    # WI-0122 (archives, drives, internet): the drive lists are filled by the editor, the schema of the engine has none
    # (M-0143); the flag updateOnEdit is not used (M-0101); the default of Lock drive is the enum value (M-0099); the choice
    # texts with a number are formatted by Lang (M-0151)
    ("default.action_change_drive_label", "DriveLetter", "default"): "M-0143",
    ("default.action_change_drive_label", "DriveLetter", "choices"): "M-0143",
    ("default.action_change_drive_label", "", "updateOnEdit"): "M-0101",
    ("default.action_eject_drive", "DriveLetter", "default"): "M-0143",
    ("default.action_eject_drive", "DriveLetter", "choices"): "M-0143",
    ("default.action_eject_drive", "", "updateOnEdit"): "M-0101",
    ("default.action_eject_drive", "Method", "choices"): "M-0151",
    ("default.action_get_drive_information", "DriveLetter", "default"): "M-0143",
    ("default.action_get_drive_information", "DriveLetter", "choices"): "M-0143",
    ("default.action_get_drive_information", "", "updateOnEdit"): "M-0101",
    ("default.action_lock_or_unlock_drive", "DriveLetter", "default"): "M-0143",
    ("default.action_lock_or_unlock_drive", "DriveLetter", "choices"): "M-0143",
    ("default.action_lock_or_unlock_drive", "", "updateOnEdit"): "M-0101",
    ("default.action_lock_or_unlock_drive", "WhatDo", "default"): "M-0099",
}
# M-0139: the window identification of the window and control elements (WI-0125, WI-0126), as M-0102 for Trigger_Hotkey
# and Trigger_Hotstring (WI-0131)
for _cls in ("action_activate_window", "action_show_window", "action_hide_window", "action_close_window",
             "action_move_window", "action_get_control_text", "action_set_control_text",
             "action_send_keystrokes_to_control", "condition_window_active", "condition_window_exists",
             "trigger_hotstring"):
    ALLOWED[("default." + _cls, "GetWindowInformation", "id")] = "M-0139"
    ALLOWED[("default." + _cls, "TitleMatchMode", "enum")] = "M-0139"
    ALLOWED[("default." + _cls, "TitleMatchMode", "result")] = "M-0139"
# M-0155: the radios with result enum of the mouse elements have the number 1 as default in v1 (the position of the
# first choice), the enum value in v2 (the same rule as M-0099)
ALLOWED[("default.action_move_mouse", "CoordMode", "default")] = "M-0155"
ALLOWED[("default.action_move_mouse", "SendMode", "default")] = "M-0155"
ALLOWED[("default.action_drag_with_mouse", "SendMode", "default")] = "M-0155"


def load_v1():
    with open(DATA, encoding="utf-8") as f:
        return json.load(f)["classes"]


def run_v2(folder):
    """The v2 schema of the product, written by tests/schema/v2_schema.ahk through tools/ahkrun.py."""
    out = Path(folder) / "v2_schema.json"
    code, stdout, stderr, dialogs = ahkrun.run(str(V2_SCRIPT), [str(out)], timeout=120)
    assert code == 0 and not dialogs, "v2_schema.ahk failed (exit %s): %s %s" % (code, stderr, stdout)
    with open(out, encoding="utf-8-sig") as f:
        return json.load(f)["classes"]


def split(value):
    """The fields of a class entry and its flags: v1 writes a class with flags as an object of numbered fields."""
    if isinstance(value, dict):
        numbered = sorted((key for key in value if key.isdigit()), key=int)
        return [value[key] for key in numbered], {key: value[key] for key in value if not key.isdigit()}
    return list(value), {}


def is_empty(value):
    return value in (None, "", [], {})


def norm(value):
    """A value as text, so that 10 and "10" are the same (v1 has no types); an empty value is "" (no default)."""
    if is_empty(value):
        return ""
    if isinstance(value, bool):
        return str(int(value))
    if isinstance(value, list):
        return [norm(item) for item in value]
    return str(value)


def lower(value):
    if isinstance(value, str):
        return value.lower()
    if isinstance(value, list):
        return [lower(item) for item in value]
    return value


def record(field, default):
    entry = {"type": str(field.get("type", "")).lower(), "default": default}
    for key in FIELDS:
        if key == "default":
            continue
        entry[key] = lower(field.get(key)) if key == "content" else field.get(key)
    return entry


def records(fields):
    """{parameter id: [record, ...]}. A field with several ids gives one record per id, the default of that index."""
    out = {}
    for field in fields:
        if not isinstance(field, dict) or "id" not in field:
            continue
        ids = field["id"]
        defaults = field.get("default")
        if isinstance(ids, list):
            for index, pid in enumerate(ids):
                default = defaults[index] if isinstance(defaults, list) and index < len(defaults) else None
                out.setdefault(pid, []).append(record(field, default))
        else:
            out.setdefault(ids, []).append(record(field, defaults))
    return out


def default_matches(v1_default, v2_default):
    """A v1 default with the random phrase marker matches a v2 default with the same fixed parts and a phrase."""
    if not isinstance(v1_default, str) or RANDOM_PHRASE not in v1_default:
        return False
    prefix, suffix = v1_default.split(RANDOM_PHRASE, 1)
    if not isinstance(v2_default, str):
        return False
    return (v2_default.startswith(prefix) and v2_default.endswith(suffix)
            and len(v2_default) > len(prefix) + len(suffix))


def differences(v1_fields, v2_fields):
    """Yields (parameter id, field, v1 value, v2 value) for every difference of one class."""
    a = records(v1_fields)
    b = records(v2_fields)
    for pid in sorted(set(a) | set(b)):
        if pid not in a:
            yield pid, "id", "missing", "present"
            continue
        if pid not in b:
            yield pid, "id", "present", "missing"
            continue
        if len(a[pid]) != len(b[pid]):
            yield pid, "count", len(a[pid]), len(b[pid])
            continue
        for x, y in zip(a[pid], b[pid]):
            if x["type"] != y["type"]:
                yield pid, "type", x["type"], y["type"]
            for key in FIELDS:
                if key == "default" and default_matches(x[key], y[key]):
                    continue
                if norm(x[key]) == norm(y[key]):
                    continue
                yield pid, key, x[key], y[key]


def by_name(classes):
    """{class ID without case: (class ID, entry)}."""
    return {name.lower(): (name, value) for name, value in classes.items()}


def compare(v1, v2, allowed=None):
    """Returns (problems, used): the differences that are not allowed, and the allow list entries that matched.

    v1 and v2 are the "classes" objects of the two schemas. Only classes that both sides have are compared (the
    caller checks the core set); a v2 class that throws in Parameters("") is a problem.
    """
    allowed = ALLOWED if allowed is None else allowed
    v1_by = by_name(v1)
    problems = []
    used = set()
    compared = set()

    def accept(key, text):
        if key in allowed:
            used.add(key)
            return
        problems.append(text)

    for name, entry in sorted(v2.items()):
        if name.lower() not in v1_by:
            continue
        compared.add(name.lower())
        v1_name, v1_entry = v1_by[name.lower()]
        if isinstance(entry, dict) and "error" in entry:
            problems.append("%s: Parameters(\"\") throws: %s" % (name, entry["error"]))
            continue
        v1_fields, v1_flags = split(v1_entry)
        v2_fields, v2_flags = split(entry)
        for flag in sorted(set(v1_flags) | set(v2_flags)):
            key = (name.lower(), "", flag)
            if (flag in v1_flags) != (flag in v2_flags):
                accept(key, "%s: flag '%s' is on the %s side only (v1: %r, v2: %r)" % (
                    name, flag, "v1" if flag in v1_flags else "v2", v1_flags.get(flag), v2_flags.get(flag)))
        for pid, field, x, y in differences(v1_fields, v2_fields):
            key = (name.lower(), pid, field)
            accept(key, "%s, parameter '%s', %s: v1 %s, v2 %s" % (name, pid, field, json.dumps(x, ensure_ascii=False),
                                                                    json.dumps(y, ensure_ascii=False)))
    for key in sorted(allowed):
        if key[0] in compared and key not in used:
            problems.append("allow list entry %r matches no difference any more (remove it)" % (key,))
    return problems, used, compared


def migration_ids_of_allowed(allowed):
    return sorted(set(allowed.values()))


def test_the_v1_schema_file_has_the_v1_classes_of_the_core_set():
    v1 = load_v1()
    names = {name.lower() for name in v1}
    missing = [name for name in CORE_SET if "default." + name.lower() not in names]
    assert not missing, "no v1 schema for: %s" % ", ".join(missing)


def test_the_v2_script_writes_the_schema_of_the_registered_classes(tmp_path):
    v2 = run_v2(tmp_path)
    assert len(v2) >= len(CORE_SET)
    assert not [name for name, entry in v2.items() if isinstance(entry, dict) and "error" in entry]


def test_the_core_set_matches_v1_except_the_allow_list(tmp_path):
    v2 = run_v2(tmp_path)
    problems, used, compared = compare(load_v1(), v2)
    compared_core = {name.lower() for name in CORE_SET if "default." + name.lower() in compared}
    not_compared = [name for name in CORE_SET if name.lower() not in compared_core]
    assert not not_compared, "not compared against v1: %s" % ", ".join(not_compared)
    assert not problems, "%d difference(s) of the v2 classes to v1:\n%s" % (len(problems), "\n".join(problems))


def test_every_allow_list_entry_names_an_existing_migration_entry():
    text = MIGRATION.read_text(encoding="utf-8")
    for key, migration in ALLOWED.items():
        assert re.search(r"^\| %s \|" % re.escape(migration), text, re.MULTILINE), \
            "%r names %s, which is not in doc/MIGRATION.md" % (key, migration)
    assert all(re.fullmatch(r"M-\d{4}", migration) for migration in migration_ids_of_allowed(ALLOWED))


def test_the_comparison_reports_a_changed_default_and_a_missing_id_with_class_and_id():
    v1 = {"Default.Action_X": [{"type": "Edit", "id": "Text", "default": "1", "content": "String"},
                               {"type": "Edit", "id": "Gone", "default": ""}]}
    v2 = {"Default.action_x": [{"type": "edit", "id": "Text", "default": "2", "content": "string"}]}
    problems, used, compared = compare(v1, v2, allowed={})
    assert len(problems) == 2, problems
    assert any("Default.action_x" in p and "'Text'" in p and "default" in p for p in problems), problems
    assert any("'Gone'" in p and "id" in p for p in problems), problems


def test_the_comparison_accepts_matching_values_in_other_notations_and_volatile_defaults():
    v1 = {"Default.Action_X": [{"type": "Edit", "id": "N", "default": 10, "content": "PositiveNumber"},
                               {"type": "Edit", "id": "P", "default": "Tracepoint <randomPhrase>"}]}
    v2 = {"Default.Action_X": [{"type": "Edit", "id": "N", "default": "10", "content": "positiveNumber"},
                               {"type": "Edit", "id": "P", "default": "Tracepoint shiny ship"}]}
    problems, used, compared = compare(v1, v2, allowed={})
    assert problems == [], problems


def test_an_allow_list_entry_covers_one_difference_and_must_match_one():
    v1 = {"Default.Action_X": [{"type": "Radio", "id": "E", "default": 1, "result": "enum", "enum": ["A", "B"]}]}
    v2 = {"Default.Action_X": [{"type": "Radio", "id": "E", "default": "A", "result": "enum", "enum": ["A", "B"]}]}
    key = ("default.action_x", "E", "default")
    problems, used, compared = compare(v1, v2, allowed={key: "M-0099"})
    assert problems == [] and used == {key}
    problems, used, compared = compare(v1, v2, allowed={key: "M-0099", ("default.action_x", "E", "result"): "M-0099"})
    assert len(problems) == 1 and "matches no difference" in problems[0]
