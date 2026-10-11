# Element-API v2

Status: Entwurf. Grundlage für die Portierung der 152 v1-Elemente (114 Actions, 17 Conditions, 5 Loops, 16 Trigger).
Vorgänger: die v1-Funktionsfamilie `Element_<Aufgabe>_<Klasse>` und die Helfer `x_*` (siehe `work_items/ANALYSE.md`, Abschnitt 2).

---

## 1. Leitlinien

1. **Eine Klasse pro Element**, eine Datei pro Klasse. Der Klassenname ist identisch mit der v1-Klassen-ID (`Action_Sleep`, `Trigger_Hotkey`), denn diese Zeichenkette steht im Feld `class` der gespeicherten Flows. Die Auflösung ist case-insensitiv (v1 schreibt `trigger_manual` und `Trigger_Manual`).
2. **Alle Methoden sind `static`.** Elemente sind zustandslos. Zustand einer Ausführung liegt in `ctx.State`.
3. **Der Kontext `ctx` ersetzt `Environment` und alle `x_*`-Funktionen.** Er hat feste, kleingeschriebene Felder (`flowId`, `elementId`, `instanceId`, `threadId`). Die uneinheitliche Schreibweise aus v1 entfällt.
4. **Fehler sind Exceptions.** `throw ElementError(msg)` beendet die Ausführung mit Ergebnis `exception` und der Meldung. Die Engine fängt jeden Aufruf mit `try/catch`, Elementcode kann sie nicht zum Absturz bringen.
5. **Parameter kommen ausgewertet an.** Die Engine besitzt die Variablen und wertet Parameter mit `content: "Expression"` aus, bevor `Run`/`Enable` aufgerufen wird. Das gilt auch für Worker und Trigger.
6. **Ein Element deklariert seinen Ausführungsmodus** (`inline`, `worker`, `trigger`). Siehe ARCHITEKTUR 2.3.
7. **Keine globalen Variablen, kein `%var%`-Zugriff, kein `ErrorLevel`.**

---

## 2. Klassenvertrag

```ahk
class Action_Example extends AhfElement {
    ; --- Metadaten (statisch, billig, ohne Seiteneffekt) ---
    static Mode      := "inline"        ; "inline" | "worker" | "trigger"
    static Level     := "Beginner"      ; "Beginner" | "Advanced" | "Programmer"
    static Stability := "Stable"        ; "Stable" | "Experimental"
    static Icon      := "example.ico"   ; Dateiname unter assets/Icons, "" = keins
    static JobTimeoutMs := 0            ; nur Worker: Jobfrist in ms, 0 = keine (WI-27, ARCHITEKTUR 6.4)

    static Name()     => Lang("Example")            ; Anzeigename
    static Category() => Lang("General")

    ; --- Editor-Seite (läuft im Editor-Prozess) ---
    static Parameters(ctx) => [ ... ]                      ; Beschreibung der Felder (Schema wie v1)
    static GenerateName(ctx, params) => Lang("Example")    ; Name mit Parametern
    static CheckSettings(form, params, staticValues) {     ; Felder aktivieren/deaktivieren
        form.Disable("WhenRelease", params.BlockKey)
    }

    ; --- Laufzeit-Seite (Engine, Worker oder Triggerhost) ---
    static Run(ctx, params) {          ; Action, Condition, Loop
        ctx.Finish("normal")           ; genau einmal (oder via Timer/Callback später)
    }
    static Stop(ctx, params) {         ; optional: Abbruch (Timer des ctx werden automatisch abgebrochen)
    }
}
```

**Trigger** (`Mode := "trigger"`) haben statt `Run`/`Stop`:

```ahk
    static Enable(ctx, params)  ; scharf schalten. Rückgabe: optionale Meldung. throw bei Fehler.
    static Disable(ctx)         ; abschalten
    static TriggerVariables(params, data) => Map()   ; reine Funktion, läuft in der Engine
```

`TriggerVariables` ersetzt `Element_postTrigger_*`: Es liefert die Thread-Variablen (Name → Wert), die nach dem Ereignis gesetzt werden, und darf keine Seiteneffekte haben (läuft in der Engine, kein I/O).

**Worker-Elemente und Blockieren (WI-27, ARCHITEKTUR 6.4):** Ein Worker-Element darf beliebig lange in einem Aufruf blockieren (Download, COM, `DllCall`, Dialog). Ein Worker mit Job wird nie angepingt und nie als hängend beendet. Zwei Folgen: Ein Abbruch (Stopp der Instanz) erreicht ein Element, das in einem einzigen Aufruf blockiert, nicht. Nach 2 s ohne Quittung lässt die Engine den ganzen Prozess beenden (es läuft nur ein Job je Worker, es geht nichts anderes verloren); `Stop(ctx, params)` des Elements läuft dann nicht mehr, Aufräumen im Element ist dort nicht möglich. Und: Ohne `JobTimeoutMs` hat der Job keine Frist (v1 hatte keine). Setzt eine Klasse `JobTimeoutMs` > 0, endet der Thread nach dieser Zeit mit dem Ergebnis `exception` und der Meldung "worker timeout", und das Element wird wie bei einem Abbruch beendet. Die Frist ist ein Klassenwert, kein Parameter; ein Parameter des Flows (z. B. "Timeout" bei einem Download) bleibt Sache des Elements.

**Klassen-ID:** Nicht über `cls.Name` lesen. Eine Klasse mit `static Name()` verdeckt die eingebaute Eigenschaft, `cls.Name` ist dann eine Funktion. Die ID liefert `ElementRegistry.IdOf(cls)` (intern `Type(cls())`). Verifiziert in WI-09.

**Registrierung:** Am Dateiende `ElementRegistry.Register(Action_Example)`. Das ist der einzige erlaubte Code auf Dateiebene. Er läuft beim Laden, vor `AhfMain`. Damit ein Fehler dort (doppelte Klasse, ungültiger `Mode`) keinen Dialog zeigt, setzt der Einstieg `src/AutoHotFlow.ahk` `OnError` als erste ausführbare Anweisung, **vor** den `#Include`-Zeilen (Handler `AhfLoadError`: Meldung auf stderr, Exit 1). Eine Elementdatei braucht dafür nichts zu tun. (Entscheidung WI-22: nicht die Registrierung in eine Funktion verlegen, weil das Hunderte Elementdateien in Phase 3 und die Vorlage änderte, ohne mehr zu fangen: der Handler deckt auch jeden anderen Code auf Dateiebene ab.) Die Registry ist ein `Map` mit `CaseSense := "Off"`. Ein generierter Include-Block pro Rolle (Engine, Editor, Worker, Triggerhost) bindet die Dateien ein, keine Textersetzung zur Laufzeit.

**Parametercontainer:** `params` ist ein Objekt mit case-insensitivem Eigenschaftszugriff (`params.Duration` gleich `params.duration`), wie v1 es nutzt. Variablenablagen dagegen sind `Map` mit `CaseSense := "Off"`, damit Variablennamen wie in v1 groß-/kleinschreibungsunabhängig bleiben und v2-Objekte nicht verwechselt werden.

---

## 3. Kontext `ctx`

| Mitglied | Ersetzt (v1) | Bemerkung |
|---|---|---|
| `ctx.flowId`, `.elementId`, `.instanceId`, `.threadId` | `Environment.FlowID` usw. | feste Schreibweise |
| `ctx.EvalParams(params)` | `x_AutoEvaluateParameters` | gibt ausgewertete Parameter zurück, wirft bei Fehler (kein `_error`) |
| `ctx.EvalParams(params, skipList)` | mit `p_skipList` | – |
| `ctx.Finish(result, msg := "")` | `x_finish` | `result`: `normal`, `yes`, `no`, `exception`, `head`, `tail` |
| `ctx.SetVar(name, value, scope := "")` | `x_SetVariable` | `scope`: `thread`, `loop`, `instance`, `static`, `global`, wie v1. Phase 2 (WI-09): nur `""`/`thread` und `instance`, andere Scopes werfen `ElementError`. |
| `ctx.GetVar(name, default := "")` | `x_GetVariable` | Sucht erst im Thread-, dann im Instanz-Scope. Liefert `default`, wenn nicht gesetzt (Phase 2: Parameter `default` ergänzt, WI-09). Im Worker nur über `imports` oder `ctx.Request`. |
| `ctx.After(ms, fn)` | `x_NewFunctionObject` + `SetTimer` | Timer gehört zur Ausführung, wird bei Stopp/Ende automatisch abgebrochen |
| `ctx.State` | `x_SetExecutionValue`/`x_GetExecutionValue`, `x_SetTriggerValue`/`x_getTriggerValue` | Objekt pro Ausführung (Run) bzw. pro scharf geschaltetem Trigger |
| `ctx.Fire(data := "")` | `x_trigger` | nur Trigger. Meldet `evt.trigger.fired` |
| `ctx.Log(level, text)` | `x_log` | Level `f0` bis `f3` |
| `ctx.Request(type, payload, callback, timeoutMs)` | – (neu) | Anfrage an die Engine mit Callback. Nur Worker/Trigger. |
| `ctx.RunScript(code, imports, exports)` | `x_ExecuteInNewAHKThread` | für AHK-Code-Elemente. Läuft immer als Worker. |
| `Lang(key, args*)` | `x_lang` | globale Funktion, Sprachdateien unverändert |
| `form.Disable(id, cond)`, `form.Enable(id, cond)` | `x_Par_Disable`/`x_Par_Enable` | nur in `CheckSettings` |
| `form.SetValue(id, v)`, `form.SetChoices(id, list)`, `form.SetLabel(id, text)` | `x_Par_SetValue` usw. | – |

Die Zahl der tatsächlich genutzten v1-Helfer ist 88 (`x_*`). Die häufigsten: `x_lang` (2211 Aufrufe), `x_finish` (681), `x_Par_Disable`/`Enable` (~420), `x_SetVariable` (171), `x_AutoEvaluateParameters` (129).

---

## 4. Beispiel 1: `Action_Sleep` (inline, mit Timer)

**v1** (`v1/Source_Elements/Default/Actions/Sleep.ahk`, gekürzt):

```ahk
Element_run_Action_Sleep(Environment, ElementParameters)
{
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage)
		return
	}
	switch (EvaluatedParameters.Unit)
	{
	case "Milliseconds": duration := EvaluatedParameters.duration
	case "Seconds":      duration := EvaluatedParameters.duration * 1000
	case "Minutes":      duration := EvaluatedParameters.duration * 60000
	}
	functionObject := x_NewFunctionObject(environment, "Action_Sleep_EndSleep", ElementParameters)
	x_SetExecutionValue(Environment, "functionObject", functionObject)
	SetTimer, % functionObject, -%duration%
}
Element_stop_Action_Sleep(Environment, ElementParameters)
{
	functionObject := x_getExecutionValue(Environment, "functionObject")
	SetTimer, % functionObject, off
}
Action_Sleep_EndSleep(Environment, ElementParameters)
{
	x_finish(Environment, "normal")
}
```

**v2:**

```ahk
#Requires AutoHotkey v2.0

class Action_Sleep extends AhfElement {
    static Mode      := "inline"
    static Level     := "Beginner"
    static Stability := "Stable"
    static Icon      := "sleep.ico"

    static Name()     => Lang("Sleep")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Duration")},
        {type: "edit", id: "Duration", default: 2, content: "Expression", WarnIfEmpty: true},
        {type: "Radio", id: "Unit", default: 2, result: "enum"
            , choices: [Lang("Milliseconds"), Lang("Seconds"), Lang("Minutes")]
            , enum: ["Milliseconds", "Seconds", "Minutes"]}
    ]

    static GenerateName(ctx, params) {
        switch params.Unit {
            case "Milliseconds": d := params.Duration " " Lang("ms #Milliseconds")
            case "Seconds":      d := params.Duration " " Lang("s #Seconds")
            case "Minutes":      d := params.Duration " " Lang("m #Minutes")
        }
        return Lang("Sleep") ": " d
    }

    static CheckSettings(form, params, staticValues) {
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)          ; wirft bei Fehler -> Ergebnis "exception"
        switch p.Unit {
            case "Milliseconds": ms := p.Duration
            case "Seconds":      ms := p.Duration * 1000
            case "Minutes":      ms := p.Duration * 60000
        }
        ctx.After(ms, () => ctx.Finish("normal"))   ; Timer wird bei Stopp automatisch entfernt
    }
}

ElementRegistry.Register(Action_Sleep)
```

Was sich ändert: kein `Element_stop` mehr nötig (der Kontext räumt den Timer ab), Fehlerpfad entfällt (Exception), Rückruf als Lambda statt benannter Funktion.
Was gleich bleibt: Klassen-ID, Parameter-IDs und -Schema, Sprachschlüssel, Ergebnisstrings, Namensformat.

---

## 5. Beispiel 2: `Trigger_Hotkey` (läuft im Triggerhost)

**v1** (`v1/Source_Elements/Default/Triggers/Hotkey.ahk`): `Element_enable_`, `Element_disable_`, `Element_postTrigger_`, Callback `Trigger_Hotkey_Trigger` → `x_trigger(Environment)`. Der Hotkey wird mit `hotkey, % fullHotkey, % functionObject, UseErrorLevel on` gesetzt.

**v2:**

```ahk
#Requires AutoHotkey v2.0

class Trigger_Hotkey extends AhfElement {
    static Mode      := "trigger"
    static Level     := "Beginner"
    static Stability := "Stable"

    static Name()     => Lang("Hotkey")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) {
        p := [
            {type: "Label", label: Lang("Hotkey")},
            {type: "Hotkey", id: "hotkey"},
            {type: "Label", label: Lang("Options")},
            {type: "Checkbox", id: "BlockKey", default: 1, label: Lang("Block_key")},
            {type: "Checkbox", id: "Wildcard", default: 0, label: Lang("Trigger even if other keys are already held down")},
            {type: "Checkbox", id: "WhenRelease", default: 0, label: Lang("Trigger on release rather than press")},
            {type: "Label", label: Lang("Scope")},
            {type: "Radio", id: "UseWindow", default: 1, result: "enum"
                , choices: [...]   ; wie v1
                , enum: ["Everywhere", "WindowIsActive", "WindowExists", "WindowIsNotActive", "WindowNotExists"]}
        ]
        WindowFunctions.AddIdentificationParameters(p, {noExcludes: true})
        return p
    }

    static GenerateName(ctx, params) => Lang("Hotkey") " - " params.Hotkey

    static CheckSettings(form, params, staticValues) {
        form.Disable("WhenRelease", params.BlockKey)
        form.Disable("BlockKey", params.WhenRelease)
        showWin := params.UseWindow != "Everywhere"
        for id in ["TitleMatchMode", "Wintitle", "excludeTitle", "winText", "ExcludeText", "ahk_class", "ahk_exe"
                 , "ahk_id", "ahk_pid", "FindHiddenText", "FindHiddenWindow", "GetWindowInformation"]
            form.Enable(id, showWin)
    }

    ; params sind ausgewertet (die Engine hat Variablen aufgelöst)
    static Enable(ctx, params) {
        if (params.hotkey = "")
            throw ElementError(Lang("The_Hotkey_is_not_set!"))

        full := params.hotkey
        if !params.BlockKey
            full := "~" full
        if params.WhenRelease
            full .= " UP"
        if params.Wildcard
            full := "*" full

        ctx.State.hotIf := Trigger_Hotkey._ContextFor(params)   ; Funktion oder ""
        ctx.State.full := full
        try {
            Trigger_Hotkey._SetContext(ctx.State.hotIf)
            Hotkey(full, (*) => ctx.Fire(), "On")
        } catch as e {
            throw ElementError(Lang("The hotkey %1% cannot be set!", full))
        } finally {
            HotIf()                                             ; Kontext zurücksetzen
        }
        return Lang("The hotkey %1% was set.", full)
    }

    static Disable(ctx) {
        ; wichtig: derselbe Kontext wie beim Setzen (v1 vergisst das)
        Trigger_Hotkey._SetContext(ctx.State.hotIf)
        try Hotkey(ctx.State.full, "Off")
        HotIf()
    }

    ; reine Funktion, läuft in der Engine
    static TriggerVariables(params, data) => Map("A_Hotkey", params.hotkey)

    ; Fensterkontext über HotIfWinActive/HotIfWinExist/... bzw. HotIf(fn)
    static _ContextFor(params) { ... }
    static _SetContext(hotIf) { ... }
}

ElementRegistry.Register(Trigger_Hotkey)
```

Was sich ändert: Die Engine wertet Parameter aus und schickt sie an den Triggerhost (`cmd.trigger.arm`). `x_enabled`/`x_disabled` entfallen (Rückgabewert bzw. Exception), `Element_postTrigger_` wird zur reinen Funktion `TriggerVariables`.
Was verbessert ist (in [MIGRATION.md](MIGRATION.md) vermerkt): `Disable` setzt denselben `HotIf`-Kontext wie `Enable`. In v1 wird `hotkey, <key>, off` ohne Kontext aufgerufen, ein kontextgebundener Hotkey bleibt dann möglicherweise aktiv.
Zusätzlich: v1 ruft im Fehlerfall der Fensterparameter in `Element_enable` `x_finish` statt `x_enabled` auf (`Hotkey.ahk` Zeile 134). In v2 gibt es dieses Muster nicht mehr, ein Fehler ist immer `throw`.

---

## 6. Mechanische Umsetzungsregeln

| v1 | v2 |
|---|---|
| `Element_run_<C>(Environment, ElementParameters)` | `static Run(ctx, params)` in `class <C> extends AhfElement` |
| `Element_getName_<C>()` usw. | `static Name()`, `Category()`, `Level`, `Stability`, `Icon` |
| `Element_getParametrizationDetails_<C>(Environment)` | `static Parameters(ctx)` |
| `Element_GenerateName_<C>(Environment, ElementParameters)` | `static GenerateName(ctx, params)` |
| `Element_CheckSettings_<C>(Environment, ElementParameters, staticValues)` | `static CheckSettings(form, params, staticValues)` |
| `Element_stop_<C>` | `static Stop(ctx, params)` (häufig überflüssig) |
| `Element_enable_<C>` / `Element_disable_<C>` / `Element_postTrigger_<C>` | `Enable` / `Disable` / `TriggerVariables` |
| `x_AutoEvaluateParameters` + `if _error` | `ctx.EvalParams` |
| `x_finish(Environment, r, m)` | `ctx.Finish(r, m)` |
| `x_enabled`/`x_disabled` | Rückgabe bzw. `throw` |
| `x_lang("k")` | `Lang("k")` |
| `x_NewFunctionObject` + `SetTimer, % fo, -n` | `ctx.After(n, fn)` |
| `x_SetExecutionValue` / `x_getExecutionValue` | `ctx.State.<name>` |
| `StringReplace, out, in, a, b, all` | `out := StrReplace(in, a, b)` |
| `IfInString, hay, needle` | `if InStr(hay, needle)` |
| `FileRead, v, path` + `ErrorLevel` | `try v := FileRead(path)` / `catch` |
| `Object()` / `{}` als Wörterbuch mit exakten Schlüsseln | `Map()` |
| `if x is number` | `IsNumber(x)` |
| `%var%` als Befehlsparameter | Ausdruck |
| `Return %x%` | `return x` |
| `global` Deklaration in Funktionen | explizite Parameter oder `static` |

Ein Konverter (`tools/convert_element.py`, Phase 3) übernimmt die Zeilen dieser Tabelle automatisch, setzt `Mode` nach Heuristik und markiert alle nicht eindeutig umsetzbaren Stellen mit `; TODO(v2-review): <Grund>`.

**Heuristik für `Mode`:** `worker`, wenn der Quelltext einen von `RunWait`, `WinWait*`, `MsgBox`, `InputBox`, `FileSelect*`, `URLDownloadToFile`, `HTTPRequest`, `DllCall`, `ComObject`, `Gui`, `Sleep` (außerhalb von Timern), `x_ExecuteInNewAHKThread` enthält. Sonst `inline`. Triggerklassen sind immer `trigger`. Das Ergebnis wird von Hand geprüft.

**Als unsicher markiert (nicht raten):** alles mit eigenem AHK-Thread, COM, DllCall, TTS, Eject, `Class_Monitor`, Bildschirmeinstellungen, `Block_User_Input`.

---

## 7. Was bleibt

- Das Beschreibungsformat der Parameter (`type`, `id`, `default`, `content: "Expression"`, `result: "enum"`, `choices`, `enum`, `WarnIfEmpty`, ...) damit der Einstellungsdialog des Editors portierbar bleibt.
- Klassen-IDs, Parameter-IDs, Ergebnisstrings, Sprachschlüssel, Paketname und -version in Flow-Dateien.
- Die Semantik der Loop-Eintrittspunkte (`head`/`tail`, `x_getEntryPoint` wird `ctx.entryPoint`).
- Loop-Variablen (`A_Index` usw.) über `ctx.SetVar(..., "loop")`.

## 8. Noch zu klären (Phase 3)

- Genaue Form von `ctx.Request` und der Importliste für Worker (`imports`) bei Elementen, die beliebige Variablen lesen.
- Ob Metadaten und Laufzeitcode je Rolle getrennt werden müssen (ARCHITEKTUR R3).
- Umgang mit Elementpaketen von Dritten (`package`, `packageVersion`): Das Chrome-Paket entfällt, die Struktur der Paketinformation bleibt für das Laden alter Flows erhalten.
