# WI-49 Flow builder and headless flow runner for tests

Size: M · Depends on: – · Blocks: WI-52 to WI-57

## Goal

Tests describe flows compactly in Python instead of writing flow JSON by hand, and run them headless with one call: start, wait for the end, read the result, the variables and the path through the flow. This carries the e2e tests of all core elements and the synthetic flows of WI-57.

## Read first

`doc/ARCHITECTURE.md` 7 (flow file format), `doc/PROTOCOL.md` (`cmd.flow.start`, `evt.instance.started/ended`, `evt.element.state`, `cmd.engine.snapshot`, `cmd.flow.get`), `doc/TEST-STRATEGY.md`, `tests/support/ahfclient.py`, `tests/integration/test_engine.py`, `tests/data/flows/`, one v1 example flow with a loop and one with `Execute_Flow` (format of `allElements`, `allConnections`, `fromPart`/`toPart`, `HeightOfVerticalBar`).

## Tasks

1. **Builder** (`tests/support/flowbuilder.py`): elements by class and parameters, connections by result (`normal`, `yes`, `no`, `exception`) and loop parts (`head`, `tail`, `break`), the trigger, `flowSettings` (including `strictTypes`). Output: a flow file in the v2 format (`formatVersion` 2) or in the v1 format (without it, for conversion tests). Defaults of the parameters may be left out; IDs and positions are generated. A small text form for linear flows is welcome (for example `"Manual -> New_variable(x=1) -> Condition_Expression(x=1) yes-> ..."`), but not required.
2. **Runner** (`tests/support/flowrun.py`): starts a session with `--data=<temp dir>` (fixtures as in the existing e2e tests), writes the flows into the data folder, starts a flow, waits for `evt.instance.ended` with `scaled()` timeouts, returns: the reason, the elements that ran in order with their results (from `evt.element.state`), the instance and thread variables at the end (snapshot or an own test command, as available), and the log entries of the flow.
3. **Global and static variables** can be preset and read through the data folder (pair format, `tests/data/variables/` as a pattern).
4. Unit tests of the builder (the output loads in the engine, round trip with `cmd.flow.get`) and one e2e test with the existing skeleton elements.

## Acceptance criteria

- One e2e test of a flow with a condition and a loop is less than 20 lines of Python.
- The runner leaves no process behind on failure (fixtures, as in the existing tests).

## Docs

`doc/TEST-STRATEGY.md` (how element tests are written), docstrings.

## Not part of this

New engine commands; if the runner needs one (for example to read the variables of an ended instance), it is a test command (`cmd.test.*`, only with `--test-roles`) until WI-50 brings the variable requests that a client can use (WI-50 task 5); then the runner switches to them.
