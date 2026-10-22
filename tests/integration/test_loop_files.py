"""WI-0121: end-to-end tests of the loop Loop through files (Loop_Loop_Through_Files, the first worker loop).

A flow is: trigger, the loop, a body that adds a text to the list `seq` (inline, Action_Add_To_List) for every pass, and the
probe of `seq` at the tail of the loop, then the marker AFTER. Each pass of the loop is a worker job (the head pass lists
the files, the later passes read one member of the list). Every test works in its own temporary folder (pytest tmp_path).
"""

import json

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def tree(root):
    """a.txt, b.log and sub/c.txt below root."""
    (root / "sub").mkdir(parents=True)
    (root / "a.txt").write_bytes(b"aaa")
    (root / "b.log").write_bytes(b"bb")
    (root / "sub" / "c.txt").write_bytes(b"c")
    return root


def add_to_list(fb, text, name="BODY"):
    """The body: appends `text` (with %var%) to the list seq, as the last value."""
    return fb.action("Action_Add_To_List", Varname="seq", NumberOfElements="One", VarValue=text,
                     WhichPosition="Last", name=name)


def loop_flow(name, pattern, operate="Files", recurse=0, body_text="%A_LoopFileName%", break_at=None):
    """trigger -> loop; head -> the body (an add of `body_text` to seq) -> tail of the loop. With break_at, the head
    goes first to a condition `A_Index = break_at`: yes leaves through the break part, no runs the body.
    tail -> probe seq -> AFTER."""
    fb = FlowBuilder(name)
    loop = fb.loop("Loop_Loop_Through_Files", file=str(pattern), OperateOnWhat=operate, Recurse=recurse)
    fb.connect(fb.trigger(), loop)
    add = add_to_list(fb, body_text)
    if break_at is None:
        fb.connect(loop, add, "head")
    else:
        cond = fb.condition("Condition_Expression", Expression="A_Index = %d" % break_at)
        fb.connect(loop, cond, "head")
        fb.connect(cond, loop, "yes", into="break")
        fb.connect(cond, add, "no")
    fb.connect(add, loop, into="tail")
    end = fb.action("Action_Do_nothing", name="AFTER")
    probe = fb.probe("seq")
    fb.connect(loop, probe, "tail")
    fb.connect(probe, end)
    return fb


def seq_of(run):
    """The list seq the probe at the end of the loop saw (empty when no pass added anything)."""
    probe = run.seen["seq"]
    return [] if probe.type == "<missing>" else json.loads(probe.text)


def passed(run):
    return run.reason == "finished" and not run.exceptions and "AFTER" in run.names


def test_files_only_are_passed_and_not_the_folders_of_the_pattern(flows, tmp_path):
    root = tree(tmp_path / "files")
    runs = run_all(flows, [loop_flow("files_only", root / "*", "Files")])
    assert passed(runs[0]), (runs[0].reason, runs[0].exceptions)
    assert sorted(seq_of(runs[0])) == ["a.txt", "b.log"]


def test_recursion_passes_the_files_of_the_subfolders(flows, tmp_path):
    root = tree(tmp_path / "recursive")
    runs = run_all(flows, [loop_flow("recursive", root / "*.txt", "Files", recurse=1)])
    assert passed(runs[0]), (runs[0].reason, runs[0].exceptions)
    assert sorted(seq_of(runs[0])) == ["a.txt", "c.txt"]


def test_folders_and_files_and_folders_only(flows, tmp_path):
    root = tree(tmp_path / "kinds")
    runs = run_all(flows, [
        loop_flow("folders_only", root / "*", "Folders"),
        loop_flow("files_and_folders", root / "*", "FilesAndFolders"),
    ])
    assert passed(runs[0]) and passed(runs[1]), [(r.reason, r.exceptions) for r in runs]
    assert seq_of(runs[0]) == ["sub"]
    assert sorted(seq_of(runs[1])) == ["a.txt", "b.log", "sub"]


def test_a_pattern_without_a_match_gives_no_pass_and_the_loop_is_left(flows, tmp_path):
    root = tree(tmp_path / "empty_match")
    runs = run_all(flows, [loop_flow("no_match", root / "*.none", "Files")])
    assert passed(runs[0]), (runs[0].reason, runs[0].exceptions)
    assert seq_of(runs[0]) == []


def test_loop_variables_of_the_file_are_set_in_every_pass(flows, tmp_path):
    root = tree(tmp_path / "vars")
    runs = run_all(flows, [loop_flow("loop_vars", root / "a.txt", "Files",
                                     body_text="%A_LoopFileNameNoExt%|%A_LoopFileExt%|%A_LoopFileSize%")])
    assert passed(runs[0]), (runs[0].reason, runs[0].exceptions)
    assert seq_of(runs[0]) == ["a|txt|3"]


def test_break_leaves_the_loop_at_the_chosen_pass(flows, tmp_path):
    root = tree(tmp_path / "brk")
    runs = run_all(flows, [loop_flow("break_second", root / "*", "Files", break_at=2)])
    assert passed(runs[0]), (runs[0].reason, runs[0].exceptions)
    assert len(seq_of(runs[0])) == 1


def test_files_created_in_the_body_do_not_change_the_passes(flows, tmp_path):
    root = tree(tmp_path / "snapshot")
    fb = FlowBuilder("snapshot")
    loop = fb.loop("Loop_Loop_Through_Files", file=str(root / "*"), OperateOnWhat="Files", Recurse=0)
    fb.connect(fb.trigger(), loop)
    write = fb.action("Action_Write_To_File", text="new", file=str(root / "new.txt"), Overwrite="Overwrite",
                      Linefeed=0, name="WRITE NEW")
    add = add_to_list(fb, "%A_LoopFileName%")
    fb.connect(loop, write, "head")
    fb.connect(write, add)
    fb.connect(add, loop, into="tail")
    end = fb.action("Action_Do_nothing", name="AFTER")
    probe = fb.probe("seq")
    fb.connect(loop, probe, "tail")
    fb.connect(probe, end)
    runs = run_all(flows, [fb])
    assert passed(runs[0]), (runs[0].reason, runs[0].exceptions)
    assert sorted(seq_of(runs[0])) == ["a.txt", "b.log"]
    assert (root / "new.txt").exists()
