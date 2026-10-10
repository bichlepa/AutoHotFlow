# WI-11 Worker-Rolle

Größe: M · Hängt ab von: WI-06, WI-09 · Blockiert: WI-10 (Integration), WI-15

## Ziel

Ein Prozess, der Elemente im Modus `worker` ausführt: blockierende Aufrufe sind hier erlaubt, die Engine bleibt davon unberührt.

## Vorher lesen

`doc/ARCHITEKTUR.md` 2.3, `doc/PROTOKOLL.md` 4.5, `doc/ELEMENT-API-V2.md` (Abschnitt 3, `ctx`).

## Zu erstellen (`src/worker/`)

- `Worker.ahk` (Rolle `worker`, erbt `Role`): Handler `cmd.worker.run`, `cmd.worker.cancel`.
  - Antwort auf `cmd.worker.run` sofort `{ok:true}` (angenommen), Ergebnis später als `evt.worker.done`.
  - Ausführung: Klasse aus der Registry, `ctx` vom Typ `WorkerContext`: `Finish` sendet `evt.worker.done`, `imports` sind schreibgeschützt, `exports` werden gesammelt. `After` ist erlaubt.
  - Genau **eine** Ausführung zugleich pro Worker. Ein zweites `run` wird mit `busy` beantwortet (Pool/Zuteilung ist Sache der Engine).
  - Der Worker darf blockieren. Damit `sys.ping` und `cmd.worker.cancel` trotzdem bedient werden, laufen blockierende Teile in kurzen Scheiben mit `Sleep -1`-Pumpen **oder** das Element wird als `worker` nur dann akzeptiert, wenn es nicht länger als `pingTolerance` (Standard 6 s) am Stück blockiert. Entscheidung und Begründung in der Paketdatei dokumentieren (siehe „Offene Punkte“).
  - Absturzsicherheit: jede Elementausführung unter `try/catch`, Ergebnis `exception`.
- `WorkerContext.ahk`: wie `ExecContext` aus WI-09, aber ohne `GetVar`/`SetVar` auf Engine-Daten. Für Phase 2 genügt `Finish`, `State`, `Log`.
- Beenden nach `cmd.worker.cancel` oder `sys.shutdown`: Elementzustand abbrechen (`Stop`), `evt.worker.done` mit `result: "stopped"`.

## Akzeptanzkriterien

- `Action_TestBlockWorker`: Ergebnis `normal` nach ≥ 800 ms. Während dieser Zeit wird `sys.ping` weiterhin beantwortet (Test: 3 Pings in 800 ms, alle beantwortet) **oder** der Worker erklärt vorab, dass er nicht antwortet, und der Supervisor-Heartbeat toleriert das (Entscheidung siehe oben, im Test festgehalten).
- `cmd.worker.cancel` auf `Action_TestHangWorker`: `evt.worker.done` mit `stopped` innerhalb 500 ms.
- Absturz des Workers (Prozess beenden) wird von der Engine als Thread-`exception` gemeldet (Integrationstest zusammen mit WI-10 und WI-07).

## Tests

`tests/integration/test_worker.py` mit Python-Hub.

## Nicht Teil

Worker-Pool-Verwaltung, `RunScript` (AHK-Skript-Element), `ctx.Request`.

## Offene Punkte

- Pings während blockierender Aufrufe: AHK v2 hat keinen zweiten Thread. Mögliche Lösungen: (a) Heartbeat-Toleranz für Worker im Zustand `busy` größer als die Elementdauer, (b) Elemente mit blockierendem Sleep in `Sleep`-Scheiben aufteilen, (c) Worker meldet beim Start der Ausführung ein „busy until“-Fenster. Empfehlung: (c), ein `evt.worker.busy {execId, expectedMs}` an den Supervisor/Engine, Heartbeat-Toleranz = erwartete Dauer + 5 s. Mit der Engine abstimmen.
