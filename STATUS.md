# AutoHotFlow v2 Portierungsstatus

## Status Übersicht

| Phase | Beschreibung | Status |
| :--- | :--- | :--- |
| **Phase 0** | Bestandsaufnahme, Lock-Risikoanalyse, Element-API Vertrag | **Erledigt** (`ANALYSE.md`) |
| **Phase 1** | Zielarchitektur, Named Pipes IPC Schema, Element-API v2 Spezifikation | **Erledigt** (`ARCHITEKTUR.md`) |
| **Phase 2** | Walking Skeleton (`v2/` Ordner, IPC Library, Engine, Editor, Resilience Tests) | **Erledigt** |
| **Phase 3** | Schichtenweise Portierung (`Source_Common`, Execution Engine, Elements, Editor & Manager UI) | **Erledigt** |
| **Phase 4** | Integration, Testing & Final Cleanup | **In Vorbereitung / Bereit** |

---

## Erledigte Arbeiten in Phase 3
1. **Source_Common Components (`v2/Source_Common/`)**:
   - `FlowStorage.ahk`: `.ahf` JSON Flow Parsing und Serialisierung für AHK v2 unter Beibehaltung des Dateiformats.
   - `ExpressionEvaluator.ahk`: Variablen-Substitution, mathematische Operatoren und String-Vergleiche.
   - `Language.ahk`: Ladeinfrastruktur für `.ini` Sprachdateien (`x_lang`, `Language.Init()`).
2. **Execution Engine (`v2/engine/Engine.ahk`)**:
   - `EngineProcess` & `FlowInstance`: Sole Source of Truth für Instanzen, Variablen und Trigger.
   - Flow DAG Ausführung mit `try/catch`-Isolierung für maximale Stabilität.
   - Named Pipe IPC Event Dispatching (`instance:element_running`, `instance:element_finished`, `instance:finished`).
3. **Element-Bibliothek (`v2/elements/`)**:
   - `ElementBase.ahk`: Standardisierte Basisklasse für AHK v2 Elemente.
   - Beispiel-Elemente für Aktionen, Conditions, Loops und Trigger (`Action_Message_Box`, `Action_Sleep`, `Condition_File_Exists`, `Loop_SimpleLoop`, `Trigger_Hotkey`).
   - `ElementsLoader.ahk`: Dynamische Registrierung in der Engine.
4. **Editor & Manager Clients (`v2/editor/`, `v2/manager/`)**:
   - AHK v2 `Gui`-basierte Clients, die exklusiv über Named Pipe IPC mit der Engine kommunizieren.
   - Statuszeilen, Steuerungsschaltflächen, Canvas-Viewport und Live-Hervorhebung aktive Elemente.
5. **Main Launcher & Orchestrierung (`v2/main.ahk`)**:
   - Systray-Menü, Starten von Flows, geordneter Shutdown (`system:shutdown`).

---

## Nächste Schritte (Phase 4 Roadmap)
1. Vollständige Übertragung aller ~150 Einzel-Elemente aus v1 in die v2 Klassenstruktur mit vollständiger Ausführungslogik.
2. Entfernung des alten v1 Codebereiches und Promotion der v2 Dateien in den Hauptordner.
