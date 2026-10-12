# Documentation AutoHotFlow v2

Lasting documents. The working papers of the port (analysis, plans, status reports, work packages) are no longer in the working tree. They are preserved under the git tag `v2-phase2-final`, for example `git show v2-phase2-final:work_items/STATUS.md`.

| Document | Content |
|---|---|
| [ARCHITEKTUR.md](ARCHITEKTUR.md) | Processes, decisions, data ownership, state machines, start/stop, error handling, file compatibility, folder layout |
| [PROTOKOLL.md](PROTOKOLL.md) | IPC: transport, envelope, message catalogue |
| [ELEMENT-API-V2.md](ELEMENT-API-V2.md) | Class contract of elements, context, examples, implementation rules |
| [TESTSTRATEGIE.md](TESTSTRATEGIE.md) | Test levels, fault injection, stress test, round trip |
| [KONVENTIONEN.md](KONVENTIONEN.md) | Code rules, forbidden patterns, AHK v2 pitfalls |
| [MIGRATION.md](MIGRATION.md) | Deliberate behavior changes compared to v1 |
| [HOW-TO.md](HOW-TO.md) | Knowledge base for AHK v2: pitfalls and working solutions |

Reading order for new contributors: ARCHITEKTUR (sections 1 to 5), KONVENTIONEN, then the document for your own task.
