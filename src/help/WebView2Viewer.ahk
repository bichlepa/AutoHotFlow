#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include HelpViewer.ahk
#Include HelpPages.ahk
#Include ComHandler.ahk
#Include WebView2Loader.ahk

; The WebView2 viewer (WI-0115, E0099, PROTOCOL 4.12): the engine of Edge in the help window. It drives the COM interfaces
; of WebView2.h (1.0.2739.15) through ComCall; the vtable indexes below are position + 3 (IUnknown first) and were checked
; against the header and by the spike (temp/wv2-spike, doc/howto/com-and-native-calls.md).
;
; Start creates the environment (the user data folder is the data folder's WebView2 folder) and the controller. Both are
; asynchronous: until the controller is ready Navigate keeps the last page, and Resize keeps the place. A failure (the
; loader, the environment, the controller) calls onFailed(reason) once; the window then shows the page with the classic
; viewer. Local pages only: a navigation to anything but file: is cancelled; an http or https link opens in the default
; browser (no network inside the help).
class WebView2Viewer extends HelpViewer {
    static IX_ENV_CREATE_CONTROLLER := 3       ; ICoreWebView2Environment::CreateCoreWebView2Controller
    static IX_CTRL_PUT_VISIBLE := 4            ; ICoreWebView2Controller::put_IsVisible
    static IX_CTRL_PUT_BOUNDS := 6             ; ICoreWebView2Controller::put_Bounds
    static IX_CTRL_CLOSE := 24                 ; ICoreWebView2Controller::Close
    static IX_CTRL_GET_CORE := 25              ; ICoreWebView2Controller::get_CoreWebView2
    static IX_CORE_GET_SOURCE := 4             ; ICoreWebView2::get_Source
    static IX_CORE_NAVIGATE := 5               ; ICoreWebView2::Navigate
    static IX_CORE_ADD_NAV_STARTING := 7       ; ICoreWebView2::add_NavigationStarting
    static IX_CORE_ADD_SOURCE_CHANGED := 11    ; ICoreWebView2::add_SourceChanged
    static IX_CORE_GO_BACK := 40               ; ICoreWebView2::GoBack
    static IX_ARGS_GET_URI := 3                ; ICoreWebView2NavigationStartingEventArgs::get_Uri
    static IX_ARGS_PUT_CANCEL := 8             ; ICoreWebView2NavigationStartingEventArgs::put_Cancel
    static IX_RELEASE := 2                     ; IUnknown::Release

    __New(hwnd, dataDir, onFailed := "") {
        this.name := "webview2"
        this.hwnd := hwnd
        this.dataDir := dataDir
        this.onFailed := onFailed
        this.env := 0
        this.ctrl := 0
        this.core := 0
        this.ready := false
        this.failed := false
        this.pending := ""          ; the last page asked before the controller was ready ("" for none)
        this.rect := ""            ; Buffer of the RECT (client pixels), once Resize was called
        this.lastUrl := ""
    }

    ; Starts the environment and the controller. Returns at once.
    Start() {
        pCreate := WebView2Loader.Proc("CreateCoreWebView2EnvironmentWithOptions")
        if (!pCreate)
            return this._Fail("the loader DLL is not loaded")
        if (this.dataDir = "")
            return this._Fail("no data folder")
        handler := ComHandler((hr, env) => this._OnEnvironment(hr, env))
        try {
            hr := DllCall(pCreate, "Ptr", 0, "WStr", this.dataDir, "Ptr", 0, "Ptr", handler.Ptr, "Int")
            if (WebView2Viewer.Failed(hr))
                this._Fail("the environment was refused, " WebView2Viewer.Hex(hr))
        } catch as e {
            this._Fail("the environment could not start: " e.Message)
        }
    }

    ; Shows the page (its file path). Before the controller is ready the page waits.
    Navigate(path) {
        if (this.failed)
            return
        if (!this.ready) {
            this.pending := path
            return
        }
        try ComCall(WebView2Viewer.IX_CORE_NAVIGATE, this.core, "WStr", HelpPages.Url(path))
        catch as e
            Log.Write("a1", "help", "WebView2 viewer: the navigation failed: " e.Message)
    }

    Back() {
        if (!this.ready)
            return
        try ComCall(WebView2Viewer.IX_CORE_GO_BACK, this.core)
        catch as e
            Log.Write("a1", "help", "WebView2 viewer: no page back: " e.Message)
    }

    ; The place of the view in pixels of the window's client area.
    Resize(x, y, w, h) {
        r := Buffer(16, 0)
        NumPut("Int", x, r, 0)
        NumPut("Int", y, r, 4)
        NumPut("Int", x + w, r, 8)
        NumPut("Int", y + h, r, 12)
        this.rect := r
        this._ApplyRect()
    }

    ; Closes the controller and releases it (the environment stays for the process).
    Close() {
        this.onLink := ""
        this.ready := false
        ctrl := this.ctrl
        this.ctrl := 0
        this.core := 0
        if (ctrl) {
            try ComCall(WebView2Viewer.IX_CTRL_CLOSE, ctrl)
            catch as e
                Log.Write("a1", "help", "WebView2 viewer: close failed: " e.Message)
            try ComCall(WebView2Viewer.IX_RELEASE, ctrl)
            catch as e
                Log.Write("a1", "help", "WebView2 viewer: release failed: " e.Message)
        }
    }

    _OnEnvironment(hr, env) {
        if (this.failed)
            return
        if (WebView2Viewer.Failed(hr) || !env)
            return this._Fail("the environment failed, " WebView2Viewer.Hex(hr))
        this.env := env
        try ComCall(1, env)                      ; AddRef: the environment is ours from here on
        catch as e
            return this._Fail("AddRef of the environment: " e.Message)
        handler := ComHandler((h, ctrl) => this._OnController(h, ctrl))
        try ComCall(WebView2Viewer.IX_ENV_CREATE_CONTROLLER, env, "Ptr", this.hwnd, "Ptr", handler.Ptr)
        catch as e
            this._Fail("CreateCoreWebView2Controller: " e.Message)
    }

    _OnController(hr, ctrl) {
        if (this.failed)
            return
        if (WebView2Viewer.Failed(hr) || !ctrl)
            return this._Fail("the controller failed, " WebView2Viewer.Hex(hr))
        try {
            ComCall(1, ctrl)                     ; AddRef: the controller is ours until Close
            this.ctrl := ctrl
            ComCall(WebView2Viewer.IX_CTRL_PUT_VISIBLE, ctrl, "Int", 1)
            core := 0
            ComCall(WebView2Viewer.IX_CTRL_GET_CORE, ctrl, "Ptr*", &core)
            this.core := core
            this._AddEvents()
        } catch as e {
            return this._Fail("the controller has no view: " e.Message)
        }
        this.ready := true
        this._ApplyRect()
        if (this.pending != "") {
            path := this.pending
            this.pending := ""
            this.Navigate(path)
        }
    }

    ; Two events: a navigation is checked (only file: pages; a web link goes to the default browser), and the source
    ; changed is reported to onLink (the window follows the page).
    _AddEvents() {
        tok := 0
        onStart := ComHandler((sender, args) => this._OnNavigationStarting(args))
        ComCall(WebView2Viewer.IX_CORE_ADD_NAV_STARTING, this.core, "Ptr", onStart.Ptr, "Int64*", &tok)
        tok := 0
        onSource := ComHandler((sender, args) => this._OnSourceChanged(sender))
        ComCall(WebView2Viewer.IX_CORE_ADD_SOURCE_CHANGED, this.core, "Ptr", onSource.Ptr, "Int64*", &tok)
    }

    _OnNavigationStarting(args) {
        uri := WebView2Viewer._Text(args, WebView2Viewer.IX_ARGS_GET_URI)
        if (SubStr(StrLower(uri), 1, 5) = "file:")
            return
        ComCall(WebView2Viewer.IX_ARGS_PUT_CANCEL, args, "Int", 1)
        if (RegExMatch(uri, "i)^https?://")) {
            try Run(uri)
            catch as e
                Log.Write("a1", "help", "the default browser could not open a link: " e.Message)
        }
    }

    _OnSourceChanged(sender) {
        url := WebView2Viewer._Text(sender, WebView2Viewer.IX_CORE_GET_SOURCE)
        if (url = "" || url = this.lastUrl)
            return
        this.lastUrl := url
        if (IsObject(this.onLink)) {
            hook := this.onLink      ; not this.onLink(url): that would pass this as the first argument
            hook(url)
        }
    }

    _ApplyRect() {
        if (!this.ready || !IsObject(this.rect))
            return
        try ComCall(WebView2Viewer.IX_CTRL_PUT_BOUNDS, this.ctrl, "Ptr", this.rect.Ptr)
        catch as e
            Log.Write("a1", "help", "WebView2 viewer: the place could not be set: " e.Message)
    }

    ; Start failed: once, with the reason; the window switches to the classic viewer.
    _Fail(reason) {
        if (this.failed)
            return
        this.failed := true
        this.ready := false
        Log.Write("a0", "help", "the WebView2 viewer could not start (" reason "), the classic viewer shows the page")
        hook := this.onFailed
        if (IsObject(hook))
            hook(reason)
    }

    ; A string that a COM method returns through an out pointer (LPWSTR, freed with CoTaskMemFree).
    static _Text(obj, index) {
        s := 0
        ComCall(index, obj, "Ptr*", &s)
        if (!s)
            return ""
        text := StrGet(s, "UTF-16")
        DllCall("ole32\CoTaskMemFree", "Ptr", s)
        return text
    }

    static Failed(hr) => ((hr & 0xFFFFFFFF) >= 0x80000000)
    static Hex(v) => Format("0x{:08X}", v & 0xFFFFFFFF)
}
