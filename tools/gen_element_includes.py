"""Generates the include blocks of the element packages per role (E0037, E0041, E0045, WI-0047).

An element package is a folder with a package description and its element files:

  <package>/package.json            name (equal to the folder name) and version, as the manifest of v1
  <package>/Actions/Action_*.ahk    one element class per file; also Conditions/Condition_*, Loops/Loop_*,
                                    Triggers/Trigger_*
  <package>/lib/*.ahk               shared code of the classes (no element class, no Mode line)
  <package>/language/<code>.ini     the texts of the package (Lang, core/LangTable.ahk)
  <package>/Icons/                  the icons (static Icon of a class)

Each package is an AutoHotkey class whose body includes the element files of the package. The type name of an element
is therefore its qualified ID, `<package>.<class>` (`Default.Action_Sleep`), which the registry, the worker jobs and
the logs use (E0045). The generator writes, per package and per role, the block `<package>/_includes_<role>.ahk`:

  1. the base files (AhfElement, ElementRegistry) and every file that the selected class files include, at file level
     (an #Include inside a class body would make the included file part of the class; AutoHotkey includes a file
     only once, so the #Include lines of the class files inside the body are then skipped);
  2. `class <package> { #Include <class file> ... }` with the class files whose Mode the role takes;
  3. `ElementRegistry.RegisterPackage(name, version)` and `ElementRegistry.Register(<package>.<class>)` per class.

and per role one block that includes the blocks of all packages of a set:

  product  src/elements/<package>/          ->  src/entry/generated/Elements_<role>.ahk
  test     tests/elements/<package>/        ->  tests/integration/helpers/entry/generated/TestElements_<role>.ahk
           (only the test entries include them)

  python tools/gen_element_includes.py            write the blocks (and delete generated blocks that are not needed)
  python tools/gen_element_includes.py --check    write nothing, exit 1 when a block is missing, stale or superfluous

The selection is made by the literal `static Mode := "<inline|worker|trigger>"` of each class file, which this tool
reads as text (it does not run AutoHotkey). Roles (ROLE_MODES): supervisor, storage, debug and manager get no block
(the manager loads all classes later if it needs them); engine and editor get all classes, triggerhost the `trigger`
classes, worker the `worker` classes.

The generation stops with the file name when a class file cannot be used: no literal Mode, not exactly one top-level
class named as the file, a class whose prefix does not fit its folder, an `ElementRegistry.Register` line (the block
registers), a reference to its own class name (a nested class has no global name: use `this` in its static methods),
an #Include of another class file (F-0081) or of a file that does not exist, a test class (`Action_Test*`) in the
product set, or a package name that is not a safe AutoHotkey class name (see `check_package_name`).

The generated files are committed. tests/test_element_includes.py fails when they differ from this tool's output.
"""

import argparse
import json
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

# Folder of a class file in a package and the prefix of its class name (the v1 layout).
KIND_FOLDERS = {"Actions": "Action_", "Conditions": "Condition_", "Loops": "Loop_", "Triggers": "Trigger_"}
LIB_FOLDER = "lib"
DESCRIPTION = "package.json"
BLOCK_PREFIX = "_includes_"

BASE_DIR = ROOT / "src" / "elements" / "base"
BASE_FILES = ("AhfElement.ahk", "ElementRegistry.ahk")

PRODUCT_DIR = ROOT / "src" / "elements"
PRODUCT_OUT = ROOT / "src" / "entry" / "generated"
TEST_DIR = ROOT / "tests" / "elements"
TEST_OUT = ROOT / "tests" / "integration" / "helpers" / "entry" / "generated"
# Where global AutoHotkey names of the code base are declared (a package class must not collide with them).
NAME_SOURCES = (ROOT / "src", ROOT / "tests", ROOT / "tools")

# A package name becomes the name of a global AutoHotkey class (E0045). It must not be a reserved word or a built-in
# name; this list is checked in addition to the global names of the code base.
RESERVED_NAMES = {
    "and", "as", "break", "case", "catch", "class", "contains", "continue", "else", "false", "finally", "for",
    "global", "goto", "if", "in", "is", "isset", "local", "loop", "not", "or", "return", "static", "super", "switch",
    "this", "throw", "true", "try", "unset", "until", "while",
    "any", "object", "primitive", "number", "integer", "float", "string", "array", "map", "buffer", "clipboardall",
    "func", "boundfunc", "closure", "enumerator", "file", "gui", "inputhook", "menu", "menubar", "regexmatchinfo",
    "varref", "comobject", "comobjarray", "comvalue", "comvalueref", "error", "memoryerror", "oserror",
    "targeterror", "timeouterror", "typeerror", "valueerror", "zerodivisionerror", "membererror", "propertyerror",
    "methoderror", "unseterror", "unsetitemerror", "indexerror", "keyerror",
}
PACKAGE_NAME = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,63}$")

_MODE_LINE = re.compile(r"^\s*static\s+Mode\s*:=", re.I)
_MODE_LITERAL = re.compile(r'^\s*static\s+Mode\s*:=\s*"([^"]*)"\s*(;.*)?$', re.I)
_INCLUDE = re.compile(r"^\s*#Include(?:Again)?\s+(.+?)\s*$", re.I | re.M)
_TOP_CLASS = re.compile(r"^class\s+(\w+)", re.I | re.M)
_REGISTER = re.compile(r"^\s*ElementRegistry\.Register\s*\(", re.I | re.M)
_GLOBAL_CLASS = re.compile(r"^class\s+(\w+)", re.I | re.M)
_GLOBAL_FUNC = re.compile(r"^(\w+)\([^)\n]*\)\s*(?:\{|=>|$)", re.M)


class GenError(Exception):
    """A class file or package that cannot be used. The message starts with the file name."""


def _shown(path):
    try:
        return Path(path).resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return Path(path).as_posix()


def _code(text):
    """The text without comments (a `;` at the start of a line or after whitespace) and without string contents,
    so that a name in a comment or a text is not taken for code. Rough, like tools/arch_check.py."""
    out = []
    for line in text.splitlines():
        line = re.sub(r'"[^"\n]*"|\'[^\'\n]*\'', '""', line)
        m = re.search(r"(^|\s);", line)
        out.append(line[:m.start()] if m else line)
    return "\n".join(out)


def read_mode(path):
    """The literal Mode of a class file, or GenError."""
    text = Path(path).read_text(encoding="utf-8")
    found = [line for line in text.splitlines() if _MODE_LINE.match(line)]
    name = _shown(path)
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


def includes_of(path):
    """The files that the file includes, resolved (in order). GenError for an include that cannot be resolved."""
    path = Path(path)
    out = []
    code = _code(path.read_text(encoding="utf-8"))
    if re.search(r"^\s*#IncludeAgain\b", code, re.I | re.M):
        raise GenError("%s: #IncludeAgain is not allowed in an element file (the file would be included again inside "
                       "the package class)" % _shown(path))
    for m in _INCLUDE.finditer(code):
        target = m.group(1).strip()
        if not target or target[0] in "<*" or "%" in target:
            raise GenError("%s: #Include %s: only a plain relative path is supported in an element file"
                           % (_shown(path), target))
        other = (path.parent / target.replace("\\", "/")).resolve()
        if not other.is_file():
            raise GenError("%s: #Include %s: the file does not exist" % (_shown(path), target))
        out.append(other)
    return out


def _has_mode_line(path):
    return any(_MODE_LINE.match(line) for line in Path(path).read_text(encoding="utf-8").splitlines())


def check_class_file(path, kind_folder):
    """Checks a class file (see the head of this file). Returns (class name, mode, included files)."""
    path = Path(path)
    name = _shown(path)
    mode = read_mode(path)
    code = _code(path.read_text(encoding="utf-8"))
    found = list(_TOP_CLASS.finditer(code))
    classes = [m.group(1) for m in found]
    if len(classes) != 1 or classes[0] != path.stem:
        raise GenError("%s: the file must hold exactly one top-level class named %s (found: %s)"
                       % (name, path.stem, ", ".join(classes) or "none"))
    cls = classes[0]
    prefix = KIND_FOLDERS[kind_folder]
    if not cls.lower().startswith(prefix.lower()):
        raise GenError("%s: a class in %s/ must start with %s" % (name, kind_folder, prefix))
    if _REGISTER.search(code):
        raise GenError("%s: remove the ElementRegistry.Register line; the generated block of the package registers "
                       "the class" % name)
    body = code[found[0].end():]
    if re.search(r"(?<![\w.])" + re.escape(cls) + r"\s*\.", body, re.I):
        raise GenError("%s: refers to its own class name %s; a nested class has no global name, use `this` in its "
                       "static methods" % (name, cls))
    incs = includes_of(path)
    for other in incs:
        if other.parent != BASE_DIR and _has_mode_line(other):
            raise GenError("%s: includes the class file %s; move the shared code into a file without a Mode line "
                           "(lib/ of the package)" % (name, other.name))
    return cls, mode, incs


def global_names():
    """Lower-case names of the global classes and functions declared in the code base (column 0), without the
    generated blocks (they declare the package classes)."""
    found = set()
    for folder in NAME_SOURCES:
        for path in folder.rglob("*.ahk"):
            if path.name.lower().startswith(BLOCK_PREFIX):
                continue
            try:
                code = _code(path.read_text(encoding="utf-8-sig", errors="replace"))
            except OSError:
                continue
            found.update(n.lower() for n in _GLOBAL_CLASS.findall(code))
            found.update(n.lower() for n in _GLOBAL_FUNC.findall(code)
                         if n.lower() not in {"if", "while", "for", "loop", "switch", "return", "catch"})
    return found


def check_package_name(name, where, names):
    """GenError unless `name` can be the name of a global AutoHotkey class (E0045): an ASCII identifier of at most 64
    characters that starts with a letter, not a reserved word or a built-in class name, not starting with `Ahf` (the
    prefix of the own classes) and not the name of a global class or function of the code base (`names`)."""
    if not PACKAGE_NAME.match(name):
        raise GenError("%s: package name '%s' is not an AutoHotkey class name (letters, digits and _, starting with "
                       "a letter, at most 64 characters)" % (where, name))
    low = name.lower()
    if low in RESERVED_NAMES:
        raise GenError("%s: package name '%s' is a reserved word or a built-in name of AutoHotkey" % (where, name))
    if low.startswith("ahf"):
        raise GenError("%s: package name '%s' starts with Ahf, the prefix of the classes of AutoHotFlow itself"
                       % (where, name))
    if low in names:
        raise GenError("%s: package name '%s' is the name of a global class or function of the code" % (where, name))


class Package:
    def __init__(self, folder):
        self.folder = Path(folder)
        desc = self.folder / DESCRIPTION
        where = _shown(desc)
        if not desc.is_file():
            raise GenError("%s: the package description is missing" % where)
        try:
            data = json.loads(desc.read_text(encoding="utf-8"))
        except ValueError as e:
            raise GenError("%s: not valid JSON: %s" % (where, e))
        self.name = data.get("name") if isinstance(data, dict) else None
        self.version = data.get("version") if isinstance(data, dict) else None
        if not isinstance(self.name, str) or self.name != self.folder.name:
            raise GenError("%s: \"name\" must be the name of the folder (%s)" % (where, self.folder.name))
        if not isinstance(self.version, str) or not self.version.strip():
            raise GenError("%s: \"version\" is missing" % where)
        self.classes = []        # (path, class name, mode, included files), sorted by class name
        for path in sorted(self.folder.rglob("*.ahk"), key=lambda p: p.as_posix().lower()):
            rel = path.relative_to(self.folder)
            if len(rel.parts) == 1 and rel.name.lower().startswith(BLOCK_PREFIX):
                continue                                   # a generated block
            if rel.parts[0] == LIB_FOLDER:
                continue                                   # shared code
            if len(rel.parts) != 2 or rel.parts[0] not in KIND_FOLDERS:
                raise GenError("%s: an element file belongs in %s/ (shared code in %s/)"
                               % (_shown(path), "/, ".join(KIND_FOLDERS), LIB_FOLDER))
            cls, mode, incs = check_class_file(path, rel.parts[0])
            self.classes.append((path, cls, mode, incs))
        self.classes.sort(key=lambda c: c[1].lower())

    def block_path(self, role):
        return self.folder / (BLOCK_PREFIX + role + ".ahk")

    def block_text(self, role):
        """The block of the package for the role."""
        modes = ROLE_MODES[role]
        chosen = [c for c in self.classes if c[2] in modes]
        rel = lambda p: os.path.relpath(p, self.folder).replace("/", "\\")
        hoisted = [BASE_DIR / f for f in BASE_FILES]
        for _path, _cls, _mode, incs in chosen:
            for inc in incs:
                if inc not in hoisted:
                    hoisted.append(inc)
        lines = ["#Requires AutoHotkey v2.0",
                 "; GENERATED by tools/gen_element_includes.py (E0037, E0041, E0045). Do not edit.",
                 "; Package %s %s: the element classes for the role %s, selected by their Mode (%s)."
                 % (self.name, self.version, role, ", ".join(modes)),
                 "; The package is the class %s, so the type name of an element is its qualified ID (%s.<class>)."
                 % (self.name, self.name),
                 "; The files that the classes include come first, outside the class body; inside it AutoHotkey skips them."]
        lines += ["#Include %s" % rel(p) for p in hoisted]
        lines += ["", "; arch-ok: one-class the generated package class is named after the package, not after this file",
                  "class %s {" % self.name]
        lines += ["    #Include %s" % rel(c[0]) for c in chosen]
        lines += ["}", "", 'ElementRegistry.RegisterPackage("%s", "%s")' % (self.name, self.version)]
        lines += ["ElementRegistry.Register(%s.%s)" % (self.name, c[1]) for c in chosen]
        return "\n".join(lines) + "\n"


def find_packages(folder):
    """The packages below `folder` (every sub-folder except base/), sorted by name. Raises GenError."""
    folder = Path(folder)
    if not folder.is_dir():
        return []
    out = []
    for sub in sorted(folder.iterdir(), key=lambda p: p.name.lower()):
        if sub.is_dir() and sub.name != "base" and not sub.name.startswith(("_", ".")):
            out.append(Package(sub))
    return out


def role_block_text(kind, role, packages, out_dir):
    lines = ["#Requires AutoHotkey v2.0",
             "; GENERATED by tools/gen_element_includes.py (E0037, E0041). Do not edit.",
             "; The element packages of the %s set for the role %s: one generated block per package." % (kind, role)]
    for pkg in packages:
        lines.append("#Include %s" % os.path.relpath(pkg.block_path(role), out_dir).replace("/", "\\"))
    return "\n".join(lines) + "\n"


def sets():
    """[(kind, package folder, output folder, file prefix)]"""
    return [("product", PRODUCT_DIR, PRODUCT_OUT, "Elements_"), ("test", TEST_DIR, TEST_OUT, "TestElements_")]


def generate():
    """Returns ({output path: text}, [generated files that are not needed any more]). Raises GenError."""
    result = {}
    superfluous = []
    names = global_names()
    seen = {}
    for kind, folder, out_dir, prefix in sets():
        packages = find_packages(folder)
        for pkg in packages:
            check_package_name(pkg.name, _shown(pkg.folder / DESCRIPTION), names)
            other = seen.get(pkg.name.lower())
            if other is not None:
                raise GenError("%s: package name '%s' is used twice (also %s)" % (_shown(pkg.folder), pkg.name, other))
            seen[pkg.name.lower()] = _shown(pkg.folder)
            if kind == "product":
                for path, cls, _mode, _incs in pkg.classes:
                    if cls.lower().startswith("action_test"):
                        raise GenError("%s: a test class belongs in a package below tests/elements/" % _shown(path))
            for role in ROLE_MODES:
                result[pkg.block_path(role)] = pkg.block_text(role)
            for old in pkg.folder.glob(BLOCK_PREFIX + "*.ahk"):
                if old not in result:
                    superfluous.append(old)
        for role in ROLE_MODES:
            result[out_dir / (prefix + role + ".ahk")] = role_block_text(kind, role, packages, out_dir)
        if out_dir.is_dir():
            for old in out_dir.glob(prefix + "*.ahk"):
                if old not in result:
                    superfluous.append(old)
    return result, superfluous


def classes_of(kind, role):
    """Qualified IDs (`<package>.<class>`) of the classes that the blocks of `role` in the set `kind` register."""
    folder = PRODUCT_DIR if kind == "product" else TEST_DIR
    modes = ROLE_MODES.get(role, ())
    return ["%s.%s" % (pkg.name, c[1]) for pkg in find_packages(folder) for c in pkg.classes if c[2] in modes]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="write nothing, exit 1 when a block is out of date")
    args = ap.parse_args(argv)
    try:
        blocks, superfluous = generate()
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
    for path in superfluous:
        print("%s %s" % ("not needed:" if args.check else "deleted:", _shown(path)))
        if not args.check:
            path.unlink()
    return 1 if (args.check and (stale or superfluous)) else 0


if __name__ == "__main__":
    sys.exit(main())
