#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test element of WI-0050 (worker): sets the instance variable ask_blocking, then blocks in one call of BlockMs (default 1500 ms, below the 2 s in which the worker must
; confirm a cancel), so a stop of the instance reaches it only afterwards; then it asks the engine for a variable. After
; a stop the engine answers gone (PROTOCOL 4.5) and GetVar throws; the element logs the text ("asked after the stop:
; <message>", level f1) and lets the error end it. Without a stop it finishes "normal".
class Action_TestAskAfterStopWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: block, then ask the engine, in a worker"
    static Category() => "Test"

    static Run(ctx, params) {
        blockMs := params.HasProp("BlockMs") && params.BlockMs != "" ? Integer(params.BlockMs) : 1500
        ctx.SetVar("ask_blocking", 1)               ; the test waits for this before it stops the instance
        DllCall("Sleep", "UInt", blockMs)
        try {
            ctx.GetVar("x")
        } catch as e {
            ctx.Log("f1", "asked after the stop: " e.Message)
            throw e
        }
        ctx.Finish("normal")
    }
}
