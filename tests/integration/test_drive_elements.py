"""WI-0122: end-to-end tests of the drive elements of the package Default: List drives, Get drive information, Change drive
label, Eject drive and Lock or unlock drive.

The reading elements (List drives, Get drive information) run for real: they only read the drives of the machine, and the
tests compare them with the drives of the operating system. The changing elements (label, eject, retract, lock, unlock) go
through the seam SystemOps (E0103): the test provider records each call with its arguments and changes no drive, so no
test touches a real drive (WI-0122 lesson 2).
"""

import ctypes
import json

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.system import SystemScript, error


def element_flow(name, cls, probe=None, **pars):
    """trigger -> the element -> (a probe of the variable)."""
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probe:
        parts.append(fb.probe(probe))
    fb.chain(*parts)
    return fb


def message_of(run):
    assert run.exceptions, run.steps
    return run.exceptions[0]


def calls(system, function):
    return [c for c in system.requests() if c["function"] == function]


def values_of(probe):
    """The members of a list variable (a probe of a Map: the JSON object of the keys 1..n, or the JSON array)."""
    data = json.loads(probe.text)
    return list(data.values()) if isinstance(data, dict) else list(data)


def os_drive_letters():
    """The drive letters of the operating system, from the bit mask of GetLogicalDrives (A to Z)."""
    mask = ctypes.windll.kernel32.GetLogicalDrives()
    return [chr(ord("A") + bit) for bit in range(26) if mask & (1 << bit)]


@pytest.fixture
def system(flows):
    """The script of the system provider: no answers, so every call is only recorded."""
    script = SystemScript(flows.datadir)
    script.script({})
    return script


# --- List drives -------------------------------------------------------------------------------------------------------
def test_list_drives_gives_every_drive_letter_of_the_system(flows):
    runs = run_all(flows, [element_flow("list_all", "Action_List_drives", probe="drives", Varname="drives")])
    assert not runs[0].exceptions, runs[0].steps
    probe = runs[0].seen["drives"]
    assert probe.type == "Map", probe.text
    assert sorted(values_of(probe)) == sorted(os_drive_letters())


def test_list_drives_of_one_type_gives_only_that_type(flows):
    """The type filter asks the system for one kind of drive; the result is a subset of all drives, without colons."""
    runs = run_all(flows, [element_flow("list_fixed", "Action_List_drives", probe="drives", Varname="drives",
                                        WhetherDriveTypeFilter="filter", DriveType="FIXED")])
    assert not runs[0].exceptions, runs[0].steps
    found = values_of(runs[0].seen["drives"])
    assert set(found) <= set(os_drive_letters())
    assert all(len(letter) == 1 for letter in found)


def test_list_drives_of_a_type_that_is_not_there_throws_the_exception(flows):
    """With no RAM disk on the machine, the choice Exception ends the element with "No drives found" (v1 text)."""
    if any(ctypes.windll.kernel32.GetDriveTypeW(letter + ":\\") == 6 for letter in os_drive_letters()):
        pytest.skip("this machine has a RAM disk: no drive type is missing")
    runs = run_all(flows, [element_flow("list_none", "Action_List_drives", probe="drives", Varname="drives",
                                        WhetherDriveTypeFilter="filter", DriveType="RAMDISK", IfNothingFound="Exception")])
    assert "No drives found" in message_of(runs[0])


# --- Get drive information -----------------------------------------------------------------------------------------------
def info_flow(name, info, letter="", folder="", **extra):
    return element_flow(name, "Action_Get_Drive_Information", probe="info", Varname="info", WhichInformation=info,
                        DriveLetter=letter, folder=folder, **extra)


def test_drive_information_of_a_folder_on_a_drive(flows, tmp_path):
    runs = run_all(flows, [
        info_flow("type", "Type", folder=str(tmp_path)),
        info_flow("capacity", "Capacity", folder=str(tmp_path)),
        info_flow("free", "FreeSpace", folder=str(tmp_path)),
    ])
    for run in runs:
        assert not run.exceptions, run.steps
    assert runs[0].seen["info"].text in ("Fixed", "Removable", "Network", "CDROM", "RAMDisk", "Unknown")
    assert int(runs[1].seen["info"].text) > 0
    assert int(runs[2].seen["info"].text) >= 0


def test_drive_information_by_drive_letter(flows):
    letter = os_drive_letters()[0] + ":"
    runs = run_all(flows, [
        info_flow("label", "Label", letter=letter),
        info_flow("status", "Status", letter=letter),
        info_flow("fs", "FileSystem", letter=letter),
    ])
    for run in runs:
        assert not run.exceptions, run.steps
    assert isinstance(runs[0].seen["info"].text, str)
    assert runs[1].seen["info"].text != ""
    assert runs[2].seen["info"].text != ""


def test_a_drive_letter_without_colon_is_accepted(flows):
    letter = os_drive_letters()[0]
    runs = run_all(flows, [info_flow("nocolon", "Status", letter=letter)])
    assert not runs[0].exceptions, runs[0].steps
    assert runs[0].seen["info"].text != ""


def test_an_empty_drive_letter_is_an_exception(flows):
    runs = run_all(flows, [info_flow("empty", "Label", letter="")])
    assert "DriveLetter" in message_of(runs[0]) and "empty" in message_of(runs[0])


def test_a_text_that_is_no_drive_letter_is_an_exception(flows):
    runs = run_all(flows, [info_flow("notletter", "Label", letter="12")])
    assert "is not a drive letter" in message_of(runs[0])


def test_a_missing_folder_for_the_capacity_is_an_exception(flows, tmp_path):
    runs = run_all(flows, [info_flow("nofolder", "Capacity", folder=str(tmp_path / "missing"))])
    assert "does not exist" in message_of(runs[0])


# --- Change drive label --------------------------------------------------------------------------------------------------
def test_change_label_passes_drive_and_label_to_the_seam(flows, system):
    runs = run_all(flows, [element_flow("label", "Action_Change_Drive_Label", DriveLetter="E:", NewLabel="Backup")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "DriveSetLabel")[-1]["args"] == ["E:", "Backup"], system.requests()


def test_an_empty_new_label_removes_the_label(flows, system):
    runs = run_all(flows, [element_flow("nolabel", "Action_Change_Drive_Label", DriveLetter="E:", NewLabel="")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "DriveSetLabel")[-1]["args"] == ["E:"]


def test_a_failing_label_change_is_an_exception(flows, system):
    system.script({"DriveSetLabel": [error("access denied")]})
    runs = run_all(flows, [element_flow("label_fail", "Action_Change_Drive_Label", DriveLetter="E:", NewLabel="X")])
    assert message_of(runs[0]) == "Label 'X' could not be set to drive 'E:'", runs[0].exceptions


def test_change_label_without_a_drive_is_an_exception(flows, system):
    runs = run_all(flows, [element_flow("label_nodrive", "Action_Change_Drive_Label", DriveLetter="", NewLabel="X")])
    assert "DriveLetter" in message_of(runs[0]) and "empty" in message_of(runs[0])
    assert not calls(system, "DriveSetLabel")


# --- Eject and retract ---------------------------------------------------------------------------------------------------
def test_eject_passes_the_drive_to_the_seam(flows, system):
    runs = run_all(flows, [element_flow("eject", "Action_Eject_Drive", DriveLetter="E:", WhatDo="ejectDrive")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "DriveEject")[-1]["args"] == ["E:"], system.requests()


def test_retract_the_tray_calls_drive_retract(flows, system):
    runs = run_all(flows, [element_flow("retract", "Action_Eject_Drive", DriveLetter="D:", WhatDo="RetractTray")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "DriveRetract")[-1]["args"] == ["D:"]
    assert not calls(system, "DriveEject")


@pytest.mark.parametrize("method", ["LibraryEjectByScan", "DeviceIoControl", "builtIn"])
def test_every_method_ends_in_the_same_eject_call(flows, system, method):
    runs = run_all(flows, [element_flow("eject_" + method, "Action_Eject_Drive", DriveLetter="E:", WhatDo="ejectDrive",
                                        Method=method)])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "DriveEject")[-1]["args"] == ["E:"]


def test_a_failing_eject_is_an_exception_with_the_description(flows, system):
    system.script({"DriveEject": [error("the device is busy")]})
    runs = run_all(flows, [element_flow("eject_fail", "Action_Eject_Drive", DriveLetter="E:", WhatDo="ejectDrive")])
    text = message_of(runs[0])
    assert text.startswith("Drive E: could not be ejected"), text
    assert "the device is busy" in text


def test_a_failing_retract_is_an_exception(flows, system):
    system.script({"DriveRetract": [error("no tray")]})
    runs = run_all(flows, [element_flow("retract_fail", "Action_Eject_Drive", DriveLetter="D:", WhatDo="RetractTray")])
    assert message_of(runs[0]).startswith("Drive D: could not be retracted")


# --- Lock and unlock -----------------------------------------------------------------------------------------------------
def test_lock_passes_the_drive_to_the_seam(flows, system):
    runs = run_all(flows, [element_flow("lock", "Action_Lock_Or_Unlock_Drive", DriveLetter="D:", WhatDo="Lock")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "DriveLock")[-1]["args"] == ["D:"]
    assert not calls(system, "DriveUnlock")


def test_unlock_passes_the_drive_to_the_seam(flows, system):
    runs = run_all(flows, [element_flow("unlock", "Action_Lock_Or_Unlock_Drive", DriveLetter="D:", WhatDo="Unlock")])
    assert not runs[0].exceptions, runs[0].steps
    assert calls(system, "DriveUnlock")[-1]["args"] == ["D:"]


def test_a_failing_lock_and_unlock_are_exceptions(flows, system):
    system.script({"DriveLock": [error("not supported")], "DriveUnlock": [error("not locked")]})
    runs = run_all(flows, [
        element_flow("lock_fail", "Action_Lock_Or_Unlock_Drive", DriveLetter="D:", WhatDo="Lock"),
        element_flow("unlock_fail", "Action_Lock_Or_Unlock_Drive", DriveLetter="D:", WhatDo="Unlock"),
    ])
    assert message_of(runs[0]) == "Could not lock drive 'D:'"
    assert message_of(runs[1]) == "Could not unlock drive 'D:'"
