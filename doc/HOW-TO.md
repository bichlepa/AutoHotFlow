# How-to AHK v2 (knowledge base)

Collection of pitfalls, mistakes and solutions encountered while implementing in AutoHotkey v2. Meant as a help for agents and developers who work on the code after us.

If you notice a difficulty or a mistake of your own, record it here (see `AGENTS.md`, rule 9).

## Entry format

```markdown
### <short title>

- **Problem:** What went wrong or what was difficult.
- **Wrong:** The faulty approach or code (brief).
- **Right:** The working solution (brief, with a code example if needed).
- **Status:** verified (tested/read) | assumed | not checked
- **Source:** Doc link or file where it occurred (optional).
```

Entries live in the category files `doc/howto/<category>.md` (the category list is the index below). Append a new entry at the end of the matching category file, and add one index line to this file. Correct or delete outdated entries, do not duplicate them.

## Index

Each line links to an entry and shows its status (verified / assumed / not checked).

### Syntax and language

- [A lambda cannot contain `throw`](howto/syntax-and-language.md#a-lambda-cannot-contain-throw) (verified)
- [FileAppend writes a BOM for a new file; strip the BOM when reading](howto/syntax-and-language.md#fileappend-writes-a-bom-for-a-new-file-strip-the-bom-when-reading) (partly verified)
- [`#Include` is relative to the including file](howto/syntax-and-language.md#include-is-relative-to-the-including-file) (verified)
- [A static method used as a callback shifts the parameters](howto/syntax-and-language.md#a-static-method-used-as-a-callback-shifts-the-parameters) (verified)
- [Backslash is not an escape character in AHK v2](howto/syntax-and-language.md#backslash-is-not-an-escape-character-in-ahk-v2) (verified)
- [`<` compares strings numerically, `Sort` sorts only text](howto/syntax-and-language.md#-compares-strings-numerically-sort-sorts-only-text) (verified)
- [`=` and `!=` compare strings case-insensitively](howto/syntax-and-language.md#-and--compare-strings-case-insensitively) (verified)
- [Float as text: precision and form](howto/syntax-and-language.md#float-as-text-precision-and-form) (partly verified)
- [Nested class with a static singleton](howto/syntax-and-language.md#nested-class-with-a-static-singleton) (verified)
- [Performance: calls per character are expensive](howto/syntax-and-language.md#performance-calls-per-character-are-expensive) (verified)
- [Reserved word `loop` must not be used as a variable name](howto/syntax-and-language.md#reserved-word-loop-must-not-be-used-as-a-variable-name) (verified)
- [Truth values are the integers 1 and 0](howto/syntax-and-language.md#truth-values-are-the-integers-1-and-0) (verified)
- [Local variable with the name of a class shadows the class](howto/syntax-and-language.md#local-variable-with-the-name-of-a-class-shadows-the-class) (verified)
- [Function in a property: calling with a dot passes the class as the first argument](howto/syntax-and-language.md#function-in-a-property-calling-with-a-dot-passes-the-class-as-the-first-argument) (partly verified)
- [Field and method with the same name](howto/syntax-and-language.md#field-and-method-with-the-same-name) (verified)
- [`Json.False` is true in AHK](howto/syntax-and-language.md#jsonfalse-is-true-in-ahk) (verified)
- [`Round(x, 1)` returns a string](howto/syntax-and-language.md#roundx-1-returns-a-string) (verified)
- [`===` does not exist; `ObjPtr("")` throws](howto/syntax-and-language.md#-does-not-exist-objptr-throws) (verified)
- [Class used from a file that is not included: load-time dialog](howto/syntax-and-language.md#class-used-from-a-file-that-is-not-included-load-time-dialog) (verified)
- [Do not override built-in AHK v2 class names](howto/syntax-and-language.md#do-not-override-built-in-ahk-v2-class-names) (partly verified)
- [Code at file level runs at load time, before `AhfMain` and before any `OnError`](howto/syntax-and-language.md#code-at-file-level-runs-at-load-time-before-ahfmain-and-before-any-onerror) (partly verified)
- [32-bit interpreter: check `A_PtrSize` before anything else](howto/syntax-and-language.md#32-bit-interpreter-check-a_ptrsize-before-anything-else) (verified)
- [A closure without a captured variable is always the same function object](howto/syntax-and-language.md#a-closure-without-a-captured-variable-is-always-the-same-function-object) (verified)
- [A space before `;` inside a string literal starts a comment](howto/syntax-and-language.md#a-space-before--inside-a-string-literal-starts-a-comment) (verified)
- [Call stack overflow ends the whole process](howto/syntax-and-language.md#call-stack-overflow-ends-the-whole-process) (verified)
- [PCRE in AHK: characters above U+FFFF and a start position inside a surrogate pair](howto/syntax-and-language.md#pcre-in-ahk-characters-above-uffff-and-a-start-position-inside-a-surrogate-pair) (verified)
- [`Integer("12345678901234567890")` wraps around](howto/syntax-and-language.md#integer12345678901234567890-wraps-around) (verified)
- [`MinInt // -1` and `Mod(MinInt, -1)` end the whole process](howto/syntax-and-language.md#minint---1-and-modminint--1-end-the-whole-process) (verified)
- [A property and a method that differ only in case are the same name](howto/syntax-and-language.md#a-property-and-a-method-that-differ-only-in-case-are-the-same-name) (verified)
- [A semicolon after whitespace starts a comment even inside a string in the source](howto/syntax-and-language.md#a-semicolon-after-whitespace-starts-a-comment-even-inside-a-string-in-the-source) (verified)
- [Comparing two characters with `>=` or `<=` throws a TypeError](howto/syntax-and-language.md#comparing-two-characters-with--or--throws-a-typeerror) (verified)
- [A local variable has the name of a function or class: `lines`, `log`](howto/syntax-and-language.md#a-local-variable-has-the-name-of-a-function-or-class-lines-log) (verified)
- [`String(0.1)` is `0.10000000000000001`: a decimal literal rarely reads back as it was written](howto/syntax-and-language.md#string01-is-010000000000000001-a-decimal-literal-rarely-reads-back-as-it-was-written) (verified)
- [A backtick before an apostrophe in a single-quoted AHK string is an escape](howto/syntax-and-language.md#a-backtick-before-an-apostrophe-in-a-single-quoted-ahk-string-is-an-escape) (verified)
- [`StrSplit("", ".")` gives an empty Array, not `[""]`](howto/syntax-and-language.md#strsplit--gives-an-empty-array-not-) (verified)
- [`IsNumber` of AutoHotkey v2 is not v1 `is number`: `"1e3"`](howto/syntax-and-language.md#isnumber-of-autohotkey-v2-is-not-v1-is-number-1e3) (verified)
- [A nested class has no global name: inside an element class use `this`](howto/syntax-and-language.md#a-nested-class-has-no-global-name-inside-an-element-class-use-this) (verified)
- [`#Include` inside a class body: a file is included only once, so include it before the class](howto/syntax-and-language.md#include-inside-a-class-body-a-file-is-included-only-once-so-include-it-before-the-class) (verified)
- [A package class is a global name: a local variable `default` shadows `Default`](howto/syntax-and-language.md#a-package-class-is-a-global-name-a-local-variable-default-shadows-default) (verified)
- [A static property and a nested class share one namespace, ignoring case](howto/syntax-and-language.md#a-static-property-and-a-nested-class-share-one-namespace-ignoring-case) (verified)
- [`IsDigit`, `IsAlpha` and the like need a String: an Integer is a TypeError](howto/syntax-and-language.md#isdigit-isalpha-and-the-like-need-a-string-an-integer-is-a-typeerror) (verified)
- [`StrSplit(text, "ab")` has ONE delimiter of two characters](howto/syntax-and-language.md#strsplittext-ab-has-one-delimiter-of-two-characters) (verified)
- [A parameter named `random` hides the function `Random` (names ignore case)](howto/syntax-and-language.md#a-parameter-named-random-hides-the-function-random-names-ignore-case) (verified)
- [A multi-statement function in an argument is `() {` ... `}`, not `() => {`](howto/syntax-and-language.md#a-multi-statement-function-in-an-argument-is-----not---) (verified)
- [A helper function of a test file is a global name: `Owner()` turns every local `owner` into a warning](howto/syntax-and-language.md#a-helper-function-of-a-test-file-is-a-global-name-owner-turns-every-local-owner-into-a-warning) (verified)

### Objects, Maps, Arrays

- [Map with `CaseSense "Off"` keeps the spelling of the first insertion](howto/objects-maps-arrays.md#map-with-casesense-off-keeps-the-spelling-of-the-first-insertion) (verified)
- [Copy keys into an array before deleting from a Map](howto/objects-maps-arrays.md#copy-keys-into-an-array-before-deleting-from-a-map) (not checked)
- [Static method `Name()` shadows the `.Name` property of a class](howto/objects-maps-arrays.md#static-method-name-shadows-the-name-property-of-a-class) (verified)
- [`static __New()` sets the key spelling of a static Map](howto/objects-maps-arrays.md#static-__new-sets-the-key-spelling-of-a-static-map) (verified)
- [Callback with state: `ObjBindMethod` instead of a lambda in a loop](howto/objects-maps-arrays.md#callback-with-state-objbindmethod-instead-of-a-lambda-in-a-loop) (verified)
- [Parameter of an element as an object with property access](howto/objects-maps-arrays.md#parameter-of-an-element-as-an-object-with-property-access) (partly verified)
- [Clone only after the change: the clone inherits it](howto/objects-maps-arrays.md#clone-only-after-the-change-the-clone-inherits-it) (verified)
- [A Map orders by keys, not by insertion: FIFO needs an array](howto/objects-maps-arrays.md#a-map-orders-by-keys-not-by-insertion-fifo-needs-an-array) (partly verified)
- [`Map.Delete` on a missing key throws](howto/objects-maps-arrays.md#mapdelete-on-a-missing-key-throws) (verified)
- [A subclass method silently replaces a same-named base class method](howto/objects-maps-arrays.md#a-subclass-method-silently-replaces-a-same-named-base-class-method) (verified)
- [`Json.Parse` returns `true` as 1, not as `Json.True`](howto/objects-maps-arrays.md#jsonparse-returns-true-as-1-not-as-jsontrue) (verified)
- [A Map key `1` and `"1"` are two keys; Integer keys come before texts](howto/objects-maps-arrays.md#a-map-key-1-and-1-are-two-keys-integer-keys-come-before-texts) (verified)
- [A function stored in an object that it holds is a reference cycle](howto/objects-maps-arrays.md#a-function-stored-in-an-object-that-it-holds-is-a-reference-cycle) (assumed)

### Error handling

- [A static class method is not a callback (`OnError`, `SetTimer`)](howto/error-handling.md#a-static-class-method-is-not-a-callback-onerror-settimer) (verified)
- [A script without a summary line ends with exit code 0](howto/error-handling.md#a-script-without-a-summary-line-ends-with-exit-code-0) (verified)
- [A callback that throws does not abort the state machine](howto/error-handling.md#a-callback-that-throws-does-not-abort-the-state-machine) (verified)
- [`OnError` handler: return 1 keeps the process alive](howto/error-handling.md#onerror-handler-return-1-keeps-the-process-alive) (verified)
- [Console output is best effort and must not block shutdown](howto/error-handling.md#console-output-is-best-effort-and-must-not-block-shutdown) (verified)
- [`FileAppend` to `**` writes to stderr without creating a file](howto/error-handling.md#fileappend-to--writes-to-stderr-without-creating-a-file) (verified)

### Processes, pipes, messages

- [Pipe reads and writes in parallel only with overlapped I/O](howto/processes-pipes-messages.md#pipe-reads-and-writes-in-parallel-only-with-overlapped-io) (partly verified)
- [`PostMessageW` with a NULL handle reports success](howto/processes-pipes-messages.md#postmessagew-with-a-null-handle-reports-success) (verified)
- [Overlapped structure: fields with ctypes](howto/processes-pipes-messages.md#overlapped-structure-fields-with-ctypes) (verified)
- [AHK overlapped pipe I/O with DllCall (pattern that works)](howto/processes-pipes-messages.md#ahk-overlapped-pipe-io-with-dllcall-pattern-that-works) (verified)
- [The wake-up call covers writing only; a follow-up timer drains the queue](howto/processes-pipes-messages.md#the-wake-up-call-covers-writing-only-a-follow-up-timer-drains-the-queue) (partly verified)
- [Re-entry: Pump, SendFrame and handlers interrupt each other](howto/processes-pipes-messages.md#re-entry-pump-sendframe-and-handlers-interrupt-each-other) (partly verified)
- [Handler return: only an empty value counts as "no result"](howto/processes-pipes-messages.md#handler-return-only-an-empty-value-counts-as-no-result) (verified)
- [Connection setup without blocking: one attempt, retry via timer](howto/processes-pipes-messages.md#connection-setup-without-blocking-one-attempt-retry-via-timer) (verified)
- [One timer per request, switched off on reply](howto/processes-pipes-messages.md#one-timer-per-request-switched-off-on-reply) (verified)
- [`sys.shutdown`: do not close the connection inside the frame handler](howto/processes-pipes-messages.md#sysshutdown-do-not-close-the-connection-inside-the-frame-handler) (verified)
- [Orphan guard: measure the deadline in its own timer](howto/processes-pipes-messages.md#orphan-guard-measure-the-deadline-in-its-own-timer) (verified)
- [Events before a subscription are lost: subscribe first, then take a snapshot](howto/processes-pipes-messages.md#events-before-a-subscription-are-lost-subscribe-first-then-take-a-snapshot) (verified)
- [`Hub.Request`: the message must carry the registered ID](howto/processes-pipes-messages.md#hubrequest-the-message-must-carry-the-registered-id) (verified)
- [Worker: reply first, start the element via timer](howto/processes-pipes-messages.md#worker-reply-first-start-the-element-via-timer) (verified)
- [`DllCall("Sleep")` in a loop: messages are handled between slices](howto/processes-pipes-messages.md#dllcallsleep-in-a-loop-messages-are-handled-between-slices) (partly verified)
- [`cmd` reply later: return `Deferred.Marker()` and reply with `Peer.Reply`](howto/processes-pipes-messages.md#cmd-reply-later-return-deferredmarker-and-reply-with-peerreply) (verified)
- [Atomic replace: `MoveFileExW` with flags, and flush before the rename](howto/processes-pipes-messages.md#atomic-replace-movefileexw-with-flags-and-flush-before-the-rename) (partly verified)
- [Time values are per process: `Time.NowMs` is not comparable across processes](howto/processes-pipes-messages.md#time-values-are-per-process-timenowms-is-not-comparable-across-processes) (verified)
- [Log lines are lost when another process has the file open (sharing violation)](howto/processes-pipes-messages.md#log-lines-are-lost-when-another-process-has-the-file-open-sharing-violation) (verified)
- [Reference cycle via `ObjBindMethod(this, ...)` in a field keeps closed connections alive](howto/processes-pipes-messages.md#reference-cycle-via-objbindmethodthis--in-a-field-keeps-closed-connections-alive) (partly verified)
- [Log writes: batch the operations; one operation per timer run is too slow](howto/processes-pipes-messages.md#log-writes-batch-the-operations-one-operation-per-timer-run-is-too-slow) (verified)
- [Check whether a PID is still alive with `OpenProcess`](howto/processes-pipes-messages.md#check-whether-a-pid-is-still-alive-with-openprocess) (partly verified)
- [Heartbeat: after a standstill of the supervisor all children look hung](howto/processes-pipes-messages.md#heartbeat-after-a-standstill-of-the-supervisor-all-children-look-hung) (partly verified)
- [Pipe names are machine-wide, mutexes are per Windows session](howto/processes-pipes-messages.md#pipe-names-are-machine-wide-mutexes-are-per-windows-session) (partly verified)
- [`CreateProcessW` with redirected handles instead of `Run`](howto/processes-pipes-messages.md#createprocessw-with-redirected-handles-instead-of-run) (verified)
- [Read the header of a JSON frame with one regex; check the payload only for balance](howto/processes-pipes-messages.md#read-the-header-of-a-json-frame-with-one-regex-check-the-payload-only-for-balance) (partly verified)
- [Set a child's state before `CreateProcessW`, not after](howto/processes-pipes-messages.md#set-a-childs-state-before-createprocessw-not-after) (verified)
- [Own process data via DllCall: memory, handles and run time](howto/processes-pipes-messages.md#own-process-data-via-dllcall-memory-handles-and-run-time) (verified)
- [Close discards the send queue: wait until the queue is flushed](howto/processes-pipes-messages.md#close-discards-the-send-queue-wait-until-the-queue-is-flushed) (partly verified)
- [A re-entry lock makes "pump first" ineffective](howto/processes-pipes-messages.md#a-re-entry-lock-makes-pump-first-ineffective) (partly verified)
- [A write error to a departed peer must not discard its unread frames](howto/processes-pipes-messages.md#a-write-error-to-a-departed-peer-must-not-discard-its-unread-frames) (partly verified)
- [A message sent only once does not reach a child that connects later](howto/processes-pipes-messages.md#a-message-sent-only-once-does-not-reach-a-child-that-connects-later) (verified)
- [A router must know which requests are open](howto/processes-pipes-messages.md#a-router-must-know-which-requests-are-open) (verified)
- [Deadlines via `SetTimer` do not survive a standstill: check them in the tick](howto/processes-pipes-messages.md#deadlines-via-settimer-do-not-survive-a-standstill-check-them-in-the-tick) (verified)
- [Do not relabel a process that has already ended](howto/processes-pipes-messages.md#do-not-relabel-a-process-that-has-already-ended) (verified)
- [Assign a sequence number and send it under `Critical`](howto/processes-pipes-messages.md#assign-a-sequence-number-and-send-it-under-critical) (verified)
- [Publish a state only after its fields, under `Critical`](howto/processes-pipes-messages.md#publish-a-state-only-after-its-fields-under-critical) (partly verified)
- [Waiting for a message: `Sleep(1)` returns only at the next tick of the system timer](howto/processes-pipes-messages.md#waiting-for-a-message-sleep1-returns-only-at-the-next-tick-of-the-system-timer) (verified)
- [A blocking wait inside a callback of the peer waits for nothing](howto/processes-pipes-messages.md#a-blocking-wait-inside-a-callback-of-the-peer-waits-for-nothing) (assumed)
- [The end of a called instance goes to the caller in the next tick, not from the step that ended it](howto/processes-pipes-messages.md#the-end-of-a-called-instance-goes-to-the-caller-in-the-next-tick-not-from-the-step-that-ended-it) (verified)

### GUI and hotkeys

- [ListView: row clicks and selection after a rebuild](howto/gui-and-hotkeys.md#listview-row-clicks-and-selection-after-a-rebuild) (assumed)
- [Closing a Gui window does not end a role (`Persistent`)](howto/gui-and-hotkeys.md#closing-a-gui-window-does-not-end-a-role-persistent) (verified)
- [Capture and operate a window of an AHK role without screen access](howto/gui-and-hotkeys.md#capture-and-operate-a-window-of-an-ahk-role-without-screen-access) (verified)
- [InputBox and MsgBox are standard dialogs (window class `#32770`)](howto/gui-and-hotkeys.md#inputbox-and-msgbox-are-standard-dialogs-window-class-32770) (verified)

### Tests and tools

- [Blocking error dialogs: `ahkrun.py` and the dialog watcher](howto/tests-and-tools.md#blocking-error-dialogs-ahkrunpy-and-the-dialog-watcher) (verified)
- [ctypes: without `argtypes`, 64-bit handles fail intermittently](howto/tests-and-tools.md#ctypes-without-argtypes-64-bit-handles-fail-intermittently) (verified)
- [The AHK interpreter does not know `--version`](howto/tests-and-tools.md#the-ahk-interpreter-does-not-know---version) (verified)
- [Test processes write output to files, not pipes](howto/tests-and-tools.md#test-processes-write-output-to-files-not-pipes) (verified)
- [Raw strings cannot end with a backslash (pipe names)](howto/tests-and-tools.md#raw-strings-cannot-end-with-a-backslash-pipe-names) (verified)
- [Result file of a test helper: Python and AHK access at the same time](howto/tests-and-tools.md#result-file-of-a-test-helper-python-and-ahk-access-at-the-same-time) (verified)
- [Python test reader lost bytes when a read was cancelled](howto/tests-and-tools.md#python-test-reader-lost-bytes-when-a-read-was-cancelled) (verified)
- [Test server in Python: the return of the handler closes the connection](howto/tests-and-tools.md#test-server-in-python-the-return-of-the-handler-closes-the-connection) (verified)
- [Starting role processes via `ahkrun.py`, output in files](howto/tests-and-tools.md#starting-role-processes-via-ahkrunpy-output-in-files) (verified)
- [psutil status lags behind `suspend` by up to 73 ms](howto/tests-and-tools.md#psutil-status-lags-behind-suspend-by-up-to-73-ms) (verified)
- [`ahkrun.py` copies stderr only at the end: read logs after the end, wait for events](howto/tests-and-tools.md#ahkrunpy-copies-stderr-only-at-the-end-read-logs-after-the-end-wait-for-events) (verified)
- [A `conftest.py` in a subfolder shadows `tests/conftest.py` for `from conftest import ...`](howto/tests-and-tools.md#a-conftestpy-in-a-subfolder-shadows-testsconftestpy-for-from-conftest-import-) (verified)
- [A test that counts operations must set `Critical` or avoid `Sleep`](howto/tests-and-tools.md#a-test-that-counts-operations-must-set-critical-or-avoid-sleep) (verified)
- [Python client: `events(timeout)` ends only after silence](howto/tests-and-tools.md#python-client-eventstimeout-ends-only-after-silence) (verified)
- [Parallel test runs (pytest-xdist): add `#SingleInstance Off` to test scripts](howto/tests-and-tools.md#parallel-test-runs-pytest-xdist-add-singleinstance-off-to-test-scripts) (verified)
- [Static checks of AHK source with regex: strip strings carefully and test every rule](howto/tests-and-tools.md#static-checks-of-ahk-source-with-regex-strip-strings-carefully-and-test-every-rule) (verified)
- [AHK unit test: change static constants at runtime and reset them](howto/tests-and-tools.md#ahk-unit-test-change-static-constants-at-runtime-and-reset-them) (verified)
- [Python ctypes: use an own `WinDLL` object instead of `windll.user32`](howto/tests-and-tools.md#python-ctypes-use-an-own-windll-object-instead-of-windlluser32) (verified)
- [A fixed pause before an abort is a race](howto/tests-and-tools.md#a-fixed-pause-before-an-abort-is-a-race) (verified)
- [Test-only start delay without a product option](howto/tests-and-tools.md#test-only-start-delay-without-a-product-option) (verified)
- [`with WakingHub(...).start()` starts the hub twice](howto/tests-and-tools.md#with-wakinghubstart-starts-the-hub-twice) (assumed)
- [Python client: `sys.pong` is a reply, not an event](howto/tests-and-tools.md#python-client-syspong-is-a-reply-not-an-event) (verified)
- [A wait loop over `events()` discards foreign messages](howto/tests-and-tools.md#a-wait-loop-over-events-discards-foreign-messages) (verified)
- [A frozen process with `psutil.suspend()`: ack timeout and orphan deadline](howto/tests-and-tools.md#a-frozen-process-with-psutilsuspend-ack-timeout-and-orphan-deadline) (verified)
- [Force an interruption in a test with a hook in a stub](howto/tests-and-tools.md#force-an-interruption-in-a-test-with-a-hook-in-a-stub) (verified)
- [The v1 interpreter does not understand `/ErrorStdOut=UTF-8`](howto/tests-and-tools.md#the-v1-interpreter-does-not-understand-errorstdoututf-8) (verified)
- [v1: a `try` block turns failing commands into exceptions, also inside called functions](howto/tests-and-tools.md#v1-a-try-block-turns-failing-commands-into-exceptions-also-inside-called-functions) (verified)
- [v1: returning a variable from a function turns a number into text](howto/tests-and-tools.md#v1-returning-a-variable-from-a-function-turns-a-number-into-text) (verified)
- [v1: `global` outside a function makes a super-global; included files run in include order](howto/tests-and-tools.md#v1-global-outside-a-function-makes-a-super-global-included-files-run-in-include-order) (verified)
- [v1: a hanging case needs a watchdog timer, and a folder reset costs 0.4 s](howto/tests-and-tools.md#v1-a-hanging-case-needs-a-watchdog-timer-and-a-folder-reset-costs-04-s) (verified)
- [Bash tool: `( ... ) &` kept running after the call](howto/tests-and-tools.md#bash-tool-----kept-running-after-the-call) (not checked)
- [`Json.Parse` refuses a repeated key; the golden case files have some](howto/tests-and-tools.md#jsonparse-refuses-a-repeated-key-the-golden-case-files-have-some) (verified)
- [Patching files with a Python script: a backslash and an n in the replacement become a line break](howto/tests-and-tools.md#patching-files-with-a-python-script-a-backslash-and-an-n-in-the-replacement-become-a-line-break) (verified)
- [An error in the constructor of a role shows only as exit 2 "bad arguments"](howto/tests-and-tools.md#an-error-in-the-constructor-of-a-role-shows-only-as-exit-2-bad-arguments) (verified)
- [`FileRead(path, "UTF-8")` still reads a UTF-16 file with BOM](howto/tests-and-tools.md#filereadpath-utf-8-still-reads-a-utf-16-file-with-bom) (verified)
- [The flows of the engine are loaded before its variables: wait for `evt.engine.ready`](howto/tests-and-tools.md#the-flows-of-the-engine-are-loaded-before-its-variables-wait-for-evtengineready) (verified)
- [Generated AHK v2 code: some mistakes stop the whole script at load time, one case can end the process](howto/tests-and-tools.md#generated-ahk-v2-code-some-mistakes-stop-the-whole-script-at-load-time-one-case-can-end-the-process) (verified)
- [A local variable named like a built-in function or a class hides it, and a script without `#Warn` shows warnings as a dialog](howto/tests-and-tools.md#a-local-variable-named-like-a-built-in-function-or-a-class-hides-it-and-a-script-without-warn-shows-warnings-as-a-dialog) (verified)
- [A role that holds element classes needs `Lang()`, and a relative `#Include` is relative to the including file](howto/tests-and-tools.md#a-role-that-holds-element-classes-needs-lang-and-a-relative-include-is-relative-to-the-including-file) (verified)
- [A timer thread can run between "check" and "use" of a shared Map entry](howto/tests-and-tools.md#a-timer-thread-can-run-between-check-and-use-of-a-shared-map-entry) (verified)
- [`FlowRun.probe` reads the files when it is called: the next run clears them](howto/tests-and-tools.md#flowrunprobe-reads-the-files-when-it-is-called-the-next-run-clears-them) (verified)
- [`psutil.cpu_percent(interval=None)` keeps its reference point per thread](howto/tests-and-tools.md#psutilcpu_percentintervalnone-keeps-its-reference-point-per-thread) (verified)
- [CPU of a process tree including the processes that already ended: a job object](howto/tests-and-tools.md#cpu-of-a-process-tree-including-the-processes-that-already-ended-a-job-object) (partly verified)
- [The log of a flow is not in execution order across elements](howto/tests-and-tools.md#the-log-of-a-flow-is-not-in-execution-order-across-elements) (verified)
- [Two flows or two elements whose IDs differ only in case](howto/tests-and-tools.md#two-flows-or-two-elements-whose-ids-differ-only-in-case) (verified)
- [`ctx.GetVar` with a path and a default object: read one member, tell "missing" from "empty"](howto/tests-and-tools.md#ctxgetvar-with-a-path-and-a-default-object-read-one-member-tell-missing-from-empty) (verified)
- [`Loop Parse` with the delimiter text "CSV" is the CSV mode](howto/tests-and-tools.md#loop-parse-with-the-delimiter-text-csv-is-the-csv-mode) (verified)
