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

## Ergebnis

Stand: umgesetzt, Testlauf grün (`pytest tests -q`: 318 passed, 1 skipped, 125 s). Commits: `6bcb290` (Kern, Hub, Registry, Testrollen), `16fbc6a` (Tests), Doku-Commit siehe `git log`.

### Abweichungen vom Plan (mit Begründung)

- **Supervisor ist keine Role.** Der Eintrag `RoleRegistry.Register("supervisor", ...)` ist entfernt. Der Einstieg (`src/AutoHotFlow.ahk`) startet `Supervisor.Run` direkt. Begründung: der Supervisor betreibt den Hub und hat keinen eigenen Peer, `Role` setzt einen Peer voraus.
- **Session-Default `main`** statt PID und Startzeit. Begründung in `doc/PROTOKOLL.md`, Abschnitt 1: die zweite Instanz muss den Hub finden.
- **Exit-Code 5** (Kind wurde nach Frist oder Hang beendet). Im Plan nicht festgelegt, jetzt in `doc/PROTOKOLL.md` 4.1 und im Einstieg dokumentiert.
- **`OpenProcess` mit SYNCHRONIZE, PROCESS_QUERY_LIMITED_INFORMATION und PROCESS_TERMINATE** (`0x00101001`) statt nur SYNCHRONIZE. Begründung: Exit-Code lesen (QUERY) und hart beenden (TERMINATE) nach Frist. Ohne diese Rechte wären beide Schritte nicht möglich.
- **`crasher` startet nur unter `--test-roles` neu** (`Children.TEST_AUTO_RESTART`). Produktiv gilt nur `storage` und `engine` als automatisch neu startbar. `manager` und `editor` nie.
- **Arm-Protokoll `cmd.test.arm`** im Absturztest: der Test muss den Prozess beobachten, bevor er stirbt. Ohne Arm stirbt `crasher` nicht.
- **Ereignisse vor dem Abonnement** gehen verloren (PROTOKOLL 5a). Späteinsteiger holen den Zustand über `cmd.process.list`. Dies war im Plan nicht vorgesehen.

### Akzeptanzkriterien

| Kriterium | Test | Gemessen |
|---|---|---|
| Start: Pflichtrollen bereit unter 3 s | `test_required_roles_are_ready_within_3_seconds` | grün, Messwert nicht festgehalten |
| Weiterleitung unverändert, `from` nicht fälschbar | `test_message_is_routed_unchanged_and_from_cannot_be_forged` | grün |
| Absturz: `crashed` innerhalb 1 s, Neustart nach Richtlinie, andere unberührt | `test_crashed_child_is_reported_within_1s_restarted_by_policy_and_others_are_untouched` | Meldung 0,09 bis 0,17 s nach dem Tod |
| Hänger (`suspend`): `hung` innerhalb 8 s, beendet | `test_frozen_child_is_hung_within_8s_and_ended_like_a_crash` | 6,1 s (Grenze 8 s) |
| Beenden sauber unter 2 s, keine Reste | `test_clean_exit_with_healthy_children_within_2s_and_no_leftover_process` | grün, Messwert nicht festgehalten |
| Beenden mit eingefrorenem Prozess unter Frist + 1 s | `test_frozen_child_at_exit_is_terminated_at_the_deadline` | grün |
| Zweite Instanz sendet Befehl, erzeugt keine Hub-Pipe | `test_second_instance_forwards_the_command_and_creates_no_hub` | grün |
| Weitere Tests | `test_slow_child_is_waited_for_and_not_terminated`, `test_a_manager_can_cancel_the_exit_in_the_prepare_phase`, `test_test_roles_are_unknown_without_the_flag` | grün |

### Nicht geprüft oder offen

- Stresswiederholung (viele Läufe nacheinander) und Last: nicht geprüft. Das ist WI-16.
- Langsamer Rechner: nicht geprüft. Alle Zeitgrenzen gelten für den Entwicklungsrechner.
- Shutdown-Gruppen (Reihenfolge UI, storage zuletzt): nur im Code gelesen (`Children.ShutdownGroups`), kein eigener Test.
- Fremder Prozess mit gleicher Session: nicht geprüft. Der Mutex-Name ist nur durch die Session eindeutig, kein Schutz gegen fremde Prozesse.
- `Hub.Request` hat keinen eigenen Timer. Für `cmd.app.prepareExit` ist das gewollt (Phase 1 wartet ohne Frist, Abbruch durch den Benutzer), für andere Anfragen des Supervisors gilt die Regel „jede Anfrage hat ein Timeout“ (`doc/KONVENTIONEN.md`, Abschnitt 4) nicht. Offen, vor WI-10 zu klären.
- Die Testdatei `test_procs.py` wurde im Commit `16fbc6a` ungenau beschrieben (Commit-Nachricht nennt eine Hilfsfunktion, tatsächlich ist es eine Status-Abfrage mit Polling in `test_suspend_and_resume`). Nur die Nachricht ist falsch, der Code ist korrekt.
