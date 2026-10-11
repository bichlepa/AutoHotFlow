#!/usr/bin/env python
"""Static architecture check for the AutoHotFlow v2 sources (WI-19).

Reads every .ahk file under src/, removes comments and string literals, and looks for rule breaks
(see doc/KONVENTIONEN.md section 3 and doc/ARCHITEKTUR.md section 8). The check is deliberately simple
(lines and patterns, no AHK parser). A false positive is justified with a comment at the place:

    ; arch-ok: <rule> <reason>

on the same line or on the line directly above (the reason is mandatory). Exceptions that are not
better placed in the source live in EXCEPTIONS below, each with a reason. An exception that no longer
matches anything is reported (rule "exception-unused") so that resolved items get removed.

Usage:  python tools/arch_check.py [--root DIR]      (exit 1 if there are violations)
When a rule is added or changed, update doc/KONVENTIONEN.md section 3 in the same commit.
"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

REPO = Path(__file__).resolve().parent.parent

RULES = ("requires", "one-class", "include-core", "include-roles", "include-tests", "dialog", "file-io",
         "blocking", "inline-element", "warn", "critical", "empty-catch", "builtin-class")

# Folders under src/ that are libraries, not process roles.
LIB_DIRS = {"core", "elements", "ui_common"}
# Roles that must never show a dialog (see "dialog" rule). Elements are checked via their Mode.
NO_DIALOG_ROLES = {"core", "engine", "supervisor", "storage", "triggerhost"}

# Known, justified exceptions: (path relative to src/, rule, regex the offending line must match or None, reason).
EXCEPTIONS = [
    ("core/Role.ahk", "file-io", r"FileAppend",
     "Role.Console writes to stderr ('**') with FileAppend, not to a file; documented in Role.ahk (F-05)."),
    ("AutoHotFlow.ahk", "include-tests", r"tests\\integration\\helpers\\",
     "Entry point includes the test roles registered with --test-roles; resolved by WI-29."),
    ("core/RoleRegistry.ahk", "one-class", r"PlaceholderRole",
     "RoleRegistry and PlaceholderRole share one file; resolved by WI-29."),
    ("core/Errors.ahk", "one-class", r"class (ErrCode|AhfError|ProtocolError|AhfTimeoutError|ElementError|JsonError)\b",
     "The error hierarchy (ErrCode + 5 tiny subclasses) lives in one module by design (PROTOKOLL 2); open point, see WI-19 result."),
    ("engine/core/Loops.ahk", "one-class", r"class LoopStack\b",
     "File is named Loops.ahk but holds class LoopStack; rename is out of scope for WI-19, open point."),
]

# Built-in AutoHotkey v2 classes that must not be redefined.
BUILTIN_CLASSES = {
    "Any", "Object", "Class", "Primitive", "Number", "Integer", "Float", "String", "Array", "Map", "Buffer",
    "ClipboardAll", "Func", "BoundFunc", "Closure", "Enumerator", "File", "Gui", "InputHook", "Menu", "MenuBar",
    "RegExMatchInfo", "VarRef", "Error", "MemoryError", "OSError", "TargetError", "TimeoutError", "TypeError",
    "ValueError", "ZeroDivisionError", "MemberError", "PropertyError", "MethodError", "UnsetError",
    "UnsetItemError", "IndexError",
}


@dataclass(frozen=True)
class Violation:
    path: str  # relative to src/, posix separators
    line: int
    rule: str
    text: str

    def __str__(self):
        return f"{self.path}:{self.line}: {self.rule}: {self.text}"


# --------------------------------------------------------------------------- text preparation

def scan(text):
    """Returns (code, code_with_strings, comments). code has comments and string contents blanked,
    code_with_strings only comments blanked; both keep length and line breaks, so offsets and line numbers
    match the original. comments maps line number (1-based) to the comment text on that line."""
    code, kept = [], []
    comments = {}
    n = len(text)
    i = 0
    line = 1
    at_line_start = True  # only whitespace seen on this line so far
    in_block = False
    quote = None
    while i < n:
        c = text[i]
        if in_block:
            if c == "\n":
                code.append(c); kept.append(c); line += 1; at_line_start = True
                i += 1
                continue
            if text.startswith("*/", i):
                in_block = False
                comments[line] = comments.get(line, "") + " "
                code.append("  "); kept.append("  "); i += 2
                continue
            comments[line] = comments.get(line, "") + c
            code.append(" "); kept.append(" "); i += 1
            continue
        if quote:
            if c == "`" and i + 1 < n and text[i + 1] != "\n":  # escape sequence
                code.append("  "); kept.append(text[i:i + 2]); i += 2
                continue
            if c == quote:
                quote = None
                code.append(c); kept.append(c); i += 1
                continue
            if c == "\n":  # unterminated string: do not run on over lines
                quote = None
                code.append(c); kept.append(c); line += 1; at_line_start = True; i += 1
                continue
            code.append(" "); kept.append(c); i += 1
            continue
        if c == "\n":
            code.append(c); kept.append(c); line += 1; at_line_start = True; i += 1
            continue
        if c in " \t\r":
            code.append(c); kept.append(c); i += 1
            continue
        if text.startswith("/*", i) and at_line_start:
            in_block = True
            code.append("  "); kept.append("  "); i += 2
            continue
        if c == ";" and (i == 0 or text[i - 1] in " \t\r\n" or at_line_start):
            j = text.find("\n", i)
            j = n if j < 0 else j
            comments[line] = comments.get(line, "") + text[i + 1:j]
            code.append(" " * (j - i)); kept.append(" " * (j - i)); i = j
            continue
        if c in "\"'":
            quote = c
            code.append(c); kept.append(c); i += 1; at_line_start = False
            continue
        at_line_start = False
        code.append(c); kept.append(c); i += 1
    return "".join(code), "".join(kept), comments


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def role_of(relpath):
    parts = PurePosixPath(relpath).parts
    return "entry" if len(parts) == 1 else parts[0]


# --------------------------------------------------------------------------- patterns

NOT_MEMBER = r"(?<![\w.%])"  # not a method call (Foo.Sleep), not part of a longer name
DIALOG_RE = re.compile(NOT_MEMBER + r"(MsgBox|InputBox|FileSelect|DirSelect)\b(?!\s*:=)")
FILEIO_RE = re.compile(NOT_MEMBER + r"(FileRead|FileAppend|FileOpen|FileDelete|FileMove|FileCopy|DirCreate|"
                       r"DirDelete|DirMove|DirCopy)\b(?!\s*:=)|\bLoop[\s,]+(Files|Read)\b", re.I)
SLEEP_RE = re.compile(NOT_MEMBER + r"Sleep\b(?!\s*:=)\s*\(?\s*([^\s,)]*)")
RUNWAIT_RE = re.compile(NOT_MEMBER + r"RunWait\b(?!\s*:=)")
WINWAIT_RE = re.compile(NOT_MEMBER + r"(WinWait(?:Active|NotActive|Close)?)\b(?!\s*:=)")
CRITICAL_RE = re.compile(NOT_MEMBER + r"Critical\b(?!\s*:=)(.*)")
CLASS_RE = re.compile(r"^[ \t]*class[ \t]+(\w+)", re.M | re.I)
INCLUDE_RE = re.compile(r"^[ \t]*#Include(?:Again)?[ \t]+(?:\*i[ \t]+)?(.+?)[ \t]*$", re.M | re.I)
WARN_RE = re.compile(r"^[ \t]*#Warn\b(.*)$", re.M | re.I)
MODE_RE = re.compile(r"\bstatic\s+Mode\s*:=\s*[\"'](\w+)[\"']", re.I)
CATCH_RE = re.compile(r"(?<![\w.])catch\b", re.I)
ARCH_OK_RE = re.compile(r"arch-ok:\s*([\w-]+)\s*(.*)")


def count_args(code, open_pos):
    """Number of top-level arguments of the call whose '(' is at open_pos (same line only)."""
    depth, args, seen = 0, 0, False
    for ch in code[open_pos:code.find("\n", open_pos) if code.find("\n", open_pos) >= 0 else len(code)]:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                break
        elif ch == "," and depth == 1:
            args += 1; seen = True
        elif not ch.isspace() and depth >= 1:
            seen = True
    return (args + 1) if seen else 0


# --------------------------------------------------------------------------- the checks

def check_text(relpath, text):
    """Checks one file. relpath is relative to src/ with forward slashes. Returns a list of Violation,
    already filtered by `; arch-ok:` comments. Listed exceptions (EXCEPTIONS) are applied elsewhere."""
    code, kept, comments = scan(text)
    role = role_of(relpath)
    stem = PurePosixPath(relpath).stem
    raw = []  # (line, rule, text)
    lines = text.split("\n")

    def add(pos_or_line, rule, label, is_line=False):
        ln = pos_or_line if is_line else line_of(code, pos_or_line)
        raw.append((ln, rule, label.strip()))

    def src_line(ln):
        return lines[ln - 1].strip() if 0 < ln <= len(lines) else ""

    # requires: first code line
    first = next((ln for ln, l in enumerate(code.split("\n"), 1) if l.strip()), None)
    if first is None or not re.match(r"#Requires\s+AutoHotkey\s+v2\.0", code.split("\n")[first - 1].strip(), re.I):
        add(first or 1, "requires", src_line(first or 1) or "(empty file)", True)

    # classes
    top = []
    depth = 0
    for m in re.finditer(r"[{}]|^[ \t]*class[ \t]+(\w+)", code, re.M | re.I):
        if m.group(0) == "{":
            depth += 1
        elif m.group(0) == "}":
            depth -= 1
        else:
            name = m.group(1)
            if name.lower() in {b.lower() for b in BUILTIN_CLASSES}:
                add(m.start(1), "builtin-class", f"class {name} redefines a built-in AutoHotkey class")
            if depth == 0:
                top.append((name, m.start(1)))
    if top and top[0][0].lower() != stem.lower():
        add(top[0][1], "one-class", f"class {top[0][0]} in file {stem}.ahk (file name must equal class name)")
    for name, pos in top[1:]:
        add(pos, "one-class", f"class {name} is a second top-level class in {stem}.ahk")

    # includes
    for m in INCLUDE_RE.finditer(code):
        target = m.group(1).strip().strip("\"'")
        if "%" in target or target.startswith("<"):
            continue
        path = PurePosixPath(relpath).parent / target.replace("\\", "/")
        norm = _normalize(path)
        if norm is None or norm.parts and norm.parts[0] == "..":
            parts = _outside_parts(PurePosixPath(relpath).parent, target)
            if parts and parts[0] == "tests":
                add(m.start(), "include-tests", f"#Include {target} (src/ must not include tests/)")
            else:
                add(m.start(), "include-roles", f"#Include {target} (outside src/)")
            continue
        troot = norm.parts[0] if len(norm.parts) > 1 else "entry"
        if role == "entry":
            continue
        if role == "core":
            if troot != "core":
                add(m.start(), "include-core", f"#Include {target} (core/ must not include {troot}/)")
            continue
        if troot == role or troot == "core":
            continue
        if troot == "elements":
            if role in LIB_DIRS:
                add(m.start(), "include-roles", f"#Include {target} ({role}/ must not include {troot}/)")
            continue
        if troot == "ui_common":
            if role not in ("manager", "editor"):
                add(m.start(), "include-roles", f"#Include {target} (ui_common/ is for UI roles only)")
            continue
        add(m.start(), "include-roles", f"#Include {target} ({role}/ must not include {troot}/)")

    # Mode of an element file
    mode = None
    if role == "elements":
        mm = MODE_RE.search(kept)
        mode = mm.group(1).lower() if mm else None

    def forbid(rule_name, pos, label):
        """Reports a dialog / file-io / blocking hit according to the role and element mode."""
        if role == "elements":
            if mode == "worker":
                return
            if mode == "inline":
                add(pos, "inline-element", f"{label} in an inline element ({rule_name})")
                return
            # base files, trigger elements: same limits as the non-worker roles
            add(pos, rule_name, label)
            return
        if rule_name == "dialog":
            if role in NO_DIALOG_ROLES:
                add(pos, "dialog", label)
        elif rule_name == "file-io":
            if role != "storage":
                add(pos, "file-io", label)
        elif rule_name == "blocking":
            if role != "worker":
                add(pos, "blocking", label)

    for m in DIALOG_RE.finditer(code):
        forbid("dialog", m.start(), m.group(1) + " (dialog)")
    for m in FILEIO_RE.finditer(code):
        forbid("file-io", m.start(), (m.group(1) or m.group(0)) + " (file access)")
    for m in SLEEP_RE.finditer(code):
        arg = m.group(1)
        if arg in ("", "0", "-1"):
            continue  # bare word, or Sleep(0) / Sleep(-1), which only yield the thread
        forbid("blocking", m.start(), f"Sleep {arg} (blocking)")
    for m in RUNWAIT_RE.finditer(code):
        forbid("blocking", m.start(), "RunWait (blocking)")
    for m in WINWAIT_RE.finditer(code):
        rest = code[m.end():]
        stripped = rest.lstrip(" \t")
        if stripped.startswith("("):
            nargs = count_args(code, m.end() + (len(rest) - len(stripped)))
        else:
            eol = rest.find("\n")
            nargs = len(rest[:eol if eol >= 0 else len(rest)].split(","))
        if nargs < 3:
            forbid("blocking", m.start(), f"{m.group(1)} without timeout (blocking)")

    # #Warn
    for m in WARN_RE.finditer(code):
        parts = [p.strip() for p in m.group(1).split(",")]
        target = parts[-1].lower() if len(parts) > 1 else ""
        if target not in ("stdout", "outputdebug", "off"):
            add(m.start(), "warn", f"#Warn without target StdOut/OutputDebug (default is a dialog): {m.group(0).strip()}")

    # Critical needs a reason in a comment (same or previous line)
    for m in CRITICAL_RE.finditer(code):
        rest = kept[m.start(1):m.end(1)].strip()  # string contents are needed here ("On" / "Off")
        if rest and not re.match(r"\(?\s*(\"on\"|'on'|true\b|[1-9]\d*\b|\))", rest, re.I):
            continue  # Critical("Off"), Critical(false), Critical(prev): switching off or restoring, not entering
        ln = line_of(code, m.start())
        if not (_has_reason(comments.get(ln)) or _has_reason(comments.get(ln - 1) if _comment_only(lines, ln - 1) else None)):
            add(m.start(), "critical", "Critical without a reason in a comment on this or the previous line")

    # empty catch
    for m in CATCH_RE.finditer(code):
        j = m.end()
        hdr = re.compile(r"[ \t]*(?:(?!as\b)[A-Za-z_][\w.]*(?:[ \t]*,[ \t]*[A-Za-z_][\w.]*)*[ \t]*)?(?:as[ \t]+\w+[ \t]*)?", re.I)
        j = hdr.match(code, j).end()
        while j < len(code) and code[j] in " \t\r\n":
            j += 1
        if j >= len(code) or code[j] != "{":
            continue
        k, d = j, 0
        while k < len(code):
            if code[k] == "{":
                d += 1
            elif code[k] == "}":
                d -= 1
                if d == 0:
                    break
            k += 1
        if code[j + 1:k].strip():
            continue
        first_ln, last_ln = line_of(code, m.start()), line_of(code, k)
        if not any(_has_reason(comments.get(x)) for x in range(first_ln, last_ln + 1)):
            add(m.start(), "empty-catch", "empty catch block without a comment that gives the reason")

    return _apply_arch_ok(relpath, raw, comments, lines)


def _has_reason(comment):
    return bool(comment) and bool(re.search(r"[A-Za-z]{3,}", comment))


def _comment_only(lines, ln):
    return 0 < ln <= len(lines) and lines[ln - 1].lstrip().startswith(";")


def _normalize(path):
    out = []
    for part in path.parts:
        if part == "..":
            if not out:
                return None
            out.pop()
        elif part != ".":
            out.append(part)
    return PurePosixPath(*out) if out else PurePosixPath(".")


def _outside_parts(parent, target):
    """Parts of an include that leaves src/, relative to the repo root (src/ is one level below)."""
    parts = ["src"]
    for part in list(parent.parts) + target.replace("\\", "/").split("/"):
        if part == "..":
            if parts:
                parts.pop()
        elif part not in (".", ""):
            parts.append(part)
    return parts


def _apply_arch_ok(relpath, raw, comments, lines):
    result = []
    used = set()
    for ln, rule, label in raw:
        ok = False
        for cl in (ln, ln - 1):
            if cl == ln - 1 and not _comment_only(lines, cl):
                continue
            m = ARCH_OK_RE.search(comments.get(cl, ""))
            if m and m.group(1) == rule and m.group(2).strip():
                ok = True
                used.add(cl)
        if not ok:
            result.append(Violation(relpath, ln, rule, label))
    # an arch-ok without a reason or for an unknown rule is a violation of its own
    for cl, c in comments.items():
        m = ARCH_OK_RE.search(c)
        if m and (m.group(1) not in RULES or not m.group(2).strip()):
            result.append(Violation(relpath, cl, "arch-ok", f"arch-ok needs a known rule and a reason: {c.strip()}"))
    return result


# --------------------------------------------------------------------------- tree

def apply_exceptions(violations, root):
    """Removes violations covered by EXCEPTIONS. Returns (remaining, number suppressed, unused-exception violations)."""
    used = [0] * len(EXCEPTIONS)
    remaining = []
    for v in violations:
        hit = False
        for i, (path, rule, pattern, _reason) in enumerate(EXCEPTIONS):
            if v.path == path and v.rule == rule and (pattern is None or re.search(pattern, _line_text(root, v))):
                used[i] += 1
                hit = True
        if not hit:
            remaining.append(v)
    unused = [Violation(p, 1, "exception-unused", f"exception for rule {r} matches nothing any more, remove it ({why})")
              for (p, r, _pat, why), n in zip(EXCEPTIONS, used) if n == 0]
    return remaining, len(violations) - len(remaining), unused


def _line_text(root, v):
    try:
        lines = (Path(root) / v.path).read_text(encoding="utf-8").split("\n")
        return lines[v.line - 1]
    except (OSError, IndexError):
        return ""


def check_tree(src_root):
    """Checks all .ahk files below src_root. Returns (violations before exceptions, files checked)."""
    src_root = Path(src_root)
    found, count = [], 0
    for f in sorted(src_root.rglob("*.ahk")):
        rel = f.relative_to(src_root).as_posix()
        found.extend(check_text(rel, f.read_text(encoding="utf-8-sig")))
        count += 1
    return found, count


def run(src_root=None):
    """Full check with exceptions. Returns (violations, suppressed, files)."""
    default = REPO / "src"
    src_root = Path(src_root) if src_root else default
    found, count = check_tree(src_root)
    remaining, suppressed, unused = apply_exceptions(found, src_root)
    # stale exceptions are only reported for the real tree (other roots, e.g. in tests, have none of them)
    return remaining + (unused if src_root.resolve() == default.resolve() else []), suppressed, count


def main(argv=None):
    ap = argparse.ArgumentParser(description="Static architecture check for src/*.ahk")
    ap.add_argument("--root", help="src directory to check (default: <repo>/src)")
    args = ap.parse_args(argv)
    violations, suppressed, count = run(args.root)
    for v in violations:
        print(v)
    print(f"arch_check: {count} files, {len(violations)} violations, {suppressed} covered by listed exceptions",
          file=sys.stderr)
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
