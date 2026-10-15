#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test element for WI-0011: a worker-mode element that always throws. The worker must report the run
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
