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

## Ergebnis

Stand: Engine-Kern umgesetzt, nicht committet. Alle Tests grün.

### Erstellt

- `src/engine/core/FlowDefinition.ahk`, `Instance.ahk`, `ThreadState.ahk`, `Scheduler.ahk`, `ExecutionPolicy.ahk`, `Loops.ahk` (Klasse `LoopStack`).
- `tests/ahk/engine_flow.test.ahk` (17 Fälle), `engine_states.test.ahk` (19), `engine_scheduler.test.ahk` (15), `engine_policy.test.ahk` (6).
- `doc/HOW-TO.md`: 7 Einträge (Syntax, Map, Fehlerbehandlung, Tests).

### Verifikation

- `python -m pytest tests -q`, letzte Zeile: `222 passed, 1 skipped in 34.98s`. Der Skip ist der bestehende Fall `tests/test_ahk_runner.py:69`.
- `pytest tests -k engine`: 61 passed (die vier Dateien einschließlich Dateiebene).
- Nach dem Lauf keine AutoHotkey-Prozesse übrig (`tasklist`).

### Akzeptanzkriterien und Beleg

1. **Alle 23 v1-Flows laden** ohne Fehler, jeweils mit mindestens einem Trigger. Beleg: `engine_flow.test.ahk`, "all v1 saved flows load and have at least one trigger". Der Test liest `v1/AppData/Saved Flows` zur Laufzeit und schlägt fehl, wenn das Verzeichnis leer ist.
2. **Zustandsautomaten vollständig geprüft**, einschließlich ungültiger Übergänge. Beleg: `engine_states.test.ahk`, "every pair of states matches the table". Alle 25 Paare für den Thread und alle 16 Paare für die Instanz werden gegen eine Liste aus ARCHITEKTUR 5.1/5.2 geprüft. Ungültige Übergänge lassen den Zustand stehen und melden genau einmal.
3. **ResolveNext auf mindestens fünf handgebauten Flows**: normal (`LinearFlow`), Ja/Nein (`YesNoFlow`), zwei Verbindungen (`TwoConnectionsFlow`), Schleife head/tail (`LoopFlow`), keine Verbindung mit `exception` (`ExceptionWithoutConnection`). Dazu: Dangling-Verbindungen (`DanglingFlow`) und der echte Flow 464187831 von Trigger bis Ende. Beleg: `engine_scheduler.test.ahk`.
4. **Keine Abhängigkeit von Peer, Pipe, Dateien, GUI.** `src/engine/core/` bindet nur `core/Errors.ahk`, `core/Json.ahk` und `core/Log.ahk` ein. Eine Suche nach Datei-, Pipe-, GUI-, `Sleep`-, `Critical`- und `DllCall`-Aufrufen in `src/engine/core/` ist leer. `Json.ahk` nutzt ein `DllCall` zur UTF-8-Umwandlung, ohne Datei- oder Pipe-Zugriff.

### Abweichungen von der Paketbeschreibung

- `Loops.ahk` enthält die Klasse `LoopStack`. Der Dateiname ist vorgegeben, die Regel "Dateiname = Klassenname" (KONVENTIONEN 1) ist hier also nicht eingehalten.
- `ThreadState` ist zugleich der Thread-Datensatz (Id, ElementId, Result, Loops) und Träger der Übergangstabelle. Der Trigger-Thread startet im Zustand `finished` mit Ergebnis `Normal`, wie in v1 `newInstance` (`Instances and Threads.ahk`). Element-Threads starten in `ready`.
- `Scheduler.Advance(instance, flow, thread, newId)` ergänzt `ResolveNext`. Es ist die einzige Stelle, die Threads verändert. `ResolveNext` bleibt rein. `newId` ist eine Funktion ohne Argumente, die der Aufrufer über `Ids` belegt.
- `ExecutionPolicy.Decide(policy, flowIsExecuting, globalPolicy := "parallel")` hat einen dritten Parameter. Er ist nötig, um `default` aufzulösen (Standard aus `Settings.ahk:14`).
- `Instance` bekam `Start`, `AddThread`, `ReleaseThread`, `Stop`, `Expire`. Sie sind für die Tabelle 5.1 nötig, stehen aber nicht im Paket.
- `FlowDefinition` verlangt bei Elementen `type` und `class` sowie bei Verbindungen `ConnectionType`. Fehlt etwas, gibt es `AhfError` mit Code `bad_payload`. Alle 23 Beispieldateien erfüllen das.
- Unbekannte IDs liefern bei `ElementKind`, `ElementClass`, `Element`, `Connection` einen leeren String, `FromConnections` ein leeres Array. Es wird nicht geworfen.
- `LoopStack.Pop()` auf einem leeren Stack wirft `AhfError` mit Code `internal`. v1 setzt still `""`. Das ist eine bewusste Abweichung und gehört in `doc/MIGRATION.md` (nicht von diesem Paket geschrieben).
- `Instance.Stop` von einem `finished`-Thread führt zu `removed`. Siehe offene Frage 4.
- `engine_flow.test.ahk` liest `v1/`. Beim Entfernen von `v1/` (WI-17) muss der Test auf eine Kopie der Beispieldateien umgestellt werden.

### Offene Fragen

1. **Richtlinie `wait` (wichtigste Frage).** Die v1-Stellen widersprechen sich:
   - `newInstance` (`Instances and Threads.ahk`, Zeilen 14 bis 44) startet bei `wait` eine neue Instanz. Es gibt kein Warten.
   - Der Dispatcher (`Execution Task.ahk`, Zeilen 31 bis 48) soll bei `wait` nur die erste laufende Instanz eines Flows zulassen. Er liest den Wert aber mit `_getFlowProperty(..., "ExecutionPolicy")` von der Flow-Wurzel. In v1-Dateien steht der Schlüssel unter `flowSettings` (`Load.ahk:230`, `Manage Flows.ahk:144`). Der Pfad wird über `parseObjectPath` aufgelöst (`Shared Variables.ahk`, ab Zeile 785). Ein fehlender Schlüssel ergibt `""`.
   - Folge (aus dem Code gelesen, nicht zur Laufzeit geprüft): In v1 wirkt `wait` wie `parallel`. `Decide` liefert `wait`, weil das der Absicht des Kommentars (Zeilen 37 bis 41) entspricht und dem Paket. Zu entscheiden: (a) Absicht umsetzen, die Instanz wartet, bis der Flow frei ist. Das ist bei WI-10 zu bauen. Oder (b) das v1-Laufzeitverhalten übernehmen, `wait` wie `parallel` behandeln und in `MIGRATION.md` festhalten.
   - Zusätzlich: `flowIsExecuting` muss der Aufrufer bestimmen. v1 `updateFlowExcutingStates` zählt alle Instanzen der Liste, also auch stoppende. Vorschlag: laufende und stoppende Instanzen zählen (WI-10).
2. **Richtlinie `stop`.** v1 stoppt alle Instanzen des Flows und startet sofort eine neue. Eine Frist gibt es in v1 nicht. Tabelle 5.1 nennt 2 s. `Decide` liefert `stop_and_start`, die Frist liegt bei der Engine.
3. **Dangling-Verbindungen.** 154 Verbindungen in 19 der 23 Beispieldateien (von 1039) haben einen leeren oder unbekannten Anfang oder Ende. v1 hat für diesen Fall kein definiertes Verhalten (das Ziel wäre `""`). Umgesetzt: `ResolveNext` ignoriert sie, `FlowDefinition.Dangling` listet sie, `Raw` behält sie. Zu entscheiden: Soll das Laden eine Warnung erzeugen?
4. **`finished` + Stop → `removed`** steht nicht in Tabelle 5.2. Gewählt, weil ein finished-Thread in v1 im selben Durchlauf weitergereicht wird und nie länger steht. Bitte bestätigen.
5. **Reihenfolge mehrerer Treffer.** v1 nimmt die Reihenfolge, in der `FromConnections` gefüllt wird (`Manage Elements.ahk`, Zeilen 477 bis 492). `FlowDefinition` nimmt die sortierte Reihenfolge der IDs, weil `Json.Parse` eine `Map` liefert, die sortiert aufzählt. Auswirkung: nur die Vergabe der Thread-IDs bei Klonen, nicht das Ergebnis. Zu entscheiden, ob die Dateireihenfolge nötig ist.
6. **Schleife mit mehreren passenden Verbindungen.** v1 entfernt den Schleifen-Stack für jede passende Verbindung einzeln (`Execution Task.ahk`, Zeilen 123 bis 126 innerhalb der Verbindungsschleife). Übernommen. Nicht geprüft, ob solche Konstellationen in den Beispieldateien vorkommen.
