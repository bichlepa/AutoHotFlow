# WI-07 Supervisor (Hub, Überwachung, Beenden)

Größe: L · Hängt ab von: WI-06 · Blockiert: WI-15

## Ziel

Der Supervisor startet die Rollen, routet Nachrichten, erkennt Absturz und Hänger und führt das zweiphasige Beenden. Er enthält keine Fachlogik und blockiert nie.

## Vorher lesen

`doc/ARCHITEKTUR.md` 3, 5.3, 6 (vollständig), `doc/PROTOKOLL.md` 1, 3, 4.1, 5.

## Zu erstellen (`src/supervisor/`)

- `Supervisor.ahk` (Rolle `supervisor`, erbt nicht von `Role`, weil sie den Hub betreibt, nutzt aber `Args`, `Log`, `Ids`):
  - Einzelinstanz per benanntem Mutex (`CreateMutexW`). Zweite Instanz sendet `cmd.app.command` und endet (`--command=<text>` genügt in Phase 2).
  - Session-ID, Hub-Pipe `\\.\pipe\ahf.<session>.hub`.
- `Hub.ahk`: `PipeListener` + Verbindungsliste. Handshake `sys.hello`/`sys.welcome` (Name, pid, hwnd). Routing nach `to`, `from` wird aus der Verbindung gesetzt. Topics (`cmd.topic.subscribe`, Verteilung von `evt.*` an Abonnenten). Pro Client Sendewarteschlange mit Obergrenze (aus WI-04), Überlauf → Client als hängend markieren.
- `Children.ahk`: `Spawn(role, args)` mit `Run(..., , "Hide", &pid)`, Handle per `OpenProcess(SYNCHRONIZE)`, Überwachung per Timer (`WaitForSingleObject(h, 0)`). Zustände nach ARCHITEKTUR 5.3 (`starting`, `ready`, `stopping`, `exited`, `hung`, `crashed`). Neustart-Richtlinie je Rolle (max. 3 in 60 s, `storage` und `engine` neu starten, `manager`/`editor` nicht automatisch).
- `Heartbeat.ahk`: `sys.ping` alle 2 s je Kind, 3 verpasste Antworten → `hung` → `sys.shutdown`, nach 2 s `TerminateProcess` → wie `crashed`.
- `Shutdown.ahk`: Phase 1 `cmd.app.prepareExit` an UIs (Antwort `cancel` möglich), Phase 2 `sys.shutdown` mit `deadlineMs`, Reihenfolge der Quittungen nach ARCHITEKTUR 6.3, harte Beendigung nach Frist, Rückmeldung per Exit-Code.
- `evt.process.*` Ereignisse auf Topic `process`: `started`, `ready`, `crashed`, `hung`, `restarted`, `exited`.
- Orphan-Guard-Gegenstück: Wird der Supervisor beendet, verlieren Kinder ihre Verbindung (Test in WI-15).

Phase 2 darf die Tray-Funktion weglassen. Der Supervisor startet in Phase 2 `storage`, `engine`, optional `triggerhost`, und einen UI-Stub, wenn `--ui=stub` übergeben wird.

## Akzeptanzkriterien

- Start: nach `evt.process.ready` aller Pflichtrollen ist das System bereit, Gesamtzeit unter 3 s auf Entwicklungsrechner.
- Weiterleitung: Nachricht von A an B kommt unverändert an, `from` kann nicht gefälscht werden.
- Absturz einer Kindrolle: `evt.process.crashed` innerhalb 1 s, Neustart nach Richtlinie, andere Kinder unberührt.
- Hänger (`suspend`): als `hung` erkannt innerhalb 8 s (3 Pings × 2 s + Toleranz), beendet, behandelt wie Absturz.
- Beenden: sauber unter 2 s bei gesunden Prozessen, mit einem eingefrorenen Prozess unter Frist + 1 s. Es bleiben keine Kindprozesse zurück.
- Zweite Instanz: sendet Kommandozeile, beendet sich, zweite Hub-Pipe wird **nicht** erzeugt.

## Tests

`tests/integration/test_supervisor.py` mit einfachen Test-Rollen (`echo`, `crasher`, `hanger`, `slow_shutdown`) aus `tests/integration/helpers/`. Die Test-Rollen dürfen in der Rollenregistrierung nur bei `--test-roles` verfügbar sein.

## Nicht Teil

Tray-Symbol, Autostart, Installer.

## Hinweise

- `TerminateProcess` nur nach vorheriger Aufforderung und Frist (ARCHITEKTUR 6.3).
- Keine blockierenden Aufrufe wie `RunWait` oder `ProcessWaitClose` mit Timeout > 0 im Supervisor.
- Kinder als Rollen mit `--hub`, `--session`, `--data` starten, den Rest über Nachrichten konfigurieren.
