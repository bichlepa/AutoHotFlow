"""Oracle of the expression language (WI-44, E35, doc/TEST-STRATEGY.md section 8): native AutoHotkey v2 against the
evaluator. The fixed corpus (tests/oracle/corpus.jsonl) runs in the fast tier; a long run with a random seed is `slow`.
The generator, the native script and the list of deliberate deviations are in tools/expr_oracle.py.
"""

import os
import random
import sys
import time
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

import expr_oracle  # noqa: E402


@pytest.fixture(scope="module")
def corpus_rows():
    cases = expr_oracle.read_corpus()
    start = time.monotonic()
    rows = expr_oracle.run_cases(cases)
    return cases, rows, time.monotonic() - start


def describe_open(rows, limit=15):
    return "\n".join("%s: %s\n    %s" % (r["id"], r["text"], r["detail"])
                     for r in [r for r in rows if r["verdict"] == "OPEN"][:limit])


@pytest.mark.xdist_group("expr_oracle")
def test_the_fixed_corpus_agrees_with_native_autohotkey(corpus_rows):
    cases, rows, _ = corpus_rows
    assert len(cases) >= 3000
    assert len(rows) == len(cases)
    assert not [r for r in rows if r["verdict"] == "OPEN"], \
        "deviations without an entry in CLASSES (tools/expr_oracle.py):\n" + describe_open(rows)


@pytest.mark.xdist_group("expr_oracle")
def test_every_deviation_class_has_a_case(corpus_rows):
    _, rows, _ = corpus_rows
    counts = expr_oracle.summary(rows)
    unused = [c for c in expr_oracle.CLASSES if not any(v == c or c in v.split(" + ") for v in counts)]
    assert not unused, "classes without a case in the corpus: %s (counts: %s)" % (unused, counts)
    assert counts.get("same", 0) > 1500, counts      # most cases must agree without any deviation


@pytest.mark.xdist_group("expr_oracle")
def test_the_corpus_has_both_error_classes_and_all_value_types(corpus_rows):
    _, rows, _ = corpus_rows
    error_classes = {r["native"]["class"] for r in rows if not r["native"]["ok"]}
    assert {"TypeError", "ZeroDivisionError"} <= error_classes, error_classes
    types = {r["native"]["type"] for r in rows if r["native"]["ok"]}
    assert {"Integer", "Float", "String"} <= types, types


@pytest.mark.xdist_group("expr_oracle")
def test_the_fixed_corpus_runs_in_its_time_budget(corpus_rows):
    _, _, seconds = corpus_rows
    assert seconds < 15, "the oracle needs %.1f s (target under 10 s)" % seconds


def test_the_generator_is_reproducible_and_the_corpus_is_the_generator_output():
    first = expr_oracle.generate(5, 200)
    assert first == expr_oracle.generate(5, 200)
    assert first != expr_oracle.generate(6, 200)
    corpus = expr_oracle.read_corpus()
    texts = [c["t"] for c in corpus]
    assert len(texts) == len(set(texts)), "the corpus has duplicates"
    # the checked-in corpus is what --write-corpus --seed 1 --count 3000 writes
    hand = expr_oracle.hand_cases_full()
    assert corpus[:len(hand)] == hand
    assert corpus[len(hand):len(hand) + 50] == [c for c in expr_oracle.generate(1, 3000) if c["t"] not in
                                                {h["t"] for h in hand}][:50]


def test_the_model_applies_only_the_listed_deviations():
    case = expr_oracle.case_of_text("i16 / i2 . \"\"")
    assert case["m"] == "D(i16, i2) . \"\"" and case["r"] == ["E29"]
    case = expr_oracle.case_of_text("12345678901234567890 + 1")
    assert case["m"] == "12345678901234567890.0 + 1" and case["r"] == ["literal beyond 63 bits"]
    assert "m" not in expr_oracle.case_of_text("i1 + 2 * i3")


def test_the_oracle_notices_a_wrong_evaluator_result():
    """classify() must not hide a difference: a wrong value without an entry is OPEN."""
    case = {"t": "i1 + 1"}
    raw = {"ok": True, "type": "Integer", "text": "2"}
    good = {"type": "Integer", "text": "2", "errors": [], "warnings": [], "missing": []}
    assert expr_oracle.classify(case, raw, None, good)[0] == "same"
    assert expr_oracle.classify(case, raw, None, dict(good, text="3"))[0] == "OPEN"
    assert expr_oracle.classify(case, raw, None, dict(good, type="Float"))[0] == "OPEN"
    assert expr_oracle.classify(case, raw, None, dict(good, warnings=["'+' failed: x"]))[0] == "OPEN"
    err = {"ok": False, "class": "TypeError", "message": "Expected a Number but got a String."}
    warn = {"type": "String", "text": "", "errors": [], "warnings": ["'+' failed: Expected a Number but got a String."],
            "missing": []}
    assert expr_oracle.classify(case, err, None, warn)[0] == "E25"
    assert expr_oracle.classify(case, err, None, dict(warn, warnings=["'+' failed: other message"]))[0] == "OPEN"
    assert expr_oracle.classify(case, err, None, dict(warn, errors=["boom"]))[0] == "OPEN"
    assert expr_oracle.classify(case, err, None, good)[0] == "OPEN"        # native fails, evaluator does not
    # a deviation needs the model to agree: the same value as the model, or it is still OPEN
    div = {"t": "4 / 2", "m": "D(4, 2)", "r": ["E29"]}
    native = {"ok": True, "type": "Float", "text": "2.0"}
    model = {"ok": True, "type": "Integer", "text": "2"}
    ev = {"type": "Integer", "text": "2", "errors": [], "warnings": [], "missing": []}
    assert expr_oracle.classify(div, native, model, ev)[0] == "E29"
    assert expr_oracle.classify(div, native, model, dict(ev, text="3"))[0] == "OPEN"


@pytest.mark.slow
@pytest.mark.xdist_group("expr_oracle_random")
def test_a_random_run_shows_no_deviation_without_an_entry():
    """20,000 generated cases with a random seed (AHF_ORACLE_SEED fixes it). A failing seed is in the message."""
    seed = int(os.environ.get("AHF_ORACLE_SEED") or random.randrange(1, 10 ** 6))
    count = 20000
    rows = expr_oracle.run_cases(expr_oracle.hand_cases_full() + expr_oracle.generate(seed, count))
    bad = [r for r in rows if r["verdict"] == "OPEN"]
    assert not bad, "seed %d, count %d (reproduce: python tools/expr_oracle.py --seed %d --count %d):\n%s" % (
        seed, count, seed, count, describe_open(rows))
