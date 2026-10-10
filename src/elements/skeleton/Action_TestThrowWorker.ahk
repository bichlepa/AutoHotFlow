#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element for WI-11: a worker-mode element that always throws. The worker must report the run
; as "exception" with the message, through ElementRunner, and stay usable for the next job.
class Action_TestThrowWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: throw in worker"
    static Category() => "Test"

    static Run(ctx, params) {
        throw ElementError("test worker throw")
    }
}

ElementRegistry.Register(Action_TestThrowWorker)
