#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Log.ahk
#Include ..\..\core\Time.ahk
#Include AhfElement.ahk
#Include ElementRegistry.ahk
#Include ExecContext.ahk

; The one place where element code is called (doc/CONVENTIONS.md section 3). No element call
; happens outside this class. Any exception from element code ends the run with "exception" and the
; exception message, so element code cannot crash the engine.
class ElementRunner {
    ; Calls to Run longer than this are reported to onSlow (ARCHITECTURE 2.3, watchdog).
    static SlowMs := 250

    ; Runs cls.Run(ctx, params). params must already be evaluated.
    ; onSlow(classId, ms) is called after a Run that took longer than SlowMs (synchronous part only).
    static Run(cls, ctx, params, onSlow := "") {
        start := Time.NowMs()
        try {
            cls.Run(ctx, params)
        } catch as e {
            ctx.Finish("exception", e.Message)
        }
        ms := Time.NowMs() - start
        if (ms > this.SlowMs && IsObject(onSlow))
            onSlow(ElementRegistry.IdOf(cls), ms)
    }

    ; Calls cls.Stop(ctx, params), then cancels the timers of ctx. An exception in Stop is logged only,
    ; the timers are cancelled anyway.
    static Stop(cls, ctx, params) {
        try {
            cls.Stop(ctx, params)
        } catch as e {
            Log.Write("a0", "element " ctx.elementId, "Stop failed: " e.Message, ctx.flowId)
        }
        ctx.CancelTimers()
    }
}
