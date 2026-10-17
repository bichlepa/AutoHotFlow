#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\GuiLayout.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ManagerModel.ahk

; The log window of the manager (WI-0080, REQ-MGR-070, PROTOCOL 4.8): a view of the ManagerModel's log. It holds no logic of
; its own: the filters call ManagerModel.LogFilter, the rows are the entries of ManagerModel.LogVisible.
;
;   - Filters: level (only errors, some, many, all = the highest digit shown), source group (all, app = a, flow = f,
;     the level letter of an entry; E0081 removed the thread group) and the flow.
;   - The rows are added and removed at the front and the end only: a redraw adds the new rows and removes the rows that
;     fell out of the model's limit. A change of the filter or a reopening rebuilds the list.
;   - The redraw is a timer of 50 ms, and runs only while the window is visible: a burst of lines is one redraw.
;   - Closing the window (the close box, or the hide) closes the log in the model: the topic is unsubscribed.
;
; Column widths are pixels at 100 % (GuiLayout.Scale). They are not set again when the DPI changes (not checked).
class LogWindow {
    static WIDTH := 760
    static HEIGHT := 470
    static RENDER_MS := 50
    ; Filter choices: the Lang key and the value of each entry, in the order of the drop-down lists.
    static LEVEL_KEYS := ["Log_only_errors", "Log_some", "Log_many", "Log_all"]
    static LEVEL_VALUES := ["0", "1", "2", "3"]
    static GROUP_KEYS := ["Log_source_all", "Log_source_app", "Log_source_flow"]
    static GROUP_VALUES := ["all", "a", "f"]

    __New(model) {
        this.model := model
        this.dirty := true
        this.filterChanged := true
        this.flowsChanged := true
        this.shown := []         ; the n of the rows in the list, in order
        this.flowIds := []       ; the flow of drop-down item k+1 is flowIds[k]
        this.timerOn := false
        this.renderFn := () => this.Render()
        this.win := UiWindow("manager.log", "Log", LogWindow.WIDTH, LogWindow.HEIGHT)
        this.win.hideOnClose := true
        g := this.win.Gui
        levels := []
        for key in LogWindow.LEVEL_KEYS
            levels.Push(Lang(key))
        groups := []
        for key in LogWindow.GROUP_KEYS
            groups.Push(Lang(key))
        this.levelBox := g.AddDropDownList("", levels)
        this.groupBox := g.AddDropDownList("", groups)
        this.flowBox := g.AddDropDownList("", [Lang("Log_all_flows")])
        this.win.Place(this.levelBox, 12, 12, 200)
        this.win.Place(this.groupBox, 222, 12, 170)
        this.win.Place(this.flowBox, 402, 12, 346)
        this.levelBox.OnEvent("Change", (*) => this._OnFilter())
        this.groupBox.OnEvent("Change", (*) => this._OnFilter())
        this.flowBox.OnEvent("Change", (*) => this._OnFilter())
        this.lv := g.AddListView("+Report -Multi +Grid", [Lang("Log_time"), Lang("Log_level"), Lang("Log_source"), Lang("Log_text")])
        this.win.Place(this.lv, 12, 48, 736, 380)
        lay := this.win.lay
        this.lv.ModifyCol(1, GuiLayout.Scale(lay, 150))
        this.lv.ModifyCol(2, GuiLayout.Scale(lay, 50))
        this.lv.ModifyCol(3, GuiLayout.Scale(lay, 170))
        this.lv.ModifyCol(4, GuiLayout.Scale(lay, 350))
        this.status := g.AddText()
        this.win.Place(this.status, 12, 438, 736, 20)
        this.win.onHide := () => this._OnHidden()
        model.AddListener((kind, data) => this._OnModel(kind, data))
    }

    ; Shows the window. The model is opened by the caller (ManagerModel.OpenLog) with the flow of the filter.
    Show() {
        this.win.Show()
        this.dirty := true
        this.filterChanged := true
        this.flowsChanged := true
        this._StartTimer()
    }

    Hide() {
        this.win.Hide()
    }

    Close() {
        this._StopTimer()
        this.win.Close()
    }

    Visible => this.win.Visible

    ; Hidden by the close box or by Hide: the timer stops and the log of the model is closed.
    _OnHidden() {
        this._StopTimer()
        this.model.CloseLog()
    }

    _StartTimer() {
        if (this.timerOn)
            return
        this.timerOn := true
        SetTimer(this.renderFn, LogWindow.RENDER_MS)
    }

    _StopTimer() {
        this.timerOn := false
        SetTimer(this.renderFn, 0)
    }

    _OnModel(kind, data) {
        switch kind {
            case "open", "close", "filter", "tail":
                this.filterChanged := true
                this.dirty := true
            case "entry":
                this.dirty := true
            case "snapshot":
                this.flowsChanged := true
                this.dirty := true
        }
    }

    ; A filter control changed by the user: the model gets the whole filter.
    _OnFilter() {
        level := this.levelBox.Value
        group := this.groupBox.Value
        flowIndex := this.flowBox.Value
        if (level < 1 || group < 1)
            return
        flowId := (flowIndex > 1 && flowIndex - 1 <= this.flowIds.Length) ? this.flowIds[flowIndex - 1] : ""
        this.model.LogFilter(Map("level", LogWindow.LEVEL_VALUES[level], "group", LogWindow.GROUP_VALUES[group]
            , "flowId", flowId))
    }

    ; Timer: draws only when something changed and the window is shown.
    Render() {
        if (!this.win.Visible) {
            this._StopTimer()
            return
        }
        if (!this.dirty)
            return
        this.dirty := false
        if (this.flowsChanged)
            this._FillFlows()
        if (this.filterChanged)
            this._SetFilterControls()
        visible := this.model.LogVisible()
        this.lv.Opt("-Redraw")
        try {
            if (this.filterChanged || visible.Length = 0)
                this._Rebuild(visible)
            else
                this._Update(visible)
        } finally {
            this.lv.Opt("+Redraw")
        }
        this.filterChanged := false
        this.status.Text := Lang("Log_shown", visible.Length, this.model.logEntries.Length)
    }

    ; The whole list again (a new filter, a new opening, nothing left to show).
    _Rebuild(visible) {
        this.lv.Delete()
        this.shown := []
        for e in visible {
            this._AddRow(e)
            this.shown.Push(e["n"])
        }
    }

    ; The rows of the list are those of the filter: the rows that fell out of the model's limit leave at the front, the new
    ; entries are added at the end.
    _Update(visible) {
        first := visible[1]["n"]
        while (this.shown.Length > 0 && this.shown[1] < first) {
            this.lv.Delete(1)
            this.shown.RemoveAt(1)
        }
        last := this.shown.Length > 0 ? this.shown[this.shown.Length] : 0
        for e in visible {
            if (e["n"] > last) {
                this._AddRow(e)
                this.shown.Push(e["n"])
            }
        }
    }

    _AddRow(e) {
        text := StrReplace(StrReplace(e["text"], "`r", ""), "`n", " | ")
        this.lv.Add("", LogWindow.LocalTime(e["ts"]), e["level"], e["source"], text)
    }

    ; The UTC text of an entry as the local time (the same clock as the log files, PROTOCOL 4.6).
    static LocalTime(utc) {
        digits := RegExReplace(String(utc), "\D")
        if (StrLen(digits) != 14)
            return String(utc)
        offset := DateDiff(A_Now, A_NowUTC, "Seconds")
        return FormatTime(DateAdd(digits, offset, "Seconds"), "yyyy-MM-dd HH:mm:ss")
    }

    ; The flow drop-down: all flows, then the flows of the model in their order.
    _FillFlows() {
        items := [Lang("Log_all_flows")]
        ids := []
        for id in this.model.flowIds {
            ids.Push(id)
            items.Push(this.model.flows[id]["name"])
        }
        this.flowIds := ids
        this.flowBox.Delete()
        this.flowBox.Add(items)
        this.flowsChanged := false
    }

    ; The drop-downs show the filter of the model.
    _SetFilterControls() {
        for i, value in LogWindow.LEVEL_VALUES {
            if (value = this.model.logLevel)
                this.levelBox.Choose(i)
        }
        for i, value in LogWindow.GROUP_VALUES {
            if (value = this.model.logGroup)
                this.groupBox.Choose(i)
        }
        choice := 1
        for i, id in this.flowIds {
            if (id = this.model.logFlowId)
                choice := i + 1
        }
        this.flowBox.Choose(choice)
    }
}
