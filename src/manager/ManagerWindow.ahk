#Requires AutoHotkey v2.0
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\ui_common\UiWindow.ahk
#Include ..\ui_common\UiDialogs.ahk
#Include ..\ui_common\UiFileDialogs.ahk
#Include ManagerModel.ahk
#Include LogWindow.ahk
#Include NoticeWindow.ahk
#Include ErrorWindow.ahk
#Include ImportReportWindow.ahk
#Include SettingsWindow.ahk
#Include AboutWindow.ahk

; The main window of the manager (WI-0073, WI-0074; REQ-MGR-010 to REQ-MGR-040): the view of the ManagerModel. It holds no
; logic of its own: it draws what the model holds and calls the operations of ManagerOps.
;
;   - The tree: the categories in their order (the uncategorized group last), the flows in their order, with their state as
;     a text mark. Several flows can be selected (Ctrl click); the tree shows the focused one.
;   - The buttons as v1, enabled by the selection (ManagerModel.ButtonStates). "Edit" and a double click open the editor of
;     the flow (WI-0087, ManagerModel.OpenEditor).
;   - Context menus of the tree (E0077: they run in this process; while a menu is open its threads stop, accepted).
;   - Drag and drop: a flow onto a flow or a category moves it; a category onto a category moves it. The drag is followed by a
;     timer (the mouse button is read at 30 ms), so no mouse capture is needed.
;   - The questions of the operations (dialogs of UiDialogs, never blocking) are answered by the methods Confirm, Input and
;     Choose of this window, the ask seam of ManagerOps.
;   - The close box only hides the window (E0014); "Exit" asks the supervisor for the end of the application.
;   - The window is redrawn by a timer of 50 ms, and only after a change, so a burst of events is one redraw.
;
; Sizes are pixels at 100 % (UiWindow scales them). Labels are Lang keys of the v1 files (assets/language) and of the
; folder manager.
class ManagerWindow {
    static WIDTH := 750
    static HEIGHT := 510
    static RENDER_MS := 50
    static DRAG_MS := 30
    static TVN_BEGINDRAG := -456     ; TVN_BEGINDRAGW (commctrl.h): the drag of the left button starts
    static TVM_HITTEST := 0x1111     ; TV_FIRST + 17
    static WM_NOTIFY := 0x4E
    static WM_DROPFILES := 0x233     ; a file is dropped on the window (DragAcceptFiles, WI-0081)
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
        ["ShowLog", 328, 332, 200, "Show_log"], ["Exit", 538, 332, 200, "Exit_#verb"],
        ["Notices", 328, 372, 200, "Notices"]]
    ; The questions: kind -> [title key, text key]. Texts take the arguments of the question.
    static ASK := Map("independent", ["Ask_independent_title", "Ask_independent_text"]
        , "force", ["Ask_force_title", "Ask_force_text"]
        , "delete", ["Delete_flow", "Ask_delete_text"]
        , "categoryDelete", ["Delete_category", "Ask_category_delete_text"]
        , "categoryMove", ["Change_category", "Ask_category_move_text"]
        , "changeCategory", ["Change_category", "Ask_change_category_text"]
        , "rename", ["Rename_flow", "Ask_rename_text"]
        , "categoryNew", ["New_category", "Ask_category_new_text"]
        , "categoryRename", ["Rename_category", "Ask_category_rename_text"]
        , "importCopies", ["Import_from_v1", "Ask_import_copies_text", "no"]
        , "autostartV1", ["Import_from_v1", "Ask_autostart_v1_text", "no"]
        , "importWarning", ["Import_file_title", "Archive_warning_dialog", "no"]     ; WI-0081: preselection No
        , "importConflict", ["Import_conflict_title", "Archive_conflict_text"]
        , "importName", ["Import_name_title", "Archive_name_text"]
        , "importExport", ["Import_and_export", "Archive_choose_text"]
        , "elevation", ["Ask_elevation_title", "Ask_elevation_text"])

    __New(model, role := "") {
        this.model := model
        this.role := role              ; the Manager role: the log window opens through its OpenLog (WI-0080)
        this.ops := role.ops           ; the operations (ManagerOps); this window answers their questions
        this.ops.ask := this
        this.logView := ""             ; the LogWindow, made at the first "Show log"
        this.noticeView := ""          ; the NoticeWindow (WI-0075), made at the first "Notices"
        this.errorView := ""           ; the ErrorWindow (WI-0113), made at the first "Show variables"
        this.importView := ""         ; the report of the import from v1 (WI-0076), made at the first import
        this.settingsView := ""       ; the settings dialog (WI-0078), made by each click on "Settings"
        this.aboutView := ""          ; the about window (WI-0078), made by each click on "About"
        this.codeShown := LangTable.Code   ; the language the open windows show (Refresh)
        this.dirty := true
        this.treeDirty := true
        this.labelDirty := Map()      ; flow ID -> true: its state mark changed (the item text only, no rebuild)
        this.filling := false
        this.treeItems := Map()       ; tree item ID -> flow ID
        this.itemOfFlow := Map()      ; flow ID -> tree item ID
        this.catItems := Map()        ; tree item ID -> category name ("" = Uncategorized)
        this.itemOfCat := Map()       ; category name -> tree item ID
        this.buttons := Map()         ; name -> control
        this.runIsStop := false
        this.enableIsDisable := false
        this.dragging := false
        this.drag := ""               ; Map(kind "flow"|"cat", id) of the drag in progress
        this.loggedReady := false
        this.fillCount := 0
        this.lastFillMs := -1
        this.win := UiWindow("manager", "Manager", ManagerWindow.WIDTH, ManagerWindow.HEIGHT)
        this.win.hideOnClose := true
        g := this.win.Gui
        this.tree := g.AddTreeView("+Border")
        this.win.Place(this.tree, 12, 12, 300, 456)
        this.tree.OnEvent("ItemSelect", (ctl, item) => this._OnTreeSelect(item))
        this.tree.OnEvent("DoubleClick", (*) => this._OnTreeDouble())
        this.tree.OnEvent("ContextMenu", (ctl, item, isRight, x, y) => this._OnContext())
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
        this.dragFn := () => this._DragTick()
        this.notifyFn := (wp, lp, msg, hwnd) => this._OnNotify(lp)
        OnMessage(ManagerWindow.WM_NOTIFY, this.notifyFn)
        this.timerOn := false
        this.win.onHide := () => this._StopTimer()
        ; An .ahf file dropped on the window starts the import (WI-0081): the window accepts files, the message says which.
        DllCall("shell32\DragAcceptFiles", "ptr", this.win.Hwnd, "int", true)
        this.dropFn := (wp, lp, msg, hwnd) => this._OnDropFiles(wp, hwnd)
        OnMessage(ManagerWindow.WM_DROPFILES, this.dropFn)
    }

    ; The list of notices (WI-0075): made at the first call, then shown. The model is changed by the role (OpenNotices).
    ShowNotices() {
        if (!IsObject(this.noticeView))
            this.noticeView := NoticeWindow(this.model, (flowId) => this.model.OpenEditor(flowId), (n) => this.ShowError(n))
        this.noticeView.Show()
    }

    ; The window of an unhandled error (WI-0113): made at the first call, shown at once; the model asks the engine for the
    ; variables and answers with the event "error" (the window shows it when it comes).
    ShowError(n) {
        if (!IsObject(this.errorView))
            this.errorView := ErrorWindow(this.model)
        this.errorView.Show()
        this.model.OpenError(n)
    }

    ; The redraw timer runs only while the window is visible (owner decision, 2026-10-17): it starts when the window is shown
    ; and stops when it is hidden, also by the close box. A change while hidden only sets the flag; the first redraw after
    ; the window is shown draws it.
    _StartTimer() {
        if (this.timerOn)
            return
        this.timerOn := true
        SetTimer(this.renderFn, ManagerWindow.RENDER_MS)
    }

    _StopTimer() {
        this.timerOn := false
        SetTimer(this.renderFn, 0)
    }

    ; The decision of the redraw: only a visible window, and only after a change since the last redraw.
    static ShouldRedraw(visible, changed) => visible && changed

    ; The window is visible (not hidden by the close box).
    Visible => this.win.Visible

    Show() {
        this.win.Show()
        this.dirty := true
        this._StartTimer()
    }

    ; cmd.manager.show: makes the window visible if it is hidden, restores it if it is minimized, and brings it to the front.
    Raise() {
        if (!this.win.Visible)
            this.Show()
        else if (WinGetMinMax(this.win.Hwnd) = -1)
            WinRestore(this.win.Hwnd)
        try WinActivate(this.win.Hwnd)
        this.dirty := true
    }

    Hide() {
        this.win.Hide()
    }

    Close() {
        this._StopTimer()
        SetTimer(this.dragFn, 0)
        this.dragging := false
        OnMessage(ManagerWindow.WM_NOTIFY, this.notifyFn, 0)
        if (IsObject(this.logView))
            this.logView.Close()
        if (IsObject(this.noticeView))
            this.noticeView.Close()
        if (IsObject(this.errorView))
            this.errorView.Close()
        if (IsObject(this.importView))
            this.importView.Close()
        if (IsObject(this.settingsView))
            this.settingsView.Close()
        if (IsObject(this.aboutView))
            this.aboutView.Close()
        this.win.Close()
    }

    ; A change of the language (WI-0078, Manager.OnSettings after UiTexts.Reload): the tree and the list of the flows are
    ; drawn again with the new texts; the windows that hold translated lists or tab names are made again (Relabel).
    Refresh() {
        if (LangTable.Code = this.codeShown)     ; another setting changed (also the dialog's own OK): nothing to draw again
            return
        this.codeShown := LangTable.Code
        this.dirty := true
        this.treeDirty := true
        if (IsObject(this.settingsView) && this.settingsView.Visible)
            this.settingsView.Relabel()
        if (IsObject(this.logView))
            this.logView.Relabel()
        if (IsObject(this.noticeView))
            this.noticeView.Relabel()
        if (IsObject(this.errorView))
            this.errorView.Relabel()
    }

    ; The settings dialog (WI-0078): a new one each time it is opened; a dialog that is open is not made twice.
    ShowSettings() {
        if (IsObject(this.settingsView) && this.settingsView.Visible)
            return
        this.settingsView := SettingsWindow(this.model)
        this.settingsView.Show()
    }

    ; The about window (WI-0078).
    ShowAbout() {
        if (IsObject(this.aboutView) && this.aboutView.Visible)
            return
        this.aboutView := AboutWindow()
        this.aboutView.Show()
    }

    ; The report of the import from v1 (WI-0076): made at the first call, then shown with its text.
    ShowImport(text) {
        if (!IsObject(this.importView))
            this.importView := ImportReportWindow()
        this.importView.Show(text)
    }

    ; The log window (WI-0080): made at the first call, then shown. The model is opened by the role (OpenLog).
    ShowLog() {
        if (!IsObject(this.logView))
            this.logView := LogWindow(this.model)
        this.logView.Show()
    }

    ; A change of the flows or the categories needs the tree to be built again. A flow state changes the state mark of its
    ; item only (labelDirty); the engine state and the buttons change nothing in the tree. A rebuild discards the expansion, so
    ; it is done only for the list itself.
    _OnModel(kind, data) {
        this.dirty := true
        if (kind = "snapshot" || kind = "categories" || kind = "settings")
            this.treeDirty := true
        else if (kind = "flow")
            this.labelDirty[data["flowId"]] := true
        else if (kind = "selection")
            this._ShowSelection()
        else if (kind = "trigger")
            this._NoticeTrigger(data)
        else if (kind = "elevationOffer")
            this.ops.OfferElevatedRestart()
        else if ((kind = "notice" || kind = "notices") && IsObject(this.noticeView))
            this.noticeView.Refresh()
        else if (kind = "error" && IsObject(this.errorView))
            this.errorView.Update(data)
    }

    ; The tree follows a selection made by the model (the driver, an operation): the item is selected without rebuilding.
    ; The ItemSelect event of that change finds the model in the same state and does nothing (see _OnTreeSelect).
    _ShowSelection() {
        m := this.model
        desired := 0
        if (m.catSelected && this.itemOfCat.Has(m.selectedCat))
            desired := this.itemOfCat[m.selectedCat]
        else if (!m.catSelected && m.selectedFlow != "" && this.itemOfFlow.Has(m.selectedFlow))
            desired := this.itemOfFlow[m.selectedFlow]
        if (desired != 0 && desired != this.tree.GetSelection())
            this.tree.Modify(desired, "Select")
    }

    ; A trigger of a flow that the user enabled cannot be armed (WI-0074, REQ-MIG-070): a notice, no blocking dialog.
    _NoticeTrigger(data) {
        rec := this.model.Flow(data["flowId"])
        name := rec = "" ? data["flowId"] : rec["name"]
        UiDialogs.Confirm(this.win.Hwnd, "Trigger_not_available", "Trigger_unavailable_text", [["ok", "OK"]]
            , (answered, id) => "", name, data["message"])
    }

    ; A handler per button (a closure over the loop variable would see the last button).
    _ButtonHandler(name) => (*) => this._OnButton(name)

    _OnButton(name) {
        switch name {
            case "Run":
                for id in this.model.SelectedFlows()
                    this.model.RunOrStop(id)
            case "Enable":
                this.ops.SetEnabled(this.model.SelectedFlows(), !this.model.EnableIsDisable())
            case "NewCategory":
                this.ops.CategoryNew()
            case "NewFlow":
                this.ops.NewFlow(this._CategoryHere())
            case "ChangeCategory":
                this._ChangeCategory(this.model.SelectedFlows())
            case "Duplicate":
                this.ops.Duplicate(this.model.selectedFlow)
            case "Edit":
                ids := this.model.SelectedFlows()
                if (ids.Length = 1)
                    this.model.OpenEditor(ids[1])
            case "Delete":
                this._DeleteSelection()
            case "Exit":
                this.model.Exit()
            case "ShowLog":
                this.role.OpenLog("")
            case "Notices":
                this.role.OpenNotices()
            case "ImportExport":
                this._ImportExport()
            case "Settings":
                this.ShowSettings()
            case "About":
                this.ShowAbout()
        }
    }

    ; Import and export (WI-0081, WI-0076): the user chooses the direction, then the dialog of the choice: export or import
    ; of .ahf files (the file dialog), or the import from v1 (the folder dialog). The dialogs are only opened by these
    ; clicks (E0076).
    _ImportExport() {
        items := [[1, Lang("Archive_export_action")], [2, Lang("Archive_import_action")], [3, Lang("Import_from_v1")]]
        this.Choose("importExport", items, (idx) => this._ExportOrImport(idx))
    }

    _ExportOrImport(idx) {
        if (idx = 1) {
            flowIds := this.model.SelectedFlows()
            if (flowIds.Length = 0) {
                this.ShowImport(Lang("Archive_export_none"))
                return
            }
            path := UiFileDialogs.File(this.win.Hwnd, "S24", "", Lang("Archive_export_title"), Lang("Archive_file_filter"))
            if (path = "")
                return
            if (!RegExMatch(path, "i)\.ahf$"))
                path .= ".ahf"
            this.role.ExportFlows(flowIds, path, (res) => this._ExportDone(res))
        } else if (idx = 2) {
            path := UiFileDialogs.File(this.win.Hwnd, "1", "", Lang("Archive_import_title"), Lang("Archive_file_filter"))
            if (path = "")
                return
            this.role.ImportFile(path, (res) => 0)
        } else if (idx = 3) {
            this._ImportV1()
        }
    }

    _ExportDone(res) {
        if (res["ok"])
            this.ShowImport(Lang("Archive_export_done", res["count"], res["path"]))
        else
            this.ShowImport(Lang("Archive_export_error", res["error"]))
    }

    ; A file dropped on the window: the first one; an .ahf file starts the import, any other file is refused with a text.
    ; The handler only checks the window and starts the chain (no dialog is opened here).
    _OnDropFiles(hDrop, hwnd) {
        if (hwnd != this.win.Hwnd)
            return
        count := DllCall("shell32\DragQueryFileW", "ptr", hDrop, "uint", 0xFFFFFFFF, "ptr", 0, "uint", 0, "uint")
        path := ""
        if (count > 0) {
            len := DllCall("shell32\DragQueryFileW", "ptr", hDrop, "uint", 0, "ptr", 0, "uint", 0, "uint")
            buf := Buffer((len + 1) * 2, 0)
            DllCall("shell32\DragQueryFileW", "ptr", hDrop, "uint", 0, "ptr", buf, "uint", len + 1, "uint")
            path := StrGet(buf, "UTF-16")
        }
        DllCall("shell32\DragFinish", "ptr", hDrop)
        if (path = "")
            return
        if (count > 1) {
            this.ShowImport(Lang("Archive_drop_many"))
            return
        }
        if (!RegExMatch(path, "i)\.ahf$")) {
            this.ShowImport(Lang("Archive_not_ahf", path))
            return
        }
        this.role.ImportFile(path, (res) => 0)
    }

    ; Import from v1 (WI-0076): the folder dialog of the user (default: the data folder of v1), then the import. The dialog is
    ; only opened by the choice "Import from v1" of the button "Import and export" (E0076). The startup folder is the real one: the autostart step of the import asks first.
    _ImportV1() {
        ; "*" makes the start folder a starting point the user may leave; without it the dialog is locked to that folder.
        start := DirExist(A_AppData "\AutoHotFlow") ? "*" A_AppData "\AutoHotFlow" : "*" A_AppData
        dir := UiFileDialogs.Dir(this.win.Hwnd, start, 1, Lang("Import_choose_folder"))
        if (dir = "")
            return
        this.role.ImportV1(dir, A_Startup, (res) => 0)
    }

    ; The category a new flow goes to: the selected category, the category of the focused flow, or Uncategorized.
    _CategoryHere() {
        m := this.model
        if (m.catSelected)
            return m.selectedCat
        if (m.selectedFlow != "" && m.flows.Has(m.selectedFlow))
            return m.flows[m.selectedFlow]["category"]
        return ""
    }

    _DeleteSelection() {
        if (this.model.catSelected)
            this.ops.CategoryDelete(this.model.selectedCat)
        else
            this.ops.Delete(this.model.SelectedFlows())
    }

    ; Moves flows to a category the user chooses (the dialog lists the categories and Uncategorized).
    _ChangeCategory(flowIds) {
        if (flowIds.Length = 0)
            return
        targets := [""]
        for name in this.model.CategoryNames()
            targets.Push(name)
        items := []
        for i, name in targets
            items.Push([i, name = "" ? Lang("Uncategorized") : name])
        this.Choose("changeCategory", items, (idx) => (idx >= 1 && idx <= targets.Length
            ? this.ops.Move(flowIds, targets[idx], "") : 0))
    }

    ; --- the questions of ManagerOps (the ask seam) -------------------------------------------------------------------

    ; The buttons of a question: "Yes" left, "No" right, as in every question of the manager. A question with a third key
    ; "no" is preselected "No" (the import, E0068): the default button is No, the order stays (pure).
    static ConfirmButtons(kind) {
        keys := ManagerWindow.ASK[kind]
        return [["yes", "Yes"], keys.Length >= 3 ? ["no", "No", true] : ["no", "No"]]
    }

    Confirm(kind, args, done) {
        keys := ManagerWindow.ASK[kind]
        opened := UiDialogs.Confirm(this.win.Hwnd, keys[1], keys[2], ManagerWindow.ConfirmButtons(kind)
            , (answered, id) => done(answered && id = "yes"), args*)
        if (!opened)
            done(false)
    }

    Input(kind, default, check, done) {
        keys := ManagerWindow.ASK[kind]
        opened := UiDialogs.Input(this.win.Hwnd, keys[1], keys[2], default, check
            , (answered, value) => done(answered ? value : ""))
        if (!opened)
            done("")
    }

    ; args: the arguments of the text (WI-0081: the name of the conflicting flow).
    Choose(kind, items, done, args*) {
        keys := ManagerWindow.ASK[kind]
        opened := UiDialogs.Choose(this.win.Hwnd, keys[1], keys[2], items, (answered, id) => done(answered ? id : 0), args*)
        if (!opened)
            done(0)
    }

    ; --- the tree: selection, context menu, drag and drop -------------------------------------------------------------

    ; The event may be late: a timer thread is uninterruptible for its first 15 ms (doc/howto/gui-and-hotkeys.md), so an
    ; event can come after the tree was built again. The current selection of the tree is read (not the event's item), and
    ; a selection that the model already has changes nothing.
    ; A double click on a flow opens its editor, as the Edit button does (WI-0087, v1 Manager GUI). The click selected the
    ; item already (ItemSelect); a category does nothing.
    _OnTreeDouble() {
        item := this.tree.GetSelection()
        if (this.treeItems.Has(item))
            this.model.OpenEditor(this.treeItems[item])
    }

    _OnTreeSelect(item) {
        if (this.filling || this.dragging)
            return
        cur := this.tree.GetSelection()
        m := this.model
        if (this.treeItems.Has(cur)) {
            id := this.treeItems[cur]
            if (GetKeyState("Ctrl", "P")) {
                m.SelectToggle(id)
                return
            }
            ; A late event of a rebuilt tree names the focused flow: the model already has it, the set stays (whatever it holds).
            if (!m.catSelected && m.selectedFlow = id)
                return
            m.Select(id)
        } else if (this.catItems.Has(cur)) {
            name := this.catItems[cur]
            if (m.catSelected && m.selectedCat = name)
                return
            m.SelectCategory(name)
        }
    }

    ; The context menu of the item under the cursor. The item is selected first if it is not part of the selection.
    _OnContext() {
        item := this._ItemAtCursor()
        m := this.model
        menu := Menu()
        if (this.treeItems.Has(item)) {
            id := this.treeItems[item]
            if (!this._InSelection(id))
                m.Select(id)
            this._FlowMenu(menu, id)
        } else if (this.catItems.Has(item)) {
            name := this.catItems[item]
            m.SelectCategory(name)
            this._CategoryMenu(menu, name)
        } else {
            this._PlainMenu(menu)
        }
        menu.Show()
    }

    _InSelection(id) {
        for sel in this.model.SelectedFlows() {
            if (sel = id)
                return true
        }
        return false
    }

    _FlowMenu(menu, id) {
        m := this.model
        flows := m.SelectedFlows()
        menu.Add(Lang(m.RunIsStop() ? "Stop_#verb" : "Run_#verb"), (*) => this._OnButton("Run"))
        menu.Add(Lang(m.EnableIsDisable() ? "Disable" : "enable"), (*) => this._OnButton("Enable"))
        menu.Add()
        if (flows.Length <= 1)
            menu.Add(Lang("Duplicate_flow"), (*) => this.ops.Duplicate(id))
        if (flows.Length <= 1)
            menu.Add(Lang("Rename_flow"), (*) => this.ops.Rename(id))
        menu.Add(Lang("Change_category"), (*) => this._OnButton("ChangeCategory"))
        menu.Add(Lang("Delete_flow"), (*) => this._OnButton("Delete"))
        menu.Add()
        this._AddCommon(menu)
    }

    _CategoryMenu(menu, name) {
        if (name != "") {
            menu.Add(Lang("Rename_category"), (*) => this.ops.CategoryRename(name))
            menu.Add(Lang("Delete_category"), (*) => this.ops.CategoryDelete(name))
            menu.Add()
        }
        this._AddCommon(menu)
    }

    _PlainMenu(menu) {
        this._AddCommon(menu)
    }

    ; The entries of every menu: new flow and category, sort alphabetically.
    _AddCommon(menu) {
        menu.Add(Lang("New_flow"), (*) => this._OnButton("NewFlow"))
        menu.Add(Lang("New_category"), (*) => this._OnButton("NewCategory"))
        menu.Add(Lang("Sort_alphabetically"), (*) => this.ops.CategorySort())
    }

    ; The item under the cursor (0 if none). TVM_HITTEST, the cursor in client coordinates of the tree.
    _ItemAtCursor() {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", pt)
        DllCall("ScreenToClient", "Ptr", this.tree.Hwnd, "Ptr", pt)
        hit := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("Int", NumGet(pt, 0, "Int"), hit, 0)
        NumPut("Int", NumGet(pt, 4, "Int"), hit, 4)
        DllCall("SendMessageW", "Ptr", this.tree.Hwnd, "UInt", ManagerWindow.TVM_HITTEST, "Ptr", 0, "Ptr", hit.Ptr, "Ptr")
        return NumGet(hit, A_PtrSize = 8 ? 16 : 12, "Ptr")
    }

    ; TVN_BEGINDRAG of the tree: the item under the cursor is dragged; the timer follows the button.
    _OnNotify(lp) {
        if (lp = 0 || NumGet(lp, 0, "Ptr") != this.tree.Hwnd)
            return
        if (NumGet(lp, 2 * A_PtrSize, "Int") != ManagerWindow.TVN_BEGINDRAG || this.dragging)
            return
        item := this._ItemAtCursor()
        if (this.treeItems.Has(item))
            this.drag := Map("kind", "flow", "id", this.treeItems[item])
        else if (this.catItems.Has(item))
            this.drag := Map("kind", "cat", "id", this.catItems[item])
        else
            return
        this.dragging := true
        SetTimer(this.dragFn, ManagerWindow.DRAG_MS)
    }

    _DragTick() {
        if (GetKeyState("LButton", "P"))
            return
        SetTimer(this.dragFn, 0)
        this.dragging := false
        drag := this.drag
        this.drag := ""
        target := this._ItemAtCursor()
        if (drag != "" && target != 0)
            this._Drop(drag, target)
    }

    ; Drop rules: a flow onto a flow moves it before that flow (in its category); a flow onto a category header appends it to
    ; that category; a category onto a category header moves it before that category (onto Uncategorized: to the end).
    ; A dragged flow that is part of the multi-selection moves the whole selection.
    _Drop(drag, target) {
        if (drag["kind"] = "flow") {
            ids := this._DragIds(drag["id"])
            if (this.treeItems.Has(target)) {
                before := this.treeItems[target]
                if (before = drag["id"])
                    return
                this.ops.Move(ids, this.model.Flow(before)["category"], before)
            } else if (this.catItems.Has(target)) {
                this.ops.Move(ids, this.catItems[target], "")
            }
        } else if (drag["kind"] = "cat") {
            if (this.catItems.Has(target) && this.catItems[target] != drag["id"])
                this.ops.CategoryMove(drag["id"], this.catItems[target])
        }
    }

    _DragIds(id) => this._InSelection(id) ? this.model.SelectedFlows() : [id]

    ; Timer, 20 Hz. Draws only when something changed and the window is shown.
    Render() {
        if (!ManagerWindow.ShouldRedraw(this.win.Visible, this.dirty)) {
            if (!this.win.Visible)
                this._StopTimer()
            return
        }
        this.dirty := false
        if (this.treeDirty) {
            this.treeDirty := false
            this.labelDirty := Map()
            this._FillTree()
        } else if (this.labelDirty.Count > 0) {
            for id in this.labelDirty {
                if (this.itemOfFlow.Has(id) && this.model.Flow(id) != "")
                    this.tree.Modify(this.itemOfFlow[id], "", this._FlowLabel(this.model.Flow(id)))
            }
            this.labelDirty := Map()
        }
        this._SetButtons()
        this._SetStatus()
    }

    ; The tree is built again from the model: the categories in the order of the engine, the flows below them. The selected
    ; flow or category stays selected. Expanded: all headers.
    _FillTree() {
        t0 := Time.NowMs()
        m := this.model
        this.filling := true
        this.tree.Opt("-Redraw")
        try {
            this.tree.Delete()
            this.treeItems := Map()
            this.itemOfFlow := Map()
            this.catItems := Map()
            this.itemOfCat := Map()
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
                this._AddCategory(c["name"], ids)
            }
            rest := []
            for id in m.flowIds {
                if (!shown.Has(id))
                    rest.Push(id)
            }
            if (rest.Length > 0)
                this._AddCategory("", rest)
            this._SelectModelItem()
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

    _AddCategory(name, ids) {
        parent := this.tree.Add(name = "" ? Lang("Uncategorized") : name, 0, "Expand")
        this.catItems[parent] := name
        this.itemOfCat[name] := parent
        for id in ids
            this._AddFlow(parent, id)
        ; "Expand" at the creation of an item without children has no effect: the flows below are shown by expanding now.
        if (ids.Length > 0)
            this.tree.Modify(parent, "Expand")
    }

    _AddFlow(parent, flowId) {
        item := this.tree.Add(this._FlowLabel(this.model.flows[flowId]), parent)
        this.treeItems[item] := flowId
        this.itemOfFlow[flowId] := item
    }

    _SelectModelItem() {
        m := this.model
        if (m.catSelected && this.itemOfCat.Has(m.selectedCat))
            this.tree.Modify(this.itemOfCat[m.selectedCat], "Select")
        else if (!m.catSelected && m.selectedFlow != "" && this.itemOfFlow.Has(m.selectedFlow))
            this.tree.Modify(this.itemOfFlow[m.selectedFlow], "Select")
    }

    ; The text of a flow item: its name and the marks of its state (translated): enabled, disabled, running, state unknown,
    ; independent triggers active while the flow is inactive, stopped by a limit, a trigger that is not available.
    ; A running flow shows the number of its running instances (E0079).
    _FlowLabel(rec) {
        marks := []
        if (rec["stateError"] != "")
            marks.Push(Lang("Flow_state_unknown"))
        else if (rec["executing"])
            marks.Push(rec["instances"] > 0 ? Lang("Flow_state_running_n", rec["instances"]) : Lang("Flow_state_running"))
        else
            marks.Push(Lang(rec["enabled"] ? "Flow_state_enabled" : "Flow_state_disabled"))
        if (!rec["enabled"] && rec["independentActive"] > 0)
            marks.Push(Lang("Flow_independent", rec["independentActive"]))
        if (rec["limit"] != "")
            marks.Push(Lang("Flow_limit", rec["limitValue"]))
        if (rec["unseen"])
            marks.Push(Lang("Flow_unseen"))
        if (ManagerModel._TriggerMessages(rec).Length > 0)
            marks.Push(Lang("Flow_trigger_unavailable"))
        if (rec["missingPackages"].Length > 0) {
            names := ""
            for name in rec["missingPackages"]
                names .= (names = "" ? "" : ", ") name
            marks.Push(Lang("Flow_missing_packages", names))      ; any element type (E0080, REQ-MIG-070)
        }
        text := rec["name"] "  ["
        for i, mark in marks
            text .= (i > 1 ? ", " : "") mark
        return text "]"
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
        disable := this.model.EnableIsDisable()
        if (disable != this.enableIsDisable) {
            this.enableIsDisable := disable
            UiTexts.SetKey(this.win.Hwnd, this.buttons["Enable"], disable ? "Disable" : "enable")
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
