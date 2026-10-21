#Requires AutoHotkey v2.0
#Include ..\core\Log.ahk

; A COM object of our own for one callback interface (WI-0115, E0085, E0099): a completion handler of the WebView2 loader or
; an event handler of a WebView2 object. The interface has three methods (QueryInterface, AddRef, Release) and one more:
; Invoke(sender, args). The vtable is built here from four CallbackCreate addresses; the callee calls Invoke with the
; handler pointer and the two arguments of the interface.
;
;   h := ComHandler((a, b) => ...)   the function gets the two arguments of Invoke (raw values: an HRESULT is masked by
;                                     the caller with & 0xFFFFFFFF, a pointer comes as it is)
;   h.Ptr                            the interface pointer to hand over
;
; Lifetime: a handler is kept in ComHandler._alive for the rest of the process, because the callee may call it later and
; the reference count of a callee is not visible here. The callbacks are not freed (a few per viewer start, see
; doc/howto/com-and-native-calls.md). Every method runs under try/catch: an error in the function is logged, it never
; reaches the COM caller.
class ComHandler {
    static _alive := Map()      ; the object's pointer -> ComHandler

    __New(fn) {
        this.fn := fn
        this.vt := Buffer(4 * A_PtrSize, 0)
        this.obj := Buffer(A_PtrSize, 0)
        NumPut("Ptr", CallbackCreate(ObjBindMethod(this, "_QueryInterface"), "F", 3), this.vt, 0)
        NumPut("Ptr", CallbackCreate(ObjBindMethod(this, "_Ref"), "F", 1), this.vt, A_PtrSize)
        NumPut("Ptr", CallbackCreate(ObjBindMethod(this, "_Ref"), "F", 1), this.vt, 2 * A_PtrSize)
        NumPut("Ptr", CallbackCreate(ObjBindMethod(this, "_Invoke"), "F", 3), this.vt, 3 * A_PtrSize)
        NumPut("Ptr", this.vt.Ptr, this.obj, 0)
        ComHandler._alive[this.obj.Ptr] := this
    }

    Ptr => this.obj.Ptr

    ; Answers every interface with the object itself (the handler implements no other interface).
    _QueryInterface(selfPtr, riid, ppv) {
        try NumPut("Ptr", selfPtr, ppv, 0)
        catch
            return 0x80004005       ; E_FAIL: the out pointer is bad, nothing is stored
        return 0                    ; S_OK
    }

    _Ref(selfPtr) => 1

    _Invoke(selfPtr, a, b) {
        h := ComHandler._alive.Get(selfPtr, "")
        if (!IsObject(h))
            return 0
        try {
            fn := h.fn               ; not h.fn(a, b): that would pass h as the first argument
            fn(a, b)
        } catch as e
            Log.Write("a1", "help", "a COM callback failed: " e.Message)
        return 0                    ; S_OK: a callback never fails the caller
    }
}
