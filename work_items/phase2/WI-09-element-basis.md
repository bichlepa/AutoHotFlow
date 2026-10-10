# WI-09 Element-Basis und Demo-Elemente

Größe: M · Hängt ab von: WI-03 · Blockiert: WI-10, WI-11, WI-14

## Ziel

Der Klassenvertrag aus `doc/ELEMENT-API-V2.md` als lauffähiger Code: Basisklasse, Registry, Kontext, sicherer Aufruf, und eine Handvoll Demo-Elemente für das Skeleton.

## Vorher lesen

`doc/ELEMENT-API-V2.md` (vollständig), `doc/ARCHITEKTUR.md` 2.3.

## Zu erstellen

Unter `src/elements/base/`:

- `AhfElement.ahk`: Basisklasse mit statischen Standardwerten (`Mode := "inline"`, `Level`, `Stability`, `Icon`, leere `CheckSettings`, `Stop`).
- `ElementRegistry.ahk`: `Register(cls)`, `Get(classId) -> cls | ""` (case-insensitiv), `All()`, `ModeOf(classId)`. Doppelte Registrierung: `AhfError`.
- `ExecContext.ahk` (**inline**-Kontext): `flowId`, `elementId`, `instanceId`, `threadId`, `entryPoint`, `Finish(result, msg)` (nur einmal wirksam, zweiter Aufruf wird geloggt und ignoriert), `After(ms, fn)` (Timer-Liste, bei Ende/Stopp automatisch abgebrochen), `State` (Objekt), `Log`, `SetVar`/`GetVar` (Phase 2: nur Scopes `thread`/`instance` im Speicher, eine einfache `VarStore`-Klasse).
- `ElementRunner.ahk`: `Run(cls, ctx, params)` mit `try/catch` (Exception → `Finish("exception", msg)`), misst die Aufrufdauer und ruft bei > 250 ms einen Watchdog-Callback (`onSlow(classId, ms)`).

Unter `src/elements/skeleton/` (nur für das Skeleton, wird in Phase 3 entfernt):

| Klasse | Modus | Verhalten |
|---|---|---|
| `Trigger_Manual` | `trigger` | wird per Befehl ausgelöst, keine eigene Logik |
| `Action_Sleep` | `inline` | wie in `doc/ELEMENT-API-V2.md` Abschnitt 4, Timer über `ctx.After` |
| `Action_Do_nothing` | `inline` | `ctx.Finish("normal")` |
| `Action_TestThrow` | `inline` | wirft `ElementError("test")` |
| `Action_TestBlockWorker` | `worker` | blockiert mit `Sleep` 800 ms (läuft nur in einem Worker) |
| `Action_TestHangWorker` | `worker` | endet nie (für Abbruch- und Timeout-Tests) |

Klassen-IDs sind exakt die v1-Namen (`Trigger_Manual`, `Action_Sleep`, `Action_Do_nothing`), damit die echten Flows laden.

## Akzeptanzkriterien

- Registry: Auflösung case-insensitiv (`trigger_manual` findet `Trigger_Manual`), Doppelregistrierung wird abgewiesen.
- `ElementRunner`: Exception im Element → `exception` mit Meldung, zweites `Finish` wird ignoriert, Timer des Kontexts sind nach Ende/Stopp weg (Test mit Zähler).
- `Action_Sleep` beendet nach Dauer ±50 ms (Unit-Test mit Zeitmessung, großzügige Toleranz).
- Kein Element im Skeleton nutzt `x_*`-Funktionen oder globale Variablen.

## Tests

`tests/ahk/element_registry.test.ahk`, `element_runner.test.ahk`, `element_sleep.test.ahk`.

## Nicht Teil

Ausdrucksauswertung (Parameter sind in Phase 2 bereits Werte), Worker-Kontext (WI-11), Editor-Seite der Elemente (`Parameters`, `CheckSettings`) außer minimalen Methodenrümpfen.
