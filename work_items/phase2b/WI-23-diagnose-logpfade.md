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
