"""WI-0122: end-to-end tests of the internet elements of the package Default: Download file and HTTP request.

No request leaves the computer (REQ-SEC-050): every URL of this file points to the local server of support/localhttp.py,
which listens on 127.0.0.1 only. The one unreachable URL uses a port that nothing listens on (found and closed first), and
the scheme test uses a URL that is refused before any connection is made.

The HTTP request is checked from both sides: the flow's variables (text, headers) and the requests that the server
received (method, headers, body bytes).
"""

import json
import socket

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.localhttp import content_md5, local_server  # noqa: F401  (fixture)


def element_flow(name, cls, probe=(), **pars):
    """trigger -> the element -> (probes of the variables; one name or a tuple of names)."""
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    names = [probe] if isinstance(probe, str) else list(probe)
    fb.chain(fb.trigger(), el, *[fb.probe(n) for n in names])
    return fb


def message_of(run):
    assert run.exceptions, run.steps
    return run.exceptions[0]


def closed_port_url(path="/"):
    """An URL of 127.0.0.1 with a port that nothing listens on: the socket is bound, read its port and closed again."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    return "http://127.0.0.1:%d%s" % (port, path)


def request_to(server, path):
    """The recorded requests whose target is path (without query)."""
    return [r for r in server.requests() if r["target"].split("?")[0] == path]


def header_of(record, name):
    return record["headers"].get(name.lower())


def http_flow(name, server, path="/get", **pars):
    """An HTTP request of the test server into the variables resp (body text) and hdr (response headers)."""
    return element_flow(name, "Action_HTTP_Request", probe=("resp", "hdr"), URL=server.url(path), ResponseDataVar="resp",
                        ResponseHeadersVar="hdr", **pars)


def echo_of(run):
    return json.loads(run.seen["resp"].text)


# --- Download file -----------------------------------------------------------------------------------------------------
def download_flow(name, url, target, **pars):
    return element_flow(name, "Action_Download_File", URL=url, file=str(target), **pars)


def test_download_writes_the_body_of_the_url_to_the_file(flows, local_server, tmp_path):
    target = tmp_path / "bytes.bin"
    runs = run_all(flows, [download_flow("dl", local_server.url("/bytes"), target)])
    assert not runs[0].exceptions, runs[0].steps
    assert target.read_bytes() == bytes(range(256))
    assert request_to(local_server, "/bytes")[0]["method"] == "GET"


def test_download_follows_a_redirect(flows, local_server, tmp_path):
    target = tmp_path / "redirected.json"
    runs = run_all(flows, [download_flow("dl_redirect", local_server.url("/redirect"), target)])
    assert not runs[0].exceptions, runs[0].steps
    assert json.loads(target.read_text(encoding="utf-8"))["url"].endswith("/get")


def test_download_to_a_folder_is_an_exception(flows, local_server, tmp_path):
    runs = run_all(flows, [download_flow("dl_folder", local_server.url("/bytes"), tmp_path)])
    assert "is a folder" in message_of(runs[0])
    assert not request_to(local_server, "/bytes")


def test_download_into_a_missing_folder_is_an_exception(flows, local_server, tmp_path):
    runs = run_all(flows, [download_flow("dl_nodir", local_server.url("/bytes"), tmp_path / "nope" / "x.bin")])
    assert "does not exist" in message_of(runs[0])
    assert not request_to(local_server, "/bytes")


def test_download_to_a_drive_root_is_refused(flows, local_server):
    runs = run_all(flows, [download_flow("dl_root", local_server.url("/bytes"), "C:\\")])
    assert "drive root" in message_of(runs[0])
    assert not request_to(local_server, "/bytes")


def test_download_from_a_closed_port_is_an_exception(flows, tmp_path):
    target = tmp_path / "never.bin"
    runs = run_all(flows, [download_flow("dl_closed", closed_port_url("/x"), target)])
    assert "Couldn't download URL" in message_of(runs[0])
    assert not target.exists()


# --- HTTP request: the default (GET, variable, automatic) --------------------------------------------------------------
def test_get_puts_the_body_and_the_headers_into_variables(flows, local_server):
    runs = run_all(flows, [http_flow("get", local_server)])
    assert not runs[0].exceptions, runs[0].steps
    echo = echo_of(runs[0])
    assert echo["url"].endswith("/get") and echo["method"] == "GET"
    assert "content-type" in runs[0].seen["hdr"].text.lower()
    assert request_to(local_server, "/get")[0]["method"] == "GET"


def test_a_status_other_than_2xx_is_no_exception(flows, local_server):
    """As in v1 the status is not an error: the body (empty here) goes into the variable and the element ends normal."""
    runs = run_all(flows, [http_flow("not_found", local_server, path="/status/404")])
    assert not runs[0].exceptions, runs[0].steps
    assert runs[0].seen["resp"].text == ""


def test_redirect_is_followed(flows, local_server):
    runs = run_all(flows, [http_flow("redirect", local_server, path="/redirect")])
    assert not runs[0].exceptions, runs[0].steps
    assert echo_of(runs[0])["url"].endswith("/get")


def test_a_slow_answer_arrives_before_the_deadline(flows, local_server):
    runs = run_all(flows, [http_flow("slow", local_server, path="/slow?seconds=1")])
    assert not runs[0].exceptions, runs[0].steps
    assert echo_of(runs[0])["url"].endswith("/slow?seconds=1")


def test_a_text_answer_keeps_its_characters(flows, local_server):
    runs = run_all(flows, [http_flow("text", local_server, path="/text")])
    assert not runs[0].exceptions, runs[0].steps
    assert runs[0].seen["resp"].text == "hello from the test server"


def test_a_connection_that_is_refused_is_an_exception(flows):
    runs = run_all(flows, [element_flow("refused", "Action_HTTP_Request", probe="resp", URL=closed_port_url("/get"),
                                        ResponseDataVar="resp")])
    assert "failed" in message_of(runs[0])


def test_a_scheme_other_than_http_is_refused_before_a_connection(flows):
    runs = run_all(flows, [element_flow("ftp", "Action_HTTP_Request", probe="resp", URL="ftp://127.0.0.1/file",
                                        ResponseDataVar="resp")])
    assert "does not support this URL" in message_of(runs[0])


def test_a_request_header_without_colon_is_an_exception(flows, local_server):
    runs = run_all(flows, [http_flow("badheader", local_server, RequestHeaders="no colon here")])
    assert "has no colon" in message_of(runs[0])
    assert not request_to(local_server, "/get")


def test_request_headers_and_user_agent_are_sent(flows, local_server):
    runs = run_all(flows, [http_flow("headers", local_server, RequestHeaders="test:test big:value\nX-Extra: 42",
                                     WhichUserAgent="custom", UserAgent="myuseragent")])
    assert not runs[0].exceptions, runs[0].steps
    record = request_to(local_server, "/get")[-1]
    assert header_of(record, "Test") == "test big:value"
    assert header_of(record, "X-Extra") == "42"
    assert header_of(record, "User-Agent") == "myuseragent"


def test_a_custom_proxy_is_accepted_and_loopback_is_sent_direct(flows, local_server):
    """WinHTTP does not send a request to 127.0.0.1 through a proxy (the loopback address is bypassed; checked with a
    listener, WI-0122), so the test shows that the custom proxy is accepted and the request reaches the server directly.
    A request through a real proxy is not tested: that would need a second host (REQ-SEC-050)."""
    proxy = "127.0.0.1:%d" % local_server.port
    url = local_server.url("/get")
    runs = run_all(flows, [element_flow("proxy", "Action_HTTP_Request", probe="resp", URL=url, ResponseDataVar="resp",
                                        WhichProxy="custom", Proxy=proxy)])
    assert not runs[0].exceptions, runs[0].steps
    assert echo_of(runs[0])["url"].endswith("/get")


# --- HTTP request: the post data --------------------------------------------------------------------------------------
def test_post_text_with_its_content_type(flows, local_server):
    runs = run_all(flows, [http_flow("post", local_server, path="/post", WhereToGetPostData="Specified",
                                     PostData="hello world", WhichContentType="custom", Contenttype="text/plain")])
    assert not runs[0].exceptions, runs[0].steps
    echo = echo_of(runs[0])
    assert echo["data"] == "hello world" and echo["method"] == "POST"
    record = request_to(local_server, "/post")[-1]
    assert header_of(record, "Content-Type") == "text/plain"


def test_post_form_data_is_parsed_by_the_server(flows, local_server):
    runs = run_all(flows, [http_flow("form", local_server, path="/post", WhereToGetPostData="Specified",
                                     PostData="helloworld=12", WhichContentType="custom",
                                     Contenttype="application/x-www-form-urlencoded")])
    assert not runs[0].exceptions, runs[0].steps
    assert echo_of(runs[0])["form"] == {"helloworld": "12"}


def test_automatic_content_md5_is_the_md5_of_the_body(flows, local_server):
    runs = run_all(flows, [http_flow("md5", local_server, path="/post", WhereToGetPostData="Specified",
                                     PostData="hello world", WhichContentMD5="automatic")])
    assert not runs[0].exceptions, runs[0].steps
    record = request_to(local_server, "/post")[-1]
    assert header_of(record, "Content-MD5") == content_md5(b"hello world") == "XrY7u+Ae7tCTyyK7j1rNww=="


def test_custom_content_md5_is_sent_as_it_is(flows, local_server):
    runs = run_all(flows, [http_flow("md5c", local_server, path="/post", WhereToGetPostData="Specified",
                                     PostData="x", WhichContentMD5="custom", ContentMD5="abc123")])
    assert not runs[0].exceptions, runs[0].steps
    assert header_of(request_to(local_server, "/post")[-1], "Content-MD5") == "abc123"


def test_post_text_in_a_codepage_is_sent_in_that_codepage(flows, local_server):
    runs = run_all(flows, [http_flow("cp", local_server, path="/post", WhereToGetPostData="Specified",
                                     PostData="gr\u00fc\u00dfe", WhichCodepage="definedCodepage", Codepage="1252")])
    assert not runs[0].exceptions, runs[0].steps
    assert request_to(local_server, "/post")[-1]["body"] == "gr\u00fc\u00dfe".encode("cp1252")


def test_an_unknown_codepage_is_an_exception(flows, local_server):
    runs = run_all(flows, [http_flow("badcp", local_server, path="/post", WhereToGetPostData="Specified",
                                     PostData="x", WhichCodepage="definedCodepage", Codepage="no-such-codepage")])
    assert "is not known" in message_of(runs[0])
    assert not request_to(local_server, "/post")


def test_uri_encoded_post_data(flows, local_server):
    runs = run_all(flows, [http_flow("uri", local_server, path="/post", WhereToGetPostData="Specified",
                                     PostData="a b&c", URIEncodePostData=1)])
    assert not runs[0].exceptions, runs[0].steps
    assert request_to(local_server, "/post")[-1]["body"] == b"a%20b%26c"


def test_post_data_from_a_file_is_uploaded_as_it_is(flows, local_server, tmp_path):
    source = tmp_path / "upload.bin"
    source.write_bytes(b"\x00\x01binary\xff")
    runs = run_all(flows, [http_flow("upload", local_server, path="/post", WhereToGetPostData="File",
                                     InputFile=str(source))])
    assert not runs[0].exceptions, runs[0].steps
    assert request_to(local_server, "/post")[-1]["body"] == b"\x00\x01binary\xff"


def test_post_data_from_a_missing_file_is_an_exception(flows, local_server, tmp_path):
    runs = run_all(flows, [http_flow("upload_missing", local_server, path="/post", WhereToGetPostData="File",
                                     InputFile=str(tmp_path / "missing.bin"))])
    assert "does not exist" in message_of(runs[0])


# --- HTTP request: method and response file ---------------------------------------------------------------------------
def test_a_custom_method_is_used(flows, local_server):
    runs = run_all(flows, [http_flow("put", local_server, path="/put", WhichMethod="custom", Method="PUT")])
    assert not runs[0].exceptions, runs[0].steps
    assert request_to(local_server, "/put")[-1]["method"] == "PUT"


def test_the_automatic_method_is_post_with_data_and_get_without(flows, local_server):
    runs = run_all(flows, [http_flow("auto_get", local_server), http_flow("auto_post", local_server, path="/post",
                                                                          WhereToGetPostData="Specified", PostData="p")])
    assert not runs[0].exceptions and not runs[1].exceptions
    assert request_to(local_server, "/get")[-1]["method"] == "GET"
    assert request_to(local_server, "/post")[-1]["method"] == "POST"


def test_the_response_goes_into_a_file_and_no_variable_is_set(flows, local_server, tmp_path):
    target = tmp_path / "answer.json"
    runs = run_all(flows, [element_flow("to_file", "Action_HTTP_Request", URL=local_server.url("/get"),
                                        WhereToPutResponseData="File", OutputFile=str(target))])
    assert not runs[0].exceptions, runs[0].steps
    assert json.loads(target.read_text(encoding="utf-8"))["url"].endswith("/get")


def test_a_response_file_in_a_missing_folder_is_an_exception(flows, local_server, tmp_path):
    runs = run_all(flows, [element_flow("to_file_nodir", "Action_HTTP_Request", URL=local_server.url("/get"),
                                        WhereToPutResponseData="File", OutputFile=str(tmp_path / "no" / "a.json"))])
    assert "does not exist" in message_of(runs[0])


def test_a_response_file_that_is_a_folder_is_an_exception(flows, local_server, tmp_path):
    runs = run_all(flows, [element_flow("to_folder", "Action_HTTP_Request", URL=local_server.url("/get"),
                                        WhereToPutResponseData="File", OutputFile=str(tmp_path))])
    assert "is a folder" in message_of(runs[0])
