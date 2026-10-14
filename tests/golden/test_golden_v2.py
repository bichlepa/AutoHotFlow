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
