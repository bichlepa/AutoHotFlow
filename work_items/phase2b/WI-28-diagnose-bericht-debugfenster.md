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


## Ergebnis

Stand: 2026-10-12. Status: abgeschlossen (Schritte a bis f). Kennzeichnung: verifiziert = gelaufen oder gelesen, vermutet, nicht geprüft.

### Erledigt (Commits)

| Schritt | Commit |
|---|---|
| (a) Entwurf in PROTOKOLL 4.9 und ARCHITEKTUR 3, 4, 6.2, 8 | `d27d0ef` |
| (b) `cmd.diag.snapshot` in jeder Rolle (`Role.Snapshot`, `DiagInfo`) und im Supervisor | `32234b2` |
| (c) Absturzbericht: `cmd.diag.report`, `DiagReport`, `cmd.storage.report.write` (`ReportFiles`), automatische Berichte | `d35b5d7` |
| (d) `Debug.Dump` in `src/core/Debug.ahk` | `3e00b94` |
| (e) Rolle `debug` (`src/debugview/`), `--command=debug`, `--start=debug`, freiwilliges Ende ist kein Absturz | `b450a5c` (Hilfsänderung der Tests: `2b1f07e`) |
| (f) Tests je Punkt, Doku (HOW-TO, MIGRATION M-21, TESTSTRATEGIE) | in den Schrittcommits, `fec7d06` |

### Belege

- Neue Tests: `tests/fault/test_snapshot.py` (8), `test_report.py` (11), `test_debug_dump.py` (4), `test_debug_role.py` (11); AHK-Unit: `core_snapshot` (6), `diag_report` (15), `report_files` (6), `core_debug` (9). Erst rot gesehen: Snapshot der Engine (`KeyError: 'snapshot'`, Namenskollision `_CmdSnapshot`), `Debug.Dump` (4 rote Fälle, Schatten `role`), Wahrheitswert `export.ok = 1` (Wächter aus WI-26).
- Seriell `python -m pytest tests -q -n 0`: 704 passed, 1 skipped, **1 failed** in 593 s: `tests/fault/test_debug_role.py::test_the_role_starts_with_start_debug_and_shows_the_process_table` ("flows ['skeleton'] not loaded within 20.0 s", Supervisor-Ausgabe leer). Nicht wieder aufgetreten: 6 Einzelläufe und 25 Läufe mit `-n 4` grün. Ursache nicht geklärt (F-31).
- Stress `-m stress`: 13 passed in 195 s.
- Parallel (`-n auto`, 8 Worker): 705 passed, 1 skipped in 91 s. Ein erster paralleler Lauf (vor dem Schlussstand, mit den Schritten a bis c) hatte `tests/stress/test_clients_churn.py::...[smoke]` ("p99 201.26 ms" über 50 ms Budget, ein Ausreißer von 200 ms) und `test_a_hung_role_writes_a_report_by_itself` (Testfehler: Ordner vor Datei, behoben) rot; der Churn-Test war danach 3 von 3 einzeln grün (bekannte Lastempfindlichkeit, F-19/F-26-Familie). Ein zweiter paralleler Schlusslauf brach im Werkzeug mit `OSError: Invalid argument` ab (Ausgabe), nicht ausgewertet.
- Nach den Läufen: keine Prozesse mit `--session=t...` übrig. Ein `AutoHotkey64.exe ... AutoHotFlow.ahk` ohne Argumente (pid 17332) lief schon; er gehört nicht zu den Tests (nicht von mir gestartet).
- Messungen (`-s`): Bericht mit 5 Rollen unter 1 s; ein Bericht mit eingefrorener Rolle endet nach der Frist von 2 s, Grenze im Test 8 s.
- `tools/arch_check.py`: 0 Verstöße. `truncated` in `BOOL_FIELDS` und `WIRE_BOOL_RE` ergänzt.

### Handprüfung des Debug-Fensters (Projektinhaber)

Ich habe das Fenster mit `PrintWindow` fotografiert (alle fünf Tabs, Knopf "Bericht exportieren" und "Pause" per `BM_CLICK`, Schließen per `WM_CLOSE`: verifiziert, siehe HOW-TO). Nicht geprüft: echte Mausbedienung, Größenänderung des Fensters, Verhalten auf anderen DPI-Einstellungen, Dauerbetrieb mit "alle 2 s".

1. Starten: `AutoHotFlow.ahk --start=debug` (oder laufendes System und dann `AutoHotFlow.ahk --command=debug`). Das Fenster "AutoHotFlow - debug" erscheint. Ein zweites `--command=debug` startet kein zweites Fenster, es holt das vorhandene nach vorn.
2. Tab Prozesse: alle Rollen mit Zustand und PID. Beende von Hand einen Prozess; die Tabelle ändert sich binnen etwa einer Sekunde.
3. Tab Snapshots: "Aktualisieren", dann Rolle in der Liste wählen; formatiertes JSON. Haken "alle 2 s": Stand-Zeit oben im Text läuft weiter, Scroll- und Auswahlposition dürfen nicht springen (nur bei geändertem Text wird ersetzt).
4. Tab Log: Ebenenfilter und Quellenfilter ändern die Liste sofort; neue Zeilen erscheinen unten.
5. Tab Ereignisse: einen Flow starten; "Pause" hält die Liste an (Text "angehalten bei Nr ... neue Ereignisse wartend"), "Weiter" zeigt alles.
6. Tab Werte: `Debug.Dump(Map("a", 1), "test")` in einer Rolle aufrufen (z. B. temporär im Engine); Eintrag erscheint, Auswahl zeigt das JSON.
7. "Bericht exportieren": die Statuszeile nennt den Ordner `Reports/<Zeit>_manual`; dort liegen `report.json`, `summary.txt`, `Log.txt`.
8. Fenster schließen (X): nur das Fenster-Prozess endet; im Log des Supervisors steht kein "ended unexpectedly", es entsteht kein Bericht.
9. Nie ein Dialog, nie blockiert das Fenster die anderen Rollen.

### Abweichungen und Entscheidungen

- Versionsklasse heißt `AhfVersion` (`src/core/AhfVersion.ahk`), Snapshot-Basis `src/core/Snapshot.ahk`, `ProcInfo.ahk`. `Debug.ahk` in `core`, von `Role.ahk` eingebunden.
- `report.json` enthält Wahrheitswerte aus Kind-Snapshots als `1`/`0` (Json.Parse), die des Supervisors als `true`/`false`.
- Test-only Option `--report-wait=<ms>` (nur mit `--test-roles`) für die Wartezeit auf Storage.
- Der Hub kann jetzt `Deferred` (`Hub.Reply`). `Children.Open` startet auch einen beendeten Eintrag neu. Ein Kind mit `sys.bye {clean}` und Exit 0 gilt als `exited` (PROTOKOLL 4.1a).
- Automatische Berichte nur für unerwartetes Ende (`crashed`), Neustartgrenze, `hung` und 10 unbehandelte Fehler in 60 s (Schwelle 21 führt ohnehin zu Exit 6 und `crashed`).

### Neue Funde

- **F-31 (niedrig, nicht geklärt):** Einmal im seriellen Gesamtlauf: nach 20 s waren die Flows der Engine nicht geladen (`Chain.wait_flows`) im Test mit `--start=debug`; nicht wieder aufgetreten (31 Wiederholungen grün). Beim Wiederauftreten Supervisor-Log (`AHF_TEST_KEEP=1`) lesen. Nächste freie Nummer: F-32.
- Beobachtung: Der Bericht wird im Supervisor mit `Json.Stringify(…, 2)` gebaut (blockiert kurz, bei 5 Rollen unter 1 s gemessen). Bei sehr großen Snapshots wäre eine Aufteilung in Zeitscheiben nötig (nicht geprüft).
- F-28 (Worker-Log erreicht Storage nicht) bleibt offen, unverändert.

### Offene Punkte

- `STATUS.md` und `AGENTS.md` nachführen (WI-29): F-31, Rolle `debug`, Berichte.
- Tray-Menü und Manager als weitere Wege, das Debug-Fenster zu öffnen (später).
- Der Snapshot kennt keine Option für Inhalte (`content` ist reserviert und wird ignoriert).
