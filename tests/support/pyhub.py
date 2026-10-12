"""Small Python stand-in for the supervisor hub (doc/PROTOCOL 1 and 3).

Used by the tests of the client and, later, by role tests without a real supervisor.
It answers sys.hello with sys.welcome, routes messages by `to`, sets `from` to the
registered name of the sender, answers unknown cmd.* with a not_found error, and
fans out topic messages to subscribers. It is deliberately simple and is not the
production hub.
"""

import threading

from support import winpipe
from support.ahfclient import FrameDecoder, encode_frame, dumps, make_envelope, wake


class _Link:
    """One connected client as seen by the hub."""

    def __init__(self, pipe):
        self.pipe = pipe
        self.name = None
        self.hwnd = 0
        self.topics = set()
        self.write_failed = False

    def send(self, env):
        try:
            self.pipe.write_all(encode_frame(dumps(env)))
            return True
        except (winpipe.PipeClosed, TimeoutError, OSError):
            self.write_failed = True
            return False


class PyHub:
    def __init__(self, pipe_name, session="pyhub"):
        self.pipe_name = pipe_name
        self.session = session
        self.received = []          # every decoded frame, in arrival order (copies)
        self._links = []
        self._lock = threading.Lock()
        self._cond = threading.Condition(self._lock)
        self._stop = False
        self._threads = []
        self._acceptor = None
        self._ids = 0

    # --- lifecycle -----------------------------------------------------------
    def start(self):
        self._acceptor = threading.Thread(target=self._accept_loop, name="pyhub-accept", daemon=True)
        self._acceptor.start()
        return self

    def stop(self):
        with self._lock:
            self._stop = True
            links = list(self._links)
        for link in links:
            link.pipe.close()
        if self._acceptor is not None:
            self._acceptor.join(timeout=3.0)
        for t in self._threads:
            t.join(timeout=3.0)

    def __enter__(self):
        return self.start()

    def __exit__(self, *exc):
        self.stop()

    # --- inspection for tests ---------------------------------------------------
    def peers(self):
        with self._lock:
            return sorted(l.name for l in self._links if l.name)

    def wait_for_peer(self, name, timeout=5.0):
        with self._cond:
            return self._cond.wait_for(lambda: name in [l.name for l in self._links], timeout)

    def wait_received(self, predicate, timeout=5.0):
        """Waits until a received message satisfies predicate and returns it."""
        def find():
            for msg in self.received:
                if predicate(msg):
                    return msg
            return None
        with self._cond:
            found = [None]

            def check():
                found[0] = find()
                return found[0] is not None
            self._cond.wait_for(check, timeout)
            return found[0]

    # --- internals ---------------------------------------------------------------
    def _accept_loop(self):
        pipe = None
        try:
            while not self._stop:
                if pipe is None:
                    pipe = winpipe.OverlappedPipe.create_server(self.pipe_name)
                if pipe.wait_connect(0.1):
                    link = _Link(pipe)
                    pipe = None
                    t = threading.Thread(target=self._serve, args=(link,), name="pyhub-client", daemon=True)
                    self._threads.append(t)
                    t.start()
        except OSError:
            pass
        finally:
            if pipe is not None:
                pipe.close()

    def _serve(self, link):
        decoder = FrameDecoder()
        try:
            with self._lock:
                self._links.append(link)
            while not self._stop and not link.write_failed:
                data = link.pipe.read_some(0.1)
                if data is None:
                    continue
                for msg in decoder.feed(data):
                    self._handle(link, msg)
        except (winpipe.PipeClosed, OSError, ValueError):
            pass
        finally:
            with self._cond:
                if link in self._links:
                    self._links.remove(link)
                self._cond.notify_all()
            link.pipe.close()

    def _handle(self, link, msg):
        with self._cond:
            self.received.append(msg)
            self._cond.notify_all()
        type_ = msg.get("type", "")
        if type_ == "sys.hello" and link.name is None:
            payload = msg.get("payload", {})
            link.name = payload.get("name")
            link.hwnd = payload.get("hwnd", 0)
            peers = self._peer_table()
            self._reply(link, msg, "sys.welcome",
                        {"ok": True, "session": self.session, "peers": peers, "settingsRev": 0})
            # Like the supervisor (PROTOCOL 4.1a): a role that said hello is ready, subscribers of "process" hear it.
            self._publish("process", "evt.process.ready", {"name": link.name, "pid": 0})
            return
        if link.name is None:
            return  # nothing is routed before the handshake
        if type_ == "cmd.topic.subscribe":
            link.topics.add(msg.get("payload", {}).get("topic"))
            self._reply(link, msg, "res.topic.subscribe", {"ok": True})
            return
        if type_ == "cmd.topic.unsubscribe":
            link.topics.discard(msg.get("payload", {}).get("topic"))
            self._reply(link, msg, "res.topic.unsubscribe", {"ok": True})
            return
        to = msg.get("to", "")
        if to == "supervisor" and type_ == "cmd.process.list":
            # The peers that are connected count as ready children (PROTOCOL 4.1).
            procs = [{"name": n, "role": n.split(":")[0], "state": "ready", "pid": 0, "restarts": 0}
                     for n in self._peer_table()]
            self._reply(link, msg, "res.process.list", {"ok": True, "processes": procs})
            return
        if to.startswith("topic:"):
            topic = to[len("topic:"):]
            with self._lock:
                targets = [l for l in self._links if topic in l.topics and l is not link]
            for target in targets:
                target.send(self._forward(link, msg))
            return
        with self._lock:
            target = next((l for l in self._links if l.name == to), None)
        if target is not None:
            target.send(self._forward(link, msg))
        elif type_.startswith("cmd."):
            self._reply(link, msg, "res." + type_[4:],
                        {"ok": False, "error": {"code": "not_found", "message": "no peer " + str(to)}})

    def _publish(self, topic, type_, payload):
        with self._lock:
            targets = [l for l in self._links if topic in l.topics]
        for target in targets:
            self._ids += 1
            target.send(make_envelope("supervisor", "supervisor#%d" % self._ids, "topic:" + topic, type_, None, None,
                                      payload))

    def _forward(self, sender, msg):
        """Copy of the message with `from` set by the hub, keeping the envelope key order."""
        env = make_envelope(sender.name, msg.get("id"), msg.get("to"), msg.get("type"),
                            msg.get("corr"), msg.get("timeoutMs"), msg.get("payload"))
        return env

    def _reply(self, link, request, type_, payload):
        self._ids += 1
        env = make_envelope("supervisor", "supervisor#%d" % self._ids, request.get("from"), type_,
                            request.get("id"), None, payload)
        link.send(env)

    def _peer_table(self):
        with self._lock:
            return {l.name: {"hwnd": l.hwnd} for l in self._links if l.name}


class WakingHub(PyHub):
    """PyHub that wakes every peer window that has announced one, after each routed message.

    PROTOCOL 1 asks the sender to post the wake-up. Without it each message waits for the 250 ms
    fallback timer of the receiver. Moved here from test_peer.py in WI-07.
    """

    def _handle(self, link, msg):
        super()._handle(link, msg)
        with self._lock:
            hwnds = [l.hwnd for l in self._links if l.hwnd]
        for hwnd in hwnds:
            wake(hwnd)
