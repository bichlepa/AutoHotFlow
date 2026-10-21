#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\core\Lang.ahk
#Include ..\core\LangTable.ahk
#Include ..\core\Role.ahk
#Include ..\core\SettingsModel.ahk
#Include ..\core\HelpPageId.ahk
#Include HelpPages.ahk
#Include HelpWindow.ahk
#Include BrowserViewer.ahk

; Role "help": the help window and its viewers (WI-0111, E0098, E0099, PROTOCOL 4.12). A process of its own, started on demand
; by the supervisor when the manager or an editor asks for a page (cmd.help.show). A hang of a browser engine stops this
; process only. It has no flows, no engine, no storage access and no element classes.
;
; The viewer comes from the setting helpViewer (HelpPages.ViewerFor): classic (the browser control, HelpWindow), browser
; (the default browser, no window). The window is created at the first page of the classic viewer and then kept hidden,
; not closed. A page asked before the settings have arrived waits for them (OnSettings), so that the viewer is the one of
; the setting.
;
;   AutoHotkey64.exe src\entry\help.ahk --role=help --session=<id> --hub=<pipe> --data=<dir> [--headless]
;   --headless  no window (every test run). Adds cmd.test.command { item: "resolve" } (PROTOCOL 4.12).
class HelpRole extends Role {
    static TEST_ITEMS := Map("resolve", 1)

    __New(args) {
        super.__New(args)
        this.headless := args.Has("headless")
        this.setting := "auto"          ; helpViewer (settings, PROTOCOL 4.2)
        this.settingsKnown := false
        this.waiting := ""              ; the page asked before the settings came ("" for none; the index is "")
        this.hasWaiting := false
        this.window := ""               ; HelpWindow, made at the first page of the classic viewer
        this.page := ""                 ; the page ID last shown ("" = the index)
        this.viewerName := ""           ; the viewer of the last page
        this.shown := 0
        this.lastResult := ""
    }

    RegisterHandlers() {
        this.On("cmd.help.show", (msg) => this._OnShow(msg))
        this.FollowSettings()
        if (this.headless)
            this.On("cmd.test.command", (msg) => this._OnTestCommand(msg))
    }

    OnSettings(settings) {
        this.setting := settings.Get("helpViewer", "auto")
        this.settingsKnown := true
        if (this.hasWaiting) {
            page := this.waiting
            this.hasWaiting := false
            this._Show(page)
        }
    }

    DiagInfo() {
        return Map("viewer", this.viewerName, "page", this.page, "shown", this.shown, "lastResult", this.lastResult)
    }

    ; The index (the contents button of the window).
    ShowIndex() => this._Show("")

    ; cmd.help.show {page} (PROTOCOL 4.12). A page ID that is not valid is refused. Answers { ok, viewer }; viewer is ""
    ; while the settings are not known yet (the page then waits for them).
    _OnShow(msg) {
        page := msg.payload.Get("page", "")
        if (!HelpPageId.IdOk(page))
            throw AhfError("payload field 'page' must be a help page ID", ErrCode.BAD_PAYLOAD)
        if (!this.settingsKnown) {
            this.waiting := page
            this.hasWaiting := true
            return Map("ok", true, "viewer", "")
        }
        return this._Show(page)
    }

    ; Shows a page with the viewer of the setting. A page that does not exist shows the index with a log line (PROTOCOL 4.12).
    _Show(page) {
        resolved := HelpPages.Resolve(page, LangTable.Code)
        if (!resolved["found"])
            Log.Write("a0", "help", "help page '" page "' does not exist, the index is shown")
        choice := HelpPages.ViewerFor(this.setting, HelpPages.WebView2Available())
        if (choice["fallback"])
            Log.Write("a0", "help", "the WebView2 viewer is not available, the classic viewer shows the page")
        this.page := page
        this.viewerName := choice["viewer"]
        this.shown += 1
        this.lastResult := "shown " (page = "" ? HelpPages.INDEX : page) " with " this.viewerName
        if (!this.headless) {
            if (choice["viewer"] = "browser")
                BrowserViewer().Navigate(resolved["path"])
            else
                this._Window().Show(resolved["path"])
        }
        return Map("ok", true, "viewer", this.viewerName)
    }

    _Window() {
        if (!IsObject(this.window))
            this.window := HelpWindow(this)
        return this.window
    }

    ; cmd.test.command {item: "resolve", page, language?} (headless only): the viewer, the file and whether the page exists,
    ; without showing anything. language replaces the language of the user interface for this request.
    _OnTestCommand(msg) {
        item := msg.payload.Get("item", "")
        if (IsObject(item) || !HelpRole.TEST_ITEMS.Has(item))
            throw AhfError("cmd.test.command: item must be 'resolve'", ErrCode.BAD_PAYLOAD)
        page := msg.payload.Get("page", "")
        if (!HelpPageId.IdOk(page))
            throw AhfError("payload field 'page' must be a help page ID", ErrCode.BAD_PAYLOAD)
        lang := msg.payload.Get("language", "")
        if (IsObject(lang))
            throw AhfError("payload field 'language' must be text", ErrCode.BAD_PAYLOAD)
        code := (lang = "") ? LangTable.Code : SettingsModel.LanguageCode(lang)
        resolved := HelpPages.Resolve(page, code)
        choice := HelpPages.ViewerFor(this.setting, HelpPages.WebView2Available())
        return Map("ok", true, "viewer", choice["viewer"], "path", resolved["path"]
            , "found", Json.Bool(resolved["found"]), "language", resolved["language"])
    }
}
