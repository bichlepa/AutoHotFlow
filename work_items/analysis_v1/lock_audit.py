#!/usr/bin/env python3
"""Heuristic lock audit for AutoHotFlow (AutoHotkey v1 source).

Scans .ahk files and, per function, tracks the critical-section depth produced by
_EnterCriticalSection()/_LeaveCriticalSection() and EnterCriticalSection(x)/LeaveCriticalSection(x).
Reports:
  - exit-paths (return/throw/exit/exitapp) while the lock is held
  - blocking or slow calls while the lock is held (MsgBox, file I/O, Run/Sleep, element code, dynamic calls)
  - functions that end with the lock still held
  - "Critical on" usage

This is a line-based heuristic, not an AHK parser. Braces inside strings and
comments can confuse it. Treat every finding as a candidate that must be checked by reading the code.

Usage:
  python work_items/analysis_v1/lock_audit.py [root] [--json]   (default root: v1/)
"""
import json
import os
import re
import sys

EXCLUDE_DIRS = {"Lib", ".git", "Tools for contributors", "AutoHotKey", "bin", "Documentation", "Help", "Icons", "language"}
EXCLUDE_FILES_CONTAINING = ()

ENTER_RE = re.compile(r"\b(_EnterCriticalSection\s*\(\s*\)|EnterCriticalSection\s*\([^)]*\))", re.IGNORECASE)
LEAVE_RE = re.compile(r"\b(_LeaveCriticalSection\s*\(\s*\)|LeaveCriticalSection\s*\([^)]*\))", re.IGNORECASE)
FUNC_START_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)\s*$")
EXIT_RE = re.compile(r"^\s*(return|throw|exit|exitapp)\b", re.IGNORECASE)
CRITICAL_ON_RE = re.compile(r"^\s*critical\b", re.IGNORECASE)

# (category, regex, description)
BLOCKING = [
    ("ui-blocking", re.compile(r"\bMsgBox\b|\bInputBox\b|\bFileSelect(File|Folder)\b", re.IGNORECASE), "dialog blocks until user reacts"),
    ("file-io", re.compile(r"\b(FileRead|FileAppend|FileDelete|FileMove|FileCopy|FileCreateDir|FileGetSize|FileCreateShortcut|FileRecycle)\b", re.IGNORECASE), "file I/O"),
    ("file-io", re.compile(r"\bfileread\b|\bfileexist\s*\(|\bIfExist\b|\bIfNotExist\b|loop\s*,\s*files\b", re.IGNORECASE), "file system access"),
    ("process-wait", re.compile(r"\bRunWait\b|\bRun\s*,|\bsleep\s*,|\bWinWait\w*\b|\bProcessWait\w*\b|\bRunWait\b", re.IGNORECASE), "waits or spawns process"),
    ("element-code", re.compile(r"\bElement_\w+_%|\bElement_\w+_[A-Za-z]\w*\s*\(|\bElement_getParameters\s*\(", re.IGNORECASE), "calls element code (not owned by the engine)"),
    ("dynamic-call", re.compile(r"%\s*[A-Za-z_]\w*\s*%\s*\(|%[A-Za-z_]\w*%\s*\(", re.IGNORECASE), "dynamic function call (callback/element)"),
    ("network", re.compile(r"\bURLDownloadToFile\b|\bHTTPRequest\b|\bWinHttp\b", re.IGNORECASE), "network"),
    ("com-dll", re.compile(r"\bComObject\w*\s*\(|\bDllCall\s*\(", re.IGNORECASE), "COM/DllCall (may block)"),
]


def strip_comment(line):
    # remove ; comments that start outside quotes (approximation)
    in_quote = False
    for i, ch in enumerate(line):
        if ch == '"':
            in_quote = not in_quote
        elif ch == ";" and not in_quote and (i == 0 or line[i - 1] in " \t"):
            return line[:i]
    return line


def iter_ahk_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        rel = os.path.relpath(dirpath, root)
        parts = set(rel.split(os.sep))
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        if parts & EXCLUDE_DIRS:
            continue
        for f in filenames:
            if f.lower().endswith(".ahk"):
                yield os.path.join(dirpath, f)


def analyse_file(path, root):
    findings = []
    try:
        with open(path, encoding="utf-8-sig", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError as e:
        return [{"file": path, "error": str(e)}]

    rel = os.path.relpath(path, root)
    func_name = None
    func_start = 0
    depth_lock = 0
    lock_first_line = None
    brace_depth = 0
    in_func = False
    pending_func = None

    for idx, raw in enumerate(lines, start=1):
        line = strip_comment(raw)
        stripped = line.strip()

        # detect function header: "Name(args)" followed by "{" on next non-empty line
        if not in_func:
            m = FUNC_START_RE.match(line)
            if m and not stripped.lower().startswith(("if", "for", "loop", "while", "switch", "else")):
                pending_func = (m.group(1), idx)
                continue
            if pending_func and stripped == "{":
                func_name, func_start = pending_func
                pending_func = None
                in_func = True
                brace_depth = 1
                depth_lock = 0
                lock_first_line = None
                continue
            pending_func = None
            continue

        # inside a function body
        opens = line.count("{")
        closes = line.count("}")

        if CRITICAL_ON_RE.match(line):
            findings.append({"file": rel, "line": idx, "func": func_name, "category": "critical-on",
                             "text": stripped, "note": "AHK 'Critical' (not the Win32 section) used"})

        enter_count = len(ENTER_RE.findall(line))
        leave_count = len(LEAVE_RE.findall(line))
        if enter_count:
            if depth_lock == 0:
                lock_first_line = idx
            depth_lock += enter_count
        if leave_count:
            depth_lock -= leave_count
            if depth_lock <= 0:
                depth_lock = 0
                lock_first_line = None

        if depth_lock > 0:
            if EXIT_RE.match(line):
                findings.append({"file": rel, "line": idx, "func": func_name, "category": "exit-while-locked",
                                 "text": stripped, "note": f"lock taken at line {lock_first_line} is not released on this path"})
            for cat, rx, desc in BLOCKING:
                if rx.search(line):
                    findings.append({"file": rel, "line": idx, "func": func_name, "category": "blocking-while-locked:" + cat,
                                     "text": stripped, "note": desc})
                    break

        brace_depth += opens - closes
        if brace_depth <= 0:
            if depth_lock > 0:
                findings.append({"file": rel, "line": idx, "func": func_name, "category": "lock-held-at-end",
                                 "text": "", "note": f"function ends while lock taken at line {lock_first_line} is still held"})
            in_func = False
            func_name = None
            depth_lock = 0

    return findings


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    as_json = "--json" in sys.argv
    root = os.path.abspath(args[0]) if args else os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "v1"))

    all_findings = []
    for path in iter_ahk_files(root):
        all_findings.extend(analyse_file(path, root))

    if as_json:
        print(json.dumps(all_findings, indent=2, ensure_ascii=False))
        return

    counts = {}
    for f in all_findings:
        counts[f.get("category", "error")] = counts.get(f.get("category", "error"), 0) + 1
    print("Summary (heuristic):")
    for cat in sorted(counts):
        print(f"  {cat:<40} {counts[cat]}")
    print()
    for f in all_findings:
        if "error" in f:
            print(f"ERROR {f['file']}: {f['error']}")
            continue
        print(f"{f['file']}:{f['line']} [{f['category']}] in {f['func']}: {f['text']}  -- {f['note']}")


if __name__ == "__main__":
    main()
