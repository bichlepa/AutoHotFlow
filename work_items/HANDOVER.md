# Handover: AutoHotFlow v2 Portierung

Stand: 2026-10-12, Branch `v2-port`. Phase 2 (Walking Skeleton), Phase 2b (Härtung vor Phase 3) und der Fix-Block WI-30 bis WI-33 sind umgesetzt. **Die Abnahmeläufe von WI-32 (Aufgabe 2) sind gefahren und nicht grün**: seriell und Stress grün, parallel 5 von 10 Läufen grün, Fault 20-mal ein roter Test (neue Funde F-37 bis F-42, `STATUS.md`, Abschnitt "Abnahmelauf Fix-Block"). **Die Wiederholung der Abnahme (WI-34, 2026-10-12, zweiter Lauf) ist ebenfalls nicht grün**: parallel 9 von 10 Läufen grün, Stress grün, seriell 2 rote Tests und Fault 20x 5 rote Wiederholungen (neue Funde F-45 bis F-47, `STATUS.md`, Abschnitt "Abnahmelauf WI-34 (2026-10-12, zweiter)"). Der Fix-Block ist damit nicht grün abgeschlossen. Als Nächstes folgt der Phase-3-Plan, den der Projektinhaber mit Claude entwirft. Statusbericht mit Funden, Messwerten und den Abschlussläufen: `work_items/STATUS.md`.

## Neu seit 2026-10-12: Fix-Block WI-30 bis WI-33 (umgesetzt)

`work_items/phase2b/README.md`, Abschnitt "Nachtrag 2026-10-12" (Entscheidungen E9 bis E15, Pakete WI-30 bis WI-33).

- WI-30: Rollen leeren ihre Sendewarteschlange vor dem Ende (`CloseWhenFlushed`), der Supervisor bewertet ein Ende erst nach dem letzten Byte; F-26 behoben (`test_shutdown.py` 400 von 400 grün).
- WI-31: Die Engine wartet auf `storage` und setzt abgebrochenes Laden fort; F-24 geschlossen, F-31 bis zur Abnahme offen.
- WI-33: Worker enden mit der Engine (E10); alle Fristen des Supervisors behalten ihren Rest nach einem Stillstand (F-16, E12); Exit 5 nur bei hartem Beenden (F-33).
- WI-32: Testbereinigung (Aufgabe 1) und Dokumente (Aufgabe 3) sind fertig. **Die Abnahmeläufe (Aufgabe 2) sind gefahren und nicht grün** (Einzelheiten in `STATUS.md`); Befehle und Kriterien stehen im Ergebnis von `work_items/phase2b/WI-32-teststabilitaet-abschluss.md`. Neu für Tests: `tests/support/timing.py` (`scaled()`, Zeitgrenzen im parallelen Lauf, `doc/TESTSTRATEGIE.md`); die strenge Log-Rate (F-32) läuft nur noch mit `-m stress`.

## Wichtigste Vorgabe zuerst

**Nicht eigenständig mit Phase 3 beginnen.** Phase 3 braucht die ausdrückliche Freigabe des Projektinhabers. Der Phase-3-Plan (`work_items/phase3/README.md`, WI-17 Schritt 6) und die gebündelten Fragen (WI-17 Schritt 7) sind noch nicht geschrieben; den Plan entwirft der Projektinhaber mit Claude. Wer Phase 3 vorbereitet, beginnt damit und klärt vorher die "Offenen Entscheidungen" unten.

`work_items/` und `v1/` nicht löschen: Das ist laut `AGENTS.md` eine Entscheidung des Projektinhabers nach der Portierung.

## Pflichtlektüre für einen neuen Agenten

1. `AGENTS.md` (Regeln, Werkzeuge, Stolpersteine, aktueller Stand)
2. `doc/ARCHITEKTUR.md` Abschnitte 1 bis 6 und 8 (Abschnitt 8 enthält den Ist-Stand der Ordnerstruktur)
3. `doc/KONVENTIONEN.md` (Abschnitt 3: Architekturwächter `tools/arch_check.py`)
4. `doc/HOW-TO.md` (Wissensbasis, seit WI-29 nach Kategorie sortiert, Status verifiziert / vermutet / nicht geprüft)
5. `doc/PROTOKOLL.md` (Abschnitt 4 beginnt mit der Liste der noch nicht umgesetzten Nachrichtentypen)
6. `work_items/STATUS.md`, `work_items/phase2b/README.md` (Entscheidungen E1 bis E8 und, im Nachtrag, E9 bis E15) und die Ergebnis-Abschnitte der Paketdateien
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
- Tests: `python -m pytest tests -q` (Standardlauf, parallel mit `-n auto --dist loadgroup` aus `pytest.ini`, rund 1 bis 2 Minuten; seriell mit `-n 0`, rund 10 Minuten; wer nur eine Datei ändert, fährt diese und ihre Nachbarn, nicht den ganzen Bestand; im Hintergrund starten, Ausgabe in eine Datei). Stress: `-m stress` (3,5 Minuten), Dauerlauf `-m soak` (600 s, `AHF_SOAK_CHURN=1` für Verbindungswechsel), Fault-Wiederholungen `AHF_FAULT_REPEAT=<n>` (20 Wiederholungen: rund 42 Minuten). Läufe nie gleichzeitig starten (Messungen und Fristen).
- Testrollen (`echo`, `crasher`, ...) gibt es nur im Testeinstieg `tests/integration/helpers/AutoHotFlowTest.ahk` mit `--test-roles`. Tests, die sie brauchen, starten diesen Einstieg, nicht `src/AutoHotFlow.ahk`.

## Was bis jetzt geliefert ist (aus den Paketberichten)

- Phase 2: Einstieg, `src/core/` (Json, Ids, Errors, Args, Log, Time, Role, `ipc/`), Rollen `supervisor`, `engine`, `storage`, `worker`, `manager` als Stub (`--ui=stub`), Skeleton-Elemente, Tests (`tests/ahk`, `integration`, `e2e`, `fault`, `stress`), Werkzeuge.
- Phase 2b (WI-18 bis WI-29): parallele Tests und Architekturwächter; Engine mit neuester Revision, Richtlinie `wait`, Loop-Stack-Korrektur; Supervisor-Heartbeat, Startreihenfolge, nur 64 Bit, benutzerbezogene Pipe-Namen; Log des Supervisors und stderr der Kinder im Log; Hub routet über Kopffelder, gestaffeltes Laden (200 Flows); Storage mit getrennten Warteschlangen (Durchsatz 1493 Zeilen/s); echte JSON-Booleans; elastischer Worker-Pool; `cmd.diag.snapshot`, Absturzberichte, Rolle `debug` (Debug-Fenster), `Debug.Dump`; Testeinstieg getrennt vom Produkteinstieg, eine Klasse je Datei, kein Wächter-Ausnahmefall mehr außer den zwei `FileAppend`-Zeilen für stderr.

## Entscheidungen des Projektinhabers

Beantwortet am 2026-10-12 (Wortlaut: `work_items/phase2b/README.md`, Nachtrag; Übersicht in `work_items/STATUS.md`):

- Löschen eines Flows ohne Frist: **bestätigt** (E9).
- Worker enden mit der Engine: **ja, umgesetzt** (E10, WI-33).
- Obergrenze des Log-Puffers: bleibt eine interne Konstante (E11).
- F-16, Fristen des Supervisors nach einem Stillstand: **gelöst** (E12, WI-33).
- Änderungen F-05 und F-07 in `src/core/`, MIGRATION M-11, M-17, M-18: **bestätigt** (E13).
- Leeres `--data=` schreibt nach `C:\Log`: egal, Beobachtungsliste (E15).
- Flow-Schreibformat: Format-Wechsel erst in Phase 3 (E8, unverändert).

## Offene Entscheidungen des Projektinhabers

1. **Schließen des Manager-Fensters** (E14): Im Stub beendet es die ganze Anwendung. Was der echte Manager tut (nur Fenster schließen, in den Tray, Anwendung beenden), wird in **Phase 3** entschieden.
2. **Freigabe von Phase 3** und der Phase-3-Plan (`work_items/phase3/README.md`, WI-17 Schritte 6 und 7), den der Projektinhaber mit Claude entwirft.
3. Handprüfung der Oberflächen (Stub, Debug-Fenster) durch den Projektinhaber, Anleitungen in `phase2/WI-13-ui-stub.md` und `phase2b/WI-28-diagnose-bericht-debugfenster.md`.

## Offene Punkte (Details und Belege in `STATUS.md`, Tabelle "Funde")

- **Wiederholung der Abnahme (WI-34), nicht grün:** parallel 9 von 10 grün (F-45 einmal), Stress grün, seriell rot (F-46 Worker-Kill-Test, F-47 `cmd.worker.cancel` unbeantwortet), Fault 20x 5 von 20 Wiederholungen rot (F-46). Offen: F-45 bis F-47 untersuchen (Ursachen nicht belegt), F-43 (Entscheidung des Projektinhabers), F-42. Haken in `phase2b/README.md` bleiben offen.
- **Abnahmeläufe von WI-32 (Aufgabe 2), nicht grün (älterer Stand):** parallel 5 von 10 Läufen grün (rote Tests F-37 bis F-41, F-38 zweimal), `AHF_TIMING_FACTOR=1` ein roter Test (F-42), seriell grün, Stress grün, Fault 20-mal ein roter Test (F-38). Zu entscheiden: die Funde F-37 bis F-42 untersuchen oder begründet zurückstellen (der Haken in `phase2b/README.md` ist offen); erst dann gilt der parallele Lauf als verlässlich.
- **F-31** geschlossen (kein Fall in den Abnahmeläufen). **F-36** (`sys.hello` unbeantwortet) in 14 Läufen nicht aufgetreten, Schließen empfohlen.
- **F-36** (niedrig bis mittel, Ursache nicht gefunden): `sys.hello` 15 s lang unbeantwortet (die Hub-Frage aus WI-23), in WI-32 in `tests/fault/test_shutdown.py` zusammen mit anderen Tests aufgetreten, als die Maschine langsam war; später nicht reproduzierbar. Details und Hinweise in `STATUS.md`.
- F-26 (behoben in WI-30), F-24 (WI-31), F-16 und F-33 (WI-33), F-32 und die Zeitgrenzen F-19 (WI-32) sind erledigt. F-35 (Drain-Frist in `src/core/ipc/`) ist offen, niedrig.
- Weitere Funde F-12 bis F-15, F-17, F-18, F-20 bis F-23, F-25, F-28 bis F-30, F-35: überwiegend niedrig, mit Entscheidung in der Tabelle.
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
| WI-30 | `7b1da26`, `29b3635`, `cdee87f`, `598e0fd`, `5a3a83c` |
| WI-31 | `4bf303f`, `f7c9b48`, `e4b5c5b`, `9fb95d8` |
| WI-33 | `198d86e`, `576ab57`, `3d2bd06`, `751416d`, `c29d810` |
| WI-32 | `8d0e65a`, `056a1d5`, `c454658`, `ef90ede`, `bb39719`, danach Dokumente und Ergebnis (siehe `git log --grep="^WI-32:"`) |

## Nächste Schritte

1. **WI-34** (`phase2b/WI-34-abnahmefunde.md`): F-41 (Produktfehler: ein Kind, das sich während des Beendens meldet, bekommt nie `sys.shutdown`) und F-40 (Anfragen an einen gestorbenen Prozess warten ihre volle Frist ab, vermutet) beheben oder klären, F-37, F-38, F-39, F-42 als Testkorrekturen, dann die Abnahme wiederholen und die Haken in `phase2b/README.md` setzen.
2. Phase-3-Plan entwerfen (Projektinhaber mit Claude): Reihenfolge Common/Variablen und Ausdrucksauswerter, Flow laden/speichern, Ausführung, Elemente in Gruppen, Triggerhost früh (E6), Editor und Zeichnen, Manager (E14: Verhalten beim Schließen des Fensters); Messaufgaben für R3, R4, R5 aus ARCHITEKTUR 10 und die offenen Fragen aus ELEMENT-API-V2 Abschnitt 8; gebündelte Fragen an den Projektinhaber. Freigabe für Phase 3 erteilen.
3. Nach der Portierung: `work_items/` und `v1/` entfernen (Entscheidung des Projektinhabers).
