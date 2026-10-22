"""Script and log of the system provider of the test entries (WI-0117, E0103).

The provider (tests/integration/helpers/TestSystemProvider.ahk) answers the calls of SystemOps from
<data folder>/TestSystem/script.json and logs every call to requests.jsonl in the same folder. The worker and the trigger
host of a session share the files, so a test needs no message route. No real function runs in a test.

    system = SystemScript(flows.datadir)
    system.script({"Shutdown": [{"value": 1}], "SpeakText": [{"error": "no voice"}]}, idle_base_ms=5000)
    ...run the flow...
    assert system.requests()[0]["function"] == "Shutdown"
"""

import json


def value(answer_value):
    """An entry that answers the call with a value (the return value of the function)."""
    return {"value": answer_value}


def error(text):
    """An entry for a call that fails: the element ends with "exception" and the text in its message."""
    return {"error": text}


class SystemScript:
    def __init__(self, datadir):
        self.dir = datadir / "TestSystem"

    def script(self, answers=None, idle_base_ms=None):
        """Writes the script (replaces the previous one). answers maps a function name to its entries, used in order.
        idle_base_ms: TimeIdle and TimeIdlePhysical answer this plus the time since the provider started."""
        self.dir.mkdir(parents=True, exist_ok=True)
        data = {"answers": answers or {}}
        if idle_base_ms is not None:
            data["idleBaseMs"] = idle_base_ms
        (self.dir / "script.json").write_text(json.dumps(data), encoding="utf-8")

    def requests(self):
        """The calls so far, in the order of the log: function, args, scripted, answer or error, element, flow, pid, role."""
        path = self.dir / "requests.jsonl"
        if not path.exists():
            return []
        return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
