# ANALYSE: Phase 0 (Bestandsaufnahme AutoHotFlow → AHK v2)

> Hinweis: Alle Quellpfade (`Source_*`, `Lib/`, `AppData/`) beziehen sich auf den v1-Stand und liegen seit dem Umbau unter `v1/`.

Stand: 2026-10-10, Branch `master`. Es wurde kein bestehender Code geändert. Neu hinzugefügt wurden nur `ANALYSE.md`, `STATUS.md` und das Skript `work_items/analysis_v1/lock_audit.py` (mit seiner Ausgabe `lock_audit_output.txt` im selben Ordner).

**Kennzeichnung:** **[V]** = im Code gelesen oder gezählt. **[H]** = Hypothese, aus dem Code abgeleitet, aber nicht getestet. **[N]** = nicht geprüft.

---

## 0. Kurzfassung

1. **Die Architektur entspricht deiner Beschreibung** [V]: vier feste Threads (Main, Manager, Draw, Execution), pro offenem Flow ein Editor-Thread und pro laufendem AHK-Code-Element ein Element-Thread. Alles teilt sich einen Prozess und ein einziges Win32-Critical-Section-Objekt `_cs_shared`.
2. **Es gibt drei Klassen von Lock-Fehlern, alle mit Stellenangabe belegt:**
   - a) **Fremder Code unter Lock:** `MsgBox`, Datei-I/O, Element-Code und Callbacks werden innerhalb von `_cs_shared` ausgeführt.
   - b) **Lock wird bei `throw`/`return` nicht freigegeben:** Das betrifft u. a. den Execution-Loop (Zeile 181) und `StaticVariable_Set`.
   - c) **Der Stopp-Pfad kann Threads töten, die ein Lock halten** (`ahkterminate` nach 500 ms) [H, hohes Risiko].
3. **Fund, den du nicht aufgeführt hast: `x_enabled` statt `x_finish`** [V im Code, Laufzeitfolge N]. In 6 `Element_run_…`-Funktionen (Actions, Conditions, Loops) wird im Fehlerfall `x_enabled(...)` aufgerufen. Das ist die Trigger-Funktion. Ein solches Element ruft dann nie `x_finish` auf, bleibt im Zustand „running“, und der Flow hängt.
4. **Weitere Fehler, die der Code zeigt** (siehe Abschnitt 3.6): nicht quotierte Variable `callback` im Execution-Loop, undefinierte Variable `instance`, Test-Suite bindet eine nicht existierende Datei ein, und `currentlyLoadingFlow` wird bei einer Exception nicht zurückgesetzt.
5. **Die Element-API ist sehr einheitlich** [V]: 152 Elemente, jeweils mit denselben Funktionsnamen-Mustern. Die Helfer-API `x_*` (91 Funktionen, in 5 Thread-Varianten identisch vorhanden) ist der eigentliche Vertrag. Die Portierung der Elemente wird also mechanisch gut machbar, wenn `x_*` und der Environment-Vertrag stabil bleiben.
6. **Der größte Aufwand liegt nicht in den Elementen, sondern in Editor (GUI) und in der Ausdrucksauswertung** (Tokenizer/Parser/Evaluator in `Source_Common/Variables`).

---

## 1. Inventar

### 1.1 Umfang [V]

Zeilenzahl über alle `.ahk`-Dateien (ohne `Lib`, `Tools for contributors`):

| Modul | Dateien | Zeilen | Anmerkung |
|---|---:|---:|---|
| `Source_Elements` | 169 | 29.207 | Default-Paket (152 Elemente) plus Chrome-Paket |
| `Source_Editor` | 17 | 7.988 | GUI, Zeichnen-Hilfen, Maus-Tracker |
| `Source_Common` | 25 | 6.321 | Variablen, Ausdrucks-Auswerter, Flows, Multithreading |
| `Source_Execution` | 6 | 2.702 | Execution-Loop, Instanzen, Trigger, Variablen |
| `Source_Manager` | 8 | 2.368 | Manager-GUI, Import/Export |
| `Source_Main` | 7 | 1.660 | Start, Threads, Task-Verteilung, Exit |
| `Source_Draw` | 2 | 1.276 | Zeichnen (inkl. `GDIp/GDIp.ahk`) |
| `Source_Test` | 2 | 28 | nicht funktionsfähig, siehe 3.6 |

Die Abweichung zu deiner Beschreibung: Elemente liegen bei 29.207 Zeilen (inkl. Chrome-Paket), nicht bei ~27.700.

### 1.2 Module und Dateien

- **Main** (`Source_Main`): `main.ahk` (Start, Task-Schleife `queryTasks` per Timer 100 ms, Exit-Routine), `Threads/Threads.ahk` (Thread-Start/Stop), `API/Shared Variables.ahk` (Erzeugung `_cs_shared`, `_share`), `API/API for Elements.ahk`, `Hidden window/`, `Tray/`, `Elements/Elements.ahk`.
- **Manager** (`Source_Manager`): `Manager.ahk`, `User Interface/` (Manager-GUI, Import/Export, Kategorien, globale Einstellungen, Hilfe, Über).
- **Editor** (`Source_Editor`): `Editor.ahk`, `User Interface/` (Editor-GUI, Menüleiste, Eingaben, Element-/Flow-Einstellungen, GDI+, Tooltip, Tray), `Assistants/` (Farbauswahl, Fensterinfo, Mausverfolgung), `Elements/` (Auswahl, Zwischenablage), `API/API for Elements.ahk`.
- **Draw** (`Source_Draw`): `Draw.ahk` (Render-Schleife `drawTask`), `GDIp/GDIp.ahk`.
- **Execution** (`Source_Execution`): `Execution.ahk` (Einstieg, Task-Verteilung), `Execution Task/Execution Task.ahk` (`executionTask()`, die Endlosschleife), `Execution Task/Instances and Threads.ahk` (`newInstance`, `newThread`, `removeThread`, `removeInstance`), `Trigger/Trigger.ahk` (Aktivieren/Deaktivieren, Trigger-Ereignisse), `Variables/Variables.ahk` (Variablen-Zugriff), `API/API for Elements.ahk` (`x_*`-Helfer, 91 Funktionen).
- **Common** (`Source_Common`): `Multithreading/` (86 `_get/_set`-Wrapper in `Shared Variables.ahk`, `API Caller to *.ahk`, `API for Elements.ahk` mit `xx_*`), `Flows/` (`Load.ahk`, `Save.ahk`, `Manage Flows.ahk`, `States.ahk`, `Compatibility.ahk`, `Flow actions.ahk`), `Elements/` (`Elements.ahk`, `Manage Elements.ahk`), `Variables/` (`Code tokenizer.ahk`, `Code parser.ahk`, `Code evaluator.ahk`, `Expression evaluator.ahk`, `Global variables.ahk`), `Debug/` (`Logger.ahk`, `Debug.ahk`), `Settings/`, `Other/`.
- **Elements** (`Source_Elements/Default`): `Actions/` (114), `Conditions/` (17), `Loops/` (5), `Triggers/` (16), `common/` (Fensterfunktionen, Kompatibilität), `lib/` (TTS, Eject, Class_Monitor, HTTP, Process list, Json, Yaml), `manifest.json` (Liste der Dateien für die Einbindung).
- **Lib** (`Lib`): `7z wrapper`, `GDI+`, `Json`, `Objects` (enthält `ObjFullyClone`/`ObjFullyMerge`), `Random Word List`, `Yunit` (Test-Framework, v1), `ini`.

### 1.3 Öffentliche Schnittstellen zwischen Modulen

- **Task-Queue (Nachrichten):** `_setTask(<ziel>, {name: …})` schreibt in `_share.Tasks[<ziel>]`, `_getTask(<ziel>)` liest das erste Element und entfernt es. Ziele sind `execution`, `main`, `draw`, `manager` und `editor<FlowID>`. Die Aufrufer stehen in `API Caller to Execution/Main/Draw/Editor/Manager.ahk`.
  - `API Caller to Execution.ahk` [V]: 9 Funktionen (`ExecuteFlow`, `EnableTriggers`, `StopFlow`, `ExecuteToggleFlow`, `DisableTriggers`, `enableOneTrigger`, `disableOneTrigger`, `externalElementFinish`, `externalTrigger`).
  - `API Caller to Main.ahk` [V]: u. a. `Thread_Stopped`, `StartElementAhkThread`, `StopElementAhkThread`, `ElementThread_Stopped`, `ElementThread_Trigger`. Die Funktion `API_Main_Thread_Stopped` schreibt sogar unter direktem `EnterCriticalSection` ohne den Zähler.
  - `API_Draw_Draw` wird 22-mal aufgerufen [V, Grep].
- **Geteilter Zustand:** `_flows`, `_settings`, `_execution`, `_share`, `_language` als `CriticalObject`s. Zugriff nur über die 86 Wrapper `_get…/_set…` in `Shared Variables.ahk` [V].
- **Element-Helfer `x_*`:** 91 Funktionen je Thread-Variante (Execution, Editor, Manager, Main, Common mit `xx_*`), die sich nur in der Weiterleitung unterscheiden [V]. 88 verschiedene davon werden von den Elementen genutzt [V, Grep].
- **Start der Threads:** `Thread_Start*` in `Threads.ahk` lädt den Quellcode der Thread-Datei, ersetzt `;PlaceholderIncludesOfElements` durch die Element-Includes und ruft `AhkThread(…)` auf [V].

### 1.4 Thread-Topologie [V]

| Thread | Code | Lebensdauer |
|---|---|---|
| Main | `main.ahk` | permanent |
| Manager | `Source_Manager/Manager.ahk` | permanent |
| Draw | `Source_Draw/Draw.ahk` | permanent |
| Execution | `Source_Execution/Execution.ahk` (in `Threads.ahk` mit dem Dateinamen `execution.ahk` referenziert, Groß/Kleinschreibung unterscheidet sich, auf Windows unkritisch) | permanent |
| Editor n | `Source_Editor/Editor.ahk` mit `_FlowID` | pro geöffnetem Flow |
| Element `element_<uniqueID>` | Code des Elements (z. B. AutoHotkey-Skript) | pro laufendem Thread-Element |

---

## 2. Element-API (der wichtigste Vertrag)

### 2.1 Entry-Points [V]

Jedes Element hat einen Klassennamen `<C>`, z. B. `Action_Sleep`, `Condition_Window_Exists`, `Loop_SimpleLoop`, `Trigger_Hotkey`. Pflicht- und Optionalfunktionen:

| Funktion | Pflicht | Aufrufer | Zweck |
|---|---|---|---|
| `Element_getName_<C>()` | ja | Editor, Manager | Anzeigename (über `x_lang`) |
| `Element_getCategory_<C>()` | ja | Editor | Kategorie |
| `Element_getElementLevel_<C>()` | ja | Editor | "Beginner" / "Advanced" / "Programmer" |
| `Element_getIconPath_<C>()` | ja | `Load.ahk` (unter Lock), Editor | Icon-Datei |
| `Element_getStabilityLevel_<C>()` | ja | Editor | "Stable" / "Experimental" |
| `Element_getParametrizationDetails_<C>(Environment)` | ja | `Element_getParametrizationDetails` in `Elements.ahk` | Beschreibt die Felder der Einstellungsmaske. Wird pro Thread **gecacht** (`static`). |
| `Element_GenerateName_<C>(Environment, ElementParameters)` | ja | `Load.ahk` (unter Lock), `Element_updateName` | Anzeigename mit Parametern |
| `Element_CheckSettings_<C>(Environment, ElementParameters, staticValues)` | ja | Editor bei jeder Änderung | Plausibilität, Felder ein-/ausblenden |
| `Element_run_<C>(Environment, ElementParameters)` | Action, Condition, Loop | Execution-Loop, **außerhalb** des Locks | Ausführung. Muss **genau einmal** `x_finish` bzw. `x_enabled` (Trigger) aufrufen. |
| `Element_stop_<C>(Environment, ElementParameters)` | optional | Execution-Loop, **innerhalb** des Locks (Zeile 211) | Abbruch laufender Timer oder Threads |
| `Element_enable_<C>` / `Element_disable_<C>` | Trigger | `Trigger.ahk` | Trigger scharf schalten (Hotkey, Timer, Fenster-Hook) |
| `Element_postTrigger_<C>(Environment, ElementParameters, TriggerData)` | optional, Trigger | `Instances and Threads.ahk:100`, **innerhalb** des Locks | Setzt Thread-Variablen nach einem Trigger-Ereignis |
| `Trigger_<X>_Trigger(Environment, ElementParameters)` | Trigger | Callback von Hotkey/Timer (Execution-Thread) | ruft `x_trigger(Environment)` |

Die Anzahl der Funktionen: `Element_run_` existiert für 136 Elemente (114 Actions + 17 Conditions + 5 Loops), `Element_enable_/disable_/postTrigger_` für 16 Trigger [V, Grep].

### 2.2 Environment-Objekt [V]

Das Environment ist ein assoziatives Array mit inkonsistenter Schreibweise der Schlüssel:
- Beim Ausführen (`Execution Task.ahk:91`): `{instanceID, threadID, flowID, elementID}`
- Beim Stoppen (`Execution Task.ahk:211`): `{FlowID, ElementID, InstanceID, ThreadID}`
- Beim Prüfen (`Manage Elements.ahk`): `{flowID, elementID}`

**Porting-Falle:** AHK v1 behandelt Schlüssel case-insensitiv. In v2 sind `Map()`-Schlüssel case-sensitiv. Beim Umbau auf `Map` muss eine einheitliche Schreibweise festgelegt werden, sonst findet man diese Stellen nicht.

### 2.3 Ergebnisse (Result-Strings) [V]

`x_finish(Environment, <Ergebnis>, <Meldung>)` mit: `normal`, `yes`, `no`, `exception`, `head`, `tail`. Verbindungen im Flow vergleichen den Ergebnisstring mit dem Verbindungstyp (`Execution Task.ahk:119`). v2 verhält sich bei `=` für Strings ebenfalls case-insensitiv, daher bleibt dieser Vergleich gleich.

### 2.4 Gelesene repräsentative Elemente [V]

| Element | Klasse | Besonderheit |
|---|---|---|
| `Actions/Sleep.ahk` | Action | Timer über `x_NewFunctionObject` + `SetTimer, % functionObject, -…`, Abbruch über `Element_stop_` |
| `Conditions/Window_Exists.ahk` | Condition | Fenster-Helfer `windowFunctions_*` (in `common/`), setzt Thread-Variable `A_WindowID` |
| `Loops/SimpleLoop.ahk` | Loop | Einstieg per `x_getEntryPoint` (`Head`/`Tail`), Schleifenzähler als Loop-Variable `A_Index`. Fehlerfall ruft `x_enabled` auf (siehe 3.6). |
| `Triggers/Hotkey.ahk` | Trigger | `Element_enable_` setzt `hotkey` mit Funktionsobjekt, `Element_disable_` schaltet ab, `Element_postTrigger_` setzt `A_Hotkey` |
| `Actions/AutoHotkey_script.ahk` | Action | Nutzt `x_ExecuteInNewAHKThread` (eigener AHK-Thread, Variablen-Export/-Import über `CriticalObject`) |

**Nicht gelesen** (bewusst zurückgestellt): `Eject_Drive`, `Search_Image`, `Search_pixel`, `Get_Screen_Settings`, `Set_Screen_Settings` (DllCall/Dll-abhängig), `Class_Monitor`, `TTS`. Sie stehen in der Liste der „unsicheren Elemente“ aus deinem Prompt.

### 2.5 Mechanismen, die in v2 neu gelöst werden müssen [V]

- **Dynamische Funktionsnamen**: `Element_run_%class%`, `Element_getIconPath_%class%`, `Element_stop_%class%`, `Element_postTrigger_%class%` (an mehreren Stellen, z. B. `Load.ahk`, `Manage Elements.ahk`, `Execution Task.ahk`, `Instances and Threads.ahk`). In v2 braucht es eine Registry (Map von Klassenname auf Funktionsobjekt oder Klasse).
- **Funktionsobjekte** (`x_NewFunctionObject`, `Class_FunctionObject`): Timer und Hotkeys werden über serialisierbare Objekte gebunden, die einen Environment-Schlüssel tragen.
- **Ausdrucksauswertung**: Parameter mit `content: "Expression"` werden über den eigenen Auswerter (`Source_Common/Variables/Expression evaluator.ahk`) berechnet. Dieser Teil ist für die Portierung kritisch (siehe 4).
- **Einbindung per Text-Ersetzung**: Element-Code wird per `;PlaceholderIncludesOfElements` in jeden Thread eingefügt. Das geht in v2 so nicht. Ein Modul-System mit `#Include` pro Element oder eine Registry ist nötig.

---

## 3. Lock-Befunde (Race Conditions, Deadlocks)

### 3.1 Inventur [V]

- `_cs_shared` wird in `Source_Main/API/Shared Variables.ahk:174` als `CriticalSection()` erzeugt und per Code-Präfix an alle Threads weitergegeben.
- `_EnterCriticalSection()` / `_LeaveCriticalSection()` (`Shared Variables.ahk:14–58`): setzt `Critical on`, ruft `EnterCriticalSection(_cs_shared)` auf und führt einen Zähler `criticalSectionCounter`.
- Aufrufe von `EnterCriticalSection(` über das gesamte Projekt (ohne Tools/Lib): **189** [V, Grep]. Davon sind 89 Wrapper-Funktionen in `Shared Variables.ahk`. Die übrigen Aufrufe stehen direkt in Funktionen wie `LoadFlow`, `Save`, `executionTask`, `logger` usw.
- `Critical`-Anweisungen: `Shared Variables.ahk:25, 57` (in den Enter/Leave-Wrappern), `Debug.ahk:48`, `GDIp.ahk:114` (`Critical,on` im Zeichenpfad) [V].
- `AhkThread(`-Aufrufe in `Source_*` (ohne Element-Libs): 11 [V, Grep].
- Das Skript `work_items/analysis_v1/lock_audit.py` (heuristisch, zeilenbasiert) fand 62 Auffälligkeiten. Siehe `work_items/analysis_v1/lock_audit_output.txt`. Gegenprüfung: Die Treffer in `Select elements.ahk:8`, `Instances and Threads.ahk:50`, `Variables.ahk:259`, `Execution Task.ahk:181` und `Load.ahk:271` wurden im Quelltext bestätigt [V].

### 3.2 Gefahrenklasse A: blockierende Aufrufe unter Lock

| Stelle | Befund | Status |
|---|---|---|
| `Load.ahk:47–283` | Lock wird in Zeile 47 genommen und erst in Zeile 283 freigegeben. In Zeile 271 wird `MsgBox` aufgerufen, bis zur Bestätigung ist alles blockiert. Zeile 273 löscht die Datei unter Lock. | [V] |
| `Execution Task.ahk:94` | `MsgBox "Unexpected error! ..."` innerhalb der Execution-Schleife und damit unter Lock. Der Text enthält außerdem die Zeichenkette `Element_run_%oneElementClass%` wörtlich, die Variable wird also nicht ersetzt. | [V] |

### 3.3 Gefahrenklasse B: Datei-I/O unter Lock (37 Stellen, heuristisch)

- `Global variables.ahk`: alle `StaticVariable_*` und `GlobalVariable_*` (Set, Get, Delete) mit `FileRead`, `FileAppend`, `FileDelete`, `FileCreateDir` **innerhalb** des Locks. Bei großen Variablen (`Jxon_Dump` von Objekten) bleibt der Lock lange belegt. [V]
- `Logger.ahk:63–64` (`FileAppend` in `Log.txt` und `Log_<Quelle>.txt` unter Lock), `Logger.ahk:255` (`FileGetSize`), `Logger.ahk:267` (`FileMove` in `log_cleanup`). [V]
- `Save.ahk:41–146`: Der gesamte Speichervorgang läuft unter Lock: Backup-Verzeichnis, `loop, files` über Backups, `FileMove`, `FileDelete`, `FileAppend`. [V]
- `Load.ahk:217–220`: `fileexist` und `FileCreateDir`. [V]
- `Variables.ahk:292, 300`: `fileexist` in `Var_GetLocation`. [V]

**Wirkung:** Während ein Flow speichert oder eine große Variable geschrieben wird, wartet jeder andere Thread, der ein Lock braucht (also praktisch alle, inklusive Execution und Draw). Das ist eine Ursache für die beschriebenen Hänger. [H]

### 3.4 Gefahrenklasse C: fremder Code unter Lock (Element-Code, Callbacks)

| Stelle | Aufruf | Status |
|---|---|---|
| `Load.ahk:116, 122, 129` | `Element_GenerateName_%…%`, `Element_getIconPath_%…%`, `Element_getParameters(…)` | [V] |
| `Manage Elements.ahk:111, 137` | `Element_getIconPath_%…%`, `Element_GenerateName_%…%` | [V] |
| `Save.ahk:87` | `Element_getParameters(…)` | [V] |
| `Execution Task.ahk:211` | `Element_stop_%…%` | [V] |
| `Instances and Threads.ahk:100` | `Element_postTrigger_%…%` | [V] |
| `Execution Task.ahk:224`, `Instances and Threads.ahk:113, 281` | Callbacks `%tempCallBackfunc%(…)` | [V] |

Element-Code ist nicht unter der Kontrolle der Engine. Ein Element kann beliebig lange laufen, Fehler auslösen oder selbst auf einen anderen Thread warten. Im Lock ist das ein Deadlock-Risiko. [H]

### 3.5 Gefahrenklasse D: Exit-Pfade ohne Freigabe (verifiziert)

| Stelle | Befund | Status |
|---|---|---|
| `Global variables.ahk:17, 57, 94, 131` | `throw` nach `_EnterCriticalSection()`, kein Leave. Der Lock bleibt belegt. | [V] |
| `Select elements.ahk:4–8` | `throw` nach `_EnterCriticalSection()`, kein Leave. | [V] |
| `Variables.ahk:255–259` | `throw` nach `_EnterCriticalSection()`, kein Leave. | [V] |
| `Instances and Threads.ahk:11–50` | `throw` nach `_EnterCriticalSection()`, kein Leave. | [V] |
| `Execution Task.ahk:15–181` | `throw` in der Execution-Schleife, bei `State of thread … is unknown!`. Der Lock bleibt belegt **und** die Schleife endet. Ob der Engine-Prozess dann ganz hängt oder nur der Execution-Thread endet, ist nicht geprüft. | [V] Code, [N] Laufzeit |

**Hinweis zur Regel:** AHK v1 kennt kein `try/finally` für Locks. Jede Exception zwischen Enter und Leave ist ein Lock-Leck. Die Heuristik findet 8 solche Stellen, die Stichprobe bestätigt sie.

### 3.6 Weitere Befunde

**Stopp-Pfad (Hypothese, hohes Risiko)** [H]: `Thread_StopElemenThread` (`Threads.ahk:132–146`) ruft `ahkFunction("ahf_exitapp")` und setzt nach 500 ms `Thread_KillElemenThreadIfNotStopped`. Diese Funktion ruft `ahkterminate(100)` auf, also ein **hartes Beenden** des Threads. Wenn der Thread gerade im Critical-Section-Wrapper steht, bleibt `_cs_shared` für immer belegt, und alle anderen Threads hängen. Der Kommentar in `Shared Variables.ahk:11` beschreibt genau dieses Problem. Die Lösung ist im Code nicht vollständig umgesetzt. [N] Reproduzierbarkeit.

**Synchroner Aufruf vom Main-Thread** [H]: `ahkFunction` wartet, bis der Ziel-Thread antwortet. Ein Element-Thread, der in `EnterCriticalSection` blockiert (Zeile 25–26 mit `Critical on`), kann nicht antworten, und Main blockiert ebenfalls. Ob die Dokumentation von AHK_H dieses Verhalten so beschreibt, ist [N], muss im Stresstest geprüft werden.

**Exit-Protokoll** [V]: `_EnterCriticalSection` beendet einen Thread mit `exit` bzw. `exitapp`, sobald `_share.exiting` gesetzt ist, und nur wenn der Zähler 0 ist (`Shared Variables.ahk:27–40`). Zusätzlich gibt es einen harten Timeout: `main.ahk:611` setzt `settimer, exit, 4000`, danach `ExitApp`.

**Verschachtelung** [V]: Jede `_get…/_set…`-Funktion nimmt das Lock einzeln. Eine logische Operation besteht daher aus vielen einzelnen Lock-Zyklen. Ein Beispiel ist `logger()`: je Aufruf rund 7 Lock-Zyklen (`_getSettings` ×2, `_getAndIncrementShared` ×2, `_appendToShared` ×2, plus Enter/Leave für die Datei-Ausgabe). Das ist eine Engstelle, da jede Log-Zeile alle Threads ausbremst.

**Execution-Schleife und Lesen über Lock-Grenzen** [V]: `executionTask` hält das Lock über die Verwaltungsphase, das schützt die dortigen Lese-/Schreibvorgänge. Elemente und Editor greifen aber außerhalb dieser Phase zu. Einzelne Getter geben mit `clone = false` **Referenzen** zurück (15 Stellen in `Multithreading` und `Execution`, z. B. `Execution Task.ahk:220`). Eine Mutation dieser Referenzen außerhalb des Locks wäre ein Race. [H für konkrete Fälle]

**UniqueID** (`Execution Task.ahk:80`) [V] / Risiko [H, eher gering]: `UniqueID := OneInstanceID "_" OneThreadID "_" OneThreadElementID "_" A_TickCount`. Ein Thread führt jeweils nur ein Element aus, und der Eintrag in `global_AllExecutionIDs` wird in `finishExecutionOfElement` (Zeile 298–299) wieder gelöscht. Eine Kollision ist daher nur möglich, wenn derselbe Thread dasselbe Element im selben Millisekunden-Tick erneut startet, bevor der vorherige Eintrag gelöscht wurde. Trotzdem ist die Konstruktion aus Tick-Zähler und Schlüsseln fragil. Empfehlung: Zähler pro Prozess, wie in deinem Prompt beschrieben.

**`currentlyLoadingFlow`** [V]: `Load.ahk:37–42` setzt das Flag, es wird erst in Zeile 284 zurückgesetzt. Jede Exception dazwischen (z. B. bei fehlerhaftem JSON in `Jxon_Load` nach Zeile 42) lässt das Flag für immer auf `true`. Danach wirft jeder weitere Ladevorgang (Zeile 39).

### 3.7 Fehler, die nicht den Lock betreffen [V] (vermutet bzw. klar im Code)

1. **`Execution Task.ahk:220`**: `_getInstanceProperty(OneInstanceID, callback, false)`. Das Wort `callback` steht ohne Anführungszeichen. In `Instances and Threads.ahk:110` und `:278` steht korrekt `"callback"`. Der Callback für gestoppte Instanzen wird dadurch vermutlich nie gefunden. [V Code, Wirkung H]
2. **`Execution Task.ahk:224`**: `%tempCallBackfunc%("stopped", instance.InstanceVars)`. Im gesamten Code gibt es keine Zuweisung an `instance` (Grep). Gemeint ist vermutlich `OneInstance`. [V Code, Wirkung H]
3. **`x_enabled` statt `x_finish` in Element-Ausführung** (6 Stellen): `Actions/Delete_From_Ini.ahk:78`, `Actions/Read_From_Ini.ahk:115`, `Actions/Write_to_ini.ahk:76`, `Conditions/Confirmation_Dialog.ahk:135, 140, 157`, `Loops/SimpleLoop.ahk:74`. Alle stehen in `Element_run_…` [V]. Folge: Das Element endet nicht, sondern bleibt im Zustand „running“ [H, Laufzeit N].
4. **Testsuite nicht lauffähig** [V]: `Source_Test/Unit_Tests.ahk:6` bindet `%a_scriptdir%\..\Source_Main\Globals\Global Variables.ahk` ein. Dieser Pfad existiert nicht. Die Datei `Source_Test/main/Globals/Test globals.ahk` existiert. Die Yunit-Einbindung `..\lib\Yunit` zeigt auf `Lib/Yunit` und ist gültig. Die Testsuite ist also de facto nicht vorhanden.
5. **Datei-Schreibweise**: `Threads.ahk:103` lädt `execution.ahk`, die Datei heißt `Execution.ahk`. Unter Windows egal, im Port zu korrigieren.

---

## 4. v1-spezifische Stellen und Portierungsaufwand

### 4.1 Häufigkeit (grob, Grep über `.ahk` ohne `Lib`/Tools) [V]

| Muster | Treffer | v2-Entsprechung / Problem |
|---|---:|---|
| `AhkThread(` | 11 (Source_*), mehr in Element-Libs | v2: keine Threads im selben Prozess mit `AhkThread`. Ersetzen durch Prozess-Architektur (laut Zielbild). |
| `CriticalObject(` | 11 | entfällt (kein geteilter Zustand mehr) |
| `ahkFunction`, `ahkReady`, `ahkterminate` | 12 | entfällt |
| `EnterCriticalSection(` | 189 | entfällt (Ersatz: Nachrichten) |
| `Object()` | 339 | `Map()` für Schlüsseltreue, `{}` für Records |
| `new X` | 289 | `X()` |
| `Gui,` / `gui,` | 517 | v2 `Gui()`-Objekte (GUI-Umbau notwendig) |
| `MsgBox` | 130 | v2 `MsgBox()`, aber im Engine-Pfad verboten (siehe Zielbild) |
| `ErrorLevel` | 156 | Exceptions (`try/catch`) |
| `StringReplace,` | 42 | v2 `StrReplace()` |
| `IfInString`, `IfNotInString` | 33 | v2 `InStr()` |
| `IfExist`, `IfNotExist` | 16 | v2 `FileExist()` |
| `SetTimer,` | 91 | v2 `SetTimer(fn, period)` |
| `FileRead,` / `FileAppend,` / `FileDelete,` | 33 / 29 / 36 | v2 `FileRead()` / `FileAppend()` / `FileDelete()` |
| `fileread` (Kleinschreibung) | 35 | wie oben |
| `%var%` in Befehlen | ~1000 (Grep, grob, enthält auch Funktionsaufrufe) | v2: Ausdrücke statt Prozent-Syntax |
| `ByRef` | 8 | `&` in v2 |
| `hotkey,` | 28 | v2 `Hotkey()` |
| `Exception(` | 60 | v2 `Error`-Klassen, `throw` bleibt |
| `\bIf\s*\w+\s+is\s` (`if x is number`) | 171 | v2: `IsNumber()`, `IsInteger()` |
| `Return %…` | 25 | v2: `return expr` |
| `sleep,` | 24 | v2 `Sleep()` |

Die Zahlen sind Grep-Treffer und beschreiben die Größenordnung. Sie sind keine exakten Zählungen aus einem Parser.

### 4.2 Lib-Abhängigkeiten [V]

- `Lib/Json` (Jxon): v1, für v2 gibt es Portierungen. Muss ersetzt oder portiert werden.
- `Lib/Objects` (`ObjFullyClone`, `ObjFullyMerge`): nutzt v1-Objektsemantik, wird für jeden Zugriff auf den geteilten Zustand verwendet. Im v2-Zielbild entfällt die Notwendigkeit für Klone über Lock-Grenzen, aber die Serialisierung für IPC braucht eine eigene Lösung.
- `Lib/7z wrapper`, `Lib/GDI+`, `Lib/Yunit` (v1), `Lib/ini`, `Lib/Random Word List`: jeweils einzeln portieren oder ersetzen.
- `Source_Elements/Default/lib`: TTS, Eject, Class_Monitor, HTTP Request, Process list, Json, Yaml. Nicht geprüft, welche davon v2-kompatibel sind [N].

### 4.3 Aufwandsschätzung pro Modul (grob, ohne Messung)

Die Einstufung ist eine qualitative Schätzung. Sie basiert auf Zeilenzahl, Anzahl der v1-Muster und der Architekturänderung. Eine Zeitangabe gebe ich bewusst nicht an, bevor Phase 1 die Architektur festlegt.

| Modul | Zeilen | Einstufung | Begründung |
|---|---:|---|---|
| Source_Elements (152 Elemente) | 29.207 | **XL** | Groß, aber mechanisch. Einheitliches Muster ermöglicht Konverter-Leitfaden. Problematisch: DLL-, COM-, Gui- und Dll-Elemente sowie Ausdruckssyntax. |
| Source_Editor | 7.988 | **XL** | Hauptsächlich GUI (`Gui,` 517 Treffer im Projekt), Zeichnen, Maus-Tracker. Sollte nach dem Zielbild neu gebaut werden. |
| Source_Common Variables (Tokenizer, Parser, Evaluator, Globals) | 2.192 | **L–XL** | Eigenes Ausdrucksformat mit v1-Semantik (Prozent-Variablen, Expression). Hohe Gefahr für Verhaltensänderungen. Braucht Testfälle vor dem Port. |
| Source_Common Flows (1.263) + Elements/Multithreading (2.193) | 3.456 | **L** | Großteils Lock-Logik, die im Zielbild entfällt. Load/Save bleiben als Logik erhalten. |
| Source_Execution | 2.702 | **XL** (Umbau) | Herzstück der Engine. Wird im Zielbild neu strukturiert (Zustandsautomaten, Engine-Prozess). |
| Source_Main | 1.660 | **L** (Umbau) | Thread-Start, Task-Verteilung und Exit werden durch Prozesse und IPC ersetzt. |
| Source_Manager | 2.368 | **L** | GUI-lastig, Import/Export mit 7z. |
| Source_Draw + GDI+ | 1.276 | **M–L** | GDI+ über DllCalls, muss mit v2-GDI+-Bibliothek neu eingebunden werden. |
| Language (`language/*.ini`) | — | **S** | Format bleibt, nur der Lade-Code (`lang()`) ändert sich. |
| Lib | — | **M** | Einzelpakete, jeweils eigene Anpassung. |

Gesamteinstufung: **Die Portierung ist ein Vorhaben in der Größenordnung mehrerer Monate Teilzeit.** Eine genauere Zahl ist erst nach Phase 1 sinnvoll.

---

## 5. Abweichungen zwischen deiner Beschreibung und dem Code

Der Code gilt, hier die Punkte:

1. **Flow-Dateiformat:** Flows werden als `.json` gespeichert (`Save.ahk:146`, `AppData/Saved Flows/*.json`). `.ahf` ist das **ZIP-Exportformat** (`Import and export.ahk:56, 98`). Die Variablen-Dateien heißen `.ahfvd` und `.ahfvar`. Deine Beschreibung „gespeicherte `.ahf`-Flows“ trifft deshalb nicht zu.
2. **`ahkExec` kommt im Code nicht vor.** Verwendet werden `ahkFunction`, `ahkReady` und `ahkterminate`.
3. **Elementanzahl:** 152 Elemente, davon 136 mit `Element_run_` (Actions 114, Conditions 17, Loops 5) und 16 Trigger.
4. **Zeilenzahl Elements:** 29.207 inkl. Chrome-Paket, nicht ~27.700.
5. **`UniqueID`:** Das Risiko ist nach Code-Lesen eher gering. Die Begründung steht in 3.6.
6. **„Trigger laufen in eigenen Prozessen pro Trigger-Art“:** Das stimmt nicht. Trigger laufen als Hotkey-/Timer-Callbacks im Execution-Thread oder als Element-Threads. Das ist für das Zielbild relevant, weil Hotkeys an den Prozess gebunden sind, der sie registriert.
7. **`Source_Execution\execution.ahk`** (`Threads.ahk:103`): Dateiname weicht in der Schreibweise ab (siehe 3.7).
8. **Exit-Mechanismus:** Zusätzlich zum Zähler gibt es einen harten Timeout von 4 Sekunden (`main.ahk:611`), danach `ExitApp`. Das solltest du beim Zielbild für den Shutdown berücksichtigen.
9. **Git-Status:** Zu Beginn zeigte der Snapshot 15 geänderte Dateien in `AppData/Saved Flows`. Beim Prüfen danach war der Working Tree sauber. Round-Trip-Tests sollten immer auf Kopien laufen, nicht auf den echten Dateien.

Alles andere in deiner Beschreibung (Modulliste, Threading-Modell, `_cs_shared`, `criticalSectionCounter`, Element-Einbindung über `Lib_includes`, MsgBox in `Load.ahk`, Logger-I/O, `StaticVariable_Set`-Throw) hat sich bestätigt.

---

## 6. Methode und Grenzen

- **Gelesen** (vollständig oder in relevanten Ausschnitten): `Shared Variables.ahk`, `Execution Task.ahk`, `Load.ahk`, `Global variables.ahk`, `Logger.ahk`, `Threads.ahk`, `Trigger.ahk`, `Instances and Threads.ahk` (Ausschnitte), `API for Elements.ahk` (Execution, Ausschnitte), `API Caller to Execution.ahk`, `API Caller to Main.ahk`, `main.ahk` (Ausschnitte), `Sleep.ahk`, `Window_Exists.ahk`, `SimpleLoop.ahk`, `Hotkey.ahk`, `AutoHotkey_script.ahk` (Ausschnitte), `Unit_Tests.ahk`, `Select elements.ahk`, `Variables.ahk` (Ausschnitte), `checkCriticalSection.ahk`.
- **Heuristik-Skript** `work_items/analysis_v1/lock_audit.py`: zeilenbasiert, zählt `Enter`/`Leave` pro Funktion und meldet `return`/`throw`/`exit` bei gehaltenem Lock, blockierende Aufrufe und Funktionsenden mit Lock. Grenzen: keine echte AHK-Syntax-Analyse, keine Verzweigungsauswertung, `{` in Strings oder Kommentaren können die Funktionsgrenzen verschieben. Gegengeprüft wurden 5 Treffer, alle bestätigt. Nicht gegengeprüft: die Mehrzahl der 37 Datei-I/O-Treffer (sie sind plausibel und zahlreich).
- **Nicht ausgeführt:** Kein AHK-Code wurde gestartet. Die Zeilenangaben stammen aus dem Lesen des Codes. Laufzeitfolgen mit [H] oder [N] sind nicht getestet.
- **Nicht geprüft:** Die Element-Libs unter `Source_Elements/Default/lib`, die Chrome-Pakete, die Dll-abhängigen Elemente, und die vollständigen Editor- und Manager-GUIs.

---

## 7. Offene Fragen vor Phase 1

Die Fragen sind gebündelt. Ich habe zu jeder eine Empfehlung angegeben.

1. **Prozessmodell:** Ein Editor-Prozess für alle Flows mit mehreren Fenstern, oder ein Prozess pro Flow wie heute (Thread pro Flow)? *Empfehlung: ein UI-Prozess mit mehreren Fenstern. Weniger Prozesse, und der Editor braucht den Zustand ohnehin über Nachrichten.*
2. **Draw-Prozess:** Eigener Prozess oder Zeichnen im UI-Prozess? *Empfehlung: im UI-Prozess. GDI+-Handles und Fenster lassen sich nicht sinnvoll über IPC teilen.* Das ist eine begründete Abweichung, die du laut Prompt freigeben musst.
3. **Element-Code, der eigene AHK-Threads nutzt** (z. B. `AutoHotkey_script`): eigene Worker-Prozesse, oder Ausführung im Engine-Prozess? *Empfehlung: eigener Worker-Prozess pro Element-Ausführung, damit Abstürze isoliert bleiben.*
4. **Zielversion AHK v2:** Welche Mindestversion? *Empfehlung: aktuelle stabile 2.0.x, die du festlegst.*
5. **Kompatibilität:** Müssen v1.2.1-Flows und -Variablen unverändert in v2 laden? Der Port soll Dateiformat und `Compatibility.ahk` beibehalten. *Empfehlung: ja, mit eigenem Lade-Test auf Kopien der echten Dateien.*
6. **Branch oder Ordner:** `v2/`-Ordner im selben Repo, oder eigener Branch? *Empfehlung: Branch `v2-port` plus Ordner `v2/`, v1 bleibt auf `master` unverändert.*
7. **Chrome-Paket:** portieren oder ausschließen?
8. **Testrahmen:** Yunit ist v1. *Empfehlung: kleiner eigener Test-Runner in v2, da der Port dadurch unabhängig bleibt.*
9. **Sofortfixes in v1:** Sollen die eindeutigen Einzelfehler (6× `x_enabled`→`x_finish`, `callback`-Quote, `instance`-Variable, `currentlyLoadingFlow`-Reset, Testpfad) als separater v1-Fix-Branch kommen, unabhängig vom Port? *Empfehlung: ja, das sind kleine, risikoarme Änderungen, und sie helfen beim Stresstest als Vergleichsbasis.*
10. **Stresstest-Referenz:** Gibt es bekannte Szenarien, in denen der Hänger reproduzierbar auftritt (Anzahl Flows, Editor öffnen/schließen, schnelle Start/Stop-Folge)? Das hilft, den Reproduzierungstest in Phase 0 bzw. 2 gezielt zu bauen.

---

## 8. Nächste Schritte

- Freigabe von Phase 0 (dieses Dokument).
- Entscheidungen zu den Fragen 1–10, vor allem 1–3 und 9.
- Dann Phase 1: `ARCHITEKTUR.md`, Nachrichtenkatalog, Element-API v2 mit zwei Beispielen.
