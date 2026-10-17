#Requires AutoHotkey v2.0
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ManagerModel.ahk

; The main window of the manager (WI-0073; REQ-MGR-080, REQ-USE-040, REQ-USE-090): the view of the ManagerModel. It holds no
; logic of its own: it draws what the model holds and calls the operations of the model for the buttons.
;
;   - The tree of the categories and their flows (the flow list of WI-0074 grows from it), the buttons as v1, a status line.
;   - A button is enabled by the selection (ManagerModel.ButtonStates). The buttons of the packages that follow
;     (WI-0074 to WI-0081) are shown disabled until their package exists.
;   - The close box only hides the window (E0014); "Exit" asks the supervisor for the end of the application.
;   - Position and size are kept in memory by UiWindow until the settings exist (WI-0077).
;   - The window is redrawn by a timer of 50 ms, and only after a change, so a burst of events is one redraw.
;
; Sizes are pixels at 100 % (UiWindow scales them). Labels are Lang keys of the v1 files (assets/language) and of the
; folder manager.
class ManagerWindow {
    static WIDTH := 750
    static HEIGHT := 510
    static RENDER_MS := 50
    ; Button name -> [x, y, w, label key]; the name is the key of ManagerModel.ButtonStates.
    static BUTTONS := [
        ["NewCategory", 328, 12, 200, "New_category"], ["NewFlow", 538, 12, 200, "New_flow"],
        ["ChangeCategory", 328, 52, 130, "Change_category"], ["Duplicate", 468, 52, 130, "Duplicate_#verb"],
        ["Delete", 608, 52, 130, "Delete"],
        ["Edit", 328, 112, 200, "Edit_#verb"],
        ["Enable", 328, 152, 200, "Enable"], ["Run", 538, 152, 200, "Run_#verb"],
        ["Settings", 328, 212, 200, "Settings"],
        ["ImportExport", 328, 252, 200, "Import_and_export"],
        ["About", 328, 292, 200, "About_AutoHotFlow"], ["Help", 538, 292, 200, "Help_#noun"],
        ["ShowLog", 328, 332, 200, "Show_log"], ["Exit", 538, 332, 200, "Exit_#verb"]]

    __New(model) {
        this.model := model
        this.dirty := true
        this.filling := false
        this.treeItems := Map()       ; tree item ID -> flow ID
        this.itemOfFlow := Map()      ; flow ID -> tree item ID
        this.buttons := Map()         ; name -> control
        this.runIsStop := false
        this.loggedReady := false
        this.fillCount := 0
        this.lastFillMs := -1
        this.win := UiWindow("manager", "Manager", ManagerWindow.WIDTH, ManagerWindow.HEIGHT)
        this.win.hideOnClose := true
        g := this.win.Gui
        this.tree := g.AddTreeView("+Border")
        this.win.Place(this.tree, 12, 12, 300, 456)
        this.tree.OnEvent("ItemSelect", (ctl, item) => this._OnTreeSelect(item))
        for b in ManagerWindow.BUTTONS {
            ctl := g.AddButton()
            this.win.Place(ctl, b[2], b[3], b[4], 30)
            this.win.Text(ctl, b[5])
            ctl.OnEvent("Click", this._ButtonHandler(b[1]))
            this.buttons[b[1]] := ctl
        }
        this.status := g.AddText()
        this.win.Place(this.status, 12, 478, 726, 20)
        this.win.Text(this.status, "Manager_engine_waiting")
        this.statusKey := "Manager_engine_waiting"
        model.AddListener((kind, data) => this._OnModel(kind, data))
        this.renderFn := () => this.Render()
        SetTimer(this.renderFn, ManagerWindow.RENDER_MS)
    }

    ; The window is visible (not hidden by the close box).
    Visible => this.win.Visible

    Show() {
        this.win.Show()
        this.dirty := true
    }

    ; cmd.manager.show: makes the window visible if it is hidden, restores it if it is minimized, and brings it to the front.
    Raise() {
        if (!this.win.Visible)
            this.win.Show()
        else if (WinGetMinMax(this.win.Hwnd) = -1)
            WinRestore(this.win.Hwnd)
        try WinActivate(this.win.Hwnd)
        this.dirty := true
    }

    Hide() {
        this.win.Hide()
    }

    Close() {
        SetTimer(this.renderFn, 0)
        this.win.Close()
    }

    _OnModel(kind, data) {
        this.dirty := true
    }

    ; A handler per button (a closure over the loop variable would see the last button).
    _ButtonHandler(name) => (*) => this._OnButton(name)

    _OnButton(name) {
        switch name {
            case "Run":
                this.model.RunOrStop()
            case "Exit":
                this.model.Exit()
        }
    }

    _OnTreeSelect(item) {
        if (this.filling)
            return
        this.model.Select(this.treeItems.Has(item) ? this.treeItems[item] : "")
    }

    ; Timer, 20 Hz. Draws only when something changed and the window is shown.
    Render() {
        if (!this.dirty || !this.win.Visible)
            return
        this.dirty := false
        this._FillTree()
        this._SetButtons()
        this._SetStatus()
    }

    ; The tree is built again from the model: the categories in the order of the engine, the flows below them. The selected
    ; flow stays selected. (The expand state and the operations on the tree are WI-0074.)
    _FillTree() {
        t0 := Time.NowMs()
        m := this.model
        this.filling := true
        this.tree.Opt("-Redraw")
        try {
            this.tree.Delete()
            this.treeItems := Map()
            this.itemOfFlow := Map()
            shown := Map()
            for c in m.categories {
                ids := []
                for id in c["flows"] {
                    if (m.flows.Has(id) && !shown.Has(id)) {
                        shown[id] := true
                        ids.Push(id)
                    }
                }
                if (c["name"] = "" && ids.Length = 0)
                    continue
                parent := this.tree.Add(c["name"] = "" ? Lang("Uncategorized") : c["name"], 0, "Expand")
                for id in ids
                    this._AddFlow(parent, id)
            }
            rest := []
            for id in m.flowIds {
                if (!shown.Has(id))
                    rest.Push(id)
            }
            if (rest.Length > 0) {
                parent := this.tree.Add(Lang("Uncategorized"), 0, "Expand")
                for id in rest
                    this._AddFlow(parent, id)
            }
            if (m.selectedFlow != "" && this.itemOfFlow.Has(m.selectedFlow))
                this.tree.Modify(this.itemOfFlow[m.selectedFlow], "Select")
        } finally {
            this.tree.Opt("+Redraw")
            this.filling := false
        }
        this.fillCount += 1
        this.lastFillMs := Integer(Time.NowMs() - t0)
        if (!this.loggedReady && m.engineState = ManagerModel.ENGINE_READY) {
            this.loggedReady := true
            Log.Write("a1", "manager", "first display with the engine ready: " m.flowIds.Length " flows, tree filled in "
                . this.lastFillMs " ms, " Integer(Time.NowMs() - m.startMs) " ms after the start of the model")
        }
    }

    _AddFlow(parent, flowId) {
        item := this.tree.Add(this.model.flows[flowId]["name"], parent)
        this.treeItems[item] := flowId
        this.itemOfFlow[flowId] := item
    }

    _SetButtons() {
        states := this.model.ButtonStates()
        for name, ctl in this.buttons
            ctl.Enabled := states[name]
        stop := this.model.RunIsStop()
        if (stop != this.runIsStop) {
            this.runIsStop := stop
            UiTexts.SetKey(this.win.Hwnd, this.buttons["Run"], stop ? "Stop_#verb" : "Run_#verb")
        }
    }

    _SetStatus() {
        m := this.model
        switch m.engineState {
            case ManagerModel.ENGINE_READY:
                key := "Manager_engine_ready"
                args := [m.flowIds.Length]
            case ManagerModel.ENGINE_LOADING:
                key := "Manager_engine_loading"
                args := []
            case ManagerModel.ENGINE_DOWN:
                key := "Manager_engine_down"
                args := []
            default:
                key := "Manager_engine_waiting"
                args := []
        }
        last := m.lastAnswer
        if (IsObject(last) && last.Count > 0 && last["ok"] != Json.True) {
            key := "Manager_answer_failed"
            args := [last["type"], last["code"] (last["message"] != "" ? " " last["message"] : "")]
        }
        UiTexts.SetKey(this.win.Hwnd, this.status, key, "Text", args*)
    }
}
