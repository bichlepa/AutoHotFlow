"""A local HTTP server for the tests of the internet elements (WI-0122, REQ-SEC-050).

It listens on 127.0.0.1 only and on a port the operating system picks, so no test request leaves the computer and no test
depends on a fixed port. It records every request (method, path, headers, body) and answers with the routes below. The
routes that echo the request answer like the httpbin service the v1 flows use (JSON with `args`, `headers`, `data`, `form`
and `url`), so the v1 flow "HTTP Request" can run against it with only its URLs changed.

Routes:
    /get, /post, /put   echo of the request as JSON (httpbin style; header names are capitalised like httpbin does)
    /text               "hello from the test server" as text/plain with a UTF-8 charset
    /bytes              the bytes 0 to 255 as application/octet-stream
    /redirect           302 to /get
    /status/<code>      an empty answer with that status code
    /slow?seconds=<n>   waits n seconds (at most 10), then answers like /get
    /proxy              (any absolute URL sent to this server as a proxy) answers with the URL it received
"""

import base64
import hashlib
import json
import threading
import time

import pytest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

HOST = "127.0.0.1"
MAX_SLOW_SECONDS = 10


class _Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):      # no output in the test log
        pass

    # --- the methods -------------------------------------------------------------------------------------------------
    def do_GET(self):
        self._handle()

    def do_POST(self):
        self._handle()

    def do_PUT(self):
        self._handle()

    def do_HEAD(self):
        self._handle()

    def do_DELETE(self):
        self._handle()

    def handle(self):
        # the client may go away at any time (a timeout or an abort of the element): nothing to answer then
        try:
            super().handle()
        except (ConnectionError, OSError):
            pass

    def _handle(self):
        self._answer()

    def _answer(self):
        server = self.server
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length > 0 else b""
        record = {
            "method": self.command,
            "target": self.path,
            "headers": {key.lower(): value for key, value in self.headers.items()},
            "raw_headers": list(self.headers.items()),
            "body": body,
        }
        with server.lock:
            server.requests.append(record)
        parts = urlsplit(self.path)
        if parts.scheme in ("http", "https"):            # a proxy request: the absolute URL
            return self._send(200, "text/plain; charset=utf-8", ("received: " + self.path).encode("utf-8"))
        route = parts.path
        query = parse_qs(parts.query)
        if route in ("/get", "/post", "/put", "/delete"):
            return self._echo(body)
        if route == "/text":
            return self._send(200, "text/plain; charset=utf-8", "hello from the test server".encode("utf-8"))
        if route == "/bytes":
            return self._send(200, "application/octet-stream", bytes(range(256)))
        if route == "/redirect":
            return self._send(302, "text/plain", b"", extra=[("Location", "/get")])
        if route.startswith("/status/"):
            try:
                code = int(route[len("/status/"):])
            except ValueError:
                code = 400
            return self._send(code, "text/plain", b"")
        if route == "/slow":
            try:
                seconds = min(float(query.get("seconds", ["1"])[0]), MAX_SLOW_SECONDS)
            except ValueError:
                seconds = 1.0
            time.sleep(seconds)
            return self._echo(body)
        return self._send(404, "text/plain", b"not found")

    def _echo(self, body):
        headers = {}
        for key, value in self.headers.items():
            headers[_title(key)] = value
        form = {}
        content_type = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        if content_type == "application/x-www-form-urlencoded":
            form = {key: values[0] for key, values in parse_qs(body.decode("utf-8", "replace")).items()}
        url = "http://%s:%d%s" % (HOST, self.server.server_address[1], self.path)
        data = body.decode("utf-8", "replace")
        answer = {"args": {}, "headers": headers, "data": data, "form": form, "url": url, "method": self.command}
        payload = json.dumps(answer).encode("utf-8")
        self._send(200, "application/json", payload)

    def _send(self, code, content_type, payload, extra=()):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        for name, value in extra:
            self.send_header(name, value)
        self.end_headers()
        if self.command != "HEAD" and payload:
            self.wfile.write(payload)


def _title(name):
    """httpbin spells the headers in title case (Content-Type, User-Agent)."""
    return "-".join(part.capitalize() for part in name.split("-"))


class LocalServer:
    """The running server. `url(path)` builds an URL of it; `requests()` lists what it received."""

    def __init__(self):
        self._httpd = ThreadingHTTPServer((HOST, 0), _Handler)
        self._httpd.daemon_threads = True
        self._httpd.lock = threading.Lock()
        self._httpd.requests = []
        self._thread = threading.Thread(target=self._httpd.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True)

    @property
    def port(self):
        return self._httpd.server_address[1]

    def start(self):
        self._thread.start()
        return self

    def stop(self):
        self._httpd.shutdown()
        self._httpd.server_close()

    def url(self, path="/get"):
        return "http://%s:%d%s" % (HOST, self.port, path)

    def requests(self):
        with self._httpd.lock:
            return list(self._httpd.requests)

    def clear(self):
        with self._httpd.lock:
            self._httpd.requests.clear()


@pytest.fixture
def local_server():
    """A running LocalServer for one test; stopped at its end."""
    server = LocalServer().start()
    yield server
    server.stop()


def content_md5(body: bytes) -> str:
    """The Content-MD5 header value of a body: the base64 of its MD5 digest (RFC 1864)."""
    return base64.b64encode(hashlib.md5(body).digest()).decode("ascii")
