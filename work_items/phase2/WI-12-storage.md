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
