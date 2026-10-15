#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test element for WI-0011: a worker-mode element that finishes at once. It exports the imported
; value "in" as "out" and finishes "normal". Tests use it for imports, exports and the worker's
; plain round trip.
class Action_TestEchoWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: echo in worker"
    static Category() => "Test"

    static Run(ctx, params) {
        ctx.Export("out", ctx.GetImport("in", ""))
        ctx.Finish("normal", "echoed")
    }
}
