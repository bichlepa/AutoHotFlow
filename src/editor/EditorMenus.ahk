#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include FlowGeometry.ahk
#Include FlowHitTest.ahk
#Include WinClipboard.ahk

; The menus of the editor (WI-0102, REQ-EDT-110, REQ-EDT-090, REQ-EDT-080, REQ-TRG-030): the menu bar of v1 (Save, Run, Stop,
; Enable or Disable, Edit with Undo, Redo, Cut, Copy, Paste, Delete, Select all, Settings, Exit) and the context menus of the
; canvas (an element, a connection, an empty place). Both come from one spec: a list of entries Map("id", "label", "enabled"
; (1 or 0), "items"), so the headless driver (cmd.test.state, cmd.test.command) reads and runs what the window shows.
; A separator is the id "-".
;
; Every action goes through Run(item): a menu item, the key table (Ctrl+Z, Ctrl+Y, Ctrl+S, EditorKeys) and the test seam.
; Run answers 1 when the action was started, 0 when the item is disabled, "" for an unknown item. The actions use the objects
; of the keys and the mouse: the pointer (copy, cut, paste, delete, select all), the draft (undo, redo), the tray and the
; flow commands (run, stop, save, enable or disable), the triggers (EditorTriggers), the class list of a new element (EditorAdd).
;
; The menu bar is the MenuBar of the window (Bar). Refresh keeps its states and the label of Enable or Disable in line with the
; model; the role calls it on every change of the model. A context menu is built when it opens (Open) and shows what the place
; offers at that moment. The paste is enabled when the clipboard holds our format (WinClipboard.Available), checked at the
; time of the spec: a clipboard that another editor fills is seen at the next change of this editor.
class EditorMenus {
    __New(role) {
        this.role := role
        this.menuBar := ""              ; the MenuBar of the window (not with --headless), see Bar
        this.placed := Map()        ; id -> Map("menu", Menu, "label", text, "enabled", 1|0) of the bar items (Refresh)
        this.context := []          ; the entries of the last context menu (Open); the headless driver reads and runs them
        this.at := ""               ; the canvas pixel of the last context menu (a paste goes there) or ""
        this.flow := [0, 0]         ; the flow point of the last context menu (a new element goes there)
        this.target := ""           ; the element of the last context menu (its settings, WI-0106), "" for none
    }

    ; --- the spec -------------------------------------------------------------------------------------------------------------

    ; The entries of the menu bar: each has its items (empty for an entry without a submenu).
    BarSpec() {
        model := this.role.model
        st := model.flowState
        selected := this._SelectionCount() > 0
        toggleLabel := (st["enabled"] || st["independentActive"] > 0) ? Lang("Disable") : Lang("enable")
        edit := [
            EditorMenus._Entry("undo", Lang("Undo"), model.draft.undoSteps.Length > 0),
            EditorMenus._Entry("redo", Lang("Redo"), model.draft.redoSteps.Length > 0),
            EditorMenus._Entry("-", "", true),
            EditorMenus._Entry("cut", Lang("Menu_cut"), selected),
            EditorMenus._Entry("copy", Lang("copy #verb"), selected),
            EditorMenus._Entry("paste", Lang("Menu_paste"), WinClipboard.Available()),
            EditorMenus._Entry("delete", Lang("Delete"), selected),
            EditorMenus._Entry("selectAll", Lang("Menu_select_all"), model.ElementCount() > 0)
        ]
        return [
            EditorMenus._Entry("save", Lang("Save #verb"), true),
            EditorMenus._Entry("run", Lang("Run #verb"), true),
            EditorMenus._Entry("stop", Lang("Stop #verb"), st["executing"]),
            EditorMenus._Entry("toggle", toggleLabel, true),
            EditorMenus._Entry("edit", Lang("Edit #verb"), true, edit),
            EditorMenus._Entry("settings", Lang("Settings"), false),      ; the flow settings dialog comes with WI-0109
            EditorMenus._Entry("exit", Lang("Exit #verb"), true)
        ]
    }

    ; The entries of a context menu. kind: "element", "connection" or "empty". trigger: the Trigger state Map of a trigger
    ; (SceneElement.Trigger) or "" for another element. An element: edit (its settings, WI-0106), cut, copy, delete; a trigger
    ; adds its switch and the default. A connection: change type, delete. An empty place: paste, select all, and a new action,
    ; condition, loop or trigger at the place.
    static ContextSpec(kind, trigger := "", pasteOk := false) {
        if (kind = "element") {
            items := [
                EditorMenus._Entry("edit", Lang("Edit #verb"), true),
                EditorMenus._Entry("cut", Lang("Menu_cut"), true),
                EditorMenus._Entry("copy", Lang("copy #verb"), true),
                EditorMenus._Entry("delete", Lang("Delete"), true)
            ]
            if (trigger is Map) {
                items.Push(EditorMenus._Entry("-", "", true))
                switchLabel := Lang(trigger["enabled"] ? "Menu_trigger_disable" : "Menu_trigger_enable")
                items.Push(EditorMenus._Entry("toggleTrigger", switchLabel, true))
                items.Push(EditorMenus._Entry("setDefault", Lang("Menu_set_default"), trigger["manual"] && !trigger["default"]))
            }
            return items
        }
        if (kind = "connection") {
            return [
                EditorMenus._Entry("changeType", Lang("Menu_change_type"), true),
                EditorMenus._Entry("delete", Lang("Delete"), true)
            ]
        }
        return [
            EditorMenus._Entry("paste", Lang("Menu_paste"), pasteOk),
            EditorMenus._Entry("selectAll", Lang("Menu_select_all"), true),
            EditorMenus._Entry("-", "", true),
            EditorMenus._Entry("newAction", Lang("Create new action"), true),
            EditorMenus._Entry("newCondition", Lang("Create new condition"), true),
            EditorMenus._Entry("newLoop", Lang("Create new loop"), true),
            EditorMenus._Entry("newTrigger", Lang("Create new trigger"), true)
        ]
    }

    static _Entry(id, label, allowed, items := "") {
        return Map("id", id, "label", label, "allowed", allowed ? 1 : 0, "items", IsObject(items) ? items : [])
    }

    ; The number of selected elements and connections.
    _SelectionCount() => this.role.model.draft.selection.Count

    ; The bar entries and their items, flattened: ID -> Map("label", text, "enabled", 1|0).
    _Flat() {
        out := Map()
        for entry in this.BarSpec() {
            out[entry["id"]] := Map("label", entry["label"], "allowed", entry["allowed"])
            for item in entry["items"]
                out[item["id"]] := Map("label", item["label"], "allowed", item["allowed"])
        }
        return out
    }

    ; --- the menu bar ---------------------------------------------------------------------------------------------------------

    ; The MenuBar of the window. Made again when the language changes (OnSettings); the states follow in Refresh.
    Bar() {
        bar := MenuBar()
        this.placed := Map()
        for entry in this.BarSpec() {
            if (entry["items"].Length = 0) {
                this._AddItem(bar, entry, true)
                continue
            }
            sub := Menu()
            for item in entry["items"]
                this._AddItem(sub, item, true)
            bar.Add(entry["label"], sub)
            this.placed[entry["id"]] := Map("menu", bar, "label", entry["label"], "allowed", 1)
        }
        this.menuBar := bar
        return bar
    }

    ; Brings the bar in line with the model: the enabled states and the label of Enable or Disable. Only what changed is
    ; changed in the menu. Nothing happens without a bar (--headless).
    Refresh() {
        if (!IsObject(this.menuBar))
            return
        for id, now in this._Flat() {
            if (!this.placed.Has(id))
                continue
            p := this.placed[id]
            if (now["label"] != "" && now["label"] != p["label"]) {
                try p["menu"].Rename(p["label"], now["label"])
                p["label"] := now["label"]
            }
            if (now["allowed"] != p["allowed"]) {
                try {
                    if (now["allowed"])
                        p["menu"].Enable(p["label"])
                    else
                        p["menu"].Disable(p["label"])
                }
                p["allowed"] := now["allowed"]
            }
        }
    }

    ; One entry of a menu: a separator, or an item with its callback and its state. track: kept for Refresh (the bar).
    _AddItem(menu, entry, track := false) {
        if (entry["id"] = "-") {
            menu.Add()
            return
        }
        menu.Add(entry["label"], this._Bind(entry["id"]))
        if (!entry["allowed"])
            menu.Disable(entry["label"])
        if (track)
            this.placed[entry["id"]] := Map("menu", menu, "label", entry["label"], "allowed", entry["allowed"])
    }

    ; The callback of an item: a closure over its own id (a loop variable would hold the last id, HOW-TO).
    _Bind(id) => (*) => this.Run(id)

    ; --- the context menu -----------------------------------------------------------------------------------------------------

    ; The right button went up without a movement (EditorPointer): cx, cy is the canvas pixel, fx, fy the flow point of the
    ; press. An element or connection under the press is selected alone when it is not selected (a left click does that
    ; too). The menu of what lies there is built and shown (the window); the headless driver reads it from this.context.
    Open(cx, cy, fx, fy) {
        model := this.role.model
        sc := model.CurrentScene()
        hit := (sc = "") ? "" : FlowHitTest.At(sc, fx, fy)
        kind := "empty"
        trigger := ""
        if (IsObject(hit)) {
            kind := EditorMenus._KindOf(sc, hit.Id)
            if (kind = "element" || kind = "connection") {
                if (!model.draft.selection.Has(hit.Id)) {
                    model.draft.SetSelection([hit.Id], "one")
                    model.SelectionChanged()
                }
            }
            if (kind = "element")
                trigger := EditorMenus._TriggerOf(sc, hit.Id)
        }
        this.at := [cx, cy]
        this.flow := [fx, fy]
        this.target := (kind = "element") ? hit.Id : ""
        pasteOk := WinClipboard.Available()
        this.context := EditorMenus.ContextSpec(kind, trigger, pasteOk)
        if (!this.role.headless && IsObject(this.role.window))
            this.Popup(this.context).Show()
    }

    ; A context menu of the entries, to show at the mouse (Menu.Show).
    Popup(entries) {
        menu := Menu()
        for entry in entries
            this._AddItem(menu, entry)
        return menu
    }

    ; --- the actions ----------------------------------------------------------------------------------------------------------

    ; Runs an item: its ID, or "ctx:<ID>" for an entry of the open context menu (the test seam). Answers 1 when the action was
    ; started, 0 when the item is disabled, "" for an unknown item.
    Run(item) {
        fromContext := (SubStr(item, 1, 4) = "ctx:")
        id := fromContext ? SubStr(item, 5) : item
        entry := this._Find(id, fromContext)
        if (entry = "")
            return ""
        if (!entry["allowed"])
            return 0
        this._Act(id)
        return 1
    }

    ; The entry of an ID: the open context menu first, then the bar (an ID that is in both is the same action).
    _Find(id, fromContext) {
        for entry in this.context {
            if (entry["id"] = id)
                return entry
        }
        if (fromContext)
            return ""
        flat := this._Flat()
        return flat.Has(id) ? flat[id] : ""
    }

    ; The action of an ID. The keys and the mouse call the same methods (EditorPointer, EditorFlowOps, EditorTriggers, EditorAdd).
    _Act(id) {
        role := this.role
        switch id {
            case "save":
                role.flowOps.Save((res) => this._Refused(res, "Menu_save_refused"))
            case "run":
                role.tray.Run()
            case "stop":
                role.flowOps.Stop((res) => this._Refused(res, "Menu_stop_refused"))
            case "toggle":
                role.tray.Toggle()
            case "undo":
                role.model.draft.Undo()
            case "redo":
                role.model.draft.Redo()
            case "cut":
                role.pointer.Cut()
            case "copy":
                role.pointer.Copy()
            case "paste":
                role.pointer.Paste(this.at)
            case "delete":
                role.pointer.Delete()
            case "selectAll":
                role.pointer.SelectAll()
            case "exit":
                role.tray.Close()
            case "changeType":
                role.connect.ChangeType(this._Selected())
            case "toggleTrigger":
                role.triggers.Switch(this._Selected())
            case "setDefault":
                role.triggers.SetDefault(this._Selected())
            case "newAction", "newCondition", "newLoop", "newTrigger":
                origin := FlowGeometry.CentredOrigin(this.flow[1], this.flow[2])
                role.add.Placed(EditorMenus._KindOfNew(id), origin[1], origin[2])
            case "edit":
                role.settings.Open(this.target)         ; the settings of the element under the last context menu (WI-0106)
            ; "settings" has no action yet (WI-0109)
        }
    }

    ; The answer of a flow command that the menu started: a refusal is a text in the status bar.
    _Refused(res, key) {
        if (!res["ok"])
            this.role.model.Notice(key)
    }

    ; The one selected element or connection (the target of an entry of a context menu).
    _Selected() {
        for id in this.role.model.draft.selection
            return id
        return ""
    }

    ; --- the test seam --------------------------------------------------------------------------------------------------------

    ; The state for cmd.test.state: the bar and the entries of the last context menu (IDs, labels, states as Json booleans).
    State() {
        return Map("bar", EditorMenus.Wire(this.BarSpec()), "context", EditorMenus.Wire(this.context))
    }

    static Wire(entries) {
        out := []
        for entry in entries
            out.Push(Map("id", entry["id"], "label", entry["label"], "enabled", Json.Bool(entry["allowed"])
                , "items", EditorMenus.Wire(entry["items"])))
        return out
    }

    ; "element", "connection" or "" for an ID of the scene.
    static _KindOf(sc, id) {
        if (!IsObject(sc))
            return ""
        for element in sc.Elements {
            if (element.Id = id)
                return "element"
        }
        for connection in sc.Connections {
            if (connection.Id = id)
                return "connection"
        }
        return ""
    }

    ; The trigger state Map of the element with the ID, or "" for an element that is not a trigger.
    static _TriggerOf(sc, id) {
        for element in sc.Elements {
            if (element.Id = id && element.Kind = "trigger" && element.Trigger is Map)
                return element.Trigger
        }
        return ""
    }

    static _KindOfNew(id) {
        switch id {
            case "newAction": return "action"
            case "newCondition": return "condition"
            case "newLoop": return "loop"
        }
        return "trigger"
    }
}
