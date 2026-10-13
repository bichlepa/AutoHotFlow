"""Architecture guard (WI-19): runs tools/arch_check.py over src/ and tests the rules themselves.

The first test fails with the complete list of violations (file:line: rule: text). The self tests feed small
example texts to the check, one hit and one non-hit per rule.
"""

import sys
from pathlib import Path

import pytest

TOOLS_DIR = Path(__file__).resolve().parent.parent / "tools"
sys.path.insert(0, str(TOOLS_DIR))
import arch_check  # noqa: E402

REQ = "#Requires AutoHotkey v2.0\n"


def rules(relpath, body, with_requires=True):
    """Rules reported for a file with the given body."""
    text = (REQ if with_requires else "") + body
    return [v.rule for v in arch_check.check_text(relpath, text)]


def test_source_tree_obeys_the_architecture_rules():
    violations, suppressed, count = arch_check.run()
    assert count > 0, "no .ahk files found under src/"
    listing = "\n".join(str(v) for v in violations)
    assert not violations, f"{len(violations)} architecture violations ({suppressed} covered by listed exceptions):\n{listing}"


def test_every_listed_exception_has_a_reason():
    for path, rule, _pattern, reason in arch_check.EXCEPTIONS:
        assert rule in arch_check.RULES, (path, rule)
        assert len(reason.split()) >= 4, f"exception {path} {rule} needs a real reason"


def test_all_rules_are_covered_by_self_tests():
    # every rule name must appear in a case table below; guards against adding a rule without tests
    covered = {rule for rule, *_ in CASES}
    assert covered == set(arch_check.RULES) | {"arch-ok"}


# (rule, relpath, body that must be reported, body that must not be reported)
CASES = [
    ("requires", "core/A.ahk", None, None),  # handled by dedicated tests below
    ("one-class", "core/A.ahk", "class B {\n}\n", "class A {\n    class Inner {\n    }\n}\n"),
    ("include-core", "core/A.ahk", "#Include ..\\engine\\Engine.ahk\nclass A {\n}\n", "#Include ipc\\Peer.ahk\nclass A {\n}\n"),
    ("include-roles", "engine/A.ahk", "#Include ..\\storage\\Storage.ahk\nclass A {\n}\n",
     "#Include ..\\core\\Log.ahk\n#Include ..\\elements\\base\\AhfElement.ahk\n#Include core\\X.ahk\nclass A {\n}\n"),
    ("include-tests", "engine/A.ahk", "#Include ..\\..\\tests\\helpers\\X.ahk\nclass A {\n}\n", "#Include ..\\core\\Log.ahk\nclass A {\n}\n"),
    ("dialog", "engine/A.ahk", "class A {\n    M() {\n        MsgBox(\"x\")\n    }\n}\n", "class A {\n    M() {\n        s := \"MsgBox\"\n    }\n}\n"),
    ("file-io", "engine/A.ahk", "class A {\n    M() {\n        FileRead(\"x\")\n    }\n}\n", "class A {\n    M() {\n        return A_LoopFileName\n    }\n}\n"),
    ("blocking", "engine/A.ahk", "class A {\n    M() {\n        Sleep(100)\n    }\n}\n", "class A {\n    M() {\n        Sleep(0)\n    }\n}\n"),
    ("inline-element", "elements/skeleton/A.ahk", "class A {\n    static Mode := \"inline\"\n    M() {\n        MsgBox(\"x\")\n    }\n}\n",
     "class A {\n    static Mode := \"worker\"\n    M() {\n        MsgBox(\"x\")\n    }\n}\n"),
    ("warn", "AutoHotFlow.ahk", "#Warn All\n", "#Warn All, StdOut\n"),
    ("critical", "engine/A.ahk", "class A {\n    M() {\n        Critical(\"On\")\n    }\n}\n",
     "class A {\n    M() {\n        Critical(\"On\")  ; reason: the guard must not be interrupted\n    }\n}\n"),
    ("empty-catch", "engine/A.ahk", "class A {\n    M() {\n        try {\n            X()\n        } catch {\n        }\n    }\n}\n",
     "class A {\n    M() {\n        try {\n            X()\n        } catch {\n            ; best effort, nothing to do\n        }\n    }\n}\n"),
    ("builtin-class", "core/A.ahk", "class TimeoutError extends Error {\n}\n", "class AhfTimeoutError extends Error {\n}\n"),
    ("wire-bool", "engine/A.ahk", "class A {\n    M() {\n        return Map(\"enabled\", true)\n    }\n}\n",
     "class A {\n    M() {\n        return Map(\"enabled\", Json.True, \"ok\", true)\n    }\n}\n"),
    ("arch-ok", "engine/A.ahk", "; arch-ok: dialog\nclass A {\n}\n", "; arch-ok: dialog a dialog is needed here\nclass A {\n}\n"),
]


@pytest.mark.parametrize("rule,relpath,bad,good", [pytest.param(*c, id=c[0]) for c in CASES if c[2] is not None])
def test_rule_hits_and_misses(rule, relpath, bad, good):
    # the "bad" text for one-class is named differently from its file, the others are checked as given
    stem = Path(relpath).stem
    bad = bad.replace("class A", "class " + stem)
    assert rule in rules(relpath, bad), f"{rule}: expected a hit"
    assert rule not in rules(relpath, good), f"{rule}: expected no hit"


def test_requires_hit_and_miss():
    assert "requires" in rules("core/A.ahk", "class A {\n}\n", with_requires=False)
    assert "requires" in rules("core/A.ahk", "#Requires AutoHotkey v1.1\nclass A {\n}\n", with_requires=False)
    assert "requires" not in rules("core/A.ahk", "class A {\n}\n")
    assert "requires" not in rules("core/A.ahk", "; comment first\n#Requires AutoHotkey v2.0\nclass A {\n}\n", with_requires=False)


def test_one_class_file_name_and_second_class():
    assert "one-class" in rules("core/A.ahk", "class Other {\n}\n")  # name differs from file
    assert "one-class" in rules("core/A.ahk", "class A {\n}\nclass B {\n}\n")  # second top-level class
    assert "one-class" not in rules("core/A.ahk", "class A {\n}\n")
    assert "one-class" not in rules("core/Util.ahk", "F() {\n}\n")  # free functions only


def test_include_rules_details():
    assert "include-roles" in rules("storage/A.ahk", "#Include ..\\engine\\X.ahk\n")
    assert "include-roles" in rules("elements/base/A.ahk", "#Include ..\\..\\engine\\X.ahk\n")
    assert "include-roles" not in rules("AutoHotFlow.ahk", "#Include engine\\Engine.ahk\n")  # entry point is exempt
    assert "include-roles" not in rules("worker/A.ahk", "#Include ..\\core\\Log.ahk\n")
    assert "include-roles" in rules("worker/A.ahk", "#Include ..\\ui_common\\X.ahk\n")
    assert "include-roles" not in rules("manager/A.ahk", "#Include ..\\ui_common\\X.ahk\n")
    assert "include-tests" in rules("AutoHotFlow.ahk", "#Include ..\\tests\\x\\Y.ahk\n")
    assert "include-core" in rules("core/ipc/A.ahk", "#Include ..\\..\\elements\\base\\X.ahk\n")
    assert "include-core" not in rules("core/ipc/A.ahk", "#Include ..\\Log.ahk\n")


def test_expr_library_rules():
    # expr/ is a library: every role may include it, it includes only core/, and it has no dialogs and no file access
    assert "include-roles" not in rules("engine/A.ahk", "#Include ..\\expr\\Expr.ahk\n")
    assert "include-roles" not in rules("worker/A.ahk", "#Include ..\\expr\\Expr.ahk\n")
    assert "include-core" in rules("core/A.ahk", "#Include ..\\expr\\Expr.ahk\n")
    assert "include-roles" not in rules("expr/A.ahk", "#Include ..\\core\\Log.ahk\n#Include B.ahk\n")
    assert "include-roles" in rules("expr/A.ahk", "#Include ..\\engine\\X.ahk\n")
    assert "include-roles" in rules("expr/A.ahk", "#Include ..\\elements\\base\\X.ahk\n")
    assert "dialog" in rules("expr/A.ahk", "class A {\n    M() {\n        MsgBox(\"x\")\n    }\n}\n")
    assert "file-io" in rules("expr/A.ahk", "class A {\n    M() {\n        FileRead(\"x\")\n    }\n}\n")
    assert "blocking" in rules("expr/A.ahk", "class A {\n    M() {\n        Sleep(100)\n    }\n}\n")


def test_roles_may_do_what_the_table_allows():
    assert "dialog" not in rules("manager/A.ahk", "class A {\n    M() {\n        MsgBox(\"x\")\n    }\n}\n")
    assert "dialog" in rules("storage/A.ahk", "class A {\n    M() {\n        InputBox(\"x\")\n    }\n}\n")
    assert "file-io" not in rules("storage/A.ahk", "class A {\n    M() {\n        FileOpen(\"x\", \"r\")\n    }\n}\n")
    assert "file-io" in rules("supervisor/A.ahk", "class A {\n    M() {\n        Loop Files \"*.*\" {\n        }\n    }\n}\n")
    assert "blocking" not in rules("worker/A.ahk", "class A {\n    M() {\n        Sleep(500)\n        RunWait(\"x\")\n    }\n}\n")
    assert "blocking" in rules("engine/A.ahk", "class A {\n    M() {\n        RunWait(\"x\")\n    }\n}\n")
    assert "blocking" in rules("supervisor/A.ahk", "class A {\n    M() {\n        WinWait(\"x\")\n    }\n}\n")
    assert "blocking" not in rules("supervisor/A.ahk", "class A {\n    M() {\n        WinWait(\"x\", , 2)\n    }\n}\n")
    assert "blocking" not in rules("supervisor/A.ahk", "class A {\n    M() {\n        DllCall(\"Sleep\", \"uint\", 5)\n    }\n}\n")


def test_comments_and_strings_are_ignored():
    body = "class A {\n    ; MsgBox(\"x\") in a comment\n    /*\n    FileRead(\"y\")\n    */\n    M() {\n        s := \"Sleep(100) FileRead\"\n    }\n}\n"
    assert rules("engine/A.ahk", body) == []


def test_element_mode_decides_for_elements():
    base = "class A {\n    static Mode := \"%s\"\n    M() {\n        Sleep(10)\n        FileRead(\"x\")\n    }\n}\n"
    assert set(rules("elements/skeleton/A.ahk", base % "inline")) == {"inline-element"}
    assert rules("elements/skeleton/A.ahk", base % "worker") == []
    assert {"blocking", "file-io"} <= set(rules("elements/skeleton/A.ahk", base % "trigger"))


def test_arch_ok_needs_a_reason_and_applies_to_next_line():
    body = "class A {\n    M() {\n        ; arch-ok: blocking Sleep is fine here, test only\n        Sleep(10)\n    }\n}\n"
    assert rules("engine/A.ahk", body) == []
    same_line = "class A {\n    M() {\n        Sleep(10)  ; arch-ok: blocking test only\n    }\n}\n"
    assert rules("engine/A.ahk", same_line) == []
    no_reason = "class A {\n    M() {\n        Sleep(10)  ; arch-ok: blocking\n    }\n}\n"
    assert "arch-ok" in rules("engine/A.ahk", no_reason)
    assert "blocking" in rules("engine/A.ahk", no_reason)
    other_rule = "class A {\n    M() {\n        Sleep(10)  ; arch-ok: dialog not the right rule\n    }\n}\n"
    assert "blocking" in rules("engine/A.ahk", other_rule)
    assert "arch-ok" in rules("engine/A.ahk", "; arch-ok: nonsense because\nclass A {\n}\n")


def test_critical_off_and_restore_are_not_reported():
    body = "class A {\n    M() {\n        Critical(\"Off\")\n        Critical(prev)\n        Critical(false)\n    }\n}\n"
    assert "critical" not in rules("engine/A.ahk", body)
    assert "critical" in rules("engine/A.ahk", "class A {\n    M() {\n        Critical\n    }\n}\n")


def test_catch_variants():
    head = "class A {\n    M() {\n        try {\n            X()\n        } "
    assert "empty-catch" in rules("engine/A.ahk", head + "catch as e {\n        }\n    }\n}\n")
    assert "empty-catch" in rules("engine/A.ahk", head + "catch OSError as e {\n        }\n    }\n}\n")
    assert "empty-catch" not in rules("engine/A.ahk", head + "catch as e {\n            Log(e)\n        }\n    }\n}\n")
    assert "empty-catch" not in rules("engine/A.ahk", head + "catch {\n            ; ignored on purpose\n        }\n    }\n}\n")


def test_warn_variants():
    assert "warn" not in rules("AutoHotFlow.ahk", "#Warn All, OutputDebug\n")
    assert "warn" not in rules("AutoHotFlow.ahk", "#Warn VarUnset, Off\n")
    assert "warn" in rules("AutoHotFlow.ahk", "#Warn All, MsgBox\n")


def test_command_line_exit_code(tmp_path):
    (tmp_path / "core").mkdir()
    (tmp_path / "core" / "A.ahk").write_text("class A {\n}\n", encoding="utf-8")  # no #Requires
    assert arch_check.main(["--root", str(tmp_path)]) == 1
    (tmp_path / "core" / "A.ahk").write_text(REQ + "class A {\n}\n", encoding="utf-8")
    assert arch_check.main(["--root", str(tmp_path)]) == 0
