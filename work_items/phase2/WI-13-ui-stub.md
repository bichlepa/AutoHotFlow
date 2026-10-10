# WI-13 UI-Stub

Größe: M · Hängt ab von: WI-06 · Blockiert: WI-15

## Ziel

Ein minimaler UI-Prozess, der beweist, dass eine echte GUI-Rolle mit Engine und Hub zusammenarbeitet: verbinden, Zustand empfangen, Befehle senden, Resync nach Engine-Neustart. Zugleich ein Testwerkzeug (Headless-Modus).

## Vorher lesen

`doc/ARCHITEKTUR.md` 4.1, 6.2, `doc/PROTOKOLL.md` 3, 4.3, 5.

## Zu erstellen (`src/manager/StubManager.ahk`, `src/manager/StubGui.ahk`)

- Rolle `manager` im Stub-Modus (`--ui=stub`):
  - Verbindet sich, abonniert `engine`, `flow:*` (explizit je Flow aus dem Snapshot), `process`, ruft `cmd.engine.snapshot` auf.
  - **GUI (v2 `Gui`)**: Tabelle der Flows (`ListView`), Tabelle der Elementzustände des gewählten Flows, Schaltflächen „Start“, „Stop“, „Beenden“, Statuszeile (Verbindung, `epoch`, `seq`, letzte Latenz).
  - **Headless** (`--headless`): keine GUI, schreibt jedes empfangene Ereignis als JSON-Zeile in `<data>/ui_events.log`, nimmt Befehle über Datei- oder Nachrichtenschnittstelle an (`cmd.test.command`, nur im Stub). Wird von den Tests genutzt.
  - Resync: bei `evt.engine.restarted`, `seq`-Lücke oder Wiederverbindung `cmd.engine.snapshot`.
  - Nur UI-Zustand halten, keine Wahrheit über die Ausführung.
- Beenden: `cmd.app.prepareExit` immer mit `cancel:false` beantworten, `sys.shutdown` → GUI schließen, `sys.bye`.

## Akzeptanzkriterien

- Headless-Stub mit laufender Engine: Ereignisse aus dem Skeleton-Flow stehen vollständig und in Reihenfolge in `ui_events.log`.
- Nach `kill` der Engine und Neustart: `ui_events.log` enthält `evt.engine.restarted` und einen neuen Snapshot, ohne dass der Stub neu gestartet wurde.
- GUI-Modus: manuell prüfbar (Start/Stop-Klick ändert die Elementtabelle, Fenster bleibt bedienbar, während eine Instanz läuft). Im Paket als Testanleitung beschreiben, nicht automatisiert.
- Der Stub blockiert nie auf Anfragen (alle Aufrufe mit Callback).

## Tests

`tests/e2e/test_ui_stub.py` (Headless).

## Nicht Teil

Echte Manager-/Editor-Oberfläche, Zeichnen, Einstellungen.

## Hinweise

- GUI-Zustandsänderungen gehören in den GUI-Thread des Stubs (derselbe Prozess): Ereignisse puffern und per Timer in kleinen Batches rendern (z. B. 20 Hz), damit eine Ereignisflut die Oberfläche nicht lähmt.
