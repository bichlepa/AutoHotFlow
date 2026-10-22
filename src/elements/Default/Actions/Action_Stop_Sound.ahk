#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Stop sound of the package Default (WI-0124): stops the sound that the worker process plays (v1 SoundPlay, -).
; Specification: the help text of v1 (help/en/Actions/Stop_Sound.md). Class ID and language keys are those of v1
; (Source_Elements/Default/Actions/Stop_Sound.ahk).
;
; Mode worker. A sound is played by the worker process of the job that started it, and only that process is reached
; (ELEMENT-API-V2 3.3a, MIGRATION M-0125): a sound that another worker plays goes on. The stop goes through the seam.
class Action_Stop_Sound extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Stop Sound")
    static Category() => Lang("Sound")

    static Parameters(ctx) => []

    static GenerateName(ctx, params) => Lang("Stop Sound")

    static Run(ctx, params) {
        try SystemOps.SoundStop()
        catch
            throw ElementError(Lang("Sound could not be stopped"))
        ctx.Finish("normal")
    }
}
