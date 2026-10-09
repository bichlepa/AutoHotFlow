# AutoHotFlow v2 Portierungsstatus

## Status Übersicht

| Phase | Beschreibung | Status |
| :--- | :--- | :--- |
| **Phase 0** | Bestandsaufnahme, Lock-Risikoanalyse, Element-API Vertrag | **Erledigt** (`ANALYSE.md`) |
| **Phase 1** | Zielarchitektur, Named Pipes IPC Schema, Element-API v2 Spezifikation | **Erledigt** (`ARCHITEKTUR.md`) |
| **Phase 2** | Walking Skeleton (`v2/` Ordner, IPC Library, Engine, Editor, Resilience Tests) | **Erledigt** |
| **Phase 3** | Schichtenweise Portierung (`Source_Common`, Execution, Elements, Editor, Manager) | **Ausstehend** |

---

## Erledigte Arbeiten in Phase 2
1. **Ordnerstruktur `v2/` angelegt**:
   - `v2/lib/`: IPC Library (`NamedPipeIPC.ahk`) und Element-Basisklasse (`ElementBase.ahk`).
   - `v2/engine/`: Engine Prozess (`Engine.ahk`).
   - `v2/editor/`: Editor IPC Client (`EditorClient.ahk`).
   - `v2/main.ahk`: Orchestrierung und Haupt-Launcher.
   - `v2/tests/`: Simulationstests für 3-Element Flows (`sim_engine_flow.py`) und Resilienz bei Client-Disconnects & RPC-Timeouts (`test_resilience.py`).
2. **IPC Nachrichtenaustausch**:
   - Nachrichten im JSON-Format `{ id, type, from, to, action, correlation_id, payload }`.
   - Engine meldet Ereignisse (`instance:created`, `instance:element_running`, `instance:element_finished`, `instance:finished`) live an den Client.
3. **Resilienz & Shutdown**:
   - Sauberes Herunterfahren über `system:shutdown` Nachricht.
   - Verbindungsabbrüche bringen den Engine-Prozess nicht zum Absturz.

---

## Nächste Schritte (Phase 3 Roadmap)
1. **Source_Common Portierung**:
   - Ausdrucks-Evaluator, Tokenizer, Parser auf AHK v2 portieren.
   - Asynchroner Logger und Flow-Lader/Speicherer (`.ahf` JSON Loader).
2. **Execution Engine & State Machine**:
   - Echte Instanz- und Thread-Klassen mit explizitem Zustandsautomaten (`starting`, `running`, `finished`, `stopped`).
3. **Element-Bibliothek Transformation**:
   - Umwandlung der 152 Elemente auf das neue v2 Klassenmodell.
4. **Editor & Manager GUIs**:
   - Portierung der Benutzeroberflächen auf AHK v2 `Gui` Objekte und Anbindung als IPC Clients.
