"""WI-0077: the global settings in real sessions (supervisor, storage, engine, and for the language the tray role).

REQ-SET-010 (model), REQ-SET-020, REQ-SET-050, REQ-SET-070, REQ-EXE-050, REQ-EXE-130, REQ-EXE-170 (global defaults),
REQ-LNG-010, REQ-LNG-020, REQ-USE-010 (setting), PROTOCOL 4.2 "Settings", 4.3 evt.settings.changed, 4.6 Settings.json.

The checks of every key are in tests/ahk/core_settings.test.ahk. Here the settings go through the real messages: a change
is written, announced and takes effect at once (policy, working directory, limits, log thresholds, language in two roles,
number of workers), survives a restart, and a broken file is kept and replaced by the defaults.
"""

import json
import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner, flows  # noqa: F401  (fixture)
from support.timing import scaled

WAIT_S = scaled(8.0)
LIMIT_S = scaled(60.0)
SHOWN_ROLES = "storage,engine,tray"
KEYS = {"language", "executionPolicy", "workingDir", "workers", "logLevelApp", "logLevelFlow", "logLevelThread",
        "maxExecutionsPerMinute", "maxWaitingInstances", "maxParallelInstances", "userLevel", "notifyUnhandledErrors",
        "startWithWindows", "runAsAdmin", "windowPositions", "helpViewer"}


def wait_for(predicate, timeout=WAIT_S):
    deadline = time.monotonic() + timeout
    while True:
        value = predicate()
        if value:
            return value
        if time.monotonic() > deadline:
            return None
        time.sleep(0.05)


def get(runner):
    return runner.request_ok("engine", "cmd.settings.get", {})["settings"]


def put(runner, **values):
    return runner.request_ok("engine", "cmd.settings.set", {"settings": values})


def refused(runner, **values):
    answer = runner.request("engine", "cmd.settings.set", {"settings": values})
    assert answer["ok"] is False, answer
    return answer["error"]


def on_disk(runner):
    return json.loads((runner.datadir / "Settings.json").read_text(encoding="utf-8-sig"))


def log_text(runner):
    path = runner.datadir / "Log" / "Log.txt"
    return path.read_text(encoding="utf-8-sig") if path.exists() else ""


def subscribe(runner, topic):
    runner.request_ok("supervisor", "cmd.topic.subscribe", {"topic": topic})


def snapshot(runner, name):
    return runner.request_ok(name, "cmd.diag.snapshot", {})["snapshot"]


def workers_info(runner):
    return snapshot(runner, "engine")["info"]["workers"]


def slow_flow(name="slow", seconds=6):
    fb = FlowBuilder(name)
    fb.chain(fb.trigger(), fb.action("Action_Sleep", Duration=seconds, Unit="Seconds"))
    return fb


def endless_loop(name="runaway", **flow_settings):
    fb = FlowBuilder(name, flow_settings=flow_settings)
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=1000000)
    body = fb.action("Action_Do_nothing")
    fb.connect(fb.trigger(), loop)
    fb.connect(loop, body, "head")
    fb.connect(body, loop, into="tail")
    return fb


@pytest.fixture
def shown(procs, datadir, session_id):
    """A FlowRunner whose session starts the headless tray role too (a second role that shows translated texts)."""
    runner = FlowRunner(procs, datadir, session_id, roles=SHOWN_ROLES)
    yield runner
    runner.close()


# --- defaults and the file ---------------------------------------------------------------------------------------

def test_without_a_file_the_defaults_are_in_force_and_nothing_is_written(flows):
    flows.start()
    s = get(flows)
    assert set(s) == KEYS | set(), sorted(set(s) ^ KEYS)
    assert s["language"] == "" and s["executionPolicy"] == "parallel" and s["workers"] == 8
    assert (s["logLevelApp"], s["logLevelFlow"], s["logLevelThread"]) == (2, 2, 2)
    assert (s["maxExecutionsPerMinute"], s["maxWaitingInstances"], s["maxParallelInstances"]) == (50000, 100, 100)
    assert s["userLevel"] == "Beginner" and s["notifyUnhandledErrors"] is True
    assert s["startWithWindows"] is False and s["runAsAdmin"] is False and s["windowPositions"] == {}
    assert s["workingDir"].endswith("\\AutoHotFlow"), s["workingDir"]
    snap = flows.request_ok("engine", "cmd.engine.snapshot", {})
    assert snap["settings"] == s, "the snapshot carries the settings"
    assert not (flows.datadir / "Settings.json").exists(), "nothing is written until the first change"
    assert workers_info(flows)["size"] == 8, "the pool size is the default (E0048)"


def test_a_change_is_written_announced_and_survives_a_restart(flows):
    flows.start()
    subscribe(flows, "settings")
    answer = put(flows, userLevel="advanced", notifyUnhandledErrors=False, windowPositions={"manager": {
        "x": 10, "y": 20, "w": 800, "h": 600}})
    assert sorted(answer["changed"]) == ["notifyUnhandledErrors", "userLevel", "windowPositions"]
    hit = flows.wait_message(lambda m: m.get("type") == "evt.settings.changed", timeout=WAIT_S)
    assert hit is not None, "evt.settings.changed was not sent"
    event = hit[1]["payload"]
    assert set(event["settings"]) == KEYS, "the event carries the whole set"
    assert event["settings"]["userLevel"] == "Advanced" and event["settings"]["notifyUnhandledErrors"] is False
    assert "epoch" in event and "seq" in event
    assert get(flows)["userLevel"] == "Advanced"
    text = on_disk(flows)
    assert text["formatVersion"] == 1 and text["userLevel"] == "Advanced" and text["notifyUnhandledErrors"] is False
    assert text["windowPositions"]["manager"]["w"] == 800
    assert set(text) == KEYS | {"formatVersion"}
    flows.stop()
    flows.start()
    s = get(flows)
    assert s["userLevel"] == "Advanced" and s["notifyUnhandledErrors"] is False
    assert s["windowPositions"]["manager"] == {"x": 10, "y": 20, "w": 800, "h": 600}
    assert s["workers"] == 8, "a key that was not changed keeps its default"


def test_a_change_to_the_same_values_writes_nothing(flows):
    flows.start()
    answer = put(flows, userLevel="Beginner")
    assert answer["changed"] == []
    assert not (flows.datadir / "Settings.json").exists()


def test_a_bad_value_is_bad_payload_with_the_key_and_changes_nothing(flows):
    flows.start()
    err = refused(flows, workers=99)
    assert err["code"] == "bad_payload" and "workers" in err["message"], err
    err = refused(flows, userLevel="Beginner", logLevelFlow=7)      # one bad key refuses the whole set
    assert err["code"] == "bad_payload" and "logLevelFlow" in err["message"], err
    err = refused(flows, nonsense=1)
    assert err["code"] == "bad_payload" and "nonsense" in err["message"], err
    err = refused(flows, executionPolicy="default")
    assert err["code"] == "bad_payload" and "executionPolicy" in err["message"], err
    err = refused(flows, workingDir="relative\\path")
    assert err["code"] == "bad_payload" and "workingDir" in err["message"], err
    bad = flows.request("engine", "cmd.settings.set", {"settings": "text"})
    assert bad["ok"] is False and bad["error"]["code"] == "bad_payload"
    assert get(flows)["userLevel"] == "Beginner" and get(flows)["workers"] == 8
    assert not (flows.datadir / "Settings.json").exists()


def test_a_broken_file_is_kept_and_the_defaults_are_used(flows):
    (flows.datadir / "Settings.json").write_text("{broken", encoding="utf-8")
    flows.start()
    kept = flows.datadir / "Settings.json.broken"
    assert wait_for(kept.is_file), "the broken file was not kept"
    assert kept.read_text(encoding="utf-8") == "{broken"
    assert not (flows.datadir / "Settings.json").exists()
    assert get(flows)["workers"] == 8
    put(flows, workers=3)
    assert on_disk(flows)["workers"] == 3, "the next change writes a new file"
    assert kept.is_file(), "the broken file stays"


def test_an_invalid_or_missing_value_counts_as_its_default_and_is_logged(flows):
    (flows.datadir / "Settings.json").write_text(json.dumps({
        "formatVersion": 1, "workers": 99, "userLevel": "Programmer", "bogus": 5}), encoding="utf-8")
    flows.start()
    s = get(flows)
    assert s["workers"] == 8, "invalid: the default"
    assert s["userLevel"] == "Programmer", "valid values of the same file are kept"
    assert s["maxParallelInstances"] == 100, "missing: the default"
    assert wait_for(lambda: "setting 'workers'" in log_text(flows)), "the invalid value was not logged"
    text = log_text(flows)
    assert "unknown setting 'bogus'" in text and "setting 'runAsAdmin' is missing" in text


def test_a_failed_write_changes_nothing(flows):
    flows.start()
    (flows.datadir / "Settings.json").mkdir()          # a folder in the way: the atomic write cannot replace it
    answer = flows.request("engine", "cmd.settings.set", {"settings": {"userLevel": "Advanced"}})
    assert answer["ok"] is False, answer
    assert get(flows)["userLevel"] == "Beginner", "the value is not in force when it could not be saved"


def test_two_changes_in_a_row_both_reach_the_file(flows):
    flows.start()
    put(flows, workers=5)
    put(flows, userLevel="Programmer")
    text = on_disk(flows)
    assert text["workers"] == 5 and text["userLevel"] == "Programmer"


def test_overlapping_changes_are_applied_in_order_and_the_later_one_wins(flows):
    flows.start()
    obs = flows._obs
    # three requests without waiting for an answer; the second one sets the value that is in force while the first one waits
    ids = [obs.send("engine", "cmd.settings.set", {"settings": values}, timeout_ms=10000)
           for values in ({"workers": 5}, {"workers": 8}, {"userLevel": "Advanced", "logLevelApp": 1})]
    answers = [obs._wait_answer(i, scaled(10.0))["payload"] for i in ids]
    assert all(a["ok"] for a in answers), answers
    assert answers[0]["changed"] == ["workers"]
    assert answers[1]["changed"] == ["workers"], "8 differs from the 5 that waits: it is a change, not 'nothing changed'"
    assert sorted(answers[2]["changed"]) == ["logLevelApp", "userLevel"]
    assert get(flows)["workers"] == 8, "the later request wins"
    text = on_disk(flows)
    assert text["workers"] == 8 and text["userLevel"] == "Advanced" and text["logLevelApp"] == 1


# --- live effect -------------------------------------------------------------------------------------------------

def test_the_global_execution_policy_decides_for_flows_set_to_default(flows):
    flow_id = flows.add(slow_flow())
    flows.start()
    first = flows.request_ok("engine", "cmd.flow.start", {"flowId": flow_id})
    assert first["instanceId"]
    put(flows, executionPolicy="skip")
    skipped = flows.request("engine", "cmd.flow.start", {"flowId": flow_id})
    assert skipped["ok"] is False and skipped["error"]["code"] == "busy", skipped
    put(flows, executionPolicy="parallel")
    second = flows.request_ok("engine", "cmd.flow.start", {"flowId": flow_id})
    assert second["instanceId"] != first["instanceId"], "parallel again: a second instance runs"
    put(flows, executionPolicy="wait")
    waiting = flows.request_ok("engine", "cmd.flow.start", {"flowId": flow_id})
    assert waiting.get("waiting") is True, waiting


def test_the_global_working_directory_is_a_working_directory_of_flows_at_once(flows, tmp_path):
    fb = FlowBuilder("wd")
    fb.chain(fb.trigger(), fb.probe("A_WorkingDir", location="thread"))
    flow_id = flows.add(fb)
    flows.start()
    before = flows.run(flow_id).probe("A_WorkingDir")
    assert before is not None and before.text == get(flows)["workingDir"], before
    target = tmp_path / "work dir"
    put(flows, workingDir=str(target))
    after = flows.run(flow_id).probe("A_WorkingDir")
    assert after is not None and after.text == str(target), after


def test_the_global_runaway_limit_stops_a_flow_without_its_own_limit(flows):
    flow_id = flows.add(endless_loop())
    flows.start()
    put(flows, maxExecutionsPerMinute=1500)
    flows.enable(flow_id)
    flows.begin(flow_id)
    hit = flows.wait_message(lambda m: m.get("type") == "evt.flow.limit", timeout=LIMIT_S)
    assert hit is not None, "the guard did not stop the flow"
    assert hit[1]["payload"]["limit"] == 1500, hit[1]["payload"]


def test_a_limit_of_the_flow_wins_over_the_global_one(flows):
    flow_id = flows.add(endless_loop(maxExecutionsPerMinute=1200))
    flows.start()
    put(flows, maxExecutionsPerMinute=900000)
    flows.begin(flow_id)
    hit = flows.wait_message(lambda m: m.get("type") == "evt.flow.limit", timeout=LIMIT_S)
    assert hit is not None and hit[1]["payload"]["limit"] == 1200, hit


def test_the_global_limit_of_running_instances_refuses_a_start(flows):
    flow_id = flows.add(slow_flow())
    flows.start()
    put(flows, maxParallelInstances=1)
    flows.request_ok("engine", "cmd.flow.start", {"flowId": flow_id})
    refused_start = flows.request("engine", "cmd.flow.start", {"flowId": flow_id})
    assert refused_start["ok"] is False and refused_start["error"]["code"] == "limit", refused_start
    put(flows, maxParallelInstances=0)               # 0 means no limit
    flows.request_ok("engine", "cmd.flow.start", {"flowId": flow_id})


def test_the_log_thresholds_change_in_every_role_at_once(shown):
    shown.start(extra=("--headless",))
    for name in ("storage", "engine", "tray"):
        assert snapshot(shown, name)["log"]["levels"] == [2, 2, 2], name
    put(shown, logLevelApp=0, workers=5)             # the pool logs "size 8 -> 5" at a1: below the new threshold
    put(shown, logLevelFlow=1, logLevelThread=3)
    levels = wait_for(lambda: all(snapshot(shown, n)["log"]["levels"] == [0, 1, 3] for n in ("storage", "engine", "tray")))
    assert levels, [snapshot(shown, n)["log"]["levels"] for n in ("storage", "engine", "tray")]
    time.sleep(scaled(0.5))
    assert "worker pool: size 8 -> 5" not in log_text(shown), "a1 is above the app threshold 0"
    put(shown, logLevelApp=1, workers=6)
    assert wait_for(lambda: "worker pool: size 5 -> 6" in log_text(shown)), "a1 is written with the threshold 1"


def test_a_command_line_log_level_wins_over_the_settings(flows):
    flows.start(extra=("--log-level=1",))
    put(flows, logLevelApp=3, logLevelFlow=3, logLevelThread=3)
    time.sleep(scaled(0.5))
    assert snapshot(flows, "engine")["log"]["level"] == 1
    assert snapshot(flows, "engine")["log"]["levels"] == [1, 1, 1]
    assert snapshot(flows, "storage")["log"]["levels"] == [1, 1, 1]


def test_the_language_changes_the_texts_of_two_roles_at_once(shown):
    flow_id = shown.add(throwing_flow())
    shown.start(extra=("--headless",))
    subscribed = wait_for(lambda: {l["name"] for l in snapshot(shown, "supervisor")["hub"]["links"]
                                   if "notice" in l.get("topics", [])} >= {"tray"})
    assert subscribed, "the tray did not subscribe to topic notice"
    assert snapshot(shown, "tray")["language"] == "en" and snapshot(shown, "storage")["language"] == "en"
    put(shown, language="de")
    assert wait_for(lambda: snapshot(shown, "tray")["language"] == "de" and snapshot(shown, "storage")["language"] == "de"
                    and snapshot(shown, "engine")["language"] == "de"), "the roles did not take the language"
    shown.request("engine", "cmd.flow.start", {"flowId": flow_id})
    german = wait_for(lambda: snapshot(shown, "tray")["info"]["lastNotice"])
    assert german and german.startswith("Der Flow "), german
    time.sleep(scaled(10.5))                           # the notice throttle window (10 s) of the flow
    put(shown, language="")                            # empty: the language of Windows (the tests set English)
    assert wait_for(lambda: snapshot(shown, "tray")["language"] == "en"), "empty means the language of Windows"
    shown.request("engine", "cmd.flow.start", {"flowId": flow_id})
    english = wait_for(lambda: (snapshot(shown, "tray")["info"]["lastNotice"] or "").startswith("The flow "))
    assert english, snapshot(shown, "tray")["info"]["lastNotice"]


def throwing_flow():
    fb = FlowBuilder("throws")
    fb.chain(fb.trigger(), fb.action("Action_TestThrow", name="THROWS"))
    return fb


def test_the_switch_for_notices_of_unhandled_errors(shown):
    flow_id = shown.add(throwing_flow())
    shown.start(extra=("--headless",))
    wait_for(lambda: {l["name"] for l in snapshot(shown, "supervisor")["hub"]["links"]
                      if "notice" in l.get("topics", [])} >= {"tray"})
    put(shown, notifyUnhandledErrors=False)
    mark = shown.mark()
    shown.request("engine", "cmd.flow.start", {"flowId": flow_id})
    time.sleep(scaled(1.5))
    assert not [m for m in shown.messages(mark) if m.get("type") == "evt.ui.notice"], "switched off: no notice"
    put(shown, notifyUnhandledErrors=True)
    shown.request("engine", "cmd.flow.start", {"flowId": flow_id})
    assert shown.wait_message(lambda m: m.get("type") == "evt.ui.notice", timeout=WAIT_S, since=mark) is not None


def test_the_number_of_workers_grows_and_shrinks_at_once(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id, roles="storage,engine")
    try:
        runner.start(extra=("--warm-workers=3",))
        assert workers_info(runner)["size"] == 8
        assert wait_for(lambda: len(workers_info(runner)["slots"]) == 3), "three warm workers"
        put(runner, workers=1)
        assert workers_info(runner)["size"] == 1
        assert wait_for(lambda: len(workers_info(runner)["slots"]) == 1), "two idle workers end at once"
        put(runner, workers=12)
        assert workers_info(runner)["size"] == 12
        assert wait_for(lambda: len(workers_info(runner)["slots"]) >= 1)
    finally:
        runner.close()


def test_the_command_line_number_of_workers_wins_over_the_setting(flows):
    flows.start(extra=("--workers=2",))
    put(flows, workers=9)
    assert get(flows)["workers"] == 9, "the setting is kept"
    assert workers_info(flows)["size"] == 2, "the option wins"


def test_the_supervisor_gives_new_processes_the_settings(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id, roles="storage,engine")
    try:
        (datadir / "Settings.json").write_text(json.dumps({
            "formatVersion": 1, "language": "de", "logLevelApp": 1, "logLevelFlow": 0, "logLevelThread": 3}), encoding="utf-8")
        runner.start()
        # a worker is started after the settings were read: it starts with them (and takes the same from the topic)
        runner.request_ok("engine", "cmd.settings.get", {})
        spawn = wait_for(lambda: [s for s in workers_info(runner)["slots"] if s["state"] in ("idle", "busy")])
        assert spawn, "no worker"
        worker = spawn[0]["name"]
        snap = snapshot(runner, worker)
        assert snap["language"] == "de" and snap["log"]["levels"] == [1, 0, 3], (snap["language"], snap["log"]["levels"])
    finally:
        runner.close()
