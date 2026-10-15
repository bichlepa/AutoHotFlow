"""Generates the element include blocks of the role entry scripts (E0041, WI-0047-PREP).

Every role includes only the element classes it needs. The selection is made by the literal `static Mode := "<inline|worker|trigger>"` of each
class file, which this tool reads as text (it does not run AutoHotkey). A class file without such a line, with
a Mode that is not a literal, or with a value other than inline, worker or trigger stops the generation with the
file name.

  python tools/gen_element_includes.py            write the blocks
  python tools/gen_element_includes.py --check    write nothing, exit 1 when a block is missing or out of date

A class file must not #Include another class file: the include runs the file-level code of that file too (the
Register line), so the class would land in every role that includes the first file (F-0081). Shared code of such
classes goes into a file without a Mode line (`src/elements/base/`, or next to the test elements in `tests/elements/`).

Classes (ROLE_MODES): supervisor, storage, debug and manager get no block (the manager loads all classes later if
it needs them); engine and editor get all classes, triggerhost the `trigger` classes, worker the `worker` classes.

Two sets of classes, each with its own output folder:
  product  src/elements/** without base/ and without Action_Test*.ahk  ->  src/entry/generated/Elements_<role>.ahk
  test     Action_Test*.ahk under src/elements/** and tests/elements/*.ahk
           ->  tests/integration/helpers/entry/generated/TestElements_<role>.ahk  (only the test entries include them)

The generated files are committed. tests/test_element_includes.py fails when they differ from this tool's output.
"""

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MODES = ("inline", "worker", "trigger")

# Roles with a block and the modes of the classes in it. Roles that are not listed get no block.
ROLE_MODES = {
    "engine": MODES,
    "editor": MODES,
    "triggerhost": ("trigger",),
    "worker": ("worker",),
}

PRODUCT_DIR = ROOT / "src" / "elements"
PRODUCT_OUT = ROOT / "src" / "entry" / "generated"
TEST_DIRS = (ROOT / "src" / "elements", ROOT / "tests" / "elements")
TEST_OUT = ROOT / "tests" / "integration" / "helpers" / "entry" / "generated"

_MODE_LINE = re.compile(r"^\s*static\s+Mode\s*:=", re.I)
_MODE_LITERAL = re.compile(r'^\s*static\s+Mode\s*:=\s*"([^"]*)"\s*(;.*)?$', re.I)
_INCLUDE = re.compile(r"^\s*#Include\s+(.+?)\s*$", re.I | re.M)


class GenError(Exception):
    """A class file that cannot be classified. The message starts with the file name."""


def read_mode(path):
    """The literal Mode of a class file, or GenError."""
    text = Path(path).read_text(encoding="utf-8")
    found = [line for line in text.splitlines() if _MODE_LINE.match(line)]
    name = Path(path).as_posix()
    if not found:
        raise GenError("%s: no `static Mode := \"...\"` line" % name)
    if len(found) > 1:
        raise GenError("%s: more than one `static Mode` line" % name)
    m = _MODE_LITERAL.match(found[0])
    if not m:
        raise GenError("%s: Mode is not a literal string: %s" % (name, found[0].strip()))
    if m.group(1) not in MODES:
        raise GenError("%s: Mode \"%s\" is not one of %s" % (name, m.group(1), ", ".join(MODES)))
    return m.group(1)


def check_includes(path):
    """GenError when the class file includes another class file (a file with a Mode line outside base/)."""
    path = Path(path)
    for m in _INCLUDE.finditer(path.read_text(encoding="utf-8")):
        target = re.split(r"\s+;", m.group(1))[0].strip()
        if not target or target[0] in "<*":
            continue
        other = (path.parent / target.replace("\\", "/")).resolve()
        if other.is_file() and other.parent.name != "base" and any(_MODE_LINE.match(line) for line in other.read_text(encoding="utf-8").splitlines()):
            raise GenError("%s: includes the class file %s; move the shared code into a file without a Mode line"
                           % (path.as_posix(), other.name))


def _is_test_class(path):
    return Path(path).name.lower().startswith("action_test")


def find_classes(kind):
    """Sorted list of class files of the set `kind` ("product" or "test")."""
    files = []
    if kind == "product":
        for p in PRODUCT_DIR.rglob("*.ahk"):
            if "base" in p.relative_to(PRODUCT_DIR).parts[:-1] or _is_test_class(p):
                continue
            files.append(p)
    else:
        for d in TEST_DIRS:
            for p in d.rglob("*.ahk"):
                if "base" in p.relative_to(d).parts[:-1] or not _is_test_class(p):
                    continue
                files.append(p)
    return sorted(files, key=lambda p: p.name.lower())


def block_text(kind, role, classes, out_dir):
    """Text of one generated block: the #Include lines of the classes whose Mode the role takes."""
    modes = ROLE_MODES[role]
    lines = ["#Requires AutoHotkey v2.0", "; GENERATED by tools/gen_element_includes.py (E0041). Do not edit.",
             "; Element classes of the %s set for the role %s, selected by their Mode (%s)."
             % (kind, role, ", ".join(modes))]
    for path, mode in classes:
        if mode in modes:
            lines.append("#Include %s" % os.path.relpath(path, out_dir).replace("/", "\\"))
    return "\n".join(lines) + "\n"


def generate():
    """Returns {output path: text} of all blocks. Raises GenError."""
    result = {}
    for kind, out_dir, prefix in (("product", PRODUCT_OUT, "Elements_"), ("test", TEST_OUT, "TestElements_")):
        for p in find_classes(kind):
            check_includes(p)
        classes = [(p, read_mode(p)) for p in find_classes(kind)]
        for role in ROLE_MODES:
            result[out_dir / (prefix + role + ".ahk")] = block_text(kind, role, classes, out_dir)
    return result


def classes_of(kind, role):
    """Class file names (without .ahk) that the block of `role` in the set `kind` includes."""
    modes = ROLE_MODES.get(role, ())
    return [p.stem for p in find_classes(kind) if read_mode(p) in modes]


def _shown(path):
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="write nothing, exit 1 when a block is out of date")
    args = ap.parse_args(argv)
    try:
        blocks = generate()
    except GenError as e:
        print("error: %s" % e, file=sys.stderr)
        return 1
    stale = []
    for path, text in blocks.items():
        current = path.read_bytes().decode("utf-8") if path.exists() else None
        if current == text:
            continue
        stale.append(path)
        if not args.check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(text.encode("utf-8"))
    for path in stale:
        print("%s %s" % ("out of date:" if args.check else "written:", _shown(path)))
    return 1 if (args.check and stale) else 0


if __name__ == "__main__":
    sys.exit(main())
