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

Entries live in the category files under `doc/howto/` (listed below). Append a new entry at the end of the matching file under `doc/howto/`, then run `python tools/doc_index.py`. The list of all entries with their line ranges is `doc/DOC-INDEX.md`. Correct or delete outdated entries, do not duplicate them.

## Category files

- [Syntax and language](howto/syntax-and-language.md)
- [Objects, Maps, Arrays](howto/objects-maps-arrays.md)
- [Error handling](howto/error-handling.md)
- [Processes, pipes, messages](howto/processes-pipes-messages.md)
- [GUI and hotkeys](howto/gui-and-hotkeys.md)
- [Tests and tools](howto/tests-and-tools.md)

The entries of all files, with their line ranges and status, are in `doc/DOC-INDEX.md` (generated; grep it for a keyword).
