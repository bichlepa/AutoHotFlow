# STATUS: AutoHotFlow → AHK v2

Stand: 2026-10-12 (nach WI-32, Teil 1 und 3). Branch `v2-port`. Code-Stand: Commit `c29d810` (WI-33) plus `8d0e65a` (WI-32, nur `WriteQueue` mit austauschbarer Uhr für Unit-Tests); sonst Tests und Dokumente.
Aktuelle Phase: **Fix-Block WI-30 bis WI-33 ist umgesetzt** (Nachtrag in `work_items/phase2b/README.md`, Entscheidungen E9 bis E15). **Offen: die Abnahmeläufe von WI-32 (Aufgabe 2)**, sie fährt ein eigener, späterer Agent (genaue Befehle im Ergebnis von `phase2b/WI-32-teststabilitaet-abschluss.md`); F-31 bleibt offen, bis dort kein Fall mehr auftritt. Als Nächstes folgt der Phase-3-Plan, den der Projektinhaber mit Claude entwirft. Phase 3 ist nicht begonnen und braucht die Freigabe des Projektinhabers. Davor war Phase 2b (Härtung vor Phase 3, WI-18 bis WI-29, Ergebnisse in `work_items/phase2b/`) abgeschlossen mit offenen Punkten; offene Entscheidungen: `work_items/HANDOVER.md`.

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
| WI-30 Sauberes Beenden (F-26) | fertig | `7b1da26` bis `5a3a83c` |
| WI-31 Engine wartet auf `storage` (F-24, F-31) | fertig, F-31 offen bis zur Abnahme | `4bf303f` bis `9fb95d8` |
| WI-33 Worker enden mit der Engine (E10), Fristen nach Stillstand (F-16, E12) | fertig | `198d86e` bis `c29d810` |
| WI-32 Teststabilität und Abschluss des Blocks | Aufgabe 1 (Testbereinigung) und 3 (Dokumente) fertig; **Aufgabe 2 (Abnahmeläufe) offen** | `8d0e65a` bis zum letzten Commit mit WI-32 im Betreff |

### Abnahme der Phase 2 (`work_items/phase2/README.md`)

| # | Kriterium | Stand | Beleg (Test) |
|---|---|---|---|
| 1 | Supervisor, Storage, Engine, UI-Stub starten, sprechen über den Hub, fahren sauber herunter (Quittungen, harte Frist) | erfüllt | `test_supervisor.py::test_required_roles_are_ready_within_3_seconds`, `::test_clean_exit_with_healthy_children_within_2s_and_no_leftover_process`, `::test_frozen_child_at_exit_is_terminated_at_the_deadline`, `tests/fault/test_shutdown.py` |
| 2 | Hartcodierter Flow im v1-Format (Trigger → Action → Action) läuft in der Engine, jede Zustandsänderung kommt beim UI-Stub an | erfüllt | `test_engine.py::test_start_emits_the_documented_event_order`, `tests/e2e/test_ui_stub.py::test_headless_stub_logs_every_skeleton_event_in_order` (Daten `tests/data/skeleton_flow.json`) |
| 3 | Absturz und Einfrieren je eines Prozesses sowie ein Timeout: nichts hängt, jedes Szenario endet binnen Frist mit gemeldetem Fehler | erfüllt | `tests/fault/test_process_crash.py`, `test_process_hang.py`, `test_timeouts.py`, `test_orphans.py`, `test_pipe_break.py`, `test_storage_abort.py`; 20 Wiederholungen (382 Tests, 2 rot wegen Testfehler/F-06, danach 80 von 80 grün) |
| 4 | Stresstest (viele parallele Instanzen, schnelle Start/Stop-Folgen, Clients verbinden/trennen) ohne Hänger | erfüllt | `tests/stress/` (`test_parallel_instances.py`, `test_start_stop_storm.py`, `test_clients_churn.py`, `test_soak.py`); Messwerte in `work_items/phase2/measurements.md` |

Einschränkung zu 3: Der Absturzfall des Triggerhosts fehlt (nicht gebaut), UI-Abstürze sind nur für den Manager-Stub geprüft, nicht für einen Editor.

## Abnahmelauf Fix-Block (2026-10-12)

Abnahme von WI-32 (Aufgabe 2), Code-Stand `0a89f65`, ein Rechner mit 8 logischen CPUs, jeder Lauf allein (nichts anderes parallel), nacheinander von einem Skript gefahren; Ausgaben liegen im Scratchpad der Sitzung, nicht im Repo. Nach jedem der 10 parallelen Läufe sowie nach den übrigen Läufen waren keine Testprozesse übrig (nur angesehen); es liefen nur `AutoHotkeyU32.exe` (Allgemeine Hilfe.ahk) und ein `python.exe` der VS-Code-Erweiterung (Prozesse des Projektinhabers). **Ergebnis: nicht grün.** Grün waren nur der serielle Lauf und der Stresslauf.

| Lauf | Befehl | Ergebnis | Dauer | Rote Tests |
|---|---|---|---|---|
| 1 | `python -m pytest tests -q` | 733 passed, 1 skipped, 0 failed | 109 s | - |
| 2 | dito | 733 passed, 1 skipped, 0 failed | 97 s | - |
| 3 | dito | 733 passed, 1 skipped, 0 failed | 112 s | - |
| 4 | dito | 732 passed, 1 skipped, **1 failed** | 100 s | `tests/integration/test_worker.py::test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms` (`assert ans["ok"]` war False, Zeile 174: `cmd.worker.cancel` wurde nicht mit ok beantwortet; der Inhalt der Antwort steht nicht in der Meldung), F-37 |
| 5 | dito | 733 passed, 1 skipped, 0 failed | 106 s | - |
| 6 | dito | 732 passed, 1 skipped, **1 failed** | 113 s | `tests/fault/test_debug_role.py::test_refresh_stores_the_snapshot_of_every_role_and_the_supervisor` (`refreshed` 5, erwartet mindestens 6), F-38 |
| 7 | dito | 732 passed, 1 skipped, **1 failed** | 107 s | derselbe Test, `refreshed` 5 (`engineEvents` 3), F-38 |
| 8 | dito | 733 passed, 1 skipped, 0 failed | 119 s | - |
| 9 | dito | 732 passed, 1 skipped, **1 failed** | 110 s | `tests/stress/test_big_flows.py::test_hub_cost_of_a_large_frame_is_below_the_budget[smoke]` (Mittel 5,074 ms gegen Grenze 5,0 ms, Maximum 17,4 ms), F-39 |
| 10 | dito | 731 passed, 1 skipped, **2 failed** | 149 s | `tests/integration/test_engine.py::test_engine_resumes_loading_when_storage_restarts_in_the_middle_and_loads_only_the_missing_files` (kein `evt.engine.ready` nach dem Neustart von `storage`, F-40) und `tests/stress/test_measurements.py::test_start_to_ready_time[smoke]` (Sitzung endet mit Exit 5, Frist von 5 s beim Beenden abgelaufen, `storage` und `worker:1` mussten beendet werden, F-41) |
| streng | `AHF_TIMING_FACTOR=1 python -m pytest tests -q` | 732 passed, 1 skipped, **1 failed** | 115 s | `tests/fault/test_diagnose.py::test_the_handles_of_the_supervisor_stay_flat_over_50_restarts` (`crasher` nicht binnen 15,0 s wieder bereit, F-42) |
| seriell | `python -m pytest tests -n 0 -q` | **733 passed, 1 skipped, 15 deselected, 0 failed** | 628 s | - |
| Fault 20x | `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` | 463 passed, **1 failed** | 2547 s | `test_debug_role.py::test_refresh_stores_the_snapshot_of_every_role_and_the_supervisor` (`refreshed` 5 statt mindestens 6), F-38 |
| Stress | `python -m pytest tests -m stress -q` | **14 passed**, 735 deselected | 207 s | - |

**Häufigkeit bei den 10 parallelen Läufen:** Läufe 1, 2, 3, 5 und 8 grün, also **5 von 10 grün**; vier Läufe mit je einem roten Test, Lauf 10 mit zwei. Nur ein roter Test trat mehrfach auf: `test_refresh_stores_the_snapshot...` in Lauf 6, Lauf 7 und im Fault-Lauf (dort 1 Ausfall in 20 Wiederholungen). Kriterium "10 von 10 grün" **nicht erfüllt**.

**F-31:** In keinem der Gesamtläufe (10 parallel, streng, seriell) und im Fault-Lauf trat "Flow nach 20 s nicht geladen" auf (`test_debug_role.py` lief in allen Läufen; sein einziger Ausfall ist F-38, andere Ursache). Das Schließungskriterium (serieller Lauf und 10 parallele Läufe ohne Fall) ist erfüllt: **F-31 geschlossen** (Vorbehalt: es trat früher nur im langen seriellen Lauf auf, davon gab es jetzt einen). **F-36** (`sys.hello` unbeantwortet) ist in keinem der 14 Läufe aufgetreten, auch nicht in `test_shutdown.py`: Schließen empfohlen (nicht wieder aufgetreten, Ursache weiter unbekannt).

**Faktor 3 von `scaled()`:** Parallel (Faktor 3) riss keine mit `scaled()` gelockerte Grenze; mit `AHF_TIMING_FACTOR=1` (alle Grenzen streng, parallel) riss ebenfalls keine davon (ein roter Test, ein festes 15-s-Warten, F-42). Der Lauf mit Faktor 1 war nicht schlechter als die Läufe mit Faktor 3 (1 roter Test gegenüber im Mittel 0,6 roten Tests je Lauf bei Faktor 3). Der Faktor 3 ist damit weder bestätigt noch widerlegt: auf dieser Maschine hat er keine Wirkung gezeigt; die Ausfälle haben andere Ursachen (Rennen, feste Fristen, nicht skalierte Latenzgrenze). Eine Entscheidung zum Faktor bleibt beim Projektinhaber.

**Gesamtaussage:** Der Fix-Block ist nicht grün abgeschlossen. Seriell (Referenz) und Stress sind grün; parallel waren 5 von 10 Läufen grün, der Fault-Lauf hat einen roten Test. Die roten Tests sind neue Funde F-37 bis F-42 (F-38 dreimal, die übrigen je einmal beobachtet). In der Abnahme wurde keine Frist und kein Test geändert. F-26 (`clean: false`) ist in keinem Lauf aufgetreten (darunter 20 Wiederholungen von `tests/fault` mit `test_shutdown.py`).

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

## Entscheidungen Fix-Block (2026-10-12, verbindlich)

Wortlaut in `work_items/phase2b/README.md`, Nachtrag. E9 bis E13 sind Empfehlungen aus dem Review, die der Projektinhaber mit "Gut" angenommen hat; E14 und E15 hat er ausdrücklich so entschieden. E16 und E17 stammen aus dem Nachtrag WI-34 (Bestätigungen).

| # | Entscheidung | Beschrieben in | Wirkt in |
|---|---|---|---|
| E9 | Löschen eines Flows ohne Frist (`Executor.FlowDeleted`) ist bestätigt: Instanzen stoppen sofort, blockierende Worker beendet der Pool nach `ORPHAN_MS` | `doc/ARCHITEKTUR.md` 4.2 (Semantiktabelle) | WI-21, Doku in WI-32 |
| E10 | Worker enden mit der Engine: Endet die Engine, beendet der Supervisor alle `worker:*`; eine neue Engine baut ihren Pool neu auf | `doc/ARCHITEKTUR.md` 6.2 und 6.4 | WI-33 (umgesetzt) |
| E11 | Die Obergrenze des Log-Puffers im Storage bleibt eine interne Konstante (20000 Einträge oder 8 MiB), keine Einstellung | Abschnitt "Bekannte Probleme" unten | WI-25, Doku in WI-32 |
| E12 | F-16 wird gelöst: alle Fristen des Supervisors berücksichtigen einen Stillstand des Supervisors | `doc/ARCHITEKTUR.md` 6.2 (Zeile "Supervisor stand still") und 6.3 | WI-33 (umgesetzt) |
| E13 | Bestätigt: Änderungen F-05 und F-07 in `src/core/`, MIGRATION M-11, M-17, M-18 | `doc/MIGRATION.md` | WI-32 (Doku) |
| E14 | Schließen des Manager-Fensters (beendet im Stub die ganze Anwendung): das Verhalten des echten Managers wird in **Phase 3** entschieden | – | Phase 3 (**offen**) |
| E15 | Leeres `--data=` (Logs landen dann in `C:\Log`) ist vorerst egal: Beobachtungsliste, kein Fix | Beobachtungsliste unten | – |
| E16 | Die Änderung `Peer.CloseWhenFlushed` in `src/core/ipc/Peer.ahk` (WI-30, nicht im Paketwortlaut) ist bestätigt | `doc/ARCHITEKTUR.md` 6.3 | WI-30, bestätigt im Nachtrag WI-34 |
| E17 | `scaled()` (`tests/support/timing.py`) mit Faktor 3 im parallelen Lauf bleibt. Der serielle Lauf und `-m stress` sind die strenge Referenz und laufen mindestens am Ende jedes Pakets, das Zeitverhalten ändert, und am Ende jedes Blocks | `doc/TESTSTRATEGIE.md` (Zeitgrenzen) | WI-32, Regel in WI-34 |

## Beobachtungsliste (E7)

Punkte, die bewusst nicht in Phase 2b behoben werden. Je Punkt: was, warum zurückgestellt, woran man erkennt, dass er wichtig wird, was dann zu tun ist.

- **F-02, Pipe beim Start unter Last nicht nach 2 s verfügbar.** Im ersten Gesamtlauf der Phase 2 zwei Supervisor-Tests, Ursache vermutet (Last des Testrechners), nicht nachgewiesen. Seitdem nicht wieder berichtet; im WI-18-Endstand (5 parallele Gesamtläufe mit 8 Workern) kein Fall. *Warum zurückgestellt:* ohne Reproduktion keine belastbare Ursache. *Erkennen:* die Meldung „Pipe nicht verfügbar nach 2,0 s“ in einem Gesamtlauf, vor allem bei parallelen Läufen. *Tun:* Lauf wiederholen und das Supervisor-Log des Tests ansehen (Hilfe: `AHF_TEST_KEEP=1`, wie in WI-18 beschrieben), Ursache festhalten, dann Fix oder Entwarnung in dieser Datei.
- **`deadlineMs` von `sys.shutdown` wird nicht überall ausgewertet.** Verifiziert: `Storage.OnShutdown` nutzt die Frist (`src/storage/Storage.ahk:62`, Warteschlange leeren bis Frist minus Puffer). `Engine.OnShutdown` (`src/engine/Engine.ahk:76`) und `StubManager.OnShutdown` (`src/manager/StubManager.ahk:99`) werten sie nicht aus. Die harte Frist erzwingt der Supervisor (`test_frozen_child_at_exit_is_terminated_at_the_deadline`). *Warum zurückgestellt:* die harte Frist reicht heute. *Erkennen:* eine Rolle braucht für Aufräumarbeit mehr Zeit, als die Frist lässt, und der Supervisor beendet sie hart, z. B. die Engine beim Stoppen vieler Instanzen. *Tun:* in `Engine.OnShutdown` eine Teilfrist je Instanz (2 s, ARCHITEKTUR 6.3) aus `deadlineMs` ableiten.
- **`tests/support/pyhub.py` ohne Weckruf.** `PyHub` antwortet nur per Abfrage (Fallback-Timer, Latenz rund 250 ms). Verifiziert: Nur `tests/support/test_client_hub.py` nutzt `PyHub`, alle anderen Tests nutzen `WakingHub`. *Warum zurückgestellt:* reines Testwerkzeug. *Erkennen:* ein neuer zeitkritischer Test nutzt `PyHub` und scheitert an einer Frist. *Tun:* auf `WakingHub` umstellen oder dort den Weckruf nachrüsten (ARCHITEKTUR 2.2).
- **Idle-CPU optimieren.** Ziel erfüllt (E5, 0,23 % des Gesamtsystems). Möglich wäre, den Sicherheitstimer der Engine (`src/engine/Engine.ahk:33`, `SAFETY_MS = 100`) nur bei laufenden Instanzen aktiv zu lassen. *Warum zurückgestellt:* kein Muss nach E5. *Erkennen:* Idle-CPU über 1 % im Gesamtsystem bei einer Messung mit Editor in Phase 3. *Tun:* Timer nur bei laufenden Instanzen, dann mit der Messmethode aus WI-16 neu messen.
- **Manuelle GUI-Prüfung des Manager-Stubs.** Die Klicks (Start/Stop, Fensterverschieben) sind nicht geprüft. Der Stub ist Wegwerf-Code, die Abnahme der Phase 2 ist automatisiert erfüllt. *Warum zurückgestellt:* kein Blocker. *Erkennen:* der Stub wird für Vorführungen genutzt oder ein Fehler im Stub blockiert einen Test. *Tun:* Anleitung in `work_items/phase2/WI-13-ui-stub.md` durchgehen, Ergebnis hier und in WI-13 festhalten.
- **Sporadischer Dialog-Test `test_msgbox_is_captured_and_closed`.** Einmal Timeout in Phase 2 (Ursache ctypes-argtypes behoben). In WI-18 scheiterten zwei Dialog-Wächter-Tests unter Parallellast, Ursache vermutet: wiederverwendete Prozess-IDs im Wächter, behoben in `tools/ahf_dialogwatch.py` (nicht einzeln nachgestellt). *Erkennen:* ein Test endet mit Exit 0 statt 97 oder mit Timeout. *Tun:* Dialogbericht in `%TEMP%\ahf_dialogs\` ansehen (Dateiname enthält seit WI-18 die Test-PID), Ursache festhalten.
- **Fristen der Rollen nach einem Standby (WI-33).** `Peer.Request` setzt jede Frist mit `SetTimer`; nach einem Standby der Maschine laufen alle fälligen Fristen einer Rolle auf einmal ab (Antwort `timeout`, der Aufrufer wiederholt). *Warum zurückgestellt:* hinnehmbar, E12 gilt dem Supervisor. *Erkennen:* nach dem Aufwachen des Rechners viele `timeout`-Antworten oder Wiederholungen gleichzeitig im Log. *Tun:* Fristliste im Tick der Rolle wie in `Hub` (`Hub.Tick`/`Hub.Shift`), Stillstand je Rolle messen. Nicht geprüft: das Verhalten nach einem echten Standby (getestet wurde nur das Einfrieren des Supervisors mit `psutil`).
- **F-05 und F-07 (Änderungen in `src/core/` ohne Absprache): bestätigt am 2026-10-12 (E13), geschlossen.** F-05 (`f7a728e`, Orphan-Guard in `Role.Console`) und F-07 (`4f566bb`, Speicherleck in der Verbindung).
- **Leeres `--data=` schreibt nach `C:\Log` (E15).** Ist `--data=` leer angegeben, landen die Logs in `C:\Log` statt im Datenordner. *Warum zurückgestellt:* Entscheidung des Projektinhabers (E15), ein Aufruf mit leerem Wert ist ein Bedienfehler. *Erkennen:* unerwartete Dateien in `C:\Log` oder Logs, die im Datenordner fehlen. *Tun:* leeren Wert beim Start abweisen (Exit 2 mit Meldung). In WI-32 nicht neu geprüft; die Angabe stammt aus dem Review.
- **Zeitgrenzen im parallelen Lauf (F-19, Rest) und die Hub-Frage aus WI-23.** Seit WI-32 gilt `support.timing.scaled()` (Faktor 3 im parallelen, 1 im seriellen Lauf; `doc/TESTSTRATEGIE.md`). Die Hub-Frage (`sys.hello` 15 s lang unbeantwortet) ist in WI-32 wieder aufgetreten, siehe F-36. *Erkennen:* `AhfTimeout: no answer to obs#1` in `faultkit.connect`. *Tun:* F-36.
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
| F-19 | Zeitbudgets der Fault- und Supervisor-Tests sind unter Last (parallele Läufe) zu eng; in `test_shutdown.py` verdeckt die Zeitprüfung die Aussage über `clean` | **behandelt in WI-32**: die oberen Grenzen, die ein Produktversprechen prüfen, laufen über `support.timing.scaled()` (seriell unverändert, parallel Faktor 3; untere Grenzen, Anzahlen und Ergebnisse unverändert; `tests/support/timing.py`, `doc/TESTSTRATEGIE.md`). Der serielle Lauf bleibt die Referenz. Rest: F-36 | `phase2b/WI-22-supervisor-robustheit.md`, Läufe in WI-29 |
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
| F-31 | Einmal im seriellen Gesamtlauf von WI-28: `Chain.wait_flows` nach 20 s ohne geladene Flows im Test `test_the_role_starts_with_start_debug_and_shows_the_process_table` | **geschlossen in der Abnahme von WI-32 (2026-10-12)**: kein Fall in den Abnahmeläufen (siehe "Abnahmelauf Fix-Block"). Vorher: offen, Ursache in WI-31 behoben [vermutet, nicht bewiesen]: die Engine gab nach 2,5 s auf, wenn `storage` später kam; jetzt wartet sie ohne Obergrenze (Test mit 5 s Verspätung rot, dann grün). **Geschlossen erst, wenn in der Abnahme von WI-32 (Aufgabe 2, späterer Agent) kein Fall mehr auftritt.** In WI-32 Teil 1 und 3 ist `test_debug_role.py` im Teil-Lauf nicht aufgefallen (zählt nicht als Abnahme). Vorher: nicht geklärt (31 Wiederholungen grün). Im WI-29-Gesamtlauf (seriell) erneut, diesmal in `test_a_debug_role_in_the_session_ends_with_it` (gleiche Datei, gleiche Meldung, 20,0 s); `test_debug_role.py` allein 5 x 11 Tests grün. Tritt also nur im langen seriellen Lauf auf (2 von 2 Gesamtläufen); der Testeinstieg von WI-29 ist nicht die Ursache (der erste Fall war vorher). Beim Wiederauftreten Supervisor-Log mit `AHF_TEST_KEEP=1` lesen | `phase2b/WI-28-diagnose-bericht-debugfenster.md` |
| F-32 | `tests/integration/test_storage.py::test_a_log_flood_is_written_at_more_than_1000_lines_per_second` einmal rot im parallelen Teil-Lauf von WI-30 (808 Zeilen/s statt mehr als 1000); einzeln seriell 3138 Zeilen/s | **behoben in WI-32**: die strenge Rate (mehr als 1000 Zeilen/s, unverändert) läuft nur noch mit `-m stress` (ein Prozess, allein auf der Maschine; gemessen 3137 Zeilen/s); der Standardlauf prüft zeitunabhängiger, dass die ganze Flut binnen 60 s geschrieben ist (mindestens 200 Zeilen/s, sechsfache Reserve zum alten Wert von 30 Zeilen/s) | `phase2b/WI-30-sauberes-beenden.md` |
| F-33 | `Shutdown` meldet Exit 5 (`EXIT_FORCED`), sobald die Frist abläuft und nicht alle Kinder bewertet sind, auch wenn danach kein Prozess hart beendet wird (`_Force` setzt `forced`, `Tick` der Kill-Phase ruft `_Done(EXIT_FORCED)`) [gelesen]. Seit WI-30 kann ein schon beendetes Kind bis zu 500 ms unbewertet sein; endet es genau an der Frist, wäre der Exit-Code 5 statt 0 | **behoben in WI-33**: die Kill-Phase endet mit `EXIT_CLEAN`, `_Done` macht 5 daraus nur bei `children.AnyKilled()`. Nur im AHK-Unit-Test nachgestellt (`EndedAtTheDeadlineIsNoForcedExit`: mit der alten Zeile Exit 5, mit der neuen 0); im echten Supervisor nicht beobachtet | `phase2b/WI-30-sauberes-beenden.md`, `phase2b/WI-33-worker-und-stillstand.md` |
| F-35 | Die zeitgebundenen Stellen der Verbindung im Hub kennen keinen Stillstand des Supervisors: `PipeConnection.WRITE_GONE_MAX_MS` (1 s Lesen bis zum Ende nach einem Schreibfehler "Gegenseite weg") und die Drain-Frist von `CloseWhenFlushed` laufen nach der Wanduhr [gelesen, `src/core/ipc/`, nicht geändert, nicht beobachtet] | offen, niedrig: Folge wäre, dass die Verbindung eines schon gegangenen Prozesses nach dem Fortsetzen ohne den Rest ihrer Daten geschlossen wird (`peer_closed`) | `phase2b/WI-33-worker-und-stillstand.md` |
| F-36 | `sys.hello` des Beobachters 15 s lang unbeantwortet (`AhfTimeout: no answer to obs#1 within 2.0 s`, dann 15 s Wiederholungen in `faultkit.connect`) in `tests/fault/test_shutdown.py` (`test_healthy_session_exits...`, `test_ui_cancels_the_exit...`; mit dem Stand vor WI-32 auch `test_frozen_storage...` und `test_two_sessions...`), wenn `test_shutdown.py` zusammen mit `tests/e2e/test_ui_stub.py` oder mit 12 weiteren Testdateien parallel läuft. Das ist die Hub-Frage aus WI-23. [verifiziert: 2 von 2 Läufen mit 14 Dateien, 2 von 3 mit zwei Dateien, auch ohne die Änderungen von WI-32 (`git stash`); in diesen Läufen brauchten 9 Tests 22 bis 35 s, später nur noch 6 s] | **Abnahme 2026-10-12: in 14 Läufen nicht wieder aufgetreten, Schließen empfohlen.** Vorher: offen, Ursache nicht gefunden. Danach (die Maschine war wieder schnell) nicht mehr reproduzierbar: 3 Läufe mit zwei Dateien grün, 1 Lauf mit allen 14 Dateien grün (171 Tests, 38 s), auch mit 8 CPU-Brennern daneben grün (9 Tests, 12,7 s). Das Datenverzeichnis des roten Tests war leer (Log leer, `sup.stderr` leer): der Supervisor hatte die Pipe, schrieb aber nichts. Vermutet: zeitweise langsame Maschine (z. B. Dateizugriff), nicht bewiesen. Beim Wiederauftreten: `AHF_TEST_KEEP=1`, während des Hängens mit `psutil` die Prozesse der Sitzung ansehen (Zustand, CPU, Threads) und prüfen, ob das `AutoHotkey64.exe` des Supervisors überhaupt läuft | `phase2b/WI-32-teststabilitaet-abschluss.md` |
| F-37 | `test_worker.py::test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms` rot im parallelen Lauf: `cmd.worker.cancel` wird nicht mit `ok` beantwortet (`assert ans["ok"]`, Zeile 174; die Meldung enthält die Antwort nicht) | **Test korrigiert in WI-34, offen bis zur Abnahme.** Ursache nachgestellt: `Action_TestBlockWorker` blockiert 800 ms; kommt der Abbruch später, ist das Element fertig und `cmd.worker.cancel` wird mit `not_found` beantwortet (Pause von 1,0 s statt 0,1 s: dieselbe rote Zeile 174). Korrektur: Element mit `Duration` 3 s, Warten auf den Auftrag im Snapshot, Antwort in der Meldung (`test_worker.py::test_cancel_stops_the_running_element_...`, Commit `4ef3b38`). Vorher: offen, 1 von 10 parallelen Läufen (Lauf 4), seriell und sonst grün. Vermutet: der Test wartet nur 0,1 s zwischen `cmd.worker.run` und dem Abbruch, unter Last ist die Ausführung dann noch nicht angemeldet (Rennen im Test); nicht geprüft. Beim Wiederauftreten die Antwort `ans` ausgeben | Abnahme WI-32 |
| F-38 | `tests/fault/test_debug_role.py::test_refresh_stores_the_snapshot_of_every_role_and_the_supervisor`: `refreshed` ist 5, erwartet mindestens 6 (Supervisor, storage, engine, manager, debug, worker:1) | **Produkt und Test geändert in WI-34, offen bis zur Abnahme.** Ursache aus dem Code gelesen: `RefreshSnapshots` fragte nur Prozesse im Zustand `ready` (aus Sicht des Fensters); war `worker:1` dort noch `starting`, fehlte er (5 statt 6). Korrektur: nicht bereite Prozesse erscheinen mit `not ready (state: <Zustand>)` (`src/debugview/DebugView.ahk`, `cmd.test.debug state` liefert `states`); der alte Test wartet auf `ready`. Rot, dann grün: `test_debug_role.py::test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out` (Commit `6013d58`). Vorher: offen, 3 Ausfälle: parallele Läufe 6 und 7, Fault-Lauf (1 von 20 Wiederholungen); seriell grün. Vermutet: Rennen, der Test wartet nur darauf, dass `worker:1` in der Prozessliste steht, nicht darauf, dass sein Schnappschuss abrufbar ist, oder ein Teilnehmer hat noch nicht geantwortet; nicht geprüft, `RefreshSnapshots` in `src/debugview/DebugView.ahk` nicht gelesen | Abnahme WI-32 |
| F-39 | `tests/stress/test_big_flows.py::test_hub_cost_of_a_large_frame_is_below_the_budget[smoke]`: Mittel 5,074 ms gegen `HUB_FRAME_BUDGET_MS` 5,0 ms (Maximum 17,4 ms, 10 Läufe) im parallelen Lauf | **Test korrigiert in WI-34, offen bis zur Abnahme.** Die Grenze läuft jetzt über `scaled()` (Commit `11e3a96`; strikt seriell und unter `-m stress`). Messwert seriell nach den Änderungen von F-40: 2,07 ms. Vorher: offen, 1 von 10 parallelen Läufen (Lauf 9). Die Grenze war nicht über `scaled()` gelockert [vermutet, nicht erneut gelesen]; der strenge Lauf mit `-m stress` ist grün | Abnahme WI-32 |
| F-40 | `tests/integration/test_engine.py::test_engine_resumes_loading_when_storage_restarts_in_the_middle_and_loads_only_the_missing_files`: nach dem Neustart des Storage-Stubs kommt kein `evt.engine.ready` (Frist `READY_TIMEOUT_S`) | **behoben in WI-34, offen bis zur Abnahme.** Ursache belegt: niemand beantwortete eine weitergeleitete Anfrage, deren Ziel starb (weder `Hub` noch der Python-Hub des Tests); die Engine wartete auf ihre offene Leseanfrage bis `READ_TIMEOUT_MS` (30 s), der Test nur 15 s. Nachgestellt: Originaltest unter Last 1 von 24 rot; deterministisch (Stub stirbt mit offener Anfrage) Engine erst nach 31,0 s bereit. Korrektur: der Hub merkt sich weitergeleitete `cmd.*` (Kopffelder) und antwortet beim Ende der Verbindung des Ziels mit `peer_gone` (PROTOKOLL 2; gewählt statt Abbruch im `Peer`, Begründung im Paket). Rot, dann grün: `test_supervisor.py::test_open_request_to_a_*` (10 s ohne Antwort, nachher 0,07 bis 0,15 s), `test_engine.py::test_engine_resumes_loading_at_once_when_storage_dies_with_an_open_read` (31,0 s, nachher 1,04 s). Originaltest danach 48 von 48 grün unter Last. Vorher: offen, 1 von 10 parallelen Läufen (Lauf 10, dem langsamsten mit 149 s) | Abnahme WI-32, `phase2b/WI-34-abnahmefunde.md` (Ergebnis), Commits `04192f9`, `27d49cb` |
| F-41 | `tests/stress/test_measurements.py::test_start_to_ready_time[smoke]`: Sitzung endet mit Exit 5 statt 0; Log: `shutdown: deadline reached, terminating the remaining processes`, `storage` und `worker:1` mussten beendet werden (`worker:1` verband sich erst nach der Beendigungsanfrage) | **behoben in WI-34, offen bis zur Abnahme.** Produktfehler belegt: `sys.shutdown` ging einmal an die Gruppe; ein Kind, das noch startete, bekam es nie, seine Gruppe und `storage` warteten bis zur Frist. Korrektur: `Shutdown.OnHello` schickt `sys.shutdown` mit der Restfrist beim `sys.hello`, wenn die Gruppe des Kindes an der Reihe war (oder es in keiner ist); dazu streicht `Children.BeginShutdown` geplante Neustarts (zweiter Weg zu einem Kind mitten im Beenden). Rot, dann grün: `test_shutdown.py::test_a_child_that_says_hello_during_the_shutdown_...` (vorher Exit 5 an der Frist, nachher Exit 0 nach 3,1 s), Unit-Tests in `supervisor_tick.test.ahk`. Rest: F-43. Vorher: offen, 1 von 10 parallelen Läufen (Lauf 10, zusammen mit F-40) | Abnahme WI-32, `phase2b/WI-34-abnahmefunde.md` (Ergebnis), Commits `6e5fc35`, `7f460ba` |
| F-42 | `tests/fault/test_diagnose.py::test_the_handles_of_the_supervisor_stay_flat_over_50_restarts`: `crasher` nicht binnen 15,0 s wieder bereit (`chain.wait_restarted_ready(..., timeout=15)`, feste Zahl, nicht über `scaled()`) | **Test korrigiert in WI-34, Ursache nicht belegt, offen bis zur Abnahme.** Das "Supervisor-Log" der Meldung war leer (`sup.text()` ist stdout/stderr; die Logzeilen stehen in `Log/Log.txt`), die Frage Last oder verzögerter Neustart ist daher nicht zu beantworten. Die Neustartverzögerung ist im Produkt konstant 300 ms; ein Neustart über 15 s ist ein einmaliger Stillstand. 12 gleichzeitige Läufe ohne Skalierung (`AHF_TIMING_FACTOR=1`, 8 CPUs) waren alle grün, je rund 55 s. Korrektur: Wartezeit über `scaled()` (im Helfer `wait_restarted_ready`), Gesamtfrist des Tests ebenso, bei Überschreitung steht der Schwanz von `Log/Log.txt` in der Meldung (Commits `03664d1`, `fb0df1c`). Vorher: offen, 1 Ausfall im Lauf mit `AHF_TIMING_FACTOR=1` (parallel), in den anderen Läufen grün. Das Supervisor-Log stand nicht in der Meldung; Ursache unbekannt (Last oder Neustart-Verzögerung) | Abnahme WI-32 |
| F-43 | Ein Kind, das beim Erreichen seiner Gruppe im Beenden noch startet, hält diese und alle späteren Gruppen bis zu seinem `sys.hello` auf. Startet es langsamer als die Frist (Worker unter Last), wird `storage` an der Frist hart beendet, ohne `sys.shutdown` bekommen zu haben (Symptom wie F-41, seltener) [gelesen, nicht nachgestellt] | offen, niedrig, braucht eine Entscheidung (lockert die Reihenfolge der Ränge): Vorschlag, ein nie verbundenes Kind zählt nicht als Bedingung seiner Gruppe (es hat nichts gesendet, was `storage` schreiben müsste) | `phase2b/WI-34-abnahmefunde.md` (Ergebnis) |
| F-45 | `test_debug_role.py::test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out`: `refreshed` 2 statt 3, 1 von 10 parallelen Läufen (Abnahme WI-34). Ursache nicht geprüft. Stand Abnahme Zyklus 1 (2026-10-12): in 10 parallelen, 1 seriellen, 505 Fault-Läufen und 14 Stress-Läufen nicht aufgetreten (0 Ausfälle). Ursache weiter nicht geprüft. | offen |
| F-46 | `test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted`: seriell 1 Ausfall, Fault 20x 5 von 20 (kein `evt.process.crashed` für `worker:1`; einmal `peer_gone` statt `worker crashed`). Ursache nicht belegt. | offen |
| F-47 | `test_worker.py::test_cancel_of_the_hang_element_reports_stopped_within_500_ms`: `cmd.worker.cancel` 5 s unbeantwortet, seriell 1 Ausfall. Möglicherweise dieselbe Familie wie der Ausfall `test_cancel_stops_the_running_element...` im Abnahmelauf davor. Stand Abnahme Zyklus 1 (2026-10-12): in 10 parallelen und 1 seriellen Lauf nicht aufgetreten (0 Ausfälle). Ursache weiter nicht geprüft. | offen |

## Bekannte Probleme

### Aus v1 (werden durch den Port gegenstandslos, nicht gefixt)

Siehe `work_items/ANALYSE.md` Abschnitt 3. Verhaltensänderungen stehen in `doc/MIGRATION.md` (M-01 bis M-16).

### Im Port offen

- **Fremder Prozess:** `AutoHotkey64.exe` PID 29328 (`/restart /script …\src\AutoHotFlow.ahk`) wurde in früheren Berichten gemeldet; am 2026-10-11 nach dem Gesamtlauf nicht mehr vorhanden. Nie von den Tests gestartet oder beendet.
- **Fortschrittshaken** in `work_items/phase2/README.md`: im Abschluss gesetzt, WI-13 und WI-14 bewusst nicht (WI-17 erst nach Schritt 7).
- **Sporadischer Dialog-Test** `test_msgbox_is_captured_and_closed`: einmal Timeout, Ursache (ctypes-argtypes) behoben, Status vermutet.
- **`deadlineMs`** von `sys.shutdown`: Nur der Storage wertet den Wert für seine Arbeit aus, Engine und Manager-Stub nicht (siehe Beobachtungsliste); seit WI-30 begrenzt der Rest der Frist (höchstens 1 s) bei jeder Rolle das Leeren der Sendewarteschlange vor dem Ende. Die Frist erzwingt der Supervisor durch hartes Beenden (`test_frozen_child_at_exit_is_terminated_at_the_deadline`).
- **`tests/support/pyhub.py`** sendet keinen Weckruf (Tests nutzen `WakingHub`, siehe Beobachtungsliste).
- **Löschen eines laufenden Flows:** Der Befehl fehlt (Phase 3). `Executor.FlowDeleted` stoppt die Instanzen sofort, ohne Frist und ohne Quittung (WI-21, ARCHITEKTUR 4.2); in v1 brach `DeleteFlow` nach 10 s ab. **Bestätigt** vom Projektinhaber am 2026-10-12 (E9).
- **Worker-Waisen:** entschieden (E10) und umgesetzt in WI-33: Endet die Engine (außerhalb des Beendens der Sitzung), beendet der Supervisor sofort alle lebenden `worker:*` (`evt.process.exited` mit `reason` "engine gone"). Gemessen: Worker mit hängendem Job 0,21 s nach dem Tod der Engine weg; ohne Neustart (`--restart-max=0`) bleibt kein Worker übrig.
- **Obergrenze des Log-Puffers** im Storage (20000 Einträge oder 8 MiB, WI-25): fester Wert, interne Konstante, keine Einstellung (E11, 2026-10-12).
- **Dangling-Verbindungen:** 154 von 1039 in den Beispielflows. M-13 legt fest: ignorieren und mit `f1`-Log melden.
- **Test-Laufzeit:** Der Standardlauf ist seit WI-18 parallel; am Ende von Phase 2b 113 s parallel und 596 s seriell (706 Tests). Er wächst mit jedem Paket, Grenze und Messung in WI-18.
- **Paralleler Lauf unter Last:** F-19 (zu enge Zeitbudgets der Fault-Tests, in WI-32 über `scaled()` behandelt), F-26 (behoben in WI-30) und zeitempfindliche Stresstests (`clients_churn[smoke]`, `big_flows[smoke]`, in WI-32 mit `scaled()`) sind in früheren parallelen Läufen (WI-22 bis WI-27) rot geworden. Die Hub-Frage aus WI-23 (`sys.hello` 15 s lang unbeantwortet) ist nicht erklärt und in WI-32 wieder aufgetreten (F-36). Der serielle Lauf ist die Referenz; ob der parallele Lauf nun verlässlich ist, zeigt erst die Abnahme von WI-32 (Aufgabe 2).

### Nicht geprüft

Timing unter Systemlast (parallele Läufe siehe oben), zweiter Windows-Benutzer und Standby, Screenshots bei gesperrtem Desktop, Editor-Zeichnen (Phase 3), GUI-Bedienung des Stubs und des Debug-Fensters von Hand (Anleitung in `WI-28`), echte blockierende Dialog-Elemente im Worker, Worker-Pool im Dauerlauf mit mehr als 3 Workern, Triggerhost (nicht gebaut), AHK-Client (Editor) als Gegenstelle der Latenzmessung, Idle-CPU und Speicher mit warmem Worker (nicht neu gemessen).

## Nächste Schritte

1. Die Abnahme von WI-34 ist gefahren (siehe "Abnahmelauf WI-34 (2026-10-12, zweiter)"): parallel 9 von 10 grün, Stress grün, aber seriell und Fault 20x rot (F-45 bis F-47). Erst diese untersuchen. Älterer Stand: Die Abnahmeläufe von WI-32 sind gefahren (siehe "Abnahmelauf Fix-Block"), nicht grün. Die Funde F-37 bis F-42 untersuchen oder begründet zurückstellen, dann die parallelen Läufe wiederholen und den Haken für den Abnahmelauf in `phase2b/README.md` setzen. F-36: Schließen empfohlen.
2. Projektinhaber: offene Entscheidungen in `work_items/HANDOVER.md` ("Offene Entscheidungen", neu: E14 Manager-Fenster schließen) beantworten, den Phase-3-Plan (`work_items/phase3/README.md`, WI-17 Schritte 6 und 7) mit Claude entwerfen und die Freigabe für Phase 3 erteilen.
3. Beobachtungsliste (oben) bei jedem Gesamtlauf im Blick behalten.
4. Projektinhaber: GUI des Stubs einmal von Hand prüfen (Anleitung in `WI-13-ui-stub.md`), danach WI-13 abhaken; ebenso das Debug-Fenster (Anleitung in `WI-28`).
5. `work_items/` und `v1/` erst nach der Portierung entfernen (Entscheidung des Projektinhabers, nicht jetzt).

## Abnahmelauf WI-34 (2026-10-12, zweiter)

Abnahme von WI-34 Abschnitt 5, Code-Stand `645d99d` (HEAD zu Beginn), ein Rechner mit 8 logischen CPUs, jeder Lauf allein (kein anderer Lauf des Agenten parallel; nur die fremden Prozesse des Projektinhabers liefen), nacheinander von einem Skript gefahren, Start 19:17, Ende 20:37 (rund 80 min). Ausgaben liegen im Scratchpad der Sitzung, nicht im Repo. Keine Änderung an Produktcode, Tests oder Fristen. **Abweichung:** Die Prüfung auf übrige Testprozesse zwischen den Läufen sollte das Skript selbst machen, ihr PowerShell-Aufruf war falsch zitiert und lieferte nur Syntaxfehler; sie hat also zwischen den Läufen nichts geprüft. Nach allen Läufen von Hand angesehen: nur `AutoHotkeyU32.exe` (Allgemeine Hilfe) und `python.exe` (VS-Code-Erweiterung) des Projektinhabers, keine Testprozesse übrig.

| Lauf | Befehl | Ergebnis | Dauer | Rote Tests |
|---|---|---|---|---|
| 1.1 | `python -m pytest tests -q` | 745 passed, 1 skipped, **1 failed** | 121 s | `tests/fault/test_debug_role.py::test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out` (Zeile 93: `answer["refreshed"]` war 2, erwartet 3), F-45 |
| 1.2 | dito | 746 passed, 1 skipped, 0 failed | 119 s | - |
| 1.3 | dito | 746 passed, 1 skipped, 0 failed | 124 s | - |
| 1.4 | dito | 746 passed, 1 skipped, 0 failed | 120 s | - |
| 1.5 | dito | 746 passed, 1 skipped, 0 failed | 117 s | - |
| 1.6 | dito | 746 passed, 1 skipped, 0 failed | 125 s | - |
| 1.7 | dito | 746 passed, 1 skipped, 0 failed | 134 s | - |
| 1.8 | dito | 746 passed, 1 skipped, 0 failed | 151 s | - |
| 1.9 | dito | 746 passed, 1 skipped, 0 failed | 134 s | - |
| 1.10 | dito | 746 passed, 1 skipped, 0 failed | 111 s | - |
| 2 seriell | `python -m pytest tests -n 0 -q` | 744 passed, 1 skipped, 15 deselected, **2 failed** | 655 s | `tests/fault/test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted[0]` (kein `evt.process.crashed` für `worker:1`, F-46) und `tests/integration/test_worker.py::test_cancel_of_the_hang_element_reports_stopped_within_500_ms` (`cmd.worker.cancel` nach 5,0 s unbeantwortet, `AhfTimeout`, F-47) |
| 3 Fault 20x | `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` | 480 passed, **5 failed** | 2646 s | 5 von 20 Wiederholungen von `test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted` (Runden 2, 6, 15, 18, 19), F-46 |
| 4 Stress | `python -m pytest tests -m stress -q` | **14 passed**, 748 deselected | 197 s | - |

**Häufigkeit bei den 10 parallelen Läufen:** 9 von 10 grün, ein Lauf mit einem roten Test (Lauf 1.1). Laufzeit (pytest-Zeit) 111 bis 151 s, Mittel rund 127 s; der Abnahmelauf davor lag bei rund 110 s, WI-18 bei 48 s. Die Laufzeit ist also weiter gewachsen (mit 746 statt 733 Tests); die zehn langsamsten Tests wurden nicht ermittelt [nicht geprüft, hätte einen weiteren Lauf mit `--durations` gebraucht]. Seriell 655 s (Abnahmelauf davor 628 s), Fault 20x 2646 s (davor 2547 s), Stress 197 s (davor 207 s).

### Rote Tests

| Test | Häufigkeit | Meldung | Einordnung |
|---|---|---|---|
| F-45 `test_debug_role.py::test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out` (der in F-38 neu geschriebene Test) | 1 von 10 parallelen Läufen (1.1); im seriellen Lauf und in den 20 Fault-Wiederholungen nicht aufgetreten | `AssertionError ... assert 2 == 3`: `refreshed` war 2, erwartet 3 (Supervisor, storage, debug); Test hatte `late in snapshots` und den Text `not ready (state: starting)` schon bestanden | Nicht eingeordnet [nicht geprüft]. Belegt ist nur: das Kind `echo:slowhello4000` war laut Test noch `starting`, und eine der drei erwarteten Antworten fehlte. Vermutet: eine der Antworten (supervisor, storage oder debug) kam im Aktualisierungsfenster nicht rechtzeitig, unter Last im parallelen Lauf. Die Zählung `refreshed == 3` ist eine feste Erwartung ohne Frist-Skalierung; ob das Zählen in `RefreshSnapshots` selbst ein Zeitfenster hat, wurde nicht gelesen. Gleiche Fundstelle wie F-38 (`refreshed` zu niedrig), anderer Test. |
| F-46 `test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted` | seriell 1 von 1 (Runde `[0]`, Lauf 2); Fault 20x: 5 von 20 (`[2]`, `[6]`, `[15]`, `[18]`, `[19]`); im parallelen Lauf 0 von 10 | Vier der fünf Fault-Ausfälle und der serielle Ausfall: `no evt.process.crashed for worker:1` (der Textteil mit dem Supervisor-Log war leer, `chain.sup.text()` leer). Runde `[6]`: der Test erhielt `evt.process.crashed` (0,011 s nach dem Tod, Instanz endete 0,017 s danach), aber das Element meldete `worker not available: worker:1 (peer_gone)` statt `worker crashed (worker:1)` | Teilweise belegt: Die Rundenfolge im Fault-Lauf (fünf Ausfälle in 20 Runden, davon vier gleicher Art) zeigt eine Häufigkeit von rund 25 Prozent in diesem seriellen Szenario; im Abnahmelauf davor trat er in 20 Runden 0-mal auf. Der Unterschied zum vorigen Abnahmelauf ist nicht erklärt. Belegt in `[6]`: die Engine hat den Tod des Workers über `peer_gone` statt über `evt.process.crashed` erfahren, also zwei Meldewege mit unterschiedlicher Reihenfolge (das Element wird mit der Meldung des schnelleren Weges beendet). Für die vier Ausfälle ohne `evt.process.crashed`: Ursache vermutet [nicht geprüft]: der Supervisor hat den Tod von `worker:1` nicht (oder anders, z. B. als Teil des WI-30/31-Pfads für Worker-Pool) gemeldet, oder der Test hat `worker:1` schon beendet vorgefunden; das Supervisor-Log war leer, ein Beleg fehlt. Es sind zwei Fehlerbilder in einem Test. |
| F-47 `test_worker.py::test_cancel_of_the_hang_element_reports_stopped_within_500_ms` | seriell 1 von 1; parallel 0 von 10; in der Fault-Gruppe nicht enthalten | `AhfTimeout: no answer to engine#3 within 5.0 s` bei `cmd.worker.cancel` an `worker:1` (Zeile 204), der Test wartet mit `ROOT_TIMEOUT_S` | Nicht eingeordnet [nicht geprüft]. Belegt: der Worker hat `cmd.worker.cancel` für das Testelement `Action_TestHangWorker` 5 s lang nicht beantwortet, im seriellen Lauf. Gleiche Familie wie der Ausfall des Abnahmelaufs davor (`test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms`, `assert ans["ok"]`, dort in Lauf 4): `cmd.worker.cancel` beim Hänge-Element. Ob es derselbe Fund ist, kann ohne Log nicht gesagt werden; Vermutung: ja, die Abbruchantwort fehlt, wenn der Abbruch das Element im Hänger trifft. |

### Gesamtaussage

**Der Fix-Block ist nicht grün abgeschlossen.** Parallel 9 von 10 Läufen grün (vorher 5 von 10), `-m stress` grün; **seriell (Referenz) rot** (2 Tests) und **Fault 20x rot** (5 Ausfälle des Worker-Kill-Tests). Regel aus dem Auftrag: rot ist rot, auch bei Einzelfällen. Neue Funde: **F-45, F-46, F-47**. Offen bleiben zusätzlich F-43 (Entscheidung des Projektinhabers) und F-42 (nicht eingegriffen). F-37 bis F-41 traten in diesen Läufen nicht mehr auf (F-38 in neuer Form als F-45).

## Schleife WI-35, Zyklus 0 (Ausgangsstand, 2026-10-12)

Reproduktion der Ausgangsfunde, jeder Lauf allein auf dem Rechner, seriell (`-n 0`). Ausgaben im Scratchpad (`z0_*.txt`, `z0n_*.txt`).

| Test | Befehl | Anzahl Läufe | Anzahl rot | Meldungen | Log-Pfad |
|---|---|---|---|---|---|
| F-46 `test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted` | `AHF_FAULT_REPEAT=20 python -m pytest tests/fault/test_process_crash.py -k killed_worker -n 0 -q` | 20 (Lauf 1) + 20 (Wiederholung mit `AHF_TEST_KEEP=1`) | 2 (Lauf 1, Parameter [2], [14]) und 6 (Wiederholung, Parameter [1], [3], [7], [8], [10], [14]) | `AssertionError: no evt.process.crashed for worker:1:` (`tests/fault/test_process_crash.py:37`). Im Log: `worker not available: worker:1 (peer_gone)`, Element-Zustand `exception`. | Wiederholung: `C:\Users\bichl\AppData\Local\Temp\ahf-test-rxcyz_uh\Log\Log.txt`, `...\ahf-test-4ts9iptt\`, `...\ahf-test-i5kukxg7\`, `...\ahf-test-08ntafi6\`, `...\ahf-test-8fh96zr1\`, `...\ahf-test-oz_cm3b_\` (je `Log\Log.txt`). Zuordnung Parameter zu Ordner nicht geprüft. |
| F-47 `test_cancel_of_the_hang_element_reports_stopped_within_500_ms` | `python -m pytest tests/integration/test_worker.py -k cancel_of_the_hang -n 0 -q` (10 Einzelläufe in einer Schleife) | 10 | 0 | Alle 10 grün (je 1 passed, 0,5 bis 0,8 s). Nicht reproduziert. | keiner (kein Fehlschlag) |
| F-45 `test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out` | `AHF_FAULT_REPEAT=10 python -m pytest tests/fault/test_debug_role.py -k refresh_shows -n 0 -q` | 11 (1 Lauf wie vorgegeben + 10 Einzelläufe) | 0 | Alle grün (je 1 passed, rund 4,8 s). Nicht reproduziert. Hinweis: `AHF_FAULT_REPEAT` wirkt in `test_debug_role.py` nicht (der Test nutzt `REPEATS` nicht), die 10 Wiederholungen sind 10 separate Aufrufe. | keiner |

Befund: F-46 ist im seriellen Einzeltest reproduzierbar (8 rot von 40 Läufen), im Log bestätigt: der Hub beantwortet die offene Anfrage an `worker:1` mit `peer_gone`, `evt.process.crashed` kommt in der Log-Datei nicht vor, das Element endet mit `worker not available: worker:1 (peer_gone)`. F-45 und F-47 traten in dieser Zyklus-0-Reproduktion nicht auf (0 von 21 bzw. 0 von 10 Läufen).

Prozesskontrolle nach den Läufen: keine Testprozesse übrig. Fremd (nicht angefasst): `AutoHotkeyU32.exe` mit "Allgemeine Hilfe.ahk", `python.exe` der VS-Code-Erweiterung (isort, `lsp_server.py`).

## Abnahmelauf WI-35, Zyklus 1 (2026-10-12)

Schritt 4 der Schleife (WI-35), Code-Stand `2f2e6e5`, keine Änderung an Code, Tests oder Fristen. Jeder Lauf allein, nacheinander, Ausgaben im Scratchpad (`a1_*.txt`). Details und Tabelle: `work_items/phase2b/WI-35-bugfix-schleife.md`, Abschnitt "Testdurchführung Zyklus 1".

| Lauf | Befehl | Ergebnis | Dauer |
|---|---|---|---|
| 1 bis 10 | `python -m pytest tests -q` | je 752 passed, 1 skipped | 137 bis 164 s |
| seriell | `python -m pytest tests -n 0 -q` | 752 passed, 1 skipped, 15 deselected | 728 s |
| Fault 20x | `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` | 505 passed | 2690 s |
| Stress | `python -m pytest tests -m stress -q` | 14 passed, 754 deselected | 200 s |

**Abnahme grün: ja.** Keine roten Tests in allen Läufen. F-46 trat nicht auf (Umsetzung Zyklus 1: 40 von 40 grün im Einzeltest). F-45 und F-47 traten nicht auf. Keine neuen Funde. Keine Testprozesse übrig; fremd und unangetastet: `AutoHotkeyU32.exe` mit "Allgemeine Hilfe.ahk".

Offen: Die gezielte Wiederholung aus Schritt 3 für F-45 und F-47 ist nicht dokumentiert (nur F-46 in der Umsetzung). Schritt 5 (Abschluss: F-46 schließen, Haken in `phase2b/README.md`) ist nicht erfolgt; er ist Sache des Projektinhabers bzw. der Abschlussrunde.
