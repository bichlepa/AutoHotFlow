#Requires AutoHotkey v2.0

; The window of the debug role (WI-28). Pure view: DebugView holds all state and calls Render at most 10 times per
; second and only after a change. The window has five tabs:
;   Prozesse    the process table (cmd.process.list)
;   Snapshots   a role chosen from a list, its snapshot as formatted JSON
;   Log         the live log with a level and a source filter
;   Ereignisse  the stream of engine and process events, with a pause button
;   Werte       the values sent with Debug.Dump, the selected one as readable JSON
; Above the tabs: "Aktualisieren" (snapshots now), "alle 2 s" (snapshots every 2 s), "Bericht exportieren" (writes a
; diagnostic report and shows its folder in the status line).
;
; Never modal: Gui.Show, no MsgBox, no InputBox, no blocking call. Labels are ASCII (no Lang() yet).
; The list controls are rebuilt only for the visible tab and only when its section changed (DebugView.rev).
; How to check it by hand: doc/MANUAL-CHECKS.md, section "Debug window".
class DebugGui {
    static MARGIN := 10
    static TOP_ROW := 34
    static STATUS_H := 36

    __New(view) {
        this.view := view
        this.shown := Map("proc", -1, "snap", -1, "log", -1, "event", -1, "dump", -1, "status", -1)
        this.snapRoles := []
        this.selectedRole := ""
        this.snapText := ""
        this.dumpRows := []
        this.win := Gui("+Resize +MinSize780x440", "AutoHotFlow - debug")
        this.win.SetFont("s9", "Segoe UI")
        this.btnRefresh := this.win.AddButton("x10 y8 w120 h24", "Aktualisieren")
        this.chkAuto := this.win.AddCheckbox("x140 y12 w80", "alle 2 s")
        this.btnExport := this.win.AddButton("x230 y8 w150 h24", "Bericht exportieren")
        this.status := this.win.AddText("x10 y40 w700 h32", "")
        this.tabs := this.win.AddTab3("x10 y76 w760 h400", ["Prozesse", "Snapshots", "Log", "Ereignisse", "Werte"])

        this.tabs.UseTab(1)
        this.procList := this.win.AddListView("x20 y108 w740 h360", ["Name", "Rolle", "Zustand", "PID", "Neustarts"])
        this.procList.ModifyCol(1, 140)
        this.procList.ModifyCol(2, 100)
        this.procList.ModifyCol(3, 90)
        this.procList.ModifyCol(4, 70)
        this.procList.ModifyCol(5, 80)

        this.tabs.UseTab(2)
        this.roleChoice := this.win.AddDropDownList("x20 y108 w260", [])
        this.snapEdit := this.win.AddEdit("x20 y140 w740 h328 ReadOnly -Wrap HScroll VScroll", "")
        this.snapEdit.SetFont("s9", "Consolas")

        this.tabs.UseTab(3)
        this.win.AddText("x20 y110 w40", "Ebene")
        this.levelChoice := this.win.AddDropDownList("x62 y106 w130 Choose4", ["a0 (Fehler)", "bis a1", "bis a2", "alles (a3)"])
        this.win.AddText("x210 y110 w50", "Quelle")
        this.sourceEdit := this.win.AddEdit("x262 y106 w200", "")
        this.logList := this.win.AddListView("x20 y138 w740 h330", ["Zeit (UTC)", "Ebene", "Quelle", "Text"])

        this.tabs.UseTab(4)
        this.btnPause := this.win.AddButton("x20 y104 w100 h24", "Pause")
        this.eventInfo := this.win.AddText("x130 y108 w400", "")
        this.eventList := this.win.AddListView("x20 y138 w740 h330", ["Nr", "Zeit (lokal)", "Typ", "Inhalt"])

        this.tabs.UseTab(5)
        this.dumpList := this.win.AddListView("x20 y108 w740 h130", ["Zeit (UTC)", "Von", "Titel"])
        this.dumpList.ModifyCol(1, 140)
        this.dumpList.ModifyCol(2, 120)
        this.dumpList.ModifyCol(3, 300)
        this.dumpEdit := this.win.AddEdit("x20 y246 w740 h222 ReadOnly -Wrap HScroll VScroll", "")
        this.dumpEdit.SetFont("s9", "Consolas")
        this.tabs.UseTab()

        this.btnRefresh.OnEvent("Click", (*) => this.view.RefreshSnapshots())
        this.chkAuto.OnEvent("Click", (*) => this.view.SetAutoRefresh(this.chkAuto.Value))
        this.btnExport.OnEvent("Click", (*) => this.view.Export())
        this.tabs.OnEvent("Change", (*) => this._ForceVisible())
        this.roleChoice.OnEvent("Change", (*) => this._OnRoleChoice())
        this.levelChoice.OnEvent("Change", (*) => this._OnLogFilter())
        this.sourceEdit.OnEvent("Change", (*) => this._OnLogFilter())
        this.btnPause.OnEvent("Click", (*) => this._OnPause())
        this.dumpList.OnEvent("ItemSelect", (lv, item, selected) => this._OnDumpSelect(item, selected))
        this.win.OnEvent("Size", (g, minMax, w, h) => this._Layout(w, h))
        this.win.OnEvent("Close", (*) => this._OnClose())
        this.win.Show("w780 h500")
        this.view.dirty := true
    }

    Close() {
        this.win.Destroy()
    }

    ; The window is brought to the front (a second `--command=debug`).
    Raise() {
        this.win.Show()
        this.win.Restore()
    }

    ; --- layout ------------------------------------------------------------------------------------------

    _Layout(w, h) {
        if (w <= 0 || h <= 0)
            return                                   ; minimized
        m := DebugGui.MARGIN
        this.status.Move(, , w - 2 * m, DebugGui.STATUS_H)
        this.tabs.Move(, , w - 2 * m, h - 76 - m)
        innerW := w - 2 * m - 20
        innerH := h - 76 - m - 36
        this.procList.Move(, , innerW, innerH)
        this.snapEdit.Move(, , innerW, innerH - 32)
        this.logList.Move(, , innerW, innerH - 30)
        this.eventList.Move(, , innerW, innerH - 30)
        this.dumpList.Move(, , innerW, 130)
        this.dumpEdit.Move(, , innerW, innerH - 138)
    }

    ; --- user actions ---------------------------------------------------------------------------------

    _OnClose() {
        this.win.Hide()
        this.view.CloseWindow()
    }

    _OnRoleChoice() {
        i := this.roleChoice.Value
        this.selectedRole := (i > 0 && i <= this.snapRoles.Length) ? this.snapRoles[i] : ""
        this.shown["snap"] := -1
        this.view.dirty := true
    }

    _OnLogFilter() {
        this.view.SetLogFilter(this.levelChoice.Value - 1, this.sourceEdit.Value)
    }

    _OnPause() {
        this.view.SetPaused(!this.view.paused)
    }

    _OnDumpSelect(item, selected) {
        if (!selected || item < 1 || item > this.dumpRows.Length)
            return
        this.dumpEdit.Value := StrReplace(this.dumpRows[item]["json"], "`n", "`r`n")
    }

    ; After a tab change the new tab is drawn at the next Render, whatever its section's revision is.
    _ForceVisible() {
        for key in ["proc", "snap", "log", "event", "dump"]
            this.shown[key] := -1
        this.view.dirty := true
    }

    ; --- drawing ---------------------------------------------------------------------------------------

    Render() {
        v := this.view
        if (this.shown["status"] != v.rev["status"]) {
            this.shown["status"] := v.rev["status"]
            this.status.Value := v.lastExport
        }
        tab := this.tabs.Value
        if (tab = 1)
            this._DrawProcesses()
        else if (tab = 2)
            this._DrawSnapshots()
        else if (tab = 3)
            this._DrawLog()
        else if (tab = 4)
            this._DrawEvents()
        else if (tab = 5)
            this._DrawDumps()
    }

    _Stale(key) {
        if (this.shown[key] = this.view.rev[key])
            return false
        this.shown[key] := this.view.rev[key]
        return true
    }

    _DrawProcesses() {
        if (!this._Stale("proc"))
            return
        lv := this.procList
        lv.Opt("-Redraw")
        lv.Delete()
        for name in this.view.processNames {
            p := this.view.processes[name]
            lv.Add("", name, p.Get("role", ""), p.Get("state", ""), p.Get("pid", ""), p.Get("restarts", ""))
        }
        lv.Opt("+Redraw")
    }

    _DrawSnapshots() {
        if (!this._Stale("snap"))
            return
        names := []
        for name, _ in this.view.snapshots
            names.Push(name)
        if (this.selectedRole = "" || !this.view.snapshots.Has(this.selectedRole))
            this.selectedRole := names.Length ? names[1] : ""
        if (!this._SameList(names, this.snapRoles)) {
            this.snapRoles := names
            this.roleChoice.Delete()
            if (names.Length)
                this.roleChoice.Add(names)
        }
        for i, name in this.snapRoles
            if (name = this.selectedRole)
                this.roleChoice.Choose(i)
        text := this.selectedRole = "" ? "Noch kein Snapshot. 'Aktualisieren' fragt alle Rollen."
            : "Stand " this.view.snapshots[this.selectedRole]["at"] "`n" this.view.snapshots[this.selectedRole]["text"]
        text := StrReplace(text, "`n", "`r`n")
        if (text != this.snapText) {
            this.snapText := text
            this.snapEdit.Value := text
        }
    }

    _DrawLog() {
        if (!this._Stale("log"))
            return
        lv := this.logList
        lv.Opt("-Redraw")
        lv.Delete()
        for e in this.view.VisibleLog(500)
            lv.Add("", e["ts"], e["level"], e["source"], e["text"])
        lv.ModifyCol(1, 140)
        lv.ModifyCol(2, 45)
        lv.ModifyCol(3, 110)
        lv.ModifyCol(4, 500)
        n := lv.GetCount()
        if (n > 0)
            lv.Modify(n, "Vis")
        lv.Opt("+Redraw")
    }

    _DrawEvents() {
        if (!this._Stale("event"))
            return
        v := this.view
        this.btnPause.Text := v.paused ? "Weiter" : "Pause"
        this.eventInfo.Value := v.paused ? "angehalten bei Nr " v.pausedAtN " (" (v.eventN - v.pausedAtN) " neue Ereignisse wartend)"
            : "Ereignisse gesamt: " v.eventN
        lv := this.eventList
        lv.Opt("-Redraw")
        lv.Delete()
        for e in v.VisibleEvents(300)
            lv.Add("", e["n"], e["ts"], e["type"], v.EventText(e))
        lv.ModifyCol(1, 50)
        lv.ModifyCol(2, 90)
        lv.ModifyCol(3, 180)
        lv.ModifyCol(4, 400)
        n := lv.GetCount()
        if (n > 0 && !v.paused)
            lv.Modify(n, "Vis")
        lv.Opt("+Redraw")
    }

    _DrawDumps() {
        if (!this._Stale("dump"))
            return
        lv := this.dumpList
        lv.Opt("-Redraw")
        lv.Delete()
        this.dumpRows := this.view.dumps.Clone()
        for d in this.dumpRows
            lv.Add("", d["ts"], d["from"], d["title"])
        n := lv.GetCount()
        if (n > 0) {
            lv.Modify(n, "Select Focus Vis")
            this.dumpEdit.Value := StrReplace(this.dumpRows[n]["json"], "`n", "`r`n")
        }
        lv.Opt("+Redraw")
    }

    _SameList(a, b) {
        if (a.Length != b.Length)
            return false
        for i, item in a
            if (item != b[i])
                return false
        return true
    }
}
