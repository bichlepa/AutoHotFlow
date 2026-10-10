# WI-10 Engine-Rolle

Größe: L · Hängt ab von: WI-06, WI-08, WI-09 · Blockiert: WI-15

## Ziel

Die Engine als Rolle: lädt Flows über `storage`, führt sie mit dem Kern aus WI-08 und den Elementen aus WI-09 aus, meldet Zustandsänderungen als Ereignisse, nimmt Befehle an.

## Vorher lesen

`doc/ARCHITEKTUR.md` 4, 5, 6 (insbesondere 6.2), `doc/PROTOKOLL.md` 4.2, 4.3, 4.5, 4.6.

## Zu erstellen (`src/engine/`, außer `core/`)

- `Engine.ahk` (Rolle `engine`, erbt `Role`):
  - Start: `evt.engine.ready` erst nach erfolgreichem Laden der Flow-Liste (`cmd.storage.flows.list`, dann `cmd.storage.flow.read` je Datei, alles per Callback). Fehler einzelner Dateien blockieren den Start nicht, sie werden als `evt.storage.error` gemeldet.
  - `epoch` (Zähler, bei jedem Start +1 aus der Prozessstartzeit), `seq` (pro Ereignis +1).
  - Handler: `cmd.engine.snapshot`, `cmd.flow.get`, `cmd.flow.start`, `cmd.flow.stop`, `cmd.flow.toggle`, `cmd.flow.enable`/`disable` (Phase 2: Flag setzen und `evt.flow.state`).
  - Ereignisse: `evt.element.state`, `evt.instance.started`/`ended`, `evt.flow.state`, `evt.engine.ready`.
- `Dispatcher` der Ausführung (Schleife über Threads im Zustand `ready`): **timer-/ereignisgesteuert**, kein `Loop` mit `Sleep`. Ein Tick pro Änderung plus ein 100-ms-Sicherheitstimer.
- `WorkerBridge.ahk`: Elemente mit `Mode = "worker"` per `cmd.worker.run` an einen Worker (Anfrage über Hub, Adresse `worker`, Worker-Zuteilung macht der Supervisor oder ein einfacher Pool in `WorkerBridge`). Antwort `evt.worker.done` setzt das Thread-Ergebnis. Abbruch über `cmd.worker.cancel`. Absturz des Workers (`evt.process.crashed` mit Rolle) → Thread-Ergebnis `exception`.
- `StopHandling`: `flow.stop` setzt Instanzen auf `stopping`, ruft `Stop` der Elemente auf, bricht Worker ab, setzt nach Quittung oder Frist (2 s) auf `ended`.
- Watchdog: `ElementRunner.onSlow` → `Log.Write("f0", ...)` mit Klasse und Flow.
- Alle Dateizugriffe nur über `storage`. Kein `MsgBox`.

Der Flow für den Skeleton: `tests/data/skeleton_flow.json` im v1-Format (`Trigger_Manual` → `Action_Sleep` 200 ms → `Action_Do_nothing`), von diesem Paket anzulegen. Der Name der Datei und der Ordner werden `storage` per `--data` gegeben (`<data>/Flows/skeleton.json`, entspricht der v1-Verzeichnisstruktur `Saved Flows`).

## Akzeptanzkriterien

- Mit `storage` und Python-Hub: Engine startet, lädt den Flow, antwortet auf `cmd.engine.snapshot`.
- `cmd.flow.start`: Ereignisfolge `instance.started`, `element.state(Trigger running → finished)`, `element.state(Sleep running)`, nach 200 ms `finished`, `element.state(Do_nothing …)`, `instance.ended`. Reihenfolge und `seq`-Monotonie geprüft.
- `cmd.flow.stop` während `Action_Sleep`: Instanz endet innerhalb 500 ms, `countRuns` korrekt, Element-Zustand `finished`.
- `Action_TestThrow`: Thread-Ergebnis `exception`, Flow-Ereignis mit Meldung, Engine läuft weiter.
- `Action_TestBlockWorker` (Worker): Während der Worker 800 ms blockiert, beantwortet die Engine `cmd.engine.snapshot` unter 50 ms.
- Engine hängt nicht beim Beenden: `sys.shutdown` → alle Instanzen gestoppt, `sys.bye` innerhalb der Frist.

## Tests

`tests/integration/test_engine.py` (mit Python-Hub und echter `storage`-Rolle oder einem Python-Stub dafür).

## Nicht Teil

Ausdrücke, echte Variablen (`global`/`static`), Trigger-Aktivierung (Phase 3, nur Befehl `cmd.flow.start`), Patches (`cmd.flow.patch`), Speichern.

## Hinweise

- Elementaufrufe immer über `ElementRunner`, nie direkt.
- Instanzen und Threads bekommen IDs aus `Ids.Next("inst-")` bzw. `Ids.Next("thr-")`.
- `evt.element.state.countRuns` zählt wie v1 (`+1` beim Start, `-1` beim Ende, Zustand `finished` bei 0).
