# WI-28 Diagnose II: Snapshot, Absturzbericht, Debug-Fenster

Größe: L · Hängt ab von: WI-23 · Blockiert: –

## Ziel

Wunsch des Projektinhabers: eine Funktion für **Absturzberichte** mit allen relevanten Informationen, und ein **Debug-Fenster**, das man bei Bedarf öffnet. Es zeigt interne Informationen, ähnlich der v1-Funktion `d()` (`v1/Source_Common/Debug/Debug.ahk`), aber schöner, und hat eine Exportfunktion, die praktisch dem Absturzbericht entspricht. Beides hilft in Phase 3 sofort beim Port der Elemente.

Abgrenzung: Das ist **kein** Flow-Debugger (Pause, Breakpoints, Variablen ändern, E1). Der kommt später. Dieses Paket betrifft die Diagnose des Systems.

## Bausteine

### 1. `cmd.diag.snapshot` (jede Rolle, Basisklasse `Role`)

Antwort mit einem allgemeinen Teil, den `Role` liefert:
- Name, Rolle, PID, Startzeit, Laufzeit, Version (eine Versionskonstante einführen, falls es keine gibt), AHK-Version (`A_AhkVersion`), 64 Bit.
- RSS und Handle-Zahl des eigenen Prozesses (`GetProcessMemoryInfo`, `GetProcessHandleCount`).
- Peer-Zähler: `status`, `PendingCount`, `lateReplies`, `badFrames`, `droppedSends`, Warteschlange der Verbindung (`QueuedFrames`, `QueuedBytes`), `handlerErrors`.
- Log: `LogStats()`, `Log.sinkErrors`, Ringpuffer der letzten Einträge (WI-23).
- Die letzten unbehandelten Fehler mit Stack (WI-23).

Plus ein rollenspezifischer Teil über einen Haken `DiagInfo()`:
- Engine: geladene Flows (Id, Name, rev), Instanzen und Threads mit Zustand und aktuellem Element, Worker-Slots, `seq`, `epoch`.
- Storage: Länge der Warteschlangen, verlorene und verworfene Logzeilen.
- Worker: aktueller Job (Klasse, seit wann).
- Manager-Stub: abonnierte Topics, letzte `seq`.

Der Supervisor beantwortet `cmd.diag.snapshot` an `supervisor` selbst: Prozesstabelle mit Neustarthistorie und Exit-Codes, Hub-Verbindungen mit Warteschlangen, `droppedAnswers`, Ringpuffer von `evt.diag.error` und stderr je Kind (WI-23), die letzten Ereignisse des Topics `process`.

**Keine Inhalte von Variablen und Flows** im Snapshot (nur Namen, Ids, Zustände), außer auf ausdrückliche Anfrage (Option im Befehl, später für den Flow-Debugger).

### 2. Absturzbericht `cmd.diag.report {reason}` an `supervisor`

- Der Supervisor fragt alle lebenden Rollen nach `cmd.diag.snapshot` (Frist je Rolle, z. B. 2 s; fehlende Antworten werden im Bericht vermerkt, nie gewartet ohne Frist), fügt seinen eigenen Snapshot und die Puffer verstorbener Kinder hinzu und schickt das Ganze an `storage`.
- Neuer Storage-Befehl, z. B. `cmd.storage.report.write {name, files: {datei: text}}` → schreibt nach `Reports/<yyyyMMdd-HHmmss>_<reason>/` (JSON und eine lesbare Zusammenfassung als Text), dazu Kopien der letzten Logdateien. Antwort mit dem Pfad. Höchstens 20 Berichte aufbewahren.
- **Automatisch** bei: unerwartetem Ende eines Kindes (`crashed`), erreichter Neustartgrenze, `hung`, Schwelle unbehandelter Fehler (WI-23). Ratenbegrenzung (z. B. höchstens ein automatischer Bericht je Minute).
- Ist `storage` selbst abgestürzt, wartet der Bericht auf den neu gestarteten Storage (mit Frist); gelingt das nicht, bleibt er im Speicher des Supervisors und wird beim nächsten Mal mitgeschrieben. Der Supervisor schreibt nie selbst Dateien.

### 3. Debug-Fenster (neue UI-Rolle `debug`)

- Eigener Prozess wie der Manager-Stub (Ordner z. B. `src/debugview/`), nie modal, kein `MsgBox`.
- Inhalte: Prozesstabelle (live über Topic `process` plus `cmd.process.list`), Snapshot je Rolle (Baum oder formatierter Text, Knopf "aktualisieren", optional automatisch alle 2 s), Live-Log mit Levelfilter und Quellenfilter (Topic `log`), Ereignisstrom der Engine (Topics `engine`, `flow:*`) mit Pause-Knopf, Knopf **"Bericht exportieren"** (`cmd.diag.report {reason: "manual"}`, zeigt den Pfad).
- Öffnen: über die zweite Instanz `AutoHotFlow.ahk --command=debug` (heute protokolliert `cmd.app.command` nur, `debug` wird der erste echte Befehl: der Supervisor startet die Rolle, falls sie nicht läuft) und mit `--start=debug`. Später zusätzlich Tray-Menü und Manager.
- Ersatz für v1-`d()`: `Debug.Dump(value, title := "")` in `src/core/` sendet `evt.debug.dump` an das Topic `debug` (blockiert nie, tut nichts, wenn niemand abonniert hat). Das Debug-Fenster zeigt die Werte als lesbares JSON.
- Ein Modus `--headless` für Tests (wie beim Stub): keine GUI, Befehle über einen Testbefehl.

## Tests

- `cmd.diag.snapshot` jeder Rolle liefert den allgemeinen Teil und den Rollenteil (Schema geprüft).
- Bericht mit allen Rollen: Verzeichnis entsteht, enthält je Rolle einen Eintrag, Zusammenfassung lesbar.
- Bericht mit eingefrorener Rolle: fertig binnen Frist, Rolle als "keine Antwort" markiert.
- Automatischer Bericht nach Absturz (`crasher`), Ratenbegrenzung greift.
- `--command=debug` startet die Rolle (headless), zweiter Aufruf startet keine zweite.
- `Debug.Dump` ohne Abonnenten blockiert nicht und wirft nicht.
- GUI: **Prüfung von Hand durch den Projektinhaber**, Anleitung im Ergebnis-Abschnitt (wie bei WI-13).

## Doku

`doc/PROTOKOLL.md` (alle neuen Befehle und Ereignisse, Topic `debug`, Rolle `debug`), `doc/ARCHITEKTUR.md` 3 (Rolle `debug`), 4 (Besitz der Diagnosedaten), 6.2 (automatischer Bericht), `doc/HOW-TO.md`.
