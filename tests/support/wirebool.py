"""Strict check for boolean fields on the wire (WI-26, doc/PROTOKOLL.md section 2).

AHK writes truth values as JSON true/false. Python decodes them to bool, so a field that falls back
to 1/0 shows up as int. `is_bool` is the strict test for one value; every frame the Python test
peers decode goes through `record`, which notes protocol fields that are not bool. The autouse
fixture in tests/conftest.py fails the test that received such a frame.
"""

import threading

# Payload fields that are truth values by the protocol (any depth, matched by key name).
BOOL_FIELDS = frozenset({
    "ok", "cancel", "started", "clean", "restart", "enabled", "executing", "exists", "existed",
    "waiting", "byMeta", "delete",
})

# Payload fields that carry user data (flow definitions, element parameters, variable values). Their content
# keeps its own format (E8: flow files do not change, "enabled": "0" is an element parameter), so the
# check does not look inside.
OPAQUE_FIELDS = frozenset({"definition", "params", "imports", "exports", "settings", "content", "env"})

_lock = threading.Lock()
_violations = []


def is_bool(value):
    """True only for a real bool (an int 0 or 1 is not accepted)."""
    return type(value) is bool


def assert_bool(value, expected, what="value"):
    """Fails unless value is exactly the bool `expected`."""
    assert is_bool(value), "%s is %r (%s), expected a JSON boolean" % (what, value, type(value).__name__)
    assert value is expected, "%s is %r, expected %r" % (what, value, expected)


def find_violations(node, path="payload"):
    """Paths of BOOL_FIELDS entries in node (dict/list tree) that are not real booleans."""
    found = []
    if isinstance(node, dict):
        for key, value in node.items():
            here = path + "." + key
            if key in OPAQUE_FIELDS:
                continue
            if key in BOOL_FIELDS and not isinstance(value, (dict, list)) and not is_bool(value):
                found.append("%s = %r" % (here, value))
            else:
                found.extend(find_violations(value, here))
    elif isinstance(node, list):
        for i, item in enumerate(node):
            found.extend(find_violations(item, "%s[%d]" % (path, i)))
    return found


def record(envelope):
    """Notes the violations of one decoded envelope (called by FrameDecoder)."""
    if not isinstance(envelope, dict):
        return
    for item in find_violations(envelope.get("payload")):
        with _lock:
            _violations.append("%s %s %s" % (envelope.get("from"), envelope.get("type"), item))


def take_violations():
    """Returns and clears the recorded violations."""
    with _lock:
        out = list(_violations)
        _violations.clear()
    return out
