# How-to AHK v2: Error handling

Entries of this category. Entry format, rules and index: [`../HOW-TO.md`](../HOW-TO.md).

### A script without a summary line ends with exit code 0

- **Problem:** A script that ends before `TestRun.Finish()` (e.g. after a silent load error) returns exit code 0 and no summary. The exit code alone does not reveal the error.
- **Right:** The test runner requires the summary line in addition to exit code 0.
- **Status:** verified (`test_script_without_finish_has_no_summary`)


### A callback that throws does not abort the state machine

- **Problem:** The `onInvalid` callback of a state machine can itself throw. Uncaught, the error would abort the transition in the middle.
- **Right:** Call the callback in `try/catch`, log the error, and still return `false` (`ThreadState.ReportInvalid`).
- **Status:** verified (test "a throwing callback is logged, not raised" in `tests/ahk/engine_states.test.ahk`)
- **Source:** `src/engine/core/ThreadState.ahk`


### `OnError` handler: return 1 keeps the process alive

- **Problem:** An error in a timer must not end a role, and the standard dialog must not appear.
- **Right:** The handler returns `1`: the error counts as handled, no dialog appears, and the process keeps running. The second parameter `mode` tells the kind of error: `"Return"`, `"Exit"` (how an error from a timer arrives) or `"ExitApp"`. `Role._OnUnexpected` counts errors and calls `ExitApp(6)` when the threshold is exceeded.
- **Status:** verified for `"Exit"` (test `test_error_in_a_timer_is_logged_and_the_role_keeps_running`). Return values other than 1, and the modes `"Return"` and `"ExitApp"`, were not tested individually.
- **Source:** `src/core/Role.ahk`


### Console output is best effort and must not block shutdown

- **Problem:** Role processes started by a supervisor have no usable stderr. `FileAppend(text, "**")` throws `OSError (6)` there. In `Role._Exit` the exception skipped `ExitApp`, so after a hard kill of the supervisor all children kept running.
- **Wrong:** Testing the orphan case only with a Python hub and a role started via `ahkrun.py`, where stderr is valid.
- **Right:** Wrap console writes in `try/catch`. Before every `ExitApp` in the shutdown path, call nothing that can throw, or catch it. Test the orphan case with the real supervisor.
- **Status:** verified (error seen with `AHF_TEST_KEEP=1` in `Log_role.txt`; after the fix exit 4 after 3.3 s, 20 of 20 runs)
- **Source:** `src/core/Role.ahk` (`Console`, `_Exit`), `tests/fault/test_orphans.py`


### `FileAppend` to `**` writes to stderr without creating a file

- **Problem:** The entry point has no log sink yet, but messages like "unknown role" must be visible without a dialog.
- **Right:** `FileAppend(text, "**", "UTF-8-RAW")` writes to stderr and creates no file. This is the exception that the convention in `doc/CONVENTIONS.md` section 3 allows for stderr.
- **Status:** verified (`test_unknown_role_exits_2_with_message_and_no_dialog`)
- **Source:** `src/core/Role.ahk` (`Role.Console`)

### A timer chain that throws must schedule its next round first

- **Problem:** A repeating trigger is a chain of one-shot timers: each callback schedules the next one. If the callback throws before it schedules the next round, the chain ends, and the trigger looks armed but never fires again.
- **Right:** Schedule the next round first, then do the work that may throw. The trigger host runs the callback under try/catch and reports the error (`evt.trigger.error`), and the chain goes on.
- **Status:** verified for the order that works (`test_a_throwing_callback_is_reported_and_the_trigger_stays_armed`: the rounds 1 and 2 are reported); the chain that ends without the reschedule is assumed, not tested
- **Source:** `tests/elements/Test/Triggers/Trigger_TestCallbackThrows.ahk`, `src/triggerhost/TriggerContext.ahk`

### A copy of the variables of an error must be taken where the error is caught, and it must be text

- **Problem:** The variables of a branch are objects (Maps) that the branch keeps changing. A reference kept to them shows the state at the time of the look, not of the error, and a loop that is left with an exception pops its variables.
- **Wrong:** Storing `thread.Vars` (or `thread.Loops.Visible`) of the failed thread and reading it later, from the window. The thread is removed and the instance goes on, so the values change under the reader.
- **Right:** Take the copy at the moment of the error, in the branch that handles the unhandled result (`Executor._Advance`), and turn every value into text there (`VarJson.Stringify` for objects, cut to a fixed length). Nothing is taken on the normal path. The loop stack is not popped in the unhandled path (`Scheduler.Advance` returns before the pop), so the loop variables are still there.
- **Status:** verified (`tests/integration/test_error_window.py::test_an_unhandled_error_keeps_the_variables_of_its_branch`, and the unit `tests/ahk/engine_error_snapshot.test.ahk`)
- **Source:** `src/engine/core/ErrorSnapshot.ahk`, `src/engine/Executor.ahk` (`_Advance`)

### A repeated error of the same flow within 10 s sends no notice at once

- **Problem:** A test starts the same failing flow twice and waits for the second notice; the notice does not come within a few seconds.
- **Wrong:** Expecting one notice per error. The throttle (`NoticeThrottle`, 10 s per kind and flow) holds the second one back and sends it with the count after the window.
- **Right:** Use another flow for the second error when the test needs its notice at once, or wait for the count (`held`) and check the newest `errorId`, which the held notice carries.
- **Status:** verified (`tests/integration/test_error_window.py`, the first version of the follow test timed out this way)
- **Source:** `src/core/NoticeThrottle.ahk`, `src/engine/Engine.ahk` (`_Notice`)
