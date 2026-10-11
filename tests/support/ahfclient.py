"""Python client for the AutoHotFlow v2 IPC protocol (doc/PROTOKOLL.md, protocol version 1).

Frame: uint32 little endian length + UTF-8 JSON. Envelope key order: to, from, id, type,
corr, timeoutMs, payload (head fields first, so a hub can route without parsing the payload).

A reader thread takes incoming frames. Messages with a `corr` are answers and wake the
request that waits for them. All other messages are queued as events. `sys.ping` is answered
automatically.
"""

import collections
import ctypes
import json
import os
import struct
import threading
import time

from support import winpipe, wirebool

PROTOCOL_VERSION = 1
MAX_FRAME = 16 * 1024 * 1024
WM_AHF_WAKE = 0x8001


class ProtocolError(Exception):
    """Malformed frame or envelope."""


class AhfTimeout(Exception):
    """No answer within the requested time."""


def encode_frame(text):
    """Returns the frame bytes for an already serialized JSON text."""
    body = text.encode("utf-8")
    if len(body) > MAX_FRAME:
        raise ProtocolError("frame too large: %d bytes" % len(body))
    return struct.pack("<I", len(body)) + body


def make_envelope(sender, msg_id, to, type_, corr=None, timeout_ms=None, payload=None):
    """Builds the envelope dict in the protocol key order."""
    env = {"to": to, "from": sender, "id": msg_id, "type": type_, "corr": corr}
    if timeout_ms is not None:
        env["timeoutMs"] = timeout_ms
    env["payload"] = {} if payload is None else payload
    return env


def dumps(env):
    """Serializes an envelope, keeping the order of its keys and the JSON types of its values."""
    return json.dumps(env, ensure_ascii=False, separators=(",", ":"))


class FrameDecoder:
    """Accumulates bytes and yields complete frames as decoded JSON text."""

    def __init__(self):
        self._buf = bytearray()

    def feed(self, data):
        self._buf.extend(data)
        out = []
        while len(self._buf) >= 4:
            (length,) = struct.unpack_from("<I", self._buf, 0)
            if length > MAX_FRAME:
                raise ProtocolError("frame length %d exceeds limit" % length)
            if len(self._buf) < 4 + length:
                break
            body = bytes(self._buf[4:4 + length])
            del self._buf[:4 + length]
            try:
                msg = json.loads(body.decode("utf-8"))
            except (UnicodeDecodeError, ValueError) as exc:
                raise ProtocolError("invalid JSON frame: %s" % exc)
            wirebool.record(msg)  # strict check of truth values (WI-26)
            out.append(msg)
        return out


def wake(peer_hwnd):
    """Posts the wake message to a window handle. Returns False if the window does not exist."""
    return bool(ctypes.windll.user32.PostMessageW(peer_hwnd, WM_AHF_WAKE, 0, 0))


def topic_address(topic):
    """Accepts 'engine' or 'topic:engine' and returns the envelope address 'topic:engine'."""
    return topic if topic.startswith("topic:") else "topic:" + topic


class AhfClient:
    """A protocol peer connected to a hub pipe. Use as a context manager or call close()."""

    def __init__(self, pipe_name, name, connect_timeout=5.0, hub="supervisor", hwnd=0):
        self.name = name
        self.pid = os.getpid()
        self.hub = hub
        self._pipe = winpipe.OverlappedPipe.connect_client(pipe_name, connect_timeout)
        self._seq = 0
        self._seq_lock = threading.Lock()
        self._cond = threading.Condition()
        self._answers = {}
        self._events = collections.deque()
        self._closed = False
        self._decoder = FrameDecoder()
        self._reader = threading.Thread(target=self._read_loop, name="ahf-client-reader", daemon=True)
        self._reader.start()
        self.welcome = None
        hello_id = self.send(hub, "sys.hello", {"name": name, "pid": self.pid, "hwnd": hwnd,
                                                "protocol": PROTOCOL_VERSION})
        self.welcome = self._wait_answer(hello_id, connect_timeout)

    # --- public API ----------------------------------------------------------
    def next_id(self):
        with self._seq_lock:
            self._seq += 1
            return "%s#%d" % (self.name, self._seq)

    def send(self, to, type_, payload=None, corr=None, timeout_ms=None):
        """Sends a message without waiting. Returns the message id."""
        msg_id = self.next_id()
        env = make_envelope(self.name, msg_id, to, type_, corr, timeout_ms, payload)
        self._write(dumps(env))
        return msg_id

    def reply(self, request, payload=None, type_=None):
        """Answers a request message. The answer type defaults to 'res.' + the request type without 'cmd.'."""
        if type_ is None:
            base = request["type"]
            type_ = "res." + (base[4:] if base.startswith("cmd.") else base)
        return self.send(request["from"], type_, payload, corr=request["id"])

    def request(self, to, type_, payload=None, timeout=5.0):
        """Sends a cmd.* request and returns the answer envelope. Raises AhfTimeout after `timeout` seconds."""
        msg_id = self.send(to, type_, payload, timeout_ms=int(timeout * 1000))
        return self._wait_answer(msg_id, timeout)

    def events(self, topic=None, timeout=5.0):
        """Yields incoming non-answer messages. Stops after `timeout` seconds without a new message.

        If topic is given, only messages addressed to that topic are yielded.
        """
        want = topic_address(topic) if topic else None
        while True:
            msg = self._next_event(timeout)
            if msg is None:
                return
            if want is None or msg.get("to") == want:
                yield msg

    def wait_event(self, type_, timeout=5.0):
        """Returns the first event (or request) of the given type, or raises AhfTimeout."""
        for msg in self.events(timeout=timeout):
            if msg.get("type") == type_:
                return msg
        raise AhfTimeout("no %s within %.1f s" % (type_, timeout))

    def wake(self, peer_hwnd):
        return wake(peer_hwnd)

    def close(self):
        self._closed = True
        self._pipe.close()  # idempotent; also cancels a blocked read
        self._reader.join(timeout=2.0)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    # --- internals -----------------------------------------------------------
    def _write(self, text):
        if self._closed:
            raise winpipe.PipeClosed("client closed")
        self._pipe.write_all(encode_frame(text))

    def _wait_answer(self, corr, timeout):
        deadline = time.monotonic() + timeout
        with self._cond:
            while corr not in self._answers:
                if self._closed:
                    raise winpipe.PipeClosed("connection lost while waiting for " + corr)
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise AhfTimeout("no answer to %s within %.1f s" % (corr, timeout))
                self._cond.wait(remaining)
            return self._answers.pop(corr)

    def _next_event(self, timeout):
        deadline = time.monotonic() + timeout
        with self._cond:
            while not self._events:
                if self._closed:
                    return None
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return None
                self._cond.wait(remaining)
            return self._events.popleft()

    def _read_loop(self):
        try:
            while not self._closed:
                data = self._pipe.read_some(0.1)
                if data is None:
                    continue
                for msg in self._decoder.feed(data):
                    self._dispatch(msg)
        except (winpipe.PipeClosed, ProtocolError, OSError):
            pass
        finally:
            with self._cond:
                self._closed = True
                self._cond.notify_all()

    def _dispatch(self, msg):
        if msg.get("type") == "sys.ping":
            self.send(msg["from"], "sys.pong", {"n": msg.get("payload", {}).get("n")})
            return
        with self._cond:
            if msg.get("corr") is not None:
                self._answers[msg["corr"]] = msg
            else:
                self._events.append(msg)
            self._cond.notify_all()
