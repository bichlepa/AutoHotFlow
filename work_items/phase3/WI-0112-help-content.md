# WI-0112 Help content: Markdown sources, the HTML generator, core set and expression page for v2

Size: L · Depends on: – · Blocks: WI-0111 (pages to show), WI-0114

## Goal

The help is written in Markdown and a tool generates the HTML that the viewers show (E0100). Every help page of v1 is taken over. The pages of the 29 core elements and the general page on variables and expressions are correct for v2 (E0097). Requirements: REQ-ELM-020 (core set), REQ-LNG-040 (content).

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0035, E0097, E0100; `doc/ELEMENT-API-V2.md` 2 (the layout of a package); `doc/EXPRESSION-LANGUAGE.md`; `doc/MIGRATION.md` (the deviations of the core set); `tools/gen_element_includes.py` and `tests/test_element_includes.py` (the pattern of a generated, committed file with a check); the core elements in `src/elements/Default/`; v1: `v1/Source_Elements/Default/help/en/` and the general pages of the v1 help.

## Tasks

1. **Layout:** the Markdown sources of the element pages go into the package (`src/elements/Default/help/en/<Kind>s/<Name>.md`, a new row of the layout table of ELEMENT-API-V2 2), the general pages into `assets/help/en/`. The generated HTML sits next to its source or in a folder of its own (decide and document); it carries `X-UA-Compatible: IE=edge` for the classic viewer (WI-0111).
2. **Generator** `tools/gen_help.py`: Markdown to HTML with one shared stylesheet (it must look good in the classic viewer, in WebView2 and in a browser); links between pages and to anchors; `--check` fails when an HTML file is stale or superfluous; a test runs `--check` (as `tests/test_element_includes.py`); a VS Code task `Tool: ...`. The Markdown library is a development dependency (`tests/requirements.txt`).
3. **Conversion of v1, once:** a script (in `tools/`, may be removed afterwards) turns the 149 v1 pages and the general pages into Markdown; check tables, images and the key list by eye on a few pages.
4. **The 29 core pages:** check each against its v2 element (parameters, behaviour, the MIGRATION deviations) and the v2 language (for example no `%var%` in an expression). Correct them in English.
5. **The general page on variables and expressions:** rewrite it for the v2 language from `doc/EXPRESSION-LANGUAGE.md`, for users, with examples. Check the other general pages for statements that are only true in v1.
6. **Tests:** every registered class of the core set has a page; the links between the pages resolve; the generated HTML is current.
7. **S0008:** the pages of its elements stay as converted. Write a list of what S0008 must check (one line per page with a v1 statement found).

## Acceptance criteria

- The tests of task 6 are green; the list of task 7 is in the result. ELEMENT-API-V2 is updated. REQ-ELM-020 and REQ-LNG-040 are updated.

## Not part of this

The viewers (WI-0111, WI-0115); the pages of the elements of S0008 (corrected with their element, E0097); translations and translation tools (S0009).

## Refinement from WI-0104 (proposal, not decided)

Written by the acceptance of S0006 (WI-0104, E0095). The project owner decides whether this stands; the package may refine it again and says so in its result.

- The generator writes committed HTML (E0100); the check that the HTML is current must be a test in the fast tier, or the project will forget to regenerate it.
