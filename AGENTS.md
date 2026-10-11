# AGENTS.md

## Worum es geht

AutoHotFlow (AHF) wird von AutoHotkey v1 (AutoHotkey_H mit `AhkThread`) auf **AutoHotkey v2** portiert. Dabei wird die Architektur so umgebaut, dass die bisherigen Deadlocks und Race Conditions konstruktiv nicht mehr entstehen: **mehrere Prozesse mit Nachrichtenaustausch, kein geteilter Speicher, kein globales Lock**.

Gesprochene Sprache mit dem Projektinhaber: Deutsch. Dokumentation: Deutsch. Code und Code-Kommentare: Englisch.

## Aktueller Stand

- Branch: `v2-port` (Portierung). `master` bleibt die lauffähige v1.
- Phase 0 (Bestandsaufnahme) und Phase 1 (Entwurf) sind abgeschlossen und freigegeben.
- **Phase 2 (Walking Skeleton) ist technisch abgeschlossen** (Pakete: `work_items/phase2/README.md`). Es laufen Supervisor, Storage, Engine, Worker-Pool und ein UI-Stub (`manager --ui=stub`) mit den Elementen aus `src/elements/skeleton/`. Fault-Injection- und Stresstests sind grün. **Nicht gebaut:** Triggerhost (WI-14, optional), Editor, echter Manager, echte Elemente; die GUI des Stubs ist nicht von Hand geprüft.
- **Aktuell: Phase 2b (Härtung vor Phase 3)**, Plan und Entscheidungen des Projektinhabers (E1 bis E8) in `work_items/phase2b/README.md`, Pakete WI-18 bis WI-29 in Reihenfolge abarbeiten. Phase 3 ist noch nicht begonnen und braucht die Freigabe des Projektinhabers.
- Der v2-Code liegt unter `src/` (Rollen `supervisor`, `engine`, `storage`, `worker`, `manager`-Stub), Tests unter `tests/`. Abweichungen von der Zielstruktur: `doc/ARCHITEKTUR.md` Abschnitt 8. Der v1-Stand liegt unverändert in `v1/` (temporär, nur Referenz, **nicht ändern**).
- Offene Funde (F-06, F-08) und Messlücken: `work_items/STATUS.md`. Übergabe: `work_items/HANDOVER.md`.
- Statusbericht: `work_items/STATUS.md`.

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

## Werkzeuge in dieser Umgebung

- AHK v2: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` (mehrere Versionen installiert). Skripte immer mit `#Requires AutoHotkey v2.0`.
- Python 3.13 mit `psutil`. `pytest`, `pytest-timeout` und `pytest-xdist` sind zu installieren: `pip install -r tests/requirements.txt`.
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
