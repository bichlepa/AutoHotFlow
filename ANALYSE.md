# Bestandsaufnahme und Risikoanalyse: AutoHotFlow (AHF)

## 1. Inventar der Module und Schnittstellen

Das Projekt umfasst insgesamt **429 Dateien** und **73.074 Zeilen Code**.

### Module & Dateistruktur

| Modul | Dateien | Zeilen | Zweck & Verantwortung |
| :--- | :--- | :--- | :--- |
| **Source_Main** | 7 | 1.667 | Einstiegspunkt (`main.ahk`), Thread-Initialisierung, Systray-Icon, globales Error-Handling. |
| **Source_Manager** | 8 | 2.372 | Hauptfenster (Flow-Liste, Kategorien, Einstellungen, Import/Export, Über-Dialog). |
| **Source_Editor** | 17 | 7.993 | Grafischer Flow-Editor (GDI+-Arbeitsfläche, Elemente platzieren/verbinden, Element-Eigenschaften). |
| **Source_Draw** | 2 | 1.278 | Rendering-Engine für den Editor (GDI+ Zeichnen von Blöcken, Verbindungslinien und Zuständen). |
| **Source_Execution** | 6 | 2.706 | Laufzeit-Engine: Instanzen, Ausführungs-Threads, Variablen-Verwaltung, Trigger-Überwachung. |
| **Source_Elements** | 327 | 41.203 | Element-Bibliothek (114 Actions, 17 Conditions, 5 Loops, 16 Triggers + Hilfsbibliotheken). |
| **Source_Common** | 25 | 6.333 | Shared State Wrapper, Multithreading IPC, Flow/Element I/O, Expression Evaluator, Logger. |
| **Source_Test** | 2 | 29 | Grundgerüst für Unit-Tests (`Unit_Tests.ahk`). |
| **Lib** | 13 | 4.102 | Drittanbieter-Bibliotheken (`Gdiplus`, `Yaml`, `Jxon`, `TTS`, `Class_Monitor`, `Eject`). |
| **Tools for contributors**| 22 | 5.391 | Entwickler-Skripte (`find modules.ahk`, `checkCriticalSection.ahk`, Element-Generatoren). |

### Öffentliche Schnittstellen zwischen Modulen

In der v1/AHK_H-Architektur kommunizieren die Module über zwei Hauptkanäle:

#### 1. IPC Task Queue (`_setTask(<ziel>, {name: ..., ...})`)
Die Kommunikation zwischen den Threads erfolgt asynchron über das Schreiben von Tasks in die geteilten Objekte:
- **API Caller to Main (`Source_Common/Multithreading/API Caller to Main.ahk`)**:
  - `API_Main_Exit()` -> `_setTask("main", {name: "exit"})`
  - `API_Main_StartElementAhkThread(UniqueID, code, notifyWhenStopped)` -> `_setTask("main", {name: "StartElementAhkThread", ...})`
  - `API_Main_StopElementAhkThread(UniqueID)` -> `_setTask("main", {name: "StopElementAhkThread", ...})`
  - `API_Main_ElementThread_Stopped(UniqueID)` -> `_setTask("main", {name: "ElementThread_Stopped", ...})`
  - `API_Main_ElementThread_Trigger(UniqueID, iteration)` -> `_setTask("main", {name: "elementAhkThreadTrigger", ...})`
- **API Caller to Manager (`Source_Common/Multithreading/API Caller to Manager.ahk`)**:
  - `API_manager_TreeView_Refill()` -> `_setTask("manager", {name: "TreeView_Refill"})`
  - `API_Manager_ShowWindow()` -> `_setTask("manager", {name: "ShowWindow"})`
- **API Caller to Execution (`Source_Common/Multithreading/API Caller to Execution.ahk`)**:
  - `API_Execution_ExecuteFlow(flowID, triggerID)` -> `_setTask("execution", {name: "ExecuteFlow", ...})`
  - `API_Execution_externaElementFinish(UniqueID)` -> `_setTask("execution", {name: "externaElementFinish", ...})`
  - `API_Execution_externalTrigger(UniqueID, iteration)` -> `_setTask("execution", {name: "externalTrigger", ...})`
- **API Caller to Editor / Draw**:
  - `API_Editor_EditGUIshow(FlowID)`
  - `API_Editor_Exit(FlowID)`
  - `API_Draw_Draw(FlowID)` -> triggert Redraw im Draw-Thread.

#### 2. Getrennte Shared Data Getters/Setters (`Source_Common/Multithreading/Shared Variables.ahk`)
Alle Module greifen direkt auf die globalen `CriticalObject`s (`_flows`, `_settings`, `_execution`, `_share`, `_language`) zu über mehr als 80 Getter-/Setter-Funktionen (wie `_getFlow()`, `_setFlow()`, `_getElement()`, `_setElement()`, `_getInstance()`, `_setInstance()`, `_getThread()`, `_setThread()`, `_getTrigger()`, `_setTrigger()`). Jeder dieser Aufrufe sperrt `_cs_shared`.

---

## 2. Element-API Vertrag

Die Element-API ist die zentrale Schnittstelle für 327 Dateien und über 41.000 Zeilen Code. Ein Element wird als Set von globalen Funktionen definiert, die nach dem Schema `Element_<Funktion>_<Typ>_<ElementID>` benannt sind (z. B. `Element_run_Action_Message_Box`).

### Kernfunktionen eines Elements

1. **Metadaten-Funktionen (statisches Manifest / Editor-Informationen)**:
   - `Element_getName_<Klasse>()`: Mengennamens-Übersetzung (`x_lang(...)`).
   - `Element_getCategory_<Klasse>()`: Kategorie-Zuordnung für die Palette.
   - `Element_getElementLevel_<Klasse>()`: "Beginner", "Advanced", oder "Programmer".
   - `Element_getIconPath_<Klasse>()`: Pfad zum Icon.
   - `Element_getStabilityLevel_<Klasse>()`: "Stable" oder "Experimental".

2. **Parametrisierung & Einstellungen GUI**:
   - `Element_getParametrizationDetails_<Klasse>(Environment)`: Gibt ein Array von Steuerelement-Objekten zurück (Edit, Combo, Radio, Checkbox, FileSelect, VarSelect).
   - `Element_CheckSettings_<Klasse>(Environment, ElementParameters, staticValues)`: Validiert Parameter-Kombinationen im Editor und aktiviert/deaktiviert Felder dynamisch (`x_Par_Enable` / `x_Par_Disable`).
   - `Element_GenerateName_<Klasse>(Environment, ElementParameters)`: Generiert den dynamischen Anzeigenamen im Editor aus den Werten (z. B. `"Message Box - Info - Hallo Welt"`).

3. **Laufzeit-Ausführung**:
   - `Element_run_<Klasse>(Environment, ElementParameters)`: Führt das Element aus.
     - Wertet Ausdrücke aus via `x_AutoEvaluateParameters(Environment, ElementParameters)`.
     - Bei einfachen Aktionen / Conditions: Berechnet das Ergebnis, setzt ggf. Variablen via `x_SetVariable(...)` und beendet mit `x_finish(Environment, "normal")` oder `x_finish(Environment, "exception", ErrorMsg)`.
     - Bei GUI / asynchronen Elementen: Erstellt GUIs oder Timer und wartet auf Events.
     - Bei Schleifen (Loops): Steuert den Kontrollfluss durch Setzen von Schleifenvariablen und Rückgabe von Next-Elements.
   - `Element_stop_<Klasse>(Environment, ElementParameters)`: Bricht eine laufende asynchrone Operation ab (z. B. Schließen eines geöffneten Dialogs oder Stoppen eines Timers).

### Untersuchung von 8 repräsentativen Elementen

1. **Action: Message Box (`Actions/Message_Box.ahk`)**:
   - *Typ*: Asynchron GUI-basiert.
   - *Verhalten*: Baut ein AHK Gui dynamisch auf, setzt Timers für Timeouts, fängt OK/Cancel/Close-Events ab. Beendet die Elementausführung erst im Event-Handler via `x_finish()`.
2. **Action: Sleep (`Actions/Sleep.ahk`)**:
   - *Typ*: Blockierende / Timer-Aktion.
   - *Verhalten*: Berechnet Dauer, setzt einen AHK `SetTimer` für das Ende der Schlafzeit.
3. **Action: AutoHotkey Script (`Actions/AutoHotkey_script.ahk`)**:
   - *Typ*: Eigenständiger Thread / Dynamischer Code.
   - *Verhalten*: Startet dynamischen AHK-Code in einem eigenen `AhkThread` über `API_Main_StartElementAhkThread`.
4. **Condition: File Exists (`Conditions/File_Exists.ahk`)**:
   - *Typ*: Synchron / Einfach.
   - *Verhalten*: Prüft `FileExist()`, setzt Ausführungsverlauf auf Wahr/Falsch-Branch, ruft sofort `x_finish()` auf.
5. **Condition: Expression (`Conditions/Expression.ahk`)**:
   - *Typ*: Auswertung dynamischer Ausdrücke.
   - *Verhalten*: Nutzt den internen AHF-Tokenizer/Evaluator (`x_EvaluateExpression`), um benutzerdefinierte Bedingungen auszuwerten.
6. **Loop: SimpleLoop (`Loops/SimpleLoop.ahk`)**:
   - *Typ*: Kontrollfluss-Schleife.
   - *Verhalten*: Führt Iterationszähler in den Thread-Variablen (`x_GetExecutionValue` / `x_SetExecutionValue`), entscheidet, ob zur Schleifen-Start oder nach außen verzweigt wird.
7. **Trigger: Hotkey (`Triggers/Hotkey.ahk`)**:
   - *Typ*: Event-Hook / In-Engine Trigger.
   - *Verhalten*: Registriert globale Hotkeys via AHK `Hotkey`-Befehl. Bei Auslösung wird `x_TriggerFired(Environment)` aufgerufen.
8. **Trigger: Periodic Timer (`Triggers/Periodic_Timer.ahk`)**:
   - *Typ*: Zeitgesteuerter Trigger.
   - *Verhalten*: Nutzt `SetTimer`, um periodisch Flows zu starten.

---

## 3. Analyse der CriticalSection-Sperren (`_cs_shared`)

Im v1-Code gibt es **207 Stellen** in **23 Dateien**, an denen `_cs_shared` betreten oder verlassen wird.

### Risikoklassifizierung der Lock-Fundstellen

#### Kategorie A: Blockierende UI-Aufrufe und Dialoge im Lock (KRITISCH - DEADLOCK / FREEZE)
- `Source_Common/Flows/Load.ahk` (Zeile 271): `MsgBox` (Sicherheitsabfrage zum Löschen beschädigter Flows) wird aufgerufen, **während `_cs_shared` gehalten wird**. Solange der Benutzer die Dialogbox nicht schließt, sind alle anderen Threads im gesamten AHF blockiert.
- `Source_Execution/Execution Task/Execution Task.ahk` (Zeile 94): `MsgBox` bei unerwarteten Fehlern im Ausführungsthread unter dem Lock.

#### Kategorie B: Datei-I/O unter dem Lock (HOCH - PERFORMANCE & LATENZ)
- `Source_Common/Variables/Global variables.ahk` (Zeilen 26, 27, 35, 40, 44, 63, 64, 72, 77, 81, 100, 109, 137, 147, 262, 263, 277, 278): `FileDelete`, `FileAppend`, `FileRead` für persistente Variablen unter `_cs_shared`.
- `Source_Common/Debug/Logger.ahk` (Zeile 63): `FileAppend` zum Schreiben in `Log.txt` und `Log_<source>.txt` unter `_cs_shared`.
- `Source_Common/Flows/Save.ahk` (Zeilen 139, 145, 146): `FileDelete` und `FileAppend` (JSON-Dump) beim Speichern von Flow-Dateien unter `_cs_shared`.
- `Source_Common/Flows/Load.ahk` (Zeile 273): `FileDelete` unter `_cs_shared`.

#### Kategorie C: `throw` / `return` ohne `_LeaveCriticalSection()` (KRITISCH - PERMANENTER LOCK LEAK)
- `Source_Execution/Variables/Variables.ahk` (Zeile 259): `throw exception("p_Name is an object")` wird innerhalb des Locks ausgeführt. Das Lock wird danach nie wieder freigegeben.
- `Source_Execution/Execution Task/Execution Task.ahk` (Zeile 181): `throw exception("State of thread ... is unknown!")` unter dem Lock.
- `Source_Execution/Execution Task/Instances and Threads.ahk` (Zeile 50): `throw exception("trigger element ID unknown...", -1)` unter dem Lock.
- `Source_Common/Variables/Global variables.ahk` (Zeilen 17, 57, 94, 131): Vier `throw exception(...)` Aufrufe unmittelbar nach `_EnterCriticalSection()`.
- `Source_Editor/Elements/Select elements.ahk` (Zeile 8): `throw exception(...)` unter dem Lock.

#### Kategorie D: Verschachtelte Locks / Doppel-Enter
- `Source_Common/Multithreading/Shared Variables.ahk` (Zeile 26): `EnterCriticalSection(_cs_shared)` innerhalb von `_EnterCriticalSection()`.

#### Kategorie E: Lange kritische Abschnitte (`Critical, On` & Monopolisierung)
- `Source_Execution/Execution Task/Execution Task.ahk`: Die zentrale Schleife `executionTask()` hält das Lock über beinahe den gesamten Durchlauf hinweg (Verwaltung aller Instanzen, Threads, Trigger).

---

## 4. AHK v1 und AHK_H Abhängigkeiten & Portierungsaufwand

### Gefundene Sprach- und Runtime-Konstrukte

1. **AHK_H Spezifisch**:
   - `AhkThread` (5 Vorkommen in `Source_Main/Threads/Threads.ahk` & `Source_Common/Multithreading/API Caller to Main.ahk`): Multithreading in v1. Wird in v2 durch eigenständige AHK v2 Executable-Prozesse ersetzt.
   - `CriticalObject` (15 Vorkommen): Geteilte In-Memory Objekte. Entfallen in der Zielarchitektur komplett.
   - `CriticalSection` / `_cs_shared` (15 Vorkommen): Globales Lock. Entfällt komplett.
2. **AHK v1 Legacy Idiome**:
   - `ByRef` (44 Vorkommen): In v2 als `&var` (VarRef) zu schreiben.
   - `StringReplace` (60 Vorkommen), `IfInString` (35 Vorkommen), `StringLen` (3 Vorkommen): In v2 durch `StrReplace()`, `InStr()`, `StrLen()` zu ersetzen.
   - `GuiControlGet` (16 Vorkommen) & `Gui, ...` Syntax: In v2 objektbasiertes GUI System (`Gui()`, `MyGui.Add()`, `MyGui.OnEvent()`).
   - Befehlssyntax ohne Klammern (z. B. `FileRead, Var, Path` -> `Var := FileRead(Path)`).
   - Ungeschützte Dereferenzierung / `%var%` in Befehlen.
   - `Object()` als Dictionary -> In v2 `Map()` verwenden.

### Portierungsaufwand pro Modul (Schätzung)

| Modul | Zeilen | Komplexität | geschätzter Portierungsaufwand | Hauptaufgaben |
| :--- | :--- | :--- | :--- | :--- |
| **Source_Common** | 6.333 | HOCH | 3-4 Tage | Entfernen aller Shared-State Lock-Wrapper, Neuimplementierung IPC (Named Pipes), Umschreiben Evaluator/Tokenizer/Parser auf v2. |
| **Source_Execution**| 2.706 | HOCH | 3-4 Tage | Aufbau des echten v2 Engine-Prozesses, Entkopplung von Thread-Objekten, Zustandsautomat für Instanzen. |
| **Source_Editor** | 7.993 | MITTEL-HOCH | 4-5 Tage | Umstellung aller GUIs und Dialoge auf AHK v2 Gui-Objekte, Umstellung der Kommunikation auf IPC-Client. |
| **Source_Manager** | 2.372 | MITTEL | 2 Tage | Umstellung Manager-GUI (TreeView, Menüs) auf v2 Gui-Objekte, Anbindung als IPC-Client. |
| **Source_Draw** | 1.278 | MITTEL | 1-2 Tage | Portierung GDI+ Wrapper und Zeichenroutinen auf v2. |
| **Source_Main** | 1.667 | MITTEL | 1-2 Tage | Prozess-Launcher, IPC-Master, Shutdown-Orchestrierung. |
| **Source_Elements** | 41.203 | HOCH (Menge) | 5-7 Tage | Standardisierte Transformation von 152 Elementen auf die neue Element-API v2 Klassenstruktur. |
| **Gesamt** | **73.074**| | **ca. 20-25 Entwicklertage** | *(In Phasen gegliedert)* |

---

## 5. Fragen an den Benutzer vor Phase 1

1. **Named Pipes vs. WM_COPYDATA**:
   - *Vorschlag*: Wir empfehlen **Named Pipes** (über `\\.\pipe\AutoHotFlow_*`), da sie voll-duplex, bidirektional, pufferbar und von Fenstern/HWNDs unabhängig sind (sicherer bei Hintergrund-Engines ohne sichtbares GUI-Fenster). Stimmen Sie dieser Wahl zu?
2. **Editor & Draw Prozess-Architektur**:
   - *Vorschlag*: Zeichnen im selben Prozess wie der Editor (Draw-Code direkt im Editor-Client-Prozess ausführen) anstatt in einem separaten Draw-Prozess. Dies spart unnötigen IPC-Overhead bei jeder Mausbewegung im Editor. Ist das in Ordnung?
3. **Trigger-Prozessmodell**:
   - Sollen systemweite Hooks/Hotkeys direkt im Engine-Prozess laufen oder in separaten Mini-Trigger-Prozessen gekapselt werden? (Empfehlung: Hooks im Engine-Prozess in `try/catch` und mit Timeout abfangen, komplexe/blockierende Trigger in eigene Subprozesse isolieren).
