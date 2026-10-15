"""Load measurement of a test run (WI-0059 part B): a thread in the pytest controller samples once per second the
system CPU, the CPU of the own process tree (controller, xdist workers and everything the tests started) and the
number of registered runs. External load = system minus own tree, clamped at 0. All values are percent of the whole
machine (100 = every logical core busy).

Own tree on Windows: the controller puts itself into a job object of its own at the start; every process started
below it is in that job, and the accounting of the job includes processes that have already ended, so a test
process that lives shorter than one sample still counts as own (one system call per sample). Fallback when the job
cannot be created: a psutil walk over the child processes, which does not see a process that starts and ends between
two samples (its CPU then counts as external).
"""

import ctypes
import os
import sys
import threading
import time

import psutil

INTERVAL_S = 1.0


class Sample:
    __slots__ = ("t", "sys", "own", "ext", "runs", "procs")

    def __init__(self, t, sys_cpu, own, runs, procs):
        self.t, self.sys, self.own, self.runs, self.procs = t, sys_cpu, own, runs, procs
        self.ext = max(0.0, sys_cpu - own)


class _JobCpu:
    """CPU seconds of every process ever in a job object that contains this process and its descendants."""

    class _Accounting(ctypes.Structure):
        _fields_ = [("TotalUserTime", ctypes.c_int64), ("TotalKernelTime", ctypes.c_int64),
                    ("ThisPeriodTotalUserTime", ctypes.c_int64), ("ThisPeriodTotalKernelTime", ctypes.c_int64),
                    ("TotalPageFaultCount", ctypes.c_uint32), ("TotalProcesses", ctypes.c_uint32),
                    ("ActiveProcesses", ctypes.c_uint32), ("TotalTerminatedProcesses", ctypes.c_uint32)]

    def __init__(self):
        from ctypes import wintypes
        k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        k32.CreateJobObjectW.restype = wintypes.HANDLE
        k32.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
        k32.GetCurrentProcess.restype = wintypes.HANDLE
        k32.AssignProcessToJobObject.restype = wintypes.BOOL
        k32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
        k32.QueryInformationJobObject.restype = wintypes.BOOL
        k32.QueryInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD,
                                                  ctypes.c_void_p]
        self._k32 = k32
        self._job = k32.CreateJobObjectW(None, None)
        if not self._job:
            raise OSError(ctypes.get_last_error(), "CreateJobObjectW failed")
        if not k32.AssignProcessToJobObject(self._job, k32.GetCurrentProcess()):
            raise OSError(ctypes.get_last_error(), "AssignProcessToJobObject failed")
        self._info = self._Accounting()

    def read(self):
        """(CPU seconds so far, processes active now)."""
        if not self._k32.QueryInformationJobObject(self._job, 1, ctypes.byref(self._info),
                                                   ctypes.sizeof(self._info), None):
            raise OSError(ctypes.get_last_error(), "QueryInformationJobObject failed")
        return (self._info.TotalUserTime + self._info.TotalKernelTime) / 1e7, self._info.ActiveProcesses


class _TreeCpu:
    """Fallback: CPU seconds of the processes below root that are alive at the moment of a call."""

    def __init__(self, root_pid):
        self._root = psutil.Process(root_pid)
        self._prev = {}                 # pid -> (create time, cpu seconds)
        self._total = 0.0
        self._last_t = None

    def read(self):
        now = time.time()
        try:
            procs = [self._root] + self._root.children(recursive=True)
        except psutil.Error:
            procs = [self._root]
        current = {}
        for p in procs:
            try:
                created = p.create_time()
                times = p.cpu_times()
            except psutil.Error:
                continue
            total = times.user + times.system
            current[p.pid] = (created, total)
            prev = self._prev.get(p.pid)
            if prev is not None and abs(prev[0] - created) < 1.0:
                self._total += max(0.0, total - prev[1])
            elif self._last_t is not None and created >= self._last_t - 0.05:
                self._total += total                    # started since the previous call
        self._prev = current
        self._last_t = now
        return self._total, len(current)


def _system_busy():
    """(busy CPU seconds, all CPU seconds) of the machine so far, summed over the cores."""
    t = psutil.cpu_times()
    total = sum(t)
    return total - t.idle, total


class LoadSampler:
    def __init__(self, count_runs=None, interval=INTERVAL_S, use_job=True):
        self.interval = interval
        self.count_runs = count_runs or (lambda: 0)
        self.samples = []
        self.cost_s = 0.0               # wall time spent in sampling (for the overhead budget)
        self.method = None
        self._stop = threading.Event()
        self._thread = None
        self._ncpu = psutil.cpu_count() or 1
        self._own = None
        if use_job and sys.platform == "win32":
            try:
                self._own, self.method = _JobCpu(), "job"
            except OSError:
                self._own = None
        if self._own is None:
            self._own, self.method = _TreeCpu(os.getpid()), "tree"
        self._prev = None               # (time, busy, total, own cpu)

    def start(self):
        self._prev = self._read()
        self._thread = threading.Thread(target=self._run, name="ahf-load-sampler", daemon=True)
        self._thread.start()
        return self

    def stop(self):
        if self._thread is not None:
            self._stop.set()
            self._thread.join(timeout=5)
            self._thread = None
            try:
                self.sample()          # the tail since the last tick
            except Exception:
                pass

    def _run(self):
        while not self._stop.wait(self.interval):
            try:
                self.sample()
            except Exception:          # sampling must never disturb the run
                pass

    def _read(self):
        busy, total = _system_busy()
        own, nprocs = self._own.read()
        return time.time(), busy, total, own, nprocs

    def sample(self):
        t0 = time.perf_counter()
        now, busy, total, own_cpu, nprocs = self._read()
        p_now, p_busy, p_total, p_own, _ = self._prev
        self._prev = (now, busy, total, own_cpu, nprocs)
        d_total = total - p_total
        if d_total <= 0:
            return
        sys_cpu = min(100.0, max(0.0, 100.0 * (busy - p_busy) / d_total))
        # cpu_times are summed over the cores, so d_total is wall time x cores
        own = min(100.0, max(0.0, 100.0 * (own_cpu - p_own) / d_total))
        try:
            runs = int(self.count_runs())
        except Exception:
            runs = 0
        self.samples.append(Sample(now, sys_cpu, own, runs, nprocs))
        self.cost_s += time.perf_counter() - t0


def window_stats(samples, start, stop):
    """Mean and peak of system and external CPU and the maximum of concurrent runs over the samples whose interval
    (previous sample, this sample] overlaps [start, stop]. A window shorter than one interval gets the sample that
    covers it."""
    picked = []
    prev_t = None
    for s in samples:
        lo = prev_t if prev_t is not None else s.t - INTERVAL_S
        if s.t > start and lo < stop:
            picked.append(s)
        prev_t = s.t
    if not picked:
        if not samples:
            return None
        picked = [min(samples, key=lambda s: abs(s.t - stop))]
    return {
        "sysMean": round(sum(s.sys for s in picked) / len(picked), 1),
        "sysPeak": round(max(s.sys for s in picked), 1),
        "extMean": round(sum(s.ext for s in picked) / len(picked), 1),
        "extPeak": round(max(s.ext for s in picked), 1),
        "runsMax": max(s.runs for s in picked),
    }


def run_stats(samples):
    if not samples:
        return None
    stats = window_stats(samples, samples[0].t - INTERVAL_S, samples[-1].t)
    stats["procsPeak"] = max(s.procs for s in samples)
    stats["samples"] = len(samples)
    stats["intervalS"] = INTERVAL_S
    return stats
