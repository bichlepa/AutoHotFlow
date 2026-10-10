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
