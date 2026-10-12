"""Measurement helpers of the stress tests (WI-16): latency distributions, process memory/handles/CPU.

record() prints a `MEASURE` line and, if AHF_MEASURE_OUT names a file, appends one JSON line to it, so a run
can be collected into doc/MEASUREMENTS.md afterwards.
"""

import json
import math
import os
import platform
import threading
import time

import psutil

_record_lock = threading.Lock()


def percentile(sorted_values, p):
    """Nearest-rank percentile (p in 0..100) of an ascending list."""
    if not sorted_values:
        raise ValueError("no values")
    rank = max(1, math.ceil(p / 100.0 * len(sorted_values)))
    return sorted_values[min(rank, len(sorted_values)) - 1]


class Dist:
    """Distribution of a list of values (milliseconds for latencies)."""

    def __init__(self, values):
        self.values = sorted(values)
        self.n = len(self.values)

    @property
    def median(self):
        return percentile(self.values, 50)

    @property
    def p95(self):
        return percentile(self.values, 95)

    @property
    def p99(self):
        return percentile(self.values, 99)

    @property
    def max(self):
        return self.values[-1]

    @property
    def mean(self):
        return sum(self.values) / self.n

    def as_dict(self):
        return {"n": self.n, "median": round(self.median, 3), "p95": round(self.p95, 3),
                "p99": round(self.p99, 3), "max": round(self.max, 3), "mean": round(self.mean, 3)}

    def __str__(self):
        return "n=%d median=%.2f p95=%.2f p99=%.2f max=%.2f" % (self.n, self.median, self.p95, self.p99, self.max)


def machine():
    """Short description of the machine (for the measurement notes)."""
    return "%s, %d logical CPUs, %.1f GB RAM, Python %s" % (
        platform.platform(), psutil.cpu_count(), psutil.virtual_memory().total / 2**30, platform.python_version())


def record(name, **fields):
    """Prints and (optionally) stores one measurement."""
    line = {"name": name, "time": time.strftime("%Y-%m-%d %H:%M:%S"), **fields}
    print("\nMEASURE %s" % json.dumps(line, ensure_ascii=False, sort_keys=True))
    out = os.environ.get("AHF_MEASURE_OUT")
    if out:
        with _record_lock, open(out, "a", encoding="utf-8") as f:
            f.write(json.dumps(line, ensure_ascii=False, sort_keys=True) + "\n")


def proc_snapshot(pid):
    """RSS in MB, handle count and thread count of one process. None if it is gone."""
    try:
        p = psutil.Process(pid)
        return {"rss_mb": round(p.memory_info().rss / 2**20, 2), "handles": p.num_handles(),
                "threads": p.num_threads()}
    except psutil.Error:
        return None


def cpu_seconds(pid):
    try:
        t = psutil.Process(pid).cpu_times()
        return t.user + t.system
    except psutil.Error:
        return None


def cpu_percent_over(pids, seconds):
    """CPU use of each pid over `seconds`, in percent of ONE core (cpu_times delta / wall time).

    Exact for the whole interval, unlike psutil.cpu_percent which only compares two calls."""
    before = {pid: cpu_seconds(pid) for pid in pids}
    t0 = time.perf_counter()
    time.sleep(seconds)
    wall = time.perf_counter() - t0
    result = {}
    for pid in pids:
        after = cpu_seconds(pid)
        if before[pid] is not None and after is not None:
            result[pid] = 100.0 * (after - before[pid]) / wall
    return result
