#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\core\Role.ahk
#Include ManagerModel.ahk
#Include ManagerOps.ahk
#Include ManagerImport.ahk
#Include ManagerArchive.ahk
#Include ManagerDriver.ahk
#Include ManagerWindow.ahk

; Role "manager" (WI-0073, doc/ARCHITECTURE.md 3 and 8, doc/PROTOCOL.md 4.8): the main window of the application. The role
; connects the three parts of the manager:
;   ManagerModel   the UI state and the commands to the engine, no GUI code (the truth stays in the engine and in storage)
;   ManagerWindow  the view; it shows the model and calls its operations
;   ManagerDriver  the test commands cmd.test.* on the operations of the model, only with --headless
;
;   AutoHotkey64.exe src\entry\manager.ahk --role=manager --session=<id> --hub=<pipe> --data=<dir> [--headless] [--cancel-exit]
;   --headless      no window; adds the test commands cmd.test.* (PROTOCOL 4.8) and keeps a record of the events
;   --cancel-exit   answers cmd.app.prepareExit with cancel true (tests the cancelled exit, headless)
;
; The window shows itself when the manager is ready. Closing it only hides it (E0014); "Show manager" of the tray menu and a
; second start of the product send cmd.manager.show, which shows it again. The supervisor never restarts a manager that
; ended (Children.AUTO_RESTART); the tray icon starts a new one.
class Manager extends Role {
    __New(args) {
        super.__New(args)
        this.headless := args.Has("headless")
        this.cancelExit := args.Has("cancel-exit")
        this.model := ""
        this.ops := ""               ; the operations on flows and categories (WI-0074), made with the model
        this.importer := ""          ; the import from v1 (WI-0076), made with the model
        this.archive := ""           ; the export and import of .ahf files (WI-0081), made with the model
        this.view := ""
        this.driver := ""
        this.started := false
    }

    RegisterHandlers() {
        this.model := ManagerModel(this.peer)
        this.ops := ManagerOps(this.model)
        this.importer := ManagerImport(this.model)
        this.importer.log := (level, text) => this._Log(level, "manager", text)
        this.archive := ManagerArchive(this.model)          ; the .ahf export and import (WI-0081)
        this.archive.log := (level, text) => this._Log(level, "manager", text)
        this.On("evt.", (msg) => this._OnEvent(msg))
        this.On("cmd.app.prepareExit", (msg) => this._OnPrepareExit(msg))
        this.On("cmd.manager.show", (msg) => this._OnShow(msg))
        this.FollowSettings()      ; log thresholds and language (WI-0077)
        if (this.headless) {
            this.model.TraceOn()
            this.driver := ManagerDriver(this, this.model)
            this.importer.ask := this.driver
            this.archive.ask := this.driver
        }
    }

    OnReady() {
        this.SetLogTarget("storage")
        if (!this.started) {
            this.started := true
            this.model.Note("manager.ready", Map("headless", this.headless ? 1 : 0))
            if (!this.headless) {
                this.view := ManagerWindow(this.model, this)
                this.importer.ask := this.view
                this.archive.ask := this.view
                this.view.Show()
            }
        }
        ; After a reconnect to the hub the state may be out of date: the first snapshot is asked for again.
        this.model.Start()
    }

    ; Role part of the snapshot (doc/PROTOCOL.md 4.9): the connection to the engine, the sequence state and the counters.
    DiagInfo() {
        m := this.model
        return Map("topics", this.peer.Topics(), "engine", m.engineState, "epoch", m.epoch, "lastSeq", m.lastSeq, "flows", m.flows.Count
            , "events", m.eventCount, "resyncs", m.resyncCount, "selectedFlow", m.selectedFlow
            , "windowVisible", IsObject(this.view) ? (this.view.Visible ? 1 : 0) : 0
            , "redrawTimer", IsObject(this.view) ? (this.view.timerOn ? 1 : 0) : 0, "headless", this.headless ? 1 : 0
            , "language", LangTable.Code)
    }

    OnShutdown(deadlineMs) {
        this.model.Note("manager.shutdown", Map("deadlineMs", deadlineMs))
        if (IsObject(this.view)) {
            this.view.Close()
            this.view := ""
        }
    }

    ; The settings changed (WI-0077): Role.ApplySettings has loaded the new language; the open windows get its texts.
    OnSettings(settings) {
        UiTexts.Reload()
        if (IsObject(this.view))
            this.view.Refresh()      ; the tree, the lists and the open dialogs get the new texts (WI-0078)
    }

    ; The event goes to the model too (it checks the sequence and keeps the settings for the dialog).
    OnSettingsMessage(msg) {
        this.model.OnEvent(msg.type, msg.payload)
    }

    ; Every event of a topic that the model subscribed to. The entries of topic log go to the log part of the model
    ; (WI-0080, only while the log is open); the other log events are not for the model.
    _OnEvent(msg) {
        if (msg.type = "evt.log.entry") {
            this.model.OnLogEntry(msg.payload)
            return
        }
        if (SubStr(msg.type, 1, 8) = "evt.log.")
            return
        this.model.OnEvent(msg.type, msg.payload)
    }

    ; The log window (WI-0080, PROTOCOL 4.8): opens the log of the model (flowId "" = all flows) and shows the window
    ; when there is one. Without a window (--headless) only the model changes.
    OpenLog(flowId := "") {
        this.model.OpenLog(flowId)
        if (IsObject(this.view))
            this.view.ShowLog()
    }

    ; The list of notices (WI-0075, PROTOCOL 4.8): the marks of the flows go, the window of the list is shown when there is one.
    OpenNotices() {
        this.model.OpenNotices()
        if (IsObject(this.view))
            this.view.ShowNotices()
    }

    ; Import from v1 (WI-0076, REQ-MIG-060): the import runs in ManagerImport. done(result) runs when it is over; the report
    ; (ManagerImport.Text) is shown when there is a window.
    ImportV1(dir, startupDir, done) {
        this.importer.Start(dir, startupDir, (res) => this._ImportDone(res, done))
    }

    _ImportDone(res, done) {
        if (IsObject(this.view))
            this.view.ShowImport(ManagerImport.Text(res))
        ManagerImport._Done(done, res)
    }

    ; Import of an .ahf file (WI-0081, REQ-MGR-050, REQ-SEC-060): the chain of ManagerArchive; done(res) when it is over, the
    ; report is shown when there is a window.
    ImportFile(path, done) {
        if (this.archive.running) {                  ; a drop or a second choice while an import runs: told, nothing started
            if (IsObject(this.view))
                this.view.ShowImport(Lang("Import_busy"))
            ManagerImport._Done(done, Map("ok", 0, "error", Lang("Import_busy"), "flows", [], "vars", [], "autostart", "skip"))
            return
        }
        this.archive.Start(path, (res) => this._ArchiveDone(res, done))
    }

    ; Export of flows to an .ahf file (WI-0081): done(res) with ok, count, error.
    ExportFlows(flowIds, path, done) {
        this.archive.Export(flowIds, path, done)
    }

    _ArchiveDone(res, done) {
        if (IsObject(this.view))
            this.view.ShowImport(ManagerImport.Text(res))
        ManagerImport._Done(done, res)
    }

    CloseLog() {
        this.model.CloseLog()
        if (IsObject(this.view) && IsObject(this.view.logView))
            this.view.logView.Hide()
    }

    _OnPrepareExit(msg) {
        this.model.Note("manager.prepareExit", Map("cancel", Json.Bool(this.cancelExit)))
        return Map("ok", true, "cancel", Json.Bool(this.cancelExit))
    }

    ; cmd.manager.show (F-0074, PROTOCOL 4.8): shows the window, restores it if it is minimized and brings it to the front.
    ; Without a window (--headless) only the record is written.
    _OnShow(msg) {
        this.model.Note("manager.show", Map("headless", this.headless ? 1 : 0))
        if (IsObject(this.view))
            this.view.Raise()
        return Map("ok", true)
    }
}
