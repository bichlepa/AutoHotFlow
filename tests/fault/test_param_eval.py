"""WI-42: parameter evaluation end to end, the same flow inline and in a worker.

Under the real supervisor (storage, engine with its worker pool, UI stub), as tests/fault/test_var_persistence.py; the
chain helpers of this folder are used, but this is no fault test. The test element Action_TestExprParams evaluates its
parameters in the engine (ctx.EvalParams on call); its twin Action_TestExprParamsWorker runs in a worker process and
gets them evaluated by the engine before the job (E26, the field "evaluated" of cmd.worker.run). Both leave the result
in the global variable global_evalresult_<tag>, which the engine writes to Variables/ (WI-41). An error ends the element
with exception; its message comes with evt.element.state. Global variables for the expressions are given as variable
files. The rules per content type are covered by tests/ahk/element_evalparams.test.ahk.
"""

import json
from pathlib import Path

import pytest

from faultkit import FULL_CHAIN, STUB_OPTS, event, request_ok, wait_until, write_flow
from faultfixtures import chains  # noqa: F401  (fixture)
from support.timing import scaled

pytestmark = pytest.mark.slow

READY_S = 20.0
FILE_S = scaled(8.0)

INLINE = "Action_TestExprParams"
WORKER = "Action_TestExprParamsWorker"

GLOBALS = {"global_n": ("normal", "5"), "global_t": ("normal", "text"),
           "global_obj": ("object", json.dumps({"k": "v", "list": [1, 2]}))}

VALUES = {"Expr": "global_n * 2", "Num": "global_n / 2", "Int": "global_n + 1", "PosInt": "global_n",
          "Text": "a %global_t% b", "Json": "%global_obj%", "VarName": "v%global_n%", "Raw": "%global_t%",
          "File": "sub\\%global_t%.txt", "Folder": "C:\\abs", "Either": "global_obj.list.2", "EitherType": "expression",
          "Condition": "x = 1"}


def write_globals(datadir):
    folder = Path(datadir) / "Variables"
    folder.mkdir(exist_ok=True)
    for name, (kind, content) in GLOBALS.items():
        (folder / (name + ".ahfvd")).write_text(json.dumps({"name": name, "type": kind}), encoding="utf-8")
        (folder / (name + ".ahfvar")).write_text(content, encoding="utf-8")


def flow(datadir, name, cls, pars, strict=False):
    """A flow with the test element; formatVersion 2 (no conversion of v1 texts) and the type mode."""
    write_flow(datadir, name, cls, pars)
    path = Path(datadir) / "Flows" / (name + ".json")
    data = json.loads(path.read_text(encoding="utf-8"))
    data["formatVersion"] = 2
    data["flowSettings"]["strictTypes"] = bool(strict)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def run(chain, name, timeout=15.0):
    """Starts the flow and returns (reason of evt.instance.ended, message of the exception of the test element)."""
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "flow:" + name})
    started = request_ok(chain.obs, "engine", "cmd.flow.start", {"flowId": name})
    ended = chain.rec.wait(event("evt.instance.ended", instanceId=started["instanceId"]), scaled(timeout))
    assert ended is not None, "instance of '%s' did not end:\n%s" % (name, chain.sup.text())
    failed = chain.rec.find(lambda m: m.get("type") == "evt.element.state"
                            and m["payload"].get("flowId") == name and m["payload"].get("state") == "exception")
    message = failed[-1][1]["payload"].get("message", "") if failed else ""
    return ended[1]["payload"]["reason"], message


def result(datadir, tag):
    """The report of the test element: id -> {type, value}, read from the variable file."""
    path = Path(datadir) / "Variables" / ("global_evalresult_%s.ahfvar" % tag)
    assert wait_until(lambda: path.exists() and path.stat().st_size > 0, FILE_S), "no result for %s" % tag

    def parsed():
        try:
            return json.loads(path.read_bytes().decode("utf-8-sig"))
        except ValueError:
            return None
    report = wait_until(parsed, FILE_S)
    assert report is not None, path.read_bytes()
    return report


def test_the_same_parameters_give_the_same_result_inline_and_in_a_worker(chains, datadir):
    write_globals(datadir)
    flows = {
        "values_in": (INLINE, dict(VALUES, Tag="values_in")),
        "values_wk": (WORKER, dict(VALUES, Tag="values_wk")),
        "error_in": (INLINE, {"Int": "global_n / 2", "Tag": "error_in"}),
        "error_wk": (WORKER, {"Int": "global_n / 2", "Tag": "error_wk"}),
        "skip_in": (INLINE, {"Int": "global_n / 2", "Skip": "Int", "Tag": "skip_in"}),
        "skip_wk": (WORKER, {"Int": "global_n / 2", "Skip": "Int", "Tag": "skip_wk"}),
    }
    for name, (cls, pars) in flows.items():
        flow(datadir, name, cls, pars)
    for name in ("compat_in", "compat_wk", "strict_in", "strict_wk"):
        cls = INLINE if name.endswith("_in") else WORKER
        flow(datadir, name, cls, {"Expr": "global_t + 1", "Tag": name}, strict=name.startswith("strict"))
    chain = chains(FULL_CHAIN, STUB_OPTS)
    # evt.engine.ready comes after the variables are loaded (WI-41); the flows alone are loaded earlier
    assert chain.rec.wait(event("evt.engine.ready"), READY_S) is not None, chain.sup.text()

    # values: the same report from both, and the expected values
    assert run(chain, "values_in") == ("finished", "")
    assert run(chain, "values_wk") == ("finished", "")
    inline, worker = result(datadir, "values_in"), result(datadir, "values_wk")
    assert inline == worker
    assert inline["Expr"] == {"type": "Integer", "value": 10}
    assert inline["Num"] == {"type": "Float", "value": 2.5}
    assert inline["Int"] == {"type": "Integer", "value": 6}
    assert inline["Text"]["value"] == "a text b"
    assert json.loads(inline["Json"]["value"]) == {"k": "v", "list": [1, 2]}
    assert inline["VarName"]["value"] == "v5"
    assert inline["Raw"]["value"] == "%global_t%"
    assert inline["File"]["value"].endswith("\\AutoHotFlow\\sub\\text.txt")
    assert inline["Folder"]["value"] == "C:\\abs"
    assert inline["Either"] == {"type": "Integer", "value": 2}
    assert "Pick" not in inline

    # an error: the same message inline and in the worker; skipped, the same parameter is no error
    reason_in, message_in = run(chain, "error_in")
    reason_wk, message_wk = run(chain, "error_wk")
    assert message_in == "Result of expression 'global_n / 2' is not an integer"
    assert message_wk == message_in
    assert run(chain, "skip_in") == ("finished", "")
    assert run(chain, "skip_wk") == ("finished", "")
    assert result(datadir, "skip_in") == result(datadir, "skip_wk")
    assert "Int" not in result(datadir, "skip_wk")

    # the type mode of the flow: compatibility mode gives the empty text, strict mode ends the element
    assert run(chain, "compat_in") == ("finished", "")
    assert run(chain, "compat_wk") == ("finished", "")
    assert result(datadir, "compat_in")["Expr"] == {"type": "String", "value": ""}
    assert result(datadir, "compat_wk")["Expr"] == {"type": "String", "value": ""}
    _, strict_in = run(chain, "strict_in")
    _, strict_wk = run(chain, "strict_wk")
    assert strict_in.startswith("An error occured while parsing expression 'global_t + 1'"), strict_in
    assert "'+' failed" in strict_in, strict_in
    assert strict_wk == strict_in
