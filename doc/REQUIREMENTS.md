# Requirements

This document lists the important features and quality requirements of AutoHotFlow: what v1 can do, what v2 must do to replace it (the port), and what comes after the port. For each requirement it states whether v1 has it and how far v2 is.

**Overview:** [REQUIREMENTS-INDEX.md](REQUIREMENTS-INDEX.md) has one table row per requirement with its status and a link to its section here. Read the index for an overview; read a section here for the details.

A requirement says **what** AutoHotFlow does, not how: what the user sees or experiences. Internal parts (engine, worker, storage, processes) appear only where a quality requirement is about them, or as a reference for the details. The how is in the other documents (`ARCHITECTURE.md`, `PROTOCOL.md`, `ELEMENT-API-V2.md`, the decisions in `DECISIONS.md`); a requirement links to them instead of repeating them. Other documents refer to a requirement by its ID (`REQ-EXE-010`), not by a link to its heading, because the ID is stable and the heading anchor changes with the title.

**Sources of the first inventory (2026-10-14).** v1: the element manifest of the Default package (`v1/Source_Elements/Default/manifest.json`: 114 actions, 17 conditions, 5 loops, 16 triggers), the user interface texts of manager, editor, settings and tray, the settings defaults (`v1/Source_Common/Settings/Settings.ahk`), the changelog and the help folder; read, not run. v2: the code, the tests and the documents on `v2-port` at commit `9df8693` (WI-0045 verified); updated on 2026-10-15 for WI-0046, WI-0047-PREP, WI-0049, WI-0050 and the decisions E0040 to E0045. A step `S0001` to `S0009` is a step of the phase 3 plan (`work_items/phase3/README.md`).

## Format

Each area is a heading `## <Title> (<CODE>)`. Each requirement is a heading `### REQ-<CODE>-<nnn> <Title>` inside its area, followed by a list of fields and then free text (explanation, tables, sub-items, open questions):

```markdown
### REQ-EXE-050 Execution policy per flow

- **v1:** partial (`wait` behaves like `parallel`, M-0011)
- **v2:** partial (the global default is missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/integration/test_engine.py` (policy tests)

A flow decides what happens when it is triggered while an instance is still running ...
```

| Field | Allowed first word | Meaning |
|---|---|---|
| `v1` | `yes`, `partial`, `no`, `n/a` | Does v1 have it? Facts about v1 come from reading its code and help texts, unless the text says "tested". `n/a` when the question makes no sense for v1. |
| `v2` | `done`, `implemented`, `partial`, `open`, `dropped` | `done`: implemented and verified by a test or a measurement (the field `Evidence` is then mandatory). `implemented`: implemented, not verified. `partial`: a part works; the text says what is missing. `open`: not implemented. `dropped`: will not be implemented; the text says why. |
| `Prio` | `must`, `should`, `could` | `must`: v2 cannot replace v1 (scope `port`) or the feature has no use (scope `later`) without it. |
| `Scope` | `port`, `later` | `port`: needed so that v2 replaces v1 (phases 3 and 4). `later`: after the port. |
| `Plan` | free text | Where the work is planned: a step (`S0004`), `phase 4`, a work item (`WI-0052`), or `-` when nothing is planned. |
| `Evidence` | free text, optional | Tests, measurements (`MEASUREMENTS.md` M-nn), manual checks. Mandatory for `done`. A path in backticks, relative to the repository root, must exist: a file, a folder (`tests/fault/`), a glob (`tests/ahk/expr_*.test.ahk`) or a Python test (`tests/x.py::test_name`). |
| `Doubt` | free text, optional | The requirement is in doubt: the project owner may still change or drop it, also when it is implemented. The text says what is in doubt. The index marks it "(in doubt)" and counts it. |

After the first word, a field may carry a short note in parentheses: `partial (wait broken, M-0011)`. The index shows only the first word.

Rules:

- IDs are never reused or renumbered. New requirements get the next free number of their area, in steps of 10 (`010`, `020`, ...), so that related requirements can be numbered close together. The order of the sections may differ from the order of the numbers.
- A dropped requirement stays in the document with `v2: dropped` and its reason.
- A requirement may list its parts in a table, for example the elements of a group. A row whose plan is `later` is an idea for that requirement after the port: it needs no requirement of its own and does not change the fields, which refer to the rows of scope `port`.
- Whoever implements, verifies or drops a feature updates its requirement **in the same commit** and runs `python tools/req_index.py`. The test `tests/test_requirements.py` fails when the format is broken, an evidence path or test does not exist, or the index is out of date. Whoever renames or deletes a test named as evidence updates the requirement.
- Distinguish verified, assumed and not checked (AGENTS.md rule 6). `done` needs evidence; a claim about v1 that was not read in the code says so.
- A requirement whose `Plan` is `-` but whose scope is `port` is a gap in the plan: the project owner decides whether it gets a step or is dropped.

## Flows and execution (EXE)

### REQ-EXE-010 A flow is a graph of triggers, actions, conditions and loops

- **v1:** yes
- **v2:** done (the model and its execution; the real elements are in ELM)
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/engine_flow.test.ahk`, `tests/ahk/engine_scheduler.test.ahk`, `tests/integration/test_engine.py::test_start_emits_the_documented_event_order`

A flow consists of elements of four kinds (trigger, action, condition, loop) and connections between them. A trigger starts the flow; actions do something; conditions decide between two ways; loops repeat a part of the flow. Each element has a class (what it does), parameters and a name. The file format is in `ARCHITECTURE.md` section 7. The editor checks a flow for mistakes (REQ-EDT-160).

### REQ-EXE-020 Connection types and parallel branches

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/engine_scheduler.test.ahk` (`ResolveNext`, `Advance` cases)

A connection has a type: `normal` (after an action), `yes` and `no` (after a condition), `exception` (after an element that failed, REQ-EXE-090). When several connections match the result of an element, the flow continues on all of them at the same time, in parallel branches. Connections whose end is missing are ignored and logged (MIGRATION M-0013). Extended by REQ-EXE-150 (any number of named outputs).

### REQ-EXE-030 Loops with head, tail and break

- **v1:** yes
- **v2:** partial (the loop mechanics work; the loop elements and the break entry are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0054)
- **Evidence:** `tests/ahk/engine_scheduler.test.ahk` (`Loop:` cases)

A loop element has connection points: the head starts an iteration, a connection back to the tail starts the next one, a connection to the break point ends the loop. The loop variables (`A_Index` and the variables of the loop element) are visible inside the loop and restored when it is left, also with nested loops and when it is left through `exception` (MIGRATION M-0019).

### REQ-EXE-040 Instances and parallel branches

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/engine_states.test.ahk`

Each start of a flow creates an **instance**: one run of the flow, with its own instance variables. Several instances of the same flow may run at the same time (REQ-EXE-050). Inside an instance, every parallel branch (REQ-EXE-020) is a **thread** with its own thread and loop variables; all threads of an instance share its instance variables (REQ-VAR-040). An instance ends when its last thread has ended or when it is stopped. Manager and editor show the running instances (REQ-EXE-140). The states of instances and threads and their transitions: `ARCHITECTURE.md` section 5.

### REQ-EXE-050 Execution policy per flow

- **v1:** partial (`wait` behaves like `parallel`, MIGRATION M-0011)
- **v2:** partial (the four policies work; the global default setting is missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (global setting)
- **Evidence:** `tests/integration/test_engine.py` (the `*_policy_*` tests), `tests/ahk/engine_wait.test.ahk`

A flow decides what happens when it is triggered while an instance of it is still running:

| Policy | Behaviour |
|---|---|
| `parallel` | start another instance |
| `skip` | do not start; the start is answered with `busy` |
| `wait` | queue the start; it runs when the flow is idle |
| `stop` | stop the running instances, then start a new one |
| `default` | use the global setting (v1 default: `parallel`) |

Missing in v2: the global setting itself (settings come in S0004). Until then `default` means `parallel`.

### REQ-EXE-060 Start and stop a flow by hand

- **v1:** yes
- **v2:** partial (the commands work; the buttons in manager and editor are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (manager), S0006 (editor)
- **Evidence:** `tests/integration/test_engine.py` (`test_start_*`, `test_stop_*`, `test_toggle_starts_and_stops_a_flow`)

The user starts a flow from the manager or the editor, through its default manual trigger or a chosen one, and stops it there. Stopping ends all running and waiting instances of the flow. Starting and stopping from inside a flow is REQ-EXE-120 and REQ-ELM-250; starting by an event is TRG.

### REQ-EXE-070 Enable and disable a flow

- **v1:** yes
- **v2:** partial (the state can be switched and is reported; triggers do not react yet; that the state survives a restart of AutoHotFlow is not checked)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003
- **Evidence:** `tests/integration/test_engine.py::test_enable_and_disable_set_the_flag_and_report_it`

Enabling a flow activates all its enabled triggers; disabling deactivates them. Running instances are not affected. Flows that were enabled when AutoHotFlow ended are enabled again at the next start.

### REQ-EXE-080 Change a flow while it runs

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/engine_revision.test.ahk`

A change in the editor applies to running instances at their next step: the next element and the next connection are taken from the changed flow (decision E0001). An element that runs while it is deleted runs to its end; a waiting branch whose element was deleted ends with `exception` (MIGRATION M-0017, M-0018).

### REQ-EXE-090 A failing element ends with `exception`

- **v1:** partial (six elements never ended on an error, MIGRATION M-0004)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_engine.py::test_element_exception_is_reported_and_the_engine_keeps_running`, `tests/ahk/element_runner.test.ahk`, `tests/ahk/engine_scheduler.test.ahk` (`Advance: exception` cases)
- **Doubt:** Should an `exception` without a connection stop the whole instance? Today, as in v1, only the branch ends and the other parallel branches of the instance go on.

An element that fails ends with the result `exception` and writes the reason to the log. If it has an `exception` connection, the flow continues there. Otherwise the branch ends and the log notes an unhandled exception. Other flows and other instances of the same flow are not affected.

### REQ-EXE-100 Waiting elements do not delay other flows

- **v1:** partial (read: only elements that call `x_ExecuteInNewAHKThread` run separately)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_worker.py`, `tests/fault/test_worker_lifecycle.py`, `tests/integration/test_worker_pool.py`

An element that waits (a dialog, a program started with "wait", a download) does not delay other flows or other branches. By default up to four such elements wait at the same time; further ones wait for their turn. An element that blocks although it is declared as quick is reported in the log, so that the mistake is noticed. How: worker processes, `ARCHITECTURE.md` sections 2.3 and 6.4.

### REQ-EXE-110 Stopping ends waiting elements quickly

- **v1:** partial (instances stop without a deadline; how a blocked call ends was not checked, MIGRATION M-0012, M-0020)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_engine.py::test_stop_during_sleep_ends_the_instance_within_500_ms`, `tests/fault/test_worker_lifecycle.py::test_cancel_of_a_frozen_worker_ends_the_instance_at_once_and_the_process_is_killed_and_replaced`

A stopped instance ends at once, also while one of its elements waits for a dialog or a download. An element that does not react is ended forcibly after 2 s. An element class may limit how long it may run.

### REQ-EXE-120 Run another flow from a flow

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0055)

The action `Execute_Flow` starts a flow (this one or another) through its default trigger or a chosen manual trigger. Options: pass the local variables to the called flow, wait until it has finished, return its local variables to the caller, skip a disabled flow without error.

### REQ-EXE-130 Working directory of a flow

- **v1:** yes
- **v2:** partial (`A_WorkingDir` and the file parameters use a fixed default; the settings are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (global), S0007 (flow settings)

Relative paths in file and folder parameters refer to the working directory. Each flow uses the global working directory (v1 default `A_MyDocuments "\AutoHotFlow"`) or its own (flow setting). Decision E0028.

### REQ-EXE-140 Every element and flow shows its state

- **v1:** yes
- **v2:** partial (the states are reported; manager and editor do not show them yet)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (manager), S0005 (editor)
- **Evidence:** `tests/integration/test_engine.py::test_start_emits_the_documented_event_order`, `tests/e2e/test_ui_stub.py::test_engine_restart_is_seen_and_resynced_without_restarting_the_stub`

Each element has a state (idle, running, finished, exception) and counts its runs. Each flow shows whether it is enabled and whether it runs, and its running and queued instances. Manager and editor show these states live, also a window that was opened later or that reconnected after a fault.

### REQ-EXE-150 Elements with any number of named outputs

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

An element can have any number of outputs, for example a switch with one output per case. The element and its configuration decide which outputs exist; the result of a run names the output (or several) to continue on. `yes`/`no` of a condition are the special case with two fixed outputs; `exception` stays a separate output of every element. Extends REQ-EXE-020.

Open points: a connection whose output disappears after a change of the configuration (a warning of the flow check, REQ-EDT-160, or refused by the editor); how the editor draws a variable number of connection points; the file format of the connection type (today a fixed set).

## Expressions and variables (VAR)

### REQ-VAR-010 Expression language with AutoHotkey v2 semantics

- **v1:** partial (an own language with known bugs; function calls never worked)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/oracle/test_expr_oracle.py`, `tests/ahk/expr_*.test.ahk`

Expressions follow AutoHotkey v2 (E0022, E0035): operators and precedence, assignments, paths into objects (`a.b[1]`), dynamic names (`%name%`), the functions `round`, `object`, `print` and `mod`. Syntax: `EXPRESSION-LANGUAGE.md`.

Where AutoHotFlow deliberately differs from AutoHotkey v2, the difference is on a short fixed list (E0025, E0029, E0034). A test checks this automatically: it generates many expressions, runs each one as native AutoHotkey v2 code and in AutoHotFlow, and accepts a different result only when the list explains it. Such an independent reference for the expected results is called an "oracle" (`EXPRESSION-LANGUAGE.md` section 19).

Expressions are checked while the user edits them: REQ-EDT-200.

### REQ-VAR-020 Script form for several statements

- **v1:** yes (action `Script`, marked experimental)
- **v2:** partial (the language has the script form; the element is missing)
- **Prio:** should
- **Scope:** port
- **Plan:** S0008 (element)
- **Evidence:** `tests/ahk/expr_script.test.ahk`

One statement per line: assignments, function calls, `if`/`else` and blocks (`EXPRESSION-LANGUAGE.md` section 8).

### REQ-VAR-030 `%var%` substitution in text parameters

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/golden/test_golden_v2.py::test_variable_access_and_substitution_are_compared`
- **Doubt:** Keep `%var%`, allow a whole expression between the percent signs (`%a + 1%`), or choose a better syntax? The feature is isolated; it can be decided at the end of the port, although it is implemented now.

A text parameter replaces `%name%` by the value of the variable. An object can be written as JSON text where the element allows it (MIGRATION M-0042).

### REQ-VAR-040 Variable scopes

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/vars_model.test.ahk`, `tests/ahk/engine_vars.test.ahk`

The name of a variable decides where it lives:

| Scope | Name | Visible in | Lives | Written by |
|---|---|---|---|---|
| loop | `A_...` (`A_Index`, ...) | the body of the loop, in the branch that runs it | while the loop runs; leaving the loop restores the values from before | the loop element |
| thread | `A_...` (`A_TriggerTime`, ...) | one branch of an instance; a new branch starts with a copy | as long as the branch | the trigger and elements |
| instance | no prefix (`count`) | all branches of one instance | as long as the instance, one run of the flow | the user (for example with `New_Variable`) and elements |
| static | `static_...` | all instances of one flow | permanently (REQ-VAR-050) | the user and elements |
| global | `global_...` | all flows | permanently (REQ-VAR-050) | the user and elements |
| built-in | `A_...` | everywhere, read only | - | AutoHotFlow (REQ-VAR-070) |

Loop and thread variables are alike: both belong to a branch; loop variables also belong to the level of the loop. Every `A_` name is a loop, thread or built-in variable; it is looked up in this order. Therefore the user cannot create a variable whose name starts with `A_`: an element refuses to write such a name, an assignment in an expression is an error (MIGRATION M-0038), and the element settings warn about it (S0007). Elements can also keep hidden variables that the user cannot reach. Details: `EXPRESSION-LANGUAGE.md` section 18.

### REQ-VAR-050 Permanent global and static variables

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_var_persistence.py`, `tests/fault/test_s1_acceptance.py`

Global and static variables keep their values when AutoHotFlow ends. A change is saved shortly after it was made and at the latest when AutoHotFlow ends; when AutoHotFlow is killed, a change of the last moments can be lost (MIGRATION M-0006). Hints for the user: REQ-VAR-130; protection against concurrent changes: REQ-VAR-140.

### REQ-VAR-060 Objects and lists in variables

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/vars_model.test.ahk`, `tests/golden/test_golden_v2.py`

A variable holds a text, a number or an object. A list is an object with the keys 1..n. Keys ignore case; `list.1` and `list["1"]` are the same member. Assigning an object copies it. Numbers keep their type through variables (MIGRATION M-0039).

### REQ-VAR-070 Built-in variables

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/vars_model.test.ahk`

Ready-made values that a flow needs often, without an extra element: the current date and time and its parts (for file names and time conditions), the standard folders (desktop, documents, temp, ...), facts about the computer and the user, and facts about the running flow (`A_FlowName`, `A_ElementName`, `A_WorkingDir`, `A_AhfVersion`, ...) for messages and logs. 55 variables of AutoHotkey and 13 of AutoHotFlow; list and deviations: `EXPRESSION-LANGUAGE.md` section 18.4.

### REQ-VAR-080 Values of the trigger reach the instance

- **v1:** yes
- **v2:** partial (`A_TriggerTime` and `A_TriggerID` are set; the values of the real triggers are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003
- **Evidence:** `tests/ahk/vars_model.test.ahk`

A new instance gets the thread variables `A_TriggerTime` and `A_TriggerID`, and the values that its trigger provides (for example the window of a window trigger).

### REQ-VAR-090 Parameter evaluation by content type

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/element_evalparams.test.ahk`, `tests/fault/test_param_eval.py`

Each parameter is evaluated by its content type: `String` (with `%var%`), `RawString`, `Expression`, `number`, `positiveNumber`, `integer`, `positiveInteger`, `positiveIntegerOrZero`, `VariableName`. File and folder parameters become full paths. The user can choose the content type of a field where the element allows it. A parameter gives the same result whether its element waits (REQ-EXE-100) or not. Details: `ELEMENT-API-V2.md` section 3.1, MIGRATION M-0048.

### REQ-VAR-100 Type errors: compatible or strict per flow

- **v1:** no (only the lenient behaviour)
- **v2:** partial (both modes work; the warnings are not shown in the editor yet)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004/S0005 (display of the warnings)
- **Evidence:** `tests/ahk/element_evalparams.test.ahk` (strict mode case)

Each flow has the option `strictTypes` (E0034). Migrated flows use the compatibility mode (a type error gives the empty text and a warning, as in v1); new flows use the strict mode (a type error ends the element with `exception`). In both modes the warnings are shown to the user in the editor.

### REQ-VAR-110 Waiting elements can use all variables

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_worker_vars.py::test_every_variable_function_gives_the_same_result_in_a_worker_as_inline`, `tests/integration/test_worker_vars.py::test_round_trip_of_a_variable_request_from_a_worker` (MEASUREMENTS MS-0031)

An element that waits (REQ-EXE-100) reads every visible variable, sets variables and evaluates expressions like every other element, with the same results. It always sees the current value: a change by another branch while it waits is visible at its next access (MIGRATION M-0045). How: requests to the engine, `ELEMENT-API-V2.md` section 3.

### REQ-VAR-120 Rounding option for decimal numbers

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Floats are written in the AutoHotkey v2 form (`0.1+0.2` gives `0.30000000000000004`, E0032). An element parameter may later round the result.

### REQ-VAR-130 Hints on global and static variables

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

The help and the element settings point out what global and static variables cost: every change is saved to disk, and several flows or instances may change the same variable at the same time (REQ-VAR-140). A variable should be global or static only when it must outlive the run or be shared.

Note: the cost in time is lower in v2 than in v1. v1 read the file at every access; v2 keeps the values in memory and saves changes in the background. The hint is therefore mainly about concurrent changes.

### REQ-VAR-140 Protect variables against concurrent changes

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -
- **Doubt:** The benefit may not be worth the complexity (locks across flows, deadlocks, timeouts, what happens when a flow is stopped while it holds a lock).

When two flows or branches read, change and write the same variable through two elements, one change can be lost. A mechanism protects a variable for a short time, so that such a sequence is atomic: for example elements that change a value in one step (increment, append to a list), or a lock that other elements wait for.

Note: an element that waits (REQ-EXE-100) may read a value, wait a long time (for example for a dialog) and write afterwards; the window for a lost change is then as long as it waits.

## Element packages (PKG)

### REQ-PKG-010 Elements are organised in packages

- **v1:** yes
- **v2:** partial (the package `Default` with its description and element files, one generated include block per package and role; language files, icons and help are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0047), help: S0007
- **Evidence:** `tests/test_element_includes.py`, `tests/ahk/element_registry.test.ahk`

A package has a manifest (name, version, author, license, libraries, element lists), its element files, icons, language files and help. Flows store the package and its version per element. Phase 3 has only the package `Default` (E0037).

### REQ-PKG-020 Install additional packages

- **v1:** yes (extension packages with their own installers)
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** - (phase 3 has only the Default package, E0037)

The user installs element packages from others. Depends on REQ-PKG-050 and REQ-PKG-060.

### REQ-PKG-030 The included elements are split into a basic and special packages

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

The elements that come with AutoHotFlow are split into a basic package (everything that most flows need) and special packages for particular purposes, which may be more complex and may use external dependencies. All packages are in the repository and in the installer; the user switches each special package on or off in the settings. The first start proposes a choice (REQ-USE-050).

### REQ-PKG-040 Users create their own packages and elements

- **v1:** no (possible in principle, not documented for users)
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

The user can create a package of their own and add elements to it with little effort. AutoHotFlow gives all the information needed: a template, the element contract (REQ-ELM-010), the parameter types and how to test the element. The information is complete enough that a user without programming knowledge can give it to an AI in a chat window, describe what the element shall do, and get a working element (see also AI).

### REQ-PKG-050 A broken element or package does not stop AutoHotFlow

- **v1:** no
- **v2:** open
- **Prio:** must
- **Scope:** later
- **Plan:** -

An element of an installed or self-made package that does not load or that fails is marked as faulty, with the reason, in the manager and in the editor. AutoHotFlow and all other elements keep working. Errors while an element runs are already covered by REQ-EXE-090; this requirement is about loading.

Open point (assumed, not checked): AutoHotkey reads all `#Include` files when a script starts, and a syntax error in one of them stops the whole script. Today every process includes every element (one entry point, D0012). A compiled program cannot include files at run time at all (REQ-DST-020). So packages from users need their own way of loading, for example a check of the package in a separate process before it is used, or running its elements in separate processes. To be designed before REQ-PKG-020 and REQ-PKG-040.

### REQ-PKG-060 The package name is part of the identity of an element

- **v1:** partial (the flow files store the package of each element, but the class name alone identifies it)
- **v2:** implemented (registry, flow lookup, worker jobs and logs use `<package>.<class>`; not yet tested with a run of two packages)
- **Prio:** should
- **Scope:** port
- **Plan:** S0002 (WI-0047, decision E0045)
- **Evidence:** `tests/ahk/element_registry.test.ahk`, `tests/test_element_includes.py::test_two_packages_with_a_class_of_the_same_name_load_in_one_process`

Every element is identified by its package and its class, also the elements of v1. So elements of different packages may have the same class name.

The flow files need nothing new: v1 already writes `package` for every element (verified: 1077 of 1077 elements in the test flows; 8 of them write `default` in lower case, so the comparison ignores case). The import fills in `Default` where the key is missing.

What is more than a file question:

- **AutoHotkey class names are global.** Two classes with the same name in one script are a load error ("This class declaration conflicts with an existing Class", verified). The class of an element therefore needs the package in its name. Nested classes do this: `class Default { class Action_Sleep ... }` has the type name `Default.Action_Sleep` (verified), which is the qualified ID at the same time. The package class includes the element files in its body, so an element file stays one class (verified).
- **Every place that names a class carries the qualified ID:** the element registry (`src/elements/base/ElementRegistry.ahk`, keyed by the qualified ID since WI-0047), the worker jobs and the trigger arming (`PROTOCOL.md` 4.4 and 4.5), logs, and elements that look up other elements by class (v1 `x_getAllElementIDsOfClass`, `Action_Set_element_parameter`; they come in S0008 and must use the qualified ID).

Doing this together with the package layout of WI-0047 is cheaper than changing it later, when many element classes exist.

## Elements (ELM)

Each group of elements is one requirement with a table of its elements. The fields of the requirement refer to the elements with scope `port`, that is the elements of v1. An idea for a further element of a group is a row with the plan `later`: it needs no requirement of its own and does not change the fields (rule in the format section). A new group is a new requirement. The class IDs are `Action_<name>`, `Condition_<name>`, `Loop_<name>`; the triggers are in TRG. The core set of S0002 comes first, the rest in S0008 (E0020).

### REQ-ELM-010 Element contract and registry

- **v1:** yes
- **v2:** partial (class contract, registry, parameters and run/stop work; the metadata for the editor is not used yet)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0047), S0007 (editor)
- **Evidence:** `tests/ahk/element_registry.test.ahk`, `tests/ahk/element_runner.test.ahk`

An element is a class with: name, category, user level, stability (stable or experimental), icon, parameter schema, `Run`, `Stop`, settings check (`CheckSettings`) and its execution mode (`inline`, `worker`, `trigger`). Contract: `ELEMENT-API-V2.md`.

### REQ-ELM-020 Every element is documented by its help text

- **v1:** yes (an HTML help page per element in `Help/en/`)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0007
- **Evidence:** -

Every element has a help page that says what it does and what its parameters mean. The help is reachable from the element settings.

### REQ-ELM-110 AutoHotkey scripts in flows

- **v1:** yes (AutoHotkey v1 code in a new AutoHotkey_H thread)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_AutoHotkey_script` | yes | open | S0008 |
| `Trigger_AutoHotkey_Script` | yes | open | S0008 |

The action and the trigger run AutoHotkey v2 code, separately from the flows (E0039). An imported v1 script is kept as text and marked; it does not run until it is ported, by hand or with the help of an AI (REQ-AI-040, MIGRATION M-0049).

### REQ-ELM-200 Variables and calculations

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0052), S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_New_Variable` | yes | open | S0002 (WI-0052) |
| `Action_Random_Number` | yes | open | S0008 |
| `Action_Absolute_Number` | yes | open | S0008 |
| `Action_Square_Root` | yes | open | S0008 |
| `Action_Trigonometry` | yes | open | S0008 |
| `Action_Rounding_a_number` | yes | open | S0008 |
| `Action_Exponentiation` | yes | open | S0008 |
| `Action_Script` (REQ-VAR-020) | yes | open | S0008 |

### REQ-ELM-210 Conditions on values

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0052)

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Condition_Expression` | yes | open | S0002 (WI-0052) |
| `Condition_Variable_Is_Empty` | yes | open | S0002 (WI-0052) |
| `Condition_Variable_content_is` | yes | open | S0002 (WI-0052) |
| `Condition_NumberIs` | yes | open | S0002 (WI-0052) |

### REQ-ELM-220 Strings

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Search_in_a_string` | yes | open | S0008 |
| `Action_Substring` | yes | open | S0008 |
| `Action_Substring2` | yes | open | S0008 |
| `Action_Get_string_Length` | yes | open | S0008 |
| `Action_Replace_in_a_string` | yes | open | S0008 |
| `Action_Trim_a_string` | yes | open | S0008 |
| `Action_Split_a_string` | yes | open | S0008 |
| `Action_Change_character_case` | yes | open | S0008 |
| `Action_Encode_string` | yes | open | S0008 |
| `Condition_String_Contains_Text` | yes | open | S0008 |

### REQ-ELM-230 Lists

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0053), S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_New_List` | yes | open | S0002 (WI-0053) |
| `Action_Add_to_list` | yes | open | S0002 (WI-0053) |
| `Action_Get_list_info` | yes | open | S0002 (WI-0053) |
| `Action_Delete_from_list` | yes | open | S0002 (WI-0053) |
| `Action_Get_index_of_element_in_list` | yes | open | S0002 (WI-0053) |
| `Action_Shuffle_list` | yes | open | S0002 (WI-0053) |
| `Condition_List_Contains_Element` | yes | open | S0002 (WI-0053) |
| `Action_Get_from_list` | yes | open | S0008 |
| `Action_Convert_list_to_string` | yes | open | S0008 |
| `Action_Convert_string_to_list` | yes | open | S0008 |

### REQ-ELM-240 Loops

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0054), S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Loop_SimpleLoop` | yes | open | S0002 (WI-0054) |
| `Loop_Condition` | yes | open | S0002 (WI-0054) |
| `Loop_Parse_A_String` | yes | open | S0002 (WI-0054) |
| `Loop_Work_through_a_list` | yes | open | S0002 (WI-0054) |
| `Loop_Loop_Through_Files` | yes | open | S0008 |

Connection points and loop variables: REQ-EXE-030.

### REQ-ELM-250 Flow control

- **v1:** yes
- **v2:** partial (`Action_Sleep` and `Action_Do_nothing` exist as skeleton elements)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0047, WI-0052, WI-0055), S0003, S0008
- **Evidence:** `tests/ahk/element_sleep.test.ahk`

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Sleep` | yes | partial (skeleton) | S0002 (WI-0047) |
| `Action_Do_nothing` | yes | partial (skeleton) | S0002 (WI-0052) |
| `Condition_Do_nothing` | yes | open | S0002 (WI-0052) |
| `Action_Execute_Flow` (REQ-EXE-120) | yes | open | S0002 (WI-0055) |
| `Action_Stop_Flow` | yes | open | S0002 (WI-0055) |
| `Condition_Flow_Running` | yes | open | S0002 (WI-0055) |
| `Action_Set_Flow_Status` | yes | open | S0003 |
| `Condition_Flow_Enabled` | yes | open | S0008 |
| `Action_Set_element_parameter` | yes | open | S0008 |

### REQ-ELM-260 Trace points

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0052)

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Trace_Point` | yes | open | S0002 (WI-0052) |
| `Action_Trace_Point_Check` | yes | open | S0002 (WI-0052) |

They record the path through a flow and check it; automatic test flows use them (REQ-TST-040).

### REQ-ELM-270 Dialogs and notifications

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0051, WI-0056), S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Message_Box` | yes | open | S0002 (WI-0056) |
| `Action_Tooltip` | yes | open | S0002 (WI-0056) |
| `Condition_Confirmation_Dialog` | yes | open | S0002 (WI-0056) |
| `Condition_Debug_Dialog` | yes | open | S0002 (WI-0056) |
| `Action_Input_Box` | yes | open | S0008 |
| `Action_Select_file` | yes | open | S0008 |
| `Action_Select_folder` | yes | open | S0008 |

Dialogs run separately from the flows (MIGRATION M-0002) and can be answered by a test provider (E0038).

### REQ-ELM-280 Date and time

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_New_Time` | yes | open | S0008 |
| `Action_Time_calculation` | yes | open | S0008 |
| `Action_Time_difference` | yes | open | S0008 |

### REQ-ELM-290 Clipboard

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Get_Clipboard` | yes | open | S0008 |
| `Action_Set_Clipboard` | yes | open | S0008 |

### REQ-ELM-300 Files and folders

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Read_From_File` | yes | open | S0008 |
| `Action_Write_To_File` | yes | open | S0008 |
| `Action_Copy_file` | yes | open | S0008 |
| `Action_Move_File` | yes | open | S0008 |
| `Action_Rename_file` | yes | open | S0008 |
| `Action_Delete_file` | yes | open | S0008 |
| `Action_Create_folder` | yes | open | S0008 |
| `Action_Copy_folder` | yes | open | S0008 |
| `Action_Move_Folder` | yes | open | S0008 |
| `Action_Rename_Folder` | yes | open | S0008 |
| `Action_Delete_folder` | yes | open | S0008 |
| `Action_Empty_Recycle_bin` | yes | open | S0008 |
| `Action_Get_file_attributes` | yes | open | S0008 |
| `Action_Get_file_size` | yes | open | S0008 |
| `Action_Get_file_time` | yes | open | S0008 |
| `Action_Set_file_attributes` | yes | open | S0008 |
| `Action_Set_file_time` | yes | open | S0008 |
| `Action_Get_shortcut_information` | yes | open | S0008 |
| `Action_Create_Shortcut` | yes | open | S0008 |
| `Action_Split_path` | yes | open | S0008 |
| `Condition_File_Exists` | yes | open | S0008 |
| `Condition_File_Has_Attribute` | yes | open | S0008 |

The loop over files is in REQ-ELM-240.

### REQ-ELM-310 Ini files

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Read_From_Ini` | yes | open | S0008 |
| `Action_Write_to_ini` | yes | open | S0008 |
| `Action_Delete_From_Ini` | yes | open | S0008 |

### REQ-ELM-320 Archives

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Compress_files` | yes | open | S0008 |
| `Action_Extract_files` | yes | open | S0008 |

### REQ-ELM-330 Drives

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_List_Drives` | yes | open | S0008 |
| `Action_Get_Drive_Information` | yes | open | S0008 |
| `Action_Change_Drive_Label` | yes | open | S0008 |
| `Action_Eject_Drive` | yes | open | S0008 |
| `Action_Lock_Or_Unlock_Drive` | yes | open | S0008 |

### REQ-ELM-340 Internet

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Download_file` | yes | open | S0008 |
| `Action_HTTP_Request` | yes | open | S0008 |

### REQ-ELM-350 Screen and images

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Screenshot` | yes | open | S0008 |
| `Action_Get_pixel_color` | yes | open | S0008 |
| `Action_Search_pixel` | yes | open | S0008 |
| `Action_Search_Image` | yes | open | S0008 |
| `Action_Get_Screen_Settings` | yes | open | S0008 |
| `Action_Set_Screen_Settings` | yes | open | S0008 |

### REQ-ELM-360 Windows and controls

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_activate_Window` | yes | open | S0008 |
| `Action_Show_window` | yes | open | S0008 |
| `Action_Hide_window` | yes | open | S0008 |
| `Action_Close_Window` | yes | open | S0008 |
| `Action_Move_window` | yes | open | S0008 |
| `Action_Minimize_All_Windows` | yes | open | S0008 |
| `Action_Get_control_text` | yes | open | S0008 |
| `Action_Set_control_text` | yes | open | S0008 |
| `Condition_Window_Active` | yes | open | S0008 |
| `Condition_Window_Exists` | yes | open | S0008 |

### REQ-ELM-370 Mouse and keyboard

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Click` | yes | open | S0008 |
| `Action_Move_Mouse` | yes | open | S0008 |
| `Action_Drag_with_mouse` | yes | open | S0008 |
| `Action_Get_mouse_position` | yes | open | S0008 |
| `Action_Send_Keystrokes` | yes | open | S0008 |
| `Action_Send_Keystrokes_To_Control` | yes | open | S0008 |
| `Action_Set_Lock_Key` | yes | open | S0008 |
| `Action_Block_User_Input` | yes | open | S0008 |
| `Condition_Key_Is_Down` | yes | open | S0008 |

### REQ-ELM-380 Sound and speech

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Play_Sound` | yes | open | S0008 |
| `Action_Stop_Sound` | yes | open | S0008 |
| `Action_Beep` | yes | open | S0008 |
| `Action_Get_Volume` | yes | open | S0008 |
| `Action_Set_Volume` | yes | open | S0008 |
| `Action_Speech_output` | yes | open | S0008 |

### REQ-ELM-390 Programs and processes

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Run` | yes | open | S0008 |
| `Action_Kill_Process` | yes | open | S0008 |
| `Action_Set_Process_Priority` | yes | open | S0008 |
| `Condition_Process_Is_Running` | yes | open | S0008 |

### REQ-ELM-400 Power and session

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Lock_Computer` | yes | open | S0008 |
| `Action_Log_Off` | yes | open | S0008 |
| `Action_Shutdown` | yes | open | S0008 |
| `Action_Reboot_Computer` | yes | open | S0008 |
| `Action_Hibernate_Computer` | yes | open | S0008 |
| `Action_Suspend_Computer` | yes | open | S0008 |

## Triggers (TRG)

### REQ-TRG-010 Triggers react at once, whatever the load

- **v1:** no (triggers live in the execution thread)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0003

Hotkeys, hooks and timers react at once, no matter how busy the running flows are (Windows removes a low-level hook that answers too slowly). An error of one trigger (a hotkey that cannot be registered) is reported and does not stop the others. How: a trigger host process, `ARCHITECTURE.md` D8.

### REQ-TRG-020 Triggers follow the enabled state, also after a restart

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0003

The triggers of enabled flows are active from the start of AutoHotFlow on, and again after an internal restart (REQ-ROB-040); disabling a flow deactivates them.

### REQ-TRG-030 Several triggers per flow

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0003, S0006

A flow can have several triggers. Each trigger can be enabled and disabled on its own. One manual trigger is the default trigger, used when the flow is started without naming a trigger.

The trigger groups below follow the same rule as the element groups in ELM: one requirement per group, a table of its triggers, ideas as rows with the plan `later`. The AutoHotkey script trigger is in REQ-ELM-110.

### REQ-TRG-200 Manual trigger

- **v1:** yes
- **v2:** partial (a skeleton `Trigger_Manual` exists, and a flow can be started through it)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0047)
- **Evidence:** `tests/integration/test_engine.py::test_start_emits_the_documented_event_order`

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Manual` | yes | partial (skeleton) | S0002 (WI-0047) |

Started by the user, by another flow (REQ-EXE-120) or through the command line (REQ-DST-040).

### REQ-TRG-210 Time triggers

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0003, S0008

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Periodic_Timer` | yes | open | S0003 |
| `Trigger_Time_of_Day` (with week days) | yes | open | S0008 |

### REQ-TRG-220 Start-up trigger

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0003

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Start_up` | yes | open | S0003 |

Fires when AutoHotFlow starts; it can tell a start with Windows (REQ-SET-030) from a start by hand.

### REQ-TRG-230 Keyboard triggers

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0003, S0008

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Hotkey` | yes | open | S0003 |
| `Trigger_Hotstring` | yes | open | S0008 |

A hotkey can be limited to a given window; it is disabled in the same context (MIGRATION M-0003).

### REQ-TRG-240 Shortcut trigger

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0008

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Shortcut` | yes | open | S0008 |

Creates a shortcut file (default on the desktop) that starts the flow through the command line of AutoHotFlow (REQ-DST-040); the shortcut is removed when the trigger is disabled (option).

### REQ-TRG-250 User activity triggers

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0008

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_User_Idle_Time` | yes | open | S0008 |
| `Trigger_Clipboard_Changes` | yes | open | S0008 |

### REQ-TRG-260 Window triggers

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0008

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Window_opens` | yes | open | S0008 |
| `Trigger_Window_closes` | yes | open | S0008 |
| `Trigger_Window_gets_active` | yes | open | S0008 |
| `Trigger_Window_gets_inactive` | yes | open | S0008 |

### REQ-TRG-270 Process triggers

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0008

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Process_starts` | yes | open | S0008 |
| `Trigger_Process_closes` | yes | open | S0008 |

### REQ-TRG-280 File triggers

- **v1:** no (the changelog 0.02.20 names a "File observer", but it is not in the manifest of the Default package)
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| File observer: fires when files in a folder change | no | open | later |

## Manager (MGR)

### REQ-MGR-010 Flow list with categories and state

- **v1:** yes
- **v2:** open (the stub lists the flows without categories)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

The manager shows all flows in a tree of categories, with their state (enabled, running). Flows without a category are under "Uncategorized".

### REQ-MGR-020 Create, rename, duplicate and delete flows

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

Names are checked: no forbidden characters, no second flow with the same name. Deleting asks for confirmation. The commands behind it (`cmd.flow.create`, `cmd.flow.delete`, `cmd.flow.meta.update`, `PROTOCOL.md` 4.2) are not built yet. Deleting a running flow stops its instances at once (E0009).

### REQ-MGR-030 Manage categories

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

Create, rename and delete categories; move flows to another category. When a category is deleted, its flows move to a category the user chooses.

### REQ-MGR-040 Operate flows from the manager

- **v1:** yes
- **v2:** open (the stub can start a flow, manual check of 2026-10-14)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

Buttons for run, stop, enable and disable, and edit (opens the editor of the flow) for the selected flows.

### REQ-MGR-050 Import and export flows

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

Export selected flows to an `.ahf` file (a ZIP archive); import from such a file through a file selector or by dropping it on the window. On a name conflict the user can rename the imported flow. An invalid file is reported.

### REQ-MGR-060 Demonstration flows

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** - (not in the phase 3 plan)

AutoHotFlow ships demo flows in their own category. They cannot be deleted or renamed, but the user can hide them (setting "Hide demonstration flows").

### REQ-MGR-070 Show the log

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

The manager shows the log, filtered by level (only errors, some, many, all) and by source (app, flow, thread). The flow settings open the log of one flow.

### REQ-MGR-080 Closing the manager window keeps AutoHotFlow running

- **v1:** yes (read: the v1 manager has no `GuiClose` handler)
- **v2:** open (the stub ends the whole application when its window is closed)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** -

Closing the manager window only hides it. Flows and triggers keep running; the tray icon brings the window back. Only the "Exit" button of the manager and the "Exit" entry of the tray menu end the application. Decision E0014.

### REQ-MGR-090 Tray icon

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (assumed; the plan does not name the tray)

The tray icon shows the manager (default action) and ends the application. Errors and warnings that have no window of their own appear as tray notices (REQ-USE-030). `ARCHITECTURE.md` 6.1 puts the tray icon in the supervisor; finding F-0064 waits for a decision on it.

### REQ-MGR-100 About window

- **v1:** yes
- **v2:** open
- **Prio:** could
- **Scope:** port
- **Plan:** -

Shows the version of AutoHotFlow and of AutoHotkey, the license and the project site.

## Editor (EDT)

### REQ-EDT-010 One editor per flow, several at the same time

- **v1:** partial (several editors, but drawing and input share one lock and one draw thread)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0005

Each open flow has its own editor window in its own process (D0002). An editor that hangs or crashes does not affect the other editors or the running flows. All open editors show live states, also those without focus.

### REQ-EDT-020 Draw the flow

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0005

Elements with icon and name, connections with their type, loops with their adjustable height; texts are aligned vertically; drawing does not flicker. Hovering an element shows its kind, class and name.

### REQ-EDT-030 Zoom and move the view

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0005

Zoom, and move the view by dragging with the right (or left) mouse button. Zoom and offset are saved with the flow (`flowSettings`).

### REQ-EDT-040 Live execution state in the editor

- **v1:** yes
- **v2:** open (the states are reported, REQ-EXE-140)
- **Prio:** must
- **Scope:** port
- **Plan:** S0005

Running elements and connections are highlighted while the flow runs; the editor shows the current state again after an internal restart (REQ-ROB-040).

### REQ-EDT-050 Add elements

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0006, S0007

The user chooses the kind (trigger, action, condition, loop) and then the class from a list grouped by category. The list shows only the elements of the user's level (REQ-USE-010) and marks experimental ones (REQ-USE-020). The new element gets a default name.

### REQ-EDT-060 Select and move

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0006

Select one or several elements (also all with Ctrl+A) and move them with the mouse. Esc or the right mouse button cancels a move.

### REQ-EDT-070 Connect elements

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0006

Draw a connection between two elements and choose its type; change the type later. Not allowed: a connection into a trigger, from an element to itself, a second identical connection.

### REQ-EDT-080 Delete, cut, copy and paste

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0006

Delete with confirmation (Del). Cut, copy and paste with Ctrl+X, Ctrl+C, Ctrl+V, also between two flows.

### REQ-EDT-090 Undo and redo

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0006

Ctrl+Z and Ctrl+Y and menu entries. A cancelled action (a move cancelled with Esc, a dialog cancelled) leaves no undo step.

### REQ-EDT-100 Save, and changes during execution

- **v1:** yes (unsaved flows are saved automatically at exit)
- **v2:** partial (revisions, conflict detection and saving work internally; edit operations are refused until the editor exists)
- **Prio:** must
- **Scope:** port
- **Plan:** S0006
- **Evidence:** `tests/integration/test_engine.py::test_patch_with_a_stale_base_revision_is_a_conflict_with_the_current_state`

Every completed edit takes effect at once, also for running instances (REQ-EXE-080). Saving (Ctrl+S, menu) writes the flow to disk. When the editor or the application is closed with unsaved changes, the user is asked and can cancel (two-phase exit, `ARCHITECTURE.md` 6.3). A rename by the manager while the editor is open is merged.

### REQ-EDT-110 Run, stop and enable from the editor

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0006

The menu bar of the editor has: save, run, stop, enable/disable, edit (undo, redo), flow settings, exit.

### REQ-EDT-120 Element settings dialog

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0007

The dialog is built from the parameter schema of the class. Field types used in v1: label, edit, multi-line edit, checkbox, radio, drop-down, combo box, list box, slider, file, folder, hotkey, week days, date and time, button. An icon next to each edit field shows its content type (expression, string, variable name). The element checks its settings while the user edits them (enable or disable fields, warnings such as "the variable name is not valid"). The important buttons stay visible in long dialogs. A help button opens the help of the element.

### REQ-EDT-130 Assistants in the element settings

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0007

Get window and control information by pointing at a window; choose a color or pick it from the screen; take a position with the mouse.

### REQ-EDT-140 Flow settings dialog

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0007

Execution policy (REQ-EXE-050), working directory (REQ-EXE-130), the type mode (REQ-VAR-100), and a button that shows the log of the flow.

### REQ-EDT-150 Warnings of the evaluation are visible in the editor

- **v1:** no
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004/S0005

The `f1` warnings of an element (for example a type error in compatibility mode) are shown at the element in the editor (E0034). Also the places of a migrated flow that carry a MIGRATION ID (REQ-MIG-040).

### REQ-EDT-160 Flow check with warnings

- **v1:** no (only the rules of REQ-EDT-070 while drawing a connection)
- **v2:** open (connections whose end is missing are logged when a flow is loaded, MIGRATION M-0013)
- **Prio:** should
- **Scope:** later
- **Plan:** -

The editor checks the whole flow against rules and shows a warning at the place of each violation. Examples of rules:

- The same connection with the same type joins the same two elements more than once.
- A ring of connections (not a loop element) makes more parallel branches on every pass.
- The inner path of a loop element is not closed: at least one way out of the inner path must lead back to the loop element (other ways may end). A connection to a connection point of another loop element is a warning too.
- A connection has no element at one of its ends.
- A connection leaves from an output that the element does not have (REQ-EXE-150).

Related: REQ-EDT-170 (refuse an invalid edit), REQ-EDT-180 (quick fixes), REQ-EDT-190 (help with variables from the same analysis).

### REQ-EDT-170 Refuse invalid edits

- **v1:** partial (the rules of REQ-EDT-070)
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Some rules of the flow check (REQ-EDT-160) are applied during each edit, and the editor refuses the action instead of warning afterwards, for example a connection to a connection point of the wrong loop element.

### REQ-EDT-180 Quick fixes for warnings

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

A warning of the flow check offers a fix in one click where the fix is clear, for example remove the duplicate connection, or remove the connection to the wrong loop element. A quick fix is one undo step.

### REQ-EDT-190 Help with variables from the flow analysis

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

The analysis of the flow (REQ-EDT-160) knows which variables can exist at an element. The element settings offer them for a quick choice, and mark in red a variable that is used but cannot have been set on any way to the element (for example never initialised).

### REQ-EDT-200 Expressions are checked while editing

- **v1:** no
- **v2:** open (the parser reports errors with their position, `EXPRESSION-LANGUAGE.md` section 10)
- **Prio:** should
- **Scope:** later
- **Plan:** - (could fit into S0007)

The element settings check every expression field and every script field (REQ-VAR-010, REQ-VAR-020) while the user types, and show a warning with the position of the error.

### REQ-EDT-210 Syntax highlighting and auto-completion

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Expression and script fields colour their syntax and complete names of variables and functions, as an IDE does.

## Settings (SET)

### REQ-SET-010 Global settings dialog

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

Settings are stored in the data folder and take effect at once where possible; a setting that needs a restart says so and offers it. The commands behind it (`cmd.settings.get/set`) are not built yet.

### REQ-SET-020 Defaults for execution policy and working directory

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

The global execution policy (REQ-EXE-050) and the global working directory (REQ-EXE-130).

### REQ-SET-030 Start with Windows

- **v1:** yes (a shortcut in the startup folder with the parameter `WindowsStartup`)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** - (not in the phase 3 plan)

AutoHotFlow starts when the user logs on to Windows, in the background. The start-up trigger knows that it was a start with Windows (REQ-TRG-220).

### REQ-SET-040 Run as administrator

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** - (not in the phase 3 plan)

AutoHotFlow restarts itself with administrator rights, so that flows can control windows of elevated programs. To check: all processes of a session must run with the same rights, or the pipes and wake-up messages fail (UIPI).

### REQ-SET-050 Logging settings

- **v1:** yes (levels for app, flow and thread; log to file)
- **v2:** partial (the level is a command-line option, `--log-level`)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/fault/test_diagnose.py::test_the_log_level_decides_what_is_forwarded_to_storage`

### REQ-SET-060 Own data folder

- **v1:** partial (a fixed folder `%APPDATA%\AutoHotFlow`)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_s1_acceptance.py` (the v1 folder stays untouched); every test runs with its own `--data` folder (`tests/conftest.py`)

v2 keeps its data in `%APPDATA%\AutoHotFlow v2`, or in the folder given by `--data` or `AHF_DATA_DIR` (E0033). It never writes into the folder of v1, so v1 and v2 can be used side by side.

### REQ-SET-070 Number of workers

- **v1:** n/a
- **v2:** partial (a command-line option `--workers`)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (E0044)

A global setting limits how many waiting elements run at the same time (REQ-EXE-100), and with it the memory of AutoHotFlow (REQ-PRF-030). Which limit exactly (the pool size or the guard of the supervisor) is detailed in S0004.

## Import and migration (MIG)

### REQ-MIG-010 v1 flows load as they are

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_storage.py::test_v1_flows_round_trip_through_storage_with_same_structure_and_types`, `tests/test_json_flows.py`, `tests/integration/test_flow_convert.py`

v1 flow files load without a conversion beforehand. Value types (text or number) are kept; unknown keys are kept and written back (`ARCHITECTURE.md` section 7, E0021).

### REQ-MIG-020 v1 variables load

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_storage.py::test_v1_variables_are_read_as_stored`, `tests/fault/test_var_persistence.py::test_v1_variable_files_are_loaded_changed_written_and_loaded_again`

Global and static variables in the v1 format (`.ahfvd`/`.ahfvar`, with or without BOM) load and keep their values.

### REQ-MIG-030 v1 expressions are converted on load

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/golden/test_golden_v2.py`, `tests/integration/test_flow_convert.py`

The expression texts of a v1 flow are converted into the new language when the flow is loaded. A converted formula gives the v1 result except for the deviations of the catalog (`EXPRESSION-LANGUAGE.md` section 15). The frozen v1 golden data (2161 cases) is the regression test of the converter (E0035).

### REQ-MIG-040 Places that need a fix are marked

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/test_migration_report.py`, `tests/test_migration_classes.py`

Every place of a loaded v1 flow that the loader cannot convert or that behaves differently carries its MIGRATION ID and keeps the v1 original text (E0035). `tools/migration_report.py` lists these places per flow. The editor shows them (REQ-EDT-150).

### REQ-MIG-050 Saved flows carry a format version

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_flow_convert.py::test_a_v1_flow_is_converted_saved_and_loaded_again_without_double_conversion`

v2 writes `formatVersion: 2`; loading a file saved by v2 converts nothing again. An element whose class is not known yet keeps its v1 text with the marker `v1Text` and is converted as soon as its class exists.

### REQ-MIG-060 Import from the v1 data folder

- **v1:** n/a
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

The user imports the flows and variables of v1 into the v2 data folder through the manager, with a report of the marked places. An automatic backup of the v1 data at the switchover may come later (E0021).

### REQ-MIG-070 Flows with missing element packages

- **v1:** yes (a dialog under the global lock; on "Yes" the file is deleted)
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0004

When a flow uses a package that is not installed, the manager asks the user whether the file shall be deleted; no dialog blocks the running flows (MIGRATION M-0008).

## Languages and help (LNG)

### REQ-LNG-010 User interface in several languages

- **v1:** yes (English, German, Russian, Korean)
- **v2:** partial (the language files of v1 load; English only, until the setting exists)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/ahk/core_lang.test.ahk`

All texts go through `Lang()` with the v1 language files (`assets/language/`). A missing text falls back to the key and is logged (MIGRATION M-0046).

### REQ-LNG-020 Choice of the language

- **v1:** yes
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

The language is the setting, or the language of Windows when nothing is set.

### REQ-LNG-030 Translated element texts

- **v1:** yes (language files per package)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0047), S0008

Names, categories and parameter labels of the elements are translated by the language files of their package.

### REQ-LNG-040 Help pages

- **v1:** yes (English only)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0007

A help window with general pages (welcome, variables, key list, color chart) and one page per element (REQ-ELM-020), opened from the manager and from the element settings.

### REQ-LNG-050 Translation tools for contributors

- **v1:** yes (language crawler and translation tool)
- **v2:** open
- **Prio:** could
- **Scope:** port
- **Plan:** -

A tool finds the texts in the code and helps to add the translations.

## Logging and diagnostics (DIA)

### REQ-DIA-010 Log files

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_storage.py` (the `test_log_*` and flood tests)

All processes log through the storage, the only writer of the files: a common log and one per source, in the v1 line format, renamed to `old` above 100 KB. No line is lost while other programs hold the files; a flood over the limit is counted, not silently dropped (MIGRATION M-0005, M-0016).

### REQ-DIA-020 Elements log what they do

- **v1:** yes (changelog 0.02.12: "All elements are logging now")
- **v2:** partial (the element API logs; the real elements are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002, S0008

Every element writes what it did and why it failed, with flow and element.

### REQ-DIA-030 Crash reports

- **v1:** no
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_report.py`

On a crash, a hang, a reached restart limit or many unhandled errors, a report folder is written with a snapshot of every process, the output of dead processes and the newest log files; at most one per minute, the last 20 are kept.

### REQ-DIA-040 Snapshots without user data

- **v1:** no
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_snapshot.py`

Each process answers a diagnostic snapshot (memory, handles, connections, log ring, last errors). It never contains contents of variables or flows.

### REQ-DIA-050 Debug window for developers

- **v1:** partial (`d()` with the setting `developing`, MIGRATION M-0021)
- **v2:** done (the manual check of the window is still open, `MANUAL-CHECKS.md` section 2; finding F-0064)
- **Prio:** should
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_debug_role.py`, `tests/fault/test_debug_dump.py`

A window shows the process table, the snapshot of each process, the live log, the events and values sent with `Debug.Dump`, and exports a report.

## Debugger (DBG)

The debugger is the long-term goal of decision E0001. It is not part of phase 3 (E0019), but nothing built now may prevent it (`ARCHITECTURE.md` 4.3).

### REQ-DBG-010 Pause and resume

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** phase 4

Pause an instance or a flow at any time and resume it.

### REQ-DBG-020 Breakpoints

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** phase 4

Execution stops before an element with a breakpoint.

### REQ-DBG-030 Single step and slow execution

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** phase 4

Execute one element at a time, or all of them with a pause between the steps, so that the user can follow the flow in the editor.

### REQ-DBG-040 Inspect and change variables while paused

- **v1:** partial (the condition `Debug_Dialog` shows variables during a run)
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** phase 4

### REQ-DBG-050 Edit the flow while debugging

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** phase 4

Changes apply at the next step, as in REQ-EXE-080.

## AI integration (AI)

A large extension after the port. Imported v1 flows (REQ-MIG-040) and user packages (REQ-PKG-040) are prepared so that an AI can work with them.

### REQ-AI-010 Connect any AI through a provider script

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

A global setting connects AutoHotFlow to an AI: a local model, a cloud API, or a command-line tool (Claude Code, GitHub Copilot, ...). Instead of fixed options, the setting points to an AutoHotkey script that follows a documented template. The user can write a connection to any AI; the template explains its interface so completely that the user can have an AI write it, also in a chat.

### REQ-AI-020 Elements that call the AI

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

Elements send a freely defined prompt to the connected AI and return its answer. The conversation history is kept in thread variables; other elements can save it in permanent variables, export it to a file or change it.

### REQ-AI-030 AI assistant in the editor

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

An AI in the editor analyses, changes and creates flows. It can read the logs of runs and, once the debugger exists (DBG), debug a flow step by step. Its references are the help of AutoHotFlow plus a system prompt and tools made for it.

### REQ-AI-040 AI-assisted import of v1 flows

- **v1:** n/a
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** - (after phase 3, E0035)

The AI gets the marked places of an imported flow (MIGRATION IDs, v1 originals, descriptions, REQ-MIG-040) and a system prompt made for the import, and proposes the fixes. This includes porting AutoHotkey v1 scripts to v2 (REQ-ELM-110, E0039).

### REQ-AI-050 Further AI elements

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Elements for other AI services, for example speech output or image generation.

## Distribution (DST)

### REQ-DST-010 Installer

- **v1:** yes (Inno Setup)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** phase 4 (R0007)

Installs AutoHotFlow with start menu entry and uninstaller.

### REQ-DST-020 Compiled program

- **v1:** yes (`AutoHotFlow.exe`)
- **v2:** partial (the supervisor and one entry script per role run with the installed interpreter; compiling is open)
- **Prio:** must
- **Scope:** port
- **Plan:** phase 4 (R0007)
- **Evidence:** `tests/integration/test_entry.py`, `tests/fault/test_role_entries.py`

The user does not need an installed AutoHotkey. Today the supervisor starts every other role from its own entry script (D0012, E0041); how the role scripts are compiled (one program or one per role) is decided in phase 4.

### REQ-DST-030 64 bit only

- **v1:** n/a (v1 is 32 bit)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_entry.py::test_the_32_bit_interpreter_is_rejected_with_exit_2_and_no_dialog`

A 32-bit interpreter is rejected at the start with exit code 2 (E0004).

### REQ-DST-040 Single instance and command line

- **v1:** partial (a second start replaces the running instance; commands through a hidden window)
- **v2:** partial (a second start shows the running manager; command forwarding exists; the commands for flows are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0008 (commands of the shortcut trigger)
- **Evidence:** `tests/fault/test_second_start.py`

A second start of AutoHotFlow does not start a second application: it passes its command line to the running one and ends (MIGRATION M-0023). Commands start a flow through a trigger (REQ-TRG-200, REQ-TRG-240).

### REQ-DST-050 Release checklist

- **v1:** yes (`Checklist before publishing.txt`: run all test flows, update translations, build and test the installer)
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** phase 4

## Robustness (ROB)

### REQ-ROB-010 A crashing or hanging process does not take the others with it

- **v1:** no (one process; a crash ends everything, a hang blocks everything)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_process_crash.py`, `tests/fault/test_process_hang.py`

The supervisor detects a crashed or frozen process, reports it and reacts by role: the engine and the storage are restarted, a UI or a worker is not. The other processes keep running and keep their connections. Running instances of an engine that crashes are lost (MIGRATION M-0001). Details: `ARCHITECTURE.md` section 6.2.

### REQ-ROB-020 No deadlocks and no races by design

- **v1:** no (a global lock; deadlocks and races were the reason for the port)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/test_architecture.py`, `tests/stress/` (repeated runs without a hang, MEASUREMENTS MS-0012 to MS-0017)

Processes exchange messages; there is no shared memory and no global lock, and every datum has exactly one owner. The forbidden patterns are checked automatically (`CONVENTIONS.md` section 3).

### REQ-ROB-030 Nothing waits without a deadline

- **v1:** no
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_timeouts.py`, `tests/fault/test_pipe_break.py`

No blocking call on the message path. Every request has a timeout; a late answer is dropped. When the target of a request goes away, the caller gets `peer_gone` at once.

### REQ-ROB-040 Recovery after a crash of the flow execution

- **v1:** no
- **v2:** partial (restart and resync work; re-arming the triggers needs the trigger host)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003 (triggers)
- **Evidence:** `tests/e2e/test_ui_stub.py::test_engine_restart_is_seen_and_resynced_without_restarting_the_stub`, `tests/fault/test_worker_lifecycle.py::test_engine_restart_during_a_worker_job_leaves_no_orphan_and_the_next_job_runs`

When the part that runs the flows (the engine) crashes, it starts again by itself. Open windows stay open and show the current state again; the triggers of enabled flows are active again. Instances that were running are lost (MIGRATION M-0001).

### REQ-ROB-050 Restart limits

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_supervisor.py::test_crashed_child_is_reported_within_1s_restarted_by_policy_and_others_are_untouched`, `tests/fault/test_worker_lifecycle.py::test_five_failures_within_a_minute_block_the_pool`, `tests/fault/test_diagnose.py::test_too_many_unhandled_errors_end_the_role_with_exit_6`

A process that keeps crashing is not restarted for ever (engine and storage: three attempts in 60 s; worker pool: five failures in 60 s). An unhandled error in a process is logged and the process keeps running, up to 20 errors in 60 s.

### REQ-ROB-060 Files are never half written

- **v1:** no (delete and append; a crash in between loses the file, MIGRATION M-0007)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_storage_abort.py`, `tests/integration/test_storage.py::test_backups_keep_exactly_ten_after_twelve_writes`

Flows and variables are written to a temporary file and renamed; a crash leaves the old or the new file. Up to ten backups of a flow are kept. A file that cannot be written is reported and the engine keeps its copy.

### REQ-ROB-070 Clean exit within a deadline

- **v1:** partial (a 4-second emergency brake, MIGRATION M-0010)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_shutdown.py`, `tests/e2e/test_ui_stub.py::test_cancelled_exit_is_answered_and_nothing_stops`

Exit has two phases: the user interfaces may ask the user and cancel; then all processes end in a fixed order within 5 s, after writing what is still queued. A process that does not end is ended hard.

### REQ-ROB-080 No orphan processes

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_orphans.py`, `tests/fault/test_worker_lifecycle.py::test_engine_killed_during_a_hanging_job_ends_the_worker_at_once_and_the_new_engine_builds_the_pool`

When the supervisor dies, every other process ends by itself within a few seconds. Workers end with their engine (E0010).

### REQ-ROB-090 Sleep and standby do not cause false alarms

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_supervisor_stall.py`

When the supervisor itself stood still (standby, heavy load), its deadlines are pushed back by that time, and no process is taken for hung (E0012).

### REQ-ROB-100 A storage that does not answer does not block the engine

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_var_persistence.py::test_frozen_storage_does_not_block_the_engine_and_the_write_happens_after_thawing`, `tests/integration/test_engine.py::test_engine_resumes_loading_when_storage_restarts_in_the_middle_and_loads_only_the_missing_files`

### REQ-ROB-110 A broken flow file does not stop the start

- **v1:** n/a (not checked)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_engine.py::test_broken_flow_file_is_reported_and_does_not_block_the_start`

The broken file is reported; all other flows load.

## Performance and resources (PRF)

The budgets are the targets of `ARCHITECTURE.md` section 9 and of the phase 3 plan. Measured on the owner's work computer, which is not idle (`MEASUREMENTS.md`).

### REQ-PRF-010 Message latency

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/stress/test_measurements.py::test_message_latency_idle_and_under_load_is_within_the_budget` (MEASUREMENTS MS-0001, MS-0002)

Engine and client through the hub: median below 5 ms, 99 % below 50 ms, also under load.

### REQ-PRF-020 Idle CPU

- **v1:** n/a (not measured)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/stress/test_measurements.py::test_idle_cpu_and_memory_of_the_chain_without_a_flow` (MS-0004: 0.23 %)

Below 1 % of the whole system without running flows (E0005).

### REQ-PRF-030 Memory

- **v1:** n/a (not measured)
- **v2:** partial (measured with 150 synthetic element classes, the manager stub and without trigger host: 49 MB with one worker, 68 MB with three; the real manager, the trigger host and the real elements are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003, S0004, S0008 (measure again)
- **Evidence:** `doc/MEASUREMENTS.md` (MS-0032, MS-0033), `tools/measure_r3.py`

The background processes (supervisor, storage, engine, trigger host, manager and the workers) need below 100 MB private bytes together in the normal state: small flows that run now and then, up to about three active workers. Editors are not counted; peaks with more workers may exceed the budget. The user can limit the number of workers (REQ-SET-070). Decision E0040, details `ARCHITECTURE.md` section 9.

### REQ-PRF-040 Start time

- **v1:** n/a (not measured)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/stress/test_measurements.py::test_start_to_ready_time` (MS-0008, MS-0009)

From the start until all processes are ready: below 3 s (with few flows).

### REQ-PRF-050 Many big flows load without blocking

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/stress/test_big_flows.py`, `doc/MEASUREMENTS.md` (MS-0030)

While 200 big flows load, AutoHotFlow stays responsive: the engine answers a snapshot within 3 s and no process is taken for hung (E0042; the budget was 1 s, finding F-0073 keeps the measurements). Loading flows only when they are needed is an optimization after the port (REQ-PRF-110).

### REQ-PRF-060 Editor redraw

- **v1:** n/a
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0005

A state change of the engine is visible in a non-blocked editor within 50 ms. A frame of a flow with 300 elements takes below 16 ms on average; otherwise drawing moves to its own process (risk R0002, `ARCHITECTURE.md` 2.1).

### REQ-PRF-070 Many instances and fast start and stop

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/stress/test_parallel_instances.py`, `tests/stress/test_start_stop_storm.py` (MS-0012, MS-0013)

200 parallel instances all end; 1000 start/stop cycles leave consistent states.

### REQ-PRF-080 Log throughput

- **v1:** no (about 30 lines/s, MEASUREMENTS MS-0021)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_storage.py::test_a_log_flood_is_written_at_more_than_1000_lines_per_second`, `tests/integration/test_storage.py::test_a_request_is_answered_in_time_during_a_log_flood` (MS-0022)

More than 1000 log lines per second; other requests to the storage are answered during a flood.

### REQ-PRF-090 Stable over long runs

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/stress/test_soak.py` (MS-0016, MS-0025)

Memory, handles and the number of processes stay flat over long runs.

### REQ-PRF-100 Each process parses only the element code it needs

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/test_element_includes.py`, `tests/fault/test_role_entries.py`, `doc/MEASUREMENTS.md` (MS-0027 to MS-0029, MS-0032, MS-0033)

Every role has its own entry script that includes only the element classes it needs, selected by their execution mode: the engine all, the trigger host the triggers, a worker the worker elements, the other roles none (E0041, risk R0003). With 150 element classes this lowered the memory of the background processes from 129 MB to 49 MB (one worker).

### REQ-PRF-110 Load flows only when they are needed

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** - (after the port, E0042)

The engine reads the list of flows at the start and loads a flow completely only when it is enabled, started or opened. This shortens the start with many big flows.

## Security (SEC)

### REQ-SEC-010 Inter-process communication is local and private

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/ahk/pipe_listener_security.test.ahk`

The pipes reject remote clients, allow only the system and the owner, and their names contain a session ID.

### REQ-SEC-020 Only the right process may start, end or report

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/integration/test_worker_pool.py` (spawn and kill from another sender are denied), `tests/fault/test_report.py::test_only_the_supervisor_may_write_reports`

### REQ-SEC-030 Sandbox for element code

- **v1:** no
- **v2:** dropped (non-goal, `ARCHITECTURE.md` section 1)
- **Prio:** could
- **Scope:** later
- **Plan:** -

Elements and AutoHotkey scripts run with the rights of the user. A flow from someone else is code; AutoHotFlow does not protect against a malicious flow or package.

## Testability (TST)

### REQ-TST-010 Automatic tests at several levels

- **v1:** partial (test flows with trace points, run by hand)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/` (unit, integration, e2e, fault, stress, characterization; `doc/TEST-STRATEGY.md`)

pytest drives everything; AHK unit tests run as real processes. Tests run in parallel, each with its own data folder, and never touch the user's data. A test can never hang (time limit, dialog guard).

### REQ-TST-020 Fault injection and stress

- **v1:** no
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/`, `tests/stress/`

Processes are killed, frozen and cut off on purpose; the system stays usable and reports the error.

### REQ-TST-030 Every element is tested headless

- **v1:** no
- **v2:** partial (the flow builder and the headless flow runner exist; the smoke test of every element and the dialog test provider are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0048, WI-0051)
- **Evidence:** `tests/support/test_flowbuilder.py`, `tests/integration/test_flowrun.py`

A smoke test covers every registered element; each element has end-to-end tests built with the flow builder and run by the headless flow runner; dialog elements are answered by a test provider (E0038).

### REQ-TST-040 The v1 test flows run green

- **v1:** yes (the "Automatic tests" flows)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (three flows, WI-0057), S0008 (all)

The "Automatic tests" flows of v1, adapted to v2 where needed, run headless and green.

### REQ-TST-050 Independent oracle for the expression language

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/oracle/test_expr_oracle.py`, `tests/golden/`

Generated expressions run as native AutoHotkey v2 code and in the evaluator; they may differ only by the listed deviations (E0035).

### REQ-TST-060 Manual checks of the user interfaces

- **v1:** n/a
- **v2:** partial (guide for the stub and the debug window; the stub passed on 2026-10-14, the debug window is not checked)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 to S0007
- **Evidence:** `doc/MANUAL-CHECKS.md`

What cannot be tested automatically has a written check for the project owner. Tests that open real windows run only on request (`gui` tier).

## Maintainability (MNT)

### REQ-MNT-010 English repository

- **v1:** yes
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `AGENTS.md` (rule), review

Code, comments, documents, log texts and commit messages are English, so that contributors worldwide can take part.

### REQ-MNT-020 Stock AutoHotkey v2

- **v1:** no (AutoHotkey_H 1.1 with threads)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** every test runs the stock 64-bit interpreter (`tools/ahkrun.py`)

No interpreter extensions; the program follows the official AutoHotkey v2 releases.

### REQ-MNT-030 Architecture rules are checked automatically

- **v1:** no
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/test_architecture.py`

### REQ-MNT-040 Elements can be ported largely mechanically

- **v1:** n/a
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0008 (E0036)

A converter `tools/convert_element.py` turns a v1 element into a v2 class; the hand-ported core set of S0002 serves as its test cases.

### REQ-MNT-050 Deliberate changes are documented

- **v1:** n/a
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `doc/MIGRATION.md`, `tests/test_migration_classes.py`

Every deliberate behaviour change compared to v1 has a MIGRATION ID; no silent changes.

## Usability (USE)

### REQ-USE-010 User level hides advanced elements

- **v1:** yes (Beginner, Advanced, Programmer)
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** - (not in the phase 3 plan; assumed S0007)

Each element has a level; the setting "Shown elements" hides the elements above the user's level, so beginners are not overwhelmed. The first start proposes a level (REQ-USE-050).

### REQ-USE-020 Experimental elements are marked

- **v1:** yes
- **v2:** open
- **Prio:** could
- **Scope:** port
- **Plan:** S0007

An experimental element is marked in the list and in its settings ("This element is experimental!").

### REQ-USE-030 Messages reach the user without blocking dialogs

- **v1:** partial (dialogs from the execution under the global lock, MIGRATION M-0008)
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0004

Errors and warnings that have no window of their own (for example a flow file that cannot be saved) reach the user as notices in the tray or the manager, never as a dialog that blocks the running flows.

### REQ-USE-040 The user interface stays responsive

- **v1:** no (the user interface waits for the global lock)
- **v2:** partial (the architecture separates the processes; the real user interfaces are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 to S0007

Manager and editors never freeze while flows run, because they are processes of their own.

### REQ-USE-050 The first start asks for the user's experience

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

At the first start AutoHotFlow asks how experienced the user is and preselects the options from the answer:

| Level | Hints (REQ-USE-060) | Packages (REQ-PKG-030) | Complex elements (REQ-USE-010) |
|---|---|---|---|
| Beginner | all hints and tips | basic package only | hidden |
| Advanced | all hints | basic package and the special packages whose dependencies are present | hidden |
| Expert | only the important hints | basic package and all special packages | shown |

After the choice of the level, every option can be changed on its own, there and later in the settings; the level only decides the preselection. Example of a complex element: the HTTP request with all its options, shown only to experts.

### REQ-USE-060 Amount of hints

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

A setting decides how much help AutoHotFlow shows: only the important hints, all hints, or all hints plus tips.

### REQ-USE-070 Hints can be switched off one by one

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

Every hint that is not critical (for example "take care with global variables", REQ-VAR-130) has an option "do not show again". The settings list the switched-off hints and can switch them on again. Critical hints cannot be switched off: messages about a concrete error, and warnings of the flow check such as duplicate connections or connections without an end (REQ-EDT-160).
