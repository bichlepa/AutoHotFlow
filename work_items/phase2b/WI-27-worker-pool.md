# WI-27 Worker-Pool-Lebenszyklus

Größe: L · Hängt ab von: WI-22, WI-23 · Blockiert: Port der Worker-Elemente in Phase 3 (Dialoge, Downloads, AHK-Skripte, RunWait)

## Ziel

Der Worker-Pool funktioniert im Produkt ohne Eingriffe: Worker werden bei Bedarf gestartet, nach Absturz ersetzt, nach einem Abbruch oder einer Fristüberschreitung beendet, und ein lange blockierender Worker wird nicht als hängend erschossen. Entscheidung E3: **Der Supervisor startet und beendet Worker auf Anfrage der Engine; ein Worker im Job ist von der Ping-Prüfung ausgenommen; die Engine hält die Fristen.**

## Funde [gelesen]

1. **Niemand startet Worker.** Die Engine nimmt `--workers=n` (`Engine._PoolSize`), aber der Supervisor gibt die Option nicht weiter (`Supervisor._RoleOpts`) und startet keine `worker:n`. Nur die Tests starten Worker selbst (`tests/integration/test_worker.py`). Im Produkt endet jedes Worker-Element mit "worker not available".
2. **Kein Ersatz nach Absturz.** `WorkerBridge` setzt den Slot auf `down`; nur `evt.process.ready` macht ihn wieder `idle`, und der Supervisor startet Worker nicht neu (`Children.AUTO_RESTART` nur `storage`, `engine`). Ein Slot, der einmal `down` ist, bleibt es.
3. **Abbruch ohne Wirkung bei blockierenden Workern.** `WorkerBridge.Cancel` setzt den Slot nach `ORPHAN_MS` (2 s) auf `down`, der Prozess (z. B. mit offener `MsgBox`) läuft weiter. `doc/ARCHITEKTUR.md` 5.1 verlangt "Frist 2 s ohne Quittung → Worker hart beenden"; die Engine darf aber keine Prozesse beenden.
4. **Neustart der Engine:** Laufende Worker-Jobs der alten Engine sind verwaist. Die neue Engine hält die Slots für `idle`, `cmd.worker.run` trifft auf `busy`, der Slot wird `down`, das späte `evt.worker.done` des alten Jobs wird verworfen. Der Pool bleibt geschädigt.
5. **Heartbeat erschießt blockierende Worker.** Ein Worker, der länger als 6 s am Stück blockiert (Download, synchroner COM-Aufruf, langer `DllCall`), beantwortet keine Pings und wird beendet ("worker crashed"). `MsgBox`, `InputBox` und `RunWait` pumpen Nachrichten und sind unkritisch (`doc/HOW-TO.md`, Worker-Abschnitte). Entscheidung in WI-11 war "keine Toleranz"; E3 ändert das.

## Entwurf (im Paket ausarbeiten, zuerst in `doc/ARCHITEKTUR.md` und `doc/PROTOKOLL.md`, dann Code)

- **Neue Befehle an den Supervisor**, nur für den Absender `engine` und nur für Namen `worker:*` erlaubt (sonst `denied`):
  - `cmd.process.spawn {role: "worker"}` → `{ok, name}` (der Supervisor vergibt die Nummer).
  - `cmd.process.kill {name, reason}` → `{ok}` (TerminateProcess, Meldung wie heute über `evt.process.*`).
- **Busy-Meldung des Workers:** Der Worker meldet dem Supervisor Beginn und Ende eines Jobs (z. B. `sys.busy {busy}`), der Heartbeat prüft Pongs eines beschäftigten Workers nicht. Alternativ meldet die Engine es dem Supervisor; im Paket entscheiden und begründen. Ein beschäftigter Worker, dessen Prozess stirbt, wird weiter über den Prozess-Handle erkannt.
- **Pool-Regeln in der Engine** (`WorkerBridge`): Obergrenze N (Option, Standard z. B. 4, später Einstellung), Zahl warmer Worker W (Standard 1). Alle beschäftigt und weniger als N vorhanden → neuen anfordern; der Thread wartet `ready` wie heute. Überzählige freie Worker enden nach einer Leerlaufzeit (z. B. 60 s).
- **Abbruch:** `cmd.worker.cancel`; kommt binnen `ORPHAN_MS` kein `evt.worker.done`, fordert die Engine `cmd.process.kill` an und bei Bedarf Ersatz.
- **Jobfrist:** optional je Element (`timeoutMs`), sonst keine (v1 hatte keine). Ablauf → wie Abbruch, Ergebnis `exception` "worker timeout".
- **Engine-Neustart:** Die neue Engine fragt `cmd.process.list` und beendet alle vorhandenen `worker:*` (Waisen der alten Epoche), dann baut sie den Pool neu auf. Einfacher und sicherer als Übernehmen.
- **Absturz eines Workers:** Slot entfernen, laufendes Element `exception` "worker crashed" (wie heute), Ersatz bei Bedarf. Neustartstürme begrenzen (z. B. höchstens 5 Starts in 60 s, dann `exception` "worker not available" und `a0`-Log).
- **Beenden:** unverändert (Worker Rang 3). Ein beschäftigter Worker meldet `stopped` vor `sys.bye` (wie heute).

## Tests (`tests/integration/test_worker.py`, `tests/fault/`)

- Produktstart ohne Testoptionen: ein Worker-Element läuft (Pool startet bei Bedarf), Zeit bis zum Start des ersten Jobs gemessen (Ziel unter 300 ms kalt).
- `Action_TestBlockWorker` blockiert länger als 6 s am Stück: kein `hung`, Element endet normal.
- Abbruch eines hängenden Workers (`Action_TestHangWorker`): Prozess nach Frist beendet, Ersatz verfügbar, nächster Job läuft.
- Worker-Absturz während eines Jobs: `exception`, Ersatz, nächster Job läuft.
- Engine-Neustart während eines Worker-Jobs: keine Waisen danach (Prozessliste), neuer Job läuft.
- Mehr Jobs als N: die überzähligen warten und laufen nacheinander, Obergrenze nie überschritten.
- `cmd.process.spawn`/`kill` von einem anderen Absender als `engine`: `denied`.
- Leerlauf: überzählige Worker enden nach der Leerlaufzeit (Zeit im Test per Option verkürzen).

## Doku

`doc/ARCHITEKTUR.md` 2.3, 3, 5.1 (Frist und hartes Beenden), 6.2; `doc/PROTOKOLL.md` 4.1 (neue Befehle, Rechte), 4.5 (Umsetzung WorkerBridge neu); `doc/HOW-TO.md`. Den Abschnitt "Entscheidung für WI-11: keine Heartbeat-Toleranz" im Kopf von `src/worker/Worker.ahk` anpassen.


## Ergebnis

Stand: 2026-10-12, Branch `v2-port`. **Status: abgeschlossen.** Die Schritte (a) bis (f) sind umgesetzt und getestet. Keine Eskalation: Abbruch (d) und Neustart (e) ließen sich innerhalb der Architektur von E3 lösen (die Engine hält Pool, Fristen und Aufräumen, der Supervisor besitzt nur die Prozesse).

### Commits

| Schritt | Commit | Inhalt |
|---|---|---|
| (a) Entwurf | `5404731` | ARCHITEKTUR 2.3, 3, 5.1, 6.2 und neu 6.4 (Pool-Regeln, Werte), PROTOKOLL 4.1 (`cmd.process.spawn`, `cmd.process.kill`, `sys.busy`), 4.1a, 4.5 |
| (b) Supervisor-Befehle | `a7fa998` | `Children.SpawnWorker`/`KillWorker`, Rechteprüfung in `Supervisor._OnProcess` (nur Absender `engine`, nur Rolle und Namen `worker:*`, sonst `denied`) |
| Busy und Heartbeat | `55abcbf` | Worker meldet `sys.busy`, Heartbeat lässt einen beschäftigten Worker aus, `busy` in `BOOL_FIELDS` und `WIRE_BOOL_RE` |
| Testelemente | `682a729` | `AhfElement.JobTimeoutMs`, `Action_TestFreezeWorker`, `Action_TestFreezeTimeoutWorker`, `Duration` für `Action_TestBlockWorker` |
| (c) bis (e) Pool, Abbruch, Frist, Neustart | `961fed2` | `WorkerBridge` neu, `Engine` (Optionen, `Start`/`Stop`), `Executor` (`Want`, Jobfrist), der Supervisor reicht die Optionen weiter. (c), (d) und (e) teilen den Zustand einer Klasse und sind daher **ein** Commit |
| Fund F-27 | `9221437` | `Children._Launch`: Zustand vor `CreateProcessW` setzen (Wettlauf mit `sys.hello`) |
| (f) Tests | `edaad96`, `0ad3847` | Unit-, Integrations- und Fault-Tests (unten); zwei bestehende Fault-Tests warten auf `worker:1` |
| Doku | `762b4a7` | HOW-TO, MIGRATION M-20, TESTSTRATEGIE, PROTOKOLL-Optionen |

### Zu den fünf Funden

1. **Niemand startet Worker:** behoben. Die Engine fordert beim Start einen warmen Worker an und bei Bedarf weitere. Beleg: `test_product_start_without_test_options_runs_a_worker_element` (Supervisor mit `--start=storage,engine`, keine Pool-Option, `worker:1` wird bereit, das Worker-Element läuft).
2. **Kein Ersatz nach Absturz:** behoben. Belege: `test_killed_worker_ends_its_element_with_worker_crashed_and_the_pool_has_a_replacement` (Kill im Job: `exception` "worker crashed (worker:1)", danach ein neuer Worker bereit, der nächste Job läuft), `test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted` (WI-15, angepasst: der Supervisor startet nie selbst neu), `test_frozen_worker_does_not_answer_the_run_and_is_replaced`, `test_five_failures_within_a_minute_block_the_pool`.
3. **Abbruch ohne Wirkung:** behoben. Belege: `test_cancel_of_a_frozen_worker_ends_the_instance_at_once_and_the_process_is_killed_and_replaced` (Instanz endet sofort, Prozess nach der 2-s-Frist beendet, nächster Job läuft auf neuem Worker), `test_job_deadline_ends_the_element_with_worker_timeout_and_kills_the_worker`.
4. **Neustart der Engine:** behoben. Beleg: `test_engine_restart_during_a_worker_job_leaves_no_orphan_and_the_next_job_runs` (Waise nach 0,68 s beendet, genau ein neuer Worker, nächster Job läuft).
5. **Heartbeat erschießt blockierende Worker:** behoben. Belege: `test_a_worker_that_blocks_longer_than_6_s_is_not_hung_and_the_element_ends_normal` (Ende zu Ende, 7,5 s in einem Aufruf), `test_worker_that_blocks_longer_than_the_pong_timeout_is_not_hung_while_it_has_a_job` (nur Supervisor), AHK-Fälle in `tests/ahk/supervisor_tick.test.ahk` ("a busy worker is not pinged and not hung", "the pong time of a worker starts again when its job ends", "a worker without a job is hung as before").

Alle Pool-Pfade ("worker crashed", "worker timeout", "worker not available") enden über `onDone` und `ctx.Finish`; `Executor._OnFinish` räumt `run["active"]` weiter auf (WI-21 Punkt 5 bleibt gültig).

### Entscheidungen und Werte

| Frage | Entscheidung | Begründung |
|---|---|---|
| Busy-Meldung | **Der Worker meldet** (`sys.busy {busy}` an den Supervisor), nicht die Engine | Die Tatsache gehört dem Worker (ein Besitzer pro Datum). Die Meldung geschieht im Handler von `cmd.worker.run`, vor dem Start des Elements: es gibt keine Lücke, in der der Worker blockiert, ohne beschäftigt gemeldet zu sein. Eine Meldung der Engine bräuchte Ordnung zwischen zwei Verbindungen (Engine → Worker, Engine → Supervisor) und bliebe nach dem Tod der Engine falsch. Preis: ein verlorenes `busy: false` (vermutet, F-30) |
| Obergrenze N | **4** (`--workers`, 0 bis 8, 0 = kein Pool). Der Supervisor lässt zusätzlich nie mehr als 16 lebende Worker zu | vier gleichzeitig blockierende Elemente decken die üblichen Flows; etwa 14 MB je Prozess |
| Warme Worker W | **1** (`--warm-workers`) | der erste Job wartet nicht auf einen Prozessstart |
| Leerlaufzeit | **60 s** (`--worker-idle-ms`, 100 ms bis 1 h) | Dialog-Flows kehren oft nach Sekunden wieder; ein Prozess im Leerlauf kostet nur Speicher |
| Sturmgrenze | **5 abnormale Enden in 60 s** (Absturz, nicht bereit gewordener Start, abgelehntes `cmd.worker.run`, abgelehnte Startanfrage). Danach keine neuen Worker, bis das älteste Ende das Fenster verlässt; ohne lebenden Worker enden Worker-Elemente mit "worker not available" | siehe Abweichungen |
| Jobfrist-Standard | **keine** (v1 hatte keine). Eine Elementklasse kann `JobTimeoutMs` setzen | ein Dialog darf beliebig lange offen bleiben |
| Bestätigung des Abbruchs | 2 s (`ORPHAN_MS`, unverändert), danach Kill | ARCHITEKTUR 5.1 |

### Messungen (verifiziert, gelaufen; Python-Beobachter, `-s`)

- **Zeit bis zum Start des ersten Jobs, kalt** (`--warm-workers=0`, Pool leer, der Prozess muss starten): Ende des Trigger-Elements bis Start des Worker-Elements **76 bis 101 ms** in 8 Läufen (Ziel unter 300 ms erreicht). Gemessen aus zwei Engine-Ereignissen, damit der Weckverzug einer Python-Anfrage (bis 250 ms) nicht eingeht.
- Warmer Worker: Flow starten bis Instanz beendet 0,18 s (enthält den Weckverzug der Python-Anfrage).
- `cmd.process.kill` bis `evt.process.exited`: 258 ms.
- Stopp eines Flows mit eingefrorenem Worker: Instanz beendet nach 0,05 s, Prozess beendet 2,13 s nach dem Stopp.
- Jobfrist 1500 ms: Instanz beendet nach 1,55 s, Prozess beendet nach 3,69 s (Frist plus 2 s).
- Kill eines Workers im Job bis `exception`: 0,09 s. Eingefrorener Worker ohne Antwort auf `cmd.worker.run`: 5,1 s (Annahmefrist 5 s). Engine getötet bis Waise beendet: 0,68 s. Leerlauf-Ende (Option 1500 ms): 1,83 s nach dem letzten Job.
- Obergrenze: 4 Jobs bei N=2: höchstens 2 Jobs gleichzeitig (aus Engine-Ereignissen) und höchstens 2 Worker-Prozesse (Stichproben alle 100 ms).

### Tests

Rot vor dem Code: Acht Lifecycle-Tests liefen gegen den Stand `45c501a` (Produktstart, kalter Start, Abbruch eines eingefrorenen Workers, Jobfrist, Absturz mit Ersatz, Neustart der Engine, Grenze N, Leerlauf-Ende) und scheiterten alle; das deckt die Funde 1 bis 4. Nicht rot gelaufen: "kein Pool", 7,5-s-Blockade, eingefrorener Worker ohne Antwort, Sturm. Die Supervisor-Tests von (b) waren vor dem Code rot (`unknown_type`). Die Unit-Tests von `WorkerBridge` und die neuen AHK-Fälle von `supervisor_tick` entstanden nach dem Code und liefen nicht rot.

- `tests/integration/test_worker_pool.py` (9): spawn und kill mit Rechten (`denied` für den Absender `manager`, für die Rollen `storage`, `engine`, `manager`, `supervisor` und für die Namen `echo:a`, `engine`, `storage`, `supervisor`, `worker`, `workers:1`), `not_found`, `bad_payload`, Nummernvergabe, Obergrenze (`busy`), Kill als geplantes Ende ohne Exit-Code 5, Spawn während des Beendens (`shutting_down`).
- `tests/integration/test_worker_busy.py` (1) und `tests/integration/test_worker.py` (+2: `sys.busy` bei Beginn und Ende, auch nach Abbruch).
- `tests/ahk/engine_worker_bridge.test.ahk` (21 Fälle, ohne Prozesse): Start mit Prozessliste und Waisen, Grenze N, Bedarf zählt startende Worker, Ready vor der Antwort, jüngster Leerlauf-Slot zuerst, Leerlauf-Ende, beschäftigter Worker nicht beendet, Absturz im Job, abgelehnter Lauf, Sturm (5 Fehler), Eigenenden sind keine Fehler, abgelehnte Startanfragen, bestätigter und unbestätigter Abbruch, Jobfrist, Jobende vor der Frist, gestoppter Pool.
- `tests/ahk/supervisor_tick.test.ahk` (+5): beschäftigter Worker, Pong-Zeit nach dem Job, Worker ohne Job, nur ein Worker kann beschäftigt sein, Hello vor dem Speichern der Pid.
- `tests/fault/test_worker_lifecycle.py` (12), Liste oben.
- Ersetzt: die Engine-Tests der festen Slots aus WI-11 in `test_worker.py`. **Nicht übernommen:** `test_snapshot_is_answered_within_50_ms_while_a_worker_element_blocks`. Python-Anfragen an den echten Hub tragen bis 250 ms Weckverzug, eine 50-ms-Aussage ist so nicht messbar. Die Eigenschaft (die Engine antwortet, während ein Worker blockiert) folgt aus der Prozesstrennung und ist nur mittelbar gestützt.
- Die Engine-Tests mit Python-Hub (`test_engine.py`, `test_storage.py`) starten die Engine mit `--workers=0` (dort gibt es keinen Supervisor).

### Läufe

- **Seriell** `python -m pytest tests -q -n 0` (Endstand `0ad3847`): **631 passed, 1 skipped, 14 deselected in 563 s**. Zwei frühere serielle Läufe auf dem Weg: (1) 601 passed, 3 failed in 830 s: `test_healthy_session_exits_within_2_seconds_and_every_role_says_it_is_clean[0]` (F-26, Manager `clean: false`), `test_worker_that_blocks_longer_than_the_pong_timeout_is_not_hung_while_it_has_a_job` (Fehler im Test: zwei Leser auf einem Client, behoben in `edaad96`), `tests/stress/test_clients_churn.py::...[smoke]` ("too few probe requests: 19", im Einzellauf grün); (2) 629 passed, 2 failed in 599 s: `test_children_end_within_the_orphan_budget_when_the_supervisor_is_killed[0]` und `test_supervisor_stand_still_does_not_make_healthy_children_hung[0]` (beide, weil der warme Worker beim Eingriff noch im Handshake war, siehe Abweichungen; behoben in `0ad3847`).
- **Stress** `python -m pytest tests -m stress -q`: **13 passed, 633 deselected in 201 s**.
- **Parallel** `python -m pytest tests -q` (`-n auto`, 8 Prozesse), 5 Läufe in 70 bis 97 s mit je 629 oder 630 passed: (1) 2 failed: `test_ahk_runner.py::test_ahk_file_completes[element_runner.test.ahk]` und `...[element_runner.test.ahk-Runner: a timer is cancelled when the run finishes]` ("the timer did not fire after Finish: expected 0 (Integer) but got 1 (Integer)"); (2) 1 failed: `tests/stress/test_big_flows.py::test_many_big_flows_load_without_hung_and_with_a_responsive_engine[smoke]` (Snapshot-Latenz max 1023 ms gegen die Grenze 1000 ms); (3) 1 failed: `tests/integration/test_storage.py::test_no_log_line_is_lost_while_other_processes_hold_the_files[readers-allow-read]`; (4) 1 failed: `test_ahk_runner.py::test_ahk_file_completes[element_sleep.test.ahk]`; (5) 2 failed: `tests/stress/test_clients_churn.py::...[smoke]` und `test_ahk_runner.py::test_ahk_case[storage_queue.test.ahk-a budget runs many small operations in one go]`. Alle sind zeitempfindlich und unter Last knapp (F-19-Familie); keiner betrifft neuen Code. `test_big_flows[smoke]` und der `storage_queue`-Fall scheitern auch auf dem Stand vor WI-27 (`45c501a` in einem Git-Worktree, 3 Läufe mit 6 bis 7 Fehlschlägen; dort kamen weitere Fälle dazu, die v1-Flows lesen und im Worktree nicht vergleichbar sind, Ursache nicht geprüft). Keine Frist in einer bestehenden Prüfung wurde geändert.
- Nach den Läufen (nur angesehen): Die Prozessliste zeigt einen AutoHotkey-Prozess ohne `--session` (`AutoHotFlow.ahk` ohne Argumente, Pid 17332). Er gehört nicht zu den Tests (jeder Testprozess trägt `--session=`) und wurde nicht angefasst.

### Abweichungen von der Paketbeschreibung

- **Die Sturmgrenze zählt Fehler, nicht Starts.** "Höchstens 5 Starts in 60 s" hätte einen normalen Stoß von vier gleichzeitigen Jobs (vier Starts) und das Wiederaufwärmen nach dem Leerlauf als Sturm gewertet. Gezählt werden Absturz, nicht bereit gewordener Start (der Supervisor meldet `hung`), abgelehntes `cmd.worker.run` und fehlgeschlagene Startanfrage. Der `a0`-Eintrag "worker pool blocked" kommt einmal je Sperre und von der Engine.
- **Kein Slot-Zustand `down`:** ausgefallene Worker verschwinden aus der Liste (der Zustand war der Kern von Fund 2).
- **Ein abgelehntes `cmd.worker.run`** entfernt den Slot und beendet den Prozess (vorher: Slot `down`, Prozess unberührt).
- **`evt.process.exited` für einen auf Anfrage beendeten Worker** trägt `reason: "killed"` und `clean: false`; es ist kein `crashed`, und der Supervisor-Exit-Code 5 bleibt unberührt.
- **Neuer Nebeneffekt der Voreinstellung:** Jede Sitzung mit einer Engine hat jetzt einen warmen Worker. Zwei Fault-Tests (Orphan-Guard, Stillstand des Supervisors) warten deshalb auf `worker:1` (`0ad3847`). Das ist eine Änderung der Vorbedingung, keine Frist.
- Die Engine beendet nie selbst einen Prozess; Beenden und Ersatz laufen über `cmd.process.kill` (WI-27 Fund 3).
- Gemeinsamer Commit für (c), (d), (e) (siehe oben). Die Reihenfolge der Schritte im Plan wurde eingehalten, die Zahl der Commits nicht.

### Nicht geprüft

- Echte blockierende Dialog-Elemente (`MsgBox`, `InputBox`, Downloads) im Worker: nur Testelemente mit `DllCall("Sleep")`. Dialoge laufen unter dem Wächter von `ahkrun.py` nicht (HOW-TO).
- Wirkung des warmen Workers auf Ruhe-CPU und Speicher des Gesamtsystems (E5, unter 1 %): nicht neu gemessen. Der Prozess kostet im Leerlauf etwa 14 MB (Messwert des Spikes), keine eigene Messung.
- N > 4, W > 1, große Pools im Dauerlauf (Soak): nur kleine Pools (N bis 3) in Tests.
- Verhalten bei verlorenen Abonnement-Ereignissen oder nach einem Verbindungsabbruch der Engine zum Hub: gelesen, nicht getestet (F-30).
- Windows-Standby und Sitzungswechsel.
- 20 Wiederholungen der neuen Fault-Tests (`AHF_FAULT_REPEAT=20`): nicht gelaufen. Gelaufen sind `test_killed_engine_is_reported_restarted...` 12-mal bei `-n 6` (12 von 12 grün nach F-27) und `test_healthy_session_exits...` 30-mal seriell (2 Fehlschläge = F-26).

### Neue Funde

- **F-27 (mittel, behoben in `9221437`): Wettlauf in `Children._Launch`.** AHK unterbrach den Thread zwischen `CreateProcessW` und dem Speichern von Pid und Zustand, das Kind meldete sich (`sys.hello`) in der Zwischenzeit, danach setzte `_Launch` den Zustand auf `starting` zurück. Das Kind blieb "starting", bis der Start-Timeout es als hängend beendet hätte. Sichtbar wurde es durch `cmd.process.list` und den Worker-Start der Engine während `Start()` des Supervisors (`test_killed_engine_is_reported_restarted_and_the_others_are_untouched` scheiterte 11 von 12 Mal bei `-n 6`; 12 von 12 grün nach der Korrektur und auf `45c501a`). Der Wettlauf ist nicht deterministisch nachgestellt; nur `OnHello` ohne Pid hat einen Unit-Test. Das Problem war vorher latent (jeder Start eines Kindes unter Last).
- **F-28 (niedrig, gelesen): Log-Einträge eines Workers erreichen `storage` nie.** `Worker` ruft `SetLogTarget` nicht auf (`Role.logTarget` bleibt leer), die Einträge warten in der Warteschlange (500, dann fallen die ältesten heraus). Auch `a0` und `f2` aus `Worker._OnFinish` gehen verloren. Ohne Wirkung auf die Funktion, aber für die Diagnose in Phase 3 (Dialog-Elemente) relevant. Nicht behoben: der Worker bräuchte dafür einen Log-Pfad (über die Engine oder direkt zu `storage`), das ist eine Entscheidung. F-17 (Kind mit hoher Log-Last) betrifft Worker nicht, solange sie nichts senden.
- **F-29 (niedrig, gesehen): Ein Kind, das sich noch verbindet, wird vom Orphan-Guard nicht erfasst.** `Role._Guard` misst nur den Zustand `reconnecting`. Ein Kind im Handshake bleibt, wenn der Supervisor stirbt, bis zum Ende des Wiederverbindungs-Budgets des Peers (10 s) am Leben (der Fault-Test fand nach 5 s einen Prozess der Sitzung). Umgekehrt gibt ein Kind im Handshake bei einem eingefrorenen Hub nach 3 s auf (kein Welcome). Beides ist vertretbar, aber in ARCHITEKTUR 6.3 nicht beschrieben.
- **F-30 (niedrig, vermutet): Verlorenes `sys.busy {busy: false}`.** Wird die Meldung nicht zugestellt (Peer nicht bereit), bleibt der Worker für den Supervisor beschäftigt und wird nie als hängend erkannt. Aufgefangen wird es durch die Annahmefrist der Engine beim nächsten Job (5 s, dann Kill und Ersatz). Nicht nachgestellt.
- F-26 (bekannt): in diesem Paket erneut gesehen. `test_healthy_session_exits...` 2 von 30 Läufen (6,7 %), im seriellen Gesamtlauf 1-mal; `test_frozen_storage_is_terminated...` 1 von 2 Läufen. Gleiche Größenordnung wie 7 von 150 (WI-26); kein Hinweis, dass der warme Worker die Häufigkeit ändert. Nicht untersucht. Der Pool nutzt denselben Pfad (`evt.process.exited`); `clean: false` bei einem getöteten Worker ist gewollt.
- F-19 (bekannt): `test_two_sessions_in_a_row_both_exit_within_2_seconds` einmal bei `-n 4` mit 2,011 s gegen 2,0 s. Ein zusätzlicher Rang (Worker) kostet beim Beenden etwa einen Supervisor-Tick (200 ms); der gesunde Austritt liegt bei 0,86 s.
- F-16 bis F-26 nicht doppelt angelegt. Die nächste freie Nummer ist F-31.

### Offene Punkte

- **Waisen zwischen dem Tod und dem Neustart der Engine:** Die alte Engine ist tot, die neue noch nicht da (300 ms Neustartverzögerung plus Startzeit); ein Worker mit Dialog bleibt in dieser Zeit sichtbar. Scheitert der Neustart der Engine (3 Versuche in 60 s), bleiben die Waisen bis zum Beenden der Sitzung. Alternative zur Entscheidung des Projektinhabers: Der Supervisor beendet alle `worker:*`, sobald die Engine endet (Prozessverwaltung, keine Fachlogik); das widerspricht dem Wortlaut von WI-27 nicht, wenn es zusätzlich zum Aufräumen der Engine geschieht.
- **Debugger (E1):** Pausieren wirkt an Elementgrenzen, ein Worker-Job läuft zu Ende (ARCHITEKTUR 4.3). Die Jobfrist der Engine läuft in einer Pause weiter; für den Debugger muss die Uhr anhaltbar werden (Phase 3 oder später).
- **HOW-TO-Einträge** stehen am Dateiende (Kategorie "Tests und Werkzeuge"), nicht in "Prozesse, Pipes, Nachrichten": in WI-29 einsortieren.
- `STATUS.md` und `AGENTS.md` nicht angepasst (WI-29). Zu übertragen: F-27 bis F-30, die Pool-Werte, "WI-27 abgeschlossen".
- `--workers`, `--warm-workers` und `--worker-idle-ms` sind Startoptionen; eine Einstellung im Manager folgt mit den Einstellungen (Phase 3).
- `tests/ahk/engine_worker_bridge.test.ahk` setzt `WorkerBridge.ORPHAN_MS` zeitweise; die Konstante ist nur im Test als änderbar gedacht.

### HOW-TO-Einträge (Status in der Datei)

- Worker-Pool: `Map.Delete` auf einen fehlenden Schlüssel wirft (verifiziert).
- Worker beschäftigt melden: der Worker, vor dem Start des Elements (verifiziert).
- Pool-Test: Anfragen aus Python tragen bis zu 250 ms Weckverzug (verifiziert).
- AHK-Unit-Test: statische Konstanten einer Klasse zur Laufzeit ändern (verifiziert).
- Supervisor: Zustand eines Kindes vor `CreateProcessW` setzen, nicht danach (verifiziert; der Wettlauf selbst nicht deterministisch nachgestellt).
- Die Einträge "Worker crasht: nur der Supervisor sieht den Prozesstod" und "Ein frozen Prozess zeigt Ack-Timeout und Orphan-Frist" sind auf den neuen Stand gebracht.
