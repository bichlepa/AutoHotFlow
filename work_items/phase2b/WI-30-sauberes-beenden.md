# WI-30 Sauberes Beenden: keine letzte Nachricht geht verloren (F-26)

Größe: M · Hängt ab von: – · Blockiert: WI-33, WI-32

## Ziel

Was eine Rolle vor ihrem Ende sendet, kommt an: `sys.bye`, `evt.worker.done` "stopped", die letzten `evt.instance.ended`, die letzten Logzeilen, in Phase 3 die Variablen, die die Engine beim Beenden zum Storage schreibt (M-06). Der Supervisor bewertet ein Prozessende erst, wenn er alles gelesen hat, was das Kind geschrieben hat. Damit ist F-26 (`clean: false` bei sauberem Ende, rund 1 %) behoben.

## Funde aus dem Review (2026-10-12) [gelesen, Ursache vermutet, nicht nachgestellt]

**Ursache A, Seite der Rolle:** `Role._FinishShutdown` (`src/core/Role.ahk`) sendet `sys.bye` und ruft sofort `peer.Close()`, dann `ExitApp`. `PipeConnection.Close` → `_Teardown` ruft `CancelIoEx` (ein noch laufender Schreibvorgang wird abgebrochen) und verwirft die Warteschlange (`this._queue := []`, Kommentar "drops queued frames"). Konnte der Rahmen nicht sofort geschrieben werden (Puffer der Pipe voll, oder es warten schon Rahmen davor), geht das `bye` verloren und alles, was davor in der Warteschlange stand. Betroffen sind laut STATUS genau die gesprächigen Rollen (`manager`-Stub protokolliert jedes Ereignis, `storage` verteilt Logzeilen an das Topic `log`). Dasselbe Muster: `Worker.OnShutdown` sendet `evt.worker.done` "stopped" kurz vor dem `bye`; `Engine.OnShutdown` erzeugt mit `StopAll` viele Ereignisse; `Role._Exit` schließt ebenfalls sofort.

**Ursache B, Seite des Supervisors:** `Supervisor._Tick` ruft seit F-11 `hub.Pump()` vor `children.Tick`. Läuft in diesem Moment aber bereits eine `Pump` derselben Verbindung (der Tick-Timer hat einen Pump-Thread des Weckrufs unterbrochen), setzt die Sperre in `PipeConnection.Pump` nur `_pumpAgain` und kehrt sofort zurück. `Children._OnGone` bewertet dann `rec["bye"]`, bevor das `bye` gelesen ist. Der deterministische Test aus WI-22 (`tests/ahk/supervisor_tick.test.ahk`) deckt diesen Fall nicht ab.

Welche der beiden Ursachen F-26 in den Läufen erzeugt hat, ist offen. Beide werden behoben.

## Aufgaben

1. **Zuerst rot zeigen**, je Ursache ein Test:
   - A: Auf Ebene `PipeConnection` (AHK-Unit oder Integration mit einer Python-Gegenstelle aus `tests/integration/helpers/rawpipe.py`, die langsam oder erst später liest): Viele Rahmen senden, dann schließen; der letzte Rahmen muss ankommen. Heute geht er verloren.
   - B: Erweiterung von `tests/ahk/supervisor_tick.test.ahk` oder ein eigener Test: Prozessende wird bewertet, während eine Pump der Verbindung läuft (simuliert über den Zustand `_pumping`); `clean` muss stimmen.
2. **Leeren vor dem Schließen (Ursache A):** `PipeConnection` bekommt einen Abschluss, der keine neuen Rahmen mehr annimmt, die Warteschlange weiter über Timer schreibt und erst schließt, wenn sie leer ist oder eine Frist abgelaufen ist (z. B. `CloseWhenFlushed(timeoutMs, onDone)`). Nie blockierend (kein `FlushFileBuffers` auf der Pipe, das wartet ohne Frist auf den Leser).
3. **Rollen nutzen es:** `Role._FinishShutdown` sendet `bye`, schließt dann über den neuen Abschluss und ruft `ExitApp` im Rückruf (Frist: Rest der Shutdown-Frist, höchstens z. B. 1000 ms; Begründung im Code). Für `Role._Exit` prüfen, ob dasselbe sinnvoll ist (bei Hub-Verlust gibt es nichts zu leeren). `Storage._FinishShutdown` (eigene Variante) entsprechend.
4. **Supervisor bewertet erst nach dem letzten Byte (Ursache B):** Ein Prozessende wird erst ausgewertet, wenn die Verbindung des Kindes geschlossen ist (`onLinkLost`, das kommt erst nach dem Lesen bis zum Ende der Pipe), oder nach einer kurzen Nachfrist ab Prozessende (Vorschlag 500 ms), falls das Kind nie verbunden war oder die Verbindung nicht endet. Bis dahin bleibt der Zustand unverändert; die Zeit bis zur Meldung `evt.process.exited`/`crashed` wächst um höchstens die Nachfrist. Prüfen, dass die Fristen des Beendens (`Shutdown`) und der Neustart davon nicht verzögert werden, außer um diese Nachfrist.
5. Test aus WI-22/WI-18 (`test_shutdown.py`) **100-mal** wiederholen (`AHF_FAULT_REPEAT`), ohne `clean: false`. Zusätzlich ein Test: Engine mit vielen laufenden Instanzen beenden, jedes `evt.instance.ended` kommt beim Beobachter an; Worker mit laufendem Job beenden, `evt.worker.done` "stopped" kommt bei der Engine an.

## Akzeptanzkriterien

- Die Tests aus Aufgabe 1 waren rot und sind grün.
- 100 Wiederholungen von `test_shutdown.py` ohne `clean: false`; F-26 in `STATUS.md` geschlossen (mit Zahl).
- Gesamtlauf parallel und seriell grün (bekannte wackelnde Tests aus WI-32 ausgenommen, im Ergebnis benannt).

## Doku

`doc/ARCHITEKTUR.md` 6.3 (Beenden: Rolle leert vor dem Ende, Supervisor bewertet nach dem letzten Byte), `doc/PROTOKOLL.md` 4.1 (`sys.bye`, Zeitpunkt von `evt.process.exited`), `doc/HOW-TO.md` (Eintrag: "Close verwirft die Warteschlange", "Sperre gegen Wiedereintritt macht 'erst pumpen' wirkungslos").

## Ergebnis

Status: Aufgaben 1 bis 5 abgeschlossen, Ursachen A und B behoben, dazu eine dritte Ursache C gefunden und behoben (2026-10-12). Keine Eskalation. Kennzeichnung: **verifiziert** = gelaufen oder gelesen, **vermutet**, **nicht geprüft**.

Commits: `7b1da26` (A, `PipeConnection.CloseWhenFlushed`), `29b3635` (A, Rollen leeren vor dem Ende; Tests aus Aufgabe 5), `cdee87f` (B, Supervisor bewertet nach dem letzten Byte), `598e0fd` (C, Schreibfehler an gegangene Gegenseite), dazu der Abschluss-Commit (diese Datei, `STATUS.md`, Haken).

### Ursache A: die Rolle verwarf ihre Sendewarteschlange [verifiziert, rot dann grün]

- `PipeConnection.CloseWhenFlushed(timeoutMs, onDone)`: keine neuen Rahmen, ein Timer (10 ms) schreibt die Warteschlange weiter, geschlossen wird bei leerer Warteschlange, bei Fristablauf (Rest verworfen, Log `a1`) oder bei einem Fehler. `onDone(flushed)` genau einmal aus dem Timer, nie im Aufruf. Kein `FlushFileBuffers`, keine Schleife ohne Frist. `Peer.CloseWhenFlushed` trennt die Verbindung vorher vom Peer (ihr Ende startet keinen Wiederaufbau). `Role._FinishShutdown` sendet `sys.bye` und endet über `_EndProcess`: `ExitApp` im Rückruf, Frist = Rest der Frist aus `sys.shutdown`, begrenzt auf 50 bis 1000 ms (`FLUSH_MIN_MS`, `FLUSH_MAX_MS`, Begründung im Code), dazu ein Notfall-Timer (Frist + 1 s). Ohne `sys.shutdown` (das Debug-Fenster schließt selbst) 1000 ms.
- `Role._Exit`: bei Hub-Verlust (Peer nicht `ready`) sofort wie bisher, es gibt nichts zu leeren; mit verbundenem Peer (Exit 6, zu viele Fehler) leeren mit höchstens 500 ms (`EXIT_FLUSH_MS`), damit das letzte `evt.diag.error` ankommt.
- `Storage._FinishShutdown`: keine Änderung nötig, es endet über `super._FinishShutdown()` und nutzt damit den neuen Abschluss; seine Marge von 500 ms vor der Frist wird zur Leerzeit [gelesen]. Engine und Worker: keine Änderung (sie senden über denselben Peer vor dem `bye`).
- Rote Tests (vor der Änderung):
  - `tests/integration/test_pipe.py::test_frames_queued_when_the_connection_is_ended_reach_a_late_reader`: 16 von 101 Rahmen, `last` fehlte (Testserver mit `Close`). Grün mit `CloseWhenFlushed`.
  - `tests/integration/test_role.py::test_frames_queued_at_shutdown_and_the_bye_reach_a_hub_that_reads_late` (Hub `StallingHub` liest 0,6 s nichts, 800 Pings füllen die Pipe): 572 von 800 Pongs, kein `sys.bye`. Grün.
- Neu, nur grün (neues Verhalten): `test_ending_after_the_queue_is_written_gives_up_at_its_deadline_and_does_not_block` (Leser liest nie: aufgegeben nach 308 ms bei 300 ms Frist, der Server bedient währenddessen andere Clients).

### Ursache B: Bewertung während einer unterbrochenen Pump [verifiziert, rot dann grün]

- `Children.Tick`: Ein beendeter Prozess wird erst bewertet, wenn `hub.HasLink(name)` falsch ist (der Hub hat die Verbindung bis zum Ende gelesen), oder `EXIT_GRACE_MS` (500 ms) nach dem ersten Sehen des Endes (`_ExitReadable`, Log `a1` beim Ablauf). In dieser Zeit greift `MarkHung` nicht, und `Terminate` beendet ein schon beendetes Kind nicht und zählt es nicht als getötet (prüft `WaitForSingleObject`).
- Roter Test: `tests/ahk/supervisor_tick.test.ahk`, Fall "Tick: an exit is not judged while another pump still reads the connection of the child (F-26, WI-30)" (Attrappe: `Pump` bei laufender Pump setzt nur "nochmal", wie `PipeConnection`): vorher "expected 0 but got 1" (bewertet, `clean` falsch). Grün. Neu und grün: Nachfrist, Kind ohne Verbindung sofort, "nicht hängend, nicht getötet".
- Fristen: `evt.process.exited`/`crashed`, das Ende einer Gruppe beim Beenden (ohne `sys.bye`) und ein Neustart verzögern sich höchstens um die Nachfrist [gelesen]; im Normalfall liest die Pump am Anfang desselben Ticks das Ende. `test_shutdown.py` (Budget 2 s) blieb in 400 Läufen im Budget [verifiziert]. Randfall siehe F-33.

### Ursache C (neu): Schreibfehler an eine gegangene Gegenseite [verifiziert, rot dann grün]

- Befund: Nach A und B lief `test_shutdown.py` mit `AHF_FAULT_REPEAT=100` (`-n 4`): **399 von 400**, einmal `manager` `clean: false` (`test_healthy_session...[0]`), ohne Log. Aus dem Code [gelesen]: Schreibt der Hub an ein Kind, das sich schon beendet hat (Topic-Ereignis; der Stub abonniert `log`, `process`, `engine`), scheitert `WriteFile` mit 232, `SendFrame` ruft `_Fail`/`_Teardown`; das bricht das Lesen ab und verwirft das noch ungelesene `sys.bye`. Kein Architekturthema, Korrektur in `PipeConnection` (in WI-30 erlaubt).
- Korrektur: Fehler 109/232/233 beim Schreiben schließen nur die Schreibseite (`_WriteSideGone`: Warteschlange verworfen, `SendFrame` liefert `false`); gelesen wird bis zum Ende des Datenstroms (`peer_closed`), höchstens 1 s (`WRITE_GONE_MAX_MS`, von `Pump` geprüft). `CloseWhenFlushed` meldet dann `flushed` falsch.
- Roter Test: `test_pipe.py::test_frames_of_a_peer_that_has_gone_are_read_although_a_write_to_it_fails`: vorher "poke" an den gegangenen Client gescheitert (`wasOpen 1, ok 0`), Verbindung `peer_closed`, die schon geschriebene `note` nie geliefert. Grün. Der Test wiederholt bis zu fünfmal, falls der Fallback-Timer des Servers das Ende zuerst liest (dann `skip`, keine Aussage).
- Dass C den einen roten Lauf erzeugte, ist **vermutet** (passt zu "manager und storage", nicht im Log nachgewiesen).

### Aufgabe 5: Läufe [verifiziert]

- `AHF_FAULT_REPEAT=100 python -m pytest tests/fault/test_shutdown.py -n 4` nach A, B und C: **400 passed** in 342 s. Keine Zeitprüfung scheiterte, also wurde `clean` in allen 100 Runden von `healthy_session...` (3 Rollen) und `frozen_storage...` (2 Rollen) geprüft und war wahr. Vorher (nur A und B): 399 von 400 (siehe C). Ein Zwischenlauf (healthy und frozen je 100, 200 passed) ist **kein Beleg**: während er lief, wurde `PipeConnection` geändert, spätere Tests liefen schon mit C.
- Engine mit vielen Instanzen: `test_engine.py::test_shutdown_with_many_instances_and_a_hub_that_reads_late_delivers_every_ended` (40 Instanzen, Hub liest 0,6 s nichts): alle 40 `evt.instance.ended` (`reason` `shutdown`), dann `sys.bye`. Gegenprobe mit der alten `Role.ahk`: **0 von 40**.
- Worker mit Job: `test_worker.py::test_shutdown_with_a_job_and_a_hub_that_reads_late_still_delivers_stopped_and_bye`: `evt.worker.done` "stopped" vor `sys.bye`. Gegenprobe mit der alten `Role.ahk`: kein `evt.worker.done`.
- Weitere Tests (Endstand nach C, parallel): `tests/integration/test_pipe.py`, `test_peer.py`, `test_role.py`, `test_supervisor.py`, `test_storage.py`, `test_engine.py`, `test_worker.py`, `test_worker_busy.py`, `test_worker_pool.py`, `tests/test_architecture.py`, `tests/fault/test_process_crash.py`, `test_pipe_break.py`, `test_orphans.py`, `test_diagnose.py`, `test_debug_role.py`, `test_process_hang.py`, `test_report.py`: **224 passed**. AHK-Unit-Tests `supervisor_tick`, `children_output`, `diag_report`: **40 passed**. `tools/arch_check.py`: 0 Verstöße. Ein früherer Teil-Lauf (vor C, 141 Tests) hatte einen roten Durchsatztest (F-32), einzeln seriell grün.
- Nach den Läufen keine Testprozesse übrig (angesehen; nur `AutoHotkeyU32.exe` "Allgemeine Hilfe" und ein Python-LSP des Projektinhabers).

### Nicht geprüft

- **Gesamtlauf parallel und seriell** (Akzeptanzkriterium 3): nicht gelaufen (laut Auftrag macht das ein eigener Agent, WI-32).
- `tests/fault` vollständig mit Wiederholungen: nicht gelaufen; nur `test_shutdown.py` (100-mal) und die oben genannten Dateien einmal.
- Exit 6 mit Leeren (`_Exit` mit verbundenem Peer): nur über die bestehenden Tests in `test_diagnose.py` (grün), kein eigener Test, dass das letzte `evt.diag.error` jetzt ankommt.
- Der Fall "Verbindung endet nicht, Nachfrist läuft ab" im echten Supervisor: nur Unit-Test.

### Abweichungen vom Plan

- Dritte Ursache C mit eigenem Commit (im Paket nicht beschrieben, gleiche Wirkung "letzte Rahmen gehen verloren"; ohne sie wären 100 Wiederholungen nicht grün gewesen).
- Aufgabe 1 A zusätzlich auf Ebene der Rolle, mit `StallingHub` in `test_role.py`; Engine- und Worker-Test nutzen ihn auch.
- Die rote Fassung des Pipe-Tests lief mit `Close()` im Testserver, die grüne mit `CloseWhenFlushed` (den Aufruf gab es vorher nicht).
- Jeder Ursachen-Commit enthält seine Doku; die Doku wurde dafür vorübergehend auf den Stand des jeweiligen Commits gebracht.

### Doku

- `doc/ARCHITEKTUR.md` 6.3: "Die Rolle leert vor dem Ende", "Der Supervisor bewertet nach dem letzten Byte" (mit Ursache C).
- `doc/PROTOKOLL.md` 4.1: `sys.bye` ist die letzte Nachricht, Schließen nach dem Leeren; 4.1a: Zeitpunkt von `evt.process.exited`/`crashed` (bis 500 ms nach dem Prozessende).
- `doc/HOW-TO.md`: neu "Close verwirft die Warteschlange", "Sperre gegen Wiedereintritt macht 'erst pumpen' wirkungslos", "Ein Schreibfehler an eine gegangene Gegenseite verwarf deren ungelesene letzte Rahmen" (je verifiziert, Ursache der früheren Ausfälle vermutet); korrigiert "sys.shutdown: Verbindung nicht im Rahmen-Handler schließen" und "Supervisor: sys.bye konnte nach dem Prozessende gelesen werden".
- `.vscode/tasks.json`: keine neue Aufrufart, keine Änderung.

### Neue Funde (in `STATUS.md`)

- **F-32**: Durchsatztest `test_a_log_flood_is_written_at_more_than_1000_lines_per_second` einmal rot unter Parallellast (808 Zeilen/s), seriell 3138 Zeilen/s. Zeitempfindlich, für WI-32.
- **F-33**: `Shutdown` meldet nach Fristablauf Exit 5, auch wenn kein Prozess hart beendet wird [gelesen]; mit der Nachfrist kann ein beendetes, noch unbewertetes Kind das genau an der Frist auslösen. Nicht beobachtet. Vorschlag für WI-33: in der Kill-Phase nach `children.AnyKilled()` entscheiden.
- F-26 in `STATUS.md` geschlossen (400 von 400).

### Offene Punkte

- Änderungen in `src/core/`: `PipeConnection.ahk` und `Role.ahk` (vom Paket genannt), dazu **`ipc/Peer.ahk`** (`CloseWhenFlushed`; nötig, damit die Rolle ohne Wiederaufbau leeren kann). Bitte im Review bestätigen.
- Während des Leerens (bis 1 s) laufen die Timer der Rolle weiter, ihre Sendungen werden abgewiesen (`droppedSends`). Für Phase 3 (M-06, Variablen beim Beenden an `storage`) heißt das: diese Nachrichten müssen vor dem `sys.bye` gesendet sein.
- Für "100-mal `test_shutdown.py`" gibt es keinen VS-Code-Task (Umgebungsvariable `AHF_FAULT_REPEAT`); bei Bedarf in WI-32 ergänzen.
