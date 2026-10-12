# WI-32 Teststabilität und Abschluss des Fix-Blocks

Größe: M · Hängt ab von: WI-30, WI-31, WI-33 · Blockiert: Phase-3-Plan

## Ziel

Der parallele Standardlauf (`python -m pytest tests -q`, rund 2 Minuten) ist ein **verlässliches** Signal: rot heißt Fehler im Produkt oder im Test, nie Zufall. Heute ist er "meist grün", der serielle Lauf dauert rund 10 Minuten. In Phase 3 kommen viele Tests hinzu; ein wackelnder Lauf kostet dann jeden Agenten Zeit und verdeckt echte Fehler.

## Bekannte wackelnde Tests

| Test | Ursache | Quelle |
|---|---|---|
| `tests/integration/test_storage.py::test_engine_starts_with_the_real_storage_and_its_log_arrives` | Der Beobachter abonniert erst nach dem `sys.hello` der Engine und wartet auf `evt.engine.ready`. Ist die Engine schneller, ist das Ereignis schon weg (PROTOKOLL 5a), Fehlschlag nach 15 s. [gelesen] In den Fault-Tests wurde dasselbe Muster in WI-28 behoben (`Chain.wait_flows`, Zustand per Snapshot) | Review-Lauf 2026-10-12, parallel |
| `tests/ahk/storage_queue.test.ahk` "a budget runs many small operations in one go" | Unit-Test misst echte Zeit (Zeitbudget 10 ms); unter Last 159 statt 300 Operationen | Review-Lauf 2026-10-12, parallel |
| Fault- und Supervisor-Tests mit engen Zeitgrenzen (F-19), z. B. `test_role.py::test_shutdown_sends_bye_and_exits_0_within_one_second` (1,158 s bei Grenze 1,0 s) | Zeitbudget unter paralleler Last zu eng | WI-26, WI-22 |
| `clients_churn[smoke]`, `big_flows[smoke]` | zeitempfindlich unter Last | STATUS "Im Port offen" |
| `test_shutdown.py` `clean: false` (F-26) und `test_debug_role.py` Flows nicht geladen (F-31) | sollten nach WI-30 und WI-31 verschwunden sein | STATUS |

## Aufgaben

1. **Muster im ganzen Testbestand suchen und beheben** (nicht nur die Tabelle):
   - Warten auf ein Ereignis, das vor dem Abonnement gekommen sein kann → auf einen Zustand warten (Snapshot, `cmd.process.list`), wie in `Chain.wait_flows`.
   - Echte Zeit in Unit-Tests → Zeitquelle injizierbar machen (z. B. `WriteQueue` mit austauschbarer Uhr) oder die Aussage zeitunabhängig formulieren.
   - Absolute Zeitgrenzen im Standardlauf → Entweder die Aussage ohne enge Grenze prüfen (Reihenfolge, Ergebnis) und die strenge Zeitmessung in eine seriell laufende Gruppe (`xdist_group`, siehe WI-18) bzw. nach `-m stress` verschieben, oder die Grenze mit Begründung anpassen. Nie stillschweigend lockern; jede Änderung im Commit begründen.
2. **Abnahmeläufe**, jeder allein auf dem Rechner, Ergebnisse in `STATUS.md`:
   - 10 parallele Gesamtläufe hintereinander, alle grün. Jeder rote Test wird analysiert und behoben, oder als Fund mit Begründung festgehalten (dann zählt der Lauf nicht).
   - 1 serieller Gesamtlauf grün.
   - `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` grün.
   - `python -m pytest tests -m stress -q` grün.
3. **Abschluss des Fix-Blocks (Dokumente):**
   - `work_items/STATUS.md`: Entscheidungen E9 bis E15 (aus `README.md`, Nachtrag), Funde F-24, F-26, F-31, F-16 mit Ergebnis, neue Funde ab F-32. Beobachtungsliste ergänzen: leeres `--data=` schreibt nach `C:\Log` (E15), Fristen der Rollen nach Standby (WI-33), F-19 falls Reste bleiben.
   - `doc/MIGRATION.md`: Status von M-11, M-17, M-18 auf "bestätigt" (E13); E9 (Löschen ohne Frist) dort oder in `ARCHITEKTUR.md` 4.2 als bestätigt vermerken.
   - `work_items/HANDOVER.md` und `AGENTS.md` (aktueller Stand: Fix-Block abgeschlossen, als Nächstes der Phase-3-Plan mit dem Projektinhaber), offene Entscheidungen aktualisieren (beantwortet sind 1 bis 5 aus dem bisherigen HANDOVER; neu offen: E14 Manager schließen für Phase 3).
   - Fortschrittshaken in `README.md` (Fix-Block).
   - `.vscode/tasks.json` nach Regel 10 in `AGENTS.md` prüfen: Jede neue Option oder jedes neue Werkzeug aus WI-30 bis WI-33, das von Hand nützlich ist, hat einen Task.

## Akzeptanzkriterien

- 10 von 10 parallelen Gesamtläufen grün, serieller Lauf, Fault-Wiederholung und Stress grün.
- Keine Zeitgrenze wurde ohne Begründung gelockert.
- Dokumente wie oben, ein neuer Agent findet über `AGENTS.md` den Stand.

## Nicht Teil

Phase-3-Plan (WI-17 Schritte 6 und 7): den entwirft der Projektinhaber danach mit Claude.

## Ergebnis

Status: **Aufgabe 1 (Testbereinigung) und Aufgabe 3 (Dokumente) abgeschlossen, Aufgabe 2 (Abnahmeläufe) nicht ausgeführt** (Aufteilung auf Anweisung des Orchestrators: sie fährt ein späterer, eigener Agent). Keine Eskalation. Kennzeichnung: **verifiziert** = gelaufen oder gelesen, **vermutet**, **nicht geprüft**. Stand 2026-10-12.

Commits: `8d0e65a` (AHK-Unit-Test der Schreibwarteschlange ohne echte Zeit), `056a1d5` (Storage-Tests: Abonnement vor dem Start, Rate nach `-m stress`), `c454658` (`support.timing.scaled()`, obere Zeitgrenzen), `ef90ede` (MIGRATION M-11, M-17, M-18 und ARCHITEKTUR 4.2 bestätigt), `bb39719` (STATUS), `9ecdbb5` (HANDOVER, AGENTS), dazu der Abschluss-Commit (diese Datei, Haken in `README.md`).

### Die Tests aus der Tabelle

| Test | Was geschah |
|---|---|
| `test_storage.py::test_engine_starts_with_the_real_storage_and_its_log_arrives` | **behoben** (`056a1d5`). Der Beobachter abonniert jetzt vor dem Start der Engine, nicht erst nach deren `sys.hello`. Test grün (einzeln und im Teil-Lauf). Dass der Fehlschlag vor der Änderung mit dieser Ursache auftrat, ist [gelesen, nicht erneut rot nachgestellt]: das Ereignis kann vor dem Abonnement kommen (PROTOKOLL 5a) |
| `tests/ahk/storage_queue.test.ahk` "a budget runs many small operations in one go" | **behoben** (`8d0e65a`). Die Ursache ist [gelesen, nicht rot nachgestellt] eine andere als in der Tabelle: das Budget des Falls war schon 1000 ms; `Add`/`AddLow` stellen den eigenen Timer der Warteschlange, und nach einem Stillstand des Test-Threads läuft dieser Timer mitten im Fall und arbeitet Operationen ab (159 statt 300). Jetzt: `Critical("On")` für die ganze Datei, und `WriteQueue(clock)` nimmt eine Uhr entgegen (nur Tests übergeben eine): Budget-, Einzeloperations- und Retry-Fälle laufen auf einer Uhr, die nur steigt, wenn eine Operation Zeit braucht. Die Aussagen sind schärfer als vorher (genau 4 Operationen bei 5 ms je Operation und 20 ms Budget). 14 von 14 Fällen grün. Keine Frist des Produkts geändert |
| `test_role.py::test_shutdown_sends_bye_and_exits_0_within_one_second` und die Fault-/Supervisor-Tests mit engen Grenzen (F-19) | **gelockert mit Begründung** (`c454658`): obere Grenzen, die ein Produktversprechen prüfen, laufen über `scaled()`: seriell unverändert (das Versprechen, Referenz), parallel Faktor 3. Begründung: mehrere AutoHotkey-Prozesse je Test auf einer gemeinsamen Maschine, 1,158 s gegen 1,0 s war ein Test-, kein Produktfehler. Genaue Liste unten. Untere Grenzen, Anzahlen und Ergebnisse unverändert, die Reihenfolge der Assertions in `test_shutdown.py` (`clean` zuerst) unverändert |
| `clients_churn[smoke]`, `big_flows[smoke]` | **gelockert mit Begründung** (`c454658`): nur die Latenzgrenzen (Median 5 ms, p99 50 ms, Snapshot unter Last 1 s) über `scaled()`; Zählungen, Handles, Neustarts, Fehler unverändert. Beide Smoke-Tests im Teil-Lauf grün. Die vollen Messungen laufen weiter nur mit `-m stress` (ein Prozess, Faktor 1) |
| `test_shutdown.py` `clean: false` (F-26), `test_debug_role.py` Flows nicht geladen (F-31) | **unverändert**. Beide sollten nach WI-30/WI-31 weg sein. In meinen Teil-Läufen ist `clean: false` nicht aufgetreten (`test_shutdown.py` mehrfach gefahren); `test_debug_role.py` habe ich nicht gefahren. Das zählt nicht als Abnahme; F-31 bleibt bis zur Abnahme offen |
| F-32 `test_a_log_flood_is_written_at_more_than_1000_lines_per_second` | **behoben** (`056a1d5`): Die strenge Rate (mehr als 1000 Zeilen/s, unverändert) ist ein eigener Test mit `@pytest.mark.stress` (gemessen 3137 Zeilen/s). Der Standardlauf prüft zeitunabhängiger: die ganze Flut von 12000 Zeilen steht binnen 60 s in beiden Dateien (mindestens 200 Zeilen/s, sechsfache Reserve zum alten Wert von 30 Zeilen/s) und der Speicher bleibt unter 120 MB. Das ist im Standardlauf eine bewusst lockerere Aussage |

### Muster aus Aufgabe 1 und Fundstellen

1. **Warten auf ein Ereignis, das vor dem Abonnement gekommen sein kann.** Alle Stellen mit `evt.engine.ready` geprüft [gelesen]: `test_engine.py` (Beobachter vor `start_engine`), `tests/e2e/test_ui_stub.py` (Abonnement vor dem Kind), `faultkit.Chain` (abonniert im Konstruktor, bevor Kinder bereit sind; `test_worker_lifecycle.py:34`, `test_process_crash.py:118` und `test_big_flows.py` nutzen `chain.rec` und sind damit nur theoretisch gefährdet, `Chain.wait_flows` bleibt die robuste Form). **`test_storage.py` war die einzige echte Stelle** und ist behoben. Die `debug`-Themen in `test_debug_dump.py` abonnieren vor dem Senden.
2. **Echte Zeit in Unit-Tests.** `tests/ahk/storage_queue.test.ahk` behoben. Weitere AHK-Tests mit `Sleep` und Timern (`diag_report`, `element_runner`, `element_sleep`, `engine_worker_bridge`) sind **nicht geändert**: Ihre Ränder sind mindestens 500 ms breit [gelesen, z. B. `CheckAStandStillMovesTheWaitForStorage` 600 ms gegen 900/1000 ms]; ein Ausfall wurde dort nie beobachtet. Vermutet unkritisch, nicht unter Last geprüft.
3. **Absolute Zeitgrenzen im Standardlauf.** `scaled()` in `tests/support/timing.py`, Regel in `doc/TESTSTRATEGIE.md`. Angewendet auf: `faultkit.py` (`CRASH_BUDGET_S`, `CLEAN_EXIT_BUDGET_S`, `REQUEST_BUDGET_S`, Schlupf von `ORPHAN_BUDGET_S`), `test_shutdown.py` (`FROZEN_EXIT_SLACK_S`, `EVENT_LAG_S`), `test_role.py` (`SHUTDOWN_LIMIT_S`, `ORPHAN_SLACK_S`), `test_supervisor.py` (`START_BUDGET_S`, `CRASH_BUDGET_S`, `CLEAN_EXIT_BUDGET_S`, `FROZEN_EXIT_SLACK_S`), `test_worker.py` (`CANCEL_BUDGET_S`, `PING_BUDGET_S`), `test_worker_pool.py` (`KILL_BUDGET_S`), `test_storage.py` (`PING_LIMIT_S`, Anfrage-Latenz in der Flut), `test_engine.py` (Stopp 0,5 s, Beenden 2 s), `tests/e2e/test_ui_stub.py` (2 s), `test_pipe.py` (500 ms, 2000 ms, 1500 ms; untere Grenzen 290/380 ms unverändert), `test_peer.py` (Timer 300 ms mit 250 als untere und 300 + 50 als obere Grenze, bisher 300 +- 50; 10-s-Frist 9,5 bis 12,5; 2000 ms), `tests/stress/test_clients_churn.py` und `test_big_flows.py`. **Nicht angefasst, weil schon großzügig oder ohne Last-Abhängigkeit:** `HANG_BUDGET_S` (8 s), `READY_S` (20 s), `ENGINE_GONE_BUDGET_S` (1,5 s, enthält schon Reserve), `FROZEN_BUDGET_S` (8 s), `test_timeouts.py` (relativ zu den eigenen Fristen), Stress-/Soak-Tests mit `-m stress` (laufen immer in einem Prozess, Faktor 1).

### Gelaufene Testdateien (alle auf dem Stand der Commits oben)

- Gelaufen (parallel, `-n auto`): `tests/test_ahk_runner.py -k storage_queue`; `tests/integration/test_storage.py` (die zwei geänderten Tests, dazu der Stress-Test einzeln mit `-m stress -n 0`); `tests/stress/test_clients_churn.py` und `test_big_flows.py` (Smoke); der Satz `tests/e2e/test_ui_stub.py`, `tests/fault/test_shutdown.py`, `tests/integration/test_engine.py`, `test_peer.py`, `test_pipe.py`, `test_role.py`, `test_storage.py`, `test_supervisor.py`, `test_worker.py`, `test_worker_pool.py`, `tests/fault/test_process_crash.py`, `test_timeouts.py`, `test_orphans.py`, `test_pipe_break.py`. Dieser Satz (die Dateien, deren Zeitgrenzen ich geändert habe, plus Nachbarn) lief vier Mal; **Endstand: 171 passed in 38 s**. Die drei früheren Läufe zeigten Rot, siehe unten (F-36). `python tools/arch_check.py`: 0 Verstöße. `pytest --collect-only`: 734 Tests gesammelt.
- **Nicht gelaufen** (und warum): der Rest von `tests/fault/` (u. a. `test_debug_role.py`, `test_report.py`, `test_snapshot.py`, `test_worker_lifecycle.py`, `test_supervisor_stall.py`): nicht geändert; `tests/ahk/*` außer `storage_queue`: nicht geändert; `tests/stress` (außer den zwei Smoke-Varianten) und `-m soak`: nicht geändert und Aufgabe des Abnahmelaufs; `tests/test_json_flows.py`, `tests/test_architecture.py` (nur der Wächter selbst direkt gefahren). Keine Gesamtläufe (Auftrag).

### Was in den Läufen auffiel (F-36, nicht aufgeklärt)

Die ersten drei Läufe des 14-Dateien-Satzes (und zwei Läufe `test_shutdown.py` + `test_ui_stub.py`) hatten in `test_shutdown.py` zwei bis drei rote Tests: `AhfTimeout: no answer to obs#1` in `faultkit.connect`, also der Supervisor hatte die Pipe, beantwortete aber 15 s lang kein `sys.hello`. Dasselbe trat mit dem Stand **vor** meinen Änderungen auf (`git stash`), es liegt also nicht an ihnen [verifiziert]. In diesen Läufen war die Maschine langsam (9 Tests in 22 bis 35 s statt 6 s); danach nicht mehr reproduzierbar (3 Läufe grün, der 14-Dateien-Satz grün in 38 s, auch mit 8 CPU-Brennern daneben). Datenordner des roten Tests: Log und `sup.stderr` leer. Als Fund F-36 in `STATUS.md` mit Hinweisen für das Wiederauftreten. Ob das ein Produktfehler (Hub antwortet nicht) oder ein Maschinenzustand ist, ist **nicht entschieden**; es ist die Hub-Frage aus WI-23. Im selben Zustand lief einmal `test_pipe.py::test_abrupt_end_of_client_process_is_seen_within_500_ms[1]` mit 1923 ms über die parallele Grenze von 1500 ms.

### Dokumente (Aufgabe 3)

- `work_items/STATUS.md`: Entscheidungen E9 bis E15 (eigene Tabelle), Beobachtungsliste (leeres `--data=` / `C:\Log`, Zeitgrenzen und Hub-Frage; die Fristen der Rollen nach Standby standen schon seit WI-33 darin), Funde F-16, F-19, F-24, F-26, F-31, F-32, F-33 mit Ergebnis, neu F-36 (F-34 wurde nie vergeben), Paketübersicht, Nächste Schritte.
- `doc/MIGRATION.md`: M-11, M-17, M-18 "bestätigt" (E13; M-17/M-18 standen noch als "geplant"). `doc/ARCHITEKTUR.md` 4.2: Löschen ohne Frist als bestätigt (E9).
- `work_items/HANDOVER.md`, `AGENTS.md`: Stand, beantwortete und neu offene Entscheidungen (E14, Freigabe Phase 3), Commits der Pakete.
- `doc/TESTSTRATEGIE.md`: Regeln zu Zeitgrenzen, Warten auf Zustände, Uhr in Unit-Tests.
- `work_items/phase2b/README.md`: Haken WI-32 (Aufgabe 1 und 3) gesetzt, der Haken für die Abnahme ist eine eigene, offene Zeile.
- Das Wurzel-`README.md` enthält keinen Fortschrittshaken zum Fix-Block (nur der Haken in `work_items/phase2b/README.md` existiert).
- `.vscode/tasks.json`: **keine Änderung nötig** [gelesen]. WI-30 bis WI-33 haben keine neuen Optionen, Rollen oder Werkzeuge eingeführt (`git diff 214cdde HEAD -- src tools` zeigt nur Änderungen in vorhandenen Dateien, keine neue Kommandozeilenoption). Alle von Hand nützlichen Aufrufe haben schon einen Task, auch die Stress-Gruppe, in die der strenge Log-Raten-Test jetzt gehört (`Test: Stress, seriell, Messung (-m stress)`). `AHF_TIMING_FACTOR` ist eine optionale Umgebungsvariable für Agenten, kein Handaufruf.

### Offen für den Abnahmelauf (Aufgabe 2, späterer Agent)

Jeder Lauf allein auf dem Rechner, nichts anderes parallel, Ausgaben in Dateien im Scratchpad, im Hintergrund starten. Danach: keine Testprozesse übrig (nur ansehen). Ergebnisse in `STATUS.md` ("Letzter Gesamtlauf"), Haken in `phase2b/README.md` setzen.

1. 10 parallele Gesamtläufe hintereinander, alle grün: `python -m pytest tests -q` (zehn Mal; jeder rund 1 bis 2 Minuten). Jeder rote Test wird analysiert (bei `sys.hello`-Timeouts: F-36, `AHF_TEST_KEEP=1`, Prozesse der Sitzung ansehen) und behoben oder als Fund festgehalten; dann zählt der Lauf nicht. Zusätzlich einmal streng, um die Wirkung von `scaled()` zu sehen: `AHF_TIMING_FACTOR=1 python -m pytest tests -q` (Ergebnis nur berichten, kein Kriterium).
2. Serieller Gesamtlauf: `python -m pytest tests -n 0 -q` (rund 10 Minuten; hier gilt Faktor 1, also die ungelockerten Grenzen). F-31 beobachten (`test_debug_role.py`).
3. `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` (rund 42 Minuten).
4. `python -m pytest tests -m stress -q` (rund 3,5 Minuten; enthält jetzt auch `test_a_log_flood_is_written_at_more_than_1000_lines_per_second`).

### Offene Punkte

- Aufgabe 2 (oben) und damit die Schließung von F-31; die Entscheidung zu F-36.
- F-35 (Drain-Frist in `src/core/ipc/`) bleibt offen; keine Frist des Produkts wurde in WI-32 verändert (einzige `src/`-Änderung: `WriteQueue` nimmt eine optionale Uhr, Standardverhalten unverändert).
- Die AHK-Tests mit `Sleep` (Muster 2) sind ungeprüft unter Last.
- Faktor 3 von `scaled()` ist eine Schätzung, kein gemessener Wert; er sollte nach dem Abnahmelauf (10 parallele Läufe) bestätigt oder angepasst werden.
- Grobe Dauer dieser Arbeit: rund zwei Stunden; die Zeit ging überwiegend in die Suche nach dem Muster der Zeitgrenzen, die Teil-Läufe (je 40 bis 90 s) und die Untersuchung von F-36.
