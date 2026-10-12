# AGENTS.md

## Worum es geht

AutoHotFlow (AHF) wird von AutoHotkey v1 (AutoHotkey_H mit `AhkThread`) auf **AutoHotkey v2** portiert. Dabei wird die Architektur so umgebaut, dass die bisherigen Deadlocks und Race Conditions konstruktiv nicht mehr entstehen: **mehrere Prozesse mit Nachrichtenaustausch, kein geteilter Speicher, kein globales Lock**.

Gesprochene Sprache mit dem Projektinhaber: Deutsch. Dokumentation: Deutsch. Code und Code-Kommentare: Englisch.

## Aktueller Stand

- Branch: `v2-port` (Portierung). `master` bleibt die lauffähige v1.
- Phase 0 (Bestandsaufnahme) und Phase 1 (Entwurf) sind abgeschlossen und freigegeben.
- **Phase 2 (Walking Skeleton) ist technisch abgeschlossen** (Pakete: `work_items/phase2/README.md`). Nicht gebaut: Triggerhost (WI-14, kommt früh in Phase 3, Entscheidung E6), Editor, echter Manager, echte Elemente; die GUI des Stubs ist nicht von Hand geprüft.
- **Phase 2b (Härtung vor Phase 3) ist abgeschlossen mit offenen Punkten** (WI-18 bis WI-29, Plan, Entscheidungen E1 bis E8 und Ergebnisse: `work_items/phase2b/README.md` und die Paketdateien). **Phase 3 ist nicht begonnen und braucht die Freigabe des Projektinhabers.** Der Phase-3-Plan (`work_items/phase3/README.md`) fehlt noch; ihn entwirft der Projektinhaber mit Claude. Offene Entscheidungen des Projektinhabers: `work_items/HANDOVER.md`, Abschnitt "Offene Entscheidungen" (nach dem Fix-Block nur noch E14 und die Freigabe von Phase 3).
- **Aktuell: **Fix-Block WI-30 bis WI-35 abgeschlossen, Abnahme grün** (WI-35 Zyklus 1, 2026-10-12, Code-Stand `2f2e6e5`: 10 parallele Läufe je 752 passed, seriell 752 passed, Fault 20x 505 passed, Stress 14 passed, keine roten Tests; `work_items/STATUS.md`, "Abnahmelauf WI-35, Zyklus 1"). F-37 bis F-42 und F-46 geschlossen. **Offen:** E14 (Manager-Fenster schließen, Phase 3), F-43 (Entscheidung des Projektinhabers), F-36 (Schließen empfohlen), F-45 und F-47 (beobachten: nicht reproduziert, Ursache nicht belegt). **Nächster Schritt:** der Phase-3-Plan mit dem Projektinhaber; Phase 3 nicht ohne Freigabe beginnen. Details zur Historie des Blocks (WI-30 bis WI-34, Entscheidungen E9 bis E15) in `work_items/phase2b/README.md`. Für Tests gilt `tests/support/timing.py` (`scaled()`: obere Zeitgrenzen sind im parallelen Lauf dreifach, im seriellen Lauf exakt; `doc/TESTSTRATEGIE.md`).
- **Neue Fähigkeiten seit Phase 2b:** nur 64 Bit (32 Bit wird mit Exit 2 abgewiesen); Worker-Pool (der Supervisor startet und beendet Worker auf Anfrage der Engine); Engine nutzt bei jedem Schritt die neueste Revision eines Flows und kennt die Richtlinie `wait`; Log des Supervisors und stderr der Kinder landen im Log; Rolle `debug` (Debug-Fenster, `--start=debug`, `--command=debug`) mit `cmd.diag.snapshot` in jeder Rolle und Absturzberichten (`Reports/` im Datenverzeichnis); `Debug.Dump` ersetzt die v1-Funktion `d()`; echte JSON-Booleans auf der Leitung; Architekturwächter `tools/arch_check.py` (Teil von `pytest`); Tests laufen parallel (`pytest.ini`, `-n auto`).
- **Einstiege:** Produkt `src/AutoHotFlow.ahk` (bindet `src/AhfBoot.ahk` ein). Testrollen (`echo`, `crasher`, `hanger`, `slow_shutdown`) gibt es nur im Testeinstieg `tests/integration/helpers/AutoHotFlowTest.ahk` mit `--test-roles`; `src/` bindet nichts aus `tests/` ein.
- Der v2-Code liegt unter `src/` (Rollen `supervisor`, `engine`, `storage`, `worker`, `manager`-Stub, `debug`), Tests unter `tests/`. Abweichungen von der Zielstruktur: `doc/ARCHITEKTUR.md` Abschnitt 8. Der v1-Stand liegt unverändert in `v1/` (temporär, nur Referenz, **nicht ändern**).
- Offene Funde und Messlücken: `work_items/STATUS.md` (Tabelle "Funde", Beobachtungsliste). Übergabe: `work_items/HANDOVER.md`. Statusbericht mit den Abschlussläufen: `work_items/STATUS.md`.

## Entscheidungen (verbindlich, Details in `doc/ARCHITEKTUR.md`)

- Prozesse statt Threads: `supervisor` (Hub), `storage`, `engine`, `triggerhost`, `manager`, ein `editor` pro offenem Flow, `worker`-Pool.
- IPC über Named Pipes (Rahmen: Längenpräfix + JSON, Weckruf per `PostMessage`), Sterntopologie über den Supervisor.
- Zeichnen im Editor-Prozess hinter der `Renderer`-Schnittstelle (später trennbar).
- Elemente laufen `inline` (Engine), `worker` (eigener Prozess) oder `trigger` (Triggerhost). Dialoge laufen nie in der Engine.
- Alte Flows (`.json`) und Variablen (`.ahfvd`/`.ahfvar`) müssen unverändert laden. Chrome-Paket entfällt.
- Tests: pytest als Treiber (e2e, Fault Injection, Stress) plus kleine AHK-Unit-Tests.

## Ordner

| Pfad | Zweck |
|---|---|
| `doc/` | dauerhafte Dokumentation (Architektur, Protokoll, Element-API v2, Teststrategie, Konventionen, Migration, How-to AHK v2) |
| `work_items/` | temporäre Arbeitsunterlagen: Analyse, Pläne, Spikes. Wird nach der Portierung gelöscht. |
| `v1/` | temporärer v1-Stand als Referenz. Wird nach der Portierung gelöscht. |
| `src/`, `tests/`, `tools/`, `assets/` | v2-Code, entstehen ab Phase 2 (Struktur siehe `doc/ARCHITEKTUR.md` Abschnitt 8) |

## Regeln für Änderungen

1. Vor jeder Aufgabe lesen: dieses Dokument, `doc/ARCHITEKTUR.md` (Abschnitte 1 bis 6), `doc/KONVENTIONEN.md`, danach das Dokument der eigenen Aufgabe. Bei AHK-v2-Code zusätzlich `doc/HOW-TO.md`.
2. Kein geteilter veränderlicher Zustand, nur Nachrichten. Jedes Datum hat genau einen Besitzer.
3. Kein blockierender Aufruf im Nachrichtenpfad (`MsgBox`, Datei-I/O, `RunWait`, `WinWait` ohne Timeout). Jede Anfrage hat ein Timeout.
4. Nichts in `v1/` ändern. Bewusste Abweichungen vom v1-Verhalten gehören in `doc/MIGRATION.md`.
5. Neue Nachrichtentypen gehören in `doc/PROTOKOLL.md`. Wer eine Schnittstelle ändert, passt das Dokument im selben Commit an.
6. Unterscheiden zwischen **verifiziert** (gelesen oder getestet), **vermutet** und **nicht geprüft**. Nichts über Code behaupten, den man nicht gelesen hat.
7. Kleine Commits, eine Änderung pro Commit. Die Commit-Nachricht beschreibt das Warum.
8. Elementcode darf die Engine nie zum Absturz bringen: jeder Aufruf unter `try/catch`, Fehler werden als Ergebnis `exception` gemeldet.
9. Schwierigkeiten und eigene Fehler bei der AHK-v2-Umsetzung gehören in `doc/HOW-TO.md`: was schwer war, was falsch war, was richtig funktioniert (Format siehe Datei). Das dient als Wissensbasis für andere Agenten. Einträge mit Status (verifiziert / vermutet / nicht geprüft) versehen.
10. **VS-Code-Tasks für den Projektinhaber:** Jeder Aufruf, den der Projektinhaber von Hand ausführen möchte (Tests, Starts der Anwendung oder einer Rolle, Werkzeuge, Handprüfungen aus einer Anleitung), bekommt einen Task in `.vscode/tasks.json`. Wer einen solchen Aufruf neu einführt oder ändert (neue Option, neue Rolle, neues Werkzeug, neue Testgruppe), ergänzt oder ändert den Task im selben Commit. Bezeichnung auf Deutsch mit Präfix (`Test:`, `Start:`, `Werkzeug:`, `Debug:`, `Testdaten:`, `Setup:`). Ausnahme zur Regel "AHK-Skripte nie direkt starten": Die `Start:`-Tasks starten `AutoHotkey64.exe` direkt, ohne `ahkrun.py` und ohne Timeout, weil der Projektinhaber die Anwendung bedient (ein Dialog blockiert dann, bis er ihn schließt). Für Agenten gilt weiter `ahkrun.py`.

## Werkzeuge in dieser Umgebung

- AHK v2: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` (mehrere Versionen installiert). Skripte immer mit `#Requires AutoHotkey v2.0`. **Nur 64 Bit** (E4): 32-Bit-Interpreter werden nicht unterstützt.
- Python 3.13 mit `psutil`. `pytest`, `pytest-timeout` und `pytest-xdist` sind zu installieren: `pip install -r tests/requirements.txt`.
- **Architekturwächter:** `python tools/arch_check.py` prüft `src/**/*.ahk` statisch gegen die Regeln aus `doc/KONVENTIONEN.md` Abschnitt 3 (Includes, Dialoge, Datei-I/O, Blockieren, `Critical`, leere `catch`, eine Klasse pro Datei). Läuft auch als `tests/test_architecture.py`. Begründete Ausnahmen: Kommentar `; arch-ok: <regel> <Begründung>` oder Liste `EXCEPTIONS` im Werkzeug.
- **Tests laufen standardmäßig parallel** (`pytest.ini`: `-n auto --dist loadgroup`, 8 Worker, rund 50 s statt 340 s). `python -m pytest tests -q` genügt. Seriell: `-n 0` (nötig zum Debuggen eines Einzeltests mit `-s`/`--pdb`). `-m stress`/`-m soak` laufen automatisch in einem Prozess (Messungen dürfen nicht parallel zu anderer Last laufen). Neue Testskripte (AHK), die mehrfach gleichzeitig laufen können, brauchen `#SingleInstance Off`, sonst öffnet AHK einen Rückfrage-Dialog.
- Messwerte AHK-v2-Prozess (Spike): Start ~30 ms, ~14 MB, 0 % CPU im Leerlauf. Named Pipe mit Weckruf: Round-Trip ~0,3 ms. Siehe `work_items/spikes/README.md`.
- Stolperstein: Beim Schreiben von Dateien über Shell-Heredocs können `\\` zu `\` zusammenfallen (Pipe-Namen!). Quelltext mit dem Editor-Werkzeug schreiben und Pipe-Namen aus Konstanten bauen.
- **AHK-Skripte nie direkt starten, sondern über `python tools/ahkrun.py [--timeout N] skript.ahk [args]`.** Ein unbehandelter AHK-Fehler oder eine `MsgBox` öffnet sonst einen Dialog, der den Aufruf für immer blockiert. `ahkrun.py` übergibt `/ErrorStdOut=UTF-8` (Ladefehler wie Syntaxfehler kommen auf stderr), fängt jeden trotzdem erscheinenden Dialog ab (Text und PNG-Screenshot in `%TEMP%\ahf_dialogs\`, den Pfad gibt das Tool aus), schließt ihn und beendet den Prozess. Exit-Codes: 97 Dialog abgefangen, 98 Timeout, 99 kein Interpreter. Die pytest-Läufe (`tests/`) nutzen denselben Wächter automatisch.
- Unbekannte Kommandozeilenoptionen (z. B. `--version`) nie an den AHK-Interpreter geben: er hält sie für einen Skriptnamen und zeigt einen Dialog.
- Eingebaute AHK-v2-Klassennamen nicht neu definieren (`TimeoutError`, `ValueError`, `OSError`, `TypeError`, `MemberError`, ...). Eigene Fehlerklassen tragen das Präfix `Ahf` (`AhfTimeoutError`).
- `.claude/commands/*` (lokal, nicht versioniert) beziehen sich noch auf die v1-Struktur.

## AHK-Hilfe online nachschlagen

Die lokale Hilfe (`C:\Program Files\AutoHotkey\v2\AutoHotkey.chm`) lässt sich nicht lesen, also die Online-Doku nutzen.

- Startseite (Inhaltsverzeichnis): `https://www.autohotkey.com/docs/v2/`
- Funktionsübersicht (alle Built-ins alphabetisch): `https://www.autohotkey.com/docs/v2/lib/index.htm`
- Einzelne Funktion/Befehl: `https://www.autohotkey.com/docs/v2/lib/<Name>.htm`, z.B. `lib/StrSplit.htm`
- Sprachkonzepte: `https://www.autohotkey.com/docs/v2/<Seite>.htm`, z.B. `Objects.htm`, `Hotkeys.htm`, `Functions.htm`
- Anker mit `#`, z.B. `lib/Math.htm#Abs`

Vorgehen:
1. Die Seite über WebFetch laden, mit einer konkreten Frage im `prompt` (z.B. "Syntax und Parameter von X").
2. Bei unbekanntem Namen zuerst `lib/index.htm` durchsuchen.
3. Die Doku ist AutoHotkey v2 und gilt für den neuen Code. Der Code unter `v1/` nutzt v1-Syntax (`#NoEnv`, `SetBatchLines`, Befehle ohne Klammern wie `MsgBox,`). Beim Lesen von v1-Code auf die Unterschiede achten.
