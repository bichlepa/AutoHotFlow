#Requires AutoHotkey v2.0
#Include ..\core\Log.ahk
#Include HelpViewer.ahk
#Include HelpPages.ahk

; The classic viewer (WI-0111, E0099): the browser control of Windows (Shell.Explorer, the engine of Internet Explorer).
; The generated pages carry X-UA-Compatible: IE=edge, so the control uses the newest document mode it has.
;
; The control is placed in the window of HelpWindow (the window's layout, at 100 %: x 12, y 52, 836 x 556). Shell.Explorer
; does not report its location changes as events of AHK, so the viewer polls LocationURL with a timer (POLL_MS) and calls
; onLink when it changed. The timer runs only while the viewer lives; Close stops it.
class ClassicViewer extends HelpViewer {
    static POLL_MS := 300
    static X := 12
    static Y := 52
    static W := 836
    static H := 556

    __New(window) {
        this.name := "classic"
        this.lastUrl := ""
        this.ctl := window.win.Gui.AddActiveX("", "Shell.Explorer")
        window.win.Place(this.ctl, ClassicViewer.X, ClassicViewer.Y, ClassicViewer.W, ClassicViewer.H)
        this.wb := this.ctl.Value
        this.pollFn := (*) => this._Poll()
        SetTimer(this.pollFn, ClassicViewer.POLL_MS)
    }

    Navigate(path) {
        this._Need()
        this.wb.Navigate(HelpPages.Url(path))
    }

    Back() {
        this._Need()
        try {
            this.wb.GoBack()
        } catch as e {
            Log.Write("a1", "help", "classic viewer: no page back: " e.Message)
        }
    }

    ; The place of the control in pixels (the window computes it from its client size).
    Resize(x, y, w, h) {
        if (IsObject(this.ctl))
            this.ctl.Move(x, y, w, h)
    }

    Close() {
        SetTimer(this.pollFn, 0)
        this.wb := ""
        this.ctl := ""
        this.onLink := ""
    }

    ; The location changed: onLink gets the new URL once (a followed link, or the page the viewer was asked to show).
    _Poll() {
        if (!IsObject(this.wb))
            return
        url := ""
        try {
            url := this.wb.LocationURL
        } catch as e {
            Log.Write("a1", "help", "classic viewer: no location yet: " e.Message)
            return
        }
        if (url = "" || url = this.lastUrl)
            return
        this.lastUrl := url
        if (IsObject(this.onLink)) {
            hook := this.onLink      ; not this.onLink(url): that would pass this as the first argument
            hook(url)
        }
    }

    _Need() {
        if (!IsObject(this.wb))
            throw AhfError("classic viewer is closed", ErrCode.INTERNAL)
    }
}
