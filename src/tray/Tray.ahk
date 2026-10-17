#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\core\Lang.ahk
#Include ..\core\Role.ahk
#Include ..\core\NoticeThrottle.ahk

; Role "tray": the tray icon and the tray menu of the application (WI-0072, E0075, REQ-MGR-090, REQ-MGR-140).
;
; Why an own process: an open menu stops the threads and timers of the process that shows it (measured, doc/MEASUREMENTS.md,
; "Open menus in a running process"). The supervisor is the hub and must never stop, the manager is busy with its
; window, so the icon has a process of its own that does nothing else. The supervisor starts it with the other
; processes and starts it again when it dies (Children.AUTO_RESTART), so the icon comes back. When the supervisor
; dies, this role ends like every role (orphan guard of Role).
;
; What it does: it shows the icon with the tooltip "AutoHotFlow" and a menu of two entries, "Show manager" (default
; entry, so a double click on the icon does the same) and "Exit". The menu handlers only send a request to the
; supervisor and return (no blocking call, every request has a timeout):
;   Show manager   cmd.app.command {argv: []}   the same as a second start of the product (PROTOCOL 4.1): the
;                                                supervisor shows the manager, or starts it when it is not running
;   Exit           cmd.app.exit {}               the clean exit of the application (ARCHITECTURE 6.3)
; It has no flows, no engine and no storage access, subscribes to nothing and holds no state besides the menu.
; Later entries (language, log; WI-0077, WI-0078) are added here.
;
; Notices (WI-0075, PROTOCOL 4.7, 4.10): the role subscribes to the topic notice and shows each evt.ui.notice as a tray
; notice (TrayTip). The tray shows it, not the supervisor: a tray notice belongs to the process that owns the icon. At most
; one tray notice per 5 s; the others are counted. A headless role only counts.
;
;   AutoHotkey64.exe src\entry\tray.ahk --role=tray --session=<id> --hub=<pipe> --data=<dir> [--headless]
;   --headless   the icon stays hidden (every test run; E0046). Adds cmd.test.command, a driver for the tests that
;                runs a menu entry as if it was clicked (doc/PROTOCOL.md 4.10). The menu itself is built as always.
;
; The standard entries of AutoHotkey are removed: its own "Exit" would end this process at once, without the shutdown
; of the application, and "Reload", "Suspend Hotkeys" and the like make no sense for a role.
class Tray extends Role {
    static TIP := "AutoHotFlow"
    static REQUEST_MS := 5000
    ; Lang keys (assets/language/basic): "_" is a space, "Exit #verb" is the key of the text "Exit".
    static KEY_SHOW := "Show_Manager"
    static KEY_EXIT := "Exit_#verb"
    ; The entries of cmd.test.command, by their name.
    static TEST_ITEMS := Map("show", 1, "exit", 1)
    ; Notices (WI-0075): at most one tray notice per NOTICE_MS; the title of the balloon.
    static NOTICE_MS := 5000
    static NOTICE_TITLE := "AutoHotFlow"
    static NOTICE_CHARS := 250         ; the balloon of Windows holds about 250 characters

    __New(args) {
        super.__New(args)
        this.headless := args.Has("headless")
        this.menuShow := ""         ; the text of the entries as they are in the menu now
        this.menuExit := ""
        this.lastResult := ""       ; outcome of the last request, for the snapshot
        this.requests := 0
        this.notices := 0           ; notices received (WI-0075)
        this.noticesHeld := 0       ; of them, not shown as a tray notice (the throttle)
        this.lastNotice := ""
        this.noticeThrottle := NoticeThrottle(Tray.NOTICE_MS)
    }

    Start() {
        super.Start()
        this.peer.Subscribe("notice")
        this._BuildMenu()
        A_IconTip := Tray.TIP
        ; The entry script carries #NoTrayIcon, so the icon appears only here, with the menu already complete.
        A_IconHidden := this.headless
    }

    RegisterHandlers() {
        this.On("evt.ui.notice", (msg) => this._OnNotice(msg))
        this.FollowSettings()      ; log thresholds; the menu follows the language (WI-0077)
        if (this.headless)
            this.On("cmd.test.command", (msg) => this._OnTestCommand(msg))
    }

    DiagInfo() {
        return Map("iconHidden", Json.Bool(A_IconHidden), "tip", A_IconTip, "items", [this.menuShow, this.menuExit]
            , "requests", this.requests, "lastResult", this.lastResult, "notices", this.notices
            , "noticesHeld", this.noticesHeld, "lastNotice", this.lastNotice)
    }

    ; --- notices (WI-0075) -----------------------------------------------------------------------------

    ; evt.ui.notice of the topic notice: the text is translated here (Lang(key, args...)); "held" adds the count of the
    ; notices the engine held back. The tray notice is shown at most once per NOTICE_MS, the others are only counted.
    _OnNotice(msg) {
        p := msg.payload
        this.notices += 1
        args := p.Get("args", [])
        text := Lang(p.Get("key", ""), args*)
        held := p.Get("held", 0)
        if (held > 0)
            text .= " " Lang("Notice_more", held)
        this.lastNotice := text
        ; A warning (a flow stopped by the runaway guard, its triggers are off) is never hidden behind the throttle: the
        ; user must learn it. It restarts the window, so the errors after it are still throttled.
        if (p.Get("kind", "") = "limit" || p.Get("level", "") = "warning") {
            this.noticeThrottle.Sent("tray", A_TickCount)
        } else if (!this.noticeThrottle.Offer("tray", A_TickCount)) {
            this.noticesHeld += 1
            return
        }
        if (!this.headless) {
            icon := p.Get("level", "") = "warning" ? "Icon!" : "Iconx"
            TrayTip(Tray.NOTICE_TITLE, SubStr(text, 1, Tray.NOTICE_CHARS), icon)
        }
    }

    ; The language may have changed (Role.ApplySettings loaded the texts already): the menu gets the new texts.
    OnSettings(settings) {
        if (this.menuShow != "" && (this.menuShow != Lang(Tray.KEY_SHOW) || this.menuExit != Lang(Tray.KEY_EXIT)))
            this._BuildMenu()
    }

    ; (Re)builds the menu from the language texts. A later change of the language calls this again.
    _BuildMenu() {
        A_TrayMenu.Delete()
        this.menuShow := Lang(Tray.KEY_SHOW)
        this.menuExit := Lang(Tray.KEY_EXIT)
        A_TrayMenu.Add(this.menuShow, (*) => this.ShowManager())
        A_TrayMenu.Add(this.menuExit, (*) => this.Exit())
        A_TrayMenu.Default := this.menuShow
    }

    ; --- menu actions (also what the double click does) ---------------------------------------------

    ShowManager() {
        this._Send("cmd.app.command", Map("argv", []))
    }

    Exit() {
        this._Send("cmd.app.exit", Map())
    }

    ; One request to the supervisor with a timeout. The answer is only logged and kept for the snapshot: the menu
    ; handler returns at once. A request that cannot be sent (hub connection lost) is logged, the role goes on; the
    ; orphan guard ends it when the hub does not come back.
    _Send(type, payload) {
        this.requests += 1
        try {
            this.peer.Request("supervisor", type, payload, (ans) => this._OnAnswer(type, ans), Tray.REQUEST_MS)
        } catch as e {
            this.lastResult := type " not sent: " e.Message
            Log.Write("a0", "tray", this.lastResult)
        }
    }

    _OnAnswer(type, ans) {
        ok := (IsObject(ans) && ans.payload.Get("ok", 0)) ? true : false
        this.lastResult := type ": " (ok ? "ok" : (IsObject(ans) ? ans.type : "no answer"))
        if (!ok)
            Log.Write("a0", "tray", this.lastResult)
    }

    ; --- test driver (--headless only) ---------------------------------------------------------------

    ; cmd.test.command {item}: runs the menu entry as if it had been clicked. item is "show" or "exit".
    _OnTestCommand(msg) {
        item := msg.payload.Get("item", "")
        if (IsObject(item) || !Tray.TEST_ITEMS.Has(item))
            throw AhfError("cmd.test.command: item must be 'show' or 'exit'", ErrCode.BAD_PAYLOAD)
        if (item = "show")
            this.ShowManager()
        else
            this.Exit()
        return Map("ok", true)
    }
}
