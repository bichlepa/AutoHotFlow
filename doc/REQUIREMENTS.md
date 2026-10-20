# Requirements

This document lists the important features and quality requirements of AutoHotFlow: what v1 can do, what v2 must do to replace it (the port), and what comes after the port. For each requirement it states whether v1 has it and how far v2 is.

**Overview:** [REQUIREMENTS-INDEX.md](REQUIREMENTS-INDEX.md) has one table row per requirement with its status and a link to its section here. Read the index for an overview; read a section here for the details.

A requirement says **what** AutoHotFlow does, not how: what the user sees or experiences. Internal parts (engine, worker, storage, processes) appear only where a quality requirement is about them, or as a reference for the details. The how is in the other documents (`ARCHITECTURE.md`, `PROTOCOL.md`, `ELEMENT-API-V2.md`, the decisions in `DECISIONS.md`); a requirement links to them instead of repeating them. Other documents refer to a requirement by its ID (`REQ-EXE-010`), not by a link to its heading, because the ID is stable and the heading anchor changes with the title.

**Sources of the first inventory (2026-10-14).** v1: the element manifest of the Default package (`v1/Source_Elements/Default/manifest.json`: 114 actions, 17 conditions, 5 loops, 16 triggers), the user interface texts of manager, editor, settings and tray, the settings defaults (`v1/Source_Common/Settings/Settings.ahk`), the changelog and the help folder; read, not run. v2: the code, the tests and the documents on `v2-port` at commit `9df8693` (WI-0045 verified); updated on 2026-10-15 for WI-0046, WI-0047-PREP, WI-0049, WI-0050 and the decisions E0040 to E0045. A step `S0001` to `S0010` is a step of the phase 3 plan (`work_items/phase3/README.md`).

## Format

Each area is a heading `## <Title> (<CODE>)`. Each requirement is a heading `### REQ-<CODE>-<nnn> <Title>` inside its area, followed by a list of fields and then free text (explanation, tables, sub-items, open questions):

```markdown
### REQ-XXX-000 Requirement name

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
| `Scope` | `port`, `later` | `port`: needed so that v2 replaces v1. `later`: after the port. |
| `Plan` | free text | Where the work is planned: a step (`S0004`), a work item (`WI-0052`), or `-` when nothing is planned. |
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
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0054)
- **Evidence:** `tests/ahk/engine_scheduler.test.ahk` (`Loop:` cases), `tests/ahk/element_loops.test.ahk`, `tests/integration/test_core_c_loops.py::test_break_in_the_first_a_middle_and_the_last_pass`, `tests/integration/test_core_c_loops.py::test_nested_loops_with_the_same_variable_names`, `tests/integration/test_core_c_loops.py::test_a_loop_left_through_exception_restores_the_variables_of_the_outer_loop`, `tests/integration/test_core_c_loops.py::test_a_stop_ends_a_loop_whose_body_waits`

A loop element has connection points: the head starts an iteration, a connection back to the tail starts the next one, a connection to the break point ends the loop. The loop variables (`A_Index` and the variables of the loop element) are visible inside the loop and restored when it is left, also with nested loops and when the loop element itself ends with `exception` (MIGRATION M-0019). An element in the body whose `exception` connection leads out of the loop does not restore them, as in v1 (ELEMENT-API-V2 7.1).

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
- **v2:** partial (the four policies work; `default` follows the global setting, which takes effect at once and is set in the settings dialog (WI-0078); the setting per flow comes with S0007)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (global setting, WI-0077, done)
- **Evidence:** `tests/integration/test_engine.py` (the `*_policy_*` tests), `tests/ahk/engine_wait.test.ahk`, `tests/integration/test_settings.py::test_the_global_execution_policy_decides_for_flows_set_to_default`

A flow decides what happens when it is triggered while an instance of it is still running:

| Policy | Behaviour |
|---|---|
| `parallel` | start another instance |
| `skip` | do not start; the start is answered with `busy` |
| `wait` | queue the start; it runs when the flow is idle |
| `stop` | stop the running instances, then start a new one |
| `default` | use the global setting (v1 default: `parallel`) |

The global setting is `executionPolicy` (default `parallel`, never `default`); it is read when a flow is started, so a change takes effect at once (WI-0077).

### REQ-EXE-060 Start and stop a flow by hand

- **v1:** yes
- **v2:** partial (the commands work; the buttons in manager and editor are missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (manager), S0006 (editor)
- **Evidence:** `tests/integration/test_engine.py` (`test_start_*`, `test_stop_*`, `test_toggle_starts_and_stops_a_flow`), `tests/e2e/test_manager_flows.py::test_a_running_flow_is_shown_as_running_while_it_runs`

The user starts a flow from the manager or the editor, through its default manual trigger or a chosen one, and stops it there. Stopping ends all running and waiting instances of the flow. Starting and stopping from inside a flow is REQ-EXE-120 and REQ-ELM-250; starting by an event is TRG.

### REQ-EXE-070 Enable and disable a flow

- **v1:** yes
- **v2:** partial (the enabled state of each trigger is kept, switched, reported and survives a restart of AutoHotFlow; the enabled triggers are armed and react, WI-0062; the real timer, start-up and hotkey triggers are in (WI-0063, WI-0064); the manager with S0004)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003 (WI-0060, WI-0062 and WI-0063 done, WI-0064 to WI-0066), S0004 (manager); the per-flow state files (E0063, WI-0068) are done
- **Evidence:** `tests/integration/test_trigger_state.py::test_an_unreadable_state_file_refuses_a_switch_until_it_can_be_read`, `tests/integration/test_engine.py::test_enable_and_disable_set_the_flag_and_report_it`, `tests/integration/test_engine.py::test_the_switched_state_survives_a_restart_of_the_engine`, `tests/ahk/engine_trigger_state.test.ahk`, `tests/integration/test_trigger_arming.py::test_disabling_the_flow_disarms_the_trigger_and_no_instance_starts_after_it`, `tests/e2e/test_manager_flows.py::test_disable_of_an_inactive_flow_with_independent_triggers_yes_disables_them`, `tests/e2e/test_manager_flows.py::test_a_switch_refused_for_an_unknown_state_yes_writes_the_state_of_the_session`

Enabling a flow activates its triggers that switch with the flow; disabling deactivates them (triggers that switch on their own: REQ-TRG-050). Running instances are not affected. The state survives a restart of AutoHotFlow. A flow file of v1 loads disabled (E0058). Decisions E0056, E0057.

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

An element that waits (a dialog, a program started with "wait", a download) does not delay other flows or other branches. A setting limits how many such elements wait at the same time (REQ-SET-070); further ones wait for their turn. An element that blocks although it is declared as quick is reported in the log, so that the mistake is noticed. How: worker processes, `ARCHITECTURE.md` sections 2.3 and 6.4.

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
- **v2:** done (MIGRATION M-0063; until S0003 a trigger counts as enabled when its flow is enabled)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0055)
- **Evidence:** `tests/integration/test_core_d_flows.py::test_execute_flow_waits_sends_and_returns_the_variables`, `tests/integration/test_core_d_flows.py::test_a_third_flow_runs_while_an_element_waits_for_another_flow`, `tests/integration/test_core_d_flows.py::test_default_trigger_and_specified_trigger_and_their_errors`, `tests/integration/test_core_d_flows.py::test_disabled_and_missing_flows`, `tests/integration/test_core_d_flows.py::test_the_called_flow_ends_with_an_exception_or_has_an_element_of_a_missing_package`, `tests/integration/test_core_d_flows.py::test_the_called_flow_is_stopped_while_the_caller_waits`, `tests/integration/test_core_d_flows.py::test_the_caller_is_stopped_while_it_waits_and_the_called_flow_runs_on`, `tests/integration/test_core_d_flows.py::test_a_flow_calls_itself_with_and_without_waiting_under_every_policy`, `tests/integration/test_core_d_flows.py::test_waiting_calls_of_a_flow_to_itself_are_limited`, `tests/ahk/engine_call_flow.test.ahk`

The action `Execute_Flow` starts a flow (this one or another) through its default trigger or a chosen manual trigger. Options: pass the local variables to the called flow, wait until it has finished, return its local variables to the caller, skip a disabled flow without error. While an element waits for the called flow, other flows and other branches go on. The waiting element ends with `exception` when the called flow ends with an unhandled exception or is stopped; a stopped caller leaves the called flow running. A call that could never end (the called flow has the policy `wait` and waits for the caller) and more than 100 calls that wait for each other end with `exception` instead of hanging.

### REQ-EXE-130 Working directory of a flow

- **v1:** yes
- **v2:** partial (`A_WorkingDir` and the file parameters use the global setting `workingDir` at once; the own folder of a flow is kept from the flow file, its editing comes with S0007)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (global, WI-0077, done), S0007 (flow settings)
- **Evidence:** `tests/ahk/vars_model.test.ahk`, `tests/integration/test_settings.py::test_the_global_working_directory_is_a_working_directory_of_flows_at_once`

Relative paths in file and folder parameters refer to the working directory. Each flow uses the global working directory (default `A_MyDocuments "\AutoHotFlow"`, the same as in v1, so imported flows find their files) or its own (flow setting). Decision E0028.

### REQ-EXE-140 Every element and flow shows its state

- **v1:** yes
- **v2:** done (the engine gives all element states of a flow at once, `cmd.flow.runstate`, WI-0086; the manager shows the state of every flow and its tree, WI-0074; the editor shows the running elements with the connection a thread took, the fade of a finished element, the exception look and the warnings, WI-0088 and WI-0089)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (manager), S0005 (editor)
- **Evidence:** `tests/integration/test_engine.py::test_start_emits_the_documented_event_order`, `tests/e2e/test_manager.py::test_engine_restart_is_seen_and_resynced_without_restarting_the_manager`, `tests/ahk/manager_model.test.ahk` (the model of the manager), `tests/e2e/test_manager_flows.py::test_a_running_flow_is_shown_as_running_while_it_runs`, `tests/e2e/test_editor.py::test_an_editor_opened_while_the_flow_runs_shows_the_running_element`, `tests/e2e/test_editor.py::test_a_running_element_and_its_connection_are_tinted_and_fade_out_after_the_end`, `tests/e2e/test_editor.py::test_an_exception_keeps_the_element_marked_and_its_message_is_kept`, `tests/ahk/editor_model.test.ahk` (the fades and the exception look)

Each element has a state (idle, running, finished, exception) and counts its runs. Each flow shows whether it is enabled and whether it runs, and its running and queued instances. Manager and editor show these states live, also a window that was opened later or that reconnected after a fault.

### REQ-EXE-150 Elements with any number of named outputs

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

An element can have any number of outputs, for example a switch with one output per case. The element and its configuration decide which outputs exist; the result of a run names the output (or several) to continue on. `yes`/`no` of a condition are the special case with two fixed outputs; `exception` stays a separate output of every element. Extends REQ-EXE-020.

Open points: a connection whose output disappears after a change of the configuration (a warning of the flow check, REQ-EDT-160, or refused by the editor); how the editor draws a variable number of connection points; the file format of the connection type (today a fixed set).

### REQ-EXE-160 Time limit per element

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Every element that can wait (REQ-EXE-100) has a setting "maximum run time". The element does not provide it itself: the element settings add it to every such element, for example in an "advanced" part. When the time is over, the element is stopped like a stopped instance (REQ-EXE-110) and ends with `exception` and the reason "time limit", so that the flow can react on the `exception` connection. Without a value there is no limit beyond the one of the element class. Extends REQ-EXE-110.

### REQ-EXE-170 Runaway flows are stopped

- **v1:** no
- **v2:** partial (the three limits work per flow with the defaults from MS-0036, set in the flow file; the notice (tray and manager list, WI-0075) is there; the global defaults and the global switch of the notice are settings and take effect at once (WI-0077); their dialog is there (WI-0078); the editing per flow (S0007) is missing)
- **Prio:** should
- **Scope:** port
- **Plan:** S0003 (WI-0066, done), S0004 (global defaults, WI-0077, done; the notice, WI-0075, done), S0007 (per flow, editing)
- **Evidence:** `tests/ahk/engine_runaway.test.ahk`, `tests/integration/test_settings.py::test_the_global_runaway_limit_stops_a_flow_without_its_own_limit`, `tests/integration/test_settings.py::test_a_limit_of_the_flow_wins_over_the_global_one`, `tests/integration/test_settings.py::test_the_global_limit_of_running_instances_refuses_a_start`, `tests/integration/test_settings.py::test_the_switch_for_notices_of_unhandled_errors`, `tests/integration/test_notices.py::test_a_stop_by_the_runaway_guard_gives_a_notice_with_the_limit`, `tests/integration/test_runaway.py::test_an_endless_loop_is_stopped_and_its_triggers_stay_disabled_after_a_restart`, `tests/integration/test_runaway.py::test_a_flood_of_refused_starts_is_answered_and_logged_a_few_times`

A flow that runs away does not disturb the others (decision E0062, after the model of the Android app AutoMagic). A flow that executes more elements per minute than its limit (the trigger of each new instance counts) is stopped and all its triggers are disabled, also those that do not switch with the flow; the user is told. A start that would exceed the limit of waiting instances (policy `wait`) or of running instances of a flow is refused like the policy `skip`; a flow that calls it learns this (`exception`). The limits have global defaults and can be changed per flow; 0 means no limit. The defaults are chosen so that a loop over a long list passes.

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

Expressions are checked while the user edits them: REQ-EDT-200. The language grows into a full script language: SCR.

### REQ-VAR-020 Script form for several statements

- **v1:** yes (action `Script`, marked experimental)
- **v2:** partial (the language has the script form; the element is missing)
- **Prio:** should
- **Scope:** port
- **Plan:** S0008 (element)
- **Evidence:** `tests/ahk/expr_script.test.ahk`

One statement per line: assignments, function calls, `if`/`else` and blocks (`EXPRESSION-LANGUAGE.md` section 8). Loops, error handling and own functions: SCR.

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
- **Evidence:** `tests/ahk/vars_model.test.ahk`, `tests/golden/test_golden_v2.py`, `tests/integration/test_core_b_lists.py::test_add_to_list_does_not_change_other_variables`

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
- **v2:** partial (`A_TriggerTime`, `A_TriggerID` and the values of `TriggerVariables` are set at every start, WI-0062; the values of the real triggers are missing, WI-0063 and WI-0064)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003
- **Evidence:** `tests/ahk/vars_model.test.ahk`, `tests/ahk/engine_trigger_arms.test.ahk` (TriggerVariables with and without the data of an event), `tests/integration/test_trigger_arming.py::test_an_enabled_trigger_is_armed_and_its_events_start_instances_with_their_variables`

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
- **v2:** done (both modes work; the engine counts the warnings per element, WI-0086; the editor shows them at the element, WI-0089)
- **Prio:** must
- **Scope:** port
- **Plan:** S0005 (display of the warnings, WI-0086, WI-0089)
- **Evidence:** `tests/ahk/element_evalparams.test.ahk` (strict mode case), `tests/integration/test_engine_runstate.py::test_strict_mode_gives_an_exception_and_no_warning`

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

### REQ-VAR-150 Several variables can refer to the same object

- **v1:** no (not checked)
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Assigning an object copies it (REQ-VAR-060), so two variables never share an object and a change through one is not seen through the other. Later a flow may let several variables refer to the same object: for example through a parameter of the elements that work on objects (copy or reference), or in scripts as in AutoHotkey (REQ-SCR-020).

Open points: a reference into another instance or into a permanent variable (REQ-VAR-050); what is saved for an object that several permanent variables share.

## Script language (SCR)

The expression language (REQ-VAR-010) and its script form (REQ-VAR-020) grow into a full script language: what a beginner builds from a chain of simple elements, an experienced user writes in a few lines. The language stays AutoHotkey v2 wherever it can (E0022, E0035), so that AutoHotkey users need to learn nothing new and the oracle (REQ-TST-050) checks every new part automatically. Elements stay the way for beginners; scripts are a second way, not a replacement.

Not the same as REQ-ELM-110: an AutoHotkey script there is real AutoHotkey code in a process of its own, with full access to the system and without the flow variables. The script language runs inside AutoHotFlow, works on the flow variables and is checked by the editor.

### REQ-SCR-010 Built-in functions

- **v1:** no (`round`, `object` and `print` existed but could never be called)
- **v2:** partial (four functions: `round`, `object`, `print`, `mod`)
- **Prio:** should
- **Scope:** later
- **Plan:** -

The language has a library of functions with the names, parameters and results of AutoHotkey v2:

| Group | Examples |
|---|---|
| Strings | `StrLen`, `SubStr`, `InStr`, `StrReplace`, `StrSplit`, `Trim`, `StrUpper`, `StrLower`, `StrTitle`, `Format`, `Ord`, `Chr`, `Sort` |
| Regular expressions | `RegExMatch`, `RegExReplace` |
| Numbers | `Abs`, `Ceil`, `Floor`, `Round`, `Mod`, `Min`, `Max`, `Sqrt`, `Exp`, `Log`, `Ln`, `Sin`, `Cos`, `Tan`, `ASin`, `ACos`, `ATan`, `Random` |
| Types | `IsNumber`, `IsInteger`, `IsFloat`, `IsSpace`, `IsAlpha`, `IsDigit`, `Type`, `Integer`, `Float`, `String`, `Number` |
| Date and time | `FormatTime`, `DateAdd`, `DateDiff` |
| Data formats | JSON text to object and back (an addition of AutoHotFlow; the elements are in REQ-ELM-310) |

Every function is documented in the help and checked by the oracle like the operators; a function that deliberately differs from AutoHotkey v2 is on the list of deviations.

Open point: functions that change something outside the flow (write a file, start a program, send keys). In the graph of a flow the user sees what the flow does; a script hides it. Proposal: the language gets functions that only read (`FileExist`, `DirExist`, `WinExist`, `ProcessExist`, ...) and changes stay elements, or are called through REQ-SCR-090.

### REQ-SCR-020 Methods and properties of lists and objects

- **v1:** no
- **v2:** open (calling a method is an evaluation error)
- **Prio:** should
- **Scope:** later
- **Plan:** -

Lists and objects are changed inside an expression, with the methods and properties of AutoHotkey v2 `Array` and `Map`: `list.Push(x)`, `list.Pop()`, `list.InsertAt(i, x)`, `list.RemoveAt(i)`, `list.Length`, `obj.Has(key)`, `obj.Delete(key)`, `obj.Count`, `obj.Clone()`; going through all members is REQ-SCR-030.

Open points:

- A list is an object with the keys 1..n (REQ-VAR-060), not an AutoHotkey `Array`. The methods of `Array` must work on it; the oracle needs a rule for the differences (a gap in the keys, negative indexes).
- Assigning an object copies it (REQ-VAR-060), so `a := b` followed by `a.Push(1)` leaves `b` unchanged, unlike AutoHotkey. This must be decided and documented before methods exist; references to the same object are REQ-VAR-150.

### REQ-SCR-030 Loops and error handling in scripts

- **v1:** no
- **v2:** partial (`if`/`else` and blocks, `EXPRESSION-LANGUAGE.md` section 8)
- **Prio:** should
- **Scope:** later
- **Plan:** -

As in AutoHotkey v2: `Loop n`, `Loop` with `until`, `while`, `for key, value in obj`, `break`, `continue`; `try`, `catch`, `finally`, `throw`. Loops make REQ-SCR-050 necessary.

### REQ-SCR-040 Own functions

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

The user defines own functions and calls them from expressions. Three ways, which can exist side by side:

| Way | How it works |
|---|---|
| In a script | A function defined in a script can be called from every expression of the same flow. Variables inside the function are local to it. |
| A flow as a function | A flow with the trigger "Function call" (REQ-TRG-200) declares its parameters. Calling it from an expression starts the flow with the arguments, waits until it ends (as `Action_Execute_Flow` with waiting, REQ-EXE-120) and returns its result. A beginner builds a function from elements, and an experienced user calls it in one line. |
| A library | A file of functions that all flows share, written in the script language or as AutoHotkey v2 code (REQ-ELM-110). |

Open points: where a library is stored and how a change reaches running instances (REQ-EXE-080); a flow called as a function waits, so the expression that calls it waits too (as in REQ-SCR-090); AutoHotkey code runs in a process of its own, so a call of its functions is slow.
### REQ-SCR-050 A script cannot hang AutoHotFlow

- **v1:** n/a
- **v2:** open
- **Prio:** must
- **Scope:** later
- **Plan:** -

An endless loop or a very long calculation in a script does not delay other flows (REQ-EXE-100). A script has a limit of time or of steps; when it is reached, the element ends with `exception` and says why. Stopping the flow ends a running script at once (REQ-EXE-110). The limit can be changed per element (REQ-EXE-160).

Open point: whether a long script runs in a worker or is interrupted in the engine. Today a script cannot loop, so the question does not arise yet.

### REQ-SCR-060 Errors name the place in the script

- **v1:** no
- **v2:** partial (expression errors carry line and column, `EXPRESSION-LANGUAGE.md` section 10)
- **Prio:** should
- **Scope:** later
- **Plan:** -

Every error and warning of a script names the line, the column and the statement, in the log and at the element in the editor (REQ-EDT-150). An error that is not caught ends the element with `exception` (REQ-EXE-090); an error caught with `try` does not.

### REQ-SCR-070 Script editor

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

A script field is a small code editor: line numbers, indentation with Tab, matching brackets, a window that can be enlarged. Checking while typing: REQ-EDT-200; syntax colours and completion: REQ-EDT-210.

### REQ-SCR-080 Elements and functions behave the same

- **v1:** n/a
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Each element of the simple groups (calculations, strings, lists, date and time; REQ-ELM-200 to REQ-ELM-280) has a function or method with the same behaviour, and the help of each points to the other. A beginner uses the element, an experienced user writes one line, and the result is the same. Best when both share one implementation, so that they cannot drift apart.

### REQ-SCR-090 Call elements from a script

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -
- **Doubt:** The graph no longer shows what the flow does, and a script that calls a waiting element (REQ-EXE-100) must wait itself. The benefit may not be worth it.

A script calls an element of any package like a function, with its parameters, and gets its result and its output variables. So a script can do everything an element can.

### REQ-SCR-100 Step through a script in the debugger

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

The debugger (DBG) runs a script line by line, with breakpoints on lines, and shows the variables of the script and of its functions.

### REQ-SCR-110 Script variants of conditions, loops and triggers

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Every kind of element can be written as a script, not only an action (`Action_Script`, REQ-VAR-020):

| Element | What the script does |
|---|---|
| Condition | its result decides between "yes" and "no" |
| Loop | the loop repeats as long as an expression is true, or the script decides at each pass |
| Trigger | the trigger checks an expression at a fixed interval and fires when it becomes true, for example `FileExist(path) && A_Hour >= 8` |

The trigger can be built with a timer, a condition and a few elements, but then the flow starts at every check and writes to the log each time. The script trigger starts the flow only when the expression has become true.

### REQ-SCR-120 Try out expressions

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

A field in the editor evaluates an expression or a short script at once and shows the result and the warnings, with values that the user enters. In the debug dialog (REQ-DBG-060) and in the debugger (DBG) the same field works on the variables of the halted branch.

### REQ-SCR-130 Tests for own functions

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

The user writes test scripts for own functions and flows called as functions (REQ-SCR-040): call with given arguments, compare the result with the expected one. AutoHotFlow runs the tests on request and reports which failed and why. The tests are code like the functions; there is no separate editor for test cases.

### REQ-SCR-140 Script templates

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

Ready-made pieces of script that the user inserts and adapts, for example "format a date", "filter a list", "read a value from JSON". The user can save own templates. Templates for element settings: REQ-EDT-220.

### REQ-SCR-150 Types of function parameters

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

The parameters and the result of an own function (REQ-SCR-040) may carry a type (number, text, list, object). The editor uses it to check calls (REQ-EDT-200) and to offer completion (REQ-EDT-210); a call with a wrong type is a warning, in strict mode an error (REQ-VAR-100).

## Element packages (PKG)

### REQ-PKG-010 Elements are organised in packages

- **v1:** yes
- **v2:** partial (the package `Default` with its description, element files, language files and icons, one generated include block per package and role; the help pages are missing)
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

Open point (assumed, not checked): AutoHotkey reads all `#Include` files when a script starts, and a syntax error in one of them stops the whole script. Engine and editor include every element class (E0041), so one broken element file stops both. A compiled program cannot include files at run time at all (REQ-DST-020). So packages from users need their own way of loading, for example a check of the package in a separate process before it is used, or running its elements in separate processes. To be designed before REQ-PKG-020 and REQ-PKG-040.

### REQ-PKG-060 The package name is part of the identity of an element

- **v1:** partial (the flow files store the package of each element, but the class name alone identifies it)
- **v2:** done (registry, flow lookup, worker jobs and logs use `<package>.<class>`; two packages with a class of the same name run in one session)
- **Prio:** should
- **Scope:** port
- **Plan:** S0002 (WI-0047, decision E0045)
- **Evidence:** `tests/integration/test_packages.py`, `tests/ahk/element_registry.test.ahk`, `tests/ahk/engine_flow_convert.test.ahk`, `tests/test_element_includes.py::test_two_packages_with_a_class_of_the_same_name_load_in_one_process`

Every element is identified by its package and its class, also the elements of v1. So elements of different packages may have the same class name. The flow files of v1 already store the package of each element; where it is missing, it is `Default`. How: decision E0045.

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
- **v2:** partial (`Action_New_Variable` is done in S0002; the calculations and `Action_Script` are S0008)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0052), S0008
- **Evidence:** `tests/integration/test_core_a_elements.py::test_new_variable_sets_texts_numbers_and_lists`, `tests/integration/test_core_a_elements.py::test_new_variable_only_if_not_exist`, `tests/integration/test_core_a_elements.py::test_new_variable_scopes_and_invalid_names`, `tests/integration/test_core_a_elements.py::test_the_v1_flow_variable_test_runs_up_to_the_first_result_list`

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_New_Variable` | yes | done | S0002 (WI-0052) |
| `Action_Random_Number` | yes | open | S0008 |
| `Action_Absolute_Number` | yes | open | S0008 |
| `Action_Square_Root` | yes | open | S0008 |
| `Action_Trigonometry` | yes | open | S0008 |
| `Action_Rounding_a_number` | yes | open | S0008 |
| `Action_Exponentiation` | yes | open | S0008 |
| `Action_Script` (REQ-VAR-020) | yes | open | S0008 |

### REQ-ELM-210 Conditions on values

- **v1:** yes
- **v2:** done (strict and compatibility mode; MIGRATION M-0052 to M-0054)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0052)
- **Evidence:** `tests/integration/test_core_a_elements.py::test_condition_expression_decides_yes_or_no`, `tests/integration/test_core_a_elements.py::test_variable_content_is_every_type_for_every_value`, `tests/integration/test_core_a_elements.py::test_number_is_with_absolute_and_relative_difference`, `tests/integration/test_core_a_elements.py::test_variable_is_empty`, `tests/integration/test_core_a_elements.py::test_the_v1_flow_numbers_runs_its_number_is_checks`

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Condition_Expression` | yes | done | S0002 (WI-0052) |
| `Condition_Variable_Is_Empty` | yes | done | S0002 (WI-0052) |
| `Condition_Variable_content_is` | yes | done | S0002 (WI-0052) |
| `Condition_NumberIs` | yes | done | S0002 (WI-0052) |

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
- **v2:** partial (the seven list elements are done in S0002; `Action_Get_from_list` and the conversions are S0008)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0053), S0008
- **Evidence:** `tests/integration/test_core_b_lists.py::test_new_list_creates_empty_and_filled_lists`, `tests/integration/test_core_b_lists.py::test_add_to_list_every_position_and_method`, `tests/integration/test_core_b_lists.py::test_get_list_info_all_four_infos`, `tests/integration/test_core_b_lists.py::test_list_contains_element_key_and_content`, `tests/integration/test_core_b_lists.py::test_delete_from_list_every_position_and_method`, `tests/integration/test_core_b_lists.py::test_get_index_of_element_in_list`, `tests/integration/test_core_b_lists.py::test_shuffle_list_keeps_content_and_count`, `tests/integration/test_core_b_lists.py::test_the_v1_flow_list_test_runs`, `tests/ahk/element_list_ops.test.ahk`

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_New_List` | yes | done | S0002 (WI-0053) |
| `Action_Add_to_list` | yes | done | S0002 (WI-0053) |
| `Action_Get_list_info` | yes | done | S0002 (WI-0053) |
| `Action_Delete_from_list` | yes | done | S0002 (WI-0053) |
| `Action_Get_index_of_element_in_list` | yes | done | S0002 (WI-0053) |
| `Action_Shuffle_list` | yes | done | S0002 (WI-0053) |
| `Condition_List_Contains_Element` | yes | done | S0002 (WI-0053) |
| `Action_Get_from_list` | yes | open | S0008 |
| `Action_Convert_list_to_string` | yes | open | S0008 |
| `Action_Convert_string_to_list` | yes | open | S0008 |

The differences from v1 that the list elements bring are in MIGRATION M-0057 and M-0058.

### REQ-ELM-240 Loops

- **v1:** yes
- **v2:** partial (the four loops of the core set are done in S0002; `Loop_Loop_Through_Files` is S0008)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0054), S0008
- **Evidence:** `tests/integration/test_core_c_loops.py::test_every_loop_makes_its_passes_and_removes_its_variables`, `tests/integration/test_core_c_loops.py::test_simple_loop_counts`, `tests/integration/test_core_c_loops.py::test_condition_loop`, `tests/integration/test_core_c_loops.py::test_condition_loop_converts_the_v1_text_on_load`, `tests/integration/test_core_c_loops.py::test_list_loop`, `tests/integration/test_core_c_loops.py::test_list_loop_works_through_the_copy_it_made_at_the_start`, `tests/integration/test_core_c_loops.py::test_parse_loop`, `tests/ahk/element_loops.test.ahk`

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Loop_SimpleLoop` | yes | done | S0002 (WI-0054) |
| `Loop_Condition` | yes | done | S0002 (WI-0054) |
| `Loop_Parse_A_String` | yes | done | S0002 (WI-0054) |
| `Loop_Work_through_a_list` | yes | done | S0002 (WI-0054) |
| `Loop_Loop_Through_Files` | yes | open | S0008 |

Connection points and loop variables: REQ-EXE-030. The differences from v1 are in MIGRATION M-0059 to M-0061. A pass of a loop costs about 0.3 ms in the engine (MEASUREMENTS MS-0034); a loop of 100,000 passes does not block the engine, other flows and requests are served meanwhile.

### REQ-ELM-250 Flow control

- **v1:** yes
- **v2:** partial (`Action_Sleep`, `Action_Do_nothing`, `Condition_Do_nothing`, `Action_Execute_Flow`, `Action_Stop_Flow` and `Condition_Flow_Running` exist; `Action_Set_Flow_Status` and `Condition_Flow_Enabled` (WI-0065) exist; `Action_Set_element_parameter` is open)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0047, WI-0052, WI-0055), S0003, S0008
- **Evidence:** `tests/ahk/element_sleep.test.ahk`, `tests/integration/test_core_a_elements.py::test_action_do_nothing_finishes_with_normal_or_exception`, `tests/integration/test_core_a_elements.py::test_condition_do_nothing_finishes_with_the_chosen_result`, `tests/integration/test_core_d_flows.py::test_stop_flow_stops_running_and_queued_instances_and_its_own_flow`, `tests/integration/test_core_d_flows.py::test_flow_running_sees_running_and_queued_instances`, `tests/ahk/engine_call_flow.test.ahk`, `tests/integration/test_flow_status_elements.py::test_set_flow_status_every_choice_for_another_flow`, `tests/integration/test_flow_status_elements.py::test_condition_flow_enabled_every_choice`

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Sleep` | yes | partial (skeleton) | S0002 (WI-0047) |
| `Action_Do_nothing` | yes | done | S0002 (WI-0052) |
| `Condition_Do_nothing` | yes | done | S0002 (WI-0052) |
| `Action_Execute_Flow` (REQ-EXE-120) | yes | done | S0002 (WI-0055) |
| `Action_Stop_Flow` | yes | done | S0002 (WI-0055) |
| `Condition_Flow_Running` | yes | done | S0002 (WI-0055) |
| `Action_Set_Flow_Status` | yes | done | S0003 (WI-0065) |
| `Condition_Flow_Enabled` | yes | done | S0003 (WI-0065) |
| `Action_Set_element_parameter` | yes | open | S0008 |

### REQ-ELM-260 Trace points

- **v1:** yes
- **v2:** done (MIGRATION M-0055, M-0056)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0052)
- **Evidence:** `tests/integration/test_core_a_trace_points.py::test_trace_point_check_every_option`, `tests/integration/test_core_a_trace_points.py::test_trace_points_belong_to_the_instance_and_are_hidden`, `tests/integration/test_core_a_trace_points.py::test_trace_point_log_message_and_stop_condition`, `tests/integration/test_core_a_trace_points.py::test_trace_point_stops_every_thread_of_the_instance`

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Trace_Point` | yes | done | S0002 (WI-0052) |
| `Action_Trace_Point_Check` | yes | done | S0002 (WI-0052) |

They record the path through a flow and check it; automatic test flows use them (REQ-TST-040).

### REQ-ELM-270 Dialogs and notifications

- **v1:** yes
- **v2:** partial (four of seven elements; the input box, the file and folder selection are S0008)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0051, WI-0056), S0008

| Element | v1 | v2 | Plan |
|---|---|---|---|
| `Action_Message_Box` | yes | partial (headless tests; real window by gui test) | S0002 (WI-0056) |
| `Action_Tooltip` | yes | partial (worker, headless tests; real tooltip by gui test) | S0002 (WI-0056) |
| `Condition_Confirmation_Dialog` | yes | partial (headless tests; real window by gui test) | S0002 (WI-0056) |
| `Condition_Debug_Dialog` (REQ-DBG-060) | yes | partial (headless tests; real window by gui test) | S0002 (WI-0056) |
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

### REQ-ELM-310 Structured data files

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
| JSON: read a file or text into an object, write an object as JSON | no | open | later |
| YAML: read and write | no | open | later |
| XML: read, query (XPath) and write | no | open | later |

JSON text can also be converted in an expression (REQ-SCR-010).

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
| Run a program and get its output (stdout, stderr) and its exit code | no | open | later |
| Talk to a console program: send input and read its output while it runs | no | open | later |

Talking to a console program is an element of its own, because it is much more complex than running a program: the program runs on while the flow sends input and reads output.

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
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** S0003 (measured, MS-0038 and MS-0040)
- **Evidence:** `tests/stress/test_trigger_host_busy.py` (WI-0067: the host keeps its timer and its hotkeys, plain and hook, while the engine is blocked for 3 s; no event lost; the hook works after the block), `tests/integration/test_triggerhost.py` (WI-0061: an error of one trigger is reported, the others and the host keep running), `tests/integration/test_trigger_arming.py` (WI-0062: the engine arms the triggers, a refused or failing trigger does not stop the others)

Hotkeys, hooks and timers react at once, no matter how busy the running flows are (Windows removes a low-level hook that answers too slowly). An error of one trigger (a hotkey that cannot be registered) is reported and does not stop the others. How: a trigger host process, `ARCHITECTURE.md` D8. The engine arms the triggers of the enabled flows (WI-0062). Measured without keys (MS-0038): while the engine is blocked for 3 s, the host keeps its timer on schedule, and the engine processes the queued events after the block. The same with real keys on a plain and a hook hotkey (MS-0040): the keys sent during the block are processed right after it, none is lost, and the hook still works.

### REQ-TRG-020 Triggers follow the enabled state, also after a restart

- **v1:** yes
- **v2:** partial (the arming works for the test triggers and for the timer and start-up triggers, with the restarts of the engine and of the trigger host; the hotkey trigger works with real keys, MS-0040)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003 (done), S0008 (the other trigger types)
- **Evidence:** `tests/integration/test_trigger_arming.py` (WI-0062: an enabled trigger is armed and fires, disabling disarms it, the startup trigger fires once per start, a restart of the engine or of the host re-arms), `tests/integration/test_time_triggers.py` (WI-0063), `tests/integration/test_hotkey_arming.py` (WI-0067: the hotkey trigger is armed, disarmed and re-armed after a restart of the trigger host; no keys are sent), `tests/ahk/engine_trigger_arms.test.ahk`

The enabled triggers are active from the start of AutoHotFlow on, and again after an internal restart (REQ-ROB-040); disabling a flow deactivates the triggers that switch with it (REQ-EXE-070).

### REQ-TRG-040 Conflicting hotkeys are reported

- **v1:** no (not checked)
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

When two enabled flows, or two triggers of one flow, use the same hotkey or hotstring in the same context, AutoHotFlow warns: in the trigger settings when the hotkey is chosen, and in the manager when the second flow is enabled. A hotkey that cannot be registered because another program uses it is reported as well (REQ-TRG-010).

### REQ-TRG-030 Several triggers per flow

- **v1:** yes
- **v2:** partial (each trigger has its own enabled state and can be switched on its own; no trigger is armed yet, and the editor cannot add or switch one yet)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003 (WI-0060 done), S0006
- **Evidence:** `tests/ahk/engine_trigger_state.test.ahk`, `tests/integration/test_engine.py::test_switches_report_the_trigger_states_and_the_independent_count`

A flow can have several triggers. Each trigger can be enabled and disabled on its own, and can be set to switch with the flow or on its own (REQ-TRG-050). One manual trigger is the default trigger, used when the flow is started without naming a trigger.

### REQ-TRG-050 Triggers that switch with the flow or on their own

- **v1:** no (every trigger switches with the flow)
- **v2:** partial (the engine has the option "switch with the flow" and the independent triggers, and the flow is active by the following ones only; the elements Set flow status and Flow enabled switch and ask by it (WI-0065); the manager and the editor are missing)
- **Prio:** should
- **Scope:** port
- **Plan:** S0003 (WI-0060 done, WI-0065 done), S0004 (manager), S0007 (editor)
- **Evidence:** `tests/ahk/engine_trigger_state.test.ahk`, `tests/integration/test_engine.py::test_switches_report_the_trigger_states_and_the_independent_count`, `tests/integration/test_engine.py::test_a_flow_without_a_following_trigger_answers_with_a_message`, `tests/integration/test_flow_status_elements.py::test_set_flow_status_every_choice_for_another_flow`, `tests/integration/test_flow_status_elements.py::test_condition_flow_enabled_every_choice`, `tests/e2e/test_manager_flows.py::test_disable_of_an_inactive_flow_with_independent_triggers_yes_disables_them`

Each trigger has the option "Switch with the flow", on by default, so that a flow behaves as in v1 (decision E0056).

- A trigger that switches with the flow is enabled and disabled together with the flow. The flow counts as active when at least one of these triggers is enabled; enabling one of them by itself makes the flow active.
- A trigger that switches on its own is enabled and disabled only by itself: in the editor or by an element of a flow. It does not make the flow active, and it stays enabled when the flow is disabled. Use: a trigger that other elements switch on and off, while the rest of the flow is enabled or disabled as a whole.
- The state of every trigger survives a restart of AutoHotFlow (REQ-EXE-070).
- The manager shows when a flow is inactive but has active triggers of its own. When the user disables such a flow by hand, the manager asks whether to disable these triggers too; the question says that they can then be enabled again by hand only in the editor.
- Elements can switch and query the flow, all its triggers, its triggers of their own, its default trigger and a given trigger (REQ-ELM-250).
- A flow stopped by the runaway guard has all its triggers disabled, also those of their own (REQ-EXE-170).

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
| Function call: declares parameters, gets the arguments and returns a result (REQ-SCR-040) | no | open | later |

Started by the user, by another flow (REQ-EXE-120) or through the command line (REQ-DST-040).

### REQ-TRG-210 Time triggers

- **v1:** yes
- **v2:** partial (the periodic timer; the time of day is missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003 (WI-0063 done), S0008
- **Evidence:** `tests/integration/test_time_triggers.py` (WI-0063: the periodic timer fires about every interval, never faster, stops on disable, and refuses a bad interval or unit with the v1 text)

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Periodic_Timer` | yes | done (WI-0063) | S0003 (WI-0063 done) |
| `Trigger_Time_of_Day` (with week days) | yes | open | S0008 |

### REQ-TRG-220 Start-up and system triggers

- **v1:** yes
- **v2:** partial (the start-up trigger of AutoHotFlow and of Windows; the system triggers are later)
- **Prio:** must
- **Scope:** port
- **Plan:** S0003 (WI-0063 done), later
- **Evidence:** `tests/integration/test_time_triggers.py` (WI-0063: Trigger_Start_up fires once per start of AutoHotFlow, the Windows type only with --windows-startup, not when enabled later, and not after a restart of the trigger host)

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Start_up` | yes | done (WI-0063) | S0003 (WI-0063 done) |
| Windows resumes from standby or hibernation | no | open | later |
| Windows shuts down or the user logs off (the flow runs before) | no | open | later |
| A USB device or a drive is connected or removed | no | open | later |
| A network connection is established or lost | no | open | later |

Fires when AutoHotFlow starts; it can tell a start with Windows (REQ-SET-030) from a start by hand.

### REQ-TRG-230 Keyboard triggers

- **v1:** yes
- **v2:** partial
- **Prio:** must
- **Scope:** port
- **Plan:** S0003, S0008
- **Evidence:** `tests/ahk/element_hotkey.test.ahk` (WI-0064: the hotkey text of every option, the window condition of each UseWindow value, two triggers on one hotkey share it), `tests/ahk/element_window_ident.test.ahk` (the window identification), `tests/integration/test_hotkey_input.py` (WI-0064: real keys with `SendInput` on unassigned keys: plain, `~`, release, the window conditions, two flows on one key, disabling one of them, an error of one trigger; the combinations with modifiers are `gui` tests for the project owner)

| Trigger | v1 | v2 | Plan |
|---|---|---|---|
| `Trigger_Hotkey` | yes | done | S0003 |
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
| The session is locked or unlocked | no | open | later |

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
- **v2:** partial (WI-0074: the tree is built from the model with the category order and the state marks: enabled, disabled, running, state unknown, independent triggers active, stopped by a limit, trigger not available; E0079: a running flow shows the number of its running instances, the count is in the snapshot and in `evt.flow.state` (tested); the text of the tree item is not checked by a test (F-0121), the look of the tree is checked by a gui test only, by the owner)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/e2e/test_manager_flows.py::test_a_running_flow_is_shown_as_running_while_it_runs`, `tests/e2e/test_manager_flows.py::test_the_running_instances_are_counted_in_the_snapshot_and_the_state`, `tests/e2e/test_manager_flows.py::test_new_flow_is_added_to_the_list_and_another_client_sees_its_flow_too`, `tests/fault/test_manager_window.py::test_the_tree_shows_each_category_and_the_flow_below_its_category (gui)`

The manager shows all flows in a tree of categories, with their state (enabled, running). A running flow shows how many of its instances run. Flows without a category are under "Uncategorized".

### REQ-MGR-020 Create, rename, duplicate and delete flows

- **v1:** yes
- **v2:** partial (WI-0074: create, duplicate, rename and delete run through the model with their checks and questions, both answers tested headless; the dialogs and the context menu are checked by the owner only)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/integration/test_flow_lifecycle_engine.py` (`test_create_*`, `test_duplicate_*`, `test_rename_*`, `test_delete_*`), `tests/integration/test_flow_lifecycle.py` (storage part), `tests/e2e/test_manager_flows.py::test_duplicate_makes_a_copy_with_the_next_name`, `tests/e2e/test_manager_flows.py::test_delete_answered_yes_removes_the_flow_for_good`, `tests/e2e/test_manager_flows.py::test_rename_with_the_dialog_refuses_a_taken_name_before_the_engine`

Names are checked: no forbidden characters, no second flow with the same name. Deleting asks for confirmation. Deleting a running flow stops its instances at once (E0009). Deleting is final: the flow, its enabled state and its static variables are removed (E0066); a deletion that can be undone is REQ-MGR-150.

### REQ-MGR-030 Manage categories

- **v1:** yes
- **v2:** partial (WI-0074: create, rename, delete with the choice of the flows target, sort, order of the categories and moves between categories run through the model and are tested headless; the drag and drop with the mouse is checked by a gui test only, by the owner)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/integration/test_categories.py` (`test_the_order_and_an_empty_category_survive_a_restart`, `test_rename_writes_every_flow_file_and_keeps_the_place`, `test_delete_moves_the_flows_first_and_then_removes_the_category`, `test_a_broken_file_is_kept_and_the_order_is_built_from_the_flows`), `tests/ahk/engine_categories.test.ahk`, `tests/e2e/test_manager_flows.py::test_sort_alphabetically_orders_the_categories_and_the_uncategorized_group_is_last`, `tests/e2e/test_manager_flows.py::test_delete_category_yes_moves_its_flows_to_the_chosen_category`, `tests/e2e/test_manager_flows.py::test_move_puts_a_flow_into_a_category_before_another_flow`, `tests/fault/test_manager_window.py::test_a_flow_dragged_onto_a_category_moves_into_it_and_the_engine_keeps_it (gui)`

Create, rename and delete categories; move flows to another category. When a category is deleted, its flows move to a category the user chooses. An empty category stays until the user deletes it, also across a restart. The user orders the categories and the flows inside a category freely (drag and drop); a command sorts them alphabetically once; a new flow comes at the end of its category (E0067; v1 sorted automatically).

### REQ-MGR-040 Operate flows from the manager

- **v1:** yes
- **v2:** partial (WI-0074: run, stop, enable and disable of the selected flows, several flows by Ctrl click; WI-0087: "Edit" is enabled for exactly one selected flow and starts the editor process of that flow, headless; the double click on a flow does the same but is only checked by hand; the editor window itself comes with WI-0088)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/e2e/test_manager_flows.py::test_enable_and_disable_switch_the_flow_and_the_buttons_follow`, `tests/e2e/test_manager_flows.py::test_ctrl_click_selects_several_flows_and_the_operations_act_on_them`, `tests/e2e/test_manager_editor.py::test_edit_button_is_enabled_for_exactly_one_selected_flow`, `tests/e2e/test_manager_editor.py::test_edit_starts_the_editor_process_of_the_flow`

Buttons for run, stop, enable and disable, and edit (opens the editor of the flow) for the selected flows.

### REQ-MGR-050 Import and export flows

- **v1:** yes
- **v2:** partial (export, import, renaming and the report are tested headless; the file dialogs and the drop are checked by hand only, MANUAL-CHECKS section 1)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/e2e/test_manager_archive.py` (headless: round trip, a real v1 export `tests/data/ahf/v1_export_two_flows.ahf` (reading a real v1 `.ahf` verified), broken and refused files, name conflicts, the limits, export without selection)

Export selected flows to an `.ahf` file (a ZIP archive); import from such a file through a file selector or by dropping it on the window. On a name conflict the user can rename the imported flow. An invalid file is reported.

### REQ-MGR-060 Demonstration flows

- **v1:** yes
- **v2:** open
- **Prio:** should
- **Scope:** port
- **Plan:** S0008

AutoHotFlow ships demo flows in their own category. They cannot be deleted or renamed, but the user can hide them (setting "Hide demonstration flows").

### REQ-MGR-070 Show the log

- **v1:** yes
- **v2:** partial (the log window and its filters work headless; the window itself is not checked, and the flow settings do not open it yet)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/integration/test_storage.py::test_log_tail_returns_the_last_entries_with_level_flow_and_source`, `tests/e2e/test_manager_log.py::test_log_opens_with_the_tail_takes_new_entries_and_filters_them`, `tests/e2e/test_manager_log.py::test_closing_the_log_ends_the_subscription_and_its_entries`, `tests/e2e/test_manager_log.py::test_a_burst_of_5000_lines_does_not_stall_the_manager_and_the_model_keeps_the_limit`

The manager shows the log, filtered by level (only errors, some, many, all) and by source (app, flow). The flow settings open the log of one flow.

The window shows the last 1000 entries and the new ones while it is open; a burst of lines does not stall the manager. Missing: the window is not checked by the agents (owner check, WI-0082); the flow settings (S0007) do not call it yet, the code path `OpenLog(flowId)` exists; the window is not complete after a burst: the hub drops log lines above its send limit before they reach storage (decided, E0082), so the window shows the lines that storage wrote, the newest 1000 of them, not every line of the burst.

### REQ-MGR-080 Closing the manager window keeps AutoHotFlow running

- **v1:** yes (read: the v1 manager has no `GuiClose` handler)
- **v2:** done (the manager hides its window on the close box; checked with the real window, gui test of 2026-10-17)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/fault/test_manager_window.py::test_closing_the_window_only_hides_it_and_the_application_runs_on`, `tests/fault/test_manager_window.py::test_the_exit_button_ends_the_application_cleanly`

Closing the manager window only hides it. Flows and triggers keep running; the tray icon brings the window back. Only the "Exit" button of the manager and the "Exit" entry of the tray menu of the application (REQ-MGR-140) end the application. Decision E0014.

### REQ-MGR-090 Tray icon of the application

- **v1:** yes
- **v2:** partial (the icon with the tooltip and the double click are done in the role tray (E0075), also without a manager and after its crash (headless tests); the tray notices of REQ-USE-030 reach the role (WI-0075, counted headless); the real icon, its tooltip and a real notice are checked by the owner only: gui test `test_the_real_icon_...` and MANUAL-CHECKS section 1 step 12)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (notices: WI-0075, done)
- **Evidence:** `tests/fault/test_tray_role.py::test_the_real_icon_opens_its_menu_and_a_menu_open_for_8_seconds_does_not_make_the_role_hung`, `tests/fault/test_tray_role.py::test_the_tray_role_always_comes_back_after_a_growing_pause`, `tests/fault/test_tray_role.py::test_a_killed_tray_role_is_started_again_so_the_icon_comes_back`, `tests/fault/test_tray_role.py::test_a_crashed_manager_is_opened_again_by_the_show_manager_entry`

While AutoHotFlow runs, its icon is in the tray, with the tooltip "AutoHotFlow", also when the manager is not running or has crashed (E0064). A double click shows the manager, and starts it if it is not running. The application has one tray icon however many of its processes run; besides it, only open editors have an icon (REQ-EDT-230). Errors and warnings that have no window of their own appear as tray notices (REQ-USE-030). The menu: REQ-MGR-140.

### REQ-MGR-140 Tray menu of the application

- **v1:** yes
- **v2:** done (the role tray, E0075; "Show manager" shows the window of the manager, WI-0073, and starts the manager when it is not running; the entries follow a change of the language, `tests/e2e/test_manager_settings.py::test_the_language_changes_the_tray_menu_and_the_manager_without_a_restart`)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/fault/test_tray_role.py::test_the_exit_entry_ends_the_supervisor_with_exit_0_and_leaves_no_process`, `tests/fault/test_tray_role.py::test_the_show_manager_entry_starts_a_manager_that_is_not_running`, `tests/integration/test_tray.py`

| Entry | Effect |
|---|---|
| Show manager | shows the manager window, and starts the manager if it is not running; default entry (double click on the icon) |
| Exit | ends the application, the same as the "Exit" button of the manager (REQ-MGR-080, REQ-ROB-070) |

The standard entries of AutoHotkey (pause, reload, exit without the shutdown of AutoHotFlow) are not in the menu. The entries are translated (REQ-LNG-010) and follow a change of the language without a restart (v1 needed a restart).
### REQ-MGR-100 About window

- **v1:** yes
- **v2:** partial (the window of WI-0078: the versions of AutoHotFlow and AutoHotkey, the license and the project site as a button that opens it; waits for the owner's check of the look, MANUAL-CHECKS section 8)
- **Prio:** could
- **Scope:** port
- **Plan:** S0004 (WI-0078, done)
- **Evidence:** `tests/ahk/manager_settings_window.test.ahk`

Shows the version of AutoHotFlow and of AutoHotkey, the license and the project site.

### REQ-MGR-110 Restore an older version of a flow

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

The manager lists the saved backups of a flow (REQ-ROB-060) with their time and restores one. The current state becomes a backup itself, so that a restore can be undone.

### REQ-MGR-120 Show and change permanent variables

- **v1:** no (not found in the texts of the manager)
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

The manager shows the global variables and the static variables of each flow with their values, and the user can change and delete them. A wrong value can be found without a flow that prints it. Secret values stay hidden (REQ-SEC-040).

### REQ-MGR-130 Search and filter flows

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

A search field filters the flow list by name and category, and a filter shows only the flows in a given state (enabled, running, with errors).

### REQ-MGR-150 A deleted flow can be restored

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

A deleted flow is not lost at once (E0066). Ideas of the owner (2026-10-17), to be chosen when it is built:

- AutoHotFlow writes an `.ahf` file of the flow with its static variables and moves it to the Windows recycle bin. The user restores it with the means of Windows, or drags it out, and imports it again (REQ-MGR-050). One file, so the flow and its variables stay together.
- Or an own folder of deleted flows, cleaned up automatically by age.

## Editor (EDT)

### REQ-EDT-010 One editor per flow, several at the same time

- **v1:** partial (several editors, but drawing and input share one lock and one draw thread)
- **v2:** partial (WI-0087: the supervisor starts one editor process per flow for the Edit button and a double click, and a second request shows the running one; WI-0088: the editor is a process of its own that shows its flow in a window, and an editor that crashes or is closed leaves the flow and the other editors running (`tests/e2e/test_editor.py`); the live states come with WI-0089, the tray icon with WI-0091)
- **Prio:** must
- **Scope:** port
- **Plan:** S0005

Each open flow has its own editor window in its own process (D0002). An editor that hangs or crashes does not affect the other editors or the running flows. All open editors show live states, also those without focus.

### REQ-EDT-020 Draw the flow

- **v1:** yes
- **v2:** partial (the geometry, the scene and the hit test are unit-tested, WI-0084; the renderer draws the elements with icon and name, the connections with their type and label, the loops with their parts, the trigger marks and the state overlays, pixel-tested, WI-0085; WI-0088: the editor process draws its flow into the back buffer of its window and copies it in WM_PAINT, without a background erase, the window itself is checked by the owner (gui test `tests/fault/test_editor_window.py`); WI-0090: the tooltip text of an element (kind, class, name), of a connection (type) and of a MIGRATION place is tested headless (`tests/e2e/test_editor.py`); the lines for an exception, an arming error and a warning are not tested yet; the timing of the hover and the real pointer are not checked, owner check in WI-0092)
- **Prio:** must
- **Scope:** port
- **Plan:** S0005

Elements with icon and name, connections with their type, loops with their adjustable height; texts are aligned vertically; drawing does not flicker. Hovering an element shows its kind, class and name.

### REQ-EDT-030 Zoom and move the view

- **v1:** yes
- **v2:** partial (zoom, move and the scale with the DPI are unit-tested, WI-0084; WI-0090: the wheel zoom at the pointer, the drag, the limits 0.1 to 3 and a new size or DPI are tested headless (`tests/e2e/test_editor.py`); the window reacts to the real mouse, not checked yet: the gui test for it is open, owner check in WI-0092)
- **Prio:** must
- **Scope:** port
- **Plan:** S0005 (zoom and move, WI-0090), S0006 (the view is saved, E0086)

Zoom, and move the view by dragging with the right (or left) mouse button. Zoom and offset are saved with the flow (`flowSettings`).

### REQ-EDT-040 Live execution state in the editor

- **v1:** yes
- **v2:** partial (the engine gives the states of all elements of a flow at once and the connection a thread took, WI-0086; the editor shows the running elements since WI-0088 (`tests/e2e/test_editor.py`); the connection taken, the fading and the exception mark come with WI-0089)
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

Every completed edit takes effect at once, also for running instances (REQ-EXE-080), and is saved automatically a few seconds later (E0065): about 3 s after the last change, at the latest every 10 s while the user keeps editing. A flow has no unsaved state, so closing the editor or the application asks nothing. Saving by hand (Ctrl+S, menu) only writes at once. Mistakes are undone with undo (REQ-EDT-090) or by a backup: a backup is made at the first write of an editing session and then at most every 10 minutes (REQ-ROB-060, REQ-MGR-110). A rename by the manager while the editor is open is merged.

### REQ-EDT-110 Run, stop and enable from the editor

- **v1:** yes
- **v2:** partial (run and enable or disable from the tray menu of the editor, E0087; the menu bar comes with S0006)
- **Prio:** must
- **Scope:** port
- **Plan:** S0005 (run and enable from the tray menu of the editor, E0087, WI-0091), S0006 (the menu bar)
- **Evidence:** `tests/e2e/test_editor_tray.py` (headless: run, enable and disable, the questions, a refused run)

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
- **v2:** done (the engine counts the warnings per element and sends them, WI-0086; the editor shows the count at the element and the migration places as badges, WI-0089)
- **Prio:** must
- **Scope:** port
- **Plan:** S0005 (counted per element by the engine, WI-0086; shown at the element, WI-0089)
- **Evidence:** `tests/integration/test_engine_runstate.py::test_warnings_of_a_loop_are_counted_exactly_and_sent_coalesced`, `tests/e2e/test_editor.py::test_warnings_show_a_count_badge_and_migration_places_a_badge`, `tests/ahk/editor_model.test.ahk` (the warnings of one evaluation, one scene per frame)

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

### REQ-EDT-220 Examples and templates in the element settings

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

The element settings offer typical settings and examples of the element, which the user takes over with one click: for example a few common formats of a date, or a typical HTTP request. The user can save the current settings of an element as an own template and use it again for other elements of the same class. Taking over a template asks before it overwrites values that the user has already entered. Where it is offered (a button with a menu, the help of the element) is open.

### REQ-EDT-230 Tray icon of an editor

- **v1:** yes (read: one icon per open editor)
- **v2:** partial (the icon, its tooltip and menu are built; the real icon and the open menu are checked by hand in WI-0092)
- **Prio:** should
- **Scope:** port
- **Plan:** S0005 (icon and menu, E0087, WI-0091)
- **Evidence:** `tests/e2e/test_editor_tray.py` (icon state, tooltip, menu entries, the questions; headless), `tests/fault/test_editor_tray_icon_gui.py` (gui, the real icon and a menu held 8 s; not run by the agent)

Every open editor has a tray icon of its own besides the icon of the application (REQ-MGR-090). The icon shows the state of its flow (disabled, enabled, running; REQ-EXE-140), as does the icon of the editor window; the tooltip names the flow ("Flow: <name>").

| Entry | Effect |
|---|---|
| Show | brings the editor window to the front; default entry (double click on the icon) |
| Run | starts the flow (REQ-EDT-110) |
| Enable or disable | switches the flow on or off (REQ-EXE-070) |
| Close | closes this editor, with the question about unsaved changes (REQ-EDT-100); the application keeps running |

The standard entries of AutoHotkey are not in the menu. v1 calls the last entry "Exit"; "Close" says that only the editor ends.

## Settings (SET)

### REQ-SET-010 Global settings dialog

- **v1:** yes
- **v2:** done (the model, the file, the commands, the effect at once, the import of the settings of v1, and the settings dialog (WI-0078); the autostart and elevation keys come with WI-0079)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (WI-0077 model, done; WI-0078 dialog, done)
- **Evidence:** `tests/ahk/core_settings.test.ahk`, `tests/ahk/manager_settings_form.test.ahk`, `tests/ahk/manager_settings_window.test.ahk`, `tests/e2e/test_manager_settings.py`, `tests/integration/test_settings.py::test_a_change_is_written_announced_and_survives_a_restart`, `tests/integration/test_settings.py::test_a_broken_file_is_kept_and_the_defaults_are_used`

Settings are stored in the data folder and take effect at once where possible; a setting that needs a restart says so and offers it.

### REQ-SET-020 Defaults for execution policy and working directory

- **v1:** yes
- **v2:** partial (both settings work and take effect at once; the settings dialog changes them (WI-0078); the owner's check of the dialog is open, MANUAL-CHECKS section 8)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (WI-0077 settings, done; WI-0078 dialog, done)
- **Evidence:** `tests/e2e/test_manager_settings.py::test_a_checked_set_from_the_dialog_reaches_the_engine_and_the_file`, `tests/ahk/manager_settings_form.test.ahk`, `tests/integration/test_settings.py::test_the_global_execution_policy_decides_for_flows_set_to_default`, `tests/integration/test_settings.py::test_the_global_working_directory_is_a_working_directory_of_flows_at_once`

The global execution policy (REQ-EXE-050) and the global working directory (REQ-EXE-130). The import of v1 takes over a working directory that the user changed in v1.

### REQ-SET-030 Start with Windows

- **v1:** yes (a shortcut in the startup folder with the parameter `WindowsStartup`)
- **v2:** partial (the shortcut `AutoHotFlow v2.lnk` is created, removed and repaired, a start with Windows starts no manager; the log on itself is a manual check, `doc/MANUAL-CHECKS.md` section 7)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (WI-0079; the owner's manual check 7 is open, listed for WI-0082)
- **Evidence:** `tests/integration/test_startup_elevation.py::test_the_shortcut_is_created_removed_and_not_taken_for_the_one_of_v1`, `tests/integration/test_startup_elevation.py::test_a_shortcut_that_does_not_match_is_repaired_at_the_start`, `tests/integration/test_startup_elevation.py::test_a_start_with_windows_starts_no_manager_and_a_normal_start_does`

If the user wants it, AutoHotFlow starts in the background when the user logs on to Windows: only the tray icon appears, no manager window. It is an option in the settings; the setup assistant (REQ-USE-100) proposes it switched on, and the user can switch it off there. The start-up trigger knows that it was a start with Windows (REQ-TRG-220). The entry is a shortcut in the startup folder of the user, as in v1 (E0070). Together with "Run as administrator" (REQ-SET-040) Windows asks at every logon; a start without the question is REQ-SET-080.

### REQ-SET-040 Run as administrator

- **v1:** yes
- **v2:** partial (the restart logic is tested with a fake elevation hook: before any child, a declined question, the restart command; the real UAC question and the rights of every process are the manual check 7)
- **Prio:** should
- **Scope:** port
- **Plan:** S0004 (WI-0079; the owner's manual check 7 is open, listed for WI-0082)
- **Evidence:** `tests/integration/test_startup_elevation.py::test_with_the_setting_on_the_supervisor_restarts_elevated_before_it_starts_any_child`, `tests/integration/test_startup_elevation.py::test_a_declined_elevation_leaves_the_session_running_without_rights`, `tests/integration/test_startup_elevation.py::test_the_command_restart_ends_the_session_and_starts_it_elevated`, `tests/ahk/manager_model.test.ahk`

AutoHotFlow restarts itself with administrator rights, so that flows can control windows of elevated programs. To check: all processes of a session must run with the same rights, or the pipes and wake-up messages fail (UIPI). Checked by hand only, because the UAC prompt cannot be automated (E0073).

### REQ-SET-050 Logging settings

- **v1:** yes (levels for app, flow and thread; log to file)
- **v2:** done (the three thresholds are settings in the dialog (WI-0078, tab Debugging) and take effect at once in every process)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (WI-0077 settings, done; WI-0078 dialog, done)
- **Evidence:** `tests/e2e/test_manager_settings.py::test_a_checked_set_from_the_dialog_reaches_the_engine_and_the_file`, `tests/fault/test_diagnose.py::test_the_log_level_decides_what_is_forwarded_to_storage`, `tests/ahk/core_settings.test.ahk`, `tests/integration/test_settings.py::test_the_log_thresholds_change_in_every_role_at_once`, `tests/integration/test_settings.py::test_a_command_line_log_level_wins_over_the_settings`

Three thresholds as in v1, one for each source group: app (`a`), flow (`f`) and thread (`t`), each from 0 to 3. They take effect at once in every process. v2 always writes the log files (rotated at 100 KB); the v1 option "Log to file" is dropped (E0069).

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
- **v2:** done (the number is a setting (default 8, 1 to 16) in the settings dialog (WI-0078) and the pool grows and shrinks at once)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (E0044; WI-0077 setting, done; WI-0078 dialog, done)
- **Evidence:** `tests/ahk/manager_settings_window.test.ahk`, `tests/e2e/test_manager_settings.py`, `tests/ahk/engine_worker_bridge.test.ahk`, `tests/integration/test_settings.py::test_the_number_of_workers_grows_and_shrinks_at_once`, `tests/integration/test_settings.py::test_the_command_line_number_of_workers_wins_over_the_setting`

A global setting limits how many waiting elements (REQ-EXE-100) run at the same time. **Default: 8, from 1 to 16.** The memory is used only while elements wait, not for the limit itself. A lower number limits the memory when many elements wait at the same time (REQ-PRF-030); a higher number lets more of them run at the same time.

### REQ-SET-080 Start with Windows as administrator without a question

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -

With "Start with Windows" and "Run as administrator" together, Windows asks at every logon (E0070). A later improvement starts AutoHotFlow through a task of the Windows Task Scheduler with the highest rights, so that no question appears.

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
- **Evidence:** `tests/test_migration_report.py`, `tests/test_migration_classes.py`, `tests/e2e/test_manager_import.py::test_the_report_has_the_places_the_engine_marked` (the places of an import in the manager's report)

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
- **v2:** partial (flows, variables, settings and the autostart question are tested headless; the folder dialog, the report window and the import of the owner's own v1 data folder are checked by the owner only: MANUAL-CHECKS section 1, part B)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/e2e/test_manager_import.py` (flows with their IDs and disabled, existing IDs skipped or copied, broken file listed, demo flows not imported, variables with v2 winning, source folder unchanged, autostart kept, removed or refused), `tests/e2e/test_manager_import_settings.py` (the settings of v1: taken over as E0068 says, a refused value listed, a missing or broken file, the default language not taken over). The folder dialog and the report window are checked by the owner only (MANUAL-CHECKS section 1, part B)

The user imports the flows and variables of v1 into the v2 data folder through the manager, with a report of the marked places. An automatic backup of the v1 data at the switchover may come later (E0021). Rules (E0068):

- The source is the v1 data folder (`%APPDATA%\AutoHotFlow` by default, selectable); it is only read.
- A flow that v2 has already (same ID) is skipped and listed; the user can import it as a copy. The demonstration flows of v1 are skipped. Imported flows are disabled (E0058).
- A global variable that v2 has already keeps its v2 value; the conflict is listed.
- The settings working directory, language, execution policy, user level and log levels are taken over; start with Windows and run as administrator are not.
- Afterwards the manager offers to remove the autostart entry of v1 (preselection "no", v1 stays in use until v2 is finished).

### REQ-MIG-070 Flows with missing element packages

- **v1:** yes (the flow is not loaded; a dialog under the global lock asks, on "Yes" the file is deleted)
- **v2:** partial (the flow loads, the element is kept and fails with `exception` when run, WI-0047; the manager marks the flow with its missing packages for every element type, E0080; the editor draws such an element as a placeholder with its name and the reason (scene and renderer unit tests, WI-0084 and WI-0085; the window of the editor is a gui test of the owner)
- **Prio:** should
- **Scope:** port
- **Plan:** S0004 (manager and the notice), S0005 to S0007 (editor)
- **Evidence:** `tests/integration/test_trigger_arming.py::test_an_unknown_class_and_a_missing_package_are_not_armed_with_their_message` (WI-0062: the trigger carries the message of the missing package in its state), `tests/e2e/test_manager_flows.py::test_enabling_a_flow_with_a_missing_package_reports_the_trigger`, `tests/e2e/test_manager_flows.py::test_a_flow_with_a_missing_package_of_an_action_is_marked_with_the_package`

When a flow uses a package that is not installed, the flow still loads and nothing is deleted, because the package may be installed later (a flow synced from another computer). Nobody is asked whether to delete anything. The manager shows at the flow which packages are missing, without a dialog. The editor shows such an element as a placeholder with its parameters; the user can delete it like any other element. Running the element ends with `exception` and names the missing package. A trigger of a missing package does not stay off silently: enabling the flow tells the user that this trigger is not available. Saving keeps the element unchanged. (Decision of the owner 2026-10-15, MIGRATION M-0008.)

### REQ-MIG-080 Files of a newer version are not destroyed

- **v1:** n/a
- **v2:** open
- **Prio:** must
- **Scope:** port
- **Plan:** S0009

When a flow, variable or settings file was written by a newer version of AutoHotFlow, an older version never overwrites it with a format it does not know: it refuses the file with a clear message, or loads it without the right to change it. So a user can go back to an older version without losing flows. Related: REQ-MIG-050.

## Languages and help (LNG)

### REQ-LNG-010 User interface in several languages

- **v1:** yes (English, German, Russian, Korean)
- **v2:** partial (the language files of v1 load; the language is a setting and every process takes a change at once, the tray menu and the windows of the manager follow it without a restart (`UiTexts.Reload()`, the manager's `Refresh`, the settings dialog is made again); unit and headless tests; the windows themselves are not checked by the agents: owner check, MANUAL-CHECKS section 8)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (WI-0077 setting, done)
- **Evidence:** `tests/ahk/core_lang.test.ahk`, `tests/ahk/ui_common_texts.test.ahk`, `tests/integration/test_settings.py::test_the_language_changes_the_texts_of_two_roles_at_once`

All texts go through `Lang()` with the v1 language files (`assets/language/`, and `src/elements/<package>/language/` for the texts of the elements, WI-0047). A missing text falls back to the key and is logged (MIGRATION M-0046).

### REQ-LNG-020 Choice of the language

- **v1:** yes
- **v2:** done (the setting, the language of Windows as its default, and the choice in the settings dialog (WI-0078) with the languages the program has)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (WI-0077 setting, done; WI-0078 dialog, done)
- **Evidence:** `tests/ahk/core_settings.test.ahk`, `tests/ahk/manager_settings_form.test.ahk`, `tests/e2e/test_manager_settings.py::test_the_language_changes_the_tray_menu_and_the_manager_without_a_restart`, `tests/integration/test_settings.py::test_the_language_changes_the_texts_of_two_roles_at_once`

The language is the setting, or the language of Windows when nothing is set.

### REQ-LNG-030 Translated element texts

- **v1:** yes (language files per package)
- **v2:** partial (the language files of the package Default are those of v1 and load in every role; the elements use them as they are ported)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0047), S0008
- **Evidence:** `tests/ahk/core_lang.test.ahk`

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
- **Plan:** S0009

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
- **v2:** done
- **Prio:** should
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_debug_role.py`, `tests/fault/test_debug_dump.py`

A window shows the process table, the snapshot of each process, the live log, the events and values sent with `Debug.Dump`, and exports a report.

## Debugger (DBG)

The debugger is the long-term goal of decision E0001. It is not part of phase 3 (E0019), but nothing built now may prevent it (`ARCHITECTURE.md` 4.3). The debug dialog (REQ-DBG-060), which v1 has, is part of the port.

### REQ-DBG-060 Debug dialog

- **v1:** yes
- **v2:** partial (the window, its reading and changing of variables, the outputs and the close result are tested headless; the real window is only checked by the gui test and the owner's look)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0056)
- **Evidence:** `tests/integration/test_core_e_dialogs.py`, `tests/ahk/element_debug_ops.test.ahk`, `tests/integration/test_dialog_windows_gui.py`

The condition `Condition_Debug_Dialog` is the debugging tool of the user: placed anywhere in a flow, it halts the branch there and opens a window in which the user

- sees every variable that the branch can see, grouped by scope (loop, thread, instance, static, global; REQ-VAR-040), and refreshes the list;
- sees the value of a variable; an object is shown as readable text, special characters optionally converted;
- changes the value and the type (value or object) of a variable, and deletes a variable;
- decides how the flow goes on: "Yes" or "No" (the outputs of the condition). Closing the window ends the element with `exception`.

The halted branch waits; other branches and flows go on (REQ-EXE-100). In tests a test provider answers the dialog (E0038). Secret values stay hidden (REQ-SEC-040). Later ideas: show the built-in variables, and evaluate an expression against the variables of the branch (REQ-SCR-120).

### REQ-DBG-010 Pause and resume

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

Pause an instance or a flow at any time and resume it.

### REQ-DBG-020 Breakpoints

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

Execution stops before an element with a breakpoint.

### REQ-DBG-030 Single step and slow execution

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

Execute one element at a time, or all of them with a pause between the steps, so that the user can follow the flow in the editor.

### REQ-DBG-040 Inspect and change variables while paused

- **v1:** partial (the debug dialog shows and changes variables during a run, REQ-DBG-060)
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

### REQ-DBG-050 Edit the flow while debugging

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

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
- **Plan:** S0009 (R0007)

Installs AutoHotFlow with start menu entry and uninstaller.

### REQ-DST-020 Compiled program

- **v1:** yes (`AutoHotFlow.exe`)
- **v2:** partial (the supervisor and one entry script per role run with the installed interpreter; compiling is open)
- **Prio:** must
- **Scope:** port
- **Plan:** S0009 (R0007)
- **Evidence:** `tests/integration/test_entry.py`, `tests/fault/test_role_entries.py`

The user does not need an installed AutoHotkey. Today the supervisor starts every other role from its own entry script (D0012, E0041); how the role scripts are compiled (one program or one per role) is decided in S0009.

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
- **Plan:** S0009

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
- **v2:** partial (restart and resync work; the triggers are armed again after a restart of the engine or of the trigger host, WI-0062; the engine gives the states of all elements of a flow at once for the resync of the editor, WI-0086; the editor shows the current state again after an engine restart, WI-0088; the states of the editor after a crash of the editor itself are the business of the supervisor (the editor is not restarted, WI-0087))
- **Prio:** must
- **Scope:** port
- **Plan:** S0005 (editor)
- **Evidence:** `tests/e2e/test_manager.py::test_engine_restart_is_seen_and_resynced_without_restarting_the_manager`, `tests/fault/test_worker_lifecycle.py::test_engine_restart_during_a_worker_job_leaves_no_orphan_and_the_next_job_runs`, `tests/integration/test_trigger_arming.py::test_the_engine_is_restarted_and_rearms_without_the_startup_context`, `tests/integration/test_trigger_arming.py::test_the_trigger_host_is_restarted_and_its_triggers_fire_again`, `tests/e2e/test_editor.py::test_killed_engine_restarts_and_the_editor_shows_the_state_again`

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
- **Evidence:** `tests/fault/test_shutdown.py`, `tests/e2e/test_manager.py::test_cancelled_exit_is_answered_and_nothing_stops`

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

### REQ-ROB-120 A crashed editor or manager loses nothing

- **v1:** no (one process; a crash ends everything)
- **v2:** partial (the manager part: a killed manager is not restarted by itself, the tray icon stays and opens a new one, which holds the 200 flows again; the owner's check of the real crash is MANUAL-CHECKS section 1 step 25; that the rest keeps running and a flow can still be started after a crash of the real manager is the gui test `test_a_crash_of_the_manager_leaves_the_rest_running_and_it_is_not_restarted` (gui tier: the gui tests of WI-0073 are reported as passed in `work_items/phase3/STATUS.md`; not repeated by agents); the editor is S0006)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (manager), S0006 (editor)
- **Evidence:** `tests/fault/test_tray_role.py::test_a_crashed_manager_is_opened_again_by_the_show_manager_entry`, `tests/fault/test_manager_window.py::test_a_crash_of_the_manager_leaves_the_rest_running_and_it_is_not_restarted (gui)`, `tests/stress/test_manager_big_flows.py::test_the_manager_holds_200_big_flows_quickly_and_in_little_memory`
- **Doubt:** Still open: whether AutoHotFlow opens a crashed editor again by itself. (The question of unsaved changes is gone with E0065.)

When an editor crashes, no completed edit is lost: every edit is in effect at once and is saved automatically (REQ-EDT-100, E0065). The user learns that the editor has ended; the editor opened again shows the flow with all edits. Only an edit in progress at that moment (an open dialog, a move with the mouse) may be lost. A crashed manager is opened again from the tray icon, which belongs to the application and stays (REQ-MGR-090, E0064). Flows and triggers keep running in both cases (REQ-ROB-010).

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
- **v2:** partial (measured with the real trigger host, tray, headless manager or none, 1 and 3 workers: 53 to 77 MB, MS-0042; the manager with its window costs 1 to 2 MB more, MS-0043; not measured: the editors, which are not counted, and a whole session with the real window; S0008 measures again with the editor)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004, S0008 (measure again with the editor and the manager)
- **Evidence:** `doc/MEASUREMENTS.md` (MS-0032, MS-0033, MS-0039, MS-0042, MS-0043), `tools/measure_r3.py`, `tests/stress/test_trigger_host_memory.py` (WI-0067), `tests/stress/test_background_memory.py` (WI-0082)

The background processes (supervisor, storage, engine, trigger host, manager and the workers) need below 100 MB private bytes together in the normal state: small flows that run now and then, up to about three elements waiting at the same time (REQ-EXE-100). Editors are not counted. When more elements wait at the same time, the memory may exceed the budget: each one costs about 10 MB, so the default limit of 8 (REQ-SET-070) means about 115 MB (extrapolated from MS-0033, not measured). The user can lower the limit. Decision E0040, details `ARCHITECTURE.md` section 9.

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

While 200 big flows load, AutoHotFlow stays responsive: the engine answers a snapshot within 3 s and no process is taken for hung (E0042; the budget was 1 s, finding F-0073 keeps the measurements). Loading flows only when they are needed is an optimization after the port (REQ-PRF-100).

### REQ-PRF-060 Editor redraw

- **v1:** n/a
- **v2:** partial (measured headless under the event load of a loop at the guard's limit: the time from the change to the end of its frame has median 34 ms and p95 46 ms, the editor answers at once and draws about 21 frames per second, MS-0047; the window on a real screen is not measured, a `gui` run is the owner's; the frame part of a flow with 300 elements: 6.3 ms, MS-0046; a rebuild of the static layer takes 106 ms at 1920×1080 and 152 ms at 3840×2160, F-0151)
- **Prio:** must
- **Scope:** port
- **Plan:** S0005
- **Evidence:** `tests/stress/test_editor_event_load.py::test_the_editor_answers_and_draws_at_a_steady_rate_while_the_guard_stops_a_loop` (the latency and the rate, printed), `doc/MEASUREMENTS.md` (MS-0047; MS-0046, the renderer of `src/editor/render/`, the frame part only)

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

### REQ-PRF-100 Load flows only when they are needed

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

### REQ-SEC-040 Secret values are never shown or logged

- **v1:** no
- **v2:** open
- **Prio:** must
- **Scope:** later
- **Plan:** -

A value can be marked as secret, for example a password or an API key. A secret value is never shown in clear text (a field shows dots; a dialog, the variable view (REQ-MGR-120) and the debugger show it masked), never written to a log, a report or a snapshot (REQ-DIA-020 to REQ-DIA-040), never part of an exported flow (REQ-MGR-050), and never sent to an AI (AI) unless the user allows it.

Open points:

- How the user marks a value as secret: a parameter type "secret" in the element settings, an option of `Action_New_Variable`, a name prefix such as `secret_`, or several of these.
- Whether a value made from a secret (a text that contains it) is secret too.
- How a permanent secret is stored: encrypted for the Windows user (for example with DPAPI) instead of plain text in the variable file.

### REQ-SEC-050 No data leaves the computer by itself

- **v1:** yes (read: no network call outside the elements)
- **v2:** implemented (nothing in v2 uses the network; not checked by a test)
- **Prio:** must
- **Scope:** port
- **Plan:** S0010 (check)

AutoHotFlow sends nothing anywhere by itself: no telemetry, no usage statistics, no crash reports to the outside (crash reports stay on the computer, REQ-DIA-030). Only elements use the network, because the user put them into a flow. A later feature that contacts a server (for example a check for updates) is off until the user switches it on.

### REQ-SEC-060 Imported flows are disabled and come with a warning

- **v1:** no (not checked)
- **v2:** partial (the warning and the disabled flows are tested headless; the warning dialog as shown is checked by hand only, MANUAL-CHECKS section 1)
- **Prio:** could
- **Scope:** port
- **Plan:** S0004
- **Evidence:** `tests/e2e/test_manager_archive.py::test_the_warning_lists_the_elements_that_act_on_the_system_and_no_creates_nothing`, the entry layout: `tests/e2e/test_manager_archive.py::test_an_archive_with_an_entry_outside_the_layout_is_refused_as_a_whole` and `tests/e2e/test_manager_archive.py::test_export_then_import_gives_a_new_disabled_flow_with_its_definition_and_static_variables` (warning of an .ahf file, disabled flows); `tests/e2e/test_manager_import.py::test_every_flow_of_the_folder_is_imported_with_its_id_and_disabled` (the import from v1)

Importing flows from a file (REQ-MGR-050) tells the user that a flow is a program with the rights of the user (REQ-SEC-030) and lists the elements that act on the system (files, programs, keys and mouse, network, AutoHotkey scripts). The imported flows are disabled, so that nothing runs before the user has looked at them.

### REQ-SEC-070 Changes of flow files from outside are noticed

- **v1:** no
- **v2:** open
- **Prio:** could
- **Scope:** later
- **Plan:** -
- **Doubt:** What does it protect against? A program that runs as the same user can also change AutoHotFlow itself.

AutoHotFlow notices when another program has changed a flow file since AutoHotFlow wrote it, and asks the user before the flow is enabled or runs. There are legitimate changes (a text editor, a sync tool, git), so AutoHotFlow asks and does not refuse.

Open point: a checksum next to the file does not help against an attacker who can write the file, because they can write the checksum too. A key outside the data folder (for example protected by Windows for the user, DPAPI) protects against other users and against tools that do not know AutoHotFlow, but not against a program that runs as the same user and knows the scheme.

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
- **v2:** partial (the flow builder, the headless flow runner and the smoke test of every registered element and the dialog test provider exist; e2e tests exist for the core set (A to E, WI-0052 to WI-0056) and the test corpus (WI-0057); the other elements are still missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S0002 (WI-0051, WI-0056, WI-0057), S0008 (the other elements)
- **Evidence:** `tests/support/test_flowbuilder.py`, `tests/integration/test_flowrun.py`, `tests/ahk/element_smoke.test.ahk`, `tests/integration/test_dialogs.py`, `tests/integration/test_core_a_elements.py`, `tests/integration/test_core_b_lists.py`, `tests/integration/test_core_c_loops.py`, `tests/integration/test_core_d_flows.py`, `tests/integration/test_core_e_dialogs.py`, `tests/integration/test_corpus.py`

A smoke test covers every registered element; each element has end-to-end tests built with the flow builder and run by the headless flow runner; dialog elements are answered by a test provider (E0038).

### REQ-TST-040 The v1 test flows run green

- **v1:** yes (the "Automatic tests" flows)
- **v2:** partial (four of the 16 "Automatic tests" flows run headless and green: "variable test" (as saved, M-0069 is done, WI-0062), "List test" and "Loop test" (as saved), and "Trigger test" on a copy without its speech output (M-0077, S0003, WI-0067); the other 12 wait for S0008, see the table PENDING)
- **Prio:** must
- **Scope:** port
- **Plan:** S0008 (the 12 flows of PENDING in `tests/integration/test_corpus.py`)
- **Evidence:** `tests/integration/test_corpus.py::test_v1_trigger_test_runs_green_on_the_adapted_copy`, `tests/integration/test_corpus.py::test_v1_variable_test_runs_green_as_saved`, `tests/integration/test_corpus.py::test_v1_list_test_runs_green`, `tests/integration/test_corpus.py::test_v1_loop_test_runs_green`

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
- **v2:** partial (guides for the stub and the debug window (passed 2026-10-14), the dialog windows (DPI, passed 2026-10-17), the triggers (sections 4 and 5; passed 2026-10-17), the manager (section 1, parts A to E), start with Windows and administrator (section 7) and the settings dialog (section 8); the checks of section 1, 7 and 8 and the gui tests of S0004 are open for the owner (WI-0082); the editor guides come with S0005 to S0007)
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
- **v2:** partial (the setting `userLevel` exists and is taken over from v1; the element list that uses it comes with S0007)
- **Prio:** should
- **Scope:** port
- **Plan:** S0004 (setting, WI-0077, done), S0007 (element list)
- **Evidence:** `tests/ahk/core_settings.test.ahk`

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
- **v2:** partial (WI-0075: the notices of unhandled exceptions, runaway stops and storage errors reach the tray and the manager's list, without a dialog; not checked: the tray notice itself on a real tray (headless tests only count it), and a notice of a flow file that cannot be saved, which no test provokes)
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 (WI-0075 done; the flow file notice and the real tray check open)
- **Evidence:** `tests/integration/test_notices.py::test_an_unhandled_exception_gives_one_notice_marks_the_flow_and_reaches_the_tray`, `tests/integration/test_notices.py::test_a_burst_of_errors_gives_one_notice_at_once_and_the_count_when_the_window_ends`, `tests/integration/test_notices.py::test_a_stop_by_the_runaway_guard_gives_a_notice_with_the_limit`, `tests/ahk/core_notice_throttle.test.ahk`, `tests/ahk/manager_model.test.ahk`

Errors and warnings that have no window of their own (for example a flow file that cannot be saved) reach the user as notices in the tray or the manager, never as a dialog that blocks the running flows.

### REQ-USE-040 The user interface stays responsive

- **v1:** no (the user interface waits for the global lock)
- **v2:** partial (the architecture separates the processes; the manager (WI-0073) handles its events in a timer and its commands with timeouts, the editor is missing; the dialogs of the UI roles do not block: `ui_common/UiDialogs.ahk` (WI-0069), unit-tested, the windows not checked; standard dialogs stall the timers for up to 0.7 s, HOW-TO gui-and-hotkeys)
- **Evidence:** `tests/ahk/ui_common_dialogs.test.ahk` (logic only), `tests/ahk/manager_model.test.ahk`, `tests/e2e/test_manager.py::test_manager_answers_at_once_while_the_engine_is_missing`
- **Prio:** must
- **Scope:** port
- **Plan:** S0004 to S0007

Manager and editors never freeze while flows run, because they are processes of their own.

### REQ-USE-100 Setup assistant at the first start

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

At the first start a short assistant leads the user through the basic choices. Every choice has a preselection and can be changed later in the settings. The steps:

- language (REQ-LNG-020)
- experience level and what follows from it (REQ-USE-050)
- start with Windows, preselected (REQ-SET-030)
- import of the flows and variables of v1, when a v1 data folder exists (REQ-MIG-060)

The user can skip the assistant and start it again from the settings.

### REQ-USE-050 The setup assistant asks for the user's experience

- **v1:** no
- **v2:** open
- **Prio:** should
- **Scope:** later
- **Plan:** -

The setup assistant (REQ-USE-100) asks how experienced the user is and preselects the options from the answer:

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

### REQ-USE-080 Unhandled errors of a flow are noticed

- **v1:** yes (read: a window with the message that does not block; a new error replaces the window shown)
- **v2:** partial (part 1 done in WI-0075: the notice (tray and list) and the mark of the flow until it is selected or the list is opened; the window with the variables of the branch is missing; the switch per flow is missing)
- **Prio:** should
- **Scope:** port
- **Plan:** S0004 (notice and mark in the manager, WI-0075, done), S0007 (the window with the variables), E0072
- **Evidence:** `tests/integration/test_notices.py::test_an_unhandled_exception_gives_one_notice_marks_the_flow_and_reaches_the_tray`, `tests/integration/test_notices.py::test_opening_the_list_of_notices_removes_the_marks_and_keeps_the_entries`, `tests/fault/test_manager_window.py::test_an_error_notice_shows_in_the_list_of_notices_opened_by_its_button`, `tests/ahk/manager_model.test.ahk`

When a branch of a flow ends with an unhandled `exception` (REQ-EXE-090), the user learns it without reading the log: a window like the debug dialog (REQ-DBG-060) shows the error message, the element and the variables of the branch at the moment of the error. Unlike the debug dialog it does not halt anything, because the branch has already ended; the variables can be looked at, not changed. The flow also gets a mark in the manager until the user has looked at the error. Many errors in a short time give one notice. The notice can be switched off per flow and globally (REQ-USE-070).

### REQ-USE-090 Sharp and correctly sized on high-resolution displays

- **v1:** no (not checked)
- **v2:** partial (dialogs done; the window base for the UI roles is written, `ui_common/UiWindow.ahk` with the layout in `core/GuiLayout.ahk` (WI-0069), the manager window (WI-0073) uses it, opened in the gui test but not checked at another scaling; the view math scales the flow with the DPI, unit-tested (WI-0084); the renderer draws at the DPI of the view and rebuilds its layer at another DPI, unit-tested (WI-0085); the editor window: the canvas takes the size below the status bar and follows a DPI change with unchanged pixels, WI-0090; the real window at another scaling is not checked, owner check in WI-0092)
- **Prio:** should
- **Scope:** port
- **Plan:** dialogs done (manual check 3, 2026-10-16); manager S0004, editor S0005 to S0007, tray icon S0004 and S0005
- **Evidence:** `doc/MANUAL-CHECKS.md` (manual check 3, steps 17 and 18, owner, 2026-10-16: dialog windows at 100 % and 225 %, DPI change with the window open, message box, debug dialog and tooltip), `src/elements/base/DialogWindow.ahk`, `src/core/GuiLayout.ahk` (the layout moved there in WI-0069; the manual check was made before the move, so the owner has to check again)

Manager, editor, dialogs and the tray icon are sharp and have the right size with a display scaling above 100 %, also when a window moves to a screen with another scaling. The editor draws the flow sharp at every zoom.
