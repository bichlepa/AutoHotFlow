"""Fetch WebView2Loader.dll (x64) from the NuGet package Microsoft.Web.WebView2 (WI-0115, E0099).

The loader is the one file of the WebView2 SDK that AutoHotFlow needs to start the help viewer. This tool downloads the
pinned package from nuget.org, checks its SHA-256, extracts only build/native/x64/WebView2Loader.dll, checks the DLL's
SHA-256 and writes it to assets/bin/ (git-ignored, never committed). Shipping the DLL with the program is S0009.

The package is untrusted input: it is downloaded into a new empty temporary directory, only one member is read from it
(zipfile, no extraction of the other members, nothing is run from it), and the directory is removed afterwards.

License (checked on the package's LICENSE.txt, version 1.0.2739.15): the binary form may be redistributed when the
copyright notice is kept and the name of Microsoft is not used for endorsement.

Usage (run with -I, the tool only reads the package):
    python -I tools/fetch_webview2_loader.py            download (when missing or the hash is wrong), verify
    python -I tools/fetch_webview2_loader.py --check    verify the DLL that is there, no download (exit 1 when missing)
    python -I tools/fetch_webview2_loader.py --force    download again even when the DLL is there
"""
import argparse
import hashlib
import os
import shutil
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile

PACKAGE = "Microsoft.Web.WebView2"
VERSION = "1.0.2739.15"
# SHA-256 of the .nupkg as downloaded from nuget.org (first download, 2026-10-21; not verified against a second source).
PACKAGE_SHA256 = "f13e5564de93c0d35064a6e3a65eb4fd501256cb394d00a52229eb4d446722db"
# Member of the package and SHA-256 of the extracted DLL (first download, same caveat).
MEMBER = "build/native/x64/WebView2Loader.dll"
DLL_SHA256 = "f4d811cda483adb33220c5a856c5ec8dca3a095fde54b44f08e1279a6a5efd33"
DLL_SIZE = 165464

URL = f"https://www.nuget.org/api/v2/package/{PACKAGE}/{VERSION}"
ALLOWED_HOST_SUFFIX = "nuget.org"
MAX_PACKAGE_BYTES = 40 * 1024 * 1024

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_DIR = os.path.join(ROOT, "assets", "bin")
TARGET = os.path.join(TARGET_DIR, "WebView2Loader.dll")


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


class _NugetOnly(urllib.request.HTTPRedirectHandler):
    """Redirects are followed only to https hosts of nuget.org."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        host = urllib.parse.urlsplit(newurl).hostname or ""
        if urllib.parse.urlsplit(newurl).scheme != "https" or not (
                host == ALLOWED_HOST_SUFFIX or host.endswith("." + ALLOWED_HOST_SUFFIX)):
            raise OSError(f"refused redirect to {newurl}")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def download(dest):
    opener = urllib.request.build_opener(_NugetOnly)
    with opener.open(URL, timeout=60) as response, open(dest, "wb") as out:
        total = 0
        while True:
            chunk = response.read(65536)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_PACKAGE_BYTES:
                raise OSError("package is larger than the limit")
            out.write(chunk)


def fetch():
    """Download, verify and install the DLL. Returns the path of the DLL."""
    work = tempfile.mkdtemp(prefix="ahf_webview2_")
    try:
        package = os.path.join(work, "package.nupkg")
        print(f"downloading {PACKAGE} {VERSION} from nuget.org")
        download(package)
        if sha256_of(package) != PACKAGE_SHA256:
            raise SystemExit("the package's SHA-256 does not match the pin in the tool; nothing was installed")
        with zipfile.ZipFile(package) as z:
            data = z.read(MEMBER)          # the one member, read into memory; nothing else is extracted
        if len(data) != DLL_SIZE:
            raise SystemExit(f"the member has {len(data)} bytes, expected {DLL_SIZE}; nothing was installed")
        dll = os.path.join(work, "WebView2Loader.dll")
        with open(dll, "wb") as f:
            f.write(data)
        if sha256_of(dll) != DLL_SHA256:
            raise SystemExit("the DLL's SHA-256 does not match the pin in the tool; nothing was installed")
        os.makedirs(TARGET_DIR, exist_ok=True)
        tmp_target = TARGET + ".part"
        shutil.copyfile(dll, tmp_target)
        os.replace(tmp_target, TARGET)
        return TARGET
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check():
    """True when the DLL is there and has the pinned hash."""
    if not os.path.isfile(TARGET):
        print(f"missing: {TARGET}")
        return False
    if sha256_of(TARGET) != DLL_SHA256:
        print(f"hash mismatch: {TARGET} (run without --check to fetch it again)")
        return False
    print(f"ok: {TARGET} ({PACKAGE} {VERSION}, x64)")
    return True


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="verify only, no download")
    parser.add_argument("--force", action="store_true", help="download again even when the DLL is there")
    args = parser.parse_args(argv)
    if args.check:
        return 0 if check() else 1
    if not args.force and check():
        return 0
    try:
        path = fetch()
    except SystemExit as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    except OSError as e:
        print(f"error: download failed: {e}", file=sys.stderr)
        return 1
    print(f"installed: {path}")
    return 0 if check() else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
