# Handover: AutoHotFlow v2 Portierung

Stand: 2026-10-10, Branch `v2-port`, letzter Commit `c34e57a` (WI-06). Arbeitsbaum sauber.

## Wichtigste Vorgabe zuerst

Der Projektinhaber hat in einer Datei im Repo-Stamm (inzwischen entfernt) geschrieben: „Stoppe nach diesem Work package!“. Das Paket WI-06 ist fertig und committet. **Nicht eigenständig mit WI-07 weitermachen.** Erst auf eine ausdrückliche Freigabe des Projektinhabers warten. Der Versuch, WI-07 an einen Sonnet-Agenten zu geben, wurde vom Projektinhaber abgelehnt.

## Pflichtlektüre

1. `AGENTS.md` (Regeln, Werkzeuge, Stolpersteine)
2. `doc/ARCHITEKTUR.md` Abschnitte 1 bis 6
3. `doc/KONVENTIONEN.md`
4. `doc/HOW-TO.md` (Wissensbasis, viele Stolpersteine)
5. `work_items/phase2/README.md` (Verträge, Wellen, Pakete)
6. `work_items/STATUS.md` (teilweise veraltet, siehe unten)

## Regeln, die gelten

- AHK-Skripte nie direkt starten, nur über `python tools/ahkrun.py [--timeout N] skript.ahk`. Exit-Codes 97 (Dialog abgefangen), 98 (Timeout), 99 (kein Interpreter).
- Unbekannte Optionen nie an den AHK-Interpreter geben (`--version` erzeugt einen Dialog).
- Eingebaute AHK-v2-Klassennamen nicht neu definieren. Eigene Fehlerklassen mit Präfix `Ahf`.
- Dateien mit Editor-Werkzeugen schreiben, nicht per Shell-Heredoc. Backslashes in Pipe-Namen fallen sonst zusammen.
- Nichts unter `v1/` ändern.
- Commits klein und einzeln, Nachricht beschreibt das Warum. Commit-Attribution: `Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>` (aktuelle Vorgabe).
- Bei AHK-Schwierigkeiten: Eintrag in `doc/HOW-TO.md` mit Status verifiziert / vermutet / nicht geprüft.
- Tests: `python -m pytest tests -q` dauert über 60 s. Befehle über 120 s im Hintergrund laufen lassen.
- Nach jedem Lauf prüfen: keine von den Tests gestarteten `AutoHotkey64.exe` übrig.

## Stand der Pakete (Phase 2)

| Paket | Commit | Stand |
|---|---|---|
| Testinfrastruktur (WI-01) | `400728e` | fertig |
| Dialog-Wächter, `ahkrun.py` | `d502043`, `62fd573` | fertig |
| Core-Basics (WI-03) | `410aa91` | fertig |
| JSON (WI-02) | `16a6539` | fertig, Parsen 1,5 s statt Ziel 1 s |
| Pipe-Schicht (WI-04) | `5c997e1`, `e62ed65` | fertig, Race bei 16-MiB-Rahmen behoben |
| Engine-Kern (WI-08) | `888dd6d` | fertig |
| Element-Basis (WI-09) | `d11afa1` | fertig |
| Nachrichtenschicht (WI-05) | `7888b9c` | fertig, 299 grün |
| Rollenbasis (WI-06) | `c34e57a` | fertig, 308 grün |
| **Supervisor (WI-07)** | – | **nicht begonnen, wartet auf Freigabe** |
| Engine-Rolle (WI-10) | – | offen |
| Worker (WI-11) | – | offen |
| Storage (WI-12) | – | offen |
| UI-Stub (WI-13) | – | offen |
| Triggerhost (WI-14) | – | offen (optional) |
| Fault-Injection (WI-15) | – | offen |
| Stresstest (WI-16) | – | offen |
| Abschluss (WI-17) | – | offen |

Letzter Gesamtlauf: `308 passed, 1 skipped` (WI-06-Bericht).

## Offene Punkte aus den Berichten

- **Fremder Prozess:** `AutoHotkey64.exe` PID 29328, Elternprozess 27720 existiert nicht mehr, Kommandozeile `/restart /script ...\src\AutoHotFlow.ahk`. Stammt nicht von den Tests. Nicht beendet. Vom Projektinhaber prüfen lassen.
- **Fortschrittshaken:** In `work_items/phase2/README.md` fehlen die Häkchen für WI-03 und WI-06 (WI-04 und WI-05 sind gesetzt).
- **Doppelte Überschrift** „Prozesse, Pipes, Nachrichten“ in `doc/HOW-TO.md`.
- **Sporadischer Dialog-Test:** `test_msgbox_is_captured_and_closed` war einmal im Timeout. Behoben wurde die Ursache mit `ctypes.argtypes`, Status vermutet, da nur 20 Läufe belegt.
- **Rollen (WI-06):** `RoleRegistry.ahk` enthält zwei Klassen (Verletzung „eine Klasse pro Datei“), auslagern. `EchoRole.ahk` ist im Produkteinstieg eingebunden, vor WI-17 entscheiden. `deadlineMs` von `sys.shutdown` wird noch nicht erzwungen (WI-10). Kurzer Hub-Ausfall unter 3 s nicht getestet.
- **Peer (WI-05):** `tests/support/pyhub.py` sendet keinen Weckruf, Tests nutzen `WakingHub`. Vorschlag: in pyhub.py übernehmen (WI-07). `with WakingHub(...).start()` könnte `start()` doppelt aufrufen (vermutet, nicht ausgeführt).
- **Storage (WI-12):** CRLF-Entscheidung treffen, v1-Dateien haben CRLF, Ausgabe bisher LF. Backup-Verhalten laut WI-12 neu umsetzen (v1 war wirkungslos, M-07). Doppeltes Entfernen von `.ahfvar` beachten.
- **MIGRATION.md:** Einträge M-01 bis M-14 vorhanden. M-11 (`wait` ist in v1 wirkungslos, in v2 wirksam) ist vom Projektinhaber nicht ausdrücklich bestätigt, nur im Bericht des Agenten dokumentiert.
- **Richtlinie `stop` (WI-08):** Frist 2 s laut Tabelle 5.1, v1 hatte keine Frist. Umsetzung bei WI-10.
- **Dangling-Verbindungen:** 154 von 1039 in den Beispielflows. Ob das Laden warnen soll, ist offen.
- **Test-Laufzeit:** Der Gesamtlauf liegt bei über 70 s. Bei weiteren Paketen steigt das.
- **Nicht geprüft:** Timing unter Systemlast, AHK 32 Bit, Verhalten bei gesperrtem Desktop für Screenshots.

## Nächste Schritte (nach Freigabe)

1. Projektinhaber fragen, ob WI-07 (Supervisor) begonnen werden soll. WI-07 ist Sonnet-Stufe (L, Prozessüberwachung, Beenden).
2. Danach WI-10 (Engine-Rolle), WI-11 (Worker), WI-12 (Storage), WI-13 (UI-Stub), WI-14 (Triggerhost), WI-15 (Fault-Injection), WI-16 (Stresstest), WI-17 (Abschluss).
3. Jedes Paket einzeln, mit eigenem Commit. Am Ende jeder Phase `doc/HOW-TO.md` mit committen.
4. Zum Schluss: `work_items/` und `v1/` löschen (laut `AGENTS.md`), Verantwortung dafür beim Projektinhaber.
