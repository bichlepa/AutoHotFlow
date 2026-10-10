# WI-08 Engine-Kern (Zustandsautomaten, Flowmodell, Scheduler)

Größe: M · Hängt ab von: WI-02, WI-03 · Blockiert: WI-10

## Ziel

Die reine Logik der Ausführung als **unabhängig testbare Klassen** ohne IPC, ohne Dateien, ohne Elemente: Zustandsautomaten für Instanzen und Threads, Flowmodell im v1-Dateiformat, Auswahl der nächsten Verbindung.

## Vorher lesen

`doc/ARCHITEKTUR.md` 4.2, 5 (Zustandsautomaten, normativ), 7 (Dateiformat), `work_items/ANALYSE.md` 2.3 und 3.x, `v1/Source_Execution/Execution Task/Execution Task.ahk` (Zeilen 98 bis 170 für die Verbindungsauswahl) und `v1/Source_Execution/Execution Task/Instances and Threads.ahk`.

## Zu erstellen (`src/engine/core/`)

- `FlowDefinition.ahk`: baut aus einem geparsten v1-Flow (`Map` aus WI-02) ein Modell. Elemente und Verbindungen per ID, `FromConnections(elementId)`, Trigger-Liste, `ElementClass(id)`, `Rev`. Unbekannte Schlüssel bleiben im Rohdatensatz erhalten (`Raw`). Defekte Dateien: `AhfError` mit lesbarer Meldung (kein Absturz).
- `Instance.ahk` und `ThreadState.ahk`: Klassen mit Übergangstabelle (`static Transitions`), Methode `TryTransition(newState, reason) -> bool`, ungültige Übergänge werden abgewiesen und über einen Callback gemeldet (`onInvalid(from, to, reason)`).
- `Scheduler.ahk`: reine Funktionen/Methoden:
  - `ResolveNext(flow, thread, result) -> [connection, ...]`: Verbindung, deren `ConnectionType` gleich dem Ergebnis ist, bei `type = loop` zusätzlich `fromPart = result` (v1 `Execution Task.ahk:119`). Case-insensitiv.
  - Behandelt mehrere passende Verbindungen (Thread klonen, `AnyConnectionFound`-Logik).
  - Liefert „keine Verbindung“ und ob das Ergebnis `exception` unbehandelt ist.
- `ExecutionPolicy.ahk`: Entscheidungsfunktion `Decide(policy, flowIsExecuting) -> "start" | "skip" | "wait" | "stop_and_start"`. **Nur** die v1-Werte `default`, `parallel`, `skip`, `wait`, `stop`. Die genaue Semantik aus `v1/Source_Execution/Execution Task/Instances and Threads.ahk` (Funktion `newInstance`) und `Execution Task.ahk` (Zeilen 31 bis 48) übernehmen und in der Dateikopfzeile **mit Zeilenverweisen** dokumentieren. Offene Fragen in der Paketdatei nachtragen.
- `Loops.ahk` (Stack der Schleifenvariablen): Operationen `Push`/`Pop` wie `LoopVariable_AddToStack`/`RestoreFromStack` (v1 `Execution Task.ahk:125, 144`).

## Akzeptanzkriterien

- Alle echten Beispiel-Flows aus `v1/AppData/Saved Flows` laden in `FlowDefinition` ohne Fehler (zusammen mit WI-02).
- Zustandsautomaten: Tabelle aus ARCHITEKTUR 5.1/5.2 vollständig als Test abgedeckt, einschließlich aller **ungültigen** Übergänge.
- `ResolveNext` auf mindestens fünf handgebauten Flows (normal, ja/nein, zwei Verbindungen, Schleife head/tail, keine Verbindung mit `exception`).
- Keine Abhängigkeit von `Peer`, `Pipe`, Dateien, GUI.

## Tests

`tests/ahk/engine_flow.test.ahk`, `engine_states.test.ahk`, `engine_scheduler.test.ahk`, `engine_policy.test.ahk`.

## Nicht Teil

Ausführen von Elementen, Variablenstore, Ausdrücke, Trigger.

## Hinweise

- Einfache Objekte/`Map` statt eigener Datenklassen, wo reine Daten.
- Keine globalen Zähler: IDs bekommt der Aufrufer über `Ids`.
