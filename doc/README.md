# Documentation AutoHotFlow v2

Lasting documents. The working papers of the port up to phase 2b and the fix block (analysis, plans, status reports, work packages) are no longer in the working tree. They are preserved under the git tag `v2-phase2-final`, for example `git show v2-phase2-final:work_items/STATUS.md`.

| Document | Content |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Processes, decisions, data ownership, state machines, start/stop, error handling, file compatibility, folder layout |
| [PROTOCOL.md](PROTOCOL.md) | IPC: transport, envelope, message catalogue |
| [ELEMENT-API-V2.md](ELEMENT-API-V2.md) | Class contract of elements, context, examples, implementation rules |
| [TEST-STRATEGY.md](TEST-STRATEGY.md) | Test levels, fault injection, stress test, round trip |
| [CONVENTIONS.md](CONVENTIONS.md) | Code rules, forbidden patterns, AHK v2 pitfalls |
| [AUSDRUECKE.md](AUSDRUECKE.md) | Expression language: syntax, operators, syntax tree, errors, limits, differences from AutoHotkey v2 and v1 |
| [MIGRATION.md](MIGRATION.md) | Deliberate behavior changes compared to v1 |
| [HOW-TO.md](HOW-TO.md) | Knowledge base for AHK v2: pitfalls and working solutions |
| [DECISIONS.md](DECISIONS.md) | Decision log (E1 onward), with open decisions |
| [OPEN-ITEMS.md](OPEN-ITEMS.md) | Open findings, watch list, known problems, what has not been checked |
| [MEASUREMENTS.md](MEASUREMENTS.md) | Measured values that decisions rest on, with method and status |
| [MANUAL-CHECKS.md](MANUAL-CHECKS.md) | Manual checks for the project owner (GUI of the stub, debug window) |
| [HISTORY.md](HISTORY.md) | Work packages mapped to commits |

Reading order for new contributors: ARCHITECTURE (sections 1 to 5), CONVENTIONS, then the document for your own task.
