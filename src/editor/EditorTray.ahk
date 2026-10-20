#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk

; The tray icon of one editor (WI-0091, REQ-EDT-230, PROTOCOL 4.11, E0087): an icon of its own in the notification area, with
; the state of its flow (running wins over enabled, else enabled or disabled), the tooltip "Flow: <name>" (the name follows a
; rename) and the menu: Show (default entry, a double click), Run, Enable or Disable (by the state), Close (as the close box).
; The window gets the same icon (EditorWindow.SetIcon).
;
; The menu handlers call the role and the flow commands (EditorFlowOps); they never wait: a result comes to Result() and
; a refused command is a tray notice of this icon and an a0 log entry. The entry script keeps #NoTrayIcon; Start shows the
; icon (A_IconHidden is false), except with --headless, where the icon stays hidden and the test driver runs the entries
; (cmd.test.command, EditorDriver). The standard entries of AutoHotkey are removed with the menu.
class EditorTray {
    static NOTICE_TITLE := "AutoHotFlow"
    static NOTICE_CHARS := 250        ; the balloon of Windows holds about 250 characters
    static TIP_CHARS := 120           ; A_IconTip holds 127 characters

    __New(role, headless) {
        this.role := role
        this.headless := headless
        this.started := false
        this.iconState := ""          ; "disabled", "enabled" or "running": the icon in use
        this.tip := ""
        this.menuItems := []          ; the texts of the entries: Show, Run, Enable or Disable, Close
        this.lastResult := ""         ; the outcome of the last menu action, for the tests and the snapshot
        this.notices := 0             ; refused commands shown as tray notices
        this.lastNotice := ""
    }

    ; The icon file of a state, in assets/icons (the folder of the program).
    static IconFile(state) => RegExReplace(A_LineFile, "\\src\\editor\\[^\\]+$") "\assets\icons\" state ".ico"

    ; Shows the icon (not with --headless) and builds the menu. The icon follows the flow state from Refresh.
    Start() {
        this.started := true
        A_IconHidden := this.headless
        this.Refresh()
    }

    ; Removes the icon at the planned end (the process would remove it at its exit anyway).
    Stop() {
        if (!this.started)
            return
        this.started := false
        A_IconHidden := true
    }

    ; The state of the flow, the name and the language changed: the icon, the tooltip, the window icon and the menu texts
    ; follow. Called by the role on every change of the model and of the settings.
    Refresh() {
        if (!this.started)
            return
        st := this.role.model.flowState
        state := st["executing"] ? "running" : (st["enabled"] ? "enabled" : "disabled")
        name := this.role.model.name
        if (name = "")
            name := this.role.flowId
        tip := SubStr(Lang("Flow") ": " name, 1, EditorTray.TIP_CHARS)
        if (!(tip == this.tip)) {          ; == compares case-sensitively (a rename may change only the case)
            this.tip := tip
            A_IconTip := tip
        }
        if (state != this.iconState) {
            this.iconState := state
            TraySetIcon(EditorTray.IconFile(state), 1, true)
        }
        if (IsObject(this.role.window))
            this.role.window.SetIcon(state)
        texts := [Lang("Show_#verb"), Lang("Run_#verb")
            , st["enabled"] || st["independentActive"] > 0 ? Lang("Disable") : Lang("enable"), Lang("Close_#verb")]
        if (!EditorTray._Same(texts, this.menuItems))
            this._BuildMenu(texts)
    }

    static _Same(a, b) {
        if (a.Length != b.Length)
            return false
        for i, text in a {
            if (!(text == b[i]))
                return false
        }
        return true
    }

    _BuildMenu(texts) {
        A_TrayMenu.Delete()
        A_TrayMenu.Add(texts[1], (*) => this.Show())
        A_TrayMenu.Add(texts[2], (*) => this.Run())
        A_TrayMenu.Add(texts[3], (*) => this.Toggle())
        A_TrayMenu.Add(texts[4], (*) => this.Close())
        A_TrayMenu.Default := texts[1]
        this.menuItems := texts
    }

    ; --- menu actions (also what the test driver runs) -------------------------------------------------------------------

    Show() {
        this.role.ShowWindow()
        this.lastResult := "show: ok"
    }

    Run() {
        this.role.flowOps.Run((res) => this._Result("run", this.menuItems[2], res))
    }

    Toggle() {
        this.role.flowOps.Toggle((res) => this._Result("toggle", this.menuItems[3], res))
    }

    Close() {
        this.lastResult := "close: ok"
        this.role.CloseEditor()
    }

    ; The answer of a command: "ok" (or "cancelled" when the user said no), else the refusal is a notice.
    _Result(item, label, res) {
        if (res["ok"]) {
            this.lastResult := item ": " (res["code"] = "cancelled" ? "cancelled" : "ok")
            return
        }
        this.lastResult := item ": " (res["code"] != "" ? res["code"] : "error")
        text := res["message"] != "" ? res["message"] : this.lastResult
        this.Notice(Lang("Flow_command_refused", label, text))
    }

    ; A tray notice of this icon (not with --headless) and an a0 log entry.
    Notice(text) {
        this.notices += 1
        this.lastNotice := text
        this.role._Log("a0", "editor", "tray: " text)
        if (!this.headless)
            TrayTip(EditorTray.NOTICE_TITLE, SubStr(text, 1, EditorTray.NOTICE_CHARS), "Icon!")
    }

    ; The language changed: the menu texts follow at the next Refresh.
    OnSettings() {
        this.Refresh()
    }

    ; The role part of the state (tests and snapshot): the icon state, the tooltip, the menu texts, the last result.
    State() {
        return Map("icon", this.iconState, "tip", this.tip, "items", this.menuItems.Clone()
            , "iconHidden", Json.Bool(A_IconHidden), "lastResult", this.lastResult, "notices", this.notices
            , "lastNotice", this.lastNotice)
    }
}
