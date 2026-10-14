"""Compares the golden data of v1 with the new expression language (WI-39, doc/EXPRESSION-LANGUAGE.md section 15).

`plain`: the unchanged v1 text is evaluated by the new evaluator. Every case that does not give the v1 result must have
a class of the deviation catalog (tools/golden_classes.py). `convert`: the text is converted first
(src/expr/V1ExprConverter.ahk); then no case may be left in a class of the handling `rewrite`.
The comparison and the classes are in tools/golden_compare.py and tools/golden_classes.py.
"""

import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

import golden_classes  # noqa: E402
import golden_compare  # noqa: E402


@pytest.fixture(scope="module")
def plain_rows():
    return golden_compare.compare(mode="plain")


def verdicts(rows):
    return golden_compare.summary(rows)


def test_every_deviation_of_the_unchanged_text_has_a_class(plain_rows):
    open_cases = [(r["id"], r["text"], r["detail"]) for r in plain_rows if r["verdict"] == "open"]
    assert not open_cases, "deviations without a class: %r" % open_cases[:10]
    unknown = set(verdicts(plain_rows)) - set(golden_classes.CLASSES) - {"same"}
    assert not unknown, "verdicts that are not in CLASSES: %s" % sorted(unknown)


def test_the_catalog_covers_all_kinds_of_cases(plain_rows):
    counts = verdicts(plain_rows)
    assert len(plain_rows) > 1000
    assert counts["same"] > 600
    # every class is used (a class without a case is dead weight in the catalog)
    unused = set(golden_classes.CLASSES) - set(counts)
    assert not unused, "classes without a case: %s" % sorted(unused)


@pytest.fixture(scope="module")
def converted_rows():
    return golden_compare.compare(mode="convert")


def test_after_the_conversion_no_case_is_left_in_a_rewrite_class(converted_rows):
    open_cases = [(r["id"], r["text"], r["detail"]) for r in converted_rows if r["verdict"] == "open"]
    assert not open_cases, "deviations without a class: %r" % open_cases[:10]
    rewrite = [r["id"] for r in converted_rows if golden_classes.CLASSES.get(r["verdict"], ("",))[0] == "rewrite"]
    assert not rewrite, "the converter should have fixed these cases: %s" % rewrite[:10]


def test_the_conversion_makes_the_rewrite_cases_agree_with_v1(plain_rows, converted_rows):
    rewrite = [r["id"] for r in plain_rows if golden_classes.CLASSES.get(r["verdict"], ("",))[0] == "rewrite"]
    assert len(rewrite) >= 6
    converted = {r["id"]: r["verdict"] for r in converted_rows}
    assert all(converted[i] == "same" for i in rewrite), [i for i in rewrite if converted[i] != "same"]


def test_converted_texts_convert_to_themselves(converted_rows):
    bad = [r["id"] for r in converted_rows if not r["conv"]["idempotent"]]
    assert not bad, "converting twice changes the text: %s" % bad[:10]


def test_unsupported_syntax_is_reported_and_left_unchanged(converted_rows):
    cases = [r for r in converted_rows if r["verdict"] == "unsupported syntax"]
    assert len(cases) >= 6
    for r in cases:
        assert r["conv"]["status"] == "unsupported", r["id"]
        assert r["conv"]["text"] == r["text"], r["id"]
        assert r["conv"]["messages"], r["id"]


def test_a_text_is_only_changed_when_a_rule_says_so(converted_rows):
    for r in converted_rows:
        conv = r["conv"]
        assert (conv["text"] != r["text"]) == (conv["status"] == "converted"), r["id"]
        if conv["status"] == "converted":
            assert conv["changes"], r["id"]
        else:
            assert not conv["changes"], r["id"]
