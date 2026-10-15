"""Lists the running AutoHotFlow processes and lets the project owner bring them to front or end them.

Usage:
    python tools/ahf_processes.py

What it lists: AutoHotkey processes (image name starts with "AutoHotkey", or "AutoHotFlow.exe" of v1) whose
command line contains one of the AHF markers: "AutoHotFlow" (the repo folder, also "AutoHotFlow-wt" workspaces)
or "ahf_runs" (the test run folders of tools/run_suite.py). Other AutoHotkey scripts of the owner are not
listed and so cannot be ended by mistake. The tool's own process is never listed.

Per process: PID, role/arguments (short; the full command line is in the details line below the table),
start time, running time, and whether a visible window exists (with its title).

Buttons:
  * Bring to front: shows one visible window of the selected process (restores it when minimised). If Windows
    refuses the foreground change, it retries with AttachThreadInput; if that fails too, a message says so.
  * End process: asks for confirmation, then ends the process. By default together with its child processes
    (the roles are children of the supervisor); the checkbox "with child processes" switches that off.
  * Refresh, and a checkbox "Auto refresh (every 3 s)".

The logic without a window (find, filter, format, kill) is in plain functions, tested by
tests/test_ahf_processes.py. The GUI and the window code (ctypes, Windows only) are for manual use.
"""

import ctypes
import os
import sys
import time
from ctypes import wintypes

import psutil

MARKERS = ("autohotflow", "ahf_runs")   # lower case; "autohotflow" also matches "AutoHotFlow-wt"
AUTO_REFRESH_MS = 3000


# ---------------------------------------------------------------- logic without a window

def is_ahf_process(name, cmdline):
    """True for an AutoHotkey process whose command line points into an AutoHotFlow folder."""
    low = (name or "").lower()
    if not (low.startswith("autohotkey") or low == "autohotflow.exe"):
        return False
    text = " ".join(cmdline or []).lower()
    return any(m in text for m in MARKERS)


def find_ahf_processes(own_pid=None):
    """Returns a list of dicts: pid, name, cmdline (str), args (short str), created (epoch seconds)."""
    own_pid = os.getpid() if own_pid is None else own_pid
    result = []
    for proc in psutil.process_iter(["pid", "name", "cmdline", "create_time"]):
        info = proc.info
        if info["pid"] == own_pid or not is_ahf_process(info["name"], info["cmdline"]):
            continue
        cmd = info["cmdline"] or []
        result.append({
            "pid": info["pid"],
            "name": info["name"],
            "cmdline": " ".join(cmd),
            "args": short_args(cmd),
            "created": info["create_time"],
        })
    result.sort(key=lambda p: p["created"])
    return result


def short_args(cmdline):
    """The script name and the arguments, without the interpreter path and the /ErrorStdOut switches."""
    parts = [c for c in (cmdline or [])[1:] if not c.lower().startswith("/errorstdout")]
    if parts:
        parts[0] = os.path.basename(parts[0])   # a script path becomes its file name
    return " ".join(parts)


def format_duration(seconds):
    """Readable running time: '12 s', '3 min 05 s', '2 h 07 min', '3 d 4 h'."""
    s = max(0, int(seconds))
    if s < 60:
        return "%d s" % s
    if s < 3600:
        return "%d min %02d s" % (s // 60, s % 60)
    if s < 86400:
        return "%d h %02d min" % (s // 3600, (s % 3600) // 60)
    return "%d d %d h" % (s // 86400, (s % 86400) // 3600)


def format_start(created):
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(created))


def kill_process(pid, with_children=True, own_pid=None):
    """Ends a process (and its children, deepest first). Returns (ended_pids, problems).

    problems is a list of text lines (vanished or denied processes); nothing is raised for them.
    The own PID is refused: ValueError.
    """
    own_pid = os.getpid() if own_pid is None else own_pid
    if pid == own_pid:
        raise ValueError("refusing to end the own process (PID %d)" % pid)
    try:
        root = psutil.Process(pid)
        targets = root.children(recursive=True) if with_children else []
    except psutil.NoSuchProcess:
        return [], ["PID %d does not exist any more" % pid]
    except psutil.AccessDenied:
        return [], ["PID %d: access denied" % pid]
    targets = [p for p in targets if p.pid != own_pid]
    targets.reverse()
    targets.append(root)
    ended, problems = [], []
    for p in targets:
        try:
            p.kill()
            ended.append(p.pid)
        except psutil.NoSuchProcess:
            problems.append("PID %d was already gone" % p.pid)
        except psutil.AccessDenied:
            problems.append("PID %d: access denied" % p.pid)
    return ended, problems


# ---------------------------------------------------------------- windows (ctypes, Windows only)

def _user32():
    u = ctypes.windll.user32
    u.EnumWindows.argtypes = [ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM), wintypes.LPARAM]
    u.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    u.GetWindowThreadProcessId.restype = wintypes.DWORD
    u.IsWindowVisible.argtypes = [wintypes.HWND]
    u.IsIconic.argtypes = [wintypes.HWND]
    u.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    u.GetWindowTextLengthW.argtypes = [wintypes.HWND]
    u.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
    u.SetForegroundWindow.argtypes = [wintypes.HWND]
    u.BringWindowToTop.argtypes = [wintypes.HWND]
    u.GetForegroundWindow.restype = wintypes.HWND
    u.AttachThreadInput.argtypes = [wintypes.DWORD, wintypes.DWORD, wintypes.BOOL]
    return u


def find_windows():
    """Returns {pid: [(hwnd, title), ...]} of all visible top-level windows with a title."""
    u = _user32()
    found = {}

    def callback(hwnd, _lparam):
        if u.IsWindowVisible(hwnd):
            length = u.GetWindowTextLengthW(hwnd)
            if length > 0:
                buf = ctypes.create_unicode_buffer(length + 1)
                u.GetWindowTextW(hwnd, buf, length + 1)
                pid = wintypes.DWORD(0)
                u.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                found.setdefault(pid.value, []).append((hwnd, buf.value))
        return True

    u.EnumWindows(ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)(callback), 0)
    return found


def bring_to_front(hwnd):
    """Returns (ok, message). Restores a minimised window; retries with AttachThreadInput if refused."""
    u = _user32()
    SW_RESTORE = 9
    if u.IsIconic(hwnd):
        u.ShowWindow(hwnd, SW_RESTORE)
    if u.SetForegroundWindow(hwnd):
        return True, ""
    fg = u.GetForegroundWindow()
    fg_thread = u.GetWindowThreadProcessId(fg, None) if fg else 0
    my_thread = ctypes.windll.kernel32.GetCurrentThreadId()
    attached = bool(fg_thread) and fg_thread != my_thread and u.AttachThreadInput(my_thread, fg_thread, True)
    try:
        u.BringWindowToTop(hwnd)
        ok = bool(u.SetForegroundWindow(hwnd))
    finally:
        if attached:
            u.AttachThreadInput(my_thread, fg_thread, False)
    if ok:
        return True, ""
    return False, "Windows refused to bring the window to the foreground."


# ---------------------------------------------------------------- GUI

def run_gui():
    import tkinter as tk
    from tkinter import messagebox, ttk

    root = tk.Tk()
    root.title("AutoHotFlow processes")
    root.geometry("1100x420")

    columns = ("pid", "args", "since", "for", "window")
    tree = ttk.Treeview(root, columns=columns, show="headings", selectmode="browse")
    for col, text, width in (("pid", "PID", 70), ("args", "Role / arguments", 330),
                             ("since", "Running since", 140), ("for", "Running for", 100),
                             ("window", "Window", 420)):
        tree.heading(col, text=text)
        tree.column(col, width=width, anchor="w", stretch=(col in ("args", "window")))

    state = {"procs": {}, "windows": {}}   # pid -> process dict; pid -> list of (hwnd, title)

    def refresh():
        selected = tree.selection()
        sel_pid = selected[0] if selected else None
        procs = find_ahf_processes()
        try:
            state["windows"] = find_windows()
        except Exception as exc:   # ctypes problems must not kill the tool
            state["windows"] = {}
            status.set("Window search failed: %s" % exc)
        state["procs"] = {str(p["pid"]): p for p in procs}
        tree.delete(*tree.get_children())
        now = time.time()
        for p in procs:
            wins = state["windows"].get(p["pid"], [])
            win_text = ("yes: " + wins[0][1] + (" (+%d)" % (len(wins) - 1) if len(wins) > 1 else "")) if wins else "no"
            tree.insert("", "end", iid=str(p["pid"]),
                        values=(p["pid"], p["args"], format_start(p["created"]),
                                format_duration(now - p["created"]), win_text))
        if sel_pid and tree.exists(sel_pid):
            tree.selection_set(sel_pid)
        show_details()
        if not status.get().startswith("Window search failed"):
            status.set("%d process(es), refreshed %s" % (len(procs), time.strftime("%H:%M:%S")))

    def selected_proc():
        sel = tree.selection()
        return state["procs"].get(sel[0]) if sel else None

    def show_details(_event=None):
        p = selected_proc()
        details.set(p["cmdline"] if p else "")

    def on_front():
        p = selected_proc()
        if not p:
            return
        wins = state["windows"].get(p["pid"], [])
        if not wins:
            messagebox.showinfo("Bring to front", "PID %d has no visible window." % p["pid"])
            return
        ok, msg = bring_to_front(wins[0][0])
        if not ok:
            messagebox.showwarning("Bring to front", msg)

    def on_kill():
        p = selected_proc()
        if not p:
            return
        with_children = kids.get()
        text = "End PID %d?\n\n%s" % (p["pid"], p["args"])
        if with_children:
            text += "\n\nIts child processes are ended too."
        if not messagebox.askyesno("End process", text, icon="warning"):
            return
        try:
            ended, problems = kill_process(p["pid"], with_children)
        except ValueError as exc:
            messagebox.showerror("End process", str(exc))
            return
        if problems:
            messagebox.showwarning("End process", "\n".join(problems))
        refresh()

    def auto():
        if autovar.get():
            refresh()
            root.after(AUTO_REFRESH_MS, auto)

    def on_auto():
        if autovar.get():
            root.after(AUTO_REFRESH_MS, auto)

    bar = ttk.Frame(root)
    bar.pack(side="top", fill="x", padx=6, pady=6)
    autovar, kids, status, details = tk.BooleanVar(), tk.BooleanVar(value=True), tk.StringVar(), tk.StringVar()
    ttk.Button(bar, text="Refresh", command=refresh).pack(side="left")
    ttk.Checkbutton(bar, text="Auto refresh (every 3 s)", variable=autovar, command=on_auto).pack(side="left", padx=10)
    ttk.Button(bar, text="Bring to front", command=on_front).pack(side="left", padx=(20, 0))
    ttk.Button(bar, text="End process", command=on_kill).pack(side="left", padx=6)
    ttk.Checkbutton(bar, text="with child processes", variable=kids).pack(side="left")

    ttk.Label(root, textvariable=status).pack(side="bottom", fill="x", padx=6)
    ttk.Label(root, textvariable=details, wraplength=1060, foreground="#555").pack(side="bottom", fill="x", padx=6, pady=4)
    tree.pack(side="top", fill="both", expand=True, padx=6)
    tree.bind("<<TreeviewSelect>>", show_details)

    refresh()
    root.mainloop()


if __name__ == "__main__":
    if sys.platform != "win32":
        sys.exit("ahf_processes.py works on Windows only")
    run_gui()
