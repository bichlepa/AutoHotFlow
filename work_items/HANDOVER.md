# Handover: AutoHotFlow v2 Portierung

Stand: 2026-10-12, Branch `v2-port`. Phase 2 (Walking Skeleton) und Phase 2b (Härtung vor Phase 3) sind abgeschlossen, Phase 2b **mit offenen Punkten** (siehe unten). Statusbericht mit Funden, Messwerten und den Abschlussläufen: `work_items/STATUS.md`.

## Neu seit 2026-10-12: Fix-Block WI-30 bis WI-33

Nach dem Review von Phase 2b kommt vor dem Phase-3-Plan ein kurzer Fix-Block: `work_items/phase2b/README.md`, Abschnitt "Nachtrag 2026-10-12" (Entscheidungen E9 bis E15, Pakete WI-30 bis WI-33). Er beantwortet die "Offenen Entscheidungen" 1 bis 5 weiter unten. Wer weiterarbeitet, beginnt mit WI-30.

## Wichtigste Vorgabe zuerst

**Nicht eigenständig mit Phase 3 beginnen.** Phase 3 braucht die ausdrückliche Freigabe des Projektinhabers. Der Phase-3-Plan (`work_items/phase3/README.md`, WI-17 Schritt 6) und die gebündelten Fragen (WI-17 Schritt 7) sind noch nicht geschrieben; den Plan entwirft der Projektinhaber mit Claude. Wer Phase 3 vorbereitet, beginnt damit und klärt vorher die "Offenen Entscheidungen" unten.

`work_items/` und `v1/` nicht löschen: Das ist laut `AGENTS.md` eine Entscheidung des Projektinhabers nach der Portierung.

## Pflichtlektüre für einen neuen Agenten

1. `AGENTS.md` (Regeln, Werkzeuge, Stolpersteine, aktueller Stand)
2. `doc/ARCHITEKTUR.md` Abschnitte 1 bis 6 und 8 (Abschnitt 8 enthält den Ist-Stand der Ordnerstruktur)
3. `doc/KONVENTIONEN.md` (Abschnitt 3: Architekturwächter `tools/arch_check.py`)
4. `doc/HOW-TO.md` (Wissensbasis, seit WI-29 nach Kategorie sortiert, Status verifiziert / vermutet / nicht geprüft)
5. `doc/PROTOKOLL.md` (Abschnitt 4 beginnt mit der Liste der noch nicht umgesetzten Nachrichtentypen)
6. `work_items/STATUS.md`, `work_items/phase2b/README.md` (Entscheidungen E1 bis E8) und die Ergebnis-Abschnitte der Paketdateien
7. Für die Phase-3-Pakete: `doc/ELEMENT-API-V2.md`, `doc/MIGRATION.md`

## Regeln, die gelten

- AHK-Skripte nie direkt starten, nur über `python tools/ahkrun.py [--timeout N] skript.ahk`. Exit-Codes 97 (Dialog abgefangen), 98 (Timeout), 99 (kein Interpreter).
- Unbekannte Optionen nie an den AHK-Interpreter geben (`--version` erzeugt einen Dialog).
- Nie Prozesse nach Namen beenden (`Stop-Process`, `taskkill` nach Bildname). Es laufen fremde AutoHotkey-Prozesse des Projektinhabers (z. B. `AutoHotkey64.exe` mit `src\AutoHotFlow.ahk` ohne Argumente, `AutoHotkeyU32.exe` mit "Allgemeine Hilfe.ahk"). Prozesse nach dem Lauf nur ansehen (`Get-CimInstance Win32_Process`), nur selbst gestartete Pids beenden.
- Eingebaute AHK-v2-Klassennamen nicht neu definieren. Eigene Fehlerklassen mit Präfix `Ahf`. Eine Klasse je Datei (der Wächter erzwingt es).
- Dateien mit Editor-Werkzeugen schreiben, nicht per Shell-Heredoc (Backslashes, lange Texte brechen).
- Nichts unter `v1/` ändern.
- Commits klein und einzeln, Nachricht beschreibt das Warum, Präfix `WI-xx:`.
- Bei AHK-Schwierigkeiten: Eintrag in `doc/HOW-TO.md` mit Status.
- Tests: `python -m pytest tests -q` (Standardlauf, parallel mit `-n auto --dist loadgroup` aus `pytest.ini`, rund 2 Minuten; seriell mit `-n 0`, rund 10 Minuten; im Hintergrund starten, Ausgabe in eine Datei). Stress: `-m stress` (3,5 Minuten), Dauerlauf `-m soak` (600 s, `AHF_SOAK_CHURN=1` für Verbindungswechsel), Fault-Wiederholungen `AHF_FAULT_REPEAT=<n>` (20 Wiederholungen: rund 42 Minuten). Läufe nie gleichzeitig starten (Messungen und Fristen).
- Testrollen (`echo`, `crasher`, ...) gibt es nur im Testeinstieg `tests/integration/helpers/AutoHotFlowTest.ahk` mit `--test-roles`. Tests, die sie brauchen, starten diesen Einstieg, nicht `src/AutoHotFlow.ahk`.

## Was bis jetzt geliefert ist (aus den Paketberichten)

- Phase 2: Einstieg, `src/core/` (Json, Ids, Errors, Args, Log, Time, Role, `ipc/`), Rollen `supervisor`, `engine`, `storage`, `worker`, `manager` als Stub (`--ui=stub`), Skeleton-Elemente, Tests (`tests/ahk`, `integration`, `e2e`, `fault`, `stress`), Werkzeuge.
- Phase 2b (WI-18 bis WI-29): parallele Tests und Architekturwächter; Engine mit neuester Revision, Richtlinie `wait`, Loop-Stack-Korrektur; Supervisor-Heartbeat, Startreihenfolge, nur 64 Bit, benutzerbezogene Pipe-Namen; Log des Supervisors und stderr der Kinder im Log; Hub routet über Kopffelder, gestaffeltes Laden (200 Flows); Storage mit getrennten Warteschlangen (Durchsatz 1493 Zeilen/s); echte JSON-Booleans; elastischer Worker-Pool; `cmd.diag.snapshot`, Absturzberichte, Rolle `debug` (Debug-Fenster), `Debug.Dump`; Testeinstieg getrennt vom Produkteinstieg, eine Klasse je Datei, kein Wächter-Ausnahmefall mehr außer den zwei `FileAppend`-Zeilen für stderr.

## Offene Entscheidungen des Projektinhabers

1. **Löschen eines Flows ohne Frist** (WI-21): `Executor.FlowDeleted` stoppt sofort ohne Quittung und ohne Abbruch nach 10 s wie in v1 (ARCHITEKTUR 4.2). Entscheidung des Agenten, nicht bestätigt.
2. **Worker beenden, wenn die Engine endet** (WI-27): Soll der Supervisor alle `worker:*` beenden, sobald die Engine endet? Heute bleiben Waisen mit Dialog bis zum Neustart der Engine oder bis zum Sitzungsende (reine Prozessverwaltung, widerspricht aber dem Wortlaut des Pakets).
3. **Obergrenze des Log-Puffers** (WI-25): 20000 Einträge oder 8 MiB sind feste Werte. Soll sie in Phase 3 eine Einstellung werden?
4. **F-16**: Die Fristen des Supervisors (Beenden, `Hub.Request`, Hello) laufen nach der Wanduhr und kennen einen Stillstand des Supervisors nicht (nur der Heartbeat). In Phase 3 lösen?
5. Zusätzlich aus früheren Paketen weiter offen: Bestätigung der Änderungen in `src/core/` (F-05, F-07), MIGRATION M-11 und M-17/M-18 nicht ausdrücklich bestätigt, Antwort auf das Format des Flow-Schreibens (E8: erst in Phase 3).

## Offene Punkte (Details und Belege in `STATUS.md`, Tabelle "Funde")

- **F-26** (mittel): `evt.process.exited` mit `clean: false` bei sauberem Ende, rund 1 % (WI-29: 4 von 460 Läufen), betrifft `manager` und `storage`. Ursache nicht untersucht.
- **F-31** (niedrig, nicht geklärt): `Chain.wait_flows` nach 20 s ohne geladene Flows in `tests/fault/test_debug_role.py`; in beiden seriellen Gesamtläufen (WI-28, WI-29) je einmal, in 5 x 11 Einzelläufen der Datei nie.
- **Parallele Läufe unter Last** sind instabil gewesen (F-19: zu enge Fristen der Fault-Tests; F-26; zeitempfindliche Stresstests `clients_churn[smoke]`, `big_flows[smoke]`); die Hub-Frage aus WI-23 (`sys.hello` 15 s lang unbeantwortet) ist nicht erklärt. Der parallele Abschlusslauf war einmal grün (113 s).
- Weitere Funde F-12 bis F-18, F-20 bis F-24, F-28 bis F-30: überwiegend niedrig, mit Entscheidung in der Tabelle.
- Nicht gebaut: Triggerhost (WI-14, E6: früh in Phase 3), Editor, echter Manager, echte Elemente, Ausdrucksauswertung, Übersetzungen, Import/Export. `cmd.flow.patch` kennt nur Schema und Revisionsprüfung. Der Befehl zum Löschen eines Flows fehlt.
- GUI des Stubs und des Debug-Fensters nicht von Hand geprüft (Anleitungen in `phase2/WI-13-ui-stub.md` und `phase2b/WI-28-diagnose-bericht-debugfenster.md`).

## Nicht geprüft

Timing unter Systemlast, zweiter Windows-Benutzer, Standby, gesperrter Desktop für Screenshots, echte blockierende Dialog-Elemente im Worker, Worker-Pool mit mehr als 3 Workern im Dauerlauf, Idle-CPU und Speicher mit warmem Worker, Triggerhost, Editor (Speicher bei 5 Editoren, Neuzeichnen).

## Commits je Paket (`git log --oneline --grep="^WI-xx:"`)

| Paket | Commits (älteste zuerst) |
|---|---|
| Plan | `d3e0650` |
| WI-18 | `a6711c5` |
| WI-19 | `4a2a6e4` |
| WI-20 | `f42ed73` |
| WI-21 | `9e84422`, `26cada9`, `58c17d9`, `a06623f`, `5a705fc` |
| WI-22 | `856ef22`, `dfe8137`, `ae919f9`, `6870a6f`, `638ce3a`, `c7a07fe`, `2da8beb` |
| WI-23 | `b47f42c`, `6892034`, `04bf3af`, `f0878c2`, `ef34b5b` |
| WI-24 | `0126ecc`, `87fd20f`, `c052813`, `f9aa362`, `b76288d`, `be3a2a3` |
| WI-25 | `831c9e8`, `41d1265`, `1e0f4d7`, `bff8955`, `f29b267`, `f1efb7a` |
| WI-26 | `1d07f5d`, `787dcf1`, `aa55dfd`, `a55e164`, `7d0bd5d`, `45c501a` |
| WI-27 | `5404731`, `a7fa998`, `55abcbf`, `682a729`, `961fed2`, `9221437`, `edaad96`, `762b4a7`, `0ad3847`, `bcc5c82` |
| WI-28 | `d27d0ef`, `32234b2`, `d35b5d7`, `3e00b94`, `2b1f07e`, `b450a5c`, `fec7d06`, `e744800` |
| WI-29 | `31afcc2` (Testeinstieg), `1a6f5e4` (eine Klasse je Datei), `facf064` (Wächter-Ausnahmen), `20efac2` (HOW-TO sortiert), danach Dokumente (siehe `git log --grep="^WI-29:"`) |

## Nächste Schritte

1. Offene Entscheidungen oben beantworten, Freigabe für Phase 3 erteilen.
2. Phase-3-Plan entwerfen (Reihenfolge Common/Variablen und Ausdrucksauswerter, Flow laden/speichern, Ausführung, Elemente in Gruppen, Triggerhost früh (E6), Editor und Zeichnen, Manager; Messaufgaben für R3, R4, R5 aus ARCHITEKTUR 10 und die offenen Fragen aus ELEMENT-API-V2 Abschnitt 8; gebündelte Fragen an den Projektinhaber).
3. F-26 und F-31 untersuchen, bevor viele neue Tests hinzukommen (jeder zusätzliche Test verlängert den seriellen Lauf).
4. Nach der Portierung: `work_items/` und `v1/` entfernen (Entscheidung des Projektinhabers).
