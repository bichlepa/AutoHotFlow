# WI-18 Testlaufzeit: parallele Ausführung

Größe: S · Hängt ab von: – · Blockiert: alle weiteren (spart Zeit)

## Ziel

Der Standardlauf `python -m pytest tests -q` dauert 346 s (2026-10-11, 431 Tests, seriell) und wächst mit jedem Paket. Ziel: deutlich kürzer durch parallele Ausführung, **ohne** neue sporadische Fehler.

## Hintergrund

- Die Tests sind für Parallelität vorbereitet (`doc/TESTSTRATEGIE.md` 1.4): `session_id` ist eine UUID (`tests/conftest.py`), jedes Datenverzeichnis ist eigen (`datadir`), Pipe-Namen enthalten die Sitzung.
- Risiken, die zu prüfen sind:
  - Zeitkritische Tests: Fault-Tests (Fristen 1 bis 8 s), Latenz- und Idle-CPU-Messungen, Speicherprüfungen (`num_handles`, RSS). Unter paralleler Last können Fristen reißen oder Messwerte verfälscht werden.
  - Gemeinsame Ressourcen: Dialog-Wächter schreibt nach `%TEMP%\ahf_dialogs\`, mögliche feste Namen (Suche nach `main`, festen Pipe- oder Mutex-Namen, festen Dateien in `%TEMP%`), Tests, die "alle AutoHotkey-Prozesse" zählen.
  - Prozessaufräumen (`procs`-Fixture) muss pro Worker-Prozess von pytest funktionieren.
- Es laufen fremde AutoHotkey-Prozesse des Projektinhabers. Nie nach Namen beenden (siehe `work_items/HANDOVER.md`).

## Aufgaben

1. Ausgangsmessung: `python -m pytest tests -q --durations=40` (Ausgabe in eine Datei, im Hintergrund). Die 40 langsamsten Tests notieren.
2. `pytest-xdist` in `tests/requirements.txt` aufnehmen und installieren.
3. Gemeinsame Ressourcen prüfen (Liste oben) und beheben, wo nötig (eindeutige Namen je Test, keine globalen Zählungen von Prozessen).
4. Zeitkritische Tests markieren und gruppieren, sodass sie nicht parallel zu Last laufen. Vorschlag: Marker `serial` plus `xdist_group` und `--dist loadgroup`, oder eine eigene Gruppe, die am Ende allein läuft. Messungen (`test_measurements.py`, Idle-CPU) dürfen nie parallel laufen. Stress und Soak bleiben wie bisher nur mit `-m`.
5. Die 10 langsamsten Tests ansehen: Wo ein festes Warten (`time.sleep`) durch Warten auf ein Ereignis mit Frist ersetzt werden kann, ersetzen. Fristen in Assertions nicht stillschweigend lockern; jede Änderung einer Frist im Commit begründen.
6. Den Aufruf festlegen (z. B. `python -m pytest tests -q -n auto --dist loadgroup`) und dokumentieren: `AGENTS.md` (Werkzeuge), `doc/TESTSTRATEGIE.md` Abschnitt 6, `work_items/HANDOVER.md`. Ob `-n` per `addopts` Standard wird, entscheidet das Paket (begründen; ein serieller Lauf muss weiter möglich sein, z. B. `-n 0`).
7. Stabilität: 5 parallele Gesamtläufe hintereinander, alle grün. Danach ein serieller Gesamtlauf grün. Nach jedem Lauf prüfen, dass keine von den Tests gestarteten AutoHotkey-Prozesse übrig sind (nur ansehen, `Get-CimInstance Win32_Process`).

## Akzeptanzkriterien

- Paralleler Standardlauf höchstens 40 % der seriellen Dauer auf diesem Rechner (Ziel unter 140 s), Zahl der Tests unverändert.
- 5 von 5 parallelen Läufen grün, 1 serieller Lauf grün.
- Keine übrig gebliebenen Testprozesse.
- Dokumentation angepasst.

## Nicht Teil

Neue Testfälle. Umbau der Stresstests.

## Hinweise

- `doc/HOW-TO.md` enthält Einträge zu Testprozessen, Ausgaben in Dateien und dem Dialog-Wächter. Neue Erkenntnisse zu xdist dort ergänzen.
- Die Anzahl der logischen CPUs ist 8. Mehr als 8 Worker bringen bei AHK-Prozessen wahrscheinlich nichts.

## Ergebnis

Status: abgeschlossen (2026-10-11). Kennzeichnung: **verifiziert** = gemessen oder getestet, **vermutet**, **nicht geprüft**.

### Erledigt

- `pytest-xdist>=3.5` in `tests/requirements.txt` (installiert: 3.8.0).
- Neue `pytest.ini` im Repo-Wurzelverzeichnis: `addopts = -n auto --dist loadgroup`. `-n auto` ergibt auf diesem Rechner 8 Worker (8 logische CPUs). Begründung für den Standard: Der Standardlauf ist der Aufruf aller Agenten; ohne `addopts` würde die Parallelität vergessen. Seriell bleibt möglich mit `-n 0` (nötig für `-s`/`--pdb` bei Einzeltests).
- `tests/conftest.py`: `pytest_cmdline_main` (`tryfirst`) schaltet Läufe mit `-m stress` / `-m soak` auf einen Prozess (`numprocesses = 0`), damit Messungen (Idle-CPU, Latenz, Speicher) nie parallel zu anderer Last laufen. Verifiziert: `-m stress` auf `tests/stress/test_log_backlog.py` lief ohne Worker (`[gw..]`).
- Gemeinsame Ressourcen geprüft (Aufgabe 3), zwei echte Funde behoben:
  1. **Gleiches AHK-Testskript gleichzeitig gestartet.** Erster Lauf mit `-n 8`: 21 Fehler in `tests/test_ahk_runner.py` ("case not reported ... exit=15"). Die Dialogberichte in `%TEMP%\ahf_dialogs\` zeigten "An older instance of this script is already running", der Dialog-Wächter beendete die Prozesse (Exit 15). Behoben mit `#SingleInstance Off` in `tests/ahk/lib/Assert.ahk`, `tests/ahk/helpers/json_bench.ahk`, `tests/ahk/helpers/json_flows.ahk` (die anderen Einstiegsskripte hatten es schon). Verifiziert: danach `-n 8` grün.
  2. **Dialog-Wächter mit veralteten Wurzel-PIDs.** Im zweiten Gesamtlauf scheiterten `test_dialogwatch.py::test_runtime_error_dialog_is_captured` und `::test_msgbox_is_captured_and_closed` (Exit 0 statt 97). Vermutete Ursache: Die Wurzel-PIDs blieben im Wächter für immer registriert, Windows vergibt PIDs schnell neu, der Wächter eines anderen Workers schloss den Dialog eines fremden Testprozesses. Behoben in `tools/ahf_dialogwatch.py`: zur PID wird die Erstellungszeit gemerkt, tote oder wiederverwendete Wurzeln werden ausgetragen. Außerdem enthalten die Dateinamen der Dialogberichte jetzt die PID des Testprozesses (`_w<pid>_`).
- Weitere geprüfte Punkte ohne Befund (gelesen): Pipe-Namen und Datenverzeichnisse enthalten die Sitzungs-ID bzw. sind `mkdtemp`; Prozesszählungen laufen über die Sitzungs-ID in der Befehlszeile (`faultkit.session_processes`) oder eine eindeutige Markierung (`test_hung_script_is_killed_at_timeout`); der Mutex-Name des Supervisors enthält die Sitzung; `AHF_MEASURE_OUT` schreibt kurze Zeilen im Anhängemodus (nur auf Wunsch). Die `procs`-Fixture räumt je Worker auf (verifiziert durch die Prozesszählung nach den Läufen).
- **Supervisor-Reihenfolge (Abweichung, siehe unten):** `Supervisor._Tick` liest zuerst die Pipes (`hub.Pump()`), dann erst `children.Tick`.
- Dokumentation: `AGENTS.md` (Werkzeuge), `doc/TESTSTRATEGIE.md` Abschnitt 6, `work_items/HANDOVER.md`, drei Einträge in `doc/HOW-TO.md`.

### Belege (Messwerte)

| Lauf | Ergebnis | Dauer |
|---|---|---|
| Ausgangsmessung seriell (`--durations=40`) | 431 passed, 1 skipped, 11 deselected | 337 s |
| Paralleler Probelauf mit `-n 8` (ohne `#SingleInstance Off`) | 21 failed, 411 passed | 50 s |
| Paralleler Lauf nach `#SingleInstance Off` | 431 passed, 1 skipped | 49 s |
| Runde 1: 5 parallele Gesamtläufe (vor Wächter- und Supervisor-Korrektur) | 2 failed / grün / 1 failed / grün / grün | 48 bis 55 s |
| Endstand: 5 parallele Gesamtläufe | je 431 passed, 1 skipped | 47,4 / 49,9 / 48,7 / 46,4 / 48,2 s |
| Endstand: 1 serieller Gesamtlauf (`-n 0`) | 431 passed, 1 skipped, 11 deselected | 333 s |

- Paralleler Lauf: rund 48 s gegen 337 s seriell, also rund 14 % (Kriterium: höchstens 40 %, Ziel unter 140 s: erfüllt). Zahl der Tests unverändert (431 passed + 1 skipped; seriell zusätzlich 11 deselected, xdist zeigt die abgewählten nicht an).
- Prozesse: Vor den Läufen 1 fremder AutoHotkey-Prozess (des Projektinhabers). Nach jedem der 5 parallelen und nach dem seriellen Lauf des Endstands: 0 übrig gebliebene Testprozesse (Filter auf `ahf-test-`, `--session=t`, `ahkrun`, `.test.ahk`), Gesamtzahl der AutoHotkey-Prozesse wieder 1 (der fremde). Es wurde nichts nach Namen beendet.
- Die langsamsten Tests der Ausgangsmessung (seriell, Sekunden): `test_storage::test_no_log_line_is_lost_while_other_processes_hold_the_files` (2 Parameter, je 16,8), `test_storage_abort::test_killed_storage_mid_write...[0]` 11,1, `test_process_hang::test_frozen_ui_stub_is_hung...` 11,0, `test_process_hang::test_frozen_engine...` 10,6, `test_peer::test_hub_gone_for_longer_than_the_budget_calls_onclosed` 10,3, `test_process_hang::test_frozen_storage...` 9,9, `test_timeouts::test_request_to_a_frozen_engine...` 9,7, `test_supervisor::test_frozen_child_is_hung_within_8s...` 9,3, `test_pipe_break::test_clients_that_close_abruptly...` 9,0, `test_peer::test_10000_sequential_requests...` 8,1, danach `test_supervisor::test_crashed_child...` 7,3, `test_clients_churn[smoke]` 5,5, `test_orphans` 5,2, `test_worker::test_frozen_worker_does_not_answer...` 5,2, `test_start_stop_storm[smoke]` (Aufruf 4,6, Teardown 5,0) und 25 weitere unter 4,3 s (vollständige Liste nur in der Ausgabe des Laufs, nicht im Repo).

### Nicht geändert, mit Begründung

- **Marker `serial` / `xdist_group`:** Nicht eingeführt. Messungen laufen nur mit `-m stress|soak` und damit automatisch einzeln. Die zeitkritischen Tests im Standardlauf (Fault-Fristen 1 bis 8 s, `num_handles`-Prüfungen) liefen in den 6 Gesamtläufen des Endstands grün unter voller Parallellast. Eine Gruppe bringt ohne echte Isolation nichts (xdist hält andere Worker nicht an). Fristen wurden nicht verändert.
- **Feste Wartezeiten (Aufgabe 5):** Keine `time.sleep` ersetzt, keine Frist gelockert. Die langsamsten Tests warten auf Fristen des Systems selbst (Hang-Erkennung nach 3 verpassten Pings, Orphan-Frist, Retry-Fenster des Storage); das ist die geprüfte Eigenschaft, kein Warten, das sich durch ein Ereignis ersetzen ließe. Im parallelen Lauf bestimmt der längste Einzeltest (rund 17 s) plus Startkosten die Untergrenze der Dauer.

### Abweichungen vom Plan

- **Änderung in `src/supervisor/Supervisor.ahk` (kein Testcode):** Runde 1 der Stabilitätsläufe (vor der Änderung) hatte 3 Ausfälle in 2 von 5 parallelen Läufen: 2 x `test_dialogwatch` (Fund 2 oben) und 1 x `test_shutdown::test_frozen_storage_is_terminated_at_the_deadline_and_the_others_exit_clean[0]` (Manager `clean` falsch, Gesamtdauer 2,28 s; die Engine war sauber). Der Ausfall ist nicht nachgestellt: 24 Wiederholungen mit `-n 4` und zusätzlich 12 Rechenlast-Prozessen blieben grün. Aus dem Code gelesen: `Supervisor._Tick` rief `children.Tick` auf, ohne vorher die Pipes zu lesen; eine Rolle sendet `sys.bye` und beendet sich, der Supervisor kann das Prozessende sehen, bevor er das `sys.bye` gelesen hat (dann ist `clean` falsch). Die Korrektur ist ein `hub.Pump()` am Anfang des Ticks. Dass dies die Ursache des beobachteten Ausfalls war, ist **vermutet**; danach liefen 5 parallele und 1 serieller Lauf grün (statistisch schwach, da der Ausfall vorher nur 1 von 6 Läufen traf). Das Paket nennt `src/supervisor/` nicht; die Änderung ist klein und gehört thematisch zu WI-22 (Supervisor-Robustheit), WI-22 sollte sie prüfen.
- Die Ausgangsmessung war seriell, der Endstand ist parallel (wie im Auftrag).

### Offene Punkte

- **F-11 (neu):** `sys.bye` und Prozessende im Supervisor: Die Reihenfolge war nicht gesichert (siehe oben). Die Korrektur ist im Code (`hub.Pump()` vor `children.Tick`), ein deterministischer Test fehlt (Rolle, die `sys.bye` sendet und sofort endet, Tick dazwischen). WI-22 bzw. WI-29 übernimmt.
- Der Ausfall von `test_shutdown` unter paralleler Last bleibt **nicht abschließend geklärt** (Ursache vermutet). Sollte er wieder auftreten: Lauf mit `AHF_TEST_KEEP=1`, Supervisor-Log des Tests ansehen.
- Dialog-Wächter: Dass der Ausfall in `test_dialogwatch` durch wiederverwendete PIDs entstand, ist nicht einzeln nachgestellt (vermutet); die Lücke selbst ist im Code geschlossen.
- Nicht geprüft: Laufzeit auf anderen Rechnern (`-n auto` richtet sich nach den logischen CPUs; mehr als 8 Worker wurden nicht ausprobiert); Stress- und Soak-Läufe wurden nur mit einer Datei (`test_log_backlog.py`, 235 s) auf die Einzelprozess-Umschaltung geprüft, nicht vollständig.
