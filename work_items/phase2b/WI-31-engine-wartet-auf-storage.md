# WI-31 Engine wartet auf `storage` und setzt abgebrochenes Laden fort (F-31, F-24)

Größe: S · Hängt ab von: – · Blockiert: WI-32

## Ziel

Die Engine lädt ihre Flows immer, egal wie lange `storage` zum Start braucht, und auch, wenn `storage` während des Ladens neu startet. Kein unnötiges `evt.storage.error` beim normalen Start.

## Funde aus dem Review (2026-10-12)

- **Die Engine gibt nach ~2,5 s für immer auf [gelesen]:** `Engine._LoadFlows` fragt `cmd.storage.flows.list`. Ist `storage` noch nicht verbunden, antwortet der Hub `not_found`, die Engine wiederholt `LOAD_TRIES` (5) mal im Abstand von `LOAD_RETRY_MS` (500 ms) und loggt dann "flow list not loaded after 5 tries, engine stays not ready" (`_RetryLoad`). Danach lädt sie nie wieder.
- **F-24 [beobachtet in WI-24]:** Die Engine meldet sich beim Start oft vor `storage`; der erste `flows.list` endet mit `not_found`, dazu ein `evt.storage.error`.
- **F-31 [vermutet, passt]:** Im langen seriellen Gesamtlauf (Last auf dem Rechner) waren die Flows einmal je Lauf nach 20 s nicht geladen. Das passt zu einem Start von `storage`, der länger als ~2,5 s dauert. Beim nächsten Auftreten im Log nach der Zeile oben suchen.
- **Folge im Produkt:** Ein langsamer Start nach der Windows-Anmeldung (Virenscanner, viele Autostarts) kann AutoHotFlow ohne Flows hochfahren lassen.
- **Abgebrochenes Laden [gelesen]:** Seit WI-24 meldet die Engine nach einem `timeout`/`peer_gone` alle übrigen Dateien sofort als Fehler (`storageDown`). Startet `storage` danach neu, werden die fehlenden Flows nie mehr geladen.

## Aufgaben

1. **Zuerst rot zeigen:** Integrationstest, in dem `storage` 5 s nach der Engine startet: heute wird die Engine nie bereit. Zweiter Test: `storage` wird während des Ladens von 20 großen Flows (`tests/data/bigflows/`) beendet und neu gestartet: heute fehlen danach Flows.
2. **Auf `storage` warten:** Die Engine abonniert das Topic `process` immer (heute nur mit Worker-Pool) und beginnt das Laden, sobald `storage` bereit ist: `evt.process.ready` mit Name `storage`, oder beim eigenen Start über `cmd.process.list` (erst abonnieren, dann fragen, PROTOKOLL 5a). Ohne feste Obergrenze der Versuche; solange `storage` fehlt, kein `evt.storage.error` (F-24), höchstens eine `a1`-Logzeile je Zeitraum.
3. **Laden fortsetzen:** Bricht das Laden durch `timeout`/`peer_gone` ab, wartet die Engine wieder auf `storage` und lädt nur die noch fehlenden Dateien (die Liste neu holen, schon geladene Flows bleiben). `evt.engine.ready` erst, wenn jede Datei der Liste ein Ergebnis hat (geladen oder echter Datei- oder Parse-Fehler).
4. Die Staffelung aus WI-24 (`LOAD_PARALLEL`) bleibt.
5. Umschauen: Gibt es andere Stellen, die beim Start auf eine Rolle warten und mit fester Versuchszahl aufgeben (Stub, Debug-Rolle, `DiagReport`, Supervisor-Log)? Im Ergebnis auflisten, offensichtliche gleich mitbeheben.

## Akzeptanzkriterien

- Beide Tests aus Aufgabe 1 rot, dann grün.
- Normaler Start: kein `evt.storage.error` mehr (Test, der das prüft; den Filter für F-24 in den bestehenden Tests entfernen).
- F-24 in `STATUS.md` geschlossen, F-31 mit dem Ergebnis aktualisiert (geschlossen, wenn in WI-32 kein Fall mehr auftritt).

## Doku

`doc/ARCHITEKTUR.md` 6.1 (Start: die Engine wartet auf `storage`), `doc/PROTOKOLL.md` 4.3 (`evt.storage.error` nur für echte Fehler), `doc/HOW-TO.md` bei Bedarf.

## Ergebnis

Status: abgeschlossen (Aufgaben 1 bis 5). Alle Angaben unten sind gelaufen oder gelesen, sofern nicht als "nicht geprüft" oder "vermutet" markiert.

### Was geändert wurde

- `src/engine/Engine.ahk`: Die Engine abonniert das Topic `process` immer (vorher nur mit Pool) und wartet auf `storage`: `OnReady` fragt `cmd.process.list` (Frist 5 s); ist `storage` dort `ready`, beginnt das Laden. Sonst wird alle 1 s erneut gefragt (`STORAGE_POLL_MS`), ohne Obergrenze; `evt.process.ready` mit Name `storage` startet das Laden sofort. Logzeile `a1` "waiting for storage" höchstens alle 30 s (`WAIT_LOG_MS`). `LOAD_TRIES` und `_RetryLoad` sind entfallen.
- Abgebrochenes Laden: `timeout`, `peer_gone`, `shutting_down` und das `not_found "no peer ..."` des Hubs (`Engine._StorageGone`) sind keine Fehler mehr: Es wird keine weitere Datei angefragt, kein `evt.storage.error` gesendet, die Engine wartet wie am Start (nach einer Pause von 1 s, siehe unten) erneut auf `storage`, holt die Liste neu und liest nur Dateien ohne Ergebnis (`_doneFiles`: geladen oder echter Lese-/Parse-Fehler). `evt.engine.ready` erst, wenn jede Datei ein Ergebnis hat. Eine Liste, die aus anderem Grund fehlschlägt, wird ohne Obergrenze mit wachsender Pause (500 ms bis 5 s) wiederholt, jeweils mit `evt.storage.error`.
- `LOAD_PARALLEL` (WI-24) unverändert.
- `tests/support/pyhub.py`: Der Python-Hub antwortet auf `cmd.process.list` (verbundene Peers als `ready`) und veröffentlicht `evt.process.ready` beim `sys.hello`, wie der Supervisor.
- Tests: `tests/integration/test_engine.py` (neu: zwei Tests aus Aufgabe 1; umgeschrieben: `..._when_storage_has_stopped_answering`, siehe Abweichungen), `tests/stress/test_big_flows.py` (Filter für F-24 entfernt: jeder `evt.storage.error` zählt).
- Doku: `doc/ARCHITEKTUR.md` 6.1, `doc/PROTOKOLL.md` 4.3 (Tabelle und Umsetzung), `doc/HOW-TO.md` (neuer Eintrag "Warten auf eine Rolle").

### Belege

- Rot vor der Änderung (Engine unverändert, Tests und `pyhub` neu): `test_engine_waits_for_a_storage_that_starts_5_s_after_it_and_reports_no_error` rot, `test_engine_resumes_loading_when_storage_restarts_in_the_middle_and_loads_only_the_missing_files` rot (`evt.storage.error` kam, danach wurde nie nachgeladen).
- Grün nach der Änderung: beide Tests; `tests/integration/test_engine.py` gesamt **25 passed** (24 s).
- Ein Zwischenstand hat eine Schleife gezeigt: Der Test mit einem Storage, das jede Anfrage mit `peer_gone` beantwortet, zählte 1440 Leseversuche in 2,5 s, weil nach dem Abbruch sofort neu gefragt wurde und der (Test-)Hub `storage` weiter als `ready` meldet. Behoben durch die Pause von 1 s nach einem Abbruch (nur `evt.process.ready` startet sofort neu). Der Test prüft jetzt, dass nur die ersten zwei Dateien immer wieder angefragt werden und dass nach der Genesung alle 9 Flows geladen sind.
- Weitere Läufe, alle grün: `tests/test_architecture.py`, `tests/integration/test_storage.py`, `test_worker_pool.py`, `test_worker_busy.py`, `test_peer.py`, `test_role.py` zusammen **94 passed** (86 s). `tests/e2e`, `tests/fault/test_storage_abort.py`, `test_debug_role.py`, `test_snapshot.py`, `test_worker_lifecycle.py`, `test_process_crash.py`, `test_report.py`, `tests/stress/test_big_flows.py` (nur die nicht als `stress` markierten Größen), `tests/test_json_flows.py` zusammen **57 passed, 2 deselected** (189 s).
- Aufgabe 5 (Umschauen, gelesen): Der Stub-Manager (`StubManager.ahk`) wartet nicht mit fester Versuchszahl (Snapshot nach `evt.engine.ready`, bei Fehlschlag bei jedem Engine-Ereignis neu), die Debug-Rolle (`DebugView.ahk`) fragt einmal `cmd.process.list` und folgt den Ereignissen, `DiagReport` hält fertige Berichte bis `storage` meldet (ereignisgesteuert, Frist 10 s nur für die Zustellung), `DiagLog` (Supervisor-Log) puffert bis `storage` verbunden ist. Nichts davon gibt nach einer festen Zahl von Versuchen auf; nichts zu beheben. Das Peer-Wiederverbinden zum Hub hat ein eigenes Budget (`reconnectTotalMs`), das hier nicht berührt wurde.

### Abweichungen

- Der Test `test_engine_does_not_ask_for_more_files_when_storage_has_stopped_answering` (WI-24) prüfte, dass 9 Fehler gemeldet werden und die Engine bereit wird, obwohl nichts geladen ist. Das ist mit der Vorgabe dieses Pakets (warten statt als Fehler melden, `ready` erst nach Ergebnis jeder Datei) nicht vereinbar; er prüft jetzt das neue Verhalten (siehe oben). Die Aussage "nach dem ersten Transportfehler wird nichts weiter angefragt" bleibt, in der Form "nur die ersten zwei Dateien werden angefragt".
- Der Python-Hub der Tests ist erweitert (s. o.), weil die Engine jetzt beim Start `cmd.process.list` braucht; ohne Supervisor hätten die Engine-Tests nie geladen.

### Nicht geprüft

- Kein Lauf mit dem echten Supervisor und einem `storage`, das beim Start tatsächlich um mehrere Sekunden verzögert wird (Last durch Virenscanner o. Ä.). Der Test mit 5 s Verspätung nutzt den Python-Hub. Der echte Pfad (`Children.Snapshot` mit `state` "ready", `evt.process.ready` aus `Children.OnHello`) ist gelesen, die Fault-Tests mit Kette laufen grün.
- Kein vollständiger serieller Gesamtlauf (Auftrag: nur relevante Tests). F-31 bleibt daher offen, bis WI-32 keinen Fall mehr sieht.
- Zustandsname des Supervisors für `storage` nach einem Absturz (Neustart läuft): gelesen nur `ready` zählt; die Zwischenzustände wurden nicht einzeln getestet.

### Offene Punkte und Funde

- Keine neuen Funde (nächste freie Nummer bleibt F-34).
- Eine Rest-Verzögerung: Nach einem abgebrochenen Laden wartet die Engine mindestens 1 s, auch wenn `evt.process.ready` schon während des Abbruchs kam (das Ereignis wird ignoriert, solange Anfragen laufen). Kosmetisch, kein Datenverlust.
- F-24 in `STATUS.md` geschlossen, F-31 mit Ergebnis aktualisiert (offen bis WI-32).
