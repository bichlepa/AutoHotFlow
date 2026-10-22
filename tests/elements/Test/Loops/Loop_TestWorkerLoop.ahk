#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test element for WI-0121: a worker loop that reports the entry point it sees. The job gets it through env.entryPoint
; (PROTOCOL 4.5), so ctx.entryPoint must be "head", "tail", "break" or "" here as it is inline. The element exports the
; entry point as "entry" and finishes as a loop does: head starts a pass, tail and break leave the loop.
class Loop_TestWorkerLoop extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: worker loop"
    static Category() => "Test"

    static Run(ctx, params) {
        entry := StrLower(String(ctx.entryPoint))
        ctx.Export("entry", entry)
        if (entry = "head")
            ctx.Finish("head")
        else if (entry = "tail" || entry = "break")
            ctx.Finish("tail")
        else
            ctx.Finish("exception", "No information whether the connection leads to head or tail")
    }
}
