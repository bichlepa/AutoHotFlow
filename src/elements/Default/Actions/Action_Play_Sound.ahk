#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\SoundOps.ahk
#Include ..\lib\TextOps.ahk

; Action Play sound of the package Default (WI-0124): plays a system sound (a file of %WinDir%\media) or a sound file.
; Specification: the help text of v1 (help/en/Actions/Play_Sound.md). Class ID, parameter IDs, defaults and language keys
; are those of v1 (Source_Elements/Default/Actions/Play_Sound.ahk).
;
; Mode worker. The sound is played by the worker process that runs the job and goes on after the job has ended when the
; element does not wait (WI-0124 task 1, ELEMENT-API-V2 3.3a): AutoHotkey plays it in its own process, and the worker
; is free for other jobs meanwhile. A new sound of the same process stops the playing one (AutoHotkey). The sound is
; reached by Action_Stop_Sound only in the same worker process (MIGRATION M-0131).
;
; New option (MIGRATION M-0130): "Wait until the sound has finished" (default off, as v1: the flow goes on at once).
; The Preview buttons of v1 are not in v2 (M-0130). The file check is done before the call: a missing file is the
; exception of v1 ("Sound could not be played").
class Action_Play_Sound extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Play Sound")
    static Category() => Lang("Sound")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Select sound")},
        {type: "Radio", id: "WhichSound", default: "SystemSound", choices: [Lang("System sound"), Lang("Sound file")]
            , result: "enum", enum: ["SystemSound", "SoundFile"]},
        {type: "DropDown", id: "systemSound", default: "tada.wav", choices: SoundOps.SystemSounds(ctx), result: "string"},
        {type: "File", id: "soundfile", label: Lang("Select a sound file")},
        {type: "Checkbox", id: "WaitUntilFinished", default: 0, label: Lang("Wait until the sound has finished")}
    ]

    static GenerateName(ctx, params) {
        sound := (TextOps.Par(params, "WhichSound") = "SoundFile") ? TextOps.Par(params, "soundfile") : TextOps.Par(params, "systemSound")
        return Lang("Play Sound") " - " sound
    }

    static Run(ctx, params) {
        isFile := (TextOps.Par(params, "WhichSound") = "SoundFile")
        p := ctx.EvalParams(params, isFile ? ["systemSound"] : ["soundfile"])
        path := isFile ? p.soundfile : SoundOps.SystemSoundPath(p.systemSound)
        if (!FileExist(path))
            throw ElementError(Lang("Sound could not be played"))
        try SystemOps.SoundPlay(path, DialogOps.Truthy(p.WaitUntilFinished) ? 1 : 0)
        catch
            throw ElementError(Lang("Sound could not be played"))
        ctx.Finish("normal")
    }
}
