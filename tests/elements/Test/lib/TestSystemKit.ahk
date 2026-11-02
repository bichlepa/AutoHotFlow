#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\SystemOps.ahk

; Shared part of Action_TestSystemWorker (worker) and Trigger_TestSystemCall (trigger), WI-0117: calls one function of
; SystemOps, chosen by name, with the arguments of the element. The tests cover one function of each group
; (doc/ELEMENT-API-V2.md 3.3a). In the tests the provider TestSystemProvider answers every call; nothing real runs.
; Arguments are text; a function that takes a number converts it. Returns the answer as text ("" for nothing).
; An unknown name throws ElementError, which ends the element with "exception".
class TestSystemKit {
    static Call(function, arg1 := "", arg2 := "") {
        switch function, "Off" {
            case "Shutdown":
                return String(SystemOps.Shutdown(Integer(arg1)))
            case "LockWorkStation":
                return String(SystemOps.LockWorkStation())
            case "DriveEject":
                return String(SystemOps.DriveEject(arg1))
            case "FileRecycleEmpty":
                return String(SystemOps.FileRecycleEmpty(arg1))
            case "MonitorCount":
                return String(SystemOps.MonitorCount())
            case "SoundBeep":
                return String(SystemOps.SoundBeep(800, 100))
            case "SpeakText":
                return String(SystemOps.SpeakText(arg1))
            case "BlockInput":
                return String(SystemOps.BlockInput(arg1))
            case "Send":
                return String(SystemOps.Send(arg1, arg2))
            case "MouseMove":
                return String(SystemOps.MouseMove(10, 20))
            case "SetCapsLockState":
                return String(SystemOps.SetCapsLockState(arg1))
            case "TimeIdle":
                return String(SystemOps.TimeIdle())
            default:
                throw ElementError("TestSystem: unknown function '" function "'")
        }
    }
}
