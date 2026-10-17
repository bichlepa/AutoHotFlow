"""Driver of tests/ahk/helpers/tray_menu_probe.ahk (WI-0072, E0064): opens the tray menu of a running AHK script,
navigates it, posts wake messages like a peer, and writes the timeline of both sides.

    python tools/tray_menu_probe.py --mode idle|thread|load [--run-ms 15000] [--menu-at 3000] [--hold-ms 6000]
                                    [--navigate] [--pings-per-s 20] [--out <dir>]

The probe script records its own events (ticks, answered pings, thread progress); this driver records when it sent
each ping, when the menu window (class #32768) appeared and disappeared, and every key it sent. Both use the wall
clock in ms. The analysis is printed as a summary; the raw files go to --out (default: the scratchpad of the run,
a temp directory). Not part of the test suite: it is a measurement, run by hand or by the agent that writes
doc/MEASUREMENTS.md. It never runs in parallel with another measurement.
"""

import argparse
import ctypes
import json
import subprocess
import sys
import tempfile
import time
from ctypes import wintypes
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tests" / "ahk" / "helpers" / "tray_menu_probe.ahk"
AHKRUN = ROOT / "tools" / "ahkrun.py"

user32 = ctypes.WinDLL("user32", use_last_error=True)
WM_AHF_WAKE = 0x8001
WM_RBUTTONUP = 0x0205
WM_CONTEXTMENU = 0x007B
VK_DOWN = 0x28
VK_ESCAPE = 0x1B
KEYEVENTF_KEYUP = 0x2
MENU_CLASS = "#32768"

EnumProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
user32.EnumWindows.argtypes = [EnumProc, wintypes.LPARAM]
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowW.restype = wintypes.HWND
user32.FindWindowExW.argtypes = [wintypes.HWND, wintypes.HWND, wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowExW.restype = wintypes.HWND


def wall_ms():
    return int(time.time() * 1000)


def find_probe_window(timeout_s):
    """The AHK window of the probe script (title contains the script name), or 0."""
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        found = []

        def cb(hwnd, _lparam):
            cls = ctypes.create_unicode_buffer(64)
            title = ctypes.create_unicode_buffer(512)
            user32.GetClassNameW(hwnd, cls, 64)
            user32.GetWindowTextW(hwnd, title, 512)
            if cls.value == "AutoHotkey" and "tray_menu_probe.ahk" in title.value:
                found.append(hwnd)
            return True

        user32.EnumWindows(EnumProc(cb), 0)
        if found:
            return found[0]
        time.sleep(0.1)
    return 0


def find_list_view(timeout_s):
    """The ListView inside the probe's Gui window (title probe-gui), or 0."""
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        top = user32.FindWindowW("AutoHotkeyGUI", "probe-gui")
        if top:
            lv = user32.FindWindowExW(top, 0, "SysListView32", None)
            if lv:
                return lv
        time.sleep(0.1)
    return 0


def key(vk):
    user32.keybd_event(vk, 0, 0, 0)
    time.sleep(0.03)
    user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)


def menu_open():
    return bool(user32.FindWindowW(MENU_CLASS, None))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="idle", choices=["idle", "thread", "load"])
    ap.add_argument("--run-ms", type=int, default=15000)
    ap.add_argument("--menu-at", type=int, default=3000, help="ms after start when the menu is opened")
    ap.add_argument("--hold-ms", type=int, default=6000, help="how long the menu stays open before Esc")
    ap.add_argument("--navigate", action="store_true", help="press Down three times while the menu is open")
    ap.add_argument("--pings-per-s", type=float, default=20.0)
    ap.add_argument("--out", default="")
    ap.add_argument("--notify-msg", default="0x404", help="tray callback message of the script (AHK_NOTIFYICON)")
    ap.add_argument("--opener", default="tray", choices=["tray", "gui"],
                    help="tray: right click on the tray icon; gui: WM_CONTEXTMENU to a ListView of a Gui")
    args = ap.parse_args()

    out = Path(args.out) if args.out else Path(tempfile.mkdtemp(prefix="ahf_tray_probe_"))
    out.mkdir(parents=True, exist_ok=True)
    result_file = out / f"probe_{args.mode}.txt"
    proc = subprocess.Popen([sys.executable, str(AHKRUN), "--timeout", str(args.run_ms / 1000 + 30), str(PROBE),
                             args.mode, str(args.run_ms), str(result_file), args.opener])
    hwnd = find_probe_window(10)
    if not hwnd:
        proc.kill()
        sys.exit("probe window not found")
    target = hwnd
    if args.opener == "gui":
        target = find_list_view(10)
        if not target:
            proc.kill()
            sys.exit("ListView of the probe Gui not found")

    events = []
    menu_seen = None
    menu_gone = None
    sent = 0
    start = time.monotonic()
    opened = False
    navigated = False
    escaped = False
    interval = 1.0 / args.pings_per_s if args.pings_per_s > 0 else 0.05
    next_ping = start
    while time.monotonic() - start < args.run_ms / 1000:
        now_s = (time.monotonic() - start) * 1000
        if time.monotonic() >= next_ping:
            user32.PostMessageW(hwnd, WM_AHF_WAKE, wall_ms(), 0)
            sent += 1
            next_ping += interval
        if not opened and now_s >= args.menu_at:
            opened = True
            events.append(["menu-open", wall_ms()])
            if args.opener == "gui":
                user32.PostMessageW(target, WM_CONTEXTMENU, target, -1)
            else:
                user32.PostMessageW(hwnd, int(args.notify_msg, 16), 1, WM_RBUTTONUP)
        if opened and menu_seen is None and menu_open():
            menu_seen = wall_ms()
            events.append(["menu-seen", menu_seen])
        if menu_seen is not None and not navigated and args.navigate and now_s >= args.menu_at + 1000:
            navigated = True
            for _ in range(3):
                key(VK_DOWN)
                events.append(["key-down", wall_ms()])
                time.sleep(0.4)
        if menu_seen is not None and not escaped and now_s >= args.menu_at + args.hold_ms:
            escaped = True
            key(VK_ESCAPE)
            events.append(["key-esc", wall_ms()])
        if escaped and menu_gone is None and not menu_open():
            menu_gone = wall_ms()
            events.append(["menu-gone", menu_gone])
        time.sleep(0.005)
    events.append(["driver-end", wall_ms()])
    events.append(["pings-sent", sent])
    if escaped and menu_gone is None:
        # Esc did not close it (or the process did not react): recorded, not forced.
        events.append(["menu-still-open-at-end", wall_ms()])
    try:
        proc.wait(timeout=args.run_ms / 1000 + 30)
    except subprocess.TimeoutExpired:
        events.append(["probe-timeout", wall_ms()])
        proc.kill()
    (out / f"driver_{args.mode}.json").write_text(json.dumps({"events": events, "args": vars(args)}, indent=1),
                                                   encoding="utf-8")
    print(f"probe result: {result_file}")
    print(f"driver events: {out / ('driver_' + args.mode + '.json')}")
    print(f"probe exit code: {proc.returncode}")
    summarize(result_file, events)


def summarize(result_file, events):
    """Prints the measures of one run: pings and ticks inside and outside the menu window, thread progress."""
    ev = {}
    for kind, value in events:
        ev.setdefault(kind, value)
    seen = ev.get("menu-seen")
    gone = ev.get("menu-gone", ev.get("driver-end"))
    if not result_file.exists():
        print("no probe result file (the probe did not finish)")
        return
    rows = []
    for line in result_file.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) >= 2:
            rows.append((parts[0], int(parts[1]), parts[2] if len(parts) > 2 else ""))

    def inside(t):
        return seen is not None and seen <= t <= gone

    pongs = [r for r in rows if r[0] == "pong"]
    ticks = [r[1] for r in rows if r[0] == "tick"]
    prog = [r[1] for r in rows if r[0] == "prog"]
    lat_in = [int(r[2]) for r in pongs if inside(r[1])]
    lat_out = [int(r[2]) for r in pongs if not inside(r[1])]
    gaps = [b - a for a, b in zip(ticks, ticks[1:]) if inside(a) or inside(b)]
    print(f"menu window: {(gone - seen) if seen else 'no menu seen'} ms")
    print(f"pings sent {ev.get('pings-sent', '?')}, answered {len(pongs)}; in the window {len(lat_in)} "
          f"(max latency {max(lat_in, default='-')} ms), outside {len(lat_out)} "
          f"(max latency {max(lat_out, default='-')} ms)")
    print(f"timer ticks in the window: {sum(1 for t in ticks if inside(t))}, longest tick gap at the window: "
          f"{max(gaps, default='-')} ms")
    print(f"thread progress records: {len(prog)} in total, {sum(1 for t in prog if inside(t))} in the window")


if __name__ == "__main__":
    main()
