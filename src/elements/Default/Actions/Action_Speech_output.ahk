#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\SoundOps.ahk
#Include ..\lib\TextOps.ahk

; Action Speech output of the package Default (WI-0124): reads a text with an installed speech voice (SAPI). Specification:
; the help text of v1 (help/en/Actions/Speech_output.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Speech_output.ahk), except the default voice (MIGRATION M-0129).
;
; Mode worker. SAPI is called through the seam SystemOps (E0103): a test records the text, the voice and the options and
; speaks nothing. A speech that does not wait goes on in the worker process after the job has ended (ELEMENT-API-V2 3.3a).
;   "Wait until previous speech output has finished" (off: the speech of this process is stopped and replaced; v1 likewise)
;   "Wait until this speech output finishes" (on: the job waits for the end of the speech, SAPI synchronous)
; Speed and pitch are integers from -10 to 10 and the volume 0 to 100 (SAPI). The voice is one of the voices of the
; machine; an empty voice is the default voice of the system. A voice that is not installed is an exception with the
; v1 text. Speech of another worker process is neither waited for nor stopped (MIGRATION M-0125).
class Action_Speech_output extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Speech output")
    static Category() => Lang("Sound") "|" Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Text to speak")},
        {type: "multiLineEdit", id: "text", default: Lang("Message"), content: "String"},
        {type: "Label", label: Lang("Wait options")},
        {type: "Checkbox", id: "WaitUntilPreviousFinished", default: 0
            , label: Lang("Wait until previous speech output has finished (if any)")},
        {type: "Checkbox", id: "WaitUntilCurrentFinishes", default: 1, label: Lang("Wait until this speech output finishes")},
        {type: "Label", label: Lang("Speech engine")},
        {type: "DropDown", id: "TTSEngine", default: "", choices: SoundOps.Voices(ctx), result: "string"},
        {type: "Label", label: Lang("Volume #sound volume")},
        {type: "Slider", id: "volume", default: 100},
        {type: "Label", label: Lang("Speed")},
        {type: "Edit", id: "speed", default: 0, content: "Integer", WarnIfEmpty: true},
        {type: "Label", label: Lang("Pitch #tone pitch")},
        {type: "Edit", id: "pitch", default: 0, content: "Integer", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Speech output") " - " TextOps.Par(params, "text") " - " TextOps.Par(params, "TTSEngine")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (p.TTSEngine != "" && !SoundOps.HasVoice(p.TTSEngine))
            throw ElementError(Lang("Could not find TTS engine '%1%'", p.TTSEngine))
        waitPrevious := DialogOps.Truthy(p.WaitUntilPreviousFinished)
        waitCurrent := DialogOps.Truthy(p.WaitUntilCurrentFinishes)
        try {
            if (waitPrevious)
                SystemOps.SpeechWait()
            SystemOps.SpeakText(p.text, p.TTSEngine, p.speed, p.volume, p.pitch, waitCurrent ? 1 : 0, waitPrevious ? 0 : 1)
        } catch {
            throw ElementError(Lang("Error on speech output"))
        }
        ctx.Finish("normal")
    }
}
