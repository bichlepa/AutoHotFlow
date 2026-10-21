"""WI-0104, REQ-ROB-120, REQ-EDT-100 and E0065 (nothing lost): an edit that the editor has sent and the engine has answered
is on disk a few seconds later, whatever happens to the editor or to the engine.

The real supervisor with the storage, the engine and the editor, headless (as in test_editor_draft.py). The edits are made
with cmd.test.edit of the editor; "completed" means the editor shows no patch on its way (settled) and the engine's
definition has the element. The file is read on disk (the autosave of E0065 writes it 3 s after the commit, at the latest
10 s after the first unsaved one). A torn read of the file counts as "not yet".

Cases: a killed editor (the notice of WI-0103, then the reopened editor shows the edit), a closed editor with an edit that
the engine has not written yet (nothing is asked, the engine writes it), a killed engine (the restarted engine and the
editor have the written edit), and the backup of the first write of an editing session (backup/ in the flow folder).

Not here: an engine killed within the 10 s before its write (the edit may be lost by design, E0065; the time rule is in
tests/integration/test_flow_autosave.py, which controls the timers).

Deterministic: a test waits for a condition (wait_until), never for a fixed time, except the write, which has a margin of
the 10 s rule (scaled).
"""

import json
from pathlib import Path

import psutil

from support.timing import scaled
from test_manager import FLOW, process_states, wait_until
from test_manager_editor import finish, op, start_manager
from test_editor import editor_state, open_editor
from test_editor_draft import NEW, add_action, edit, engine_definition, settled
import test_editor_crash_notice as notice

EDITOR = "editor:" + FLOW


def on_disk(datadir, element=NEW):
    """True when the flow file of the flow has the element (a torn read or a missing file is "not yet")."""
    try:
        data = json.loads((Path(datadir) / "Flows" / (FLOW + ".json")).read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return False
    return element in data.get("allElements", {})


def backups(datadir):
    return sorted((Path(datadir) / "Flows" / "backup").glob(FLOW + "_backup_*.json"))


def test_an_edit_is_on_disk_a_few_seconds_later_and_the_first_write_of_the_session_has_a_backup(procs, datadir,
                                                                                               session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        edit(obs, [add_action(NEW)])
        assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)
        assert wait_until(lambda: on_disk(datadir), scaled(12)), "the edit is not written within 10 s"
        assert len(backups(datadir)) >= 1, "the first write of the editing session asks for a backup (E0065)"
    finally:
        finish(sup, obs)


def test_a_killed_editor_loses_no_completed_edit_and_the_reopened_editor_shows_it(procs, datadir, session_id):
    sup, obs = notice.start(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        before = open_editor(obs)
        edit(obs, [add_action(NEW)])
        assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)
        assert wait_until(lambda: on_disk(datadir), scaled(12)), "the edit is not written within 10 s"
        old = notice.kill_editor(obs)
        assert wait_until(lambda: len(notice.editor_notices(obs)) == 1, scaled(15)), "the user gets the notice"
        assert wait_until(lambda: notice.tray_info(obs)["editorFlow"] == FLOW, scaled(15))
        assert notice.tray_click(obs) is True
        notice.wait_editor_again(obs, old)
        st = editor_state(obs)
        assert st["elements"] == before["elements"] + 1, "the reopened editor shows the edit: %r" % st
        assert NEW in engine_definition(obs)["allElements"]
    finally:
        finish(sup, obs)


def test_an_editor_closed_with_an_edit_not_yet_written_asks_nothing_and_the_engine_writes_it(procs, datadir,
                                                                                             session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        edit(obs, [add_action(NEW)])
        assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)
        ans = obs.request(EDITOR, "cmd.test.close", {}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: process_states(obs).get(EDITOR, {}).get("state") == "exited", scaled(15)), \
            process_states(obs).get(EDITOR)
        assert process_states(obs)[EDITOR].get("clean") in (True, None), process_states(obs)[EDITOR]
        assert wait_until(lambda: on_disk(datadir), scaled(12)), "the engine writes the edit after the editor has gone"
        assert NEW in engine_definition(obs)["allElements"]
    finally:
        finish(sup, obs)


def test_a_killed_engine_keeps_the_edit_that_was_written_and_the_editor_shows_it(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        before = open_editor(obs)
        edit(obs, [add_action(NEW)])
        assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)
        assert wait_until(lambda: on_disk(datadir), scaled(12)), "the edit is not written within 10 s"
        engine_pid = process_states(obs)["engine"]["pid"]
        psutil.Process(engine_pid).kill()
        assert wait_until(lambda: process_states(obs).get("engine", {}).get("pid") not in (None, engine_pid)
                          and process_states(obs)["engine"].get("state") == "ready", scaled(30)), process_states(obs)
        assert wait_until(lambda: (editor_state(obs) or {}).get("epoch") not in (None, before["epoch"])
                          and (editor_state(obs) or {}).get("engine") == "ready", scaled(30)), editor_state(obs)
        assert NEW in engine_definition(obs)["allElements"], "the restarted engine has the written edit"
        assert editor_state(obs)["elements"] == before["elements"] + 1
    finally:
        finish(sup, obs)
