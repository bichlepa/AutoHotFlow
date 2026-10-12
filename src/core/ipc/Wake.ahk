#Requires AutoHotkey v2.0
#Include ..\Log.ahk

; Wake-up of a process that waits for pipe data (doc/ARCHITECTURE.md 2.2).
; The sender posts WM_AHF_WAKE to the peer's script window after each write; the receiver pumps
; its connections on that message and, as a safety net, on a fallback timer (250 ms), so a lost
; wake-up only delays delivery.
;
;   Wake.Install(() => myPump())      ; message handler and fallback timer, one call
;   Wake.Uninstall()
;   Wake.Hwnd                         ; this process's window handle for the peer's PeerHwnd

class Wake {
    static WM_AHF_WAKE := 0x8001
    static FALLBACK_MS := 250
    ; Handler threads that may run at once (OnMessage MaxThreads). With 1, AHK may drop a wake that
    ; arrives while the handler runs; the fallback timer then delivers it up to 250 ms late. No
    ; dropped wake was observed in 12000 ping-pong round trips with 1 and with 4 (WI-04).
    static MaxThreads := 1
    static _pumpFn := ""
    static _msgFn := ""
    static _timerFn := ""
    static _handler := ""

    ; Window handle that peers post the wake message to (the hidden script window).
    static Hwnd => A_ScriptHwnd

    ; Registers a raw message handler: handler(wParam, lParam, msg, hwnd).
    static Register(handler) {
        if (IsObject(this._handler))
            OnMessage(Wake.WM_AHF_WAKE, this._handler, 0)
        this._handler := handler
        OnMessage(Wake.WM_AHF_WAKE, handler, this.MaxThreads)
    }

    ; Calls pumpFn() on every wake message and every fallback interval. Replaces an earlier install.
    static Install(pumpFn, fallbackMs := 250) {
        this.Uninstall()
        this._pumpFn := pumpFn
        this._msgFn := (wParam, lParam, msg, hwnd) => Wake._OnWake()
        this._timerFn := () => Wake._OnWake()
        this.Register(this._msgFn)
        SetTimer(this._timerFn, fallbackMs)
    }

    static Uninstall() {
        if (IsObject(this._timerFn))
            SetTimer(this._timerFn, 0)
        if (IsObject(this._handler))
            OnMessage(Wake.WM_AHF_WAKE, this._handler, 0)
        this._pumpFn := ""
        this._msgFn := ""
        this._timerFn := ""
        this._handler := ""
    }

    ; Posts the wake message to a peer window. A dead window is not an error here: the peer's
    ; fallback timer (or its absence) is handled by the connection state, not by this call.
    static Post(hwnd) {
        if (hwnd != 0)
            DllCall("PostMessageW", "ptr", hwnd, "uint", Wake.WM_AHF_WAKE, "ptr", 0, "ptr", 0)
    }

    static _OnWake() {
        fn := Wake._pumpFn
        if (!IsObject(fn))
            return 0
        try {
            fn()
        } catch as e {
            Log.Write("a0", "ipc", "pump failed: " Type(e) ": " e.Message " (line " e.Line ")")
        }
        return 0
    }
}
