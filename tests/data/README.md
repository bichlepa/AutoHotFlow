# Test data

Everything the tests read lives here, so a fresh clone or worktree needs nothing outside the repository.
Files are compared byte for byte; `.gitattributes` turns line-ending conversion off for `flows/` and `variables/`.

| Folder | Content | Origin |
|---|---|---|
| `flows/v1_examples/` | 23 example flows and 4 demo flows of AutoHotFlow v1, unchanged | copied from `v1/AppData/Saved Flows` and `v1/Saved Flows/demo flows` |
| `flows/personal/` | 4 flows of the project owner, published with consent | copied from the owner's working directory; the only change is the user name in a path (`C:\Users\example\Downloads` in `Flow 1730863959`) |
| `variables/` | Synthetic variable files (`.ahfvd`/`.ahfvar`) in the v1 format: objects (a list, a map) and texts (a float text `0.500000`, a text with a leading zero and a non-ASCII character), UTF-8 with BOM like the files of v1 (WI-41) | hand-made, no real data |
| `flows/s1_acceptance/` | One flow in the v1 format with the test elements (`Action_TestSetVar`, `Action_TestExprParams`): sets a variable of each kind and has expression texts that the loader converts (WI-43); the flow ID `Flow 1000000001` is the folder name of the static variables in `variables/` | hand-made |
| `skeleton_flow.json` | Minimal flow of the walking skeleton | hand-made |

## Rules

- Never add flows or variables from a working directory without checking them for personal data (paths, user names,
  URLs with IDs, names of people, credentials). Real variable files are not added at all: they change with every
  test run and may contain private values. Create synthetic ones.
- Tests must not write into this folder. Tests that change data copy it into a temporary directory first.
- A new variable file is added when a feature needs it, not in advance.
