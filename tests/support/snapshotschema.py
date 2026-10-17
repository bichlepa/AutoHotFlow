"""Schema of cmd.diag.snapshot (doc/PROTOCOL.md 4.9, WI-0028) as a checker for the tests.

check_snapshot(snapshot, role) raises AssertionError with the path of the first wrong field. The general part
is the same for every role (Role.Snapshot); the role part `info` differs (Role.DiagInfo). The supervisor has
its own shape (no peer, no info).
"""

import json

GENERAL = {
    "schema": int, "name": str, "role": str, "pid": int, "startedAt": str, "uptimeMs": int,
    "version": str, "ahkVersion": str, "bits": int, "rssBytes": int, "handles": int,
    "log": dict, "errors": dict,
}
PEER = {"status": str, "pending": int, "lateReplies": int, "badFrames": int, "droppedSends": int,
        "queuedFrames": int, "queuedBytes": int, "handlerErrors": int}
LOG = {"queued": int, "dropped": int, "sinkErrors": int, "lastSinkError": str, "level": int, "recent": list}
LOG_ENTRY = {"ts": str, "level": str, "source": str, "text": str}
ERRORS = {"count": int, "recent": list}
ERROR_ENTRY = {"ts": str, "errorType": str, "message": str, "file": str, "line": int, "stack": str, "mode": str}

INFO = {
    "engine": {"epoch": int, "seq": int, "flows": list, "instances": list, "workers": dict},
    "storage": {"queue": dict, "logQueuedEntries": int, "logQueuedChars": int, "logLinesLost": int,
                "logLinesDropped": int},
    "worker": {"job": (str, dict)},
    "manager": {"topics": list, "engine": str, "epoch": int, "lastSeq": int, "flows": int, "events": int, "resyncs": int,
                "selectedFlow": str, "windowVisible": int, "redrawTimer": int, "headless": int},
    "debug": {"topics": list, "processes": list, "snapshots": list, "logEntries": int, "engineEvents": int,
              "dumps": list, "paused": bool},
    "tray": {"iconHidden": bool, "tip": str, "items": list, "requests": int, "lastResult": str},
    "echo": {},
}
SUPERVISOR = {"hub": dict, "children": list, "diagErrors": list, "diagLog": dict, "processEvents": list,
              "reports": dict}


def _check_fields(obj, spec, where):
    assert isinstance(obj, dict), "%s is %r, expected an object" % (where, type(obj).__name__)
    for key, kind in spec.items():
        assert key in obj, "%s.%s is missing (has %s)" % (where, key, sorted(obj))
        value = obj[key]
        if kind is int:
            assert isinstance(value, int) and not isinstance(value, bool), "%s.%s = %r, expected an integer" % (where, key, value)
        elif kind is bool:
            assert isinstance(value, bool), "%s.%s = %r, expected a boolean" % (where, key, value)
        else:
            assert isinstance(value, kind), "%s.%s = %r, expected %s" % (where, key, value, kind)


def check_snapshot(snap, role):
    """Checks the snapshot of a role (`role` = base name: engine, storage, worker, manager, debug, echo, supervisor)."""
    _check_fields(snap, GENERAL, "snapshot")
    assert snap["schema"] == 1
    assert snap["role"] == role, (snap["role"], role)
    assert snap["bits"] == 64
    assert snap["pid"] > 0 and snap["rssBytes"] > 0 and snap["handles"] > 0 and snap["uptimeMs"] >= 0
    assert snap["ahkVersion"].startswith("2."), snap["ahkVersion"]
    _check_fields(snap["log"], LOG, "snapshot.log")
    for i, entry in enumerate(snap["log"]["recent"]):
        _check_fields(entry, LOG_ENTRY, "snapshot.log.recent[%d]" % i)
    assert len(snap["log"]["recent"]) <= 100
    _check_fields(snap["errors"], ERRORS, "snapshot.errors")
    for i, entry in enumerate(snap["errors"]["recent"]):
        _check_fields(entry, ERROR_ENTRY, "snapshot.errors.recent[%d]" % i)
    assert len(snap["errors"]["recent"]) <= 20
    if role == "supervisor":
        _check_fields(snap, SUPERVISOR, "snapshot")
        assert "peer" not in snap
        for i, child in enumerate(snap["children"]):
            _check_fields(child, {"name": str, "role": str, "state": str, "pid": int, "restarts": int,
                                  "startedAt": str, "output": list}, "snapshot.children[%d]" % i)
        _check_fields(snap["hub"], {"links": list, "droppedAnswers": int, "pending": int, "routedOpen": int,
                                    "goneAnswers": int}, "snapshot.hub")
        for i, link in enumerate(snap["hub"]["links"]):
            _check_fields(link, {"name": str, "pid": int, "queuedFrames": int, "queuedBytes": int, "topics": list},
                          "snapshot.hub.links[%d]" % i)
        _check_fields(snap["reports"], {"written": int, "unwritten": int, "autoSuppressed": int}, "snapshot.reports")
        return
    _check_fields(snap, {"peer": dict, "info": dict}, "snapshot")
    _check_fields(snap["peer"], PEER, "snapshot.peer")
    assert snap["info"].get("error") is None, "role part failed: %s" % snap["info"].get("error")
    _check_fields(snap["info"], INFO[role], "snapshot.info")
    if role == "engine":
        _check_fields(snap["info"]["workers"], {"size": int, "warm": int, "slots": list, "spawning": int, "failures": int},
                      "snapshot.info.workers")
        for i, flow in enumerate(snap["info"]["flows"]):
            _check_fields(flow, {"flowId": str, "name": str, "rev": int, "enabled": bool, "executing": bool},
                          "snapshot.info.flows[%d]" % i)
        for i, inst in enumerate(snap["info"]["instances"]):
            _check_fields(inst, {"instanceId": str, "flowId": str, "state": str, "threads": list},
                          "snapshot.info.instances[%d]" % i)
            for j, thread in enumerate(inst["threads"]):
                _check_fields(thread, {"threadId": str, "elementId": str, "state": str, "result": str},
                              "snapshot.info.instances[%d].threads[%d]" % (i, j))
    if role == "storage":
        _check_fields(snap["info"]["queue"], {"requests": int, "log": int}, "snapshot.info.queue")


def dump(snap):
    """The snapshot as one JSON text (for searches, e.g. 'no contents')."""
    return json.dumps(snap, ensure_ascii=False)
