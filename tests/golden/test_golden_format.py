"""Checks the golden data of v1 (WI-36): every case file has a result file, and both follow the format.

The comparison with v2 comes with the converter (WI-39). The tests here need neither the v2 interpreter nor v1,
except `test_a_sample_of_cases_is_reproduced_by_the_v1_interpreter`, which runs a few cases in the v1 interpreter
and compares them with the checked-in results (it is skipped when v1/ is gone after the port).
"""

import json
import os
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

import golden_corpus  # noqa: E402
import golden_v1  # noqa: E402

CASES = REPO / "tests" / "golden" / "cases"
EXPECTED = REPO / "tests" / "golden" / "expected"

# the groups of work item WI-36, task 4
REQUIRED_GROUPS = ["arithmetic", "division", "comparison", "logic", "concat", "numbers", "strings", "variables",
                   "assignment", "functions", "errors", "script", "replace", "builtin", "varaccess", "names", "objects",
                   "corpus_flows"]


def case_files():
    return sorted(p.stem for p in CASES.glob("*.json"))


def test_the_required_groups_exist():
    assert set(REQUIRED_GROUPS) <= set(case_files())


def test_case_files_follow_the_format():
    groups = golden_v1.load_case_files(str(CASES))     # raises ValueError with the case id on a format error
    assert set(groups) == set(case_files())
    for name, data in groups.items():
        assert data["cases"], "%s has no cases" % name


@pytest.mark.parametrize("group", case_files())
def test_every_case_file_has_a_result_file_in_the_right_format(group):
    expected = EXPECTED / (group + ".json")
    assert expected.is_file(), "no result file for the case file %s.json (run tools/golden_v1.py)" % group
    with open(CASES / (group + ".json"), encoding="utf-8") as f:
        case_data = json.load(f)
    with open(expected, encoding="utf-8") as f:
        data = json.load(f)
    problems = golden_v1.check_result_file(data, case_data)
    assert not problems, "\n".join(problems[:20])


def test_there_are_no_result_files_without_case_file():
    assert sorted(p.stem for p in EXPECTED.glob("*.json")) == case_files()


def test_volatile_results_hold_no_value():
    for path in EXPECTED.glob("*.json"):
        with open(path, encoding="utf-8") as f:
            for cid, result in json.load(f)["results"].items():
                if result.get("volatile"):
                    assert set(result) <= {"id", "kind", "outcome", "volatile", "value"}, cid
                    assert result.get("value", {}).get("value", golden_v1.VOLATILE) == golden_v1.VOLATILE, cid


def test_the_check_compares_content_and_not_line_endings(tmp_path):
    # a Windows working copy has CRLF, the generated text is LF: the same content must count as unchanged
    source = EXPECTED / "arithmetic.json"
    with open(source, encoding="utf-8", newline="") as f:
        text = f.read()
    assert "\r" not in text.replace("\r\n", "")
    generated = text.replace("\r\n", "\n")
    crlf = tmp_path / "crlf.json"
    with open(crlf, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(generated)
    assert b"\r\n" in crlf.read_bytes()
    assert golden_v1.differs_from_checked_in(str(crlf), generated) is False
    changed = tmp_path / "changed.json"
    with open(changed, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(generated.replace("1.1.32", "1.1.31", 1))
    assert golden_v1.differs_from_checked_in(str(changed), generated) is True
    assert golden_v1.differs_from_checked_in(str(tmp_path / "missing.json"), generated) is True


def test_the_result_files_name_the_v1_interpreter_they_come_from():
    with open(EXPECTED / "arithmetic.json", encoding="utf-8") as f:
        interpreter = json.load(f)["interpreter"]
    assert interpreter["ahkVersion"].startswith("1.1.32"), interpreter
    assert interpreter["ptrSize"] == 4      # 32 bit, as the application is delivered


def test_typed_values_keep_numbers_apart_from_text():
    assert golden_v1.typed(5) == {"t": "n", "v": "5"}
    assert golden_v1.typed(0.5) == {"t": "n", "v": "0.5"}
    assert golden_v1.typed("5") == {"t": "s", "v": "5"}
    assert golden_v1.typed({"a": 1}) == {"t": "o", "v": {"a": 1}}
    assert golden_v1.typed([1, 2]) == {"t": "o", "v": [1, 2]}
    with pytest.raises(ValueError):
        golden_v1.check_value(True, "x")


def test_a_case_with_an_unknown_field_is_refused():
    with pytest.raises(ValueError):
        golden_v1.check_case({"id": "x", "kind": "expression", "text": "1", "typo": 1}, "t")
    with pytest.raises(ValueError):
        golden_v1.check_case({"id": "x", "kind": "nonsense", "text": "1"}, "t")
    with pytest.raises(ValueError):
        golden_v1.check_case({"id": "x", "kind": "expression", "text": "1", "vars": {"nowhere": {}}}, "t")


def test_a_result_file_that_misses_a_case_is_reported():
    case_data = {"group": "g", "cases": [{"id": "g.a", "kind": "expression", "text": "1"}]}
    problems = golden_v1.check_result_file({"group": "g", "results": {}}, case_data)
    assert any("no result for case g.a" in p for p in problems)


def test_the_findings_name_existing_cases():
    ids = set()
    for path in EXPECTED.glob("*.json"):
        with open(path, encoding="utf-8") as f:
            ids.update(json.load(f)["results"])
    with open(REPO / "tests" / "golden" / "FINDINGS.md", encoding="utf-8") as f:
        text = f.read()
    assert text.count("\n### S") >= 6
    cited = []
    for line in text.splitlines():
        if line.startswith("Cases: "):
            cited.extend(line.split("`")[1::2])
    assert cited
    for cid in cited:
        assert cid in ids, "FINDINGS.md: no such case %s" % cid


# ---- the corpus tool (pure functions, no v1 needed) ----

def test_corpus_variables_get_missing_number_and_text_variants():
    builtins = {"a_index", "a_now", "a_space"}
    result = golden_corpus.variants("expression", 'x + a_index > y.k and "z"', builtins)
    names = [v[0] for v in result]
    assert names == ["missing", "num", "txt"]
    num = result[1][1]
    assert set(num["instance"]) == {"x", "y"}
    assert "k" in num["instance"]["y"] and num["instance"]["x"] == 2
    assert result[0][2] is True      # a_index is built-in and not stable: volatile


def test_corpus_values_without_variables_have_one_case():
    assert [v[0] for v in golden_corpus.variants("expression", '1 + 2 and "x y"', set())] == ["plain"]
    assert [v[0] for v in golden_corpus.variants("replace", "100% of nothing", set())] == ["plain"]


def test_corpus_finds_variables_in_percent_signs():
    refs = golden_corpus.references("replace", "a %x% b %list.1% c")
    assert set(refs) == {"x", "list"}


def test_corpus_picks_the_content_type_of_a_parameter():
    spec = {"ids": ["p"], "type": "edit", "content": ["string", "expression"], "contentID": "p_content"}
    assert golden_corpus.decide_kinds(spec, {"p_content": "Expression"}, set())[0] == ["expression"]
    assert golden_corpus.decide_kinds(spec, {"p_content": "string"}, set())[0] == ["replace"]
    assert golden_corpus.decide_kinds(spec, {}, set())[0] == ["expression", "replace"]
    assert golden_corpus.decide_kinds({"ids": ["p"], "type": "edit", "content": ["variablename"], "contentID": None},
                                      {}, set())[0] == ["checkname", "replace"]
    assert golden_corpus.decide_kinds({"ids": ["p"], "type": "edit", "content": ["rawstring"], "contentID": None},
                                      {}, set())[0] == []
    assert golden_corpus.decide_kinds({"ids": ["p"], "type": "file", "content": [], "contentID": None},
                                      {}, set())[0] == ["replace"]
    assert golden_corpus.decide_kinds(None, {}, set())[0] == ["expression", "replace"]


# ---- the v1 interpreter itself ----

SAMPLE = ["arithmetic.add.int", "division.exact", "comparison.eq.case", "logic.oror.value.text",
          "variables.object.dot", "assignment.script.set.number", "replace.two", "script.if.else.false",
          "strings.escape.n", "errors.unclosed.paren", "names.check.space.inside", "varaccess.set.global.object"]


@pytest.mark.skipif(not os.path.isfile(golden_v1.V1_EXE), reason="v1/ is gone")
def test_a_sample_of_cases_is_reproduced_by_the_v1_interpreter(tmp_path):
    groups = golden_v1.load_case_files(str(CASES))
    cases = [c for g in groups.values() for c in g["cases"] if c["id"] in SAMPLE]
    assert len(cases) == len(SAMPLE)
    raw, header = golden_v1.run_cases(cases, str(tmp_path))
    for case in cases:
        group = case["id"].split(".")[0]
        with open(EXPECTED / (group + ".json"), encoding="utf-8") as f:
            stored = json.load(f)["results"][case["id"]]
        assert golden_v1.finish_result(case, raw[case["id"]]) == stored, case["id"]
