"""Builds flow files for tests (WI-0049): elements, connections, loops and settings in a few lines.

    fb = FlowBuilder("loop and condition", strict_types=True)
    trigger = fb.trigger()
    cond = fb.condition("Condition_Expression", Expression="x = 1")
    yes = fb.action("Action_Do_nothing")
    fb.chain(trigger, cond)
    fb.connect(cond, yes, "yes")
    text = fb.to_text()                  # the flow file (format of ARCHITECTURE section 7)

Loops (the parts of v1, `fromPart` and `toPart`):

    loop = fb.loop("Loop_SimpleLoop", repeatCount=3)
    fb.connect(before, loop)                      # into the head (default for a loop as target)
    fb.connect(loop, body, "head")                # out of the head
    fb.connect(body, loop, into="tail")           # end of the body, next round
    fb.connect(check, loop, "yes", into="break")  # leave the loop early
    fb.connect(loop, after, "tail")               # out of the tail, after the last round

A linear flow can also be written as text (see `FlowBuilder.linear`):

    fb.linear("Trigger_Manual -> Action_Sleep(Duration=10, Unit=Milliseconds) -> Condition_Expression(Expression='x = 1')"
              " yes-> Action_Do_nothing")

Format. `v2=True` (default) writes what the engine writes: root key `formatVersion` 2 and `flowSettings.strictTypes` as a
JSON boolean (a file with `formatVersion` is not converted, only elements marked with `v1Text` are). `v2=False` writes the
format of v1 without both keys (the engine converts the expression texts when it loads it, for conversion tests).
A class is written as `"Package.Class"` (the element then names that package, E0045) or plain: a plain test class
(`Action_Test*`) is in the package Test, any other in Default (tests/support/elements.py); the text form takes both.
Parameters keep their Python type (an int is written as a JSON number, a str as a JSON string). Parameters whose default
may be used are simply left out. IDs are `element<10 digits>` and `connection<10 digits>` from one counter, positions
are a column of 140 units per element.
"""

import json
import re
from pathlib import Path

from support.elements import split as split_class

KINDS = ("trigger", "action", "condition", "loop")
# v1 spelling of the element type (the loader compares case-insensitively; v2 files of the engine use lower case)
V1_KIND = {"trigger": "trigger", "action": "Action", "condition": "Condition", "loop": "Loop"}
PACKAGE_VERSION = "1.2.0"
RESULTS = ("normal", "yes", "no", "exception")
LOOP_PARTS = ("head", "tail", "break")
ROW_HEIGHT = 140
PROBE_CLASS = "Action_TestSetVar"


class El:
    """Handle of an element in a builder. str(el) is its ID."""

    def __init__(self, id_, cls, kind, name, package="Default"):
        self.id = id_
        self.cls = cls
        self.package = package
        self.kind = kind
        self.name = name

    def __str__(self):
        return self.id

    def __repr__(self):
        return "El(%s, %s)" % (self.id, self.cls)


def kind_of_class(cls):
    """'Trigger_Manual' -> 'trigger', 'Condition_Expression' -> 'condition' ... (the prefix of the class name)."""
    prefix = cls.split("_", 1)[0].lower()
    if prefix not in KINDS:
        raise ValueError("cannot tell the kind of element class '%s' (prefix Trigger_, Action_, Condition_ or Loop_)" % cls)
    return prefix


class FlowBuilder:
    def __init__(self, name="Test flow", category="Test", strict_types=True, v2=True, execution_policy="default",
                 flow_settings=None):
        """strict_types: the type mode of the flow (E0034); None leaves the key out (a migrated flow, loaded in the
        compatibility mode). Ignored with v2=False. flow_settings: further keys of `flowSettings`."""
        self.name = name
        self.category = category
        self.v2 = v2
        self.strict_types = strict_types
        self.settings = {"DefaultWorkingDir": 1, "ExecutionPolicy": execution_policy, "Offsetx": "0.000000",
                         "Offsety": "0.000000", "WorkingDir": "", "zoomFactor": "1.000000"}
        self.settings.update(flow_settings or {})
        self.elements = {}        # id -> element dict, in order of creation
        self.handles = {}         # id -> El
        self.connections = {}     # id -> connection dict
        self.probed = []          # names that probe() asked for, in order
        self._counter = 0

    # --- elements ----------------------------------------------------------------------------------------------
    def _next_id(self, prefix):
        self._counter += 1
        return "%s%010d" % (prefix, self._counter)

    def element(self, cls, kind=None, name=None, v1_text=False, extra=None, **pars):
        """Adds an element of class `cls` with the parameters `pars`. `cls` is `"Package.Class"` or a plain class: a
        test class (`Action_Test*`) is in the package Test, any other in Default (support/elements.py, E0045).
        `kind` comes from the class prefix.
        `name` is the display name (default: the class). `v1_text` marks the expression texts as v1 syntax in a v2 file.
        `extra` are further keys of the element (for example `HeightOfVerticalBar`). Returns the handle."""
        package, cls = split_class(cls)
        kind = kind or kind_of_class(cls)
        if kind not in KINDS:
            raise ValueError("unknown kind '%s'" % kind)
        id_ = self._next_id("element")
        row = len(self.elements)
        element = {
            "class": cls,
            "ID": id_,
            "name": name or cls,
            "package": package,
            "packageVersion": PACKAGE_VERSION,
            "pars": dict(pars),
            "StandardName": "0" if name else "1",
            "type": kind if self.v2 else V1_KIND[kind],
            "x": "0",
            "y": str(row * ROW_HEIGHT),
        }
        if kind == "trigger":
            element["enabled"] = "0"
            element["DefaultTrigger"] = "1" if not any(h.kind == "trigger" for h in self.handles.values()) else "0"
            element["pars"].setdefault("ID", name or self.name)
        if kind == "loop":
            element["HeightOfVerticalBar"] = "280"
        if v1_text:
            element["v1Text"] = True
        element.update(extra or {})
        self.elements[id_] = element
        handle = El(id_, cls, kind, element["name"], package)
        self.handles[id_] = handle
        return handle

    def trigger(self, cls="Trigger_Manual", **pars):
        return self.element(cls, "trigger", **pars)

    def action(self, cls, **pars):
        return self.element(cls, "action", **pars)

    def condition(self, cls, **pars):
        return self.element(cls, "condition", **pars)

    def loop(self, cls, **pars):
        return self.element(cls, "loop", **pars)

    def probe(self, *names, location=""):
        """Adds the test element that copies the variables `names` (any scope; instance and thread variables as seen
        at this place of the flow) into global variables, which FlowRunner reads from the data folder
        (FlowRun.probes). Returns the handle; connect it like any element. `location` ("thread" or "loop") is
        for built-in names with the prefix A_."""
        steps = [{"op": "probe", "name": n} for n in names]
        for n in names:
            if n not in self.probed:
                self.probed.append(n)
        return self.element(PROBE_CLASS, "action", name="Probe " + ", ".join(names), Steps=json.dumps(steps))

    # --- connections -------------------------------------------------------------------------------------------
    def connect(self, src, dst, result="normal", into=None):
        """Connects `src` to `dst`. `result`: normal, yes, no, exception; for a loop as source also head or tail (the
        part the connection leaves). `into`: for a loop as target the part it enters, head (default), tail or break.
        Returns the connection ID."""
        src_h = self._handle(src)
        dst_h = self._handle(dst)
        result = str(result).lower()
        conn = {"ConnectionType": "normal", "from": src_h.id, "ID": self._next_id("connection"), "to": dst_h.id,
                "type": "Connection"}
        if result in LOOP_PARTS and result != "break":
            if src_h.kind != "loop":
                raise ValueError("result '%s' is only for a loop as source, not for %s" % (result, src_h.cls))
            conn["fromPart"] = result.upper()
        elif result in RESULTS:
            conn["ConnectionType"] = result
        else:
            raise ValueError("unknown result '%s'" % result)
        if dst_h.kind == "loop":
            part = (into or "head").lower()
            if part not in LOOP_PARTS:
                raise ValueError("unknown loop part '%s'" % part)
            conn["toPart"] = part.upper()
        elif into is not None:
            raise ValueError("'into' is only for a loop as target, not for %s" % dst_h.cls)
        if not self.v2:
            conn["ConnectionType"] = {"normal": "normal", "yes": "Yes", "no": "No", "exception": "Exception"}[
                conn["ConnectionType"]]
        self.connections[conn["ID"]] = conn
        return conn["ID"]

    def chain(self, *items):
        """Connects the items in a row with the result `normal`. Returns the last one."""
        for a, b in zip(items, items[1:]):
            self.connect(a, b)
        return items[-1]

    def _handle(self, item):
        if isinstance(item, El):
            return item
        if item in self.handles:
            return self.handles[item]
        raise KeyError("no element '%s' in this flow" % (item,))

    # --- text form -----------------------------------------------------------------------------------------------
    def linear(self, text):
        """Adds the elements of a linear flow written as text and connects them. Returns the handles in order.

        `Class(par=value, par="text, with comma") -> Class2 yes-> Class3 exception-> Class4`
        An arrow with a result word in front of it (`yes->`, `no->`, `exception->`) sets the result of the connection
        that leaves the element on its left; a plain `->` is `normal`. A value is a text; give it in single or double
        quotes if it contains a comma, a parenthesis or spaces at the ends. A value that is a whole number or a
        decimal number without quotes is written as a JSON number. A loop is not part of the text form."""
        out = []
        pending = "normal"
        for kind, value in _tokens(text):
            if kind == "arrow":
                pending = value
                continue
            handle = self.element(value[0], **value[1])
            if out:
                self.connect(out[-1], handle, pending)
            out.append(handle)
            pending = "normal"
        return out

    # --- output ------------------------------------------------------------------------------------------------
    def to_dict(self):
        root = {"name": self.name, "category": self.category, "ElementIDCounter": str(self._counter)}
        settings = dict(self.settings)
        if self.v2:
            root["formatVersion"] = 2
            if self.strict_types is not None:
                settings["strictTypes"] = bool(self.strict_types)
        root["flowSettings"] = settings
        root["allElements"] = {k: dict(v) for k, v in self.elements.items()}
        root["allConnections"] = {k: dict(v) for k, v in self.connections.items()}
        return root

    def to_text(self):
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)

    def write(self, datadir, flow_id=None):
        """Writes Flows/<flow_id>.json below the data folder (UTF-8, no BOM). The flow ID is the file name without
        extension, default the name of the flow. Returns the flow ID."""
        flow_id = flow_id or self.name
        path = Path(datadir) / "Flows" / (flow_id + ".json")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(self.to_text(), encoding="utf-8", newline="\r\n")
        return flow_id


# --- the text form: tokenizer ----------------------------------------------------------------------------------------
_ARROW = re.compile(r"\s*(?:(normal|yes|no|exception)\s*)?->\s*", re.IGNORECASE)
_CLASS = re.compile(r"\s*([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)?)")
_NUMBER = re.compile(r"-?\d+(?:\.\d+)?$")


def _tokens(text):
    """Yields ('element', (class, {pars})) and ('arrow', result) in the order of the text."""
    pos = 0
    n = len(text)
    expect_element = True
    while pos < n:
        if expect_element:
            m = _CLASS.match(text, pos)
            if not m:
                raise ValueError("flow text: class name expected at %d: %r" % (pos, text[pos:pos + 20]))
            cls = m.group(1)
            pos = m.end()
            pars = {}
            if pos < n and text[pos] == "(":
                pars, pos = _parameters(text, pos + 1)
            yield "element", (cls, pars)
            expect_element = False
            while pos < n and text[pos].isspace():
                pos += 1
        else:
            m = _ARROW.match(text, pos)
            if not m:
                raise ValueError("flow text: '->' expected at %d: %r" % (pos, text[pos:pos + 20]))
            yield "arrow", (m.group(1) or "normal").lower()
            pos = m.end()
            expect_element = True
    if expect_element and n:
        raise ValueError("flow text: element expected after the last arrow")


def _parameters(text, pos):
    pars = {}
    n = len(text)
    while True:
        while pos < n and text[pos] in " \t":
            pos += 1
        if pos < n and text[pos] == ")":
            return pars, pos + 1
        m = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*").match(text, pos)
        if not m:
            raise ValueError("flow text: parameter name expected at %d: %r" % (pos, text[pos:pos + 20]))
        key = m.group(1)
        pos = m.end()
        if pos < n and text[pos] in "\"'":
            quote = text[pos]
            end = text.find(quote, pos + 1)
            if end < 0:
                raise ValueError("flow text: unterminated quote at %d" % pos)
            pars[key] = text[pos + 1:end]
            pos = end + 1
        else:
            start = pos
            while pos < n and text[pos] not in ",)":
                pos += 1
            raw = text[start:pos].strip()
            pars[key] = (float(raw) if "." in raw else int(raw)) if _NUMBER.match(raw) else raw
        while pos < n and text[pos] in " \t":
            pos += 1
        if pos < n and text[pos] == ",":
            pos += 1
        elif pos < n and text[pos] == ")":
            return pars, pos + 1
        else:
            raise ValueError("flow text: ',' or ')' expected at %d" % pos)
