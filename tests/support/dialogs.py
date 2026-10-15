"""Script and log of the dialog test provider (WI-0051, E0038).

The provider (tests/integration/helpers/TestDialogProvider.ahk) answers the dialogs of elements from
<data folder>/TestDialogs/script.json and logs every request to requests.jsonl in the same folder. The files are
the same for every process of the session (engine, every worker), so a test needs no message route.

    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("Yes"), no_answer())     # the first dialog gets "Yes", the second is never answered
    ...run the flow...
    assert dialogs.requests()[0]["args"]["text"] == "Really?"
"""

import json


def answer(value, delay_ms=0, kind=None):
    """An entry for a dialog that is answered. value: String (MsgBox button, path), list (FileSelect multi-select),
    or for InputBox {"result": "OK", "value": "text"}."""
    entry = {"answer": value}
    if delay_ms:
        entry["delayMs"] = delay_ms
    if kind:
        entry["kind"] = kind
    return entry


def no_answer(delay_ms=0, kind=None):
    """An entry for a dialog that nobody answers: it returns "Timeout" after its T option, or waits for ever."""
    entry = {"noAnswer": True}
    if delay_ms:
        entry["delayMs"] = delay_ms
    if kind:
        entry["kind"] = kind
    return entry


class DialogScript:
    def __init__(self, datadir):
        self.dir = datadir / "TestDialogs"

    def script(self, *entries):
        """Writes the script (replaces the previous one). Write it before the dialogs are requested."""
        self.dir.mkdir(parents=True, exist_ok=True)
        (self.dir / "script.json").write_text(json.dumps({"answers": list(entries)}), encoding="utf-8")

    def requests(self):
        """The requested dialogs so far, in the order of the log: kind, args, scripted, pid, role, note (optional)."""
        path = self.dir / "requests.jsonl"
        if not path.exists():
            return []
        return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
