"""Raw frame level pipe helpers for tests/integration/test_pipe.py (WI-04).

The AHK pipe layer carries text frames and no protocol. These helpers speak exactly that:
uint32 little endian length + UTF-8, no JSON. They are built on tests/support/winpipe.py
(overlapped handles) and add a reader thread per connection, an accepting server, the
deterministic test frames (mirror of Kit.GenText in PipeTestKit.ahk) and the wake message.
"""

import ctypes
import json
import queue
import struct
import threading
import time
from ctypes import wintypes
from pathlib import Path

from support import winpipe

WM_AHF_WAKE = 0x8001
MAX_FRAME = 16 * 1024 * 1024
ALPHA_MIXED = "abcé€xyz"
ALPHA_ASCII = "abcdefghij"

_user32 = ctypes.WinDLL("user32")
_user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
_user32.PostMessageW.restype = wintypes.BOOL


def wake(hwnd):
    """Posts the wake message to a window. Returns False if the window is gone."""
    return bool(_user32.PostMessageW(hwnd, WM_AHF_WAKE, 0, 0)) if hwnd else False


def gen_size(i):
    """Size in characters of test frame i. Must match Kit.GenSize."""
    if i == 0:
        return 1
    if i % 500 == 499:
        return 1048576
    if i % 200 == 7:
        return 70000
    if i % 101 == 0:
        return 65532 + (i // 101) % 9
    if i % 10 == 3:
        return 4000
    return 1 + (i * 37) % 2000


def gen_text(i):
    """Text of test frame i. Must match Kit.GenText."""
    n = gen_size(i)
    alpha = ALPHA_MIXED if (n <= 65536 and i % 2 == 0) else ALPHA_ASCII
    prefix = "%d|" % i
    return (prefix + alpha * (n // len(alpha) + 1))[:n]


def encode(text):
    body = text.encode("utf-8")
    return struct.pack("<I", len(body)) + body


class RawEnd:
    """One pipe connection with a reader thread that splits the byte stream into frames."""

    CHUNK = 32768

    def __init__(self, pipe, read=True):
        self.pipe = pipe
        self.peer_hwnd = 0
        self.frames = queue.Queue()
        self.closed = threading.Event()
        self._thread = None
        if read:
            self._thread = threading.Thread(target=self._read_loop, name="rawend-reader", daemon=True)
            self._thread.start()

    @classmethod
    def connect(cls, name, timeout=5.0, read=True):
        return cls(winpipe.OverlappedPipe.connect_client(name, timeout), read=read)

    def _read_loop(self):
        buf = bytearray()
        try:
            while not self.closed.is_set():
                data = self.pipe.read_some(0.1)
                if data is None:
                    continue
                buf.extend(data)
                while len(buf) >= 4:
                    (n,) = struct.unpack_from("<I", buf, 0)
                    if len(buf) < 4 + n:
                        break
                    self.frames.put(bytes(buf[4:4 + n]).decode("utf-8"))
                    del buf[:4 + n]
        except (winpipe.PipeClosed, OSError):
            pass
        finally:
            self.closed.set()

    # --- sending ---------------------------------------------------------------------------
    def send_bytes(self, data, wake_peer=True, chunk=None):
        """Writes in chunks and posts the wake message after each, like a sender that wakes per write."""
        chunk = chunk or self.CHUNK
        for off in range(0, len(data), chunk):
            self.pipe.write_all(data[off:off + chunk], timeout_s=10.0)
            if wake_peer:
                wake(self.peer_hwnd)

    def send_text(self, text, wake_peer=True):
        self.send_bytes(encode(text), wake_peer)

    # --- receiving -------------------------------------------------------------------------
    def recv(self, timeout=10.0):
        """Next frame text. Raises PipeClosed when the peer is gone and nothing is left, TimeoutError on timeout."""
        deadline = time.monotonic() + timeout
        while True:
            try:
                return self.frames.get(timeout=0.05)
            except queue.Empty:
                if self.closed.is_set():
                    try:
                        return self.frames.get_nowait()
                    except queue.Empty:
                        raise winpipe.PipeClosed("connection closed")
                if time.monotonic() > deadline:
                    raise TimeoutError("no frame within %.1f s" % timeout)

    def recv_until_hello(self, timeout=10.0):
        """Reads the 'hello:<hwnd>' frame an AHK peer sends first and stores the window handle."""
        text = self.recv(timeout)
        assert text.startswith("hello:"), text[:40]
        self.peer_hwnd = int(text[6:])
        return self.peer_hwnd

    def close(self):
        self.closed.set()
        self.pipe.close()
        if self._thread is not None:
            self._thread.join(timeout=2.0)


class PyServer:
    """Accepts connections on a pipe and runs handler(RawEnd) on its own thread for each."""

    def __init__(self, name, handler=None):
        self.name = name
        self.handler = handler or self.echo_handler
        self.ends = []
        self._stop = threading.Event()
        self._threads = []
        self._acceptor = None
        self.accepted = threading.Semaphore(0)

    @staticmethod
    def echo_handler(end):
        """Echoes every frame except 'hello:<hwnd>' (which sets the wake handle)."""
        while True:
            try:
                text = end.recv(timeout=0.2)
            except TimeoutError:
                if end.closed.is_set():
                    return
                continue
            except winpipe.PipeClosed:
                return
            if text.startswith("hello:"):
                end.peer_hwnd = int(text[6:])
                continue
            try:
                end.send_text(text)
            except (winpipe.PipeClosed, TimeoutError, OSError):
                return

    def start(self):
        self._acceptor = threading.Thread(target=self._accept_loop, name="pyserver-accept", daemon=True)
        self._acceptor.start()
        return self

    def _accept_loop(self):
        pipe = None
        try:
            while not self._stop.is_set():
                if pipe is None:
                    pipe = winpipe.OverlappedPipe.create_server(self.name)
                if pipe.wait_connect(0.1):
                    end = RawEnd(pipe)
                    pipe = None
                    self.ends.append(end)
                    t = threading.Thread(target=self._run, args=(end,), name="pyserver-conn", daemon=True)
                    self._threads.append(t)
                    t.start()
                    self.accepted.release()
        except OSError:
            pass
        finally:
            if pipe is not None:
                pipe.close()

    def _run(self, end):
        try:
            self.handler(end)
        finally:
            end.close()

    def wait_accept(self, timeout=10.0):
        if not self.accepted.acquire(timeout=timeout):
            raise TimeoutError("no client connected within %.1f s" % timeout)
        return self.ends[-1]

    def stop(self):
        self._stop.set()
        for end in list(self.ends):
            end.close()
        if self._acceptor is not None:
            self._acceptor.join(timeout=3.0)
        for t in self._threads:
            t.join(timeout=3.0)

    def __enter__(self):
        return self.start()

    def __exit__(self, *exc):
        self.stop()


def read_jsonl(path):
    """Parses a JSON-lines file that may be written to right now: an incomplete last line is ignored."""
    p = Path(path)
    if not p.exists():
        return []
    out = []
    data = None
    for _ in range(50):
        try:
            data = p.read_bytes()
            break
        except PermissionError:      # the AHK writer holds the file for a moment
            time.sleep(0.002)
    if data is None:
        return []
    for line in data.decode("utf-8-sig").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            break
    return out


class Helper:
    """An AutoHotkey helper script started through the ProcessTracker. Its result file is polled."""

    def __init__(self, procs, ahk_exe, datadir, script, *args, label="helper"):
        self.procs = procs
        self.script = Path(script)
        self.result = Path(datadir) / ("%s-%s.jsonl" % (label, id(self)))
        self._stdout = open(Path(datadir) / ("%s-%s.stdout" % (label, id(self))), "wb")
        self._stderr = open(Path(datadir) / ("%s-%s.stderr" % (label, id(self))), "wb")
        self.proc = procs.start([ahk_exe, "/ErrorStdOut=UTF-8", str(self.script), str(self.result), *map(str, args)],
                                stdout=self._stdout, stderr=self._stderr, cwd=str(self.script.parent))
        self.pid = self.proc.pid

    def records(self):
        return read_jsonl(self.result)

    def of_type(self, type_):
        return [r for r in self.records() if r.get("type") == type_]

    def wait_record(self, predicate, timeout=10.0, poll=0.005):
        """First record satisfying predicate (a dict -> bool, or a type name). Fails with diagnostics."""
        if isinstance(predicate, str):
            wanted = predicate
            predicate = lambda r: r.get("type") == wanted  # noqa: E731
        deadline = time.monotonic() + timeout
        while True:
            for r in self.records():
                if predicate(r):
                    return r
            if time.monotonic() > deadline or self.proc.poll() is not None:
                # one last look, then report
                for r in self.records():
                    if predicate(r):
                        return r
                raise AssertionError("no matching record from %s within %.1f s (exit=%s)\nrecords: %s\nstdout: %s\nstderr: %s"
                                     % (self.script.name, timeout, self.proc.poll(), self.records(),
                                        self.stdout_text(), self.stderr_text()))
            time.sleep(poll)

    def wait_exit(self, timeout=10.0):
        try:
            return self.proc.wait(timeout=timeout)
        except Exception:
            raise AssertionError("%s did not exit within %.1f s; records: %s" % (self.script.name, timeout, self.records()))

    def stdout_text(self):
        self._stdout.flush()
        return Path(self._stdout.name).read_bytes().decode("utf-8", "replace")

    def stderr_text(self):
        self._stderr.flush()
        return Path(self._stderr.name).read_bytes().decode("utf-8", "replace")

    def kill(self):
        """Kills the process without waiting (the caller measures the detection latency)."""
        import psutil
        try:
            psutil.Process(self.pid).kill()
        except psutil.NoSuchProcess:
            pass
