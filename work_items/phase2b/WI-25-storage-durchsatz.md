# WI-25 Storage: Log-Durchsatz und getrennte Warteschlangen (F-08)

Größe: M · Hängt ab von: – · Blockiert: –

## Ziel

Der Storage schreibt Logs schnell genug für echte Last, und Log-Zeilen können Dateianfragen nie verdrängen. Dazu zwei kleine Verbesserungen der Datensicherheit.

## Funde

- **F-08 [verifiziert im Verhalten]:** Der Storage schreibt rund 30 Logzeilen/s. Bei 290 Ereignissen/s wuchs er in 20 s von 17 auf 56 MB und schrieb danach noch 207 s nach (`work_items/phase2/WI-16-stress.md`, `doc/HOW-TO.md` "Storage schreibt das Log mit rund 30 Zeilen je Sekunde").
- **Ursache [vermutet, passt zu den Zahlen]:** `WriteQueue` führt eine Operation je Timer-Durchlauf aus (`SetTimer(..., -1)`), die Timer-Auflösung liegt bei rund 15,6 ms; je Logzeile zwei Operationen (`Log.txt` und `Log_<source>.txt`), jede öffnet und schließt die Datei und fragt die Größe ab. Das ergibt etwa 32 Zeilen/s.
- **Schwerer als bisher eingeordnet [gelesen]:** Logzeilen und Anfragen (`flow.read`, `flow.write`, `var.*`) teilen **eine** Warteschlange (`Storage._Defer` und `Storage._EnqueueLog` fügen beide in `this.queue` ein). Bei Rückstau warten Anfragen hinter tausenden Logzeilen und laufen in ihre Frist (Standard 30 s, `RunOne` beantwortet sie dann mit `timeout`). Ein Flow, der 100 Zeilen/s loggt, verhindert so das Speichern.
- **Temp-Dateien nach hartem Abbruch** (`*.ahf-<pid>.tmp`) werden nie aufgeräumt (STATUS, nicht geprüft).
- **`AtomicFile.Write`** ersetzt die Datei mit `MoveFileExW(REPLACE_EXISTING | WRITE_THROUGH)`, ohne die Temp-Datei vorher mit `FlushFileBuffers` auf die Platte zu bringen. Bei Stromausfall kann die Umbenennung vor den Daten auf der Platte landen (leere oder kaputte Datei). [gelesen, allgemeines Wissen zu NTFS]

## Aufgaben

1. **Zwei Warteschlangen:** Anfragen und Logzeilen getrennt. Anfragen haben Vorrang. Die Reihenfolge innerhalb jeder Warteschlange bleibt erhalten.
2. **Zeitbudget je Durchlauf:** Ein Durchlauf arbeitet so lange, bis ein Zeitbudget (Vorschlag 10 ms) verbraucht ist oder die Warteschlangen leer sind, nicht nur eine Operation. Eine einzelne große Operation (5-MB-Datei) bleibt eine Operation; die Anforderung "`sys.ping` unter 1 s während eines großen Schreibvorgangs" (WI-12) bleibt erfüllt.
3. **Logzeilen bündeln:** Alle wartenden Zeilen einer Datei in einem Zug schreiben (einmal öffnen, alle Zeilen, einmal schließen), Rotation (100 KB, `_old.txt`) vor dem Bündel prüfen; das Verhalten bei gesperrter Datei (F-04, Wiederholung bis 3 s) bleibt je Datei erhalten. Format der Zeilen unverändert (v1).
4. **Obergrenze:** Log-Warteschlange begrenzen (Vorschlag 20.000 Zeilen oder 8 MB). Bei Überlauf neue Zeilen verwerfen und zählen; sobald wieder Platz ist, eine Zeile "N log lines dropped" schreiben. Nie blockieren.
5. **Aufräumen beim Start:** `*.ahf-<pid>.tmp` in `Flows/` und `Variables/` (rekursiv) löschen, deren Prozess nicht mehr läuft.
6. **`FlushFileBuffers`** auf die Temp-Datei vor `MoveFileExW` (Handle der `FileOpen`-Datei, `file.Handle`).
7. **Dauerlauf anpassen:** `tests/stress/test_soak.py` hält heute wegen F-08 nur ~20 Ereignisse/s; die Rate anheben, soweit der neue Durchsatz es trägt.

## Tests

- Durchsatz: mindestens 1000 Zeilen/s über 10 s (Messung in `tests/stress/test_log_backlog.py` anpassen), RSS kehrt danach zurück.
- Vorrang: Während einer Log-Flut wird `cmd.storage.flow.read` in unter 1 s beantwortet.
- Obergrenze: Flut über der Grenze, Zähler und Zeile "dropped" erscheinen, Prozess bleibt stabil.
- Bestehende Tests zu F-04, Rotation, Format, atomarem Schreiben, 5-MB-Schreiben grün.
- Aufräumen: angelegte Temp-Datei mit nicht existierender PID ist nach dem Start weg, eine mit lebender PID bleibt.

## Doku

`doc/PROTOKOLL.md` 4.6 (Umsetzung Storage), `doc/HOW-TO.md` (Eintrag F-08 mit Ergebnis aktualisieren), `work_items/STATUS.md` (F-08 schließen, wenn erfüllt).


## Ergebnis

Stand: alle sieben Aufgaben abgeschlossen. Verifiziert heißt: gelaufen, mit Zahlen. Mess-Rechner: Windows 11, 8 logische CPUs, 23,9 GB RAM.

### Erledigt (Commits)

| Aufgabe | Commit | Beleg |
|---|---|---|
| 1 Zwei Warteschlangen, 2 Zeitbudget | `831c9e8` | AHK-Komponententests `storage_queue.test.ahk`: "requests overtake log operations, both keep their order", "a budget runs many small operations in one go", "a budget stops after the operation that used it up", "one big operation is never split", "a log retry waits for its delay while requests go on" (vorher rot, danach grün) |
| 3 Bündeln, 4 Obergrenze, 7 Dauerlauf | `41d1265` | `test_a_log_flood_is_written_at_more_than_1000_lines_per_second`, `test_a_request_is_answered_in_time_during_a_log_flood`, `test_a_flood_over_the_limit_drops_lines_counts_them_and_the_process_stays_up`, Stresstest `test_storage_writes_1500_log_lines_per_second_for_10_seconds`, angepasster `test_event_flood_keeps_the_engine_responsive...`; `test_soak.py` |
| 5 Aufräumen beim Start | `1e0f4d7` | `test_temp_files_of_dead_processes_are_removed_at_start_and_those_of_live_ones_stay` |
| 6 `FlushFileBuffers` | `bff8955` | alle Tests zum atomaren Schreiben und zum 5-MB-Schreiben grün; die Wirkung bei Stromausfall ist nicht prüfbar |

Dokumentation (`doc/PROTOKOLL.md` 4.6, `doc/HOW-TO.md`, `STATUS.md`, diese Datei) in einem eigenen Commit.

Die Tests wurden vor der Umsetzung rot gesehen (die vier Python-Tests und die fünf AHK-Fälle schlugen fehl). Der Test der Obergrenze musste umgebaut werden: der schnelle Storage kam dem Sender nach und erreichte die Grenze nie (erste Fassung: kein "dropped"). Er hält jetzt `Log.txt` mit einem fremden Prozess fest (wie im F-04-Test), dann füllt sich die Warteschlange deterministisch.

### Messwerte (vorher / nachher)

| Messung | Vorher (WI-16, HOW-TO) | Nachher |
|---|---|---|
| Logzeilen/s (Storage allein) | rund 28 bis 30 | 1493/s gesendet über 10 s (15000 Zeilen), Endmarker 0,1 s nach der letzten Zeile in beiden Dateien; 12000 Zeilen im Stoß: 3057 Zeilen/s einschließlich Sender (Sender 3,5 s, alles geschrieben nach 3,9 s), also durch den Sender begrenzt, der Höchstwert des Storage ist nicht gemessen |
| Flut mit 362 Ereignissen/s (905 Instanzen in 20 s) | Log stand erst 207 s nach dem Ende; RSS 17 auf 56 MB | Log 1 s nach dem Ende vollständig; RSS Storage 17,59 auf 18,05 MB, nach dem Abfluss 18,05 MB; Snapshot-Latenz der Engine Median 0,88 ms, p99 7,27 ms |
| `flow.read` während 15000 Zeilen Flut | wartet hinter der Flut (Frist 30 s) | 189, 99, 5, 3, 9 ms (der erste Wert enthält vermutlich den Verbindungsaufbau) |
| Dauerlauf (90 s) | rund 20 Ereignisse/s | rund 120 Ereignisse/s (4 Starts je 0,25 s, `AHF_SOAK_BURST`); keine Fehler, RSS und Handles flach (Storage 17,86 auf 17,93 MB), Snapshot-Latenz p99 11,5 ms; der 600-s-Lauf wurde nicht gemacht |

### Läufe

- Seriell `python -m pytest tests -q -n 0`: 573 passed, 1 skipped, 14 deselected in 396 s.
- Stress `python -m pytest tests -m stress -q`: 13 passed in 185 s.
- Parallel `python -m pytest tests -q`: 573 passed, 1 skipped in 59 s.
- `python tools/arch_check.py`: 64 Dateien, 0 Verstöße.
- Übrig nach den Läufen (nur angesehen): zwei AutoHotkey-Prozesse. PID 16348 ist ein fremdes Skript des Benutzers (`Allgemeine Hilfe.ahk`). PID 17332 ist `src/AutoHotFlow.ahk` und lief bei der Prüfung schon über 2 Stunden, also vor meinem Beginn; nicht angefasst.

### Begründung der Zahlen

- **Zeitbudget 10 ms:** Die Nachrichtenschleife wird erst zwischen Timer-Läufen bedient (`sys.ping`, neue Anfragen). Der Ping hat 1 s Frist (WI-12); 10 ms plus die letzte Operation (ein 5-MB-Schreiben, dessen Ping unter 1 s bleibt, Test in `test_storage.py`, grün) halten das mit großem Abstand ein. Die Auflösung von `SetTimer` (rund 15,6 ms) ist der Grund für die 30 Zeilen/s mit einer Operation je Lauf (vermutet, passt zu den Zahlen); mit dem Budget laufen in einem Lauf Hunderte kleiner Operationen. Gegen andere Werte (5, 20, 50 ms) nicht gemessen: nicht geprüft.
- **Obergrenze 20000 Einträge oder 8 MiB (Zeichen):** Ein Eintrag belegt rund 200 bis 400 Zeichen, 20000 Einträge also 4 bis 8 MiB Text; die Zeichenobergrenze greift erst bei langen Zeilen. Bei 1500 Zeilen/s Drainrate entspricht die Grenze einem Rückstau von über 13 s, genug für kurze Sperren (F-04: 3 s). Der Speicher bei voller Warteschlange wurde nicht gemessen (nicht geprüft; aus F-08: 56 MB bei einem Rückstau von mehreren tausend Einträgen). Gezählt wird in Einträgen (nicht Dateizeilen) und in Zeichen (nicht UTF-8-Bytes).
- **Bündel höchstens 500 Zeilen oder 64 K Zeichen:** begrenzt die Länge einer einzelnen Operation und die Überschreitung der Rotationsgrenze (100 KB, geprüft vor dem Bündel).

### Abweichungen

- Je Datei gibt es einen eigenen Puffer; über Dateien hinweg ist die Reihenfolge nicht mehr festgelegt (nur je Datei, nur das war nötig). `evt.log.entry` geht weiter nach dem Schreiben von `Log_<source>.txt`.
- Neue, in der WI nicht genannte Optionen `--log-queue-max-lines` und `--log-queue-max-chars` (für Tests; in `doc/PROTOKOLL.md` 4.6).
- Das Aufräumen der Temp-Dateien läuft als erste Logoperation nach dem Start, nicht vor `sys.hello`, damit große Datenverzeichnisse den Start nicht verzögern. Der Test wartet daher bis zu 10 s.
- Das Verwerfen von Logzeilen über der Grenze ist eine Verhaltensänderung gegenüber dem unbegrenzten Rückstau. Ob v1 eine Grenze hatte, habe ich nicht geprüft; daher kein Eintrag in `doc/MIGRATION.md`.
- Keine Änderungen in `src/core/`.

### Nicht geprüft

- Die Wirkung von `FlushFileBuffers` bei Stromausfall (nicht prüfbar), und ob `OpenProcess` mit "Zugriff verweigert" (Fehler 5) in der Praxis vorkommt.
- Die Kosten von bis zu 500 `Send`-Aufrufen (`evt.log.entry`) im `finish` eines Bündels: sie laufen im selben Timer-Lauf und können das Zeitbudget von 10 ms überschreiten. Die Ping-Latenz während der Flut wurde nicht gezielt gemessen (nur `flow.read`, unter 200 ms); vermutet unkritisch.
- Mehrere hundert verschiedene Quellen (je Quelle ein Puffer und eine Operation); geprüft nur mit 4 Quellen (F-04-Test).
- Der volle 600-s-Dauerlauf mit der neuen Rate.

### Neue Funde

- **F-25 (niedrig):** Ist eine Logdatei dauerhaft von einem anderen Prozess gesperrt, wartet der Storage 3 s und verwirft dann das ganze Bündel dieser Datei (bis 500 Zeilen), gezählt, höchstens 5 Zeilen einzeln im eigenen Log. Vorher ging eine Zeile je 3 s verloren, wobei die Warteschlange stand; jetzt ist der Verlust je Ereignis größer, der Stau kürzer. In `STATUS.md` übertragen.
- F-16 bis F-24 nicht doppelt angelegt (Übertragung nach STATUS in WI-29).

### Offene Punkte

- Soll die Obergrenze später eine Einstellung werden (Phase 3)? Entscheidung des Projektinhabers.
- Ping-Latenz während einer Flut gezielt messen, wenn der Manager echte Logs erzeugt (Phase 3).
