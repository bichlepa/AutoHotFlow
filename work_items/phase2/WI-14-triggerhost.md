# WI-14 Triggerhost (Skeleton, optional)

Größe: S · Hängt ab von: WI-06, WI-09 · Blockiert: nichts in Phase 2 (Stretch)

## Ziel

Beweisen, dass Trigger in einem eigenen Prozess scharf geschaltet werden können und die Engine nur das Ereignis `evt.trigger.fired` bekommt. Kein Anspruch auf echte Trigger-Vielfalt.

## Vorher lesen

`doc/ARCHITEKTUR.md` D8, `doc/PROTOKOLL.md` 4.4, `doc/ELEMENT-API-V2.md` Abschnitt 5.

## Zu erstellen (`src/triggerhost/`)

- `TriggerHost.ahk` (Rolle `triggerhost`): Handler `cmd.trigger.arm`, `cmd.trigger.disarm`. Registry nach Klasse, Aufruf `cls.Enable(ctx, params)` unter `try/catch`, Fehler → `res` mit `ok:false`.
- Kontext `TriggerContext`: `Fire(data)` sendet `evt.trigger.fired {triggerKey, flowId, elementId, data}` an `engine`. `State` pro scharf geschaltetem Trigger.
- Trigger für den Test (unter `src/elements/skeleton/`): `Trigger_Periodic_Timer` (`Enable` startet `SetTimer`, `Disable` stoppt, Intervall aus `params.Interval` in ms).
- Beim Beenden: alle Trigger deaktivieren, `sys.bye`.
- Beim Verlust der Verbindung zur Engine (`evt.engine.restarted`): alle Trigger deaktivieren und auf neues `arm` warten.

## Akzeptanzkriterien

- Mit Python-Hub: `arm` Periodic_Timer 100 ms → 5 `evt.trigger.fired` in 500–600 ms. `disarm` → keine weiteren.
- Doppeltes `arm` desselben `triggerKey`: wird abgewiesen oder ersetzt, ohne doppelte Timer (Test).
- Fehler in `Enable` (Exception): `res ok:false`, Host läuft weiter.
- Die Engine (WI-10) kann `evt.trigger.fired` in eine Instanz übersetzen (nur wenn WI-10 fertig ist: e2e-Test in WI-15).

## Tests

`tests/integration/test_triggerhost.py`.

## Nicht Teil

Echte Hotkeys, Hooks, Fenster-Watcher (Phase 3).
