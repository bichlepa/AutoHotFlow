"""WI-0115: the setup tool of the WebView2 loader (tools/fetch_webview2_loader.py). No download happens here: the network
is replaced by a fake package, the tool's pins are checked for their form, and the refusals are checked (a package or a
DLL with a wrong hash is never installed; a redirect away from nuget.org is refused).
"""

import importlib.util
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "fetch_webview2_loader.py"


@pytest.fixture
def tool(tmp_path, monkeypatch):
    spec = importlib.util.spec_from_file_location("fetch_webview2_loader", TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.TARGET_DIR = str(tmp_path / "bin")
    module.TARGET = str(tmp_path / "bin" / "WebView2Loader.dll")
    return module


def test_the_pins_have_the_form_of_sha256_and_the_official_url(tool):
    for pin in (tool.PACKAGE_SHA256, tool.DLL_SHA256):
        assert re.fullmatch(r"[0-9a-f]{64}", pin), pin
    assert tool.URL == "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/" + tool.VERSION
    assert tool.MEMBER == "build/native/x64/WebView2Loader.dll"


def test_check_is_false_without_the_file(tool):
    assert tool.check() is False


def test_check_refuses_a_file_with_another_hash(tool):
    Path(tool.TARGET).parent.mkdir(parents=True)
    Path(tool.TARGET).write_bytes(b"not the loader")
    assert tool.check() is False


def test_a_package_with_a_wrong_hash_is_not_installed(tool, monkeypatch):
    def fake_download(dest):
        Path(dest).write_bytes(b"PK not the package")
    monkeypatch.setattr(tool, "download", fake_download)
    with pytest.raises(SystemExit, match="does not match"):
        tool.fetch()
    assert not Path(tool.TARGET).exists()


def test_a_redirect_away_from_nuget_is_refused(tool):
    handler = tool._NugetOnly()
    with pytest.raises(OSError, match="refused redirect"):
        handler.redirect_request(None, None, 302, "Found", {}, "https://example.com/package.nupkg")
    with pytest.raises(OSError, match="refused redirect"):
        handler.redirect_request(None, None, 302, "Found", {}, "http://www.nuget.org/x")


def test_the_loader_is_ignored_by_git():
    text = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert "/assets/bin/" in text.splitlines()


def test_the_setup_task_exists_and_runs_the_tool_in_isolated_mode():
    text = (ROOT / ".vscode" / "tasks.json").read_text(encoding="utf-8")
    assert text.count('"label": "Setup: WebView2 loader') == 1
    assert '"-I",\n                "tools/fetch_webview2_loader.py"' in text
