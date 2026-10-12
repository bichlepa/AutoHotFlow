"""WI-12: storage role (src/storage/).

The storage role runs as a real process (src/AutoHotFlow.ahk --role=storage, started through
tools/ahkrun.py). Its hub is the Python stand-in RoleHub (WakingHub). The files are checked on disk
from Python. v1 example data is copied to a temporary directory, never used in place.
"""

import json
import os
import shutil
import stat
import time
import re
from pathlib import Path

import psutil
import pytest

from support.ahfclient import AhfClient
from test_role import RoleHub, RoleRun, wait_hello, SHUTDOWN_LIMIT_S

ROOT = Path(__file__).resolve().parents[2]
V1_FLOWS = ROOT / "v1" / "AppData" / "Saved Flows"
V1_VARS = ROOT / "v1" / "AppData" / "Variables"
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
BIG_BYTES = 5 * 1024 * 1024
ASK_TIMEOUT_S = 15.0
PING_LIMIT_S = 1.0          # acceptance: sys.ping is answered within 1 s during a 5 MB write
V1_LOG_LINE = re.compile(r"^--- \d{4} \d{2} \d{2} \d{2}:\d{2}:\d{2} ~[^~]*~[^~]*~ ")


# --- helpers ----------------------------------------------------------------------------------------

def same(a, b):
    """Structure and JSON types must match exactly (1 and 1.0 are different, "5" and 5 too)."""
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return a == b


def read_json(path):
    return json.loads(Path(path).read_bytes().decode("utf-8-sig"))


def ask(client, type_, payload=None, timeout=ASK_TIMEOUT_S):
    """Request to the storage role. Returns the answer payload."""
    answer = client.request("storage", type_, payload or {}, timeout=timeout)
    assert answer["type"] == "res." + type_[4:], answer
    return answer["payload"]


def ask_ok(client, type_, payload=None, timeout=ASK_TIMEOUT_S):
    answer = ask(client, type_, payload, timeout)
    assert answer.get("ok") is True, answer   # a real JSON boolean (PROTOKOLL 2)
    return answer


def observer(pipe, name, *topics):
    client = AhfClient(pipe, name)
    for topic in topics:
        answer = client.request("supervisor", "cmd.topic.subscribe", {"topic": topic}, timeout=5)
        assert answer["payload"]["ok"], answer
    return client


def flow_text(label, pad=""):
    """A small valid flow object (the root must be a JSON object)."""
    obj = {"name": label, "category": "", "ElementIDCounter": "1", "flowSettings": {"zoomFactor": "0.700000"},
           "allElements": {}, "allConnections": {}}
    if pad:
        obj["pad"] = pad
    return json.dumps(obj, ensure_ascii=False, indent=2)


@pytest.fixture
def pipe(session_id):
    return "ahf.storage.%s" % session_id


@pytest.fixture
def runs(procs):
    started = []
    yield started
    for run in started:
        run.close_files()


@pytest.fixture
def hub(pipe):
    with RoleHub(pipe) as h:
        yield h


@pytest.fixture
def flowdir(datadir):
    """Data directory with one flow in Flows/ (the folder name of v2, see MIGRATION M-15)."""
    (datadir / "Flows").mkdir()
    shutil.copy(SKELETON_SRC, datadir / "Flows" / "skeleton.json")
    return datadir


def start_storage(procs, datadir, runs, pipe, session_id, label="storage", *extra):
    args = ["--role=storage", "--session=" + session_id, "--hub=" + pipe, "--data=" + str(datadir), *extra]
    run = RoleRun(procs, datadir, label, args)
    runs.append(run)
    return run


@pytest.fixture
def storage(procs, flowdir, runs, pipe, session_id, hub):
    """A running storage role with the hub; yields (run, pid, client). The client is named 'tester'."""
    run = start_storage(procs, flowdir, runs, pipe, session_id)
    pid = wait_hello(hub, "storage")
    client = AhfClient(pipe, "tester")
    yield run, pid, client
    client.close()


# --- start, list, read ------------------------------------------------------------------------------

def test_storage_lists_and_reads_flows_and_reports_missing_files(storage, flowdir, pipe):
    run, pid, client = storage
    listed = ask_ok(client, "cmd.storage.flows.list")
    names = [f["name"] for f in listed["files"]]
    assert names == ["skeleton"]
    assert listed["files"][0]["path"] == "Flows/skeleton.json"
    assert isinstance(listed["files"][0]["mtime"], int)

    read = ask_ok(client, "cmd.storage.flow.read", {"path": "Flows/skeleton.json"})
    assert json.loads(read["text"]) == json.loads((flowdir / "Flows" / "skeleton.json").read_text("utf-8"))

    missing = ask(client, "cmd.storage.flow.read", {"path": "Flows/nothere.json"})
    assert not missing["ok"]          # booleans come as 0/1 (PROTOCOL 2)
    assert missing["error"]["code"] == "not_found"


def test_names_with_spaces_and_umlauts_work(storage, flowdir):
    _, _, client = storage
    path = "Flows/Flow 1010290492 Übung.json"
    ask_ok(client, "cmd.storage.flow.write", {"path": path, "text": flow_text("Übung"), "backup": False})
    assert (flowdir / "Flows" / "Flow 1010290492 Übung.json").is_file()
    listed = ask_ok(client, "cmd.storage.flows.list")
    assert "Flow 1010290492 Übung" in [f["name"] for f in listed["files"]]
    read = ask_ok(client, "cmd.storage.flow.read", {"path": path})
    assert json.loads(read["text"])["name"] == "Übung"


@pytest.mark.parametrize("bad", ["../escape.json", "Flows/../escape.json", "C:\\escape.json",
                                 "Flows\\sub.json", "Flows/sub/x.json", "Flows/x.txt", "", "Flows/.json"])
def test_bad_flow_paths_are_rejected_before_any_file_access(storage, flowdir, bad):
    _, _, client = storage
    answer = ask(client, "cmd.storage.flow.write", {"path": bad, "text": flow_text("x"), "backup": False})
    assert not answer["ok"], answer
    assert answer["error"]["code"] == "bad_payload"
    assert not (flowdir.parent / "escape.json").exists()


def test_flow_write_rejects_text_that_is_not_a_json_object(storage, flowdir):
    _, _, client = storage
    for text in ["{ not json", "[1, 2]", ""]:
        answer = ask(client, "cmd.storage.flow.write", {"path": "Flows/bad.json", "text": text, "backup": False})
        assert answer["error"]["code"] == "bad_payload", (text, answer)
    assert not (flowdir / "Flows" / "bad.json").exists()


# --- v1 round trip ----------------------------------------------------------------------------------

def test_v1_flows_round_trip_through_storage_with_same_structure_and_types(procs, datadir, runs, pipe,
                                                                           session_id, hub):
    """Reads every v1 flow, writes it back through storage and compares structure and JSON types."""
    flows = sorted(V1_FLOWS.glob("Flow *.json"))
    assert len(flows) >= 20, "v1 example flows are missing"
    (datadir / "Flows").mkdir()
    for src in flows:
        shutil.copy(src, datadir / "Flows" / src.name)
    start_storage(procs, datadir, runs, pipe, session_id)
    wait_hello(hub, "storage")
    client = AhfClient(pipe, "tester")
    try:
        listed = ask_ok(client, "cmd.storage.flows.list")
        assert sorted(f["name"] for f in listed["files"]) == sorted(p.stem for p in flows)
        for src in flows:
            path = "Flows/" + src.name
            text = ask_ok(client, "cmd.storage.flow.read", {"path": path})["text"]
            ask_ok(client, "cmd.storage.flow.write", {"path": path, "text": text, "backup": False})
            written = datadir / "Flows" / src.name
            raw = written.read_bytes()
            assert raw[:3] != b"\xef\xbb\xbf", src.name + " must be written without BOM"
            assert b"\r\n" in raw and raw.count(b"\n") == raw.count(b"\r\n"), src.name + " must be CRLF"
            assert same(read_json(written), read_json(src)), src.name
    finally:
        client.close()


# --- atomic write, backup, read-only target ---------------------------------------------------------

def test_hard_kill_during_a_big_write_leaves_old_or_new_file_never_a_half_one(procs, datadir, runs,
                                                                               session_id):
    """Three rounds: a 5 MB write is sent, the role is killed at once. The file is old or new, never half.
    Every round has its own hub and pipe name, so the hello of the new role is the one that is waited for."""
    target = datadir / "Flows" / "atomic.json"
    (datadir / "Flows").mkdir()
    for round_no in range(3):
        pipe_n = "ahf.storage.%s.%d" % (session_id, round_no)
        old = flow_text("old %d" % round_no)
        target.write_text(old, encoding="utf-8")
        with RoleHub(pipe_n) as hub:
            start_storage(procs, datadir, runs, pipe_n, session_id, label="storage%d" % round_no)
            pid = wait_hello(hub, "storage")
            client = AhfClient(pipe_n, "tester")
            new = flow_text("new %d" % round_no, pad="y" * BIG_BYTES)
            client.send("storage", "cmd.storage.flow.write",
                        {"path": "Flows/atomic.json", "text": new, "backup": True}, timeout_ms=30000)
            psutil.Process(pid).kill()
            client.close()
        time.sleep(0.2)
        parsed = json.loads(target.read_bytes().decode("utf-8"))   # must be complete JSON
        assert same(parsed, json.loads(old)) or same(parsed, json.loads(new)), \
            "half-written file in round %d" % round_no


def test_big_write_does_not_stop_the_ping(storage, flowdir):
    """A 5 MB write is queued; sys.ping is answered within 1 s while the write runs or waits."""
    _, _, client = storage
    big = flow_text("big", pad="z" * BIG_BYTES)
    started = time.perf_counter()
    write_id = client.send("storage", "cmd.storage.flow.write",
                           {"path": "Flows/big.json", "text": big, "backup": False}, timeout_ms=30000)
    pings = []
    for n in range(3):
        t0 = time.perf_counter()
        answer = client.request("storage", "sys.ping", {"n": n}, timeout=PING_LIMIT_S)
        pings.append(time.perf_counter() - t0)
        assert answer["type"] == "sys.pong"
    listed = ask_ok(client, "cmd.storage.flows.list")
    assert "big" in [f["name"] for f in listed["files"]]
    print("\nping seconds during the 5 MB write: %s, write+list total %.3f s"
          % (["%.4f" % p for p in pings], time.perf_counter() - started))
    assert max(pings) < PING_LIMIT_S
    assert write_id


def test_backups_keep_exactly_ten_after_twelve_writes(storage, flowdir):
    _, _, client = storage
    versions = [flow_text("version %d" % i) for i in range(12)]
    for text in versions:
        ask_ok(client, "cmd.storage.flow.write", {"path": "Flows/skeleton.json", "text": text, "backup": True})
    backups = sorted((flowdir / "Flows" / "backup").glob("skeleton_backup_*.json"))
    assert len(backups) == 10, [b.name for b in backups]
    # The newest backup is the version before the last write, the oldest kept one is version 2.
    assert same(read_json(backups[-1]), json.loads(versions[10]))
    assert same(read_json(backups[0]), json.loads(versions[1]))
    assert same(read_json(flowdir / "Flows" / "skeleton.json"), json.loads(versions[11]))


def test_read_only_target_fails_with_error_event_and_keeps_the_old_file(storage, flowdir, pipe):
    _, _, client = storage
    target = flowdir / "Flows" / "skeleton.json"
    before = target.read_bytes()
    engine = observer(pipe, "engine-watch", "engine")
    try:
        os.chmod(target, stat.S_IREAD)
        answer = ask(client, "cmd.storage.flow.write", {"path": "Flows/skeleton.json",
                                                        "text": flow_text("changed"), "backup": True})
        assert not answer["ok"]
        assert answer["error"]["code"] == "internal"
        event = engine.wait_event("evt.storage.error", timeout=5)
        assert event["payload"]["op"] == "flow.write"
        assert event["payload"]["path"] == "Flows/skeleton.json"
        assert target.read_bytes() == before
    finally:
        os.chmod(target, stat.S_IREAD | stat.S_IWRITE)
        engine.close()


def test_missing_flow_read_reports_storage_error_to_the_engine_topic(storage, pipe):
    _, _, client = storage
    engine = observer(pipe, "engine-watch", "engine")
    try:
        ask(client, "cmd.storage.flow.read", {"path": "Flows/none.json"})
        event = engine.wait_event("evt.storage.error", timeout=5)
        assert event["payload"]["op"] == "flow.read"
        assert event["payload"]["code"] == "not_found"
    finally:
        engine.close()


# --- variables --------------------------------------------------------------------------------------

def test_v1_variables_are_read_as_stored(procs, datadir, runs, pipe, session_id, hub):
    shutil.copytree(V1_VARS, datadir / "Variables")
    (datadir / "Flows").mkdir()
    start_storage(procs, datadir, runs, pipe, session_id)
    wait_hello(hub, "storage")
    client = AhfClient(pipe, "tester")
    try:
        got = ask_ok(client, "cmd.storage.var.get", {"scope": "global", "name": "global_testResults"})
        assert got["exists"] is True and got["type"] == "object"
        assert same(json.loads(got["content"]), read_json(V1_VARS / "global_testResults.ahfvar"))
        got = ask_ok(client, "cmd.storage.var.get",
                     {"scope": "static", "flowId": "Flow 1010290492", "name": "static_results"})
        assert got["exists"] is True and got["type"] == "object"
        assert same(json.loads(got["content"]),
                    read_json(V1_VARS / "Flow 1010290492" / "static_results.ahfvar"))
        assert ask_ok(client, "cmd.storage.var.get", {"scope": "global", "name": "nothere"})["exists"] is False
    finally:
        client.close()


def test_variable_round_trip_for_strings_numbers_objects_and_utf8(storage, flowdir):
    _, _, client = storage
    varsdir = flowdir / "Variables"
    obj = {"name": "Grüße \"x\" \\ € 中", "list": [1, 2.5, "3", "0.700000"], "nested": {"ß": 7}}
    ask_ok(client, "cmd.storage.var.set", {"scope": "global", "name": "obj", "type": "object",
                                           "content": json.dumps(obj, ensure_ascii=False)})
    meta = read_json(varsdir / "obj.ahfvd")
    assert meta == {"name": "obj", "type": "object"}
    assert same(read_json(varsdir / "obj.ahfvar"), obj)
    got = ask_ok(client, "cmd.storage.var.get", {"scope": "global", "name": "obj"})
    assert same(json.loads(got["content"]), obj)

    for name, value in [("text", "Ümlaut ß € 中"), ("number", "1.50"), ("int", "42")]:
        ask_ok(client, "cmd.storage.var.set", {"scope": "static", "flowId": "Flow 1", "name": name,
                                               "type": "normal", "content": value})
        assert (varsdir / "Flow 1" / (name + ".ahfvar")).read_bytes() == value.encode("utf-8")
        got = ask_ok(client, "cmd.storage.var.get", {"scope": "static", "flowId": "Flow 1", "name": name})
        assert got["type"] == "normal" and got["content"] == value

    listed = ask_ok(client, "cmd.storage.var.list", {"scope": "static", "flowId": "Flow 1"})
    assert listed["names"] == ["int", "number", "text"]


def test_deleting_a_variable_twice_is_not_an_error(storage, flowdir):
    _, _, client = storage
    ask_ok(client, "cmd.storage.var.set", {"scope": "global", "name": "gone", "type": "normal", "content": "1"})
    first = ask_ok(client, "cmd.storage.var.delete", {"scope": "global", "name": "gone"})
    second = ask_ok(client, "cmd.storage.var.delete", {"scope": "global", "name": "gone"})
    assert first["existed"] is True and second["existed"] is False
    assert not (flowdir / "Variables" / "gone.ahfvd").exists()
    assert not (flowdir / "Variables" / "gone.ahfvar").exists()
    assert not ask_ok(client, "cmd.storage.var.get", {"scope": "global", "name": "gone"})["exists"]


@pytest.mark.parametrize("scope, flowId, name", [("global", "", "../evil"), ("global", "", "a/b"),
                                                 ("global", "", ""), ("static", "../x", "name"),
                                                 ("weird", "", "name")])
def test_variable_names_and_scopes_are_checked(storage, flowdir, scope, flowId, name):
    _, _, client = storage
    answer = ask(client, "cmd.storage.var.set", {"scope": scope, "flowId": flowId, "name": name,
                                                 "type": "normal", "content": "x"})
    assert answer["error"]["code"] == "bad_payload", answer


# --- log --------------------------------------------------------------------------------------------

def test_log_line_has_the_v1_format_and_goes_to_the_log_topic(storage, flowdir, pipe):
    _, _, client = storage
    watcher = observer(pipe, "log-watch", "log")
    try:
        sender = AhfClient(pipe, "Editor3")
        ts = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())
        sender.send("storage", "evt.log.append", {"ts": ts, "level": "f1", "source": "Flow 369404488",
                                                 "flowId": "Flow 369404488", "text": "left mouse button click"})
        event = watcher.wait_event("evt.log.entry", timeout=5)
        assert event["payload"]["text"] == "left mouse button click"
        sender.close()
        log_txt = flowdir / "Log" / "Log.txt"
        deadline = time.time() + 5
        while time.time() < deadline and not (log_txt.exists() and "left mouse button click" in log_txt.read_text("utf-8")):
            time.sleep(0.05)
        raw = log_txt.read_bytes().decode("utf-8")
        line = raw[raw.rindex("\r\n---"):]
        assert V1_LOG_LINE.match(line[2:]), line
        assert line.endswith("~Editor3~Flow 369404488~ left mouse button click")
        # Time is local, as in v1: the stamp is close to the local now (the sender sends UTC).
        stamp = re.search(r"--- (\d{4} \d{2} \d{2} \d{2}:\d{2}:\d{2})", line).group(1)
        local_struct = time.strptime(stamp, "%Y %m %d %H:%M:%S")
        assert abs(time.mktime(local_struct) - time.time()) < 60
        per_source = flowdir / "Log" / "Log_Flow 369404488.txt"
        assert per_source.is_file() and "left mouse button click" in per_source.read_text("utf-8")
    finally:
        watcher.close()


def test_log_file_over_100_kb_is_renamed_to_old_before_the_next_entry(storage, flowdir):
    _, _, client = storage
    logdir = flowdir / "Log"
    logdir.mkdir(exist_ok=True)
    (logdir / "Log.txt").write_bytes(b"x" * (100 * 1024 + 10))
    client.send("storage", "evt.log.append", {"ts": "2026-10-10 10:00:00", "level": "a1",
                                              "source": "rot", "text": "after rotation"})
    deadline = time.time() + 5
    while time.time() < deadline and not (logdir / "Log_old.txt").exists():
        time.sleep(0.05)
    assert (logdir / "Log_old.txt").stat().st_size > 100 * 1024
    assert "after rotation" in (logdir / "Log.txt").read_text("utf-8")


def _hold_exclusive(path, stop, share_mode, permanent=False):
    """Opens the file over and over with the given Win32 share mode (0 = nobody else may open it),
    keeps it for a moment, closes it. Stands in for an editor or a virus scanner."""
    import ctypes
    from ctypes import wintypes
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.CreateFileW.restype = wintypes.HANDLE
    k32.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
                                wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    invalid = wintypes.HANDLE(-1).value
    while not stop.is_set():
        handle = k32.CreateFileW(str(path), 0x80000000, share_mode, None, 3, 0x80, None)  # GENERIC_READ, OPEN_EXISTING
        if handle != invalid:
            if permanent:
                stop.wait()
            else:
                time.sleep(0.004)
            k32.CloseHandle(handle)
        time.sleep(0.001)


@pytest.mark.parametrize("share_mode", [1, 0], ids=["readers-allow-read", "readers-deny-all"])
def test_no_log_line_is_lost_while_other_processes_hold_the_files(storage, flowdir, pipe, share_mode):
    """F-04: other processes open Log.txt and Log_<source>.txt (share mode 1 = FILE_SHARE_READ, like a
    viewer; 0 = exclusive, like a scanner) while several sources log at once. Every line must arrive,
    in order per source, in Log.txt and in the file of its source."""
    import threading
    _, _, client = storage
    logdir = flowdir / "Log"
    logdir.mkdir(exist_ok=True)
    sources = ["src%d" % i for i in range(4)]
    per_source = 120
    for name in ["Log.txt"] + ["Log_%s.txt" % s for s in sources]:
        (logdir / name).write_bytes(b"")
    stop = threading.Event()
    holders = [threading.Thread(target=_hold_exclusive, args=(logdir / name, stop, share_mode), daemon=True)
               for name in ["Log.txt"] + ["Log_%s.txt" % s for s in sources]]
    for h in holders:
        h.start()

    def sender_run(source):
        sender = AhfClient(pipe, source)
        ts = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())
        for n in range(per_source):
            sender.send("storage", "evt.log.append", {"ts": ts, "level": "a1", "source": source,
                                                     "text": "%s line %04d" % (source, n)})
        sender.close()

    senders = [threading.Thread(target=sender_run, args=(s,)) for s in sources]
    try:
        for t in senders:
            t.start()
        for t in senders:
            t.join(30)
        total = per_source * len(sources)
    finally:
        time.sleep(2.0)   # the holders stay while the storage drains its queue
        stop.set()
        for h in holders:
            h.join(5)
    # The holders are stopped. Writes in the queue may still be retried; they get the time they are allowed.
    deadline = time.time() + 30
    while time.time() < deadline:
        counts = [len(re.findall(r"~src\d~ src\d line \d{4}", (logdir / name).read_bytes().decode("utf-8")))
                  for name in ["Log.txt"] + ["Log_%s.txt" % s for s in sources]]
        if counts[0] >= total and all(c >= per_source for c in counts[1:]):
            break
        time.sleep(0.2)
    for name in ["Log.txt"] + ["Log_%s.txt" % s for s in sources]:
        text = (logdir / name).read_bytes().decode("utf-8")
        for s in sources:
            if name != "Log.txt" and name != "Log_%s.txt" % s:
                continue
            found = [int(m) for m in re.findall(r"~%s~ %s line (\d{4})" % (s, s), text)]
            assert found == list(range(per_source)), "%s in %s: %d lines, first gap near %s" % (
                s, name, len(found), next((i for i, v in enumerate(found) if v != i), len(found)))


def test_a_log_line_that_cannot_be_written_is_reported_in_the_own_log(storage, flowdir, pipe):
    """F-04: when the retries fail, the loss is not silent: a line in Log_storage.txt names it."""
    import threading
    _, _, client = storage
    logdir = flowdir / "Log"
    logdir.mkdir(exist_ok=True)
    held = logdir / "Log_stuck.txt"
    held.write_bytes(b"")
    stop = threading.Event()
    holder = threading.Thread(target=_hold_exclusive, args=(held, stop, 0, True), daemon=True)
    holder.start()
    try:
        client.send("storage", "evt.log.append", {"ts": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime()),
                                                 "level": "a1", "source": "stuck", "text": "never written"})
        own = logdir / "Log_storage.txt"
        deadline = time.time() + 15
        while time.time() < deadline and not (own.exists() and "log line lost" in own.read_text("utf-8")):
            time.sleep(0.2)
    finally:
        stop.set()
        holder.join(5)
    text = own.read_text("utf-8")
    assert "log line lost: Log_stuck.txt, source 'stuck'" in text and "never written" in text
    assert "never written" in (logdir / "Log.txt").read_text("utf-8")   # the common log has it
    assert "never written" not in held.read_text("utf-8")


# --- WI-25: log throughput, priority of requests, limit of the log queue, temp files ------------------

def _now_utc():
    return time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())


def _flood(client, source, count, text="flood line"):
    """Sends count log lines as fast as the pipe takes them. Returns the seconds it took."""
    ts = _now_utc()
    t0 = time.perf_counter()
    for n in range(count):
        client.send("storage", "evt.log.append", {"ts": ts, "level": "a1", "source": source,
                                                 "text": "%s %05d" % (text, n)})
    return time.perf_counter() - t0


def _wait_for_text(path, needle, timeout):
    """Seconds until needle is in the file, or None."""
    t0 = time.perf_counter()
    while time.perf_counter() - t0 < timeout:
        try:
            if needle in Path(path).read_bytes().decode("utf-8", "replace"):
                return time.perf_counter() - t0
        except OSError:
            pass
        time.sleep(0.05)
    return None


def _flood_and_measure(storage, flowdir):
    """Floods the log with 12000 lines and waits for the end marker in both files. Returns (lines/s over the whole run,
    storage RSS in MB). The flood stays below the limit of the log queue (20000 lines), so no line is dropped. The end
    marker is the last line of the source, so both files (Log.txt and Log_flood.txt) have been written up to it when it
    shows up. The rate is taken over the whole run, sender included, not per second."""
    _, pid, client = storage
    count = 12000
    t0 = time.perf_counter()
    sent_s = _flood(client, "flood", count)
    client.send("storage", "evt.log.append", {"ts": _now_utc(), "level": "a1", "source": "flood", "text": "END MARKER"})
    logdir = flowdir / "Log"
    seen = _wait_for_text(logdir / "Log_flood.txt", "END MARKER", 60)
    total = time.perf_counter() - t0
    assert seen is not None, "end marker not written within 60 s"
    assert _wait_for_text(logdir / "Log.txt", "END MARKER", 5) is not None
    rate = (count + 1) / total
    rss = psutil.Process(pid).memory_info().rss / 2**20
    print("\nflood: %d lines, sender %.1f s, all written after %.1f s = %.0f lines/s, storage RSS %.1f MB"
          % (count, sent_s, total, rate, rss))
    return rate, rss


def test_a_log_flood_is_written_completely_and_far_above_the_old_pace(storage, flowdir):
    """F-08: before WI-25 the storage wrote about 30 lines per second (12000 lines would take 400 s). Standard run,
    also in parallel with other tests: the whole flood must be written within the 60 s of the helper (at least 200
    lines/s, a 6 times margin over the old pace) and the memory stays bounded. The strict rate (more than 1000 lines/s)
    is measured in the stress group, alone on the machine (F-32, WI-32): a rate depends on the load of the machine."""
    rate, rss = _flood_and_measure(storage, flowdir)
    assert rate > 200, "%.0f lines/s" % rate
    assert rss < 120


@pytest.mark.stress
def test_a_log_flood_is_written_at_more_than_1000_lines_per_second(storage, flowdir):
    """F-08, the strict rate. Runs with -m stress (a single process, no other load), because a rate is only
    meaningful then (F-32: 808 lines/s once under parallel load, 3138 lines/s alone)."""
    rate, rss = _flood_and_measure(storage, flowdir)
    assert rate > 1000, "%.0f lines/s" % rate
    assert rss < 120


def test_a_request_is_answered_in_time_during_a_log_flood(storage, flowdir, pipe):
    """F-08: requests and log lines used to share one queue, so a read waited behind the whole flood."""
    _, _, client = storage
    other = AhfClient(pipe, "reader")
    try:
        _flood(client, "flood", 15000)
        latencies = []
        for _ in range(5):
            t0 = time.perf_counter()
            ask_ok(other, "cmd.storage.flow.read", {"path": "Flows/skeleton.json"}, timeout=10)
            latencies.append(time.perf_counter() - t0)
            time.sleep(0.1)
    finally:
        other.close()
    print("\nflow.read during a flood: %s ms" % ", ".join("%.0f" % (v * 1000) for v in latencies))
    assert max(latencies) < 1.0, latencies


def test_a_flood_over_the_limit_drops_lines_counts_them_and_the_process_stays_up(procs, flowdir, runs, pipe,
                                                                                 session_id, hub):
    """F-08: the log queue is limited (default 20000 lines, 8 MB). The limit is lowered here with
    --log-queue-max-lines, so the flood is small. Dropped lines are counted; once the queue has room again, a line
    '<n> log lines dropped' is written. Nothing blocks: requests are answered during the flood."""
    import threading
    logdir = flowdir / "Log"
    logdir.mkdir(exist_ok=True)
    # Log.txt is held by another process for the whole flood, so the queue cannot drain and has to hit
    # the limit however fast the machine is (a fast storage would keep up with the sender otherwise).
    held = logdir / "Log.txt"
    held.write_bytes(b"")
    stop = threading.Event()
    holder = threading.Thread(target=_hold_exclusive, args=(held, stop, 0, True), daemon=True)
    holder.start()
    start_storage(procs, flowdir, runs, pipe, session_id, "storage", "--log-queue-max-lines=300")
    pid = wait_hello(hub, "storage")
    client = AhfClient(pipe, "tester")
    try:
        _flood(client, "flood", 6000)
        ask_ok(client, "cmd.storage.flows.list", timeout=5)      # requests are not blocked by the full queue
        stop.set()                                                # the file is free again, the queue drains
        holder.join(5)
        found = _wait_for_text(logdir / "Log_storage.txt", "log lines dropped", 40)
        assert found is not None, "no 'log lines dropped' line"
        text = (logdir / "Log_storage.txt").read_bytes().decode("utf-8")
        counts = [int(m) for m in re.findall(r"~ (\d+) log lines dropped", text)]
        assert counts and counts[0] > 0, text[-500:]
        assert sum(counts) <= 6000 - 300
        # after the flood a new line is accepted again and written
        client.send("storage", "evt.log.append", {"ts": _now_utc(), "level": "a1", "source": "after", "text": "after the flood"})
        assert _wait_for_text(logdir / "Log_after.txt", "after the flood", 15) is not None
        assert psutil.pid_exists(pid) and psutil.Process(pid).is_running()
        ask_ok(client, "cmd.storage.flows.list")
    finally:
        stop.set()
        client.close()


def _dead_pid():
    pid = 4000000
    while psutil.pid_exists(pid):
        pid += 4
    return pid


def test_temp_files_of_dead_processes_are_removed_at_start_and_those_of_live_ones_stay(procs, flowdir, runs, pipe,
                                                                                         session_id, hub):
    """WI-25: *.ahf-<pid>.tmp (left after a hard stop) in Flows/ and Variables/ (recursive) go when the
    process does not run any more. One of a running process (this test) stays."""
    (flowdir / "Variables" / "Flow 1").mkdir(parents=True)
    dead = _dead_pid()
    gone = [flowdir / "Flows" / ("a.json.ahf-%d.tmp" % dead),
            flowdir / "Variables" / ("global.ahfvd.ahf-%d.tmp" % dead),
            flowdir / "Variables" / "Flow 1" / ("v.ahfvar.ahf-%d.tmp" % dead)]
    stays = [flowdir / "Flows" / ("b.json.ahf-%d.tmp" % os.getpid()), flowdir / "Flows" / "keep.json"]
    unrelated = flowdir / "Flows" / "note.ahf-x.tmp"
    for f in gone + stays + [unrelated]:
        f.write_text("x")
    start_storage(procs, flowdir, runs, pipe, session_id)
    wait_hello(hub, "storage")
    deadline = time.time() + 10
    while time.time() < deadline and any(f.exists() for f in gone):
        time.sleep(0.1)
    assert [f.name for f in gone if f.exists()] == []
    assert all(f.exists() for f in stays) and unrelated.exists()

# --- shutdown ---------------------------------------------------------------------------------------

def test_shutdown_finishes_the_queued_writes_then_says_bye_and_exits_0(storage, flowdir, procs, hub):
    """Writes sent before sys.shutdown are finished before sys.bye. The test hub forwards the client's
    frames on its own thread and the shutdown on another path, so the writes get a short head start.
    The queue drain itself is covered by tests/ahk/storage_queue.test.ahk (FailAll, deadlines)."""
    run, pid, client = storage
    names = ["shutdown%d" % i for i in range(3)]
    for name in names:
        client.send("storage", "cmd.storage.flow.write",
                    {"path": "Flows/%s.json" % name, "text": flow_text(name, pad="q" * (1024 * 1024)),
                     "backup": False}, timeout_ms=30000)
    time.sleep(0.5)
    hub.send_to("storage", "sys.shutdown", {"reason": "user", "deadlineMs": 3000})
    bye = hub.wait_received(lambda m: m.get("type") == "sys.bye" and m.get("from") == "storage", timeout=5)
    assert bye is not None
    assert run.wait_exit(timeout=SHUTDOWN_LIMIT_S + 2) == 0
    for name in names:
        assert json.loads((flowdir / "Flows" / (name + ".json")).read_text("utf-8"))["name"] == name


# --- the engine with the real storage ---------------------------------------------------------------

def test_engine_starts_with_the_real_storage_and_its_log_arrives(procs, datadir, runs, pipe, session_id, hub):
    """The engine test contract (tests/integration/test_engine.py) against this storage."""
    (datadir / "Flows").mkdir()
    shutil.copy(SKELETON_SRC, datadir / "Flows" / "skeleton.json")
    start_storage(procs, datadir, runs, pipe, session_id)
    wait_hello(hub, "storage")
    # Subscribe BEFORE the engine starts (PROTOKOLL 5a). Subscribing after its sys.hello could miss evt.engine.ready when
    # the engine is quick (WI-32, parallel run: failure after 15 s). The state is asked for below in any case.
    obs = observer(pipe, "obs-engine", "engine")
    engine_args = ["--role=engine", "--session=" + session_id, "--hub=" + pipe, "--data=" + str(datadir), "--workers=0"]
    engine = RoleRun(procs, datadir, "engine", engine_args)
    runs.append(engine)
    wait_hello(hub, "engine")
    try:
        ready = obs.wait_event("evt.engine.ready", timeout=15)
        assert ready["payload"]["seq"] >= 1
        snap = obs.request("engine", "cmd.engine.snapshot", {}, timeout=5)["payload"]
        assert [f["flowId"] for f in snap["flows"]] == ["skeleton"]
    finally:
        obs.close()
    deadline = time.time() + 5
    engine_log = datadir / "Log" / "Log_engine.txt"
    while time.time() < deadline and not engine_log.exists():
        time.sleep(0.05)
    assert "ready with 1 flow(s)" in engine_log.read_text("utf-8")
