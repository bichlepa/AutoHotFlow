# WI-06 Einstieg und Rollenbasis

Größe: S · Hängt ab von: WI-05 · Blockiert: WI-07, WI-10 bis WI-14

## Ziel

Ein einziger Einstieg startet jede Rolle. Eine Basisklasse nimmt den gemeinsamen Lebenszyklus ab (Argumente, Verbindung zum Hub, Standardhandler, Beenden, Orphan-Guard).

## Vorher lesen

`doc/ARCHITEKTUR.md` 3, 6.1 bis 6.3, `doc/PROTOKOLL.md` 4.1.

## Zu erstellen

- `src/AutoHotFlow.ahk`: parst `A_Args` mit `Args.Parse`. `--role=<name>` wählt die Rolle. Ohne `--role` oder mit `supervisor` die Supervisor-Rolle (kommt in WI-07). Unbekannte Rolle: Exit-Code 2 mit Meldung in die Log-Senke (kein `MsgBox`).
- Rollenregister: `RoleRegistry.Register("engine", EngineRole)` in `src/core/RoleRegistry.ahk`. Die Rollendateien werden **per `#Include` im Einstieg** eingebunden (keine dynamische Ladung). Platzhalter-Einträge für noch nicht vorhandene Rollen sind erlaubt (Platzhalter-Klasse, die „not implemented“ meldet).
- `src/core/Role.ahk`: Basisklasse wie in `README.md`. Pflichten:
  - Peer erzeugen (`name` aus `--role` und optional `--flow`), verbinden, `OnReady()` aufrufen.
  - Standardhandler: `sys.ping`/`pong` (im Peer), `sys.shutdown` → `OnShutdown(deadlineMs)` → danach `sys.bye` und `ExitApp`.
  - **Orphan-Guard:** Verbindung zum Hub verloren und nicht wiederhergestellt → nach 3 s `ExitApp`.
  - Log-Senke: Rollen senden `evt.log.append` an `storage` (sobald vorhanden), vorher in Warteschlange (max. 500 Einträge).
  - Unerwartete Exceptions: global `OnError`, loggen, Rolle bleibt wenn möglich laufend (Policy pro Rolle überschreibbar).

## Akzeptanzkriterien

- `--role=nonexistent` beendet mit Exit-Code 2, keine Dialoge.
- Eine Test-Rolle (`--role=echo`, in `tests/integration/helpers/EchoRole.ahk`, nur für Tests) verbindet sich mit einem Python-Hub, beantwortet `cmd.test.echo`, beendet sich auf `sys.shutdown` mit `sys.bye` und Exit-Code 0 innerhalb 1 s.
- Hub wird beendet: Rolle beendet sich nach höchstens 3 s + Wiederverbindungsfrist, kein verwaister Prozess (Test mit `psutil`).

## Tests

`tests/integration/test_role.py`.

## Nicht Teil

Supervisor-Logik, echte Rollen.

## Hinweise

- `#SingleInstance Off` im Einstieg.
- `Persistent` im Rollenkontext setzen, damit der Prozess ohne GUI am Leben bleibt.

## Ergebnis

Stand: WI-06 umgesetzt, **nicht committet**. `python -m pytest tests -q`: `308 passed, 1 skipped in 71.40s (0:01:11)`. Danach keine von den Tests gestarteten AutoHotkey-Prozesse übrig (siehe Offene Punkte zu einem fremden Prozess).

Erstellt:

- `src/AutoHotFlow.ahk`: Einstieg. Parst `A_Args`, wählt die Rolle, `AhfMain`/`AhfExit`.
- `src/core/Role.ahk`: Basisklasse (Lebenszyklus, sys.shutdown, Orphan-Guard, Log-Warteschlange, OnError-Policy).
- `src/core/RoleRegistry.ahk`: Register/Lookup, `PlaceholderRole` und Platzhalter für `supervisor`, `storage`, `engine`, `triggerhost`, `manager`, `editor`, `worker`.
- `tests/integration/helpers/EchoRole.ahk`: Testrolle `echo` (Befehle `cmd.test.*`, nur für Tests).
- `tests/integration/test_role.py`: 9 Tests.
- Geändert: `doc/HOW-TO.md` (7 Einträge), `work_items/phase2/README.md` (Vertrag Role/RoleRegistry, Exit-Codes).

Akzeptanzkriterien und Beleg:

- `--role=nonexistent` beendet mit Exit 2, kein Dialog, Meldung auf stderr: `test_unknown_role_exits_2_with_message_and_no_dialog` (ahkrun würde bei einem Dialog 97 liefern).
- Echo-Rolle verbindet sich, beantwortet `cmd.test.echo`: `test_echo_role_says_hello_and_answers_a_command`.
- `sys.shutdown` → `sys.bye {clean:true}` und Exit 0 innerhalb 1 s: `test_shutdown_sends_bye_and_exits_0_within_one_second`. Gemessen: Exit 0 nach 239 ms.
- Hub beendet → Rolle endet mit Exit 4, kein verwaister Prozess (psutil, `pid_exists` false, ahkrun beendet): `test_hub_gone_role_ends_within_orphan_budget_and_leaves_no_process`. Gemessen: 3,25 s nach dem Stopp des Hubs.
- Weitere Pflichten: `sys.ping`/`pong` (`test_ping_is_answered_by_the_peer`), fehlende Argumente Exit 2 (`test_missing_connection_arguments_exit_2`), nicht implementierte Rolle Exit 3 (`test_role_without_implementation_reports_not_implemented`), Fehler im Timer wird geloggt, Rolle läuft weiter (`test_error_in_a_timer_is_logged_and_the_role_keeps_running`), Log-Warteschlange max. 500 mit Zählung der verworfenen Einträge und Versand an das Ziel `storage` (`test_log_queue_keeps_500_and_sends_them_when_storage_is_the_target`).

Stabilität: `tests/integration/test_role.py` fünfmal hintereinander grün (`9 passed` je Lauf, rund 10 s je Lauf). Vor der Korrektur war ein Lauf von fünf rot: der Test las stderr, bevor `ahkrun.py` es übernommen hatte (Wettlauf im Test, nicht im Rollencode). Behoben, siehe `test_hub_gone_...`.

Abweichungen vom Paket:

- Der Vertrag in `work_items/phase2/README.md` wurde nachgetragen: `RegisterHandlers`, `On`, `OnUnexpectedError`, `SetLogTarget`, `LogStats`, `Role.Current`, `Role.Console`, `Role.BaseName`, `RoleRegistry`, Exit-Codes 0 bis 4.
- Exit-Codes 1 (Start fehlgeschlagen), 3 (nicht implementiert) und 4 (Hub verloren oder Peer geschlossen) sind neu. Das Protokoll sieht keine Exit-Codes vor. Dokumentiert in README und im Kopf von `AutoHotFlow.ahk`.
- Konsolen-Log-Senke: `FileAppend(..., "**")` schreibt auf stderr, ohne Datei. Das ist eine bewusste Ausnahme zu KONVENTIONEN 3 (dort nur storage), begründet im HOW-TO-Eintrag.
- Die Konvention "eine Klasse pro Datei" ist in `RoleRegistry.ahk` verletzt: `RoleRegistry` und `PlaceholderRole` liegen in einer Datei. Die Schreibliste dieses Pakets ließ keine weitere Datei zu. Auslagern, sobald die Platzhalter ersetzt werden.
- `EchoRole.ahk` (Testrolle) wird per `#Include` im Produkteinstieg eingebunden, damit `--role=echo` mit dem Einstieg startet. Vor einem Build-Artefakt (WI-17) entscheiden, ob die Testrolle hinter einem Build-Schalter bleibt.
- `#Warn All` fehlt im Einstieg. Eine Warnung würde als Dialog erscheinen, und die Konvention nennt es nur für den Entwicklungsmodus.
- `Role.ConsoleFn` wird nicht direkt aufgerufen, sondern über `Role.Console` (HOW-TO, Eintrag "Funktion in einer Eigenschaft").
- Der Peer-Name ist `<role>` bzw. `<role>:<flow>` (z. B. `editor:Flow 1`), entsprechend der Adressierung im Protokoll.
- `WakingHub` wird aus `test_peer.py` importiert. `tests/support/pyhub.py` blieb unverändert.

Nicht geprüft oder offen:

- Kurzer Hub-Ausfall (unter 3 s) mit Wiederherstellung der Verbindung in der Rolle: nicht getestet. Der Peer-Teil ist in WI-05 getestet, die Rollenreaktion (`OnPeerLost` und Rückkehr auf `ready`) nicht.
- `deadlineMs` von `sys.shutdown` wird nicht erzwungen. `OnShutdown` läuft synchron ohne Frist. Das folgt mit der Engine (WI-10).
- `OnError` mit anderen Rückgaben als 1 nicht geprüft.
- `SetLogTarget("storage")` wird in dieser Phase nirgends aufgerufen (WI-12).
- Der Fortschrittshaken WI-06 in `work_items/phase2/README.md` ist nicht gesetzt. Die Datei stand nicht auf der Schreibliste, bitte nach dem Commit abhaken.
- Im Arbeitsbaum liegt unversioniert `Hinweis vom Benutzer.txt` (Inhalt: "Stoppe nach diesem Work package! ... Lösche diese Datei, mach commit, dann stoppe."). Sie wurde nicht gelöscht und nicht committet, weil die Vorgabe dieses Pakets "NICHT committen" lautet. Entscheidung beim Nutzer.
- Ein fremder Prozess `AutoHotkey64.exe` (PID 29328, gestartet 18:53:18) läuft noch mit der Kommandozeile `/restart /script ...\src\AutoHotFlow.ahk`. Der Elternprozess (27720) existiert nicht mehr. Die Tests starten nie mit `/restart`, daher stammt er nicht von ihnen. Nicht beendet, bitte prüfen.
