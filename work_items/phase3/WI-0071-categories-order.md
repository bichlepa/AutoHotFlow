# WI-0071 Categories and the order of the list (`Categories.json`)

Size: M · Depends on: WI-0070 · Blocks: WI-0074

## Goal

Categories are managed by the engine: create, rename, delete (with a target for the flows), and the free order of the categories and of the flows inside each category (E0067). Empty categories survive a restart. The order and the empty categories are in `Categories.json`; the category of a flow stays in its flow file. Requirement: REQ-MGR-030 (engine part).

## Read first

As WI-0070, plus E0067 and the file part of E0057/E0063 (one owner, written through storage), `src/engine/FlowStateFile.ahk` and `src/storage/StateFiles.ahk` (the pattern of a state file with coalesced writes), v1 `v1/Source_Common/Flows/Manage Flows.ahk` (`NewCategory`, names of categories).

## Tasks

1. **Docs first:** PROTOCOL 4.2 (`cmd.category.create/rename/delete`, `cmd.list.order` or one command for the order, the snapshot fields `categories` and the order), 4.3 (`evt.category.changed` or the changed `evt.flow.list.changed`; choose one and say why), 4.6 (`Categories.json`: format with `formatVersion`), ARCHITECTURE 3 (owner of the order), MIGRATION (v1 sorted automatically and lost empty categories).
2. **Model in the engine:** the list of categories in order, per category the order of its flow IDs; "Uncategorized" (a fixed key, the name through `Lang`) is always there and always first or last (choose; it cannot be deleted or renamed). A flow that is not in the order (a new file, a file copied in by hand) is appended at the end of its category. A name in the order that no flow file has and that is not an empty category is dropped.
3. **Commands:** create (the name is checked like a flow name, unique among categories), rename (writes the category name into every flow file of the category; each write as in WI-0070), delete (`{ name, moveTo }`, the flows move first), order (`{ categories: [...], flows: { <category>: [ids] } }` or a move of one item; choose the form that the drag and drop of WI-0074 needs), "sort alphabetically" (once, case-insensitive).
4. **File:** read at start before `evt.engine.ready` (missing: the order is built from the flows, alphabetically, so the first start of v2 looks like v1); written at most once per second, flushed at shutdown; a broken file is kept as `.broken` and rebuilt.
5. **Tests:** AHK unit tests of the order model (append, drop, move, sort, a flow moved to another category); e2e: the order and an empty category survive a restart, rename and delete of a category with flows, a broken file.
6. **Load path:** `tests/stress/test_big_flows.py` at the end; time to ready and largest snapshot answer in the result.

## Acceptance criteria

- The tests of task 5 are green, serial and parallel; the stress test within the budget (3 s).

## Not part of this

The drag and drop in the manager (WI-0074).
