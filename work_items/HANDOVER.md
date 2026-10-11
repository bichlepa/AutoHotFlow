# Handover: AutoHotFlow v2 Portierung

Stand: 2026-10-11, Branch `v2-port`. Phase 2 (Walking Skeleton) ist technisch abgeschlossen. Aktueller Statusbericht mit Funden, Messwerten und Gesamtlauf: `work_items/STATUS.md`.

## Wichtigste Vorgabe zuerst

**Nicht eigenständig mit Phase 3 beginnen.** Phase 3 braucht die ausdrückliche Freigabe des Projektinhabers. Offen aus WI-17: Schritt 6 (Phase-3-Plan `work_items/phase3/README.md`) und Schritt 7 (gebündelte Fragen an den Projektinhaber am Ende von `STATUS.md`) sind noch nicht geschrieben. Wer Phase 3 vorbereitet, beginnt damit.

`work_items/` und `v1/` nicht löschen: Das ist laut `AGENTS.md` eine Entscheidung des Projektinhabers nach der Portierung.

## Pflichtlektüre für einen neuen Agenten

1. `AGENTS.md` (Regeln, Werkzeuge, Stolpersteine)
2. `doc/ARCHITEKTUR.md` Abschnitte 1 bis 6 und 8 (Abschnitt 8 enthält den Ist-Stand der Ordnerstruktur)
3. `doc/KONVENTIONEN.md`
4. `doc/HOW-TO.md` (Wissensbasis: viele AHK-v2-Stolpersteine mit Status verifiziert / vermutet / nicht geprüft)
5. `doc/PROTOKOLL.md` (Abschnitt 4 beginnt mit der Liste der noch nicht umgesetzten Nachrichtentypen)
6. `work_items/STATUS.md`, `work_items/phase2/README.md`, `work_items/phase2/measurements.md`
7. Für die Phase-3-Pakete: `doc/ELEMENT-API-V2.md`, `doc/MIGRATION.md`

## Regeln, die gelten

- AHK-Skripte nie direkt starten, nur über `python tools/ahkrun.py [--timeout N] skript.ahk`. Exit-Codes 97 (Dialog abgefangen), 98 (Timeout), 99 (kein Interpreter).
- Unbekannte Optionen nie an den AHK-Interpreter geben (`--version` erzeugt einen Dialog).
- Nie Prozesse nach Namen beenden (`Stop-Process`, `taskkill` nach Bildname). Es laufen fremde AutoHotkey-Prozesse des Projektinhabers (v1-`AutoHotFlow.exe`, PID 29328 mit `/restart /script ...\src\AutoHotFlow.ahk`). Prozesse nach dem Lauf nur ansehen (`Get-CimInstance Win32_Process`), nur selbst gestartete Pids beenden.
- Eingebaute AHK-v2-Klassennamen nicht neu definieren. Eigene Fehlerklassen mit Präfix `Ahf`.
- Dateien mit Editor-Werkzeugen schreiben, nicht per Shell-Heredoc (Backslashes in Pipe-Namen).
- Nichts unter `v1/` ändern.
- Commits klein und einzeln, Nachricht beschreibt das Warum. Die Attribution steht in der Systemvorgabe der jeweiligen Sitzung.
- Bei AHK-Schwierigkeiten: Eintrag in `doc/HOW-TO.md` mit Status.
- Tests: `python -m pytest tests -q` (Standardlauf, über 5 Minuten, im Hintergrund starten, Ausgabe in eine Datei). Stress: `python -m pytest tests -m stress -q`, Dauerlauf `-m soak`, Fault-Wiederholungen `AHF_FAULT_REPEAT=<n>`.

## Was Phase 2 geliefert hat (verifiziert aus dem Dateibaum und den Paketberichten)

- `src/AutoHotFlow.ahk` (Einstieg, Rollen per `--role`), `src/core/` (Json, Ids, Errors, Args, Log, Time, Role, RoleRegistry, `ipc/` mit Pipe, Rahmen, Weckruf, Message, Dispatcher, Peer).
- Rollen: `supervisor` (Hub, Prozessüberwachung, zweiphasiges Beenden), `engine` (Zustandsautomaten, Ausführungsrichtlinien, Worker-Anbindung), `storage` (Flows, Variablen, Log, atomares Schreiben, Schreibwarteschlange), `worker` (ein Element zur Zeit), `manager` als Stub (`--ui=stub`, headless oder mit kleinem Fenster).
- Elemente: nur `src/elements/skeleton/` (Demo- und Testelemente). Basis in `src/elements/base/`.
- Tests: `tests/ahk` (Unit), `tests/integration`, `tests/e2e`, `tests/fault`, `tests/stress`, Werkzeuge in `tests/support` und `tools/`.

## Ehrlich: was fehlt

- **Triggerhost (WI-14, optional) ist nicht gebaut.** Die Rolle ist in `RoleRegistry.ahk` ein Platzhalter. Damit sind `cmd.trigger.*`/`evt.trigger.*` ungetestet und es gibt keinen Absturzfall für den Triggerhost.
- **Editor-Rolle ist nicht gebaut** (Platzhalter, Exit 3). Deshalb nicht gemessen: Speicher bei 5 Editoren (Ziel unter 100 MB) und Zustandsänderung bis Neuzeichnen (Ziel unter 50 ms). Das Zeichnungsrisiko (ARCHITEKTUR 2.1, 10) ist unbewertet.
- **GUI des Stubs nicht von Hand geprüft** (Anleitung in `work_items/phase2/WI-13-ui-stub.md`). WI-13 ist deshalb nicht abgehakt.
- Keine echten Elemente, keine Ausdrucksauswertung, kein echter Manager, keine Übersetzungen, kein Import/Export.
- `cmd.flow.patch` kennt nur Schema und Revisionsprüfung, die Operationen fehlen. Richtlinie `wait` ist nicht umgesetzt.

## Offene Punkte (Details und Belege in `STATUS.md`)

- Funde F-06 (`clean` in `evt.process.exited` unzuverlässig, Ursache vermutet) und F-08 (Storage-Log-Rückstau, unbegrenzte Warteschlange) für Phase 3. F-02 beobachten (Pipe-Start über 2 s unter Last).
- `core/RoleRegistry.ahk` enthält zwei Klassen. Der Einstieg bindet Testrollen aus `tests/` ein.
- Änderungen in `src/core/` ohne Absprache während Phase 2: F-05 (`Role.Console`), F-07 (`PipeConnection`), Entfernen des `manager`-Platzhalters in `RoleRegistry`. Der Projektinhaber soll sie bestätigen.
- Idle-CPU: Ziel "unter 1 %" ist als Anteil des Gesamtsystems erfüllt (0,23 %), als Prozent eines Kerns nicht (1,8 %). Lesart ist nicht festgelegt.
- MIGRATION M-11 (`wait` in v1 wirkungslos) ist vom Projektinhaber nicht ausdrücklich bestätigt.
- Nicht geprüft: Timing unter Systemlast, AHK 32 Bit, gesperrter Desktop für Screenshots, Worker-Pool unter Last, Dauerlauf mit Verbindungswechseln nach dem F-07-Fix.

## Nächste Schritte

1. Freigabe des Projektinhabers für Phase 3 abwarten.
2. WI-17 Schritte 6 und 7 schreiben (Phase-3-Plan mit Reihenfolge Common/Variablen und Ausdrucksauswerter, Flow laden/speichern, Ausführung, Elemente in Gruppen, Editor und Zeichnen, Manager; Messaufgaben für R3, R4, R5 aus ARCHITEKTUR 10 und die offenen Fragen aus ELEMENT-API-V2 Abschnitt 8; gebündelte Fragen an den Projektinhaber).
3. Nach der Portierung: `work_items/` und `v1/` entfernen (Entscheidung des Projektinhabers).
