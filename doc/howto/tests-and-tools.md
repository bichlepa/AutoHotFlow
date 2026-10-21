# How-to AHK v2: Tests and tools

Entries of this category. Entry format, rules and index: [`../HOW-TO.md`](../HOW-TO.md).

### Blocking error dialogs: `ahkrun.py` and the dialog watcher

- **Problem:** A load error, an unhandled run-time error or a `MsgBox` opens a dialog. The process waits for a click, and the calling agent hangs.
- **Wrong:** Starting the script directly with the interpreter and waiting for it to return.
- **Right:** `python tools/ahkrun.py --timeout 30 skript.ahk`. Load errors go to stderr (`/ErrorStdOut=UTF-8`). Other dialogs are detected by `tools/ahf_dialogwatch.py` (windows of class `#32770` in the process tree), their text and a PNG are saved under `%TEMP%\ahf_dialogs\`, the dialog is closed, and the process ends with exit code 97.
- **Status:** verified (`tests/support/test_dialogwatch.py`: load error, run-time error, `MsgBox`, timeout). Limits: only dialogs of class `#32770`.
- **Source:** `tools/ahkrun.py`, `tools/ahf_dialogwatch.py`


### ctypes: set `argtypes` and `restype`, and use an own `WinDLL` object

- **Problem:** The dialog watcher closed dialogs only sometimes. `GetDIBits` without `argtypes` received a handle as a C `int`; values above 2**31 raised `OverflowError`. The watcher thread swallowed the exception, and the dialog stayed open. Another module had set `argtypes` on the shared `windll.user32` with its own `WINFUNCTYPE` class; each call of `WINFUNCTYPE` creates a new class, so `EnumWindows` raised `ArgumentError: expected WinFunctionType instance`.
- **Wrong:** Calling WinAPI functions with handle parameters without `argtypes`/`restype`, discarding exceptions in a watcher loop before the essential step is done, and setting `argtypes` on the shared `windll.user32`.
- **Right:** Set `argtypes` and `restype` for every function called. Gather information in `try`; close and end in `finally`. Use `user32 = ctypes.WinDLL("user32")`: its functions are separate from those of `windll.user32`.
- **Status:** verified (20 consecutive runs of the dialog watcher, worst 0.58 s; `tests/fault/test_debug_role.py` for the `WinDLL` object)
- **Source:** `tools/ahf_dialogwatch.py`, `tests/fault/test_debug_role.py`


### Test processes: output in files, read logs only after the end

- **Problem:** An AHK process started with `subprocess.PIPE` can keep the pipe open at a timeout, and then `communicate()` hangs too. `ahkrun.py` copies its stderr only at the end: while a role runs under it, its stderr and log files are empty. A test waiting for a log line hit its deadline, and right after the end an observer may not have the last event yet. A role started via `ahkrun.py` with output in a pipe can block as well, because the pipe buffer fills up.
- **Wrong:** `subprocess.PIPE` for AHK processes; looking into the output during the run to check the state.
- **Right:** Redirect stdout and stderr to files in the data directory (`run_ahk` in `tests/conftest.py`); on `TimeoutExpired`, end the process tree with `psutil`. Start role processes via `ahkrun.py` as a child process (`procs.start`) with output in files and `--timeout 60`; the AutoHotkey PID is in `sys.hello` (`payload.pid`) and is a child of `ahkrun` (`psutil.Process(pid).ppid()`); the exit code of `ahkrun` is that of the script. During the run query the state via messages (`cmd.process.list`, `sys.hello`); end the session, wait for the end, then read the log. Fetch events with `Recorder.wait(..., timeout=1)`, not with `find`.
- **Status:** verified (`test_hung_script_is_killed_at_timeout`, no `AutoHotkey64.exe` left over; `tests/integration/test_role.py`, 9 tests; `tests/fault/test_pipe_break.py`, `tests/fault/test_shutdown.py`: `find` was too early once in 20 runs, 80 of 80 green with `wait`)
- **Source:** `tests/conftest.py`, `tests/integration/test_role.py` (`RoleRun`), `tools/ahkrun.py`


### Raw strings cannot end with a backslash (pipe names)

- **Problem:** `r"\\.\pipe\"` is a syntax error in Python, because a raw string must not end with a backslash.
- **Right:** `PIPE_PREFIX = "\\\\.\\pipe\\"` as a normal string; only append names.
- **Status:** verified (code runs, pipe connections in the tests)
- **Source:** `tests/support/winpipe.py`


### Result file of a test helper: Python and AHK access at the same time

- **Problem:** The Python test polled the JSON Lines file of an AHK helper every 5 ms. The helper's `FileAppend` in `OnClose` then failed with an access error, the entry was lost, and the test reported "no connection-close message". Python in turn raised `PermissionError` while AHK was writing.
- **Wrong:** A single `FileAppend` attempt in the helper, a single `read_bytes` in the test.
- **Right:** Both sides retry briefly (`Kit.Record` up to 200 times with `DllCall("Sleep", 2)`; `rawpipe.read_jsonl` up to 50 times). An incomplete last line is ignored.
- **Status:** verified (error reproducible; after the change 8 runs of the 26 pipe tests without occurrence)
- **Source:** `tests/integration/helpers/PipeTestKit.ahk`, `tests/integration/helpers/rawpipe.py`


### Python test reader lost bytes when a read was cancelled

- **Problem:** `test_frame_of_exactly_16_mib_is_echoed` occasionally waited 60 s for a reply that the AHK server had written completely. `read_some` waited 100 ms, cancelled with `CancelIoEx`, and always returned `None`. If the read completed between the end of the wait and the cancel, the bytes were in `n` and got discarded, and a frame was missing forever.
- **Wrong:** After `CancelIoEx` and `GetOverlappedResult(..., wait=True)`, ignoring the result and returning `None`.
- **Right:** If `GetOverlappedResult` succeeds with `n > 0`, return the bytes. An overlapped operation can complete despite the cancel (the same holds for writes).
- **Status:** verified (60 of 60 runs of a loop script green; previously failed after 10 to 40 runs)
- **Source:** `tests/support/winpipe.py`


### Test server in Python: the return of the handler closes the connection

- **Problem:** `PyServer(name, handler=lambda end: None)` closed the connection at once; the AHK client saw "connection closed" instead of the expected data.
- **Right:** The handler owns the connection. To use it from outside, let the handler block (`lambda end: end.closed.wait(300)`).
- **Status:** verified (own error in the test)


### psutil status lags behind `suspend` by up to 73 ms

- **Problem:** After `psutil.Process.suspend()`, `status()` does not show `STATUS_STOPPED` at once. A single check right after stopping is unreliable.
- **Wrong:** Reading `status()` once after `suspend` and checking it immediately.
- **Right:** Poll the status every 10 ms until `STATUS_STOPPED`, with a deadline of 2 s.
- **Status:** verified (30 runs measured, delay up to 73 ms)
- **Source:** `tests/support/test_procs.py`


### A `conftest.py` in a subfolder shadows `tests/conftest.py` for `from conftest import ...`

- **Problem:** With `tests/fault/conftest.py`, the full run failed at collection: modules that do `from conftest import TESTS_DIR` got the subfolder's `conftest` (`ImportError`). Single runs of the fault tests did not show it.
- **Wrong:** Putting fixtures of a subfolder in its `conftest.py` while other tests import `conftest` by name.
- **Right:** Put the fixtures in a module such as `tests/fault/faultfixtures.py` and import it explicitly. Always also run the full suite (`python -m pytest tests -q`).
- **Status:** verified (the full run was red with 2 collection errors; green after the change)
- **Source:** `tests/fault/faultfixtures.py`


### A test that counts operations must set `Critical` or avoid `Sleep`

- **Problem:** A test of the time budget let operations wait with `Sleep(5)`. The queue had set a timer when enqueuing; during `Sleep` the timer ran in between and processed operations itself, so the count was wrong.
- **Right:** Start the test with `Critical("On")` (the timer is deferred), and wait with a loop over `Time.NowMs()` instead of `Sleep`. `until` is a reserved word and cannot be a variable name.
- **Status:** verified
- **Source:** `tests/ahk/storage_queue.test.ahk`


### Python client: `events(timeout)` ends only after silence

- **Problem:** `AhfClient.events(timeout=0.3)` does not listen for 0.3 s; it ends after 0.3 s without a new message. With a running flow the loop never ended, and threads hung until the deadline.
- **Wrong:** `sum(1 for _ in client.events(timeout=0.3))` to listen for 0.3 s.
- **Right:** Loop with an own end time and `client._next_event(remaining time)` (see `test_clients_churn.py`). Every waiting loop in a test needs its own deadline.
- **Status:** verified (hang until the pytest deadline; green afterwards)
- **Source:** `tests/stress/test_clients_churn.py`


### Parallel test runs (pytest-xdist): add `#SingleInstance Off` to test scripts

- **Problem:** In the first run with `-n 8`, 21 tests failed with "exit=15". Several workers started the same `*.test.ahk` at the same time. AHK asks "An older instance of this script is already running. Replace it?" (default without `#SingleInstance Off`); the dialog watcher closed it and ended the process.
- **Wrong:** Assuming that a separate data directory and session ID isolate the scripts. They isolate data and pipes, not the script itself.
- **Right:** Put `#SingleInstance Off` in every script a test can start as the main script (`tests/ahk/lib/Assert.ahk`, `tests/ahk/helpers/*.ahk`).
- **Status:** verified (21 errors before, green with `-n 8` afterwards)
- **Source:** `tests/ahk/lib/Assert.ahk`


### Static checks of AHK source with regex: strip strings carefully and test every rule

- **Problem 1:** The checker removes string literals before matching. That turned `Critical("On")` into `Critical("  ")`, so a rule that looks for `"On"` never fired.
- **Right:** Match the arguments on a text version that keeps the strings, and use the version without strings only for the keyword. Every rule needs a self-test with a hit, otherwise such an error stays unnoticed.
- **Problem 2:** In `catch as e {`, the pattern took `as` for the error class, and empty `catch as e {}` blocks were missed.
- **Right:** Exclude the word with `(?!as\b)`.
- **Status:** verified (self-tests `critical` and `test_catch_variants`)
- **Source:** `tools/arch_check.py`, `tests/test_architecture.py`


### AHK unit test: change static constants at runtime and reset them

- **Problem:** The test for an unacknowledged abort would have waited 2 s (`WorkerBridge.ORPHAN_MS`).
- **Right:** Set `WorkerBridge.ORPHAN_MS := 150` in the test and reset it in `finally`. The constant is read on each call, not copied at load time.
- **Status:** verified (`tests/ahk/engine_worker_bridge.test.ahk`; without the reset the value would stay changed for later cases)


### A fixed pause before an abort is a race

- **Problem:** `test_cancel_stops_the_running_element` waited 0.1 s after `cmd.worker.run`, then sent `cmd.worker.cancel`. The test element blocks only 800 ms. Under load the abort came after the end, and the answer was `not_found`.
- **Wrong:** Waiting a fixed time and assuming the element is still running.
- **Right:** Let the element run long enough (parameter `Duration`, 3 s); wait for the job via `cmd.diag.snapshot` (`info.job`); put the answer of the abort into the error message.
- **Status:** verified (reproduced with a pause of 1.0 s; new test green). That the acceptance failure happened this way is inferred, not seen.
- **Source:** `tests/integration/test_worker.py`


### Test-only start delay without a product option

- **Problem:** A child had to report only seconds after its start, but the supervisor passes only a fixed list of options to children.
- **Right:** Use the `--start=` argument the supervisor passes anyway: `--start=echo:slowhello3000` starts the role `echo` with `--flow=slowhello3000`. `EchoRole.Start` then calls `super.Start()` only after 3000 ms, via `SetTimer` in its own method (with `try`). `Persistent()` is already set, so the process stays alive while it waits.
- **Status:** verified (`tests/fault/test_shutdown.py`: the child is in state `starting` at shutdown and reports afterwards)
- **Source:** `tests/integration/helpers/EchoRole.ahk`


### `with WakingHub(...).start()` starts the hub twice

- **Problem:** `with WakingHub(name).start() as hub:` calls `start()` twice, because `PyHub.__enter__` calls `start()` itself. Two accept loops on the same name are the result.
- **Right:** `with WakingHub(name) as hub:`. Without `with`: `hub = WakingHub(name).start()` and `hub.stop()` in a `finally`.
- **Status:** assumed (read from the source of `tests/support/pyhub.py`, not executed)
- **Source:** `tests/support/pyhub.py` (`__enter__`)


### Python client: `sys.pong` is a reply, not an event

- **Problem:** The test waited in vain with `wait_event("sys.pong")`, although the worker answered.
- **Wrong:** `send` followed by reading `events()`.
- **Right:** `client.request("worker:1", "sys.ping", {...})`. Replies carry `corr` and do not appear in the event stream of `AhfClient.events()`.
- **Status:** verified (`test_pings_are_answered_while_a_blocking_element_runs`)


### A wait loop over `events()` discards foreign messages

- **Problem:** A helper read `events()` and searched for one message. Events of other runs that it did not search for were lost, and the test waited in vain.
- **Right:** Collect all events of a time window (`late = [m for m in ... if type == ...]`), or read events in order with one list per type.
- **Status:** verified (in a test run, the second `done` event was missing at first)


### A frozen process with `psutil.suspend()`: ack timeout and orphan deadline

- **Problem:** Whether the engine and the pool end properly when a worker does not respond had not been checked.
- **Right:** `psutil.Process(pid).suspend()` freezes the worker. Then `cmd.worker.run` gets no acknowledgement (5 s ack timeout; the element ends with `exception`, "worker not available"). The engine removes the slot and lets the process be terminated (`TerminateProcess` also ends a suspended process), and the next job runs on a new worker. After a cancel without acknowledgement, the engine waits `ORPHAN_MS` (2 s), then terminates and replaces the worker.
- **Status:** verified (`test_frozen_worker_does_not_answer_the_run_and_is_replaced`, `test_cancel_of_a_frozen_worker_ends_the_instance_at_once_and_the_process_is_killed_and_replaced` in `tests/fault/test_worker_lifecycle.py`)


### Force an interruption in a test with a hook in a stub

- **Problem:** An error that occurs only when a timer interrupts between two lines is hard to reproduce with real time.
- **Right:** The stub of a dependency (`FakeWorkers.Usable`) calls a hook once (`owner.executor.Tick()`). The call sits exactly between check and start and behaves like an interrupting timer, without time dependence.
- **Status:** verified
- **Source:** `tests/ahk/helpers/EngineOwner.ahk`


### The v1 interpreter does not understand `/ErrorStdOut=UTF-8`

- **Problem:** `tools/ahkrun.py --interpreter` first passed the same `/ErrorStdOut=UTF-8` as for v2. The v1 interpreter (AutoHotkey_H 1.1.32.00) does not know the suffix and opens a dialog (the dialog guard caught it, exit 97), even for a script that is correct.
- **Wrong:** `/ErrorStdOut=UTF-8` for the v1 interpreter.
- **Right:** `/ErrorStdOut` without a suffix. Load errors then go to stderr (`script.ahk (3) : ==> Missing ")"`, exit code 2). The output encoding of `FileAppend ..., *` was not checked; the golden harness writes its results to a file with `UTF-8-RAW` and only ASCII (non-ASCII as `\uXXXX`).
- **Status:** verified (both variants run with `ahkrun.run(..., interpreter=...)`)
- **Source:** `tools/ahkrun.py` (`ERROR_OPTION_CUSTOM`)


### v1: a `try` block turns failing commands into exceptions, also inside called functions

- **Problem:** The first harness wrapped every case in `try/catch`. `FileDelete` of a file that does not exist (inside `GlobalVariable_Set`) then threw an exception with the message `1` (the ErrorLevel), which v1 never does because it never calls these functions inside a `try`.
- **Wrong:** `try { Var_Set(...) } catch e { ... }` around code that uses commands which set ErrorLevel.
- **Right:** No `try` around the code under test. An uncaught error opens a dialog; with `ahkrun.py` the dialog is caught and the generator records the case as `uncaught_error` and goes on with the next case.
- **Status:** verified (first run of the harness: exception `1` from `FileDelete`)
- **Source:** `tests/golden/v1/harness.ahk`


### v1: returning a variable from a function turns a number into text

- **Problem:** The kind of a value ("pure number" or text, determined the way `Jxon_Dump` does: `ObjGetCapacity([v], 1) == ""` is true for a pure number) changed on the way through functions.
- **Right:** `return v` and `ObjFullyClone(v)` give a text even if `v` held a number; `return a + b` and a direct read from an object give a number. Consequence for the golden data: everything that v1 reads through `Var_Get` is text, only the result of arithmetic is a number (`doc/TEST-STRATEGY.md` section 7, `tests/golden/FINDINGS.md`). A float given as JSON number to `Jxon_Load` becomes a text (only integers are converted), so the harness takes numbers as text and adds `+ 0`.
- **Status:** verified (small v1 script and golden cases `variables.instance.number`, `varaccess.set.number`)
- **Source:** `tests/golden/v1/harness.ahk`, `v1/Lib/Json/Jxon.ahk`


### v1: `global` outside a function makes a super-global; included files run in include order

- **Problem:** The v1 sources use `_WorkingDir`, `global_AllBuiltInVars` and similar inside functions without declaring them. It was unclear how the harness can supply them.
- **Right:** A `global x := ...` statement outside any function creates a variable that every function sees (AutoHotkey_L feature). Top-level code of an included file (`Global variables.ahk` creates the `Variables` folder from `_WorkingDir`) runs in the position of the `#Include` in the auto-execute section, so set `_WorkingDir` before the include and call the main function after all includes. Functions and classes may be anywhere.
- **Status:** verified (harness runs against the unchanged v1 sources)
- **Source:** `tests/golden/v1/harness.ahk`


### v1: a hanging case needs a watchdog timer, and a folder reset costs 0.4 s

- **Problem:** The v1 script parser loops forever for some inputs (a line that starts with `;`), and the generator waited for the outer timeout. Separately, removing and recreating a folder with `FileRemoveDir`/`FileCreateDir` took 413 ms per pair on this machine (20 pairs: 8266 ms), which made 1200 cases take 9 minutes.
- **Right:** `SetTimer` with a check of `A_TickCount` interrupts a long running loop of the main thread in v1; the timer writes the result line `timeout` and calls `ExitApp`, and the generator restarts after that case. Reset the folder only when the previous case left a file there (check with `Loop, Files`); the run then takes about 2 minutes for 2200 cases. The cause of the slow folder operations (virus scanner, indexer) is assumed, not checked.
- **Status:** verified (6 hangs ended by the watchdog; timing measured)
- **Source:** `tests/golden/v1/harness.ahk`, `tools/golden_v1.py`


### Bash tool: `( ... ) &` kept running after the call

- **Problem:** `(cmd > file; echo done >> file) &` in the Bash tool returned at once and the output file stayed empty, which looked as if nothing had started. The job was in fact running; starting the same command again with `run_in_background` produced two runs that wrote the same result files.
- **Right:** Start a long command once with the tool's `run_in_background`, and look at the process list (`Get-CimInstance Win32_Process`) before starting it again. This contradicts the note in `doc/PARALLEL-WORK.md` section 7 ("a shell loop started with `&` ended with the command that started it") for this one observation.
- **Status:** observed once; cause not investigated


### `Json.Parse` refuses a repeated key; the golden case files have some

- **Problem:** `Json.Parse` throws a `JsonError` ("duplicate key") for an object with the same key twice. 21 case lines in `tests/golden/cases/*.json` have a repeated key in `vars` (the file is not valid for a strict parser, though Python reads it).
- **Right:** A test that only needs the text of each case cuts `kind` and `text` out of the line with a regular expression and decodes the string with `Json.Parse` (`tests/ahk/expr_eval_vars.test.ahk`). The regular expression sits in a single-quoted AHK string, where a backslash is literal and is not doubled.
- **Status:** verified


### Patching files with a Python script: a backslash and an n in the replacement become a line break

- **Problem:** A patch script written in a shell heredoc replaced text with a replacement that contained a backslash followed by n (meant as the two characters, for a JSON text inside an AHK string). The file got a real line break instead, and did not load. The doubled backslash of the script was halved on its way (the pitfall of AGENTS.md about heredocs, here with `\\n`). The same script silently did not match when the file had CRLF line ends.
- **Right:** Use the editor tool for small changes. In a script, build the backslash with `chr(92)` and the line break with `chr(10)`, read and write with `newline=""`, and check with `print(old in s)` that the text was found. Better still, write the patch script itself with the editor tool and run the file: in WI-0040 a quoted heredoc (`<<'EOF'`) with a Python script still lost one of two backslashes, so `engine\\vars` arrived as `engine\vars` and Python made `\v` a vertical tab (an `#Include` that could not be opened); `"\\r\\n"` became a broken string.
- **Status:** verified (several failed patches in WI-0039 and WI-0040)


### An error in the constructor of a role shows only as exit 2 "bad arguments"

- **Problem:** `AhfBoot` builds the role in a `try` and reports every exception as `bad arguments: <message>`, without the line. A mistake in a new class that the constructor creates (WI-0041: a field and a method with the same name) looks like a wrong option, and the supervisor restarts the engine three times.
- **Right:** Build the role in a small test script and print `e.Message`, `e.File`, `e.Line` and `e.Stack` of the exception: `#Include src\AhfBoot.ahk`, then `try { Engine(Map("session", "x", "hub", "h", "data", "d")) } catch as e { FileAppend(e.Stack, "**") }`, run with `tools/ahkrun.py`. The stack names the line of the failed assignment.
- **Status:** verified (WI-0041)
- **Source:** `src/AhfBoot.ahk`


### `FileRead(path, "UTF-8")` still reads a UTF-16 file with BOM

- **Problem:** The v1 language files are UTF-8 without BOM (`en.ini`) and UTF-16 LE with BOM (`de.ini`, `ko.ini`, `ru.ini`). One read for both was wanted.
- **Right:** `FileRead(path, "UTF-8")`: a BOM decides over the encoding option, so the UTF-16 file is read correctly and the UTF-8 file without BOM as UTF-8 (not as ANSI). `IniRead` was not used: it reads UTF-16 files and ANSI files only.
- **Status:** verified (probe: `Abbrechen` found in `de.ini` with and without the option; `tests/ahk/core_lang.test.ahk`)
- **Source:** `src/core/LangTable.ahk`


### The flows of the engine are loaded before its variables: wait for `evt.engine.ready`

- **Problem:** An end-to-end test waited with `Chain.wait_flows` (the flows appear in `cmd.engine.snapshot`) and started them at once. The expressions found no global variable: "Retrieving variable 'global_n' failed", and the log said "ready with 11 flow(s) and 3 variable(s)" only afterwards.
- **Wrong:** Starting a flow that reads global or static variables as soon as the snapshot lists it.
- **Right:** Wait for `evt.engine.ready` (it comes after the variables are loaded, WI-0041) before such a flow starts, as `tests/fault/test_var_persistence.py` does.
- **Status:** verified (red before, green after the wait)
- **Source:** `tests/fault/test_param_eval.py`


### Generated AHK v2 code: some mistakes stop the whole script at load time, one case can end the process

- **Problem:** The expression oracle (`tools/expr_oracle.py`) writes one script with thousands of cases. A string literal in front of an arithmetic operator (`"a" + 1`, `"a" * x`, `!"a" * 2`) is a **load error** ("Unexpected operator following literal string"): the script does not start at all, not even for the other cases. `1 + "a"`, `-"a"`, `1 / 0` and `Mod(1, 0)` load fine and throw a `TypeError` or `ZeroDivisionError` when they run. An unassigned variable that is read gives a warning dialog at load time unless `#Warn All, Off` is set. `MinInt // -1` (and `Mod(MinInt, -1)`) ends the whole process, no `try` can catch it.
- **Wrong:** Generating `"a" + 1` and expecting a catchable error; running all cases in one process and losing every result when one case ends the process.
- **Right:** The generator never puts a string literal in front of an arithmetic operator (a variable that holds the text is fine), and keeps `//` and `Mod` away from operands near the limits of Integer. The runner works in batches and bisects a batch that ends without a result, so the offending case is reported by its ID (`NativeCrash`). Write a `Main()` and call it: a script whose `Main` is never called exits 0 without any output.
- **Status:** verified (WI-0044)
- **Source:** `tools/expr_oracle.py`


### A role that holds element classes needs `Lang()`, and a relative `#Include` is relative to the including file

- **Problem:** The element files call `Lang()` in `Name()` and `Parameters()`. The engine and the worker got `core/Lang.ahk` by chance through the parameter evaluation. The first process that held element classes without it (the trigger host stand-in of the memory measurement, WI-0047-PREP) showed a `#Warn` dialog "Specifically: Lang" at the start, which `ahkrun.py` caught as exit 97. A second trap with the role entries: a relative `#Include` is relative to the folder of the file that contains it, not to the main script, so a copy of an entry script in another folder has to make the paths absolute (`tools/measure_r3.py`, `rewrite_entry`).
- **Wrong:** An element base class that includes only `Errors.ahk` while the element files use `Lang()`; a copy of `src/entry/engine.ahk` in a temporary folder with the includes unchanged.
- **Right:** `elements/base/AhfElement.ahk` includes `core/Lang.ahk`, so every role with element classes has it. Copies of entry scripts get absolute include paths. The file-level code of an element (`ElementRegistry.Register`) runs when the file is included, also when a class file includes another class file, so such an include registers the class in every role that includes the first file (F-0081).
- **Status:** verified (WI-0047-PREP: the warning dialog before the change, the measurement and `tests/test_element_includes.py` after it)
- **Source:** `src/elements/base/AhfElement.ahk`, `tools/measure_r3.py`


### A timer thread can run between "check" and "use" of a shared Map entry

- **Problem:** AutoHotkey runs a timer or a message handler between two lines of another thread unless `Critical` is on. `if (!m.Has(k)) ...` followed by `m[k]` on the next line is not atomic: when the timer deletes `k` in between, `m[k]` throws `UnsetItemError`. In storage this was a log line that vanished without a count (F-0088: `_LogToFile` against `_FinishLogBundle`). The error is easy to miss: a handler that throws is only a log line.
- **Wrong:** `if (!this.logBuffers.Has(f)) this.logBuffers[f] := Map(...)` and then `buf := this.logBuffers[f]`; and a flag, a check and a `Delete` of the same entry in another thread without `Critical`.
- **Right:** Read once (`buf := m.Get(k, "")`, create if not an object) and run every change of the shared state (flag, check, removal, scheduling) in one `Critical` section in both threads (`prev := Critical("On")` ... `finally Critical(prev)`).
- **Status:** verified (burst test red about 1 in 3 under load before, 0 of 30 after; `tests/ahk/storage_logbuf.test.ahk` red before, green after)
- **Source:** `src/storage/Storage.ahk` (`_LogToFile`, `_FinishLogBundle`), `doc/OPEN-ITEMS.md` F-0088


### `FlowRun.probe` reads the files when it is called: the next run clears them

- **Problem:** A test that runs several flows one after the other and calls `run.probe("x")` at the end reads the probe files of the LAST run (`flows.begin` clears `global_probe*` before every run), or `None`, and a test of the first flow fails for no visible reason.
- **Wrong:** `runs = [flows.run(i) for i in ids]` and then `runs[0].probe("x")`.
- **Right:** read the probes right after the run, before the next one starts (`tests/integration/test_core_a_elements.py::run_all` stores them in `run.seen`). A run that ended with an exception has no probe: `probe` then waits for its timeout, so read it only for a flow that finished.
- **Status:** verified (WI-0052)
- **Source:** `tests/support/flowrun.py`, `tests/integration/test_core_a_elements.py`


### `psutil.cpu_percent(interval=None)` keeps its reference point per thread

- **Problem:** The load sampler (WI-0059) primed `psutil.cpu_percent(interval=None)` in the main thread and read it in its own thread one second later: the first value was always `0.0`.
- **Wrong:** Priming in one thread and reading in another, or relying on the first call of a new thread.
- **Right:** Compute the system load from two `psutil.cpu_times()` readings (busy = total minus idle, both summed over the cores), which has no hidden state (`tests/support/loadsampler.py`).
- **Status:** verified (by hand: main thread `21.0`, a new thread `0.0` after one second; psutil 6.1.1)


### CPU of a process tree including the processes that already ended: a job object

- **Problem:** A psutil walk over the children only sees processes that are alive at the moment of a sample. Test processes that live shorter than one second, and the xdist workers that end before `pytest_sessionfinish`, then count as external load.
- **Right:** The controller assigns itself to a job object of its own (`CreateJobObjectW`, `AssignProcessToJobObject(GetCurrentProcess())`); every process started below it is in the job, and `QueryInformationJobObject(JobObjectBasicAccountingInformation)` returns the user and kernel time of all processes that were ever in it, plus the number of active ones. Set `argtypes`/`restype` for every call (64-bit handles, see above). Nested jobs need Windows 8 or later; the fallback is the psutil walk (history field `load.ownTree`: `job` or `psutil`). The job gets no limit at all (no `SetInformationJobObject`): no `KILL_ON_JOB_CLOSE`, so the end of the controller kills nothing.
- **Limits:** (1) A process that leaves the job is missing from the sum and counts as external load. With our job (no `JOB_OBJECT_LIMIT_BREAKAWAY_OK`) a child cannot break away: `CreateProcess` with `CREATE_BREAKAWAY_FROM_JOB` fails with error 5 (access denied), so a program that insists on breaking away does not start inside a test run at all. Nothing in the repository uses that flag. (2) A process that a test causes but that is not started below the controller (a service, a COM server, a program started through the shell of the desktop) is not in the job either and counts as external.
- **Status:** verified: own vs external (`tests/test_runtool_runs.py::test_external_load_shows_in_the_figures_of_the_test`), no limit flags and refused breakaway (`tests/test_runtool_runs.py::test_the_job_object_only_counts`), fallback (`tests/test_load_history.py::test_without_a_job_the_sampler_falls_back_to_psutil`). Limit (2) is assumed, not tested.
- **Source:** `tests/support/loadsampler.py`


### The log of a flow is not in execution order across elements

- **Problem:** A test of nested loops read the lines of two trace points (`I 1`, `I 2`, `O 1`, ...) from `run.log` and expected the order in which the elements ran. The lines of one element came first, then the lines of the next one (`I 1 I 2 I 3 I 1 I 2 I 3 O 1 O 2`), although the steps ran in the right order.
- **Wrong:** Reading the order of events of different elements from `run.log`.
- **Right:** The log entries are written in a batch per source (an element is a source), so the order holds inside one element only. To record an order, append to a list variable in the flow (`Action_Add_To_List` to `seq`, probe it at the end: `tests/integration/test_core_c_loops.py::note` and `seq_of`). The log is fine for one element.
- **Status:** verified (WI-0054)
- **Source:** `tests/integration/test_core_c_loops.py`


### Two flows or two elements whose IDs differ only in case

- **Problem:** The flow runner writes `Flows/<flow id>.json`; on Windows `parse-x-CSV.json` and `parse-x-csv.json` are one file, so one flow overwrote the other and the engine "did not load" the list of flows. The same in a flow file: the keys of `allElements` are case-insensitive for `Json.Parse` (a repeated key is refused), so the IDs `i` and `I` are a "duplicate key".
- **Wrong:** Test flow names or element IDs that differ only by case.
- **Right:** Make the names differ by more than case (`...-upper-CSV-...`, `...-lower-csv-...`).
- **Status:** verified (WI-0054)


### `ctx.GetVar` with a path and a default object: read one member, tell "missing" from "empty"

- **Problem:** A loop that keeps its values in a hidden loop variable has to read one member per pass. Reading the whole variable per pass copies the whole list every time (a pass would cost O(size of the list)), and the empty text as the default cannot tell a missing member from an empty field.
- **Wrong:** `list := ctx.GetVar("A_LoopCurrentList", "", true)` in every pass; `if (field = "")` as the end of the list.
- **Right:** `ctx.GetVar("A_LoopCurrentList." index, NONE, true)` copies only the member (the path is split at the dots, an Integer key is found by its digits), and a default that is a unique object (`static NONE := Object()`) is returned as it is: compare with `ObjPtr`. Hidden loop variables are saved and restored with the other loop variables when a loop is entered and left.
- **Status:** verified (WI-0054, `tests/ahk/element_loops.test.ahk`, `tests/integration/test_core_c_loops.py::test_long_loops_do_not_scale_with_the_size_of_the_list_or_the_text` runs 3,000 members; the time per pass for a big list was not measured)
- **Source:** `src/elements/Default/lib/LoopOps.ahk`


### `Loop Parse` with the delimiter text "CSV" is the CSV mode

- **Problem:** The text of the delimiter field is a set of characters, except that AutoHotkey reads the text `CSV` (any case) as the CSV mode: `Loop Parse "a,b", "CSV"` gives `a` and `b`, not one field. v1 and v2 do the same.
- **Wrong:** Assuming that every delimiter text is a set of characters.
- **Right:** Keep the behavior (a flow may rely on it) and document it; a test pins it (`FieldsOf('a,"b,c",d', "CSV", "")` is three fields).
- **Status:** verified (v1 interpreter and `tests/ahk/element_loops.test.ahk`)
- **Source:** `src/elements/Default/Loops/Loop_Parse_A_String.ahk`


### A race test without a way to interrupt: a Map subclass runs the other path inside `Get`

- **Problem:** An interrupt cannot be forced between two lines of AutoHotkey code, so a race between a timer and a message handler cannot be tested by timing alone (a race that shows once in about 30,000 jobs needs minutes).
- **Wrong:** Waiting for a race to show with a loop and a timer, or a test that only checks the final result.
- **Right:** Give the shared container a subclass of `Map` whose `Get` runs a hook once, after the value is read and before it is returned: the hook runs the other path (for example the deadline) at the same place where the interrupt would land. `class SpyJobs extends Map { Get(key, default := "") { value := super.Get(key, default); if (IsObject(this.hook) && IsObject(value)) { h := this.hook, this.hook := "", h() }; return value } }`. Copy the entries into the spy and put it in place of the field. Old code gives 2 callbacks, the fix gives 1.
- **Status:** verified (`AnswerAndDeadlineOfOneJobEndTheJobOnce`, red before and green after); the spy catches only a `Get` that the code does before the change, so a test of a new code path needs its own spy method.
- **Source:** `tests/ahk/engine_worker_bridge.test.ahk`
### Writing AHK source with Python: a backslash-u in a Python literal becomes the character

- **Problem:** A test file for AutoHotkey was written with a Python script, and the expected text (an AutoHotkey string with a backslash-u escape, as plain text) was stored as the real character e-acute. The test then failed with a message whose two values looked alike.
- **Wrong:** Editing `.ahk` source through Python string literals, where backslash-u, backslash-n and similar are escapes of Python.
- **Right:** Write source files with the editor tool, or in Python through raw strings or bytes; check for non-ASCII bytes after the edit (decode the file and look for characters above 127).
- **Status:** verified (WI-0056, `tests/ahk/element_debug_ops.test.ahk`, fixed by byte replacement)
- **Source:** `tests/ahk/element_debug_ops.test.ahk`

### A stub that records a request before it does the work makes the test race

- **Problem:** A Python stand-in for storage appended the request to its list, then wrote the file. The test waited for the list entry and read the file at once, and got an empty file on a loaded machine (`JSONDecodeError` in `test_the_switched_state_survives_a_restart_of_the_engine`).
- **Wrong:** `self.state_writes.append(text)` followed by `target.write_text(text)` in the stub's handler, with a test that polls the list.
- **Right:** Do the work first, then record it, so that a test that sees the record also sees the effect. Check the stub for every request type the role sends: a request the stub does not answer waits for its deadline (here the engine would wait 30 s before it is ready).
- **Status:** verified (the failure in the run log of 20261016-210338-860; the fix is in `tests/integration/test_engine.py`)
- **Source:** `tests/integration/test_engine.py` (`StorageStub._handle`)


### Kill tests: subscribe before the kill and wait for the restart before the next pid

- **Problem:** Three mistakes in one set of fault tests: the observer subscribed to the topic `process` after the kill, so the `evt.process.crashed` never reached it; a second kill read the pid of the process list before the supervisor had restarted the child, and killed a dead process (`NoSuchProcess`); the snapshot of the engine was asked while the restarted engine was still loading the flows, which made the helper fail with "flow is not in the snapshot".
- **Wrong:** `kill(...)` followed by `wait_message(...)` with no subscription, a loop of kills without a wait for `evt.process.ready`, and a helper that raises when a flow is missing.
- **Right:** Subscribe to the topics right after the start. Wait for `evt.process.ready` of the child (and for `evt.engine.ready` of an engine) before the next pid is read. A helper that polls the engine returns "not yet" while the engine restarts.
- **Status:** verified (`tests/integration/test_trigger_arming.py`, the three fault tests green after the fix)
- **Source:** `tests/integration/test_trigger_arming.py` (`watch`, `wait_engine_ready`, `snapshot_flow`)

### A test double of an engine class must have the members that the real class adds

- **Problem:** `Executor` gained a call of `owner.arms.StartInfo` for every start. The test double `EngineOwner` did not have `arms`, so 127 unit tests of the executor failed with "has no property named arms". A second problem came with it: `Executor` named the class `TriggerArms` (defined in another file), which the scripts that include only `Executor.ahk` do not have ("This local variable appears to never be assigned").
- **Wrong:** Let a shared class call a member of its owner that only the real owner has, and name a class of a sibling file in a file that is included by test scripts without it.
- **Right:** Give the test double the same member (a stub that returns the neutral answer), and keep a shared helper in the class that uses it (`Executor.ErrorText`). Run the whole unit test set after a change of a shared class, not only the new test file.
- **Status:** verified (`python -m pytest tests/test_ahk_runner.py -q -n 0`: 127 red before the stub, 620 green after)
- **Source:** `tests/ahk/helpers/EngineOwner.ahk` (`NoArms`), `src/engine/Executor.ahk` (`ErrorText`, `_Start`)

### A timer trigger in an integration test needs the trigger host role

- **Problem:** A flow with `Trigger_Periodic_Timer` enabled in a session with the roles `storage,engine` never fired; its `evt.trigger.state` said `trigger host is not running`, so no instance started. The test looked like a guard bug at first.
- **Right:** Start the session with the trigger host as well (`roles="storage,engine,triggerhost"`, as `tests/integration/test_time_triggers.py` does with its `host_flows` fixture). Manual triggers need no host.
- **Status:** verified (the failing run of `test_a_flood_of_refused_starts_is_answered_and_logged_a_few_times`, then green with the host role)
- **Source:** `tests/integration/test_runaway.py`

### Unassigned keys for hotkey input tests: not every virtual key reaches a plain hotkey

- **Problem:** The input tests of `Trigger_Hotkey` (`tests/integration/test_hotkey_input.py`) all skipped: the probe key `vk9A`, sent with `SendInput`, never fired the plain hotkey `vk9A`. The same key fired with `$vk9A` or `~vk9A`, and a standalone listener showed it: plain `vk9A`, `vk9B`, `vk9C` stay silent, while `vk88` to `vk8F`, `vkD8` to `vkDA`, `vkE8`, `vk97` and F13 fire in every form. An earlier spike that mixed the forms looked like "sometimes it works". A plain hotkey also does not stop the key from reaching other keyboard hooks: only a hook hotkey (`$`) blocks it.
- **Wrong:** Pick the unassigned keys from one range without trying each form (plain, `~`, ` up`), and test "the key is blocked" with a plain hotkey.
- **Right:** Use `vk88` to `vk8F` and `vkE8`, and `$vkNN` where the test needs the block. Debug a silent hotkey first in a standalone script (`Hotkey()` plus the sender), then in the host: a log line in the callback shows whether the key arrived or the trigger path failed.
- **Status:** verified (10 input tests green in two serial runs; listener runs for the key list)
- **Source:** `tests/integration/test_hotkey_input.py`, `tests/support/inputlock.py`

### `loop files` takes a mode string, not a number

- **Problem:** `loop files, folder "\*", 2` (a number for directories only) failed at run time with "Parameter #2 invalid"; the storage role answered every request of the v1 listing with `internal`.
- **Wrong:** `loop files, dir "\*", 2`.
- **Right:** `loop files, dir "\*", "D"` and filter with `InStr(A_LoopFileAttrib, "D")`, so the loop takes both kinds and only the folders are used.
- **Status:** verified (WI-0076, tests/e2e/test_manager_import.py, the v1 listing of the statics)
- **Source:** WI-0076, src/storage/V1Source.ahk `List`.

### A closure over the variable of a `for` loop does not work in a test case

- **Problem:** `Assert.Throws(() => Check("workers", bad), AhfError)` inside `for bad in [...]` failed with "Class has no property Name" (the lambda threw an unset-variable error, which is not an `AhfError`, and `Assert.Throws` then fails while it builds its own message).
- **Wrong:** a fat-arrow function that uses the loop variable of the enclosing `for`.
- **Right:** Bind the value: `Assert.Throws(CheckOf.Bind("workers", bad), AhfError)` with `CheckOf(key, value) => SettingsModel.Check(key, value)`.
- **Status:** verified (WI-0077, tests/ahk/core_settings.test.ahk)
- **Source:** WI-0077, tests/ahk/core_settings.test.ahk.

### A window with real controls can be tested without showing it (verified)

- **Problem:** The settings dialog and the about window were to be tested without a user and without a visible window.
- **Wrong:** Building the windows in the end-to-end tests: they are headless, and the window code is not loaded there.
- **Right:** In an AHK unit test (`tests/ahk/*.test.ahk`, `#SingleInstance Off`) make the window (`UiWindow` makes a hidden `Gui`), read and set its controls (`ctl.Value`, `ctl.Text`), call the handler the button calls (`win.OnOk()`), and give the model a fake (a class with the same method name that records the call and answers at once). Never call `Show`; `win.Close()` in a `finally`. The controls of a window are not enumerable in AHK v2 without a list: keep the controls you test in a Map or an Array of the window (`this.lines`, `this.ctl`).
- **Status:** verified (tests/ahk/manager_settings_window.test.ahk, 7 cases pass; the same windows are shown only by the gui test, owner run).
- **Source:** WI-0078, tests/ahk/manager_settings_window.test.ahk.

### A session with N workers needs `--workers=N` and `--warm-workers=N`, and `--windows-startup` drops the manager (verified)

- **Problem:** A memory measurement with one and three workers, and with and without a manager, started sessions that did not have the processes the test expected.
- **Wrong:** `--workers=3` alone: the engine asks for the default number of warm workers (1) at the start, so only one worker process exists until flows need more. A `--start` list with `manager` plus `--windows-startup`, expecting a manager: the supervisor leaves the manager out of a start with Windows (E0064), without a message.
- **Right:** Pass both options for N living workers at once, and count the `--role=worker` processes before sampling (`tests/stress/test_background_memory.py` waits for them and asserts the count). For "no manager" use `--windows-startup` with the normal start list: the test then also checks the real start-with-Windows path. The roles `tray` and `manager` with `--headless` have no visible icon or window, so a stress run opens nothing; the window itself is measured only by a gui test.
- **Status:** verified (tests/stress/test_background_memory.py, 12 sessions).
- **Source:** WI-0082, `Supervisor.ahk` (`startList`), `Engine.ahk` (`--workers`, `--warm-workers`).

### SendMessage with a buffer of this process reads or writes the memory of the other process (gui tests, assumed)

- **Problem:** The gui test read the text of the editor's status bar with `SB_GETTEXTW` and a `create_unicode_buffer` of the test process. The editor then hung (no pong for 6 s) and ended as crashed: the status bar wrote the text into the address of the test's buffer, which is an arbitrary address in the editor's memory.
- **Wrong:** `user32.SendMessageW(status, SB_GETTEXTW, 0, ctypes.addressof(buf))` with a pointer of the caller's process, when `status` belongs to another process.
- **Right:** Allocate the buffer in the owner's process and read it back: `OpenProcess` (VM_OPERATION, VM_READ, VM_WRITE), `VirtualAllocEx`, `SendMessageW`, `ReadProcessMemory`, `VirtualFreeEx`, `CloseHandle`. Same rule for every message that takes a pointer (`WM_GETTEXT`, `SB_GETTEXT`, `LVM_GETITEMTEXT`, ...).
- **Status:** assumed (the cause is read in the code; the fixed gui test is not run by agents, the owner runs it)
- **Source:** `tests/fault/test_editor_mouse_gui.py` (`status_text`).

### A Gui window of AutoHotkey has the class AutoHotkeyGUI, not AutoHotkey (assumed)

- **Problem:** A gui test looked for the editor's window by its process and class `AutoHotkey` and found none, although the window was visible.
- **Wrong:** `cls == "AutoHotkey"`: that is the hidden main window of the script (used for the tray messages, `FindWindowW`).
- **Right:** The windows made by `Gui()` have the class `AutoHotkeyGUI`; filter by the process ID and this class, and check `IsWindowVisible`.
- **Status:** assumed (read in the code, not run; tests/fault/test_editor_tray_icon_gui.py uses the class `AutoHotkey` on purpose, for the tray message).
- **Source:** `tests/fault/test_editor_mouse_gui.py` (`_window_of_pid`).

### A window title with the flow name depends on the language and the case of the name (assumed)

- **Problem:** The editor window test searched the title "AutoHotFlow Editor - Skeleton" and never found it: the title is "AutoHotFlow <Editor> - <flow name>", with the flow ID `skeleton` in lower case and the word in the language of the test folder.
- **Wrong:** Comparing the whole title with a constant (the match is also case sensitive).
- **Right:** Match the start ("AutoHotFlow ") and the end (" - skeleton") of the title, and check the visible state.
- **Status:** assumed (the title code is read; the gui test is not run by agents).
- **Source:** `src/editor/EditorWindow.ahk` (`Refresh`), `tests/fault/test_editor_window.py`.

### `cmd.editor.open` is reserved for the manager: a gui test sends it as the manager (assumed)

- **Problem:** The editor gui tests sent `cmd.editor.open` through the observer connection and got `denied`, so no editor started.
- **Wrong:** `chain.obs.request("supervisor", "cmd.editor.open", ...)`.
- **Right:** `open_editor_as_manager(chain, flowId)` in `tests/fault/faultkit.py`: a short connection named `manager` sends the request once and closes. The e2e tests use the real manager (`tests/e2e/test_manager_editor.py`).
- **Status:** verified by reading `Supervisor.ahk` (`_OnEditor` refuses other senders); the fixed gui test is not run by agents.
- **Source:** `src/supervisor/Supervisor.ahk` (`_OnEditor`).

### AHK's FileAppend fails in a missing folder, and SplitPath needs backslashes (assumed)

- **Problem:** The renderer bench tool wrote its result to `temp/s5/renderer-window.txt` (given with slashes by the VS Code task). The folder did not exist in a fresh checkout, so the script ended with "Das System kann den angegebenen Pfad nicht finden" in a blocking dialog (caught by `ahkrun.py`, exit 97).
- **Wrong:** `SplitPath(args[1], , &dir)` with `C:/...` gives an empty folder, so no `DirCreate` happens; and `FileAppend` into a missing folder.
- **Right:** `resultFile := StrReplace(args[1], "/", "\")` before `SplitPath`, then `DirCreate(dir)`.
- **Status:** assumed (the dialog was reported by the owner; the fixed bench is not run by agents)
- **Source:** `tests/ahk/helpers/renderer_bench.ahk` (`Main`).

### The wire-bool rule also flags internal Maps with `"enabled", 1` (verified)

- **Problem:** `tools/arch_check.py` (rule `wire-bool`) matches the text `"enabled", 1` in any Map literal, also in an internal menu spec that never goes on the wire. The first version of `EditorMenus.ahk` failed the check for that.
- **Right:** Name an internal flag differently (here `allowed`), and write the wire key (`enabled`) only with `Json.Bool(...)`, which the rule accepts.
- **Status:** verified (`python tools/arch_check.py` before and after the rename, WI-0102)
- **Source:** `tools/arch_check.py`, `src/editor/EditorMenus.ahk`

### A pytest run started as `(... ) &` in a bash subshell stops with the tool call (verified)

- **Problem:** A long pytest run was started as `(timeout 1500 python -m pytest ... > out.txt; echo EXIT >> out.txt) &` in the Bash tool. The tool reported the job as completed after a few seconds, and `out.txt` held only the first lines of the run: the process had ended with the call.
- **Wrong:** Backgrounding inside the shell command with `&`.
- **Right:** Start the run with the tool's own `run_in_background` (the notification comes when it ends), and write its output to a file in the scratchpad (not `/tmp`). Read the file only after the notification.
- **Status:** verified (the output file of the first run held 66 bytes; the second run with `run_in_background` wrote the whole output).
- **Source:** WI-0104 (agent work in the workspace `wi-104`)

### tests/ahk/lib/Assert.ahk has no False check (verified)

- **Problem:** A unit test that called `Assert.False(...)` stopped with an error at the first case.
- **Wrong:** `Assert.False(FlowNotify.On(def, true))`
- **Right:** `Assert.True(!value, "message")` (the library has `Equal`, `True` and `Throws` only).
- **Status:** verified (tests/ahk/engine_flow_notify.test.ahk, tests/ahk/editor_flow_settings.test.ahk)
- **Source:** tests/ahk/lib/Assert.ahk (WI-0109)
