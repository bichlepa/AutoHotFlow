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

## Ergebnis

Stand: WI-10 umgesetzt, alle Schritte committet (Commits mit Präfix `WI-10:`, `git log --oneline`). Gesamtlauf `python -m pytest tests -q`: `339 passed, 1 skipped in 141.57s`. Der Skip ist der schon vor WI-10 bestehende AHK-seitige Skip in `tests/test_ahk_runner.py`. Danach keine von den Tests gestarteten AutoHotkey-Prozesse übrig.

**Akzeptanzkriterien (Stand dieses Pakets):**

| Kriterium | Ergebnis | Beleg |
|---|---|---|
| Engine startet mit Stand-in-Storage, lädt den Flow, antwortet auf `cmd.engine.snapshot` | erfüllt | `test_engine_loads_flow_announces_ready_and_answers_snapshot` |
| `cmd.flow.start`: Reihenfolge `instance.started`, Trigger running/finished, Sleep running, nach 200 ms finished, Do_nothing running/finished, `instance.ended`; `seq` monoton | erfüllt | `test_start_emits_the_documented_event_order` (Sleep gemessen: 199,5 bis 208,3 ms) |
| `cmd.flow.stop` während `Action_Sleep`: Ende innerhalb 500 ms, `countRuns` korrekt, Zustand `finished` | erfüllt | `test_stop_during_sleep_ends_the_instance_within_500_ms` (gemessen: 1,0 bis 1,2 ms bis `instance.ended`) |
| `Action_TestThrow`: Ergebnis `exception`, Flow-Ereignis mit Meldung, Engine läuft weiter | erfüllt | `test_element_exception_is_reported_and_the_engine_keeps_running` (prüft auch die f0-Logzeile bei `storage`) |
| `Action_TestBlockWorker`: Snapshot unter 50 ms während 800 ms Blockade | **nicht erfüllt** | Die Worker-Rolle fehlt (WI-11). Nur das Melden fehlt nicht: `test_worker_element_is_reported_as_exception_not_skipped` (Ergebnis `exception`, "worker not available") |
| `sys.shutdown`: alle Instanzen gestoppt, `sys.bye` innerhalb der Frist | erfüllt | `test_shutdown_stops_running_instances_and_says_bye_within_the_deadline` (Exit 0 nach 125 ms gemessen, Frist 2 s) |

Die Worker-Zeile bleibt offen. WI-10 ist deshalb **nicht** mit `[x]` in `work_items/phase2/README.md` markiert. Der Haken folgt, wenn WI-11 den Worker liefert und die Blockade-Messung nachgetragen ist.

**Weitere Tests (`tests/integration/test_engine.py`, 19 Tests, Laufzeit etwa 14 s):** Snapshot und `cmd.flow.get` (inkl. `not_found`, `bad_payload`), kaputte Flow-Datei blockiert den Start nicht (`flow.parse`), Toggle, Enable/Disable, Richtlinien `parallel`, `default`, `skip` (busy), `wait` (busy), `stop` (`policy stop`), ungültige Richtlinie (`bad_payload`), `cmd.flow.patch` (Konflikt, leere `ops`, abgelehnte Operationen).

**Messwerte (Python-Client, Python-Hub, Stand-in-Storage, AHK-Engine):**

- `cmd.engine.snapshot` Round-Trip: Median 0,65 ms, p99 0,78 ms (200 Anfragen). Ziel Budget < 5 ms erfüllt, nicht gegen Last gemessen.
- `Action_Sleep` 200 ms, running bis finished: 199,5 bis 208,3 ms.
- `cmd.flow.stop` bis `evt.instance.ended`: 1,0 bis 1,2 ms.
- `sys.shutdown` bis Engine-Exit 0: 125 ms.

**Erstellt:**

- `src/engine/Engine.ahk`: Rolle (Laden über `storage`, Ereignisse mit `epoch`/`seq`, Befehle, Shutdown).
- `src/engine/Executor.ahk`: Instanzen und Threads, Dispatch (ereignisgesteuert, Kick plus 100-ms-Sicherheitstimer), Elementlauf über `ElementRunner`, Stop, Richtlinien.
- `src/engine/FlowTable.ahk`, `src/engine/FlowRecord.ahk`: geladene Flows, Revision, Flag.
- `tests/data/skeleton_flow.json`: der Testflow im v1-Format.
- `tests/integration/test_engine.py`: 19 Tests, mit `StorageStub` (Python-Stand-in für `storage`).
- Geändert: `src/AutoHotFlow.ahk` (Rolle `engine` registriert, Skeleton-Elemente eingebunden), `src/core/RoleRegistry.ahk` (Platzhalter `engine` entfernt), `tests/integration/test_role.py` (der "nicht implementiert"-Fall nutzt jetzt `worker`), `doc/PROTOKOLL.md` (Abschnitte zur WI-10-Umsetzung und zu `cmd.flow.patch`), `doc/HOW-TO.md` (drei Einträge).

**Abweichungen von WI-10:**

- `WorkerBridge.ahk` nicht erstellt. Die Vorgabe des Auftrags verlangt, dass Worker-Elemente in WI-10 nur als `exception` ("worker not available") gemeldet werden. Der Worker-Transport gehört zu WI-11.
- `src/core/RoleRegistry.ahk` geändert: der Platzhalter `engine` ist entfernt. Das hatte der Kommentar in WI-06 ausdrücklich vorgesehen. Die Registrierung steht jetzt in `AhfRegisterRoles()` im Einstieg, weil `core/` keine Rollenklassen nennen darf.
- Der Testflow Trigger wird beim Start simuliert (`running`, dann `finished`). `TriggerVariables` wird nicht aufgerufen (Trigger-Aktivierung ist Phase 3).
- Parameter werden nicht ausgewertet (Ausdrücke sind Phase 3). Die Engine übergibt den Rohwert aus der Datei.
- Richtlinie `wait` antwortet mit `busy` statt zu warten (nicht umgesetzt).
- Der 2-Sekunden-Stoppfrist gilt nicht: Elemente haben keine asynchrone Stopp-Quittung, die Engine quittiert synchron.
- Die Flow-ID ist der Dateiname ohne `.json`. Die globale Richtlinie ist fest `parallel`, `settings` in `cmd.engine.snapshot` ist `{}`.
- `cmd.flow.enable` setzt nur das Flag, Trigger werden nicht scharf geschaltet.
- `cmd.flow.patch` prüft Schema und Revision, wendet aber keine Operationen an.
- `evt.element.state` trägt zusätzlich `lastRun` und bei Ausnahmen `message`. Das steht in `doc/PROTOKOLL.md`.
- `test_role.py`: der Fall "nicht implementiert" nutzt `worker` statt `engine`, weil `engine` jetzt implementiert ist.

**Stand-ins:**

- `storage`: Python-Stand-in `StorageStub` in `tests/integration/test_engine.py` (liefert `cmd.storage.flows.list` und `cmd.storage.flow.read`, nimmt `evt.log.append` an). Die echte Storage-Rolle (WI-12) fehlt. Nicht geprüft: Schreibvorgänge, Fehlerpfade von `storage` außer der kaputten Datei.
- Hub: Python-`WakingHub` (PyHub-Stand-in), nicht der Supervisor-Hub. Die Pflichtrolle `engine` im Supervisor-Test wurde gestartet, aber nicht als Engine-Test geprüft.

**Nicht geprüft oder offen:**

- Watchdog für blockierende Inline-Elemente (`f0` nach 250 ms): der Hook ist eingebaut (`Executor._OnSlow`), kein Test-Element blockiert inline.
- Wiederholung der Dateiliste nach Fehler (`LOAD_TRIES`, `LOAD_RETRY_MS`): nicht getestet.
- Neustart der Engine und neues `epoch` (`evt.engine.restarted`): nicht implementiert, nicht getestet.
- Späteres `OnReady` nach Wiederverbindung: lädt nicht neu, nicht getestet.
- Trigger-Arming, `cmd.worker.*`, Anwendung von Patches: Phase 3 bzw. WI-11.
- Stresstest (WI-16): nicht Teil dieses Pakets.
- Snapshot-Latenz während einer Worker-Blockade (Akzeptanzkriterium 5): offen bis WI-11.
