# STATUS: AutoHotFlow → AHK v2

Stand: 2026-10-12 (nach WI-29). Branch `v2-port`. Code-Stand: Commit `20efac2` (WI-29, Code-Änderungen von WI-29 beginnen bei `31afcc2`); seitdem nur Dokumente.
Aktuelle Phase: **Phase 2b (Härtung vor Phase 3) ist abgeschlossen mit offenen Punkten** (WI-18 bis WI-29 erledigt, Ergebnisse in `work_items/phase2b/`). Phase 3 ist nicht begonnen und braucht die Freigabe des Projektinhabers; offene Entscheidungen des Projektinhabers stehen in `work_items/HANDOVER.md`.

Davor: **Phase 2 (Walking Skeleton) technisch abgeschlossen, 15 von 17 Paketen fertig.** Offen: WI-13 nur wegen der manuellen GUI-Prüfung, WI-14 (optional, Entscheidung E6: früh in Phase 3) nicht gebaut. WI-17 ist bis Schritt 5 erledigt; der Phase-3-Plan (`work_items/phase3/README.md`) und die Fragenliste an den Projektinhaber (WI-17 Schritte 6 und 7) fehlen noch.

Detailliertes Handover: `work_items/HANDOVER.md`.

## Erledigt

- **Phase 0:** Bestandsaufnahme in `work_items/ANALYSE.md`, Lock-Audit in `work_items/analysis_v1/`.
- **Phase 1:** Architektur in `doc/` (ARCHITEKTUR, PROTOKOLL, ELEMENT-API-V2, TESTSTRATEGIE, KONVENTIONEN, MIGRATION, HOW-TO).
- **Spike:** Named Pipe + Weckruf in AHK v2 (`work_items/spikes/`).
- **Repo-Umbau:** v1 unverändert in `v1/`, Arbeitsdokumente in `work_items/`.
- **Werkzeuge:** `tools/ahkrun.py` und Dialog-Wächter (keine hängenden Läufe durch Fehlerdialoge).

### Phase-2-Pakete

| Paket | Stand | Wichtigste Commits |
|---|---|---|
| WI-01 Testinfrastruktur | fertig | `400728e` |
| Dialog-Wächter, `ahkrun.py` | fertig | `d502043`, `62fd573` |
| WI-02 JSON | fertig, Parsen 1,5 s (Ziel 1 s, kein hartes Gate) | `16a6539` |
| WI-03 Core-Basics | fertig | `410aa91` |
| WI-04 Pipe-Schicht | fertig | `5c997e1`, `e62ed65` |
| WI-05 Nachrichtenschicht | fertig | `7888b9c` |
| WI-06 Rollenbasis | fertig | `c34e57a`, F-05-Fix `f7a728e` |
| WI-07 Supervisor | fertig | `6bcb290`, `2bc8424` |
| WI-08 Engine-Kern | fertig | `888dd6d` |
| WI-09 Element-Basis | fertig | `d11afa1` |
| WI-10 Engine-Rolle | fertig | `5825344`, F-01 `111fde0` |
| WI-11 Worker | fertig | `a28ee3a`, `1086e2e` |
| WI-12 Storage | fertig | `be3d79f`, F-04 `1adb088` |
| WI-13 UI-Stub | **Automatisierte Abnahme erfüllt, GUI-Bedienung nicht geprüft (Klicks Start/Stop, Verschieben des Fensters)** | `9aa9537`, `d953843` |
| WI-14 Triggerhost | **nicht gebaut** (optional). Rolle `triggerhost` ist ein Platzhalter | – |
| WI-15 Fault-Injection | fertig, 20 Wiederholungen ohne Hänger | `fd0b927` bis `4042f45` |
| WI-16 Stress und Messung | fertig; Editor-Zielgrößen nicht messbar | `83dd463` bis `604a4a9` |
| WI-17 Abschluss | Schritte 1 bis 5 erledigt, 6 und 7 offen | siehe unten |

### Phase-2b-Pakete (`work_items/phase2b/README.md`)

| Paket | Stand | Commit |
|---|---|---|
| WI-18 Testlaufzeit: parallele Ausführung | fertig | `a6711c5` |
| WI-19 Architekturwächter | fertig | `4a2a6e4` |
| WI-20 Entscheidungen und Beobachtungsliste | fertig | `f42ed73` |
| WI-21 Engine: Loop-Stack, Wiedereintritt, neueste Revision, `wait` | fertig | `9e84422` bis `5a705fc` |
| WI-22 Supervisor: Heartbeat, Startreihenfolge, 64 Bit, Pipe-Namen | fertig | `856ef22` bis `2da8beb` |
| WI-23 Diagnose I: Log des Supervisors, stderr der Kinder | fertig | `b47f42c` bis `ef34b5b` |
| WI-24 Hub routet über Kopffelder, gestaffeltes Laden | fertig | `0126ecc` bis `be3a2a3` |
| WI-25 Storage: Durchsatz, getrennte Warteschlangen (F-08) | fertig | `831c9e8` bis `f1efb7a` |
| WI-26 JSON: echte Wahrheitswerte | fertig | `1d07f5d` bis `45c501a` |
| WI-27 Worker-Pool-Lebenszyklus | fertig | `5404731` bis `bcc5c82` |
| WI-28 Diagnose II: Snapshot, Absturzbericht, Debug-Fenster | fertig | `d27d0ef` bis `e744800` |
| WI-29 Aufräumen und Abschluss | fertig, Abschlussläufe mit offenen Punkten (siehe unten) | `31afcc2` bis zum letzten Commit mit WI-29 im Betreff, Ergebnis in `phase2b/WI-29-aufraeumen-abschluss.md` |

### Abnahme der Phase 2 (`work_items/phase2/README.md`)

| # | Kriterium | Stand | Beleg (Test) |
|---|---|---|---|
| 1 | Supervisor, Storage, Engine, UI-Stub starten, sprechen über den Hub, fahren sauber herunter (Quittungen, harte Frist) | erfüllt | `test_supervisor.py::test_required_roles_are_ready_within_3_seconds`, `::test_clean_exit_with_healthy_children_within_2s_and_no_leftover_process`, `::test_frozen_child_at_exit_is_terminated_at_the_deadline`, `tests/fault/test_shutdown.py` |
| 2 | Hartcodierter Flow im v1-Format (Trigger → Action → Action) läuft in der Engine, jede Zustandsänderung kommt beim UI-Stub an | erfüllt | `test_engine.py::test_start_emits_the_documented_event_order`, `tests/e2e/test_ui_stub.py::test_headless_stub_logs_every_skeleton_event_in_order` (Daten `tests/data/skeleton_flow.json`) |
| 3 | Absturz und Einfrieren je eines Prozesses sowie ein Timeout: nichts hängt, jedes Szenario endet binnen Frist mit gemeldetem Fehler | erfüllt | `tests/fault/test_process_crash.py`, `test_process_hang.py`, `test_timeouts.py`, `test_orphans.py`, `test_pipe_break.py`, `test_storage_abort.py`; 20 Wiederholungen (382 Tests, 2 rot wegen Testfehler/F-06, danach 80 von 80 grün) |
| 4 | Stresstest (viele parallele Instanzen, schnelle Start/Stop-Folgen, Clients verbinden/trennen) ohne Hänger | erfüllt | `tests/stress/` (`test_parallel_instances.py`, `test_start_stop_storm.py`, `test_clients_churn.py`, `test_soak.py`); Messwerte in `work_items/phase2/measurements.md` |

Einschränkung zu 3: Der Absturzfall des Triggerhosts fehlt (nicht gebaut), UI-Abstürze sind nur für den Manager-Stub geprüft, nicht für einen Editor.

## Letzter Gesamtlauf

**Abschlussläufe von Phase 2b (WI-29, Code-Stand `20efac2`, 2026-10-12, ein Rechner mit 8 logischen CPUs, jeder Lauf allein, Ausgaben nicht im Repo):**

| Lauf | Ergebnis | Dauer |
|---|---|---|
| `python -m pytest tests -n 0 -q` (seriell) | **704 passed, 1 skipped, 1 failed**, 14 deselected. Rot: `tests/fault/test_debug_role.py::test_a_debug_role_in_the_session_ends_with_it` (`Chain.wait_flows`: Flow `skeleton` nach 20,0 s nicht geladen), siehe F-31 | 596 s |
| `python -m pytest tests -q` (parallel, `-n auto`) | **705 passed, 1 skipped**, ein Lauf | 113 s |
| `python -m pytest tests -m stress -q` | **13 passed** (zum ersten Mal vollständig nach F-07 und WI-25) | 211 s |
| `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` | **456 passed, 4 failed** von 460. Rot: `test_shutdown.py::test_healthy_session_exits_within_2_seconds_and_every_role_says_it_is_clean[5]` (`manager` `clean: false`), `[12]` (`storage` `clean: false`), `::test_frozen_storage_is_terminated_at_the_deadline_and_the_others_exit_clean[7]` und `[19]` (beide `manager`). Alle vier sind F-26 | 2527 s |
| `AHF_SOAK_CHURN=1 python -m pytest tests -m soak -q` (600 s mit Verbindungswechseln) | **1 passed** (zum ersten Mal mit Verbindungswechseln nach F-07; die Umgebungsvariable war gesetzt, die Testausgabe zeigt es nicht) | 609 s |

Weitere Prüfung: `test_debug_role.py` allein, 5 Läufe seriell: 55 von 55 grün (je rund 40 s). Der Fehlschlag aus dem seriellen Gesamtlauf ist also nur im Gesamtlauf aufgetreten (siehe F-31). Der parallele Lauf war einmal grün; die Instabilität unter Last (F-19, zeitempfindliche Stresstests) ist nicht erneut gemessen worden. Nach den Läufen waren keine Testprozesse übrig (nur angesehen); es liefen noch `AutoHotkeyU32.exe` (Allgemeine Hilfe.ahk) und `AutoHotkey64.exe` mit `src/AutoHotFlow.ahk` ohne Argumente (beides Prozesse des Projektinhabers).

Davor, im WI-19-Abschluss (Code-Stand `4a2a6e4`): `python -m pytest tests -q` **458 passed, 1 skipped in 48,4 s** (WI-18: seriell 333 s, parallel 47 bis 50 s; Details in `work_items/phase2b/WI-18-testlaufzeit.md`).

Vorher, im WI-17-Abschluss (Code-Stand `604a4a9`): `python -m pytest tests -q`: **431 passed, 1 skipped, 11 deselected in 345,60 s**, Exit 0. Der Skip ist der bewusste Test in `tests/test_ahk_runner.py`; die 11 deselected sind die Stress- und Soak-Tests (laufen nur mit `-m stress` bzw. `-m soak`). Danach waren keine von den Tests gestarteten AutoHotkey-Prozesse übrig (nur angesehen). Der Prozess PID 29328 aus früheren Berichten existierte nicht mehr; es liefen noch `AutoHotkeyU32.exe` (Allgemeine Hilfe.ahk) und das v1-`AutoHotFlow.exe` des Projektinhabers.

Stress (`python -m pytest tests -m stress -q`, laut `WI-16-stress.md`, vor dem F-07-Fix): 9 passed, 1 failed (F-07). Nach dem Fix laut WI-16-Bericht der Churn-Test grün; ein vollständiger Stresslauf nach dem Fix ist in diesem Abschluss **nicht** wiederholt worden. Dauerlauf 600 s: ein Lauf grün (WI-16).

## Messwerte (Zusammenfassung, Details in `work_items/phase2/measurements.md`, ein Rechner, der nebenbei lief)

| Zielgröße (ARCHITEKTUR 9) | Ergebnis |
|---|---|
| Latenz `cmd.engine.snapshot`, Leerlauf / unter Last | Median 1,44 / 1,51 ms, p99 1,9 / 12,6 ms: erfüllt (Client weckt den Hub; ohne Weckruf 226 ms) |
| Idle-CPU ohne Flow | 0,23 % des Gesamtsystems (8 CPUs): erfüllt; als Summe in Prozent eines Kerns 1,8 %: **verfehlt**, Lesart des Ziels offen |
| Start bis `ready` | Median 0,30 s (Ziel 3 s): erfüllt |
| Speicher bei 5 offenen Editoren, Zustandsänderung bis Neuzeichnen | **nicht gemessen** (keine Editor-Rolle). Kette ohne Editor: 68,3 MB |

## Entscheidungen

Aus der Freigabe des Projektinhabers:
1. Mehrere Prozesse, ein Editor-Prozess pro Flow. Begründung in `doc/ARCHITEKTUR.md` 2.1.
2. Zeichnen im Editor-Prozess hinter `Renderer`-Schnittstelle, später trennbar. Risiko nicht gemessen, Messung in Phase 3.
3. Worker-Prozesse für blockierende und AHK-Skript-Elemente.
4. Zielversion AHK v2.
5. Alte Flows und Variablen müssen unverändert laden.
6. Eigener Branch `v2-port`, temporärer `v1/`-Ordner.
7. Chrome-Paket entfällt.
8. Tests mit pytest (e2e, Fault Injection, Stress) plus AHK-Unit-Tests.
9. Direkter Port, kein v1-Fix-Branch.

## Entscheidungen Phase 2b (2026-10-11, verbindlich)

Vollständiger Wortlaut mit Begründung in `work_items/phase2b/README.md`. Die Beschreibung steht je Entscheidung an genau einer Stelle in `doc/`, die übrigen Stellen verweisen darauf.

| # | Entscheidung | Beschrieben in | Wirkt in |
|---|---|---|---|
| E1 | Ändern während der Ausführung ist erlaubt. Die Engine nutzt die neueste committete Revision. Debugger-Anforderungen dürfen nicht verbaut werden | `doc/ARCHITEKTUR.md` 4.2 (Semantiktabelle), 4.3 (Ausblick Debugger) | WI-20, WI-21 |
| E2 | Ausführungsrichtlinie `wait` wird umgesetzt | `doc/MIGRATION.md` M-11 | WI-21 |
| E3 | Worker-Pool: Supervisor startet und beendet Worker auf Anfrage der Engine, Worker im Job ohne Ping-Prüfung, Fristen hält die Engine | `doc/ARCHITEKTUR.md` 2.3 | WI-27 |
| E4 | Nur 64 Bit, 32 Bit wird beim Start abgewiesen | `doc/ARCHITEKTUR.md` Kopf | WI-20, WI-22 |
| E5 | Idle-CPU-Ziel gilt für das Gesamtsystem, erfüllt (0,23 %) | `doc/ARCHITEKTUR.md` 9 | – |
| E6 | Triggerhost (WI-14) wird früh in Phase 3 gebaut, nicht in Phase 2b | `doc/ARCHITEKTUR.md` 8 | Phase 3 |
| E7 | Bewusst zurückgestellte Punkte stehen in der Beobachtungsliste (unten) | dieser Abschnitt | – |
| E8 | JSON-Wahrheitswerte als echte Booleans. Das Flow-Schreibformat bleibt in Phase 2b unverändert, Format-Wechsel erst in Phase 3 | `doc/ARCHITEKTUR.md` 7 | WI-26 |

## Beobachtungsliste (E7)

Punkte, die bewusst nicht in Phase 2b behoben werden. Je Punkt: was, warum zurückgestellt, woran man erkennt, dass er wichtig wird, was dann zu tun ist.

- **F-02, Pipe beim Start unter Last nicht nach 2 s verfügbar.** Im ersten Gesamtlauf der Phase 2 zwei Supervisor-Tests, Ursache vermutet (Last des Testrechners), nicht nachgewiesen. Seitdem nicht wieder berichtet; im WI-18-Endstand (5 parallele Gesamtläufe mit 8 Workern) kein Fall. *Warum zurückgestellt:* ohne Reproduktion keine belastbare Ursache. *Erkennen:* die Meldung „Pipe nicht verfügbar nach 2,0 s“ in einem Gesamtlauf, vor allem bei parallelen Läufen. *Tun:* Lauf wiederholen und das Supervisor-Log des Tests ansehen (Hilfe: `AHF_TEST_KEEP=1`, wie in WI-18 beschrieben), Ursache festhalten, dann Fix oder Entwarnung in dieser Datei.
- **`deadlineMs` von `sys.shutdown` wird nicht überall ausgewertet.** Verifiziert: `Storage.OnShutdown` nutzt die Frist (`src/storage/Storage.ahk:62`, Warteschlange leeren bis Frist minus Puffer). `Engine.OnShutdown` (`src/engine/Engine.ahk:76`) und `StubManager.OnShutdown` (`src/manager/StubManager.ahk:99`) werten sie nicht aus. Die harte Frist erzwingt der Supervisor (`test_frozen_child_at_exit_is_terminated_at_the_deadline`). *Warum zurückgestellt:* die harte Frist reicht heute. *Erkennen:* eine Rolle braucht für Aufräumarbeit mehr Zeit, als die Frist lässt, und der Supervisor beendet sie hart, z. B. die Engine beim Stoppen vieler Instanzen. *Tun:* in `Engine.OnShutdown` eine Teilfrist je Instanz (2 s, ARCHITEKTUR 6.3) aus `deadlineMs` ableiten.
- **`tests/support/pyhub.py` ohne Weckruf.** `PyHub` antwortet nur per Abfrage (Fallback-Timer, Latenz rund 250 ms). Verifiziert: Nur `tests/support/test_client_hub.py` nutzt `PyHub`, alle anderen Tests nutzen `WakingHub`. *Warum zurückgestellt:* reines Testwerkzeug. *Erkennen:* ein neuer zeitkritischer Test nutzt `PyHub` und scheitert an einer Frist. *Tun:* auf `WakingHub` umstellen oder dort den Weckruf nachrüsten (ARCHITEKTUR 2.2).
- **Idle-CPU optimieren.** Ziel erfüllt (E5, 0,23 % des Gesamtsystems). Möglich wäre, den Sicherheitstimer der Engine (`src/engine/Engine.ahk:33`, `SAFETY_MS = 100`) nur bei laufenden Instanzen aktiv zu lassen. *Warum zurückgestellt:* kein Muss nach E5. *Erkennen:* Idle-CPU über 1 % im Gesamtsystem bei einer Messung mit Editor in Phase 3. *Tun:* Timer nur bei laufenden Instanzen, dann mit der Messmethode aus WI-16 neu messen.
- **Manuelle GUI-Prüfung des Manager-Stubs.** Die Klicks (Start/Stop, Fensterverschieben) sind nicht geprüft. Der Stub ist Wegwerf-Code, die Abnahme der Phase 2 ist automatisiert erfüllt. *Warum zurückgestellt:* kein Blocker. *Erkennen:* der Stub wird für Vorführungen genutzt oder ein Fehler im Stub blockiert einen Test. *Tun:* Anleitung in `work_items/phase2/WI-13-ui-stub.md` durchgehen, Ergebnis hier und in WI-13 festhalten.
- **Sporadischer Dialog-Test `test_msgbox_is_captured_and_closed`.** Einmal Timeout in Phase 2 (Ursache ctypes-argtypes behoben). In WI-18 scheiterten zwei Dialog-Wächter-Tests unter Parallellast, Ursache vermutet: wiederverwendete Prozess-IDs im Wächter, behoben in `tools/ahf_dialogwatch.py` (nicht einzeln nachgestellt). *Erkennen:* ein Test endet mit Exit 0 statt 97 oder mit Timeout. *Tun:* Dialogbericht in `%TEMP%\ahf_dialogs\` ansehen (Dateiname enthält seit WI-18 die Test-PID), Ursache festhalten.
- **Fristen der Rollen nach einem Standby (WI-33).** `Peer.Request` setzt jede Frist mit `SetTimer`; nach einem Standby der Maschine laufen alle fälligen Fristen einer Rolle auf einmal ab (Antwort `timeout`, der Aufrufer wiederholt). *Warum zurückgestellt:* hinnehmbar, E12 gilt dem Supervisor. *Erkennen:* nach dem Aufwachen des Rechners viele `timeout`-Antworten oder Wiederholungen gleichzeitig im Log. *Tun:* Fristliste im Tick der Rolle wie in `Hub` (`Hub.Tick`/`Hub.Shift`), Stillstand je Rolle messen. Nicht geprüft: das Verhalten nach einem echten Standby (getestet wurde nur das Einfrieren des Supervisors mit `psutil`).
- **F-05 und F-07 (Änderungen in `src/core/` ohne Absprache).** F-05 (`f7a728e`, Orphan-Guard in `Role.Console`) und F-07 (`4f566bb`, Speicherleck in der Verbindung). Im Review am 2026-10-11 gelesen, ohne Befund. *Offen:* Bestätigung durch den Projektinhaber. *Erkennen:* ein Befund im Review oder ein Test, der Speicher oder stderr betrifft. *Tun:* Bestätigung einholen oder Befund beheben.
- **F-11, Reihenfolge in `Supervisor._Tick` (WI-18): geschlossen in WI-22.** Deterministischer Test `tests/ahk/supervisor_tick.test.ahk` (ungelesenes `sys.bye`, Prozess schon beendet): mit der alten Reihenfolge `clean` falsch, mit `hub.Pump()` vor `children.Tick` wahr. Dass dieser Fehler auch den einmaligen Ausfall in WI-18 verursachte, bleibt vermutet, ist nach 2 x 50 Wiederholungen von `test_shutdown` (kein falsches `clean`) aber sehr wahrscheinlich. Bei erneutem Auftreten von `clean=false` zuerst das Supervisor-Log lesen. Details: "Ergebnis" in `work_items/phase2b/WI-22-supervisor-robustheit.md`.

## Funde (Entscheidung je Fund; eine Datei `findings.md` wurde nie angelegt, die Funde stehen in den Paketdateien)

| Fund | Inhalt | Entscheidung | Beleg |
|---|---|---|---|
| F-01 | Engine sendete `evt.engine.restarted` nicht | behoben | `111fde0`, `test_engine_restart_is_seen_and_resynced_without_restarting_the_stub` |
| F-02 | Zwei Supervisor-Tests im ersten Gesamtlauf mit "Pipe nicht verfügbar nach 2,0 s" (Last, größerer Einstieg). Ursache vermutet | bewusst offen, beobachten (Beobachtungsliste, E7). In den dokumentierten späteren Gesamtläufen (427, 431 grün) und im WI-18-Endstand nicht berichtet | `WI-13-ui-stub.md` |
| F-03 | Test startete Flow vor dem Laden (eigener Testfehler) | behoben | `WI-13-ui-stub.md` |
| F-04 | Storage verlor Log-Zeilen, wenn ein anderer Prozess die Datei offen hatte | behoben | `1adb088`, `test_no_log_line_is_lost_while_other_processes_hold_the_files` |
| F-05 | Orphan-Guard beendete vom Supervisor gestartete Rollen nicht (`Console` warf) | behoben | `f7a728e`, `tests/fault/test_orphans.py` (20/20). Änderung in `src/core/` ohne Absprache, bitte prüfen |
| F-06 | `clean` in `evt.process.exited` einmal `false` bei sauberem Ende. Ursache: `_OnGone` vor dem Lesen von `sys.bye` | **behoben** (WI-18 Reihenfolge `Pump` vor `children.Tick`, WI-22 deterministischer Test: alte Reihenfolge `clean=false`, neue `true`; `test_shutdown` 2 x 50 Wiederholungen, `clean` nie falsch) | `WI-15-fault-injection.md`, `phase2b/WI-22-supervisor-robustheit.md` |
| F-07 | Speicherleck 83 KB je Verbindung (Referenzzyklus in `PipeConnection`) | behoben | `4f566bb`, `test_many_connects_keep_the_memory_of_the_supervisor_flat` |
| F-08 | Storage drainierte Log mit rund 30 Zeilen/s, Warteschlange unbegrenzt | behoben in WI-25 (1493 Zeilen/s über 10 s gemessen, Obergrenze 20000 Einträge oder 8 MiB, getrennte Warteschlangen) | `WI-25-storage-durchsatz.md` |
| F-09 | `seq` der Engine-Ereignisse vertauscht bei 200 Instanzen | behoben | `4906f7d` |
| F-10 | Trigger als Aktion ausgeführt (Race zwischen `Advance` und Dispatch-Timer) | behoben; ob `_Dispatch` und das Klonen in `Advance` dasselbe Muster haben, ist nicht geprüft | `887988b` |
| F-11 | Reihenfolge in `Supervisor._Tick`: `sys.bye` konnte nach dem Prozessende gelesen werden, `clean` falsch (WI-18) | behoben in WI-18 (Pump vor Tick) und WI-22 (deterministischer Test `tests/ahk/supervisor_tick.test.ahk`). Siehe aber F-26 | `phase2b/WI-18-testlaufzeit.md`, `WI-22-supervisor-robustheit.md` |
| F-12 | `Scheduler.Advance` ruft `Pop` vor `finished → ready`; bei leerem Stack (M-14) wirft es statt den Thread mit `exception` zu beenden [gelesen] | offen, niedrig. Vorschlag: `Advance` fängt den Fehler und beendet den Thread mit `exception` | `phase2b/WI-21-engine-korrektheit.md` |
| F-13 | Weitere Prüfen-dann-Ändern-Stellen ohne Schutz (`Executor._OnFinish`/`_StopRun`, `_ElementStarted`/`_ElementStopped`, `WorkerBridge`) [gelesen, nicht reproduziert] | offen, beobachten (Beobachtungsliste) | `phase2b/WI-21-engine-korrektheit.md` |
| F-14 | `Ids.Next` erhöht und liest den Zähler in getrennten Zeilen; `ExecContext.Finish` prüft und setzt getrennt [gelesen, `src/core/` und `src/elements/`, nicht geändert] | offen, niedrig; in Phase 3 mit `Critical` absichern (Änderung in `src/core/` braucht Absprache) | `phase2b/WI-21-engine-korrektheit.md` |
| F-15 | Für ein gelöschtes Element sendet die Engine `evt.element.state` (`running`, dann `exception`) [beobachtet] | bewusst so gelassen: Clients ignorieren unbekannte Element-IDs | `phase2b/WI-21-engine-korrektheit.md` |
| F-16 | Fristen des Supervisors außer dem Heartbeat (`Shutdown.deadlineAt`, `Hub.Request`, Hello-Zeitlimit) laufen nach der Wanduhr und kennen einen Stillstand des Supervisors nicht [gelesen] | **geschlossen in WI-33 (E12)**: `Stall` misst den Stillstand an einer Stelle (Anfang von `Supervisor._RunTick`), `Children.OnStall`, `Hub.Shift`, `Shutdown.Shift` und `DiagReport.Shift` verlängern ihre Fristen um dessen Länge; `Hub.Request` nutzt eine Fristliste statt `SetTimer`. Rot, dann grün: `test_open_prepare_exit_request_keeps_its_remaining_time_after_a_stand_still` (vorher Ablauf 0,24 s nach dem Fortsetzen, nachher 5,11 s), `test_connection_without_hello_keeps_its_remaining_time_after_a_stand_still` (vorher 0,00 s, nachher 3,45 s). Offen bleibt F-35 | `phase2b/WI-33-worker-und-stillstand.md` |
| F-17 | Kind mit hoher Log-Last gibt in einem langen Stillstand des Supervisors auf (Pipe-Warteschlange 1000 Rahmen, Orphan-Frist) [gelesen, nicht getestet] | offen, niedrig | `phase2b/WI-22-supervisor-robustheit.md` |
| F-18 | Hub-Pipe nicht auf den Benutzer beschränkt (Option in WI-22 Punkt 5 nicht umgesetzt) | offen, niedrig; Name enthält Sitzung und Benutzer | `phase2b/WI-22-supervisor-robustheit.md` |
| F-19 | Zeitbudgets der Fault- und Supervisor-Tests sind unter Last (parallele Läufe) zu eng; in `test_shutdown.py` verdeckt die Zeitprüfung die Aussage über `clean` | offen. Die Reihenfolge der Assertions (`clean` zuerst) ist nicht geändert; Fristen nicht gelockert. Serieller Lauf ist die Referenz | `phase2b/WI-22-supervisor-robustheit.md`, Läufe in WI-29 |
| F-20 | Meldungen des Supervisors nach dem Weggang von `storage` (und bei einem Absturz des Supervisors) gehen nicht ins Log, nur auf stderr | offen, niedrig; teilweise durch den Absturzbericht (WI-28) abgedeckt | `phase2b/WI-23-diagnose-logpfade.md` |
| F-21 | Gesprächiges Kind kann `storage` fluten (200 Zeilen je Tick und Kind) | durch WI-25 entschärft (Durchsatz 1493 Zeilen/s, Obergrenze 20000 Einträge oder 8 MiB); Dauerlauf-Messung siehe WI-29 | `phase2b/WI-23-diagnose-logpfade.md`, `WI-25-storage-durchsatz.md` |
| F-22 | stdout und stderr der Kinder sind nicht unterscheidbar (eine Pipe) | bewusst so gelassen (reicht für die Diagnose) | `phase2b/WI-23-diagnose-logpfade.md` |
| F-23 | Die Engine zahlt für jede Flow-Datei doppelt (Parsen des Rahmens und des Flow-Textes): rund 0,23 s je Flow, 45 s für 200 Flows | offen, nicht umgesetzt; Alternativen (Flow als Objekt senden, Chunking, nativer Parser) für Phase 3 | `phase2b/WI-24-hub-routing-laden.md` |
| F-24 | `flows.list` wird beim Start einmal mit `not_found: no peer 'storage'` beantwortet, danach Wiederholung und unnötiges `evt.storage.error` | **geschlossen in WI-31**: die Engine wartet auf `storage` (Topic `process`, `cmd.process.list`), kein `evt.storage.error` mehr beim Start; Test `test_engine_waits_for_a_storage_that_starts_5_s_after_it_and_reports_no_error` | `phase2b/WI-31-engine-wartet-auf-storage.md` |
| F-25 | Ein von einem anderen Prozess dauerhaft gehaltenes Logfile verliert nach 3 s das ganze Bündel (bis 500 Zeilen) dieser Datei, nicht nur eine Zeile | offen, niedrig (gezählt und im Log vermerkt, F-04 unverändert) | `WI-25-storage-durchsatz.md` |
| F-26 | `evt.process.exited` meldet gelegentlich `clean: false` bei sauberem Ende (`manager`, aber auch `storage`). WI-26: 7 von 150 Läufen von `test_healthy_session_exits...` ohne WI-26, 5 von 480 mit WI-26. WI-29: 4 von 460 Läufen in `tests/fault` mit `AHF_FAULT_REPEAT=20` | **behoben in WI-30** (drei Ursachen, je ein Test rot, dann grün): A die Rolle verwarf beim Beenden ihre Sendewarteschlange (`Close`), jetzt `CloseWhenFlushed`; B der Supervisor bewertete das Ende während einer unterbrochenen Pump, jetzt erst nach dem Ende der Verbindung (Nachfrist 500 ms); C ein Schreibfehler des Hubs an das schon beendete Kind verwarf dessen ungelesenes `sys.bye`, jetzt wird bis zum Ende gelesen. Nach A und B blieb 1 von 400 Läufen von `test_shutdown.py` rot (`manager`), das führte zu C. Nach A, B und C: `AHF_FAULT_REPEAT=100`, `test_shutdown.py`, **400 von 400 grün**, `clean` in allen 200 Runden der beiden prüfenden Tests wahr. Welche Ursache die früheren Ausfälle erzeugte, ist vermutet (keine Logs) | `phase2b/WI-26-json-wahrheitswerte.md`, `phase2b/WI-29-aufraeumen-abschluss.md`, `phase2b/WI-30-sauberes-beenden.md` |
| F-27 | Wettlauf in `Children._Launch` (Zustand nach dem Hello überschrieben) | behoben (`9221437`); der Wettlauf selbst ist nicht deterministisch nachgestellt, nur `OnHello` ohne Pid hat einen Unit-Test | `phase2b/WI-27-worker-pool.md` |
| F-28 | Log-Einträge eines Workers erreichen `storage` nie (`SetLogTarget` fehlt) | offen, niedrig; braucht eine Entscheidung (Log-Pfad über Engine oder direkt), relevant für Phase 3 (Dialog-Elemente) | `phase2b/WI-27-worker-pool.md` |
| F-29 | Kind im Handshake wird vom Orphan-Guard nicht erfasst (bis 10 s Lebenszeit nach Supervisor-Tod) | offen, niedrig, in ARCHITEKTUR 6.3 nicht beschrieben | `phase2b/WI-27-worker-pool.md` |
| F-30 | Verlorenes `sys.busy {busy: false}` lässt den Worker beschäftigt erscheinen [vermutet] | offen, niedrig; aufgefangen durch die Annahmefrist der Engine (5 s) | `phase2b/WI-27-worker-pool.md` |
| F-31 | Einmal im seriellen Gesamtlauf von WI-28: `Chain.wait_flows` nach 20 s ohne geladene Flows im Test `test_the_role_starts_with_start_debug_and_shows_the_process_table` | offen, Ursache in WI-31 behoben [vermutet, nicht bewiesen]: die Engine gab nach 2,5 s auf, wenn `storage` später kam; jetzt wartet sie ohne Obergrenze (Test mit 5 s Verspätung rot, dann grün). **Geschlossen erst, wenn in WI-32 kein Fall mehr auftritt.** Vorher: nicht geklärt (31 Wiederholungen grün). Im WI-29-Gesamtlauf (seriell) erneut, diesmal in `test_a_debug_role_in_the_session_ends_with_it` (gleiche Datei, gleiche Meldung, 20,0 s); `test_debug_role.py` allein 5 x 11 Tests grün. Tritt also nur im langen seriellen Lauf auf (2 von 2 Gesamtläufen); der Testeinstieg von WI-29 ist nicht die Ursache (der erste Fall war vorher). Beim Wiederauftreten Supervisor-Log mit `AHF_TEST_KEEP=1` lesen | `phase2b/WI-28-diagnose-bericht-debugfenster.md` |
| F-32 | `tests/integration/test_storage.py::test_a_log_flood_is_written_at_more_than_1000_lines_per_second` einmal rot im parallelen Teil-Lauf von WI-30 (808 Zeilen/s statt mehr als 1000); einzeln seriell 3138 Zeilen/s | offen, niedrig: zeitempfindlicher Test unter Parallellast (wie F-19), für WI-32 | `phase2b/WI-30-sauberes-beenden.md` |
| F-33 | `Shutdown` meldet Exit 5 (`EXIT_FORCED`), sobald die Frist abläuft und nicht alle Kinder bewertet sind, auch wenn danach kein Prozess hart beendet wird (`_Force` setzt `forced`, `Tick` der Kill-Phase ruft `_Done(EXIT_FORCED)`) [gelesen]. Seit WI-30 kann ein schon beendetes Kind bis zu 500 ms unbewertet sein; endet es genau an der Frist, wäre der Exit-Code 5 statt 0 | **behoben in WI-33**: die Kill-Phase endet mit `EXIT_CLEAN`, `_Done` macht 5 daraus nur bei `children.AnyKilled()`. Nur im AHK-Unit-Test nachgestellt (`EndedAtTheDeadlineIsNoForcedExit`: mit der alten Zeile Exit 5, mit der neuen 0); im echten Supervisor nicht beobachtet | `phase2b/WI-30-sauberes-beenden.md`, `phase2b/WI-33-worker-und-stillstand.md` |
| F-35 | Die zeitgebundenen Stellen der Verbindung im Hub kennen keinen Stillstand des Supervisors: `PipeConnection.WRITE_GONE_MAX_MS` (1 s Lesen bis zum Ende nach einem Schreibfehler "Gegenseite weg") und die Drain-Frist von `CloseWhenFlushed` laufen nach der Wanduhr [gelesen, `src/core/ipc/`, nicht geändert, nicht beobachtet] | offen, niedrig: Folge wäre, dass die Verbindung eines schon gegangenen Prozesses nach dem Fortsetzen ohne den Rest ihrer Daten geschlossen wird (`peer_closed`) | `phase2b/WI-33-worker-und-stillstand.md` |

## Bekannte Probleme

### Aus v1 (werden durch den Port gegenstandslos, nicht gefixt)

Siehe `work_items/ANALYSE.md` Abschnitt 3. Verhaltensänderungen stehen in `doc/MIGRATION.md` (M-01 bis M-16).

### Im Port offen

- **Fremder Prozess:** `AutoHotkey64.exe` PID 29328 (`/restart /script …\src\AutoHotFlow.ahk`) wurde in früheren Berichten gemeldet; am 2026-10-11 nach dem Gesamtlauf nicht mehr vorhanden. Nie von den Tests gestartet oder beendet.
- **Fortschrittshaken** in `work_items/phase2/README.md`: im Abschluss gesetzt, WI-13 und WI-14 bewusst nicht (WI-17 erst nach Schritt 7).
- **Sporadischer Dialog-Test** `test_msgbox_is_captured_and_closed`: einmal Timeout, Ursache (ctypes-argtypes) behoben, Status vermutet.
- **`deadlineMs`** von `sys.shutdown`: Nur der Storage wertet den Wert für seine Arbeit aus, Engine und Manager-Stub nicht (siehe Beobachtungsliste); seit WI-30 begrenzt der Rest der Frist (höchstens 1 s) bei jeder Rolle das Leeren der Sendewarteschlange vor dem Ende. Die Frist erzwingt der Supervisor durch hartes Beenden (`test_frozen_child_at_exit_is_terminated_at_the_deadline`).
- **`tests/support/pyhub.py`** sendet keinen Weckruf (Tests nutzen `WakingHub`, siehe Beobachtungsliste).
- **Löschen eines laufenden Flows:** Der Befehl fehlt (Phase 3). `Executor.FlowDeleted` stoppt die Instanzen sofort, ohne Frist und ohne Quittung (WI-21, ARCHITEKTUR 4.2); in v1 brach `DeleteFlow` nach 10 s ab. Das ist eine Entscheidung des Agenten in WI-21, vom Projektinhaber **nicht bestätigt**.
- **Worker-Waisen:** entschieden (E10) und umgesetzt in WI-33: Endet die Engine (außerhalb des Beendens der Sitzung), beendet der Supervisor sofort alle lebenden `worker:*` (`evt.process.exited` mit `reason` "engine gone"). Gemessen: Worker mit hängendem Job 0,21 s nach dem Tod der Engine weg; ohne Neustart (`--restart-max=0`) bleibt kein Worker übrig.
- **Obergrenze des Log-Puffers** im Storage (20000 Einträge oder 8 MiB, WI-25): fester Wert; ob sie eine Einstellung wird (Phase 3), ist offen.
- **Dangling-Verbindungen:** 154 von 1039 in den Beispielflows. M-13 legt fest: ignorieren und mit `f1`-Log melden.
- **Test-Laufzeit:** Der Standardlauf ist seit WI-18 parallel; am Ende von Phase 2b 113 s parallel und 596 s seriell (706 Tests). Er wächst mit jedem Paket, Grenze und Messung in WI-18.
- **Paralleler Lauf unter Last:** F-19 (zu enge Zeitbudgets der Fault-Tests), F-26 (behoben in WI-30) und zeitempfindliche Stresstests (`clients_churn[smoke]`, `big_flows[smoke]`) sind in früheren parallelen Läufen (WI-22 bis WI-27) rot geworden; die Hub-Frage aus WI-23 (`sys.hello` 15 s lang unbeantwortet) ist nicht erklärt. Der parallele Abschlusslauf war einmal grün. Der serielle Lauf ist die Referenz.

### Nicht geprüft

Timing unter Systemlast (parallele Läufe siehe oben), zweiter Windows-Benutzer und Standby, Screenshots bei gesperrtem Desktop, Editor-Zeichnen (Phase 3), GUI-Bedienung des Stubs und des Debug-Fensters von Hand (Anleitung in `WI-28`), echte blockierende Dialog-Elemente im Worker, Worker-Pool im Dauerlauf mit mehr als 3 Workern, Triggerhost (nicht gebaut), AHK-Client (Editor) als Gegenstelle der Latenzmessung, Idle-CPU und Speicher mit warmem Worker (nicht neu gemessen).

## Nächste Schritte

1. Projektinhaber: offene Entscheidungen in `work_items/HANDOVER.md` ("Offene Entscheidungen") beantworten und die Freigabe für Phase 3 erteilen. Den Phase-3-Plan (`work_items/phase3/README.md`) entwirft der Projektinhaber mit Claude (WI-17 Schritte 6 und 7).
2. F-31 (Flows nach 20 s nicht geladen, nur im langen seriellen Lauf): Ursache in WI-31 behoben, Abnahme im Gesamtlauf von WI-32 (beim Wiederauftreten Supervisor-Log mit `AHF_TEST_KEEP=1` lesen). F-26 ist in WI-30 behoben.
3. Beobachtungsliste (oben) bei jedem Gesamtlauf im Blick behalten.
4. Projektinhaber: GUI des Stubs einmal von Hand prüfen (Anleitung in `WI-13-ui-stub.md`), danach WI-13 abhaken; ebenso das Debug-Fenster (Anleitung in `WI-28`).
5. `work_items/` und `v1/` erst nach der Portierung entfernen (Entscheidung des Projektinhabers, nicht jetzt).
