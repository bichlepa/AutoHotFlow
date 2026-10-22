#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The shared functions of the drive elements of the package Default (WI-0122): the drive letter of a parameter and the
; drive list of the drop-downs. The drive functions of AutoHotkey that only read (DriveGetList, DriveGetLabel, ...) run in
; the worker; the functions that change a drive (label, eject, lock) go through the seam SystemOps (E0103).
;
; The drive list is read only with a context (the editor): the engine calls Parameters("") to convert the flows and must
; not ask the system for the drives (ELEMENT-API-V2 section 2, Parameters). Without a context the drop-down is empty.
class DriveOps {
    ; The drive letter of a parameter as "C:": "C", "c:" and "C:\" are accepted. An empty text is "Drive is not specified"
    ; (the v1 text); any other text is refused.
    static Letter(text) {
        value := Trim(String(text))
        if (value = "")
            throw ElementError(Lang("Drive is not specified"))
        if (RegExMatch(value, "^([A-Za-z]):?\\?$", &m))
            return StrUpper(m[1]) ":"
        throw ElementError(Lang("'%1%' is not a drive letter.", value))
    }

    ; The drives of the system as "C:", "D:", ... for a drop-down (the editor only). The first one is the default.
    static Choices(ctx) {
        choices := []
        if (!IsObject(ctx))
            return choices
        try {
            list := DriveGetList()
            loop parse list
                choices.Push(A_LoopField ":")
        }
        return choices
    }

    ; The default of a drop-down of drives: the first drive of the system (the editor only), "" otherwise.
    static Default(ctx) {
        choices := DriveOps.Choices(ctx)
        return choices.Length ? choices[1] : ""
    }
}
