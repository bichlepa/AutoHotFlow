"""WI-04: named pipes, frames and wake-up of src/core/ipc (AutoHotkey) against Python peers.

Both directions are tested with real processes: AHK server with a Python client, and a Python
server with an AHK client. The helpers are in tests/integration/helpers/ (pipe_echo_server.ahk,
pipe_client.ahk). Measurements are printed (run with `-s` to see them) and not hard gates,
except where the acceptance criterion is a limit (detection of an abrupt end below 500 ms).
"""

import statistics
import struct
import sys
import threading
import time
from pathlib import Path

import psutil
import pytest

HELPERS = Path(__file__).resolve().parent / "helpers"
sys.path.insert(0, str(HELPERS))

import rawpipe  # noqa: E402
from rawpipe import Helper, PyServer, RawEnd, gen_size, gen_text  # noqa: E402
from support import winpipe  # noqa: E402

SERVER_AHK = HELPERS / "pipe_echo_server.ahk"
CLIENT_AHK = HELPERS / "pipe_client.ahk"
FRAME_COUNT = 10000


# --- fixtures and helpers --------------------------------------------------------------------

@pytest.fixture
def pipe_name(session_id):
    return "ahf.pipetest.%s" % session_id


def launch_server(procs, ahk_exe, datadir, pipe_name, *options):
    """Starts the AHK echo server and returns (helper, hwnd) once it listens."""
    h = Helper(procs, ahk_exe, datadir, SERVER_AHK, pipe_name, *options, label="server")
    ready = h.wait_record("ready", timeout=15)
    return h, ready["hwnd"]


def launch_client(procs, ahk_exe, datadir, pipe_name, *options):
    return Helper(procs, ahk_exe, datadir, CLIENT_AHK, pipe_name, *options, label="client")


def connect_client(pipe_name, server_hwnd, announce=True):
    """Connects a raw Python client to the AHK server and posts the wake message so the server accepts at once."""
    end = RawEnd.connect(pipe_name, timeout=10.0)
    end.peer_hwnd = server_hwnd
    rawpipe.wake(server_hwnd)
    end.recv_until_hello()
    if announce:
        end.send_text("hello:0")
    return end


def percentile(values, q):
    s = sorted(values)
    return s[min(len(s) - 1, int(len(s) * q))]


def echo_once(end, text, timeout=10.0):
    end.send_text(text)
    got = end.recv(timeout)
    assert got == text
    return got


# --- 10,000 frames in both directions -------------------------------------------------------

def test_ahk_server_python_client_exchanges_10000_frames(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = connect_client(pipe_name, hwnd)
    sizes = [gen_size(i) for i in range(FRAME_COUNT)]
    assert min(sizes) == 1 and max(sizes) == 1048576
    end.send_text("ctl:gen:%d" % FRAME_COUNT)       # before expect: expect swallows the next frames
    end.send_text("ctl:expect:%d" % FRAME_COUNT)
    errors = []

    def writer():
        try:
            for i in range(FRAME_COUNT):
                end.send_text(gen_text(i))
        except Exception as exc:  # noqa: BLE001 - reported through the list
            errors.append(exc)

    t0 = time.perf_counter()
    t = threading.Thread(target=writer)
    t.start()
    total_bytes = 0
    for i in range(FRAME_COUNT):
        got = end.recv(timeout=30)
        want = gen_text(i)
        assert got == want, "frame %d differs (len %d, expected %d)" % (i, len(got), len(want))
        total_bytes += len(got.encode("utf-8"))
    t.join(timeout=60)
    assert not t.is_alive() and not errors, errors
    verified = server.wait_record("verified", timeout=30)
    elapsed = time.perf_counter() - t0
    assert verified["count"] == FRAME_COUNT and verified["bad"] == 0
    assert server.wait_record("gen_done", timeout=10)["sent"] == FRAME_COUNT
    print("\nAHK server <-> Python client: %d frames each way, %.1f MB received, %.2f s, %.1f MB/s (one direction)"
          % (FRAME_COUNT, total_bytes / 1e6, elapsed, total_bytes / 1e6 / elapsed))
    end.close()


def test_python_server_ahk_client_exchanges_10000_frames(procs, ahk_exe, datadir, pipe_name):
    errors = []
    with PyServer(pipe_name, handler=lambda end: end.closed.wait(300)) as server:
        client = launch_client(procs, ahk_exe, datadir, pipe_name, "mode=exchange", "n=%d" % FRAME_COUNT)
        end = server.wait_accept(timeout=15)
        end.recv_until_hello(timeout=15)

        def writer():
            try:
                for i in range(FRAME_COUNT):
                    end.send_text(gen_text(i))
            except Exception as exc:  # noqa: BLE001
                errors.append(exc)

        t0 = time.perf_counter()
        t = threading.Thread(target=writer)
        t.start()
        total_bytes = 0
        for i in range(FRAME_COUNT):
            got = end.recv(timeout=30)
            assert got == gen_text(i), "frame %d from the AHK client differs" % i
            total_bytes += len(got.encode("utf-8"))
        t.join(timeout=60)
        assert not t.is_alive() and not errors, errors
        done = client.wait_record("done", timeout=30)
        elapsed = time.perf_counter() - t0
        assert done["sent"] == FRAME_COUNT and done["received"] == FRAME_COUNT
        assert done["bad"] == 0, "first bad frame index %s" % done["firstBad"]
        assert client.wait_exit(timeout=10) == 0
        print("\nPython server <-> AHK client: %d frames each way, %.1f MB, %.2f s, %.1f MB/s (one direction)"
              % (FRAME_COUNT, total_bytes / 1e6, elapsed, total_bytes / 1e6 / elapsed))


def test_frame_of_exactly_16_mib_is_echoed(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = connect_client(pipe_name, hwnd)
    text = ("0123456789abcdef" * (rawpipe.MAX_FRAME // 16))
    assert len(text) == rawpipe.MAX_FRAME
    end.send_text(text)
    got = end.recv(timeout=60)
    assert len(got) == rawpipe.MAX_FRAME and got == text
    try:
        assert echo_once(end, "still alive") == "still alive"
    except winpipe.PipeClosed:
        raise AssertionError("server closed the connection: %s" % server.records())
    end.close()


# --- latency -----------------------------------------------------------------------------------

def test_round_trip_python_to_ahk_with_wake(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = connect_client(pipe_name, hwnd)
    for i in range(30):
        echo_once(end, "warm:%d" % i)
    lat = []
    for i in range(1000):
        t0 = time.perf_counter()
        end.send_text("ping:%d" % i)
        assert end.recv(timeout=5) == "ping:%d" % i
        lat.append((time.perf_counter() - t0) * 1000)
    med, p99 = statistics.median(lat), percentile(lat, 0.99)
    print("\nRound trip Python -> AHK server -> Python with wake: n=1000 median %.2f ms, p99 %.2f ms, max %.2f ms"
          % (med, p99, max(lat)))
    assert med < 25, "median %.1f ms: the wake message is not effective (fallback timer is 250 ms)" % med
    end.close()


def test_round_trip_python_to_ahk_without_wake_falls_back_to_timer(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = connect_client(pipe_name, hwnd)
    end.peer_hwnd = 0                       # no wake messages from here on
    lat = []
    for i in range(8):
        t0 = time.perf_counter()
        end.send_text("ping:%d" % i, wake_peer=False)
        assert end.recv(timeout=5) == "ping:%d" % i
        lat.append((time.perf_counter() - t0) * 1000)
    print("\nRound trip without wake (fallback timer 250 ms): n=8 median %.0f ms, max %.0f ms"
          % (statistics.median(lat), max(lat)))
    assert max(lat) < 600                   # data is never lost, only delayed by the timer period
    end.close()


def test_round_trip_ahk_to_ahk_with_wake(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    client = launch_client(procs, ahk_exe, datadir, pipe_name, "mode=pingpong", "n=1000", "wake=1")
    rec = client.wait_record("pingpong", timeout=60)
    assert client.wait_exit(10) == 0
    print("\nRound trip AHK client -> AHK server -> AHK client with wake: n=%d median %.2f ms, p99 %.2f ms, "
          "max %.2f ms (first round trip incl. accept: %.0f ms)"
          % (rec["count"], rec["medianUs"] / 1000, rec["p99Us"] / 1000, rec["maxUs"] / 1000, rec["firstUs"] / 1000))
    assert rec["count"] == 999


def test_round_trip_ahk_client_python_server_with_wake(procs, ahk_exe, datadir, pipe_name):
    with PyServer(pipe_name) as server:
        client = launch_client(procs, ahk_exe, datadir, pipe_name, "mode=pingpong", "n=500", "wake=1")
        rec = client.wait_record("pingpong", timeout=60)
        print("\nRound trip AHK client -> Python server -> AHK client with wake: n=%d median %.2f ms, p99 %.2f ms"
              % (rec["count"], rec["medianUs"] / 1000, rec["p99Us"] / 1000))
        assert rec["medianUs"] < 25000


# --- abrupt end, leaks, hangs ----------------------------------------------------------------------

@pytest.mark.parametrize("attempt", range(3))
def test_abrupt_end_of_client_process_is_seen_within_500_ms(procs, ahk_exe, datadir, pipe_name, attempt):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    client = launch_client(procs, ahk_exe, datadir, pipe_name, "mode=hold")
    client.wait_record("connected", timeout=15)
    rawpipe.wake(hwnd)                       # accept without waiting for the timer
    server.wait_record("connect", timeout=10)
    time.sleep(0.4)                          # let both sides settle into their idle state
    t_kill = time.perf_counter() * 1000
    client.kill()
    rec = server.wait_record("close", timeout=5)
    latency = rec["t"] - t_kill              # QueryPerformanceCounter on both sides
    print("\nAbrupt end of the client process seen by the AHK server after %.0f ms (reason %s)"
          % (latency, rec["reason"]))
    assert rec["reason"] == "peer_closed"
    assert latency < 500
    assert psutil.Process(server.pid).is_running()


def test_abrupt_end_of_server_side_is_seen_by_ahk_client_within_500_ms(procs, ahk_exe, datadir, pipe_name):
    with PyServer(pipe_name, handler=lambda end: end.closed.wait(30)) as server:
        client = launch_client(procs, ahk_exe, datadir, pipe_name, "mode=watch")
        end = server.wait_accept(timeout=15)
        client.wait_record("connected", timeout=15)
        time.sleep(0.4)
        t_close = time.perf_counter() * 1000
        end.close()
        rec = client.wait_record("close", timeout=5)
        latency = rec["t"] - t_close
        print("\nAbrupt close of the server side seen by the AHK client after %.0f ms (reason %s)"
              % (latency, rec["reason"]))
        assert rec["reason"] == "peer_closed"
        assert latency < 500
        assert client.wait_exit(5) == 0


def test_100_connect_disconnect_cycles_against_ahk_server_do_not_leak(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    proc = psutil.Process(server.pid)

    def cycle(i):
        end = RawEnd.connect(pipe_name, timeout=10)
        end.peer_hwnd = hwnd
        rawpipe.wake(hwnd)
        end.send_text("hello:0")
        end.send_text("ping:%d" % i)
        while True:
            text = end.recv(timeout=10)
            if text == "ping:%d" % i:
                break
        end.close()

    for i in range(10):
        cycle(i)
    time.sleep(0.5)
    before = proc.num_handles()
    t0 = time.perf_counter()
    for i in range(10, 110):
        cycle(i)
    elapsed = time.perf_counter() - t0
    time.sleep(0.6)                          # the server notices the last close on its fallback timer
    after = proc.num_handles()
    closes = server.of_type("close")
    print("\n100 cycles against the AHK server: %.2f s, handles before %d, after %d, closes recorded %d"
          % (elapsed, before, after, len(closes)))
    assert after - before <= 2, "handle leak: %d -> %d" % (before, after)
    assert len(closes) >= 109
    assert {c["reason"] for c in closes} == {"peer_closed"}
    assert psutil.Process(server.pid).is_running()
    # the server still serves a new client
    end = connect_client(pipe_name, hwnd)
    assert echo_once(end, "after the cycles") == "after the cycles"
    end.close()


def test_100_connect_disconnect_cycles_from_ahk_client_do_not_leak(procs, ahk_exe, datadir, pipe_name):
    with PyServer(pipe_name) as server:
        client = launch_client(procs, ahk_exe, datadir, pipe_name, "mode=cycles", "n=100")
        done = client.wait_record(lambda r: r.get("type") in ("done", "error"), timeout=90)
        assert done["type"] == "done", done
        assert client.wait_exit(10) == 0
        print("\n100 cycles of an AHK client: handles after 10 cycles %d, after 100 cycles %d"
              % (done["handlesAfter10"], done["handlesEnd"]))
        assert done["handlesEnd"] - done["handlesAfter10"] <= 2


def test_accept_without_wake_happens_on_the_fallback_timer(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    t0 = time.perf_counter()
    end = RawEnd.connect(pipe_name, timeout=10)          # no wake message at all
    first = end.recv(timeout=5)                          # the server's hello shows that it accepted
    waited = (time.perf_counter() - t0) * 1000
    print("\nAccept without wake message: first frame after %.0f ms" % waited)
    assert first.startswith("hello:")
    assert waited < 700
    end.close()


# --- a reader that never reads -----------------------------------------------------------------------

def test_non_reading_peer_causes_queue_overflow_without_blocking(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = RawEnd.connect(pipe_name, timeout=10, read=False)     # connects, never reads
    end.peer_hwnd = hwnd
    rawpipe.wake(hwnd)
    end.send_text("hello:0")
    end.send_text("ctl:flood:102400:2000")
    flood = server.wait_record("flood", timeout=15)
    close = server.wait_record("close", timeout=15)
    print("\nNon-reading peer: SendFrame failed at frame %d after %.1f ms, queue limit 8 MiB, close reason %s"
          % (flood["failedAt"], float(flood["elapsedMs"]), close["reason"]))
    assert flood["failedAt"] > 0 and flood["sent"] == flood["failedAt"] - 1
    assert flood["sent"] < 200                    # about 8 MiB of 100 KiB frames plus the pipe buffer
    assert float(flood["elapsedMs"]) < 2000              # the loop never waited for the peer
    assert flood["isOpen"] == 0
    assert close["reason"] == "queue_overflow"
    # the server is alive and serves other clients
    other = connect_client(pipe_name, hwnd)
    assert echo_once(other, "alive") == "alive"
    other.close()
    end.close()


def test_frame_count_limit_closes_with_queue_overflow(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = RawEnd.connect(pipe_name, timeout=10, read=False)
    end.peer_hwnd = hwnd
    rawpipe.wake(hwnd)
    end.send_text("hello:0")
    end.send_text("ctl:flood:10:200000")
    flood = server.wait_record("flood", timeout=15)
    close = server.wait_record("close", timeout=15)
    print("\nNon-reading peer, 10 byte frames: SendFrame failed at frame %d, reason %s"
          % (flood["failedAt"], close["reason"]))
    assert flood["failedAt"] > 0 and close["reason"] == "queue_overflow"
    end.close()


def test_configured_queue_byte_limit_is_applied(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name, "maxBytes=300000")
    end = RawEnd.connect(pipe_name, timeout=10, read=False)
    end.peer_hwnd = hwnd
    rawpipe.wake(hwnd)
    end.send_text("hello:0")
    end.send_text("ctl:flood:102400:50")
    flood = server.wait_record("flood", timeout=15)
    # the frame being written does not count, the backlog behind it is checked before a frame is
    # added: 0, 102400 and 204800 bytes are below the limit of 300000, 307200 bytes are not
    assert flood["sent"] == 4 and flood["failedAt"] == 5
    end.close()


# --- fragmented and malformed input ------------------------------------------------------------------

def test_fragmented_frames_are_reassembled(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = connect_client(pipe_name, hwnd)

    def trickle(parts):
        for p in parts:
            end.pipe.write_all(p)
            rawpipe.wake(hwnd)
            time.sleep(0.03)

    text1 = "frag one é€ end"
    f1 = rawpipe.encode(text1)
    # header split 1+3, body split in the middle of the three byte euro sign
    cut = f1.index("€".encode("utf-8")) + 1
    trickle([f1[:1], f1[1:4], f1[4:cut], f1[cut:]])
    assert end.recv(5) == text1

    text2 = "second frame"
    text3 = "third frame \U0001F600"
    two = rawpipe.encode(text2) + rawpipe.encode(text3)
    trickle([two[:-3], two[-3:]])           # two frames, the second one incomplete in the first write
    assert end.recv(5) == text2
    assert end.recv(5) == text3

    big = "x" * 200000                      # byte by byte header, then large body in odd pieces
    fb = rawpipe.encode(big)
    trickle([fb[:2], fb[2:4], fb[4:70001], fb[70001:131072], fb[131072:]])
    assert end.recv(10) == big

    # one write that holds the end of one frame and the start of the next
    a, b = rawpipe.encode("tail of a"), rawpipe.encode("b complete")
    trickle([a[:6]])
    trickle([a[6:] + b[:3]])
    trickle([b[3:]])
    assert end.recv(5) == "tail of a"
    assert end.recv(5) == "b complete"
    end.close()


@pytest.mark.parametrize("header,label", [
    (struct.pack("<I", rawpipe.MAX_FRAME + 1) + b"abc", "oversize"),
    (struct.pack("<I", 0xFFFFFFFF), "huge"),
    (struct.pack("<I", 0), "empty"),
])
def test_bad_frame_header_closes_that_connection_only(procs, ahk_exe, datadir, pipe_name, header, label):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    good = connect_client(pipe_name, hwnd)
    bad = connect_client(pipe_name, hwnd)
    bad.send_bytes(header)
    close = server.wait_record(lambda r: r.get("type") == "close", timeout=5)
    assert close["reason"] == "protocol_error", label
    with pytest.raises(winpipe.PipeClosed):
        bad.recv(timeout=5)
    assert echo_once(good, "unaffected") == "unaffected"
    good.close()
    bad.close()


def test_data_written_before_close_is_still_readable(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = connect_client(pipe_name, hwnd)
    end.send_text("ctl:farewell")
    assert end.recv(5) == "bye"
    with pytest.raises(winpipe.PipeClosed):
        end.recv(timeout=5)
    close = server.wait_record("close", timeout=5)
    assert close["reason"] == "local"
    end.close()


BURST_FRAMES = 100          # 100 frames of 4000 bytes: far more than the 64 KiB of the pipe
BURST_SIZE = 4000


def burst_end(procs, ahk_exe, datadir, pipe_name, timeout_ms):
    """A client that does not read yet asks the AHK server for a burst and the end of the connection (WI-30)."""
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = RawEnd.connect(pipe_name, timeout=10, read=False)
    end.peer_hwnd = hwnd
    rawpipe.wake(hwnd)
    end.send_text("hello:0")
    end.send_text("ctl:burstend:%d:%d:%d" % (BURST_SIZE, BURST_FRAMES, timeout_ms))
    rec = server.wait_record("burstend", timeout=15)
    assert rec["queuedFrames"] > 0, "the burst fitted into the pipe, the test shows nothing: %s" % rec
    return server, end


def test_frames_queued_when_the_connection_is_ended_reach_a_late_reader(procs, ahk_exe, datadir, pipe_name):
    # F-26 cause A (WI-30): frames that still wait in the send queue when the connection is ended are written
    # first; the last one arrives, then the end of the stream.
    server, end = burst_end(procs, ahk_exe, datadir, pipe_name, 5000)
    time.sleep(0.5)                                  # the reader is late: the pipe is full meanwhile
    end.start_reading()
    frames = end.recv_all(timeout=10)
    assert frames[0].startswith("hello:")
    body = frames[1:]
    assert len(body) == BURST_FRAMES + 1, "got %d frames, the last is %r" % (len(body), body[-1][:20] if body else None)
    assert [f.split("|")[0] for f in body[:-1]] == [str(i) for i in range(1, BURST_FRAMES + 1)]
    assert body[-1] == "last"
    drained = server.wait_record("drained", timeout=5)
    assert drained["flushed"] == 1, drained
    close = server.wait_record("close", timeout=5)
    assert close["reason"] == "local"
    end.close()


def test_ending_after_the_queue_is_written_gives_up_at_its_deadline_and_does_not_block(procs, ahk_exe, datadir,
                                                                                       pipe_name):
    # A reader that never reads: the end waits at most its deadline (300 ms), then the connection closes with
    # the rest dropped. Meanwhile the server serves other clients (nothing blocks).
    server, end = burst_end(procs, ahk_exe, datadir, pipe_name, 300)
    other = connect_client(pipe_name, server.wait_record("ready")["hwnd"])
    assert echo_once(other, "not blocked") == "not blocked"
    drained = server.wait_record("drained", timeout=5)
    print("\nEnd with a reader that never reads: gave up after %.0f ms (deadline 300 ms)" % float(drained["elapsedMs"]))
    assert drained["flushed"] == 0, drained
    assert 290 <= float(drained["elapsedMs"]) < 1500, drained
    assert server.wait_record("close", timeout=5)["reason"] == "local"
    other.close()
    end.close()


def test_frames_of_a_peer_that_has_gone_are_read_although_a_write_to_it_fails(procs, ahk_exe, datadir, pipe_name):
    # WI-30 (F-26): a client writes its last frame and ends. Before the server has read that frame, it writes
    # to the client; the write fails (the pipe is being closed). The frame must still be read and delivered,
    # then the connection ends with peer_closed. Before WI-30 the failed write tore the connection down and
    # the unread frame (in the hub: the sys.bye of a role) was lost.
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    control = connect_client(pipe_name, hwnd)                     # id 1, pumped before the leaving client
    for attempt in range(1, 6):
        leaving = connect_client(pipe_name, hwnd, announce=False)
        leaving_id = 1 + attempt
        server.wait_record(lambda r: r.get("type") == "connect" and r.get("id") == leaving_id, timeout=5)
        leaving.send_bytes(rawpipe.encode("note:last words %d" % attempt), wake_peer=False)
        leaving.close()
        control.send_text("ctl:poke:%d" % leaving_id)               # wakes the server: the write comes first
        poke = server.wait_record(lambda r: r.get("type") == "poke" and r.get("id") == leaving_id, timeout=5)
        if poke["wasOpen"] == 1 and poke["ok"] == 0:
            break                                                   # the case of the test: write to a gone peer
        # the fallback timer of the server read the end before the poke: no statement, try again
    else:
        pytest.skip("the server always read the end before the write (5 attempts)")
    note = server.wait_record(lambda r: r.get("type") == "note" and r.get("id") == leaving_id, timeout=5)
    assert note["text"] == "note:last words %d" % attempt
    close = server.wait_record(lambda r: r.get("type") == "close" and r.get("id") == leaving_id, timeout=5)
    assert close["reason"] == "peer_closed", close
    control.close()


def test_python_client_end_after_traffic_is_peer_closed(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = connect_client(pipe_name, hwnd)
    echo_once(end, "one")
    end.close()
    rawpipe.wake(hwnd)
    close = server.wait_record("close", timeout=5)
    assert close["reason"] == "peer_closed"


# --- start up and misuse ------------------------------------------------------------------------------

def test_connect_without_server_times_out(procs, ahk_exe, datadir, pipe_name):
    client = launch_client(procs, ahk_exe, datadir, pipe_name + ".none", "mode=connect_fail", "timeout=400")
    rec = client.wait_record("error", timeout=15)
    assert rec["error"] == "AhfTimeoutError" and rec["code"] == "timeout"
    assert 380 <= float(rec["elapsedMs"]) < 1500
    assert client.wait_exit(5) == 0


def test_second_listener_on_the_same_name_is_refused(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    second = Helper(procs, ahk_exe, datadir, SERVER_AHK, pipe_name, label="server2")
    rec = second.wait_record("error", timeout=15)
    assert "CreateNamedPipeW" in rec["message"]
    assert second.wait_exit(5) == 3
    end = connect_client(pipe_name, hwnd)
    assert echo_once(end, "first server unaffected") == "first server unaffected"
    end.close()


def test_server_that_exits_leaves_no_process_behind(procs, ahk_exe, datadir, pipe_name):
    server, hwnd = launch_server(procs, ahk_exe, datadir, pipe_name)
    end = connect_client(pipe_name, hwnd)
    end.send_text("ctl:exit")
    assert server.wait_exit(5) == 0
    with pytest.raises(winpipe.PipeClosed):
        end.recv(timeout=5)
    end.close()
