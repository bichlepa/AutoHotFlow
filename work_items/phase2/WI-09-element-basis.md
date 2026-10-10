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

## Ergebnis

Stand: umgesetzt, nicht committet. Alle Dateien unter den erlaubten Pfaden.

### Erstellt

- `src/elements/base/`: `AhfElement.ahk`, `ElementRegistry.ahk`, `ExecContext.ahk`, `ElementRunner.ahk`, `VarStore.ahk` (zusätzlich, für `SetVar`/`GetVar`; im Paket nur als Teil von `ExecContext` genannt).
- `src/elements/skeleton/`: `Trigger_Manual.ahk`, `Action_Sleep.ahk`, `Action_Do_nothing.ahk`, `Action_TestThrow.ahk`, `Action_TestBlockWorker.ahk`, `Action_TestHangWorker.ahk`.
- `tests/ahk/element_registry.test.ahk` (9 Fälle), `element_runner.test.ahk` (14 Fälle), `element_sleep.test.ahk` (5 Fälle).
- `doc/HOW-TO.md`: drei Einträge (`Name()` verdeckt `.Name`, `static __New` für `CaseSense`, `ObjBindMethod` für Timer) und ein Testeintrag zu Timern und Mutation.

### Verträge geändert (begründet)

- `doc/ELEMENT-API-V2.md`, Abschnitt 2: Hinweis, dass die Klassen-ID nicht über `cls.Name` gelesen wird. Grund: Element-Klassen definieren `static Name()`, das verdeckt die Eigenschaft. Gemessen: `cls.Name` ist dann `Func`. Die ID liefert `ElementRegistry.IdOf(cls)` (`Type(cls())`).
- `doc/ELEMENT-API-V2.md`, Abschnitt 3: `ctx.GetVar(name, default := "")` als Erweiterung (Default-Wert), Scopes in Phase 2 auf `thread`/`instance` eingeschränkt. Die bisherige Signatur bleibt gültig.
- `work_items/phase2/README.md` nicht geändert.

### Abweichungen vom Paket

- `Name()`/`Category()` liefern einfache Texte statt `Lang()`, weil `Lang` im Repo noch nicht existiert.
- `Action_Sleep` nimmt die Einheit `Unit` mit Standard `Seconds` (v1: Radio-Default 2 = Seconds). Die Doku-Version nutzt denselben Default.
- Klasse `Action_TestWorkerBlock` aus dem Testflow in `README.md` heißt im Paket `Action_TestBlockWorker`. Ich habe den Paketnamen übernommen. Die Namensdifferenz im `README.md` bleibt offen.
- Die Sleep-Toleranz: Akzeptanz ±50 ms. Gemessen 200,2 bis 204,8 ms (8 Läufe, Messskript im Scratchpad). Der Test prüft 150 bis 300 ms, die Obergrenze liegt bewusst über +50 ms, damit ein belasteter Lauf nicht rot wird. Die untere Grenze 150 ms prüft, dass der Timer nicht früh feuert.
- `ctx.EvalParams`, `ctx.Fire`, `ctx.Request`, `ctx.RunScript`, `ctx.entryPoint`-Logik nicht implementiert (Ausdrucksauswertung und Worker sind nicht Teil dieses Pakets). `entryPoint` ist nur als Feld vorhanden.
- Kein Include-Sammeldatei für das Skeleton. Die Engine-Rolle (WI-10) bindet die Elementdateien selbst ein.
- Der Zusatz `onSlow` in `ElementRunner.Run(cls, ctx, params, onSlow := "")` ist optional. Ohne Angabe wird der Watchdog nicht gemeldet.

### Akzeptanzkriterien und Beleg

| Kriterium | Beleg |
|---|---|
| Registry case-insensitiv, `trigger_manual` findet `Trigger_Manual` | `element_registry`: "lookup is case-insensitive" (pass) |
| Doppelregistrierung wird abgewiesen | `element_registry`: "duplicate registration is rejected" (pass) |
| Exception im Element → `exception` mit Meldung | `element_runner`: "an exception in Run ends the run as exception" (pass, Meldung `test`) |
| Zweites `Finish` wird ignoriert | `element_runner`: "a second Finish is ignored" (pass) |
| Timer nach Ende/Stopp weg (Zähler) | `element_runner`: "timer is cancelled when the run finishes", "Stop cancels pending timers" (pass). Mutationsprüfung in einer Kopie: ohne beide Schutzmechanismen schlägt der Test fehl. |
| `Action_Sleep` nach Dauer, Zeitmessung | `element_sleep`: "200 ms ends after about 200 ms" (pass). Gemessen 200 bis 205 ms. |
| Kein `x_*` und keine globalen Variablen im Skeleton | `element_registry`: "Skeleton: no x_ helpers and no global variables" (pass) |

### Lauf

- `python -m pytest tests -q` (vollständig): `253 passed, 1 skipped in 36.36s`. Der Skip ist der bewusste Test `test_ahk_runner.py:69` (Skip-Berichterstattung).
- Element-Tests dreimal wiederholt (`-k element`): je `37 passed`.
- Nach dem Lauf keine `AutoHotkey`-Prozesse mehr (`tasklist`).

### Offene Punkte

- Die Timing-Tests laufen im Gesamtlauf auf einem unbelasteten Rechner. Unter starker Last ist keine Aussage getroffen (nicht geprüft).
- `Parameters`/`CheckSettings` sind nur als leere bzw. leere-Liste-Rümpfe vorhanden.
- Der Fortschrittshaken in `work_items/phase2/README.md` ist nicht gesetzt (liegt außerhalb der erlaubten Pfade). Setzen nach Commit durch den Verantwortlichen.
- Nicht committet, wie vorgegeben.
