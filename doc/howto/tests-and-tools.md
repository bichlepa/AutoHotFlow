# How-to AHK v2: Tests and tools

Entries of this category. Entry format, rules and index: [`../HOW-TO.md`](../HOW-TO.md).

### Blocking error dialogs: `ahkrun.py` and the dialog watcher

- **Problem:** A load error, an unhandled run-time error or a `MsgBox` opens a dialog. The process waits for a click, and the calling agent hangs.
- **Wrong:** Starting the script directly with the interpreter and waiting for it to return.
- **Right:** `python tools/ahkrun.py --timeout 30 skript.ahk`. Load errors go to stderr (`/ErrorStdOut=UTF-8`). Other dialogs are detected by `tools/ahf_dialogwatch.py` (windows of class `#32770` in the process tree), their text and a PNG are saved under `%TEMP%\ahf_dialogs\`, the dialog is closed, and the process ends with exit code 97.
- **Status:** verified (`tests/support/test_dialogwatch.py`: load error, run-time error, `MsgBox`, timeout). Limits: only dialogs of class `#32770`.
- **Source:** `tools/ahkrun.py`, `tools/ahf_dialogwatch.py`

### ctypes: without `argtypes`, 64-bit handles fail intermittently

- **Problem:** The dialog watcher closed dialogs only sometimes. `GetDIBits` without `argtypes` received a handle as a C `int`; values above 2**31 raised `OverflowError`. The watcher thread swallowed the exception, and the dialog stayed open.
- **Wrong:** Calling WinAPI functions with handle parameters without `argtypes`/`restype`, and discarding exceptions in a watcher loop before the essential step is done.
- **Right:** Set `argtypes` and `restype` for every function called. Gather information in `try`; close and end in `finally`.
- **Status:** verified (20 consecutive runs, worst 0.58 s)
- **Source:** `tools/ahf_dialogwatch.py`

### The AHK interpreter does not know `--version`

- **Problem:** `AutoHotkey64.exe --version` opens the dialog "Script file not found. --version".
- **Right:** Do not query the version via the command line. In a script, output `A_AhkVersion`.
- **Status:** verified (self-triggered)

### Test processes write output to files, not pipes

- **Problem:** An AHK process started with `subprocess.PIPE` can keep the pipe open at a timeout, and then `communicate()` hangs too.
- **Right:** Redirect stdout and stderr to files in the data directory (`run_ahk` in `tests/conftest.py`). On `TimeoutExpired`, end the process tree with `psutil`.
- **Status:** verified (`test_hung_script_is_killed_at_timeout`; no `AutoHotkey64.exe` left over)

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

### Starting role processes via `ahkrun.py`, output in files

- **Problem:** A role test needs the role process next to a running hub. `ahkrun.py` waits until the end, and a pipe buffer for its output can block.
- **Right:** Start `ahkrun.py` as a child process (`procs.start`) with output in files and `--timeout 60`. The AutoHotkey PID is in `sys.hello` (`payload.pid`) and is a child of `ahkrun` (`psutil.Process(pid).ppid()`). The exit code of `ahkrun` is that of the script.
- **Status:** verified (`tests/integration/test_role.py`, 9 tests)
- **Source:** `tests/integration/test_role.py` (`RoleRun`)

### psutil status lags behind `suspend` by up to 73 ms

- **Problem:** After `psutil.Process.suspend()`, `status()` does not show `STATUS_STOPPED` at once. A single check right after stopping is unreliable.
- **Wrong:** Reading `status()` once after `suspend` and checking it immediately.
- **Right:** Poll the status every 10 ms until `STATUS_STOPPED`, with a deadline of 2 s.
- **Status:** verified (30 runs measured, delay up to 73 ms)
- **Source:** `tests/support/test_procs.py`

### `ahkrun.py` copies stderr only at the end: read logs after the end, wait for events

- **Problem:** While a role runs under `ahkrun.py`, its stderr and log files are empty. A test waiting for a log line hit its deadline, and right after the end an observer may not have the last event yet.
- **Wrong:** Looking into the output during the run to check the state.
- **Right:** Query the state via messages during the run (`cmd.process.list`, `sys.hello`). End the session, wait for the end, then read the log. Fetch events with `Recorder.wait(..., timeout=1)`, not with `find`.
- **Status:** verified (`tests/fault/test_pipe_break.py`, `tests/fault/test_shutdown.py`: `find` was too early once in 20 runs; 80 of 80 green with `wait`)
- **Source:** `tools/ahkrun.py`, `tests/integration/test_role.py`

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

### Python ctypes: use an own `WinDLL` object instead of `windll.user32`

- **Problem:** `EnumWindows` raised `ArgumentError: expected WinFunctionType instance`. Another module had set `argtypes` on the shared `windll.user32` with its own `WINFUNCTYPE` class; each call of `WINFUNCTYPE` creates a new class.
- **Right:** `user32 = ctypes.WinDLL("user32")`. Its functions are separate from those of `windll.user32`.
- **Status:** verified (`tests/fault/test_debug_role.py`)

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

### A local variable named like a built-in function or a class hides it, and a script without `#Warn` shows warnings as a dialog

- **Problem:** AutoHotkey v2 names are case-insensitive. A function that assigns a local `type` can no longer call `Type(e)`: the call fails with `This value of type "String" has no method named "Call"`. The same holds for a local `role` or `ids` against the classes `Role` and `Ids`. It shows only when the path that uses the hidden name runs, and the error handler is the usual such path (a `catch` block that builds a message with `Type(e)`). The warning type `LocalSameAsGlobal` finds it, but it is not part of the default; `#Warn All` switches it on. Second point, from F-0072: a script without a `#Warn` directive shows its warnings (`VarUnset` is on by default) in a MsgBox, which blocks until the dialog guard closes it; a file that uses a class from another file and is included alone is reported as "local variable never assigned".
- **Wrong:** `type := "cmd.engine.var." op` and, in the same function, `catch as e` with `Type(e)` in the message. A helper file that uses `Engine._ErrorText` without a note that it needs `Engine.ahk`.
- **Right:** Name the local after what it holds (`reqType`, `msgType`, `roleName`, `idList`); never a name of a built-in function or of a class, whatever the spelling. State in the header of a helper file which class it needs and through which file it is included. For a script of your own: `#Warn VarUnset, StdOut` (and `Unreachable`), so a warning is a text line in the output, not a dialog.
- **Status:** verified (2026-10-15: probe script with a local `type` and `Type(e)`; the test `worker: a request that cannot be sent gives an ElementError` was red before and green after the rename in `WorkerContext._Ask`)
- **Source:** `src/worker/WorkerContext.ahk`, `src/engine/vars/VarLoader.ahk`, `doc/OPEN-ITEMS.md` F-0078

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
