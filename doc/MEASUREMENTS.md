# Measurements

This document lists the measured values that design decisions rest on. For each measurement it gives what was measured, how, when, the result, the decision or document it supports, and its status.

Status words:

- **verified**: measured or read, and the number is in the source.
- **assumed**: presumed in the source, not measured.
- **not checked**: not measured.

## Important: one machine, not an idle machine

All numbers were measured on **one machine**, the owner's normal work computer. The machine was **not idle**: VS Code, the v1 AutoHotFlow and other AutoHotkey scripts kept running. No load was removed for the measurements. The values are therefore typical values for a normally used work machine, not benchmark values. They change with the load. Example: an earlier development run measured idle CPU at 0.31 % of the system; the final run measured 0.23 % (M-04).

The spikes (M-10, M-11) ran on a development machine with AutoHotkey 2.0.x. The source gives no further hardware data for them.

Measurement machine (stated in the sources):

- Windows 11 Pro (10.0.26300), 8 logical CPUs, 23.9 GB RAM (stated in WI-25 only)
- Python 3.13 with `psutil`
- AutoHotkey v2, `AutoHotkey64.exe` (64-bit only, see ARCHITECTURE decision E4)

## Overview

Targets are the performance budgets in `doc/ARCHITECTURE.md`, section 9.

| ID | What was measured | Date | Result | Supports | Status |
|---|---|---|---|---|---|
| M-01 | Command latency `cmd.engine.snapshot`, idle | 2026-10-11 | 10 runs of 2000 requests. Median 1.44 ms (max over runs 1.47); p99 1.91 ms (max 4.91); largest single value 28.5 ms | Target: median < 5 ms, p99 < 50 ms | verified; target met |
| M-02 | Command latency `cmd.engine.snapshot` under load (a new instance every 5 ms) | 2026-10-11 | 10 runs of 3000 requests. Median 1.51 ms (max 1.52); p95 9.9 ms; p99 12.6 ms (max 13.0); largest single value 36.6 ms | Target: median < 5 ms, p99 < 50 ms | verified; target met |
| M-03 | Latency of a Python client that does not wake the hub | 2026-10-11 | 10 runs of 100 requests. Median 226 ms, p99 264 ms, max 274 ms. The client is served only by the hub's 250 ms fallback timer | PROTOCOL section 1 (wake-up calls); HOW-TO | verified; a client without a window cannot meet the 5 ms target |
| M-04 | Idle CPU of the chain (supervisor, storage, engine, manager stub, `--headless`), 30 s per run | 2026-10-11 | 5 runs. 0.23 % of the whole system (8 CPUs; max 0.25 %), i.e. 1.82 % of one core (median of the sum of the four roles; max 2.03 %) | Target: idle CPU < 1 %, applies to the whole system (decision E5, 2026-10-11) | verified; target met under E5 |
| M-05 | Memory of the chain without an editor | 2026-10-11 | Sum of RSS 68.3 MB (max 68.5 MB) over the idle runs | Memory target (see M-06) | verified, for the chain without editor only |
| M-06 | Memory with 5 open editors | not stated | **Not measured**: there is no editor role yet | Target: < 100 MB | not checked |
| M-07 | Engine state change until editor redraw | not stated | **Not measured**: no editor, no redraw | Target: < 50 ms | not checked |
| M-08 | Start until `ready` (supervisor start until all roles ready and flows loaded), 100 starts (10 runs of 10) | 2026-10-11 | Median 0.30 s (max 0.34 s). All roles ready after 0.21 s (max 0.24 s) | Target: < 3 s | verified; target met. The flow used is not named in the source; see M-09 |
| M-09 | Start of the chain with one flow (`test_start_to_ready_time`), after WI-24 | 2026-10-11 | 10 runs. Median 0.56 s (max 1.19 s). Before WI-24: median 0.30 s | Target: < 3 s | verified; cause of the increase not investigated |
| M-10 | Process cost of an AutoHotkey v2 process (spike, 8 instances) | 2026-10-10 | Start about 30 ms, about 14 MB RSS, 0 % CPU idle | Process model: processes instead of threads (AGENTS.md, decisions) | verified (spike, approximate values) |
| M-11 | Named-pipe round trip (spike) | 2026-10-10 | Polling only (250 ms timer): median about 256 ms. With `PostMessage` wake-up after each write: median about 0.3 ms, max about 0.5 ms | IPC design: named pipes with `PostMessage` wake-up (AGENTS.md, decisions) | verified (spike) |
| M-12 | 200 parallel instances (policy `parallel`); 50 instances as a smaller case | 2026-10-11 | 200 instances: all starts answered, median 0.87 s (max 0.93 s). All instances finished, median 6.84 s (max 6.90 s; the flow sleeps 6 s). Error rate 0, peak 200 at the same time, `countRuns` 0, `seq` gapless. After fixes F-09 and F-10: 60 of 60 runs without failure | Design rule 2 (no shared mutable state); race class of the old version | verified |
| M-13 | Start/stop storm: 1000 cycles (1334 instances) | 2026-10-11 | 10.5 s per run (max 10.9 s). Start answer median 2.7 ms, p99 17.5 ms. Stop answer median 2.5 ms, p99 15.8 ms. Each instance has exactly one `started` and one `ended`; `seq` gapless over 8830 events; engine handles 159 → 159; RSS 17.1 → 17.1 MB | Design rule 2 | verified |
| M-14 | 20 clients connecting and disconnecting, 8 rounds (160 changes), while a flow runs | 2026-10-11 | 10 runs. Errors 0; pids unchanged; handles supervisor 186 → 186, engine 159 → 159. Snapshot latency during the changes: median 2.05 ms, p99 9.5 ms (max over runs 15.3 ms). Connect: median 5.1 ms, p99 103 ms (max 145 ms) | Connection handling; latency budget | verified |
| M-15 | Supervisor memory after 400 connections (F-07) | 2026-10-11 | Before the fix: RSS 25.2 → 57.8 MB, about 83 KB per connection (red test). After the fix (commit `4f566bb`): 17.46 → 17.46 MB. Probe: 17.47 → 17.49 MB after 800 connections. Peer reconnect probe, before: 16.57 → 47.91 MB (about 104 KB per reconnect); after: 14.66 → 14.63 MB | Fix in `src/core/ipc/PipeConnection.ahk` (commit `4f566bb`) | verified (the reconnect probe script is not in the repository) |
| M-16 | Soak run, 600 s, about 20 events/s, no connection changes | 2026-10-11 | 1 run. Errors 0; pids unchanged; processes 5 → 5; handles flat (supervisor 195, roles 159). RSS: supervisor 17.88 → 17.86 MB, engine 17.07 → 17.10, manager 17.06 → 17.09, storage 17.14 → 17.21 MB. Snapshot latency in the last part: median 2.5 ms, p99 11.2 ms (max 59.6 ms) | Long-run stability | verified (one run) |
| M-17 | Event flood: 20 s at about 290 events/s (725 instances) | 2026-10-11 | Engine snapshot latency during the flood: median 1.6 ms, p95 29 ms, p99 40 ms, max 59 ms (budget held). Storage fell behind: RSS 17.1 → 56.1 MB at the end of the flood; the log kept being written 207 s after it; RSS afterwards 17.4 MB | Latency budget; storage backlog F-08 (fixed by WI-25, see M-22 to M-24) | verified |
| M-18 | Large flows: hub cost per frame (`res.storage.flow.read`, 109,232 characters, 93 KB flow), mean over 100 runs | 2026-10-11 | Before (`ef34b5b`): 216 ms (max 243 ms). After (`0126ecc`, `87fd20f`): 1.84 ms (max 2.2 ms) | WI-24 (hub routing and loading) | verified |
| M-19 | Start with 20 flows (1.2 MB) and with 200 flows (12.1 MB) | 2026-10-11 | 20 flows: start to `evt.engine.ready` 4.46 s → 4.51 s; largest `cmd.engine.snapshot` response during loading 658 ms (n=14) → 260 ms (n=55). 200 flows: 31.25 s with only 79 of 200 loaded and 122 reads timed out after 30 s → 45.3 s, all 200 loaded, 0 errors; largest snapshot response 2514 ms (p99 1007 ms) → 506 ms (p99 495 ms, median 194 ms, n=199, 0 timeouts). No `hung`, `crashed` or `restarted` reported, before or after | WI-24 | verified |
| M-20 | Cost breakdown of the largest flow (92,808 characters), mean of 5 runs | 2026-10-11 | `Json.Stringify` in storage 54 ms; `Message.Parse` of the frame in the engine 161 ms; `Json.Parse` of the flow text 143 ms (`FlowDefinition.FromText` 124 ms); `Message.ParseHead` in the hub 1.25 ms | WI-24 | verified |
| M-21 | Log throughput of the storage, before WI-25 | 2026-10-11 | About 28 to 30 log lines/s (storage alone). Event flood of 20 s: log written until 207 s after the flood | F-08 | verified. The cause (one operation per timer run, timer resolution) is assumed |
| M-22 | Log throughput of the storage, after WI-25 | not stated | 1493 lines/s sent over 10 s (15000 lines); end marker 0.1 s after the last line in both files. Burst of 12000 lines: 3057 lines/s including the sender (sender 3.5 s; all written after 3.9 s). The value is limited by the sender; the storage maximum was not measured | WI-25 target: at least 1000 lines/s over 10 s | verified; target met |
| M-23 | Event flood after WI-25: 362 events/s (905 instances in 20 s) | not stated | Log complete 1 s after the flood. RSS storage 17.59 → 18.05 MB, 18.05 MB after drain. Engine snapshot latency median 0.88 ms, p99 7.27 ms | WI-25 | verified |
| M-24 | `flow.read` during a log flood of 15000 lines | not stated | Response times 189, 99, 5, 3 and 9 ms (the first value probably includes connection setup). Before WI-25: the request waited behind the flood up to its 30 s deadline | WI-25 target: answered in under 1 s | verified |
| M-25 | Soak run after WI-25: 90 s, about 120 events/s (4 starts of 0.25 s each) | not stated | Errors 0; RSS and handles flat (storage 17.86 → 17.93 MB); snapshot latency p99 11.5 ms. Before WI-25: about 20 events/s. The 600 s run was not done | WI-25 (soak rate) | verified (one 90 s run) |
| M-26 | Arrival time of events in the GUI stub (command to event in the stub) | not stated | Skeleton flow, first run: 2 to 4 ms for `evt.instance.started` and the first element states; 223 to 226 ms for the events after the 200 ms sleep element. Second run: 4 to 16 ms, then 224 to 227 ms. Wall clock via `GetSystemTimePreciseAsFileTime`; the Python side is not included | WI-13 (stub) | verified |
| M-27 | R3: parse time of one process with N synthetic element classes (about 160 lines each, 10 parameters). Wall time of a process that parses everything and ends at once (`--role=none`, exit 2), including the start of `ahkrun.py` and the interpreter. Median (min to max) of 7 runs | 2026-10-14 | N=0: 179 ms (159 to 277). N=50: 183 ms (178 to 408). N=150: 226 ms (218 to 880). N=300: 281 ms (279 to 1328). Per class about 0.33 ms. The maxima are single outliers (first run of a new file set; antivirus scan assumed) | R3 (ARCHITECTURE 10): threshold 150 ms later at 150 elements, not reached (+48 ms) | verified (one machine, see the note on the machine at the top; load before 8 %, after 17 %) |
| M-28 | R3: memory of a process after the start with N element classes: working set and private bytes (`psutil memory_info`, 1.5 s after ready; the same values for supervisor, storage, engine and worker within 1 MB). Median of 7 runs | 2026-10-14 | N=0: working set 20.7 MB, private 9.9 MB. N=50: 24.5 / 13.9 MB. N=150: 32.2 / 21.4 MB. N=300: 43.1 / 32.2 MB. Per class about 75 KB (about 480 bytes per source line), the same in every process. Max over the runs at most 0.2 MB above the median | R3: threshold 10 MB more at 150 elements, **exceeded** (+11.5 MB private and +11.5 MB working set per process). With about 10 processes (supervisor, storage, engine, manager, 5 editors, warm worker) the sum is about 115 MB more at 150 elements. See ARCHITECTURE 10, R3 | verified for the synthetic elements; the editor and the manager do not exist yet (assumed to cost the same) |
| M-29 | R3: start of the processes with N element classes. Time from the launch of the supervisor (`ahkrun.py`) until the state `ready` in `cmd.process.list`, polled every 3 ms; and the time of a worker from `cmd.process.spawn` to `ready` (3 workers per run, 7 runs = 21 values) | 2026-10-14 | Worker request to ready, median (min to max): N=0 172 ms (100 to 231); N=50 150 ms (94 to 282); N=150 176 ms (156 to 230); N=300 242 ms (195 to 389). Engine ready from the launch: N=0 570 ms, N=50 603, N=150 495, N=300 617 (the spread of 400 to 1000 ms between runs is larger than the effect; supervisor, storage and engine start at the same time and the supervisor tick decides when `ready` is seen; no trend visible below N=300) | R3: threshold worker start 150 ms later at 150 elements, not reached (+4 ms median). At 300 elements +70 ms | verified. The start-to-ready times of the whole chain are too noisy to show an effect; M-27 is the clean number for the parse time |
| M-30 | Load phase of the engine with 200 big v1 flows (12.1 MB, the flows of `test_big_flows.py`), 3 runs per variant (alternating). `plain`: the element classes of the product (only 3 of the flow classes registered, so `FlowExprConvert` leaves 14,925 elements pending). `stubs`: a stub class for each of the 65 other classes of the 8 flows, every one of their 352 parameters declared as an expression (worst case after S2 and S8). Timings inside the engine from QueryPerformanceCounter hooks (`tools/measure_r3_hooks.ahk`, no change in `src/`) | 2026-10-14 | `plain`: start to `evt.engine.ready` 54.5 s (51.9 to 55.4). Per flow: `FlowDefinition.FromText` 91 to 98 ms mean (max 308 ms), `FlowExprConvert.Run` 0.65 ms mean (max 10 ms; 0.13 s in total), whole answer handler 92 to 97 ms mean. From the first flow list to the last flow loaded 51.6 s, of which the answer handlers 19.5 s: the other 32 s (about 160 ms per flow) are outside the handler (frame parse in the engine, M-20: 161 ms; storage read and hub), assumed. Variable phase (last flow loaded to ready) 1.9 s, its answer handlers 40 ms in total. Snapshot during the load: median 159 ms, max 588, 668 and **1511 ms** over the 3 runs (budget 1000 ms). `stubs`: ready 53.4 s (51.9 to 60.4). `FlowExprConvert.Run` 21 to 24 ms per flow on average (max 69 ms; 4.3 s in total, 4.3 to 4.9 s), by flow size from 9 ms (30 KB) to 43 ms (91 KB); handler 105 to 126 ms. Variable phase 1.6 to 1.9 s. Snapshot: median 163 ms, max 555, 563 and 791 ms. Once more the plain test through `run_suite.py` (no hooks): ready 52.0 s, snapshot median 128 ms, max 576 ms, 275 samples, passed | F-282 (OPEN-ITEMS), WI-46; baseline for the packages of S2 that run `test_big_flows.py` | verified (3 runs per variant, one machine with the normal load of the owner's machine, load before 17 %, after 4 %). The 1511 ms outlier of one `plain` run is not explained |

Notes on the table:

- M-08 and M-09 give different start times (0.30 s and 0.56 s). They are not the same setup: M-08 is the 100-start test, M-09 is the start with one flow after WI-24. The source does not explain the difference.
- Dates marked "not stated" are missing in the source. The work items of these measurements carry no date of the measurement itself.

## Method

**Test runs.** The stress measurements run with `python -m pytest tests -m stress`. When `AHF_MEASURE_OUT=<file>` is set, each measurement writes one JSON line to that file and prints it as `MEASURE ...`. The Python clients (`tests/stress/stresskit.py`, `StressClient`) wake the hub after each write, as the AutoHotkey roles do. All tests except the long runs ran ten times in a row (`-k "not memory and not backlog"`). Unless stated otherwise, the values are the median and the maximum over these 10 runs (latencies: median of the medians, maximum of the maxima). Memory and handles are read with `psutil`. Idle CPU is the difference of the CPU time (`psutil cpu_times`) divided by the wall-clock time, over 30 s after 5 s of settling.

**Soak and churn.** The soak test (`-m soak`, `tests/stress/test_soak.py`) runs in one process and takes its length from `AHF_SOAK_SECONDS`. Connection churn in the soak run is switched on with `AHF_SOAK_CHURN=1`. Measurements must not run in parallel with other load.

**Spikes.** The spike code (`pipe_server.ahk`, `client.py`) is not in the working tree any more. It is in the git tag `v2-phase2-final` under `work_items/spikes/`.

**Big flows.** `tests/stress/test_big_flows.py` (WI-24). The cost breakdown (M-20) was taken on the largest flow (92,808 characters), the frame and flow sizes in M-18 and M-19 are as stated in the table.

**Log throughput.** `tests/stress/test_log_backlog.py` and the flood tests (WI-25). The 1000 lines/s target is measured over 10 s.

**R3 and load phase (WI-46).** `tools/measure_r3.py` (VS Code tasks "Tool: R3 measurement ..."; code state of the numbers: commit `d1ee026`). Run it alone: `python tools/measure_r3.py parse --runs 7` (M-27 to M-29: synthetic element files in a temporary folder, an entry script that includes `src/AhfBoot.ahk` and the files; rounds alternate over the counts N = 0, 50, 150, 300, in forward and reverse order) and `python tools/measure_r3.py load --runs 3` (M-30: the flows and the probe of `tests/stress/test_big_flows.py`, entry with `tools/measure_r3_hooks.ahk`; `--variants plain,stubs`). Memory: `psutil memory_info` (`wset` = working set, `private`), 1.5 s after `ready`. The numbers are medians; `--out FILE` appends the JSON lines. The synthetic elements are about 160 lines each (v1: about 160 lines per element, 162 elements), so N=150 corresponds to the size of v1.

**Stub arrival times.** M-26 was measured with `GetSystemTimePreciseAsFileTime` from the stub side only.

## Not measured

These points are missing from the measurements. The first group is listed in the source as "not measured" or "not checked".

- Memory with 5 open editors (M-06). There is no editor role.
- Engine state change until editor redraw (M-07). There is no editor.
- Latency with an AutoHotkey client as the other end. Only the Python client was used.
- Triggerhost (WI-14) was not built and is not part of the runs.
- Worker elements (pool) were not put under load.
- The 10-minute soak with connection changes (`AHF_SOAK_CHURN=1`) was not run. At the time of WI-16 it would have failed on F-07; the source does not say that it was run after the fix.
- The 600 s soak with the new rate (WI-25) was not run.
- The cause of the 0.56 s start with one flow (M-09). The source does not rule out an influence of the test run before it.
- The storage maximum log throughput (M-22). The value shown is limited by the sender.
- Memory with a full log queue (the WI-25 limit was reached in a test, but its memory was not measured).
- Log time budget values of 5, 20 and 50 ms. Only 10 ms was used, and no other value was compared.
- Ping latency during a log flood. Only `flow.read` was measured (under 200 ms).
- The cost of up to 500 `evt.log.entry` sends in one bundle. They run in the same timer run and may exceed the 10 ms budget.
- Several hundred log sources. Only 4 sources were tested.
- Effect of `FlushFileBuffers` on a power failure. Not testable in this setup.
- Whether `OpenProcess` returns "access denied" (error 5) in practice.
- Idle CPU as "sum of the processes in percent of one core". Decision E5 applies the target to the whole system, so this reading is not a target any more.
