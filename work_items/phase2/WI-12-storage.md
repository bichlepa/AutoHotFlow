# WI-12 Storage-Rolle (Skeleton)

Größe: M · Hängt ab von: WI-06 · Blockiert: WI-10 (Integration), WI-15

## Ziel

Der einzige Prozess, der Dateien anfasst. In Phase 2: Flows lesen/schreiben (atomar), Variablen schreiben/lesen, Log-Senke, mit Warteschlange und Quittungen.

## Vorher lesen

`doc/ARCHITEKTUR.md` D7, 4, 6.3, 7, `doc/PROTOKOLL.md` 4.6, `v1/Source_Common/Flows/Save.ahk` (Backup-Verhalten, ab Zeile 123), `v1/Source_Common/Debug/Logger.ahk`, `v1/Source_Common/Variables/Global variables.ahk` (Dateiformat der Variablen).

## Zu erstellen (`src/storage/`)

- `Storage.ahk` (Rolle `storage`):
  - Datenverzeichnis aus `--data`. Unterordner wie v1: `Flows/` (v1: `Saved Flows`), `Variables/`, `Log/`.
  - `WriteQueue.ahk`: serielle Warteschlange der Dateioperationen. Ein Schreibvorgang pro Tick-Scheibe, damit `sys.ping` und neue Anfragen beantwortet werden (große Dateien in Blöcken). Jede Operation hat Frist und liefert Quittung.
  - `FlowFiles.ahk`: `list`, `read`, `write` mit **atomarem** Schreiben (Temp-Datei im selben Ordner, `MoveFileEx` mit `REPLACE_EXISTING`) und v1-Backup (`backup/`-Ordner, Dateiname `<Name>_backup_<timestamp>.json`, höchstens 10).
  - `VarFiles.ahk`: `.ahfvd`/`.ahfvar` lesen, schreiben, löschen, auflisten (global und je Flow-ID), Format wie v1.
  - `LogSink.ahk`: Handler `evt.log.append` (ohne Antwort), schreibt `Log/Log.txt` und `Log/Log_<source>.txt` im v1-Format (`--- <timestamp> ~<thread>~<source>~ <text>`), Rotation bei > 100 KB zu `_old.txt` wie `log_cleanup`. Leitet jeden Eintrag zusätzlich an das Topic `log`.
  - Fehler: `res` mit `ok:false` und `error.code`, zusätzlich `evt.storage.error` an die Engine.
- Beenden: `sys.shutdown` → Warteschlange leeren (bis Frist), `sys.bye`.

## Akzeptanzkriterien

- Schreiben ist atomar: Wird der Prozess während `write` hart beendet (Test), ist die Zieldatei entweder alt oder neu, nie halb.
- Große Datei (5 MB) schreiben, während Anfragen eingehen: `sys.ping` wird in unter 1 s beantwortet.
- Variablen: Round-Trip für Strings, Zahlen, Objekte, Sonderzeichen (UTF-8) gegen vorhandene Beispiele aus `v1/AppData/Variables/` (Lesen) und Neuerzeugung (Schreiben, Vergleich der JSON-Struktur).
- Backups: 12 Schreibvorgänge hinterlassen genau 10 Backups.
- Log-Format entspricht v1 (Regressionstest gegen eine Beispielzeile).
- Kein `MsgBox`, keine Ausnahme verlässt den Handler.

## Tests

`tests/integration/test_storage.py` (Python-Hub, Vergleich der Dateien auf der Platte).

## Nicht Teil

Einstellungsdatei (`cmd.storage.settings.*`, Phase 3), `.ahf`-Export/Import.

## Hinweise

- **v1-Backup ist faktisch wirkungslos** (geprüft in `Save.ahk:124-126`): `Filemove` verschiebt `<name>.txt`, nicht `<name>.json`. Der Ordner `backup` bleibt leer. v2 soll Backups tatsächlich anlegen (Kopie der vorherigen `.json` vor dem atomaren Ersetzen, höchstens 10). Das ist in `doc/MIGRATION.md` (M-07) eingetragen.
- v1 speichert mit `FileDelete` + `FileAppend` (nicht atomar, `Save.ahk:145-146`). Ein Absturz dazwischen verliert die Datei. v2: Temp-Datei + Ersetzen.
- Pfade mit Leerzeichen und Umlauten testen (`Flow 1010290492`).
- `FileOpen` mit `UTF-8-RAW` für Flows (kein BOM, wie v1).

## Ergebnis

Stand: WI-12 umgesetzt, alle Akzeptanzkriterien grün. Commits mit Präfix `WI-12:` (`git log --oneline`). Gesamtlauf `python -m pytest tests -q`: `396 passed, 1 skipped in 161.48s`, Exit 0. Der Skip ist der bestehende AHK-seitige Skip in `tests/test_ahk_runner.py` (`selfcheck.test.ahk`, gewollt). Einzelne Läufe vor dem Gesamtlauf waren rot und sind behoben (Testfehler, siehe Commits).

**Akzeptanzkriterien:**

| Kriterium | Ergebnis | Beleg (`tests/integration/test_storage.py`, wenn nicht anders angegeben) |
|---|---|---|
| Atomar: harter Abbruch während `write`, Datei alt oder neu, nie halb | erfüllt (3 Runden) | `test_hard_kill_during_a_big_write_leaves_old_or_new_file_never_a_half_one`. Nicht sicher: ob der Abbruch jeweils mitten im Schreiben traf. |
| 5-MB-Datei, `sys.ping` unter 1 s während Anfragen | erfüllt | `test_big_write_does_not_stop_the_ping`: gemessen 0,333 s (erster Ping, enthält das Senden des 5-MB-Rahmens), dann 0,031 s und 0,015 s |
| Variablen: Round-Trip Strings, Zahlen, Objekte, UTF-8 | erfüllt | `test_v1_variables_are_read_as_stored` (Lesen aus `v1/AppData/Variables`), `test_variable_round_trip_for_strings_numbers_objects_and_utf8` (Schreiben, Vergleich der JSON-Struktur und der Bytes) |
| Backups: 12 Schreibvorgänge, genau 10 Backups | erfüllt | `test_backups_keep_exactly_ten_after_twelve_writes` (neuestes Backup = Stand vor dem letzten Schreiben) |
| Log-Format wie v1 | erfüllt | `test_log_line_has_the_v1_format_and_goes_to_the_log_topic` (Regex aus dem Format der v1-Logzeile, lokale Zeit, Weiterleitung an Topic `log`), `test_log_file_over_100_kb_is_renamed_to_old_before_the_next_entry` |
| Kein `MsgBox`, keine Ausnahme verlässt den Handler | erfüllt (Prüfung im Code und Fehlerfälle) | `test_read_only_target_fails_with_error_event_and_keeps_the_old_file` (`internal`), `test_bad_flow_paths_are_rejected_before_any_file_access`, `test_flow_write_rejects_text_that_is_not_a_json_object`; Warteschlange fängt jeden Lauf und jede Antwort ab (`tests/ahk/storage_queue.test.ahk`) |
| Fehler als `res` mit `error.code` und `evt.storage.error` an die Engine | erfüllt | `test_read_only_target_...` (Topic `engine`, `op` = `flow.write`), `test_missing_flow_read_reports_storage_error_to_the_engine_topic` (`code` = `not_found`) |
| Beenden: Warteschlange leeren bis Frist, dann `sys.bye`, Exit 0 | erfüllt | `test_shutdown_finishes_the_queued_writes_then_says_bye_and_exits_0`, Queue-Fälle in `tests/ahk/storage_queue.test.ahk` |
| Round-Trip gegen echte v1-Flows (Struktur, Typen, CRLF, ohne BOM) | erfüllt | `test_v1_flows_round_trip_through_storage_with_same_structure_and_types` (alle `Flow *.json` aus `v1/AppData/Saved Flows`, Kopie im Temp-Ordner) |
| Pfade mit Leerzeichen und Umlauten | erfüllt | `test_names_with_spaces_and_umlauts_work` (`Flow 1010290492 Übung`) |
| Engine-Vertrag mit dem echten Storage | erfüllt | `test_engine_starts_with_the_real_storage_and_its_log_arrives` (Start, `evt.engine.ready`, Snapshot mit einem Flow, `Log_engine.txt` enthält `ready with 1 flow(s)`) |

**Entscheidungen (WI-12 ließ sie offen):**

- **CRLF:** Storage schreibt CRLF wie v1 (alle v1-Dateien sind CRLF, verifiziert an den Beispielen). Die Ausgabe der Engine (LF, `Json.Stringify`) wird am Storage umgewandelt, der Round-Trip-Test prüft CRLF und das Fehlen von BOM. Kein BOM: `UTF-8-RAW`, wie die Flow-Dateien (MIGRATION M-16 für die Logs).
- **Backup:** Vor dem Ersetzen wird die alte Datei nach `Flows/backup/<name>_backup_<yyyyMMddHHmmss><ms>.json` kopiert (v1 hat das nie getan, M-07). Höchstens 10, die ältesten zuerst. Schlägt das Backup fehl, wird **nicht** geschrieben (`internal`). Begründung: lieber kein Schreiben als ein Überschreiben ohne Sicherung.
- **Variablen, doppeltes Löschen:** `cmd.storage.var.delete` ist idempotent. Ein zweites Löschen ist `ok: true` mit `existed: false`. Begründung: das Ziel (nicht mehr vorhanden) ist erreicht, und die Engine muss nicht zwischen „schon weg“ und „Fehler“ unterscheiden. Getestet mit `test_deleting_a_variable_twice_is_not_an_error`.
- **Variablen-Inhalt:** Storage speichert den Inhalt-Text unverändert (`object`: JSON-Text, geprüft; `normal`: Wert als Text). Die Engine serialisiert Objekte. So entsteht kein zweiter JSON-Dialekt in der Storage-Rolle.
- **Log-Zeile:** v1-Format unverändert. Thread-Feld = Name des sendenden Prozesses (v1: AHK-Thread). Zeit lokal wie v1. Der `ts` der Nachricht ist UTC und wird umgerechnet.

**Änderungen an `core/` (Absprache nötig):** `src/core/ipc/Deferred.ahk` (neu), `Dispatcher.ahk`, `Peer.ahk` (Antwort später: `Deferred.Marker()` und `peer.Reply`), `src/core/RoleRegistry.ahk` (Platzhalter `storage` entfernt, der Kommentar sah das vor). Die Begründung steht im Commit `419051a`. Ohne den Marker kann Storage keine Warteschlange betreiben, ohne sie wäre I/O im Nachrichtenpfad (AGENTS Regel 3). Die bestehenden Peer- und Worker-Tests laufen grün.

**Abweichungen von WI-12:**

- Keine Blockweise Schreiben: jede Datei wird in einer Operation geschrieben. Die Anforderung „Ping unter 1 s“ ist mit 5 MB erfüllt (Messung oben). Blockweises Schreiben ist nicht gebaut.
- `evt.storage.error` geht an das Topic `engine` (wie PROTOCOL 4.3), nicht an die Engine-Adresse direkt. Zusätzlich trägt es `code` (PROTOCOL 4.3 angepasst).
- Der Testhub leitet Frames des Clients und den Shutdown auf getrennten Wegen weiter. Der Shutdown-Test wartet deshalb 0,5 s, bevor er `sys.shutdown` sendet (sonst kommen die Schreibaufträge nach dem Shutdown an). Der Drain der Warteschlange bei gefüllter Queue wird im AHK-Unittest (`tests/ahk/storage_queue.test.ahk`) geprüft, nicht im Integrationstest.
- `test_role_without_implementation_reports_not_implemented` nutzte `storage` als Platzhalter. Jetzt `triggerhost` (WI-14), derselbe Exit-Code und dieselbe Meldung.
- Ordner `Flows/` statt v1 `Saved Flows/` (MIGRATION M-15).

**Nicht geprüft / offen:**

- Abbruch mitten im Schreiben: der Test trifft den Zeitpunkt nicht gezielt. „Alt oder neu“ gilt für jeden Ausgang.
- Liegengebliebene Temp-Dateien (`*.ahf-<pid>.tmp`) nach einem harten Abbruch werden nicht aufgeräumt. Sie werden nie gelesen.
- Eigene Log-Senke des Storage-Prozesses (`Storage.SelfLogFn`): nur bei Fehlern aktiv, kein gezielter Test.
- Überlauf der Platte, Schreibschutz auf dem Ordner (nur die Datei wurde getestet).
- Der Supervisor startet Storage nicht im Integrationstest (`--start=storage` wird nicht geprüft).
- Einstellungen (`cmd.storage.settings.*`) und `.ahf`-Export: Phase 3, nicht gebaut.
- Der Engine-Test (`test_engine.py`) nutzt weiter den StorageStub. Der echte Storage ist nur im einen Test oben angebunden.

**Nachtrag F-04 (Log-Zeilen unter Parallellast):** behoben. Schreiben mit `FileOpen` (teilt Lesen und Schreiben) und Wiederholung per Timer in `WriteQueue` bei gesperrter Datei (3 s), danach Zähler `logLinesLost` und Selbstlog-Eintrag. Tests: `test_no_log_line_is_lost_while_other_processes_hold_the_files` (zwei Varianten), `test_a_log_line_that_cannot_be_written_is_reported_in_the_own_log`, AHK-Fälle "a retry keeps the order ..." und "a retry past its time ...". Siehe `doc/HOW-TO.md` (Eintrag F-04) und Commit `WI-12: retry ...` (`git log`).
