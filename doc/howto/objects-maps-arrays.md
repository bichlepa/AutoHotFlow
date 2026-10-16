# How-to AHK v2: Objects, Maps, Arrays

Entries of this category. Entry format, rules and index: [`../HOW-TO.md`](../HOW-TO.md).

### Map with `CaseSense "Off"` keeps the spelling of the first insertion

- **Problem:** Are key spellings preserved when enumerating a case-insensitive Map?
- **Right:** Yes. The first insertion fixes the spelling; a later insertion in another spelling only replaces the value. Enumeration is sorted (`apple`, `mango`, `zebra`). Two keys that differ only in spelling become one, which `Json.Parse` rejects.
- **Status:** verified (`tests/ahk/json.test.ahk`). The sorted enumeration is observed, not documented.

### Copy keys into an array before deleting from a Map

- **Problem:** When an instance stops, threads are removed from a `Map` while iterating over it.
- **Right:** First copy the keys into an array, then iterate over the array (`Instance.Stop`).
- **Status:** not checked (whether deleting during a `for` loop over a Map works was not tested; the copy avoids the question)
- **Source:** `src/engine/core/Instance.ahk`

### Static method `Name()` shadows the `.Name` property of a class

- **Problem:** The registry read the class ID from `cls.Name`. For element classes this returns a function (`Func`), because `static Name()` shadows the built-in property.
- **Wrong:** `id := cls.Name` for classes with `static Name() => ...`.
- **Right:** Read the class ID from an instance: `Type(cls())` returns `Action_Sleep`. Elements have no constructor, so the call is cheap. See `ElementRegistry.IdOf`.
- **Status:** verified (probe: `cls.Name` gives `Func`, `Type(cls())` gives the class name; `tests/ahk/element_registry.test.ahk`)
- **Source:** `src/elements/base/ElementRegistry.ahk`

### `static __New()` sets the key spelling of a static Map

- **Problem:** A `static` Map should find keys regardless of case. `CaseSense` cannot be set in the class line.
- **Right:** `static __New() { this.classes.CaseSense := "Off" }` runs when the class is loaded, before first use. Afterwards `Has("TRIGGER_MANUAL")` finds `Trigger_Manual`.
- **Status:** verified (probe; `tests/ahk/element_registry.test.ahk`, case "lookup is case-insensitive")
- **Source:** `src/elements/base/ElementRegistry.ahk`

### Callback with state: `ObjBindMethod` instead of a lambda in a loop

- **Problem:** The engine sends one read request per flow file. Each callback needs the name and path of its file.
- **Wrong:** `for f in files { peer.Request(..., (res) => this._OnRead(st, f["name"], res)) }`. Lambdas capture variables by reference, so all callbacks see the last entry.
- **Right:** `peer.Request(..., ObjBindMethod(this, "_OnFlowRead", st, name, path), timeout)`. The bound arguments come before the caller's argument.
- **Status:** verified (`tests/integration/test_engine.py`, loading of two flow files and an error file)
- **Source:** `src/engine/Engine.ahk` (`_OnFlowList`)

### Parameter of an element as an object with property access

- **Problem:** `Action_Sleep` reads `params.Duration` (property access, as in v1), but the flow file delivers the parameters as a `Map`.
- **Wrong:** Passing the `Map` directly as `params`.
- **Right:** Build an object: `p := {}` and for each key `p.%k% := v`.
- **Status:** verified (Sleep with Duration 200 in `tests/integration/test_engine.py`). Whether a `Map` with `HasProp` would behave the same was not checked.
- **Source:** `src/engine/Executor.ahk` (`_Params`)

### Clone only after the change: the clone inherits it

- **Problem:** `Scheduler.Advance` cloned the thread for the second connection after the first thread had received the loop element and the loop stack push. The clone inherited the push (depth 1 instead of 0), and the second rollback of the stack threw.
- **Right:** Establish the state once (pop), then create all clones, and only afterwards give each target its own change.
- **Status:** verified (tests `Advance: branching into a loop pushes only the loop thread` and `Loop: two tail connections pop the loop stack once` were red before the fix)
- **Source:** `src/engine/core/Scheduler.ahk`

### A Map orders by keys, not by insertion: FIFO needs an array

- **Problem:** The instances were kept in a `Map` with keys `inst-<n>`. Enumeration is sorted by key, not by start time, so it cannot serve as the FIFO queue of the policy `wait`.
- **Right:** Use a dedicated queue: an `Array` per flow, `Push` at the end, `RemoveAt(1)` at the beginning.
- **Status:** sorting by key verified (documentation and code); that `inst-10` sorts before `inst-2` is assumed (not measured).
- **Source:** `src/engine/Executor.ahk` (`_waiting`)

### `Map.Delete` on a missing key throws

- **Problem:** An event handler called `this._earlyReady.Delete(name)` for a name that was never entered. `Map.Delete` throws `UnsetItemError` ("Item has no value"). The peer caught the error and logged it, so the crash of a worker had no effect and the element hung.
- **Wrong:** `m.Delete(key)` without a check when the key may be missing.
- **Right:** `if (m.Has(key)) m.Delete(key)`.
- **Status:** verified (`test_killed_worker_ends_its_element_with_worker_crashed_and_the_pool_has_a_replacement`, red with this log line, green after the fix)
- **Source:** `src/engine/WorkerBridge.ahk` (`OnProcessEvent`)

### A subclass method silently replaces a same-named base class method

- **Problem:** `Role` got a method `_CmdSnapshot` for `cmd.diag.snapshot`, but the engine already had a private method `_CmdSnapshot`. The subclass method replaced the base method without a warning, and the engine's call ran the wrong code.
- **Wrong:** Creating a private method in a base class with a short, obvious name that a subclass may already use.
- **Right:** Use a unique name (`_CmdDiagSnapshot`). Before adding a method to `Role`, search for the name in all roles (`grep -n "_Name(" src`). A test that asks every role (`tests/fault/test_snapshot.py`) finds such a case.
- **Status:** verified (red with `KeyError: 'snapshot'` for the engine; green after renaming)
- **Source:** `src/core/Role.ahk`

### `Json.Parse` returns `true` as 1, not as `Json.True`

- **Problem:** `Json.True` and `Json.False` are for writing. A parsed `true` is the Integer 1, so `value == Json.True` is false for a marker that was read from a file.
- **Right:** Compare a parsed truth value with `1` (and accept `"1"` and `"true"` where a file may have been edited by hand), as `FlowExprConvert.IsMarked` does. `Json.Stringify` writes `Json.True` as `true`.
- **Status:** verified (unit test `tests/ahk/engine_flow_convert.test.ahk`)
- **Source:** `src/engine/core/FlowExprConvert.ahk`

### A Map key `1` and `"1"` are two keys; Integer keys come before texts

- **Problem:** In v1 `list.1`, `list[1]` and `list["1"]` are the same member. In an AutoHotkey v2 `Map` the Integer `1` and the text `"1"` are different keys (`m["10"] := 1` then `m.Has(10)` is 0), even with `CaseSense "Off"`. A Float key is stored as its text (`1.5` becomes `"1.5"`).
- **Right:** Normalize keys when storing and looking up (`VarValues.NormKey`: a text of decimal digits becomes the Integer). A `Map` enumerates its Integer keys in ascending order first, then its text keys sorted (with `CaseSense "Off"` without case: `_` before `A` before `b`). That is the order of v1 objects, so no own sort is needed.
- **Status:** verified (probe with `ahkrun.py`: `-3, 2, 10, "1.5", "1x", "_", "A", "b", "Z"`; golden case `objects.dict.whole`)
- **Source:** `src/engine/vars/VarValues.ahk`

### A function stored in an object that it holds is a reference cycle

- **Problem:** The source of the parameter evaluation (`ExecContext.EvalSource`) needs a log function that knows the current parameter. The first version stored `ObjBindMethod(this, "_EvalLog", src)` in `src` itself: `src` holds the function, the function holds `src`, and both are never freed (one leak per `EvalParams` call).
- **Wrong:** `src.logFn := ObjBindMethod(this, "_EvalLog", src)` (the same with a closure that captures `src`).
- **Right:** Bind a small separate object that holds only the changing data (`at := {param: ""}`; `src.at := at`; `ObjBindMethod(this, "_EvalLog", at)`). `at` does not hold `src`, so there is no cycle. See also "Reference cycle via `ObjBindMethod(this, ...)` in a field".
- **Status:** assumed (seen in review before it ran; the leak itself was not measured)
- **Source:** `src/elements/base/ExecContext.ahk` (`EvalSource`)
