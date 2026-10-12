# WI-33 Worker enden mit der Engine (E10), Fristen nach Stillstand (F-16, E12)

Größe: S · Hängt ab von: WI-30 (gleiche Dateien im Supervisor) · Blockiert: WI-32

## 1. Worker enden mit der Engine (E10)

**Heute [gelesen, WI-27]:** Endet die Engine, bleiben ihre Worker leben, bis eine neue Engine sie beim Start (`WorkerBridge.Start`, `cmd.process.list`) beenden lässt. Bleibt die Engine dauerhaft weg (Neustartgrenze erreicht), bleiben Worker mit offenen Dialogen bis zum Ende der Sitzung stehen; ihr Ergebnis nimmt niemand mehr an.

**Entscheidung E10:** Endet der Engine-Prozess (unerwartet oder geplant, außerhalb des Beendens der Sitzung), beendet der Supervisor sofort alle lebenden `worker:*` (Grund z. B. "engine gone", Meldung als `evt.process.exited` mit `reason`, kein Absturz, zählt nicht für Exit-Code 5). Beim Beenden der Sitzung bleibt die Reihenfolge der Ränge unverändert.

**Aufgaben:** Umsetzen in `src/supervisor/` (an der Stelle, an der das Ende der Engine erkannt wird). `WorkerBridge.Start` in der neuen Engine bleibt als zweite Sicherung.

**Tests:** Engine hart beenden, während ein Worker einen hängenden Job hat (`Action_TestHangWorker`): Worker ist binnen 1 s weg; die neue Engine baut den Pool auf, ein neuer Job läuft. Engine bis zur Neustartgrenze beenden: keine Worker bleiben übrig.

## 2. Fristen nach einem Stillstand des Supervisors (F-16, E12)

**Heute [gelesen, WI-22]:** Nur der Heartbeat erkennt einen Stillstand des Supervisors (Lücke zwischen zwei Ticks größer als `PING_EVERY_MS`, z. B. Standby oder langer Rückstau) und setzt seine Zeitstempel zurück. Andere Fristen laufen nach der Wanduhr weiter und können nach dem Aufwachen sofort ablaufen:
- `Shutdown.deadlineAt` (hartes Beenden der Kinder),
- `Hub.Request` (über `SetTimer`, z. B. `cmd.app.prepareExit` mit 10 Minuten),
- Frist für `sys.hello` neuer Verbindungen (`Hub.Tick`) und die Startfrist der Kinder (`Children.STARTUP_MS`),
- weitere, die das Paket findet (`DiagReport`, Warten auf `storage`, ...).

**Aufgaben:**
1. Die Stillstandserkennung an **eine** Stelle legen (Tick des Supervisors) und alle Fristinhaber benachrichtigen. Jede Frist wird um die Dauer des Stillstands verlängert (Restzeit bleibt erhalten), statt sofort abzulaufen.
2. Für Fristen über `SetTimer` (`Hub.Request`): Restzeit merken und den Timer neu setzen, oder auf eine Fristliste umstellen, die der Tick prüft. Im Paket entscheiden und begründen.
3. Alle Fristinhaber im Ergebnis auflisten (gefunden, angepasst oder bewusst nicht).

**Tests:** Supervisor 8 s einfrieren (`psutil`), während eine Anfrage `cmd.app.prepareExit` mit verkürzter Frist (`--prepare-limit`, z. B. 5 s) offen ist: Nach dem Fortsetzen läuft sie nicht sofort ab, sondern bekommt ihre Restzeit. Dasselbe für eine neue Verbindung ohne `sys.hello`.

**Hinweis für die Rollen (nicht Teil):** Auch die Fristen der Rollen (`Peer.Request` über `SetTimer`) laufen nach einem Standby alle auf einmal ab. Das ist hinnehmbar (Antwort `timeout`, der Aufrufer wiederholt). Als Beobachtungspunkt in `STATUS.md` aufnehmen.

## Akzeptanzkriterien

- Tests aus 1 und 2 grün, Gesamtlauf grün.
- F-16 in `STATUS.md` geschlossen, E10 umgesetzt.

## Doku

`doc/ARCHITEKTUR.md` 6.2 (Stillstand), 6.4 (Worker-Pool: Ende mit der Engine), `doc/PROTOKOLL.md` 4.1a (`evt.process.exited` mit `reason` "engine gone").

## Ergebnis

**Status: abgeschlossen** (Teil 1, Teil 2 und F-33). Commits: `198d86e` (E10), `576ab57` (F-33), `3d2bd06` (Stillstand F-16/E12), `751416d` (Doku).

### Teil 1: Worker enden mit der Engine (E10)

- `Children.Tick` erkennt das signalisierte Prozess-Handle der Engine und ruft einmal `_EndWorkersOfGoneEngine`: Alle lebenden `worker:*` bekommen `state = stopping`, `killReason = "engine gone"` und `Terminate(name, false)`. Der Auslöser ist das Prozessende der Engine selbst, nicht erst ihre Bewertung (die bis zu 500 ms warten kann). Beim Beenden der Sitzung (`shuttingDown`) passiert nichts, die Ränge gelten. Meldung: `evt.process.exited {reason: "engine gone"}`, kein `crashed`, zählt nicht für Exit-Code 5, kein Neustart. `WorkerBridge.Start` ist unverändert und bleibt zweite Sicherung.
- Test rot, dann grün (`tests/fault/test_worker_lifecycle.py`):
  - `test_engine_killed_during_a_hanging_job_ends_the_worker_at_once_and_the_new_engine_builds_the_pool` (`Action_TestHangWorker`): rot (kein `evt.process.exited` mit `reason` "engine gone"; der Worker verschwand erst durch die neue Engine nach 0,80 s), grün: Worker **0,21 s** nach dem Tod der Engine weg, danach baut die neue Engine ihren Pool auf, ein neuer Job läuft. Zeitbudget im Test 1,5 s (Ziel 1 s; Spielraum wegen paralleler Läufe).
  - `test_engine_beyond_the_restart_limit_leaves_no_worker` (`--restart-max=0`): rot (Worker lebte 5 s nach dem Tod der Engine noch), grün: kein Worker übrig.
  - Geänderte Erwartung (bewusst, E10): `test_engine_restart_during_a_worker_job_leaves_no_orphan_and_the_next_job_runs` erwartet jetzt `reason` "engine gone" statt "killed" (Worker 0,52 s nach dem Tod der Engine weg).
- AHK-Unit-Tests (`tests/ahk/supervisor_tick.test.ahk`): `EngineEndEndsTheWorkers`, `EngineEndDuringShutdownKeepsTheWorkers`.

### Teil 2: Fristen nach einem Stillstand (F-16, E12)

**Entwurf.** Neue Klasse `Stall` (`src/supervisor/Stall.ahk`) misst die Lücke zwischen zwei Ticks (mehr als 2000 ms ist ein Stillstand; Länge = Lücke minus ein regulärer Tick) an **einer** Stelle, am Anfang von `Supervisor._RunTick` (neu aus `_Tick` herausgelöst, damit es mit einer vorgegebenen Zeit testbar ist), noch vor `hub.Pump` und jeder Bewertung. Bei einem Stillstand ruft der Supervisor die Fristinhaber: `children.OnStall(now, ms)`, `hub.Shift(ms)`, `shutdown.Shift(ms)`, `report.Shift(now, ms)`. Die Erkennung ist aus `Heartbeat.Tick` entfernt (`Heartbeat.Arm` entfällt), das Log `a1` "supervisor stood still for N ms" steht jetzt im Supervisor.

**Entscheidung zu Aufgabe 2 (`Hub.Request`): Fristliste statt neu gesetzter Timer.** Jede Anfrage trägt `dueAt`; `Hub.Tick` prüft sie. Begründung: Ein `SetTimer`, der im Stillstand fällig wurde, kann nach dem Fortsetzen vor dem Tick laufen, der den Stillstand bemerkt; die Reihenfolge fälliger Timer ist nicht zu steuern (vermutet, nicht nachgestellt). Bei einer Liste im Tick ist die Reihenfolge deterministisch (Stillstand messen, verschieben, dann prüfen), und eine Antwort, die im Stillstand eintraf, wird vor der Fristprüfung gelesen (`Pump` vor `Tick`). Preis: die Frist ist auf einen Tick (200 ms) genau statt auf eine Timerauflösung.

**Liste aller Fristinhaber:**

| Fristinhaber | Ergebnis |
|---|---|
| `Heartbeat` (Pong-/Ping-Zeit, Startfrist `Children.STARTUP_MS`) | angepasst: `Children.ResetLiveness` wie bisher, jetzt vom Supervisor über `OnStall` aufgerufen |
| Killzeit eines hängenden Kindes (`killAt`, `KILL_AFTER_MS`) | angepasst (`Children.OnStall`; vorher bewusst unverändert, jetzt verschoben) |
| geplanter Neustart (`restartAt`, `RESTART_DELAY_MS`) | angepasst (`Children.OnStall`) |
| Nachfrist eines beendeten Prozesses (`exitSeenAt`, `EXIT_GRACE_MS`, WI-30) | angepasst (`Children.OnStall`) |
| `Shutdown.deadlineAt` und `killDeadline` (`KILL_WAIT_MS`) | angepasst (`Shutdown.Shift`) |
| `Hub.Request`, u. a. `cmd.app.prepareExit` (`--prepare-limit`) und `cmd.diag.snapshot`, `cmd.storage.report.write` des Berichts | angepasst (Fristliste, `Hub.Shift`) |
| `sys.hello`-Frist neuer Verbindungen (`Hub.HELLO_TIMEOUT_MS`) | angepasst (`Hub.Shift`) |
| `DiagReport`: Warten auf `storage` (`STORAGE_WAIT_MS`, SetTimer) | angepasst (`DiagReport.Shift` setzt den Timer mit der Restzeit neu). Ein Timer, der vor dem Tick liefe, beantwortet den Aufrufer nur früher ("kept and written when storage is back"); der Bericht geht nicht verloren |
| Neustarthistorie (`RESTART_WINDOW_MS`, 60 s) | bewusst nicht: eine Rate über echte Zeit |
| Mindestabstand automatischer Berichte (`AUTO_MIN_INTERVAL_MS`), Fenster der Fehlerzählung (`ERROR_WINDOW_MS`) | bewusst nicht: Raten über echte Zeit, ein Stillstand zählt als vergangene Zeit |
| `Hub._Deny` (SetTimer 50 ms bis zum Schließen), `Wake`-Fallback-Timer (250 ms), `Request` ohne Verbindung (SetTimer -1) | bewusst nicht: keine Fristen im Sinne des Pakets |
| `PipeConnection.WRITE_GONE_MAX_MS` (1 s) und Drain-Frist von `CloseWhenFlushed` | nicht angepasst (`src/core/`, nicht im Paket); neuer Fund F-35 |
| `SupervisorCommand` (Anfrage- und Verbindungsfrist der zweiten Instanz) | nicht vorhanden im Supervisor-Prozess (läuft in der zweiten Instanz, nicht im Hub) |
| Fristen der Rollen (`Peer.Request`, `SetTimer`) | nicht Teil (Hinweis des Pakets): Beobachtungspunkt in `STATUS.md` |
| Frist von `sys.shutdown` bei den Rollen | nicht vorhanden als Uhr im Supervisor: sie kommt als `deadlineMs` und wird von der Rolle gemessen |

**Tests rot, dann grün** (`tests/fault/test_supervisor_stall.py`, Supervisor 8 s mit `psutil.suspend` eingefroren):
- `test_open_prepare_exit_request_keeps_its_remaining_time_after_a_stand_still` (`--prepare-limit=5000`, Anfrage offen): rot (Ende **0,24 s** nach dem Fortsetzen), grün (**5,11 s**, Rest der Frist).
- `test_connection_without_hello_keeps_its_remaining_time_after_a_stand_still` (Verbindung, nach 1,5 s 8 s Stillstand): rot (geschlossen **0,00 s** nach dem Fortsetzen), grün (**3,45 s**, Rest von 5 s).
- Der bestehende `test_supervisor_stand_still_does_not_make_healthy_children_hung` bleibt grün (das Log "supervisor stood still" wird weiter gefunden).
- AHK-Unit-Tests: `StallMovesEveryDeadline`, `NoStallMovesNothing`, `StallBeforeTheFirstTickIsMeasured`, `StallMovesTheTimesOfTheRecords`, `ShutdownDeadlinesMove`, `HubRequestEndsAtItsLimit`, `HubShiftMovesTheLimits` (`supervisor_tick.test.ahk`), `CheckAStandStillMovesTheWaitForStorage` (`diag_report.test.ahk`). Die fünf Heartbeat-Tests zum Stillstand laufen jetzt über `Stall` und `Children.OnStall` (`StalledTick`), ihre Erwartungen sind unverändert.

### F-33

Behoben (`576ab57`): Die Kill-Phase endet mit `EXIT_CLEAN`, `_Done` macht 5 daraus nur bei `children.AnyKilled()`. Unit-Tests `EndedAtTheDeadlineIsNoForcedExit` (mit der alten Zeile **rot**: Exit 5, mit der neuen grün: 0) und `TerminatedAtTheDeadlineIsAForcedExit` (5). Im echten Supervisor nicht beobachtet und nicht nachgestellt. Das Feld `Shutdown.forced` wird weiter gesetzt, aber nirgends gelesen.

### Gelaufene Tests

- `python -m pytest tests/ahk tests/test_ahk_runner.py tests/test_architecture.py tests/integration/test_supervisor.py tests/integration/test_worker.py tests/integration/test_worker_busy.py tests/integration/test_worker_pool.py tests/fault -q` (parallel, 8 Worker): **577 passed, 1 skipped** in 98 s. Der Lauf umfasst auch `test_shutdown.py`, `test_timeouts.py` (Frist 500 ms von `--prepare-limit`, jetzt auf einen Tick genau), `test_report.py`, `test_process_*.py`, `test_orphans.py`, `test_supervisor_stall.py`.
- Ein früherer Lauf (4 Dateien, 47 Tests) hatte einen Ausfall beim Start einer Kette (`AhfTimeout: no answer to obs#1 within 2.0 s`, `test_supervisor_stand_still_does_not_make_healthy_children_hung`) vor jeder Stillstandsprüfung; der Test lief danach in zwei weiteren Läufen grün. Das passt zu F-02 (Start unter Last), ist aber nicht untersucht.
- Nicht gelaufen: Gesamtlauf (macht ein eigener Agent), `tests/integration/test_engine.py`, `test_role.py`, `test_pipe.py`, `test_storage.py`, `tests/e2e`, `tests/stress`, Wiederholungsläufe (`AHF_FAULT_REPEAT`).
- Nach den Läufen keine Testprozesse übrig (angesehen; nur `AutoHotkeyU32.exe` "Allgemeine Hilfe" des Projektinhabers).

### Nicht geprüft

- Ein echter Standby der Maschine (getestet wurde das Einfrieren des Supervisors mit `psutil`; ob `Time.NowMs` per `QueryPerformanceCounter` im Standby weiterläuft, ist nicht geprüft).
- Dass ein `SetTimer` nach einem Stillstand tatsächlich vor dem Tick laufen würde (Grund für die Fristliste): vermutet, nicht nachgestellt.
- Dass die Kill-Phase von `Shutdown` im echten Supervisor mit einem Prozess an der Frist 0 statt 5 meldet (nur Unit-Test).
- Stillstand während des Beendens (`Shutdown.Shift`): nur Unit-Test, kein Prozesstest.

### Abweichungen

- Die Commits sind gröber als "eine Änderung je Commit", weil Dateien (`Children.ahk`, `Shutdown.ahk`, `supervisor_tick.test.ahk`) zu mehreren Änderungen gehören: die AHK-Unit-Tests von E10 und F-33 stehen im Commit `3d2bd06` (Stillstand). `Children.ahk` und `Shutdown.ahk` wurden dafür teilweise gestaged.
- `Hub.Request`-Fristen sind jetzt auf einen Tick (200 ms) genau und laufen nicht mehr über `SetTimer` (siehe Entscheidung). Bestehende Assertions blieben unverändert; nur die Erwartung `reason` "killed" in einem Testfall wurde durch E10 zu "engine gone".
- `Heartbeat.Arm` entfällt (die Erkennung liegt im Supervisor); fünf Heartbeat-Unit-Tests wurden auf `Stall` umgestellt.
- Keine Änderung in `src/core/` und in `src/engine/`.

### Neue Funde

- **F-35** (in `STATUS.md`): Die zeitgebundenen Stellen der Hub-Verbindung (`PipeConnection.WRITE_GONE_MAX_MS`, Drain-Frist) kennen keinen Stillstand [gelesen, `src/core/`, nicht geändert]. Der Auftrag nannte F-34 als belegt (`WI-31` nennt F-34 als nächste freie Nummer), deshalb F-35.

### Offene Punkte

- Beobachtungspunkt in `STATUS.md`: Fristen der Rollen (`Peer.Request`) nach einem Standby.
- F-35 (siehe oben).
- Doku: `doc/ARCHITEKTUR.md` 6.2, 6.3, 6.4, `doc/PROTOKOLL.md` 4.1 (Frist von `prepareExit`) und 4.1a (`reason` "engine gone"), `doc/HOW-TO.md` (drei Einträge). `.vscode/tasks.json`: keine neue Aufrufart, keine Änderung.
