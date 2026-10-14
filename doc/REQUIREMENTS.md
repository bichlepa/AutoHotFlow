# Requirements

This document lists the important features and quality requirements of AutoHotFlow: what v1 can do, what v2 must do to replace it (the port), and what comes after the port. For each requirement it states whether v1 has it and how far v2 is.

**Overview:** [REQUIREMENTS-INDEX.md](REQUIREMENTS-INDEX.md) has one table row per requirement with its status and a link to its section here. Read the index for an overview; read a section here for the details.

A requirement says **what** AutoHotFlow does, not how. The how is in the other documents (`ARCHITECTURE.md`, `PROTOCOL.md`, `ELEMENT-API-V2.md`, the decisions in `DECISIONS.md`); a requirement links to them instead of repeating them. Other documents refer to a requirement by its ID (`REQ-EXE-010`), not by a link to its heading, because the ID is stable and the heading anchor changes with the title.

## Format

Each area is a heading `## <Title> (<CODE>)`. Each requirement is a heading `### REQ-<CODE>-<nnn> <Title>` inside its area, followed by a list of fields and then free text (explanation, tables, sub-items, open questions):

```markdown
### REQ-EXE-010 Execution policy per flow

- **v1:** partial (`wait` behaves like `parallel`, M-11)
- **v2:** partial (the global default is missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S4
- **Evidence:** `tests/integration/test_engine.py` (policy tests)

A flow decides what happens when it is triggered while an instance is still running ...
```

| Field | Allowed first word | Meaning |
|---|---|---|
| `v1` | `yes`, `partial`, `no`, `n/a` | Does v1 have it? Facts about v1 come from reading its code and help texts, unless the text says "tested". `n/a` when the question makes no sense for v1. |
| `v2` | `done`, `implemented`, `partial`, `open`, `dropped` | `done`: implemented and verified by a test or a measurement (the field `Evidence` is then mandatory). `implemented`: implemented, not verified. `partial`: a part works; the text says what is missing. `open`: not implemented. `dropped`: will not be implemented; the text says why. |
| `Prio` | `must`, `should`, `could` | `must`: v2 cannot replace v1 (scope `port`) or the feature has no use (scope `later`) without it. |
| `Scope` | `port`, `later` | `port`: needed so that v2 replaces v1 (phases 3 and 4). `later`: after the port. |
| `Plan` | free text | Where the work is planned: a step (`S4`), `phase 4`, a work item (`WI-52`), or `-` when nothing is planned. |
| `Evidence` | free text, optional | Tests, measurements (`MEASUREMENTS.md` M-nn), manual checks. Mandatory for `done`. |

After the first word, a field may carry a short note in parentheses: `partial (wait broken, M-11)`. The index shows only the first word.

Rules:

- IDs are never reused or renumbered. New requirements get the next free number of their area, in steps of 10 (`010`, `020`, ...), so that related requirements can be numbered close together. The order of the sections may differ from the order of the numbers.
- A dropped requirement stays in the document with `v2: dropped` and its reason.
- Whoever implements, verifies or drops a feature updates its requirement **in the same commit** and runs `python tools/req_index.py`. The test `tests/test_requirements.py` fails when the format is broken or the index is out of date.
- Distinguish verified, assumed and not checked (AGENTS.md rule 6). `done` needs evidence; a claim about v1 that was not read in the code says so.

## Flows and execution (EXE)

### REQ-EXE-010 Execution policy per flow

- **v1:** partial (`wait` behaves like `parallel`, MIGRATION M-11)
- **v2:** partial (the four policies work; the global default setting is missing)
- **Prio:** must
- **Scope:** port
- **Plan:** S4 (global setting)
- **Evidence:** `tests/integration/test_engine.py` (the `*_policy_*` tests)

A flow decides what happens when it is triggered while an instance of it is still running:

| Policy | Behaviour |
|---|---|
| `parallel` | start another instance |
| `skip` | do not start; the start is answered with `busy` |
| `wait` | queue the start; it runs when the flow is idle |
| `stop` | stop the running instances, then start a new one |
| `default` | use the global setting (v1 default: `parallel`) |

Missing in v2: the global setting itself (settings come in S4). Until then `default` resolves to `parallel` (`src/engine/core/ExecutionPolicy.ahk`).

## Expressions and variables (VAR)

## Elements (ELM)

## Triggers (TRG)

## Manager (MGR)

### REQ-MGR-010 Closing the manager window keeps AutoHotFlow running

- **v1:** yes (read: the v1 manager has no `GuiClose` handler)
- **v2:** open (the stub ends the whole application when its window is closed)
- **Prio:** must
- **Scope:** port
- **Plan:** S4
- **Evidence:** -

Closing the manager window only hides it. Flows and triggers keep running; the tray icon brings the window back. Only the "Exit" button of the manager and the "Exit" entry of the tray menu end the application. Decision E14.

## Editor (EDT)

## Settings (SET)

## Import and migration (MIG)

## Languages and help (LNG)

## Element packages (PKG)

### REQ-PKG-010 Chrome package

- **v1:** yes
- **v2:** dropped (decision of the project owner)
- **Prio:** could
- **Scope:** port
- **Plan:** -

v1 had a package with elements that control the Chrome browser. It is not ported (phase 1 release, item 7 in `DECISIONS.md`; MIGRATION M-09).

## Logging and diagnostics (DIA)

## Debugger (DBG)

## Distribution (DST)

## Robustness (ROB)

### REQ-ROB-010 A crashing or hanging process does not take the others with it

- **v1:** no (one process; a crash ends everything, a hang blocks everything)
- **v2:** done
- **Prio:** must
- **Scope:** port
- **Plan:** -
- **Evidence:** `tests/fault/test_process_crash.py`, `tests/fault/test_process_hang.py`

The supervisor detects a crashed or frozen process, reports it and reacts by role: the engine and the storage are restarted, a UI or a worker is not. The other processes keep running and keep their connections. Running instances of an engine that crashes are lost (MIGRATION M-01). Details: `ARCHITECTURE.md` section 6.2.

## Performance and resources (PRF)

## Security (SEC)

## Testability (TST)

## Maintainability (MNT)

## Usability (USE)
