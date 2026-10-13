# History of the Work Packages

The work packages (WI-xx) were planning files in `work_items/`. They were removed from the working tree after phase 2b. Their content and history are in git:

- The tag `v2-phase2-final` (commit `fc85151`, WI-35 final) is the last commit in which the work-item files existed.
- Show a file as it was at the tag: `git show v2-phase2-final:work_items/<path>`, for example `git show v2-phase2-final:work_items/phase2b/README.md`.
- List the commits of one package: `git log --grep="^WI-xx:"`. Commit messages start with the package ID, so this lists exactly the commits of that package. Add `--reverse` for oldest first.

Commit IDs in the table below are the short IDs from the sources. The "Commits" column is in commit order (oldest first). The rows for WI-18 to WI-33 are taken from the table "Commits je Paket" in `v2-phase2-final:work_items/HANDOVER.md`. The rows marked "git log" are not in that table; they were added from `git log --reverse --grep="^WI-xx:" v2-phase2-final`.

## Phases and packages

| Phase | Packages | Status (per sources) |
|---|---|---|
| Phase 0 and 1 | none (analysis and architecture, no WI numbers; commit `d3e0650` is the Phase 2b plan) | done |
| Phase 2, walking skeleton | WI-01 to WI-17 | done, except WI-13 (manual GUI check) and WI-14 (not built, decision E6) |
| Phase 2b, hardening before phase 3 | WI-18 to WI-29 | done, with open points (end state of phase 2b) |
| Fix block | WI-30 to WI-35 (WI-30, WI-31, WI-33, WI-32, WI-34, WI-35 in this order of work) | done; acceptance green in WI-35, cycle 1 |
| Phase 3 | WI-36 to WI-43 | approved by the project owner on 2026-10-13; the work items are open |

WI-36 to WI-43 are in `work_items/phase3/` in the working tree. They are not tracked by git and have no commits (checked with `git ls-files`).

## Packages and commits

| Package | Title | Commits (oldest first) | Source |
|---|---|---|---|
| Plan phase 2b | Umsetzungsplan (not WI-prefixed) | `d3e0650` | HANDOVER table |
| WI-01 | Test- und Laufinfrastruktur | `400728e` | git log |
| WI-02 | JSON-Baustein | `16a6539` | git log |
| WI-03 | Ids, Fehler, Argumente, Log-Client | `410aa91` | git log |
| WI-04 | Pipe, Rahmen, Weckruf | `5c997e1` | git log |
| WI-05 | Nachrichtenschicht (Peer, Dispatcher) | `7888b9c` | git log |
| WI-06 | Einstieg und Rollenbasis | `c34e57a` | git log |
| WI-07 | Supervisor (Hub, Prozessüberwachung, Beenden) | `6bcb290`, `16fbc6a`, `3701f79`, `2bc8424`, `c4cff06` | git log |
| WI-08 | Engine-Kern (Zustandsautomaten, Flowmodell) | `888dd6d` | git log |
| WI-09 | Element-Basis und Demo-Elemente | `d11afa1` | git log |
| WI-10 | Engine-Rolle | `c6167c7`, `5825344`, `fe78728`, `3f45002`, `068afea`, `111fde0` | git log |
| WI-11 | Worker-Rolle | `a28ee3a`, `1086e2e`, `8b284e8`, `5483de5` | git log |
| WI-12 | Storage-Rolle (Skeleton) | `419051a`, `be3d79f`, `f02568d`, `0b420c8`, `b8ecdc7`, `1adb088` | git log |
| WI-13 | UI-Stub | `9aa9537`, `d953843`, `e763cc7`, `94f126c` | git log |
| WI-14 | Triggerhost (Skeleton, optional) | none (not built, decision E6) | git log |
| WI-15 | Fault-Injection-Tests | `1bc5f23`, `fd0b927`, `c1959d5`, `5c93be9`, `6d35734`, `6d4929c`, `1be0f39`, `4042f45` | git log |
| WI-16 | Stresstest und Messung | `83dd463`, `4906f7d`, `f7195ad`, `0a8afb1`, `1f4387b`, `887988b`, `8bb02bf`, `1c09e13`, `604a4a9` | git log |
| WI-17 | Abschluss, Status, Überprüfung | `3f6462c`, `b0a6c53`, `5153ec3`, `0a7924a`, `02d01b0`, `cded4e2`, `95a804c` | git log |
| WI-18 | Testlaufzeit: parallele Ausführung | `a6711c5` | HANDOVER table |
| WI-19 | Architekturwächter | `4a2a6e4` | HANDOVER table |
| WI-20 | Entscheidungen und Beobachtungsliste dokumentieren | `f42ed73` | HANDOVER table |
| WI-21 | Engine: Loop-Stack, Wiedereintritt, neueste Revision, `wait` | `9e84422`, `26cada9`, `58c17d9`, `a06623f`, `5a705fc` | HANDOVER table |
| WI-22 | Supervisor: Heartbeat, F-06, Startreihenfolge, 64 Bit, Pipe-Namen | `856ef22`, `dfe8137`, `ae919f9`, `6870a6f`, `638ce3a`, `c7a07fe`, `2da8beb` | HANDOVER table |
| WI-23 | Diagnose I: Log des Supervisors, stderr der Kinder | `b47f42c`, `6892034`, `04bf3af`, `f0878c2`, `ef34b5b` | HANDOVER table |
| WI-24 | Hub routet über Kopffelder, Engine lädt gestaffelt | `0126ecc`, `87fd20f`, `c052813`, `f9aa362`, `b76288d`, `be3a2a3` | HANDOVER table |
| WI-25 | Storage: Log-Durchsatz und getrennte Warteschlangen | `831c9e8`, `41d1265`, `1e0f4d7`, `bff8955`, `f29b267`, `f1efb7a` | HANDOVER table |
| WI-26 | JSON: echte Wahrheitswerte auf der Leitung | `1d07f5d`, `787dcf1`, `aa55dfd`, `a55e164`, `7d0bd5d`, `45c501a` | HANDOVER table |
| WI-27 | Worker-Pool-Lebenszyklus | `5404731`, `a7fa998`, `55abcbf`, `682a729`, `961fed2`, `9221437`, `edaad96`, `762b4a7`, `0ad3847`, `bcc5c82` | HANDOVER table |
| WI-28 | Diagnose II: Snapshot, Absturzbericht, Debug-Fenster | `d27d0ef`, `32234b2`, `d35b5d7`, `3e00b94`, `2b1f07e`, `b450a5c`, `fec7d06`, `e744800` | HANDOVER table |
| WI-29 | Aufräumen und Abschluss | `31afcc2`, `1a6f5e4`, `facf064`, `20efac2`, `5555686`, `6d4d799`, `030cc31` (the last three are the documents "danach" in the table; from git log) | HANDOVER table, completed from git log |
| Plan fix block | Work packages WI-30 to WI-33 (not WI-prefixed) | `d79fd89` | git log |
| WI-30 | Sauberes Beenden (F-26) | `7b1da26`, `29b3635`, `cdee87f`, `598e0fd`, `5a3a83c` | HANDOVER table |
| WI-31 | Engine wartet auf `storage` (F-31, F-24) | `4bf303f`, `f7c9b48`, `e4b5c5b`, `9fb95d8` | HANDOVER table |
| WI-33 | Worker enden mit der Engine (E10), Fristen nach Stillstand (F-16, E12) | `198d86e`, `576ab57`, `3d2bd06`, `751416d`, `c29d810` | HANDOVER table |
| WI-32 | Teststabilität und Abschluss des Blocks | `8d0e65a`, `056a1d5`, `c454658`, `ef90ede`, `bb39719`, `9ecdbb5`, `0a89f65`, `d9bfbaf` (the last three are the documents and the acceptance run "danach"; from git log) | HANDOVER table, completed from git log |
| WI-34 | Funde aus der Abnahme (F-37 bis F-42), Abnahme wiederholen | `a7dd1ad`, `6e5fc35`, `7f460ba`, `04192f9`, `27d49cb`, `57684d7`, `4ef3b38`, `6013d58`, `11e3a96`, `03664d1`, `fb0df1c`, `ce97772`, `39591cd`, `a6e4c68`, `3406214`, `645d99d`, `1c0da27` | git log (not in HANDOVER table) |
| WI-35 | Bugfix-Schleife bis zur grünen Abnahme | `ae14180`, `9263f28`, `abd993c`, `8f9ecdf`, `f6c32e7`, `2f2e6e5`, `be815b2`, `fc85151` (tag) | git log (not in HANDOVER table) |

Notes on the table:

- The HANDOVER table has no rows for WI-01 to WI-17, WI-34 and WI-35. Those rows come from `git log`. The phase 2 rows are complete per package; the sources do not list them separately.
- Commits without a WI prefix are not assigned to a package by the sources, except the two plan commits named in the table.
- The tag commit `fc85151` is the WI-35 commit "Fix-Block WI-30 bis WI-35 abgeschlossen, Abnahme grün". Commits after the tag (on `HEAD`) are documentation translations only, with no WI prefix.
- The fix-block acceptance runs that were not green (WI-32, WI-34) are recorded in `v2-phase2-final:work_items/STATUS.md`, not here.
