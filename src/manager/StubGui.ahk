#Requires AutoHotkey v2.0

; Window of the manager stub (v2-phase2-final:v2-phase2-final:work_items/phase2/WI-13-ui-stub.md). Shows the flow list, the element states of the
; selected flow and a status line (connection, epoch, seq, counters, last command latency). Buttons:
; Start, Stop (selected flow), Beenden (cmd.app.exit). Closing the window means Beenden.
;
; Not modal: Gui.Show, no MsgBox, no InputBox, no blocking call. The view has no logic: StubManager
; builds the model (ViewModel) and calls Render at most 20 times per second, and only after a change.
; Labels are ASCII on purpose (the stub has no Lang() yet, and the script encoding is not checked for
; umlauts). Layout test: doc/MANUAL-CHECKS.md, section "Manager stub".
class StubGui {
    __New(manager) {
        this.manager := manager
        this.rowFlowIds := []
        this.win := Gui("+Resize", "AutoHotFlow - manager stub")
        this.win.SetFont("s9", "Segoe UI")
        this.win.AddText("xm w600", "Flows (state as reported by the engine)")
        this.flowList := this.win.AddListView("xm w600 h160 -Multi", ["Flow", "Name", "Aktiv", "Laeuft", "Rev"])
        this.flowList.OnEvent("Click", (lv, row) => this._OnFlowClick(row))
        this.win.AddText("xm w600", "Elements of the selected flow")
        this.elemList := this.win.AddListView("xm w600 h190", ["Element", "Zustand", "Laeufe", "Letzter Lauf", "Meldung"])
        this.btnStart := this.win.AddButton("xm w100", "Start")
        this.btnStop := this.win.AddButton("x+8 yp w100", "Stop")
        this.btnExit := this.win.AddButton("x+8 yp w100", "Beenden")
        this.btnStart.OnEvent("Click", (*) => this.manager.UserStart(this.manager.selectedFlow))
        this.btnStop.OnEvent("Click", (*) => this.manager.UserStop(this.manager.selectedFlow))
        this.btnExit.OnEvent("Click", (*) => this.manager.UserExit())
        this.statusText := this.win.AddText("xm w600 h40", "")
        this.win.OnEvent("Close", (*) => this.manager.UserExit())
        this.win.Show("w620")
    }

    ; Redraws the lists and the status line from a model built by StubManager.ViewModel.
    Render(model) {
        this.statusText.Value := "Verbindung: " model["conn"] "   epoch " model["epoch"] "   seq " model["seq"]
            . "   Ereignisse " model["events"] "   Resync " model["resyncs"]
            . "   letzte Befehlslatenz " (model["latencyMs"] >= 0 ? model["latencyMs"] " ms" : "-")
            . "`n" model["lastResult"]
        this.flowList.Delete()
        this.rowFlowIds := []
        selectRow := 0
        for f in model["flows"] {
            this.flowList.Add("", f["flowId"], f["name"], f["enabled"] ? "ja" : "nein"
                , f["executing"] ? "ja" : "nein", f["rev"])
            this.rowFlowIds.Push(f["flowId"])
            if (f["flowId"] = model["selectedFlow"])
                selectRow := this.rowFlowIds.Length
        }
        if (selectRow > 0)
            this.flowList.Modify(selectRow, "Select Focus")
        this.elemList.Delete()
        for e in model["elements"]
            this.elemList.Add("", e["elementId"], e["state"], e["countRuns"], e["lastRun"], e["message"])
    }

    Close() {
        this.win.Destroy()
    }

    _OnFlowClick(row) {
        if (row > 0 && row <= this.rowFlowIds.Length)
            this.manager.SelectFlow(this.rowFlowIds[row])
    }
}
