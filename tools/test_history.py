"""Reads the run history of the test suite (WI-0059): one JSON file per pytest run, written by tests/conftest.py into
temp/history/ of the main checkout (AHF_HISTORY_DIR overrides it). Read-only.

Usage:
    python tools/test_history.py [--last N]            # table of the last runs (default 10)
    python tools/test_history.py --flaky [--since DATE] # red and green at the same commit (clean runs only)
    python tools/test_history.py --test <node id>      # history of one test (substring match if no exact id)
    python tools/test_history.py --load                # red rate and test duration over buckets of external CPU
    python tools/test_history.py --durations           # tests whose duration grows over commits

Options for every mode: --dir <folder> (instead of the default folder), --since YYYY-MM-DD.
Load figures are percent of the whole machine (100 = every logical core busy); "ext" is the load that did not come
from the run's own processes. Nothing here decides anything: the figures are for the reader.
"""

import argparse
import statistics
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tests"))

from support import history  # noqa: E402

RED = history.RED
BUCKETS = (0, 10, 25, 50, 75, 100.01)


def _since_epoch(text):
    return time.mktime(time.strptime(text, "%Y-%m-%d")) if text else None


def load(folder, since=None):
    records = history.load_records(folder)
    if since is not None:
        records = [r for r in records if (r["run"].get("startEpoch") or 0) >= since]
    return records


def _short(sha):
    return (sha or "-")[:8]


def _commit(record):
    code = record.get("code") or {}
    mark = "*" if code.get("dirty") else (" " if code.get("dirty") is False else "?")
    return _short(code.get("sha")) + mark


def _counts(record):
    counts = record.get("counts") or {}
    order = ("passed", "failed", "error", "skipped", "xfailed", "xpassed", "incomplete")
    parts = ["%d %s" % (counts[k], k) for k in order if counts.get(k)]
    parts += ["%d %s" % (v, k) for k, v in sorted(counts.items()) if k not in order]
    return ", ".join(parts) or "no tests"


def _fmt(value, spec="%.0f"):
    return "-" if value is None else spec % value


def _is_clean(record):
    return record.get("complete") is True and (record.get("code") or {}).get("dirty") is False


def show_last(records, n, out):
    if not records:
        out.write("no runs in the history\n")
        return 0
    out.write("%-16s %-9s %-36s %8s %5s  %s\n" % ("start", "commit", "counts", "duration", "ext", "log"))
    for r in records[-n:]:
        run, logs, load_ = r["run"], r.get("logs") or {}, r.get("load") or {}
        flags = []
        if not r.get("complete"):
            flags.append("incomplete")
        if run.get("recheckOf"):
            flags.append("recheck of " + run["recheckOf"])
        if run.get("startedBy") not in (None, "direct"):
            flags.append(run["startedBy"])
        out.write("%-16s %-9s %-36s %7.1fs %4s%%  %s%s\n" % (
            (run.get("start") or "")[:16].replace("T", " "), _commit(r), _counts(r)[:36], run.get("durationS") or 0,
            _fmt(load_.get("extMean")), logs.get("output") or logs.get("runLog") or "-",
            "  (%s)" % ", ".join(flags) if flags else ""))
    out.write("(* = uncommitted changes; ext = mean external CPU over the run)\n")
    return 0


def flaky(records):
    """{(sha, test id): {"red": [(record, item)], "green": [...]}} for tests with both outcomes at one commit."""
    seen = {}
    for r in records:
        if not _is_clean(r):
            continue
        sha = r["code"].get("sha")
        for item in r.get("tests") or []:
            if item["outcome"] in RED:
                kind = "red"
            elif item["outcome"] == "passed":
                kind = "green"
            else:
                continue
            seen.setdefault((sha, item["id"]), {"red": [], "green": []})[kind].append((r, item))
    return {k: v for k, v in seen.items() if v["red"] and v["green"]}


def _load_list(entries):
    return ", ".join("%s/%s" % (_fmt(i.get("extMean")), _fmt(i.get("sysMean"))) for _, i in entries)


def show_flaky(records, out):
    found = flaky(records)
    if not found:
        out.write("no test was red and green at the same commit (clean, complete runs only)\n")
        return 0
    out.write("red and green at the same commit; load per run as ext/sys mean %:\n")
    for (sha, test), v in sorted(found.items(), key=lambda kv: (-len(kv[1]["red"]), kv[0][1])):
        out.write("%s  at %s\n    red   %d x  %s\n    green %d x  %s\n" % (
            test, _short(sha), len(v["red"]), _load_list(v["red"]), len(v["green"]), _load_list(v["green"])))
    return 0


def show_test(records, test_id, out):
    rows = [(r, i) for r in records for i in r.get("tests") or [] if i["id"] == test_id]
    if not rows:
        rows = [(r, i) for r in records for i in r.get("tests") or [] if test_id in i["id"]]
    if not rows:
        out.write("no result for %s\n" % test_id)
        return 1
    out.write("%-16s %-9s %-10s %8s %9s %9s %4s  %s\n" % ("start", "commit", "outcome", "duration", "sys m/p",
                                                         "ext m/p", "runs", "test"))
    for r, i in rows:
        out.write("%-16s %-9s %-10s %7.2fs %4s/%-4s %4s/%-4s %4s  %s\n" % (
            (r["run"].get("start") or "")[:16].replace("T", " "), _commit(r), i["outcome"], i.get("duration") or 0,
            _fmt(i.get("sysMean")), _fmt(i.get("sysPeak")), _fmt(i.get("extMean")), _fmt(i.get("extPeak")),
            _fmt(i.get("runsMax"), "%d"), i["id"]))
        if i.get("failure"):
            out.write("%s%s\n" % (" " * 27, i["failure"]))
    return 0


def load_buckets(records):
    """Per bucket of external CPU (mean of the test's window): results, red results, and the median of the duration
    relative to the median duration of the same test over the whole history."""
    by_test = {}
    for r in records:
        for i in r.get("tests") or []:
            if i.get("extMean") is not None and i["outcome"] in RED + ("passed",):
                by_test.setdefault(i["id"], []).append(i)
    medians = {t: statistics.median(x.get("duration") or 0 for x in items) for t, items in by_test.items()}
    rows = []
    for lo, hi in zip(BUCKETS, BUCKETS[1:]):
        items = [(t, i) for t, its in by_test.items() for i in its if lo <= i["extMean"] < hi]
        red = sum(1 for _, i in items if i["outcome"] in RED)
        rel = [i["duration"] / medians[t] for t, i in items if medians[t] >= 0.05 and i.get("duration")]
        rows.append({"bucket": "%d-%d %%" % (lo, min(hi, 100)), "results": len(items), "red": red,
                     "redRate": (100.0 * red / len(items)) if items else None,
                     "relDuration": statistics.median(rel) if rel else None})
    return rows


def show_load(records, out):
    out.write("%-10s %8s %5s %8s %13s\n" % ("ext CPU", "results", "red", "red rate", "rel. duration"))
    for row in load_buckets(records):
        out.write("%-10s %8d %5d %7s%% %13s\n" % (row["bucket"], row["results"], row["red"],
                                                 _fmt(row["redRate"], "%.1f"), _fmt(row["relDuration"], "%.2f")))
    out.write("(rel. duration: duration / median duration of the same test, median per bucket; tests under 50 ms are "
              "left out of it)\n")
    return 0


def duration_growth(records, min_ratio=1.5, min_increase=0.5):
    """Tests whose median duration of the passed results at the last commit is min_ratio times that at the first
    commit (commits in the order of their first run) and at least min_increase seconds longer."""
    per_test = {}
    for r in records:
        if not r.get("complete"):
            continue
        sha = (r.get("code") or {}).get("sha")
        for i in r.get("tests") or []:
            if i["outcome"] == "passed" and i.get("duration") is not None:
                commits = per_test.setdefault(i["id"], {})
                commits.setdefault(sha, []).append(i["duration"])
    found = []
    for test, commits in per_test.items():
        if len(commits) < 2:
            continue
        shas = list(commits)                       # dict order = order of the first run of each commit
        first, last = statistics.median(commits[shas[0]]), statistics.median(commits[shas[-1]])
        if last - first >= min_increase and last >= min_ratio * max(first, 1e-3):
            found.append((test, shas[0], first, shas[-1], last, len(shas)))
    return sorted(found, key=lambda f: -(f[4] / max(f[2], 1e-3)))


def show_durations(records, out, min_ratio, min_increase):
    found = duration_growth(records, min_ratio, min_increase)
    if not found:
        out.write("no test got %.1f times slower (and %.1f s longer) between its first and its last commit\n"
                  % (min_ratio, min_increase))
        return 0
    for test, sha0, d0, sha1, d1, n in found:
        out.write("%6.2fs at %s -> %6.2fs at %s  (x%.1f, %d commits)  %s\n" % (d0, _short(sha0), d1, _short(sha1),
                                                                            d1 / max(d0, 1e-3), n, test))
    out.write("(median of the passed results per commit; the load of the machine is not taken out)\n")
    return 0


def main(argv=None, out=None):
    out = out or sys.stdout
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--last", type=int, metavar="N", help="table of the last N runs (default mode, N = 10)")
    mode.add_argument("--flaky", action="store_true", help="tests red and green at the same commit")
    mode.add_argument("--test", metavar="NODEID", help="history of one test")
    mode.add_argument("--load", action="store_true", help="red rate and duration over buckets of external CPU")
    mode.add_argument("--durations", action="store_true", help="tests whose duration grows over commits")
    parser.add_argument("--since", metavar="YYYY-MM-DD", help="only runs started on or after this day")
    parser.add_argument("--dir", help="history folder (default: temp/history of the main checkout)")
    parser.add_argument("--min-ratio", type=float, default=1.5, help="--durations: growth factor (default 1.5)")
    parser.add_argument("--min-increase", type=float, default=0.5, help="--durations: seconds (default 0.5)")
    args = parser.parse_args(argv)
    folder = Path(args.dir) if args.dir else history.history_dir_to_read(REPO)
    try:
        since = _since_epoch(args.since)
    except ValueError:
        parser.error("--since needs YYYY-MM-DD")
    records = load(folder, since)
    out.write("history: %s (%d runs)\n" % (folder, len(records)))
    if args.flaky:
        return show_flaky(records, out)
    if args.test:
        return show_test(records, args.test, out)
    if args.load:
        return show_load(records, out)
    if args.durations:
        return show_durations(records, out, args.min_ratio, args.min_increase)
    return show_last(records, args.last or 10, out)


if __name__ == "__main__":
    sys.exit(main())
