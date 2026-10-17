# Conventions for the v2 code

Applies to everything under `src/`, `tests/ahk/` and `tools/`. Language of the documentation and of the code (comments, names, log texts outside `Lang()`): English.

## 1. Files and structure

- Every AHK file starts with `#Requires AutoHotkey v2.0`. Role entry points additionally use `#SingleInstance Off` (several instances of the same file are intended) and, in development mode, `#Warn All`.
- **One class per file**, file name = class name (`Dispatcher.ahk`). Several free functions only in `Util` files.
- **No global variables.** State lives in classes or as `static` members. Exceptions (the entry point's `A_Args` parsing, the registry singleton) are in `AutoHotFlow.ahk` and the role module respectively.
- Includes only according to the rules in ARCHITECTURE 8 (`core/` knows no roles, roles do not know each other).
- **Role entries (E0041, D0012):** a role entry script (`src/entry/<role>.ahk`, `src/AutoHotFlow.ahk`) includes only `AhfBoot.ahk`, the code of its own role and its generated element block (`generated/Elements_<role>.ahk`), registers its own role in `RoleRegistry`, and then calls `AhfMain()`. It never includes a class file directly.
- **Element packages (E0037, E0045, WI-0047, doc/ELEMENT-API-V2.md section 2):** an element file is `src/elements/<package>/<Actions|Conditions|Loops|Triggers>/<class>.ahk` (test elements: `tests/elements/<package>/`, never in `src/`). It holds one class and comments, nothing else at file level: no `ElementRegistry.Register` line (the generated block of the package registers the class), and inside the class the class is `this`, never its own name (the class is nested in the package class and has no global name). A class file does not include another class file (F-0081): shared code goes into `lib/` of the package or `src/elements/base/` (files without a `Mode` line). `static Mode` of an element class is a **string literal** (`"inline"`, `"worker"` or `"trigger"`), because the generator reads it as text. A package name is a safe AutoHotkey class name (ELEMENT-API-V2 section 2). The generated blocks (`<package>/_includes_<role>.ahk`, `src/entry/generated/`) are written by `python tools/gen_element_includes.py` and committed; **never edit them by hand**, and never resolve a merge conflict in them by hand: generate them again. `tools/gen_element_includes.py` refuses a file that breaks one of these rules, and `tests/test_element_includes.py` fails when a block is stale.
- Encoding: UTF-8 without BOM. Line endings: LF (`.gitattributes`: `* text=auto eol=lf`); no test checks the endings: git converts to LF on `git add`, so CRLF on disk is harmless, and `tests/test_gitattributes.py` only guards the setting (see AGENTS.md rule 13). Files marked `-text` (test data, v1 language files) are byte for byte. `v1/` keeps the CRLF on disk (frozen reference).

## 2. Names

- Classes, methods, properties: `PascalCase`. Local variables and parameters: `camelCase`. Constants: `UPPER_SNAKE`.
- Message types: lowercase, dot-separated (`cmd.flow.start`). IDs from flow files are never changed.
- Private members start with `_`.

## 3. Forbidden patterns (review rules)

The patterns with fixed wording are **checked automatically**: `python tools/arch_check.py` (exit 1 on violations, output `file:line: rule: text`) and `tests/test_architecture.py` (part of the full run). Rules: `requires`, `one-class`, `include-core`, `include-roles`, `include-tests`, `dialog`, `file-io`, `blocking`, `inline-element`, `warn`, `critical`, `empty-catch`, `builtin-class`, `wire-bool`, `dialog-seam`. A justified exception is a comment `; arch-ok: <rule> <justification>` on the same or the previous line, or (for known legacy cases) an entry in the `EXCEPTIONS` list in `tools/arch_check.py`. **New rules are added here and in the tool (including its self-test) at the same time.** The check is deliberately simple (lines and patterns); it does not detect `A_TickCount`/randomness used as ID, access across process boundaries, or a missing `try/catch` around element code (review).

| Pattern | Where forbidden | Instead |
|---|---|---|
| `MsgBox`, `InputBox`, `FileSelect`, `DirSelect`, any blocking GUI | `engine`, `supervisor`, `storage`, `triggerhost`, `core` | Message to UI/worker (`evt.ui.notice`, dialog element in the worker) |
| `FileRead/FileAppend/FileOpen/FileDelete/DirCreate/Loop Files` | everything except `storage` (and reading startup parameters during boot) | Request to `storage`. Not file I/O in the sense of this rule: writing to stderr (`**`, `Role.Console`) and the supervisor reading the anonymous pipe of its children (`ChildPipe`, `PeekNamedPipe`/`ReadFile` on a handle that is not a file, never blocking). |
| `Sleep` (>0), `RunWait`, `WinWait*` without timeout, `Loop` with a wait time | everything except `worker` | `SetTimer`, callback |
| `A_TickCount` or randomness as ID | everywhere | `Ids.Next(prefix)` (counter per process) |
| `Critical` | everywhere | not needed. If it is, with a justification in the comment |
| `try` without handling (empty `catch`) | everywhere | log it or justify it deliberately |
| Access to objects of another process, shared memory, `SendMessage` to other roles | everywhere | message via the hub |
| Element code without `try/catch` around the call | `engine`, `worker`, `triggerhost` | central call site `ElementRunner` |
| `MsgBox(`, `InputBox(`, `ToolTip(`, `TrayTip(`, `FileSelect(`, `DirSelect(` called directly (rule `dialog-seam`); `Dialogs.UseProvider` (E0038) | `src/elements/` (the direct calls, except `elements/base/Dialogs.ahk`); `FileSelect(`/`DirSelect(` in `manager/`, `editor/`, `ui_common/` (except `ui_common/UiFileDialogs.ahk`, E0076); everywhere in `src/` (`UseProvider`) | `Dialogs.MsgBox(...)` and the like (`doc/ELEMENT-API-V2.md` 3.3); in a UI role `UiFileDialogs.File(...)`/`.Dir(...)`, called from a click handler. Only the test entries register a provider |
| `#Warn` without target `StdOut`/`OutputDebug` (a dialog); `#Warn LocalSameAsGlobal, Off` or `#Warn All, Off` (rule `warn`) | `src/` | `#Warn All, StdOut`. A local named like a class or a built-in function (`type`, `role`, `ids`, `run`) hides it for the whole function: give the local another name. The unit-test scripts and the test entries have `#Warn All, StdOut` before their first include |
| Boolean as literal (`"enabled", true`, `"cancel", 1`) in a protocol payload; `Json.False` in program state checked with `if` | everywhere | `Json.True`/`Json.False`/`Json.Bool(x)` only when building the message, internally `1`/`0` (PROTOCOL 2). `ok` is converted by `Message.Serialize` |

## 4. Errors and protocol

- Exceptions: classes `AhfError` (base), `ElementError`, `ProtocolError`, `AhfTimeoutError`. Each carries `code` (see the error codes in the protocol).
- Every request has a timeout. There is no waiting without a deadline. Exception with an upper bound: `cmd.app.prepareExit` (10 minutes, PROTOCOL 4.1), because the user's decision has no fixed deadline.
- Incoming messages are validated (type, mandatory payload fields) and answered on error, never ignored.
- State machines are classes with a transition table (`static Transitions := Map(...)`). Invalid transitions: return `false` plus an `a0` log entry.

## 5. AHK v2 pitfalls (short)

- `Map` enumerates in **sorted** key order, not in insertion order. Where order matters: use `Array`.
- Object properties are case-insensitive, `Map` keys are case-sensitive by default. For variable names and class IDs, set `m.CaseSense := "Off"` directly after creating the map (before inserting).
- `=` compares strings case-insensitively, `==` case-sensitively. Numbers and strings that look like numbers: keep JSON types, do not "repair" them.
- Accessing a non-existing map key throws. Use `m.Get(key, default)` or `m.Has(key)`.
- Read `A_LastError` directly after the `DllCall`; every further call overwrites it.
- `OnMessage` handlers and `SetTimer` callbacks hold references. When cleaning up: `OnMessage(..., 0)` or `SetTimer(fn, 0)`.
- Lambdas capture variables by reference. In loops create a local binding (`(v := x) => ...` or a helper function).
- When creating files through a shell (heredocs), `\\` can collapse to `\`. Always write source code with the editor tool, build pipe names from constants.

## 6. Tests and docs

- Every change to `core/`, state machines or the protocol comes with a test.
- New message types are added to `PROTOCOL.md`.
- Deliberate behavior changes compared to v1 are recorded in `MIGRATION.md` (ID, area, v1, v2, reason).
- A feature that is implemented, verified or dropped updates its requirement in `REQUIREMENTS.md` (AGENTS.md rule 12).
- Commits are small and descriptive, one change per commit.
