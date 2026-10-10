# Architektur-Entwurf: AutoHotFlow v2 (AHF v2)

## 1. Prozessaufteilung & Kernprinzipien

In **AutoHotFlow v2** wird der geteilte Speicher (`CriticalObject`, `_cs_shared`) vollständig abgeschafft. Das System baut auf dem **Actor / Message-Passing Modell** auf: Mehrere isolierte Betriebssystemprozesse kommunizieren ausschließlich über strukturierte Nachrichten über Windows Named Pipes.

```
+-----------------------------------------------------------------------+
|                             MAIN / LAUNCHER                           |
|                      (Prozess-Starter & Systray)                      |
+-----------------------------------------------------------------------+
        |                                       |
        | (Named Pipe)                          | (Named Pipe)
        v                                       v
+-------------------------------+       +-------------------------------+
|         ENGINE-PROZESS        |       |    EDITOR / DRAW CLIENT       |
|  - Sole Source of Truth für   |       |  - Pure IPC Client            |
|    Flow-Laufzeitzustand       |       |  - GDI+ Canvas & UI           |
|  - Flow-Instanzen & Threads   | <---> |  - Sendet Commands (Run/Stop) |
|  - Asynchrones File-I/O       |  IPC  |  - Empfängt Event-Updates     |
|  - Element-Ausführung (Engine)|       |  - Rendert Element-Status     |
+-------------------------------+       +-------------------------------+
        ^
        | (Named Pipe)
        v
+-------------------------------+
|        MANAGER CLIENT         |
|  - Pure IPC Client            |
|  - Flow & Kategorie Liste     |
|  - Import/Export GUI          |
+-------------------------------+
```

### Prozess-Rollen

1. **Main / Launcher Process (`AHF_Main.exe` / `AHF_Main.ahk`)**:
   - Verwaltet den Lebenszyklus der Anwendung, Systray-Icon und globale Hotkeys.
   - Startet und überwacht die Subprozesse (Engine, Manager, Editor).
   - Dient als Master Pipe Server / Router für Verbindungen.

2. **Engine Process (`AHF_Engine.exe` / `AHF_Engine.ahk`)**:
   - **Sole Source of Truth**: Besitzt exklusiv den gesamten Laufzeitzustand (aktive Flows, Instanzen, Threads, Variablen, Trigger).
   - Führt Flow-Elemente aus und verarbeitet Timer.
   - Enthält **keine UI-Dialoge** (z. B. `MsgBox`). Wenn ein Element eine Benutzereingabe erfordert (z. B. `Message_Box`), fordert die Engine den UI-Client per Nachrichten an, den Dialog anzuzeigen, und wartet asynchron auf die Antwort.
   - File-I/O (Laden, Speichern, Loggen) erfolgt strictly asynchron, um die Engine-Nachrichtenschleife niemals zu blockieren.

3. **Editor / Draw Client Process (`AHF_Editor.exe` / `AHF_Editor.ahk`)**:
   - Enthält die Benutzeroberfläche des Editors und die GDI+-Zeichenengine.
   - Reine Client-Anwendung: Sendet Befehle wie `flow:start`, `flow:stop`, `flow:save` an die Engine.
   - Empfängt Ereignisse wie `instance:element_running`, `instance:element_finished` und hebt aktive Elemente grafisch rot hervor.

4. **Manager Client Process (`AHF_Manager.exe` / `AHF_Manager.ahk`)**:
   - Verwaltet die Liste aller Flows und Kategorien (TreeView).
   - Erlaubt das Ein-/Ausschalten von Autostart-Triggern und globale Einstellungen.

---

## 2. Named Pipes IPC Protokoll & Nachrichtenkatalog

### Pipe-Infrastruktur
- Pipe-Name Format: `\\.\pipe\AutoHotFlow_<SessionID>_<TargetProcess>` (z. B. `\\.\pipe\AutoHotFlow_1042_Engine`).
- Transportschicht: UTF-8 codierte JSON-Nachrichten, getrennt durch ein Newline-Zeichen (`\n`).

### Einheitliches Nachrichtenschema
Jede Nachricht hat genau folgende Struktur:

```json
{
  "id": "1042-893",
  "type": "command",
  "from": "editor_1",
  "to": "engine",
  "action": "flow:start",
  "correlation_id": "",
  "payload": {
    "flow_id": "f_1592384912",
    "trigger_id": "manual"
  }
}
```

- `id`: Eindeutige Nachrichten-ID Format: `<process_id>-<counter>` (kein `A_TickCount`).
- `type`: `"command"`, `"response"`, `"event"`, oder `"error"`.
- `from` / `to`: Prozess-Identifikatoren (`"main"`, `"engine"`, `"editor_<id>"`, `"manager"`).
- `action`: Name des Befehls oder Ereignisses.
- `correlation_id`: Bei Anfragen (RPC), die eine Antwort erwarten, trägt die Antwort hier die `id` der ursprünglichen Anfrage.
- `payload`: Ein JSON-Objekt mit spezifischen Parametern.

### Nachrichten-Katalog

#### Commands (Client -> Engine / Main)
| Action | RPC/Event | Timeout | Beschreibung | Payload Params |
| :--- | :--- | :--- | :--- | :--- |
| `flow:start` | RPC | 3.000 ms | Startet einen Flow. | `{ "flow_id": "...", "trigger_id": "..." }` |
| `flow:stop` | RPC | 5.000 ms | Stoppt eine laufende Flow-Instanz. | `{ "instance_id": "..." }` |
| `flow:save` | RPC | 10.000 ms| Weist die Engine an, einen Flow auf Disk zu speichern. | `{ "flow_id": "...", "flow_data": { ... } }` |
| `ui:show_dialog`| RPC | Infinity | Engine bittet Client, eine MsgBox/Dialog anzuzeigen. | `{ "dialog_type": "msgbox", "title": "...", "text": "..." }` |
| `system:shutdown`| RPC | 5.000 ms | Beendet alle Prozesse geordnet. | `{ "reason": "user_exit" }` |

#### Events (Engine -> Clients)
| Action | Empfänger | Beschreibung | Payload Params |
| :--- | :--- | :--- | :--- |
| `instance:created` | Editor, Manager | Eine neue Flow-Instanz wurde gestartet. | `{ "instance_id": "...", "flow_id": "..." }` |
| `instance:element_running` | Editor | Ein Element wird jetzt ausgeführt (Hervorhebung). | `{ "instance_id": "...", "element_id": "..." }` |
| `instance:element_finished`| Editor | Elementausführung beendet. | `{ "instance_id": "...", "element_id": "...", "status": "normal" }` |
| `instance:finished` | Editor, Manager | Flow-Instanz vollständig beendet. | `{ "instance_id": "...", "status": "success" }` |
| `flow:updated` | Editor, Manager | Ein Flow wurde geändert oder geladen. | `{ "flow_id": "...", "flow_data": { ... } }` |

---

## 3. Data Ownership & Asynchrones I/O

| Datenart | Exklusiver Besitzer | Leserechte | Schreibrechte | Persistenz |
| :--- | :--- | :--- | :--- | :--- |
| **Flow-Laufzeitzustand** (Instanzen, Threads, Vars) | **Engine** | Engine (Exklusiv) | Engine (Exklusiv) | In-Memory |
| **Flow-Definitionen (`.ahf` / JSON)** | **Engine** | Alle via IPC | Engine (Asynchron) | `AppData/Saved Flows/*.ahf` |
| **Globale Einstellungen (`settings.json`)** | **Engine** | Alle via IPC | Engine (Asynchron) | `AppData/settings.json` |
| **System-Log (`Log.txt`)** | **Logger Queue** | N/A | Dedicated Async Logger | `AppData/Log/Log.txt` |
| **Editor UI State** (Zoom, Scroll, Selection) | **Editor** | Editor (Exklusiv) | Editor (Exklusiv) | Editor In-Memory |

### I/O Regel im kritischen Pfad
Kein Prozess führt synchrone Datei-E/A im Hauptstrang der Nachrichtenverarbeitung aus. Dateioperationen werden in Hintergrund-Aufgaben gepuffert und sequentiell abgearbeitet.

---

## 4. Lifecycle, Shutdown & Fehlerbehandlung

### Shutdown Ablauf (Graceful Termination)
1. **Initiierung**: Launcher oder UI sendet `system:shutdown` an den Engine-Prozess.
2. **Flow-Stopp**: Engine stoppt alle aktiven Flow-Instanzen geordnet (Aufruf von `stop()` auf allen laufenden Elementen).
3. **Persistenz**: Engine schreibt ausstehende Daten/Variablen asynchron auf Disk.
4. **Quittierung**: Engine antwortet allen Clients mit `{ "status": "ok" }`.
5. **Abmeldung**: Clients schließen ihre Pipe-Handles und beenden sich.
6. **Hard Timeout**: Bricht ein Subprozess nicht innerhalb von **5 Sekunden** nach dem Shutdown-Signal ab, beendet der Launcher-Prozess ihn hart via `ProcessClose()`.

### Fehlerbehandlung & Resilienz
- **Pipe-Absturz / Client-Disconnect**: Bricht die Pipe-Verbindung zum Editor ab, läuft die Engine ungestört weiter. Der Editor kann neu geöffnet und wieder verbunden werden.
- **Timeout-Management**: Jede Anfrage mit `correlation_id` führt ein Timer-Objekt. Antwortet die Gegenseite nicht innerhalb des definierten Timeouts, wird das Versprechen mit einem `TimeoutError` abgebrochen und geloggt.
- **Prozess-Crash**: Der Main-Launcher überwacht die PID aller Prozesse. Stürzt die Engine unerwartet ab, informiert der Launcher den Benutzer und bietet einen Neustart der Engine an.

---

## 5. Abwärtskompatibilität & Flow-Dateiformat (`.ahf`)

Das bestehende Flow-Dateiformat (JSON-Struktur mit Versionierung) bleibt vollständig erhalten.
- `.ahf`-Dateien enthalten Metadaten, Elemente, Verbindungen und Parameter.
- **Compatibility-Layer (`Source_Common/Flows/Compatibility.ahk`)**:
  - Wird nach AHK v2 portiert.
  - Prüft beim Laden die Dateiversion (`fileVersion`).
  - Wendet Transformationen für ältere `.ahf`-Formate an, sodass bestehende Flows ohne Konvertierungsschmerz geladen werden können.

---

## 6. Element-API v2 Spezifikation

In AHF v2 werden Elemente als **AHK v2 Klassen** definiert. Jedes Element erbt von `ElementBase`.

### Vergleich v1 vs. v2

| Eigenschaft | v1 (Alt) | v2 (Neu) |
| :--- | :--- | :--- |
| **Struktur** | Globale Funktionen (`Element_run_...`) | AHK v2 Klasse (`class Action_Message_Box extends ElementBase`) |
| **Instanziierung** | Keine (Funktionssammlung) | Instanz per Element-Ausführung oder Singleton-Metadaten |
| **Rückgabe/Finish** | Globaler Aufruf `x_finish(Environment, ...)` | Instanz-Methode `this.finish(env, "normal")` |
| **UI-Interaktion** | Direct Gui Creation in Engine Thread | Async Message Call to UI Client |
| **Fehlerbehandlung** | Untypisierte Exception / `ErrorLevel` | Standard AHK v2 `try/catch` & `Error` Klassen |

### Beispiel 1: Action Element (`Message_Box.ahk` in AHK v2)

```autohotkey
#Requires AutoHotkey v2.0

class Action_Message_Box extends ElementBase {
    static Name => "Message Box"
    static Category => "User interaction"
    static Level => "Beginner"
    static Stability => "Stable"

    static GetParametrizationDetails(env) {
        params := []
        params.Push(Map("type", "Label", "label", x_lang("Title")))
        params.Push(Map("type", "Edit", "id", "title", "default", x_lang("Title"), "content", "String"))
        params.Push(Map("type", "Label", "label", x_lang("Message")))
        params.Push(Map("type", "multiLineEdit", "id", "message", "default", x_lang("Message"), "content", "String"))
        return params
    }

    static GenerateName(env, params) {
        return x_lang("Message_Box") " - " params["title"]
    }

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        if (evalParams.Has("_error")) {
            return this.finish(env, "exception", evalParams["_errorMessage"])
        }

        ; In Engine process: Send request to UI Client to show MsgBox asynchronously
        env.RequestUIDialog({
            type: "msgbox",
            title: evalParams["title"],
            message: evalParams["message"],
            callback: (result) => this.onDialogComplete(env, result)
        })
    }

    onDialogComplete(env, result) {
        env.SetVariable("A_UserAction", result.button, "thread")
        this.finish(env, "normal")
    }

    stop(env, params) {
        env.CancelUIDialog()
    }
}
```

### Beispiel 2: Condition Element (`File_Exists.ahk` in AHK v2)

```autohotkey
#Requires AutoHotkey v2.0

class Condition_File_Exists extends ElementBase {
    static Name => "File Exists"
    static Category => "File system"
    static Level => "Beginner"
    static Stability => "Stable"

    static GetParametrizationDetails(env) {
        params := []
        params.Push(Map("type", "Label", "label", x_lang("File path")))
        params.Push(Map("type", "FileSelect", "id", "filePath", "default", "", "content", "String"))
        return params
    }

    run(env, params) {
        evalParams := this.autoEvaluateParameters(env, params)
        if (evalParams.Has("_error")) {
            return this.finish(env, "exception", evalParams["_errorMessage"])
        }

        path := evalParams["filePath"]
        if FileExist(path) {
            env.SetConditionResult(true)
            this.finish(env, "normal", "True")
        } else {
            env.SetConditionResult(false)
            this.finish(env, "normal", "False")
        }
    }
}
```

---

## 7. Zusammenfassung der Architektur-Fragen

1. **Named Pipes**: Nutzung von `\\.\pipe\AutoHotFlow_*` als Standard IPC für alle Prozesse.
2. **Editor & Draw Prozess**: Zusammenlegung in einen gemeinsamen UI Client Prozess zur Vermeidung von Canvas IPC Overhead.
3. **Element v2 Klassenmodell**: Alle 114 Actions, 17 Conditions, 5 Loops und 16 Triggers werden nach dem obigen Schema in v2 Klassen umgewandelt.
