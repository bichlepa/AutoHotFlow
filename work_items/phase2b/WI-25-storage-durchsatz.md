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
