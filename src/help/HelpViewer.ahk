#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk

; The interface of a help viewer (WI-0111, E0099, PROTOCOL 4.12). The window and the role talk only to it; a viewer is
; one of the classic control (ClassicViewer), the default browser (BrowserViewer) and later WebView2 (WI-0115).
;
;   Navigate(path)            shows the generated HTML file path
;   Back()                    one page back, in the viewer's own history
;   Resize(x, y, w, h)        the place of the viewer's control in pixels of its window (the window calls it on size)
;   Close()                   releases the control and its timers
;   onLink                    fn(url): called when the viewer's location changed (a followed link, or a page it was
;                             asked to show); "" for none. The window does not need it for navigation.
;
; A viewer that does not support one of them throws AhfError (the role logs it; the window keeps running).
class HelpViewer {
    name := ""
    onLink := ""

    Navigate(path) => this._Unsupported("Navigate")
    Back() => this._Unsupported("Back")
    Resize(x, y, w, h) => this._Unsupported("Resize")
    Close() => this._Unsupported("Close")

    _Unsupported(what) {
        throw AhfError("help viewer '" this.name "' does not support " what, ErrCode.INTERNAL)
    }
}
