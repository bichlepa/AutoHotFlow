# WI-23 Diagnose I: Log des Supervisors, stderr der Kinder, Fehlermeldungen

Größe: M · Hängt ab von: WI-22 · Blockiert: WI-27, WI-28

## Ziel

Heute gehen gerade die wichtigsten Meldungen verloren: wer abgestürzt ist, wer hing, wer neu gestartet wurde, warum eine Rolle nicht startet. Nach diesem Paket landet jede Meldung jedes Prozesses im Log, und unbehandelte Fehler werden zentral gesammelt. Grundlage für den Absturzbericht (WI-28).

## Funde

- **Supervisor-Log geht ins Leere** [gelesen]: `AhfMain` setzt `Log.Configure(Role.ConsoleFn)`. Der Supervisor ist keine `Role` und konfiguriert keine andere Senke. Alle `Log.Write` des Supervisors (`children`, `hub`, `shutdown`, `supervisor`) gehen nur auf stderr. Wird AutoHotFlow per Doppelklick gestartet, gibt es kein stderr.
- **stderr der Kinder geht verloren** [gelesen]: `Children._Launch` startet mit `Run(cmd, , "Hide", &pid)`. Laut Kommentar in `Role.Console` hat eine so gestartete Rolle kein nutzbares stderr (F-05). Damit verschwinden Ladefehler (`/ErrorStdOut`), `Role.Console`-Zeilen (z. B. "ends with exit 4: hub not reachable") und letzte Worte vor einem Absturz. Der Supervisor sieht nur den Exit-Code.
- **Unbehandelte Fehler** werden in jeder Rolle nur geloggt (`Role.OnUnexpectedError`, Rückgabe 1 = weiterlaufen). Eine Rolle mit dauerhaft kaputtem Zustand läuft so als Zombie weiter, und niemand sammelt die Fehler.

## Aufgaben

### 1. Log des Supervisors

- Eigene Senke im Supervisor: Einträge gehen als `evt.log.append` direkt über den Hub an `storage` (Quelle wie bisher, Absender `supervisor`), solange `storage` verbunden ist; sonst in eine Warteschlange (Obergrenze wie `Role.LOG_QUEUE_MAX`), die beim `evt.process.ready` von `storage` geleert wird. Zusätzlich weiter auf die Konsole.
- Rekursion verhindern: Ein Fehler beim Senden darf nicht wieder in die Senke loggen (Flag).

### 2. stderr und stdout der Kinder mitlesen

- `Children._Launch` startet über `CreateProcessW` (DllCall) statt `Run`: `STARTF_USESTDHANDLES`, `hStdOutput` und `hStdError` = Schreibende einer anonymen Pipe (vererbbar), `hStdInput` = `NUL`, Fenster versteckt (`STARTF_USESHOWWINDOW`, `SW_HIDE`). Prozess- und Thread-Handle wie bisher verwenden (OpenProcess entfällt dann).
- Nur die nötigen Handles vererben (vorzugsweise `PROC_THREAD_ATTRIBUTE_HANDLE_LIST`, sonst sicherstellen, dass Hub-Pipes nicht vererbbar sind).
- Der Supervisor liest das Leseende im Tick ohne Blockieren (`PeekNamedPipe`, dann `ReadFile` der verfügbaren Bytes), zerlegt in Zeilen (UTF-8), schreibt sie als Log-Einträge (Quelle `<kind>`, Level `a0` für stderr) und hält je Kind einen Ringpuffer der letzten 100 Zeilen, der auch nach dem Prozessende erhalten bleibt (für WI-28).
- Beim Prozessende den Rest lesen, dann Handles schließen.
- `Role.Console` bleibt `try`-geschützt (F-05), schreibt aber jetzt tatsächlich irgendwohin.

### 3. Ringpuffer und Level

- `Log` (`src/core/Log.ahk`) hält zusätzlich die letzten N Einträge (z. B. 500, alle Level) im Speicher, unabhängig von der Senke (für WI-28).
- Schwelle für das Weiterleiten an `storage`: Option `--log-level=<0..3>` (Standard 2; Ebene 3 nur im Ringpuffer). Der Supervisor gibt sie an die Rollen weiter. Später eine Einstellung (Phase 3).

### 4. Unbehandelte Fehler zentral

- `Role._OnUnexpected` sendet zusätzlich `evt.diag.error {name, errorType, message, file, line, stack, mode}` an `supervisor` (`e.Stack` nutzen). Der Supervisor loggt und hält die letzten 50 in einem Ringpuffer.
- Schwelle: Mehr als 20 unbehandelte Fehler in 60 s → die Rolle beendet sich mit einem neuen Exit-Code (Vorschlag 6, "too many unexpected errors"). Für `engine` und `storage` greift dann die Neustartregel. Konstanten im Paket begründen.

## Tests

- Supervisor-Meldungen (z. B. "started engine") stehen in `Log/Log.txt` des Datenverzeichnisses.
- Eine Rolle, die auf stderr schreibt (Testrolle `echo`, neuer Testbefehl oder bestehendes `cmd.test.*`), erzeugt eine Logzeile mit ihrem Text.
- Ein Kind mit Startfehler (z. B. unbekannte Rolle, Exit 2) hinterlässt seine Meldung im Log.
- Handles des Supervisors bleiben flach über 50 Neustarts (`crasher`).
- `evt.diag.error` kommt beim Supervisor an (Testrolle `echo`, `cmd.test.throwlater`); die Schwelle beendet die Rolle mit dem neuen Exit-Code.

## Doku

`doc/PROTOKOLL.md` (`evt.diag.error`, Exit-Code, `--log-level`), `doc/ARCHITEKTUR.md` 6.2 (Fehlerbehandlung), `doc/KONVENTIONEN.md` (klarstellen: das Mitlesen von stderr ist keine Datei-I/O, der Supervisor liest anonyme Pipes), `doc/HOW-TO.md` (CreateProcessW mit umgeleiteten Handles).

## Ergebnis

Status: Punkte 1 bis 4 abgeschlossen (2026-10-11). Kennzeichnung: **verifiziert** = gelaufen oder gelesen, **vermutet**, **nicht geprüft**. Keine Eskalation.

Commits: `b47f42c` (Punkt 1), `6892034` (Punkt 2), `04bf3af` (Punkt 3), `f0878c2` (Punkt 4). Dokumentation und HOW-TO-Einträge stehen in den jeweiligen Commits, dieser Abschnitt und der Haken im Abschlusscommit.

### Punkt 1: Log des Supervisors [verifiziert]

- Neue Klasse `DiagLog` (`src/supervisor/DiagLog.ahk`): Senke für `Log` im Supervisor. Jeder Eintrag geht auf die Konsole (stderr) und als `evt.log.append` (Absender `supervisor`) über den Hub an `storage`, solange `storage` verbunden ist; sonst in eine Warteschlange (`Role.LOG_QUEUE_MAX` = 500, älteste fallen heraus, gezählt), die `Supervisor._OnHello` beim `sys.hello` von `storage` leert. Ein neuer Eintrag überholt die Warteschlange nicht. Das Flag `busy` verhindert Rekursion, wenn das Senden selbst loggt.
- Tests: `tests/fault/test_diagnose.py::test_the_messages_of_the_supervisor_are_in_the_log_file` (rot vorher: `Log.txt` enthielt nur die Zeile von `storage`; grün nachher: "started storage", "started echo:a", "client 'echo:a' connected" von `~supervisor~`). `tests/ahk/diag_log.test.ahk`: Warteschlange bis `storage` da ist, Reihenfolge, Obergrenze mit Zähler, abgelehnter Eintrag bleibt, keine Rekursion (5 Fälle).

### Punkt 2: stderr und stdout der Kinder [verifiziert]

- `ChildLauncher` (`CreateProcessW` per `DllCall`, anonyme Pipe, `NUL` als stdin, `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` mit genau zwei Handles, Fenster versteckt) und `ChildPipe` (Lesen ohne Blockieren mit `PeekNamedPipe`/`ReadFile`, Zeilen an Byte 0x0A, dann UTF-8, Rest ohne Zeilenende beim Ende). `Children._Launch` nutzt sie statt `Run`/`OpenProcess`; `Children.Tick` liest je Tick, `_OnGone` liest den Rest und schließt Pipe und Handle. Je Kind ein Ringpuffer der letzten 100 Zeilen (`Children.Output(name)`), er bleibt nach dem Prozessende.
- Log-Eintrag je Zeile: Level `a0`, Quelle = Rolle (`echo`, nicht `echo:a`, damit es in `Log_echo.txt` landet), Text `[echo:a] <Zeile>`. **stdout und stderr sind eine gemeinsame Pipe**, es gibt also keine Unterscheidung nach Strom (alles `a0`).
- Grenzen je Kind und Tick (begründet im Code): 64 KB gelesen, 200 Zeilen geloggt, der Rest nur im Ringpuffer mit einer Hinweiszeile. Pipe-Puffer 256 KB, damit ein Kind beim Schreiben nicht auf den Tick (200 ms) wartet.
- Die Logzeile eines Absturzes nennt jetzt die Bedeutung bekannter Exit-Codes (`Children.EXIT_TEXT`, z. B. "exit 3: role not implemented").
- `Role.Console` bleibt `try`-geschützt (F-05); der Kommentar sagt jetzt, dass vom Supervisor gestartete Rollen ein lesbares stderr haben.
- Tests: `test_a_line_on_stderr_of_a_child_becomes_a_log_line` (Umlaute und U+2713; rot vorher, grün nachher), `test_a_child_that_fails_to_start_leaves_its_message_in_the_log` (Manager ohne `--ui`: "no UI selected" und "exit 3" im Log; rot vorher), `test_the_exit_of_a_killed_child_is_in_the_log`, `tests/ahk/child_launcher.test.ahk` (10 Fälle: stdout und stderr, `NUL` als stdin, Exit-Code, fehlgeschlagener Start ohne Leck, **40 Starts ohne Handle-Zuwachs**, UTF-8-Zeichen über Lesegrenzen, unvollständige Zeile, leere Zeilen, überlange Zeile, geschlossener Leser), `tests/ahk/children_output.test.ahk` (4 Fälle).
- **Handle-Test über 50 Neustarts** (`test_the_handles_of_the_supervisor_stay_flat_over_50_restarts`, Testrolle `crasher`; Handles des Supervisors nach 5 und nach 50 Neustarts: **179 und 179**, Dauer 54 s). Dazu die Testoption `--restart-max=<n>` (nur mit `--test-roles`), weil die Neustartregel sonst bei 3 anhält. **Der Test war nicht rot zu bekommen**: Auch der alte Weg (`Run` plus `OpenProcess` plus `CloseHandle`) verlor keine Handles; er sichert die Umstellung ab.
- **Nicht geprüft:** dass ein Kind wirklich keine anderen Handles erbt (die Handle-Tabelle eines fremden Prozesses ist aus dem Test nicht einfach lesbar). Gelesen: Die Hub-Pipe ist ohnehin nicht vererbbar (`CreateNamedPipeW` ohne Sicherheitsattribute), und die Handle-Liste begrenzt die Vererbung auf `hWrite` und `NUL`. Ein Kind mit eigener Konsole nicht geprüft (AHK-Rollen haben keine).

### Punkt 3: Ringpuffer und Level [verifiziert]

- `Log` hält die letzten 500 Einträge aller Ebenen (`Log.Recent(n)`, Kopien), unabhängig von der Senke. `Log.level` (Bibliotheksstandard 3 = alles, damit Werkzeuge und Unit-Tests unverändert laufen) wird von `Role.Start` und vom Supervisor auf den Wert von `--log-level` gesetzt (Standard `Log.DEFAULT_LEVEL` = 2). Ein Eintrag über der Schwelle geht nicht an die Senke. `--log-level` ungültig: Rolle Exit 2, Supervisor Exit 1.
- Tests: `tests/ahk/core_log.test.ahk` (+6 Fälle: Ring 500, Ring ohne Senke, Kopien, Schwelle, Stufe 0, `ParseLevel`), `test_the_log_level_decides_what_is_forwarded_to_storage` (drei Stufen: Standard, 0, 3; prüft Rolle **und** Supervisor), `test_a_bad_log_level_is_refused`. Vorher rot (Stand ohne die `src/`-Änderung, per `git stash`): alle vier.

### Punkt 4: unbehandelte Fehler zentral [verifiziert]

- `Role._OnUnexpected` zählt, sendet `evt.diag.error {name, errorType, message, file, line, stack, mode}` (Stack auf 4000 Zeichen gekürzt), ruft den Hook und beendet die Rolle mit **Exit 6** (`Role.EXIT_TOO_MANY_ERRORS`), wenn mehr als `ERROR_LIMIT` = 20 Fehler innerhalb `ERROR_WINDOW_MS` = 60000 ms gezählt sind. Begründung der Konstanten: Eine gesunde Rolle hat keinen unbehandelten Fehler; ein kaputtes Element oder ein Timer wirft ein paar Mal hintereinander; 21 in einer Minute heißt, der Zustand ist kaputt und ein Neustart ist besser als ein Zombie. Das Fenster verhindert, dass seltene Fehler über ein langes Leben aufsummiert werden. Für `engine` und `storage` greift danach die vorhandene Neustartregel, andere Rollen werden als abgestürzt gemeldet.
- Der Supervisor (`DiagLog.AddError`, Handler `evt.diag.error` in `Supervisor._Wire`) loggt `a0` (Quelle `diag`) und hält die letzten 50 (`DiagLog.Errors()`). Eigene unbehandelte Fehler des Supervisors kommen in denselben Ring.
- Tests: `test_an_unhandled_error_arrives_at_the_supervisor`, `test_too_many_unhandled_errors_end_the_role_with_exit_6` (21 Fehler: `exitCode` 6, "too many unexpected errors" im Log), `test_exactly_the_threshold_does_not_end_the_role` (20 Fehler: Rolle antwortet weiter), `tests/ahk/diag_log.test.ahk` (+7 Fälle: Ring 50, Logzeile, fehlende Felder, Payload eines echten Fehlers mit Stack, lange Stacks, Schwelle genau und darüber, alte Fehler verlassen das Fenster). Vorher rot (ohne `src/`-Änderung): alle drei.
- Testrolle `echo` neu: `cmd.test.stderr {text}`, `cmd.test.log {count, level, text}`, `cmd.test.throwlater {count}` (PROTOKOLL 4.1b).

### Läufe

- Vollständiger Lauf **seriell** (`python -m pytest tests -q -n 0`): **550 passed, 1 skipped, 11 deselected in 527 s** [verifiziert, Stand `f0878c2`]. `tools/arch_check.py`: 64 Dateien, 0 Verstöße.
- Vollständiger Lauf **parallel** (`python -m pytest tests -q`): **550 passed, 1 skipped in 63 s** (Stand `f0878c2`). Davor zwei parallele Läufe mit Fehlschlägen: (a) 3 failed (`test_diagnose.py`: `test_a_child_that_fails_to_start...`, `test_a_line_on_stderr...`, `test_the_messages_of_the_supervisor...`), (b) 2 failed (`..._fails_to_start...`, `..._messages_of_the_supervisor...`) und 1 error (`test_ui_stub.py::test_engine_restart_is_seen_and_resynced_without_restarting_the_stub`), alle mit "no answer to obs#1 within 2.0 s" beim Verbinden (keine Zeitbudget-Assertion: der Hub beantwortete das `sys.hello` 15 s lang nicht). Ein weiterer Lauf von `test_diagnose.py` allein mit `-n 8` zeigte 4 bis 7 Fehlschläge desselben Musters. **Ursache nicht gefunden.** Ein Vergleich spricht gegen meine Änderungen: Ein Scratch-Test (16 Starts von `storage,echo:a`, `-n 8`) lief in einem Worktree auf allen vier Commits dieses Pakets und auf `2da8beb` jeweils grün (16 von 16 in 4 bis 6 s); im Arbeitsverzeichnis zuerst 4 Fehlschläge in 35 s, wenige Minuten später 16 von 16 in 4,4 s, ohne Quelländerung dazwischen. Vermutet: Last auf der Maschine, zeitgleich mit den Resten eines mit Timeout abgebrochenen Testlaufs; nicht nachgewiesen. Danach liefen `test_diagnose.py -n 8` (12 von 12 in 57 s) und der Gesamtlauf grün.
- Zeitbudgets: keine Frist einer bestehenden Assertion wurde geändert. Die neuen Tests warten auf Ereignisse (`wait_for_log`, `wait_restarted_ready`, `chain.rec.wait`) statt auf feste Zeiten; die Grenzen (15 s) sind großzügig. Der 50-Neustarts-Test hat `timeout(240)` (Laufzeit 54 s).
- Keine Testprozesse übrig (nur die fremden `AutoHotkeyU32.exe` und ein `AutoHotkey64.exe` ohne Argumente des Projektinhabers, nicht angefasst).

### Abweichungen vom Plan

- Der Auftrag nennt als Quelle der stderr-Einträge `<kind>`; umgesetzt ist die Rolle ohne Flow-Anteil (`echo`), der Kindname steht im Text.
- `Run`/`OpenProcess` durch `CreateProcessW` ersetzt; `Children.OPEN_ACCESS` bleibt, weil Unit-Tests damit Handles öffnen.
- Neue Dateien `ChildLauncher.ahk`, `ChildPipe.ahk`, `DiagLog.ahk` (je eine Klasse) in `src/supervisor/`.
- Änderungen in `src/core/`: `Log.ahk` und `Role.ahk` (vom Paket genannt), sonst keine.
- F-16 (Fristen laufen nach der Wanduhr) nicht bearbeitet; lag nicht im Pfad.

### Neue Funde

- **F-20: Meldungen des Supervisors nach dem Weggang von `storage` gehen nicht ins Log.** Beim Beenden verlässt `storage` die Sitzung zuletzt; was der Supervisor danach loggt ("shutdown: finished", "ends with exit"), steht nur auf stderr (die Warteschlange wird nie mehr geleert). Auch bei einem Absturz des Supervisors geht die Warteschlange verloren. Gelesen, die fehlenden letzten Zeilen in `Log.txt` gesehen. Bei Bedarf in WI-28 (Absturzbericht) mitnehmen.
- **F-21: Gesprächiges Kind kann `storage` fluten.** Die Grenze je Tick (200 Zeilen je Kind) bremst, aber 200 Zeilen je 200 ms liegen weit über dem Durchsatz von `storage` (F-08, rund 30 Zeilen/s). Nicht gemessen. Mit WI-25 prüfen.
- **F-22: stdout und stderr der Kinder sind nicht unterscheidbar** (eine Pipe, alles `a0`). Reicht für die Diagnose; ein getrenntes stdout bräuchte eine zweite Pipe.
- Zwei HOW-TO-Funde ohne F-Nummer: Ein Closure ohne erfasste Variable ist dasselbe Funktionsobjekt (`SetTimer` setzt nur neu), und ein Parameter `log` verdeckt die Klasse `Log`.

### HOW-TO-Einträge dieses Pakets (Status)

- "CreateProcessW mit umgeleiteten Handles statt Run": verifiziert, bis auf die Vererbung fremder Handles (nicht geprüft).
- "Ein Closure ohne erfasste Variable ist immer dasselbe Funktionsobjekt": verifiziert.
- "Ein Parameter `log` verdeckt die Klasse `Log`": verifiziert.
- "OnError-Handler und `mode`": verifiziert für `Exit`; `Return` und `ExitApp` nicht einzeln getestet.

### Offene Punkte

- F-20 bis F-22 in `STATUS.md` übertragen (WI-29). F-16 bis F-19 bleiben offen (WI-22).
- Parallelen Lauf auf ruhiger Maschine mehrfach wiederholen; die zwei Fehlläufe oben bleiben unerklärt.
- Zweiter Windows-Benutzer und Vererbung fremder Handles: nicht geprüft.
