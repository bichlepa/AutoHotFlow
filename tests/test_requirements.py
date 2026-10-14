"""Requirements document: doc/REQUIREMENTS.md keeps its format and doc/REQUIREMENTS-INDEX.md is up to date.

The first test fails with the format errors of the source or with the hint to run tools/req_index.py. The
other tests feed small example texts to the parser of the tool.
"""

import io
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent.parent / "tools"
sys.path.insert(0, str(TOOLS_DIR))
import req_index  # noqa: E402

GOOD = """\
- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/x.py`
"""


def doc(*reqs, area="## Flows (EXE)"):
    return "# Requirements\n\n" + area + "\n\n" + "\n".join(reqs)


def req(rid="REQ-EXE-010", title="Something", meta=GOOD, body="Text.\n"):
    return "### %s %s\n\n%s\n%s" % (rid, title, meta, body)


def errors(text):
    return req_index.parse(text)[1]


def test_requirements_document_is_valid_and_the_index_is_up_to_date():
    out = io.StringIO()
    code = req_index.run(check=True, out=out)
    assert code == 0, out.getvalue()


def test_a_valid_requirement_is_parsed_with_its_fields():
    areas, errs = req_index.parse(doc(req(body="- a list item in the text\n- **Note:** not a field\n")))
    assert errs == []
    (area,) = areas
    assert (area.title, area.code) == ("Flows", "EXE")
    (r,) = area.reqs
    assert (r.id, r.title, r.word("v2"), r.meta["Evidence"]) == ("REQ-EXE-010", "Something", "done", "`tests/x.py`")


def test_a_note_after_the_first_word_is_allowed():
    meta = GOOD.replace("- **v1:** yes", "- **v1:** partial (wait broken, M-11)")
    areas, errs = req_index.parse(doc(req(meta=meta)))
    assert errs == [] and areas[0].reqs[0].word("v1") == "partial"


def test_missing_field_unknown_field_and_bad_word_are_reported():
    assert any("'Plan' missing" in e for e in errors(doc(req(meta=GOOD.replace("- **Plan:** -\n", "")))))
    assert any("unknown field 'Owner'" in e for e in errors(doc(req(meta=GOOD + "- **Owner:** me\n"))))
    assert any("v2 must start with" in e for e in errors(doc(req(meta=GOOD.replace("v2:** done", "v2:** finished")))))
    assert any("field 'Prio' twice" in e for e in errors(doc(req(meta=GOOD + "- **Prio:** could\n"))))


def test_done_needs_evidence():
    meta = GOOD.replace("- **Evidence:** `tests/x.py`\n", "")
    assert any("needs an Evidence" in e for e in errors(doc(req(meta=meta))))
    assert errors(doc(req(meta=meta.replace("v2:** done", "v2:** open")))) == []


def test_id_rules():
    assert any("its code must be EXE" in e for e in errors(doc(req(rid="REQ-MGR-010"))))
    assert any("used twice" in e for e in errors(doc(req(), req(title="Other"))))
    assert any("not inside an area" in e for e in errors("# R\n\n## Format\n\n" + req()))
    assert any("must be '### REQ-XXX-nnn Title'" in e for e in errors(doc("### REQ-EXE-10 Short number\n")))
    assert any("area code EXE used twice" in e for e in errors(doc(req()) + "\n## Again (EXE)\n"))


def test_requirement_headings_in_code_blocks_are_ignored():
    example = "```markdown\n### REQ-EXE-010 Example\n\n- **v2:** whatever\n```\n"
    text = "# R\n\n## Format\n\n" + example + "\n## Flows (EXE)\n\n" + req()
    areas, errs = req_index.parse(text)
    assert errs == [] and [r.title for r in areas[0].reqs] == ["Something"]


def test_slug_matches_the_github_anchor():
    assert req_index.slug("REQ-EXE-010 Execution policy per flow") == "req-exe-010-execution-policy-per-flow"
    assert req_index.slug("Flows and execution (EXE)") == "flows-and-execution-exe"
    assert req_index.slug("REQ-VAR-020 `global` and `static`, kept") == "req-var-020-global-and-static-kept"


def test_index_has_summary_counts_links_and_escaped_cells():
    areas, _ = req_index.parse(doc(req(title="A | B"), req(rid="REQ-EXE-020", meta=GOOD.replace("done", "open"))))
    text = req_index.render(areas)
    assert "| [Flows (EXE)](#flows-exe) | 2 | 1 | 0 | 0 | 1 | 0 | 0 |" in text
    assert "[REQ-EXE-010](REQUIREMENTS.md#req-exe-010-a--b) | A \\| B | yes | done |" in text


def test_a_requirement_in_doubt_is_marked_and_counted():
    areas, errs = req_index.parse(doc(req(meta=GOOD + "- **Doubt:** keep this syntax?\n")))
    assert errs == []
    text = req_index.render(areas)
    assert "| [Flows (EXE)](#flows-exe) | 1 | 1 | 0 | 0 | 0 | 0 | 1 |" in text
    assert "| Something *(in doubt)* | yes | done |" in text


def evidence_errors(tmp_path, evidence):
    (tmp_path / "tests").mkdir(exist_ok=True)
    (tmp_path / "tests" / "x.py").write_text("def test_a():\n    pass\n", encoding="utf-8")
    (tmp_path / "tests" / "y_1.test.ahk").write_text("", encoding="utf-8")
    meta = GOOD.replace("`tests/x.py`", evidence)
    areas, errs = req_index.parse(doc(req(meta=meta)))
    assert errs == []
    return req_index.check_evidence(areas, tmp_path)


def test_evidence_paths_and_test_names_must_exist(tmp_path):
    assert evidence_errors(tmp_path, "`tests/x.py`, `tests/x.py::test_a`, `tests/y_*.test.ahk`, `tests/`") == []
    assert evidence_errors(tmp_path, "the `*_policy_*` tests, measurement M-01") == []   # not a path: not checked
    assert any("'tests/z.py' does not exist" in e for e in evidence_errors(tmp_path, "`tests/z.py`"))
    assert any("'tests/q_*.ahk' does not exist" in e for e in evidence_errors(tmp_path, "`tests/q_*.ahk`"))
    assert any("'test_b' not found" in e for e in evidence_errors(tmp_path, "`tests/x.py::test_b`"))


def test_command_line_writes_checks_and_rejects(tmp_path):
    source, index = tmp_path / "REQUIREMENTS.md", tmp_path / "REQUIREMENTS-INDEX.md"
    source.write_text(doc(req()), encoding="utf-8")
    (tmp_path / "tests").mkdir()
    (tmp_path / "tests" / "x.py").write_text("", encoding="utf-8")
    args = ["--source", str(source), "--index", str(index), "--repo", str(tmp_path)]
    assert req_index.main(args + ["--check"]) == 1          # no index yet
    assert req_index.main(args) == 0 and index.exists()
    assert req_index.main(args + ["--check"]) == 0
    index.write_bytes(index.read_bytes().replace(b"\n", b"\r\n"))
    assert req_index.main(args + ["--check"]) == 0          # line ends of the checkout do not matter
    source.write_text(doc(req(title="Renamed")), encoding="utf-8")
    assert req_index.main(args + ["--check"]) == 1          # source changed, index outdated
    source.write_text(doc(req(rid="REQ-XYZ-010")), encoding="utf-8")
    assert req_index.main(args) == 1                        # format error: nothing written
    source.write_text(doc(req(meta=GOOD.replace("tests/x.py", "tests/gone.py"))), encoding="utf-8")
    assert req_index.main(args) == 1                        # missing evidence
