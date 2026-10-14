#!/usr/bin/env python
"""Requirements index: checks doc/REQUIREMENTS.md and generates doc/REQUIREMENTS-INDEX.md from it.

doc/REQUIREMENTS.md is the source. Every requirement is a heading with a fixed list of metadata below it
(the format is described at the top of that file):

    ## Flows and execution (EXE)

    ### REQ-EXE-010 Execution policy per flow

    - **v1:** partial (`wait` behaves like `parallel`, M-11)
    - **v2:** done
    - **Prio:** must
    - **Scope:** port
    - **Plan:** -
    - **Evidence:** `tests/e2e/test_policies.py`

    Free text, tables, lists ...

The index is a summary plus one table per area, with links to the sections. It is never edited by hand.

Usage:  python tools/req_index.py            check the source and write the index (exit 1 on format errors)
        python tools/req_index.py --check    check the source and that the index is up to date (exit 1 if not)
"""

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "doc" / "REQUIREMENTS.md"
INDEX = REPO / "doc" / "REQUIREMENTS-INDEX.md"

AREA = re.compile(r"^## (?P<title>.+?) \((?P<code>[A-Z]{2,4})\)\s*$")
OTHER_H2 = re.compile(r"^## ")
REQ = re.compile(r"^### (?P<id>REQ-(?P<code>[A-Z]{2,4})-(?P<num>\d{3})) (?P<title>\S.*?)\s*$")
REQ_LIKE = re.compile(r"^#{1,6} +REQ-")
FENCE = re.compile(r"^\s*(```+|~~~+)")
META = re.compile(r"^- \*\*(?P<key>[^*]+):\*\* *(?P<value>.*?)\s*$")

# Allowed first word of each status field; the rest of the value is free text (a reason, a reference).
VOCAB = {
    "v1": ("yes", "partial", "no", "n/a"),
    "v2": ("done", "implemented", "partial", "open", "dropped"),
    "Prio": ("must", "should", "could"),
    "Scope": ("port", "later"),
}
REQUIRED = ("v1", "v2", "Prio", "Scope", "Plan")
KEYS = REQUIRED + ("Evidence",)
V2_ORDER = VOCAB["v2"]


@dataclass
class Requirement:
    id: str
    title: str
    line: int
    area: "Area"
    meta: dict = field(default_factory=dict)

    def word(self, key):
        """First word of a status field ("partial (M-11)" -> "partial")."""
        return self.meta.get(key, "").split(" ", 1)[0]


@dataclass
class Area:
    title: str
    code: str
    line: int
    reqs: list = field(default_factory=list)

    @property
    def heading(self):
        return "%s (%s)" % (self.title, self.code)


def slug(heading):
    """Anchor of a heading as GitHub and the VS Code preview make it: lower case, punctuation dropped, spaces to '-'."""
    return re.sub(r"[^\w\- ]", "", heading.strip().lower()).replace(" ", "-")


def parse(text):
    """(areas, errors). errors are 'line N: message' strings."""
    areas, errors, ids = [], [], {}
    area = None
    # fenced code blocks (format examples) are blanked out; the line numbers stay the same
    lines, fence = [], None
    for line in text.splitlines():
        m = FENCE.match(line)
        if fence is None and m:
            fence = m[1]
        elif fence is not None and line.strip().startswith(fence):
            fence = None
        else:
            lines.append("" if fence is not None else line)
            continue
        lines.append("")
    i = 0
    while i < len(lines):
        line = lines[i]
        m = AREA.match(line)
        if m:
            area = Area(m["title"], m["code"], i + 1)
            if any(a.code == area.code for a in areas):
                errors.append("line %d: area code %s used twice" % (i + 1, area.code))
            areas.append(area)
            i += 1
            continue
        if OTHER_H2.match(line):
            area = None
            i += 1
            continue
        m = REQ.match(line)
        if not m:
            if REQ_LIKE.match(line):
                errors.append("line %d: requirement heading must be '### REQ-XXX-nnn Title': %s" % (i + 1, line))
            i += 1
            continue
        if area is None:
            errors.append("line %d: %s is not inside an area ('## Title (CODE)')" % (i + 1, m["id"]))
            i += 1
            continue
        req = Requirement(m["id"], m["title"], i + 1, area)
        if m["code"] != area.code:
            errors.append("line %d: %s is in area %s, its code must be %s" % (i + 1, req.id, area.heading, area.code))
        if req.id in ids:
            errors.append("line %d: %s used twice (first in line %d)" % (i + 1, req.id, ids[req.id]))
        ids[req.id] = i + 1
        area.reqs.append(req)
        # the metadata list follows the heading, blank lines in between are allowed
        i += 1
        while i < len(lines) and not lines[i].strip():
            i += 1
        while i < len(lines):
            mm = META.match(lines[i])
            if not mm:
                break
            key, value = mm["key"], mm["value"]
            if key not in KEYS:
                errors.append("line %d: %s: unknown field '%s' (allowed: %s)" % (i + 1, req.id, key, ", ".join(KEYS)))
            elif key in req.meta:
                errors.append("line %d: %s: field '%s' twice" % (i + 1, req.id, key))
            else:
                req.meta[key] = value
            i += 1
        errors.extend("line %d: %s" % (req.line, e) for e in check_req(req))
    return areas, errors


def check_req(req):
    errors = []
    for key in REQUIRED:
        if not req.meta.get(key):
            errors.append("%s: field '%s' missing or empty" % (req.id, key))
    for key, words in VOCAB.items():
        if req.meta.get(key) and req.word(key) not in words:
            errors.append("%s: %s must start with one of %s, not '%s'" % (req.id, key, "/".join(words), req.word(key)))
    if req.word("v2") == "done" and not req.meta.get("Evidence"):
        errors.append("%s: v2 'done' needs an Evidence field (test or measurement)" % req.id)
    return errors


def cell(text):
    return text.replace("|", "\\|")


def render(areas, source_name=SOURCE.name):
    out = [
        "# Requirements index",
        "",
        "Generated by `python tools/req_index.py` from [%s](%s). **Do not edit by hand**: change the source and" % (source_name, source_name),
        "run the tool. The legend of the columns is at the top of the source.",
        "",
        "## Summary",
        "",
        "| Area | Total | " + " | ".join(V2_ORDER) + " |",
        "|---|---:|" + "---:|" * len(V2_ORDER),
    ]
    totals = [0] * (len(V2_ORDER) + 1)
    for a in areas:
        counts = [len(a.reqs)] + [sum(1 for r in a.reqs if r.word("v2") == w) for w in V2_ORDER]
        totals = [t + c for t, c in zip(totals, counts)]
        out.append("| [%s](#%s) | %s |" % (cell(a.heading), slug(a.heading), " | ".join(str(c) for c in counts)))
    out.append("| **All** | " + " | ".join("**%d**" % t for t in totals) + " |")
    for a in areas:
        out += ["", "## " + a.heading, ""]
        if not a.reqs:
            out.append("No requirements yet.")
            continue
        out += ["| ID | Requirement | v1 | v2 | Prio | Scope | Plan |", "|---|---|---|---|---|---|---|"]
        for r in a.reqs:
            link = "[%s](%s#%s)" % (r.id, source_name, slug("%s %s" % (r.id, r.title)))
            out.append("| %s | %s | %s | %s | %s | %s | %s |" % (
                link, cell(r.title), r.word("v1"), r.word("v2"), r.word("Prio"), r.word("Scope"), cell(r.meta.get("Plan", ""))))
    return "\n".join(out) + "\n"


def run(source=SOURCE, index=INDEX, check=False, out=sys.stdout):
    """0 when fine, 1 on format errors or (with check) an outdated index."""
    areas, errors = parse(source.read_text(encoding="utf-8"))
    for e in errors:
        print("%s: %s" % (source.name, e), file=out)
    if errors:
        return 1
    text = render(areas)
    current = index.read_text(encoding="utf-8") if index.exists() else None
    # line ends depend on the git checkout; compare the content only
    up_to_date = current is not None and current.replace("\r\n", "\n") == text
    if check:
        if not up_to_date:
            print("%s is out of date: run python tools/req_index.py" % index.name, file=out)
            return 1
        return 0
    if not up_to_date:
        with open(index, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    n = sum(len(a.reqs) for a in areas)
    print("%s: %d requirements in %d areas, %s" % (index.name, n, len(areas), "written" if not up_to_date else "unchanged"), file=out)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="only check; exit 1 if the index is out of date")
    ap.add_argument("--source", type=Path, default=SOURCE)
    ap.add_argument("--index", type=Path, default=INDEX)
    args = ap.parse_args(argv)
    return run(args.source, args.index, args.check)


if __name__ == "__main__":
    sys.exit(main())
