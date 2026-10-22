#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The shared functions of the process elements of the package Default (WI-0123): the process that a parameter names (a
; name or a PID), the run mode of Run and the start of a program. The elements that touch processes are workers (process
; access, ARCHITECTURE 2.3); this file makes no call that disturbs the computer itself.
;
; Process names: the name is not case-sensitive and the first matching process is used (AutoHotkey). A text of digits is
; a PID, as v1 accepted it. An empty text is refused: AutoHotkey would otherwise act on the script's own process
; (MIGRATION M-0120).
class ProcessOps {
    ; The process of a parameter: an Integer for a PID, the text for a name. An empty text is an exception.
    static Target(text) {
        text := Trim(text)
        if (text = "")
            throw ElementError(Lang("Process name or ID is empty"))
        return IsInteger(text) ? Integer(text) : text
    }

    ; The options of Run for the run mode of v1: "Normal" is the empty option, the others are the options of AutoHotkey.
    static RunOptions(mode) => (mode = "Normal") ? "" : mode

    ; Starts a program with the working folder dir ("" for the working folder of the worker). Returns its PID, or 0 when
    ; AutoHotkey does not give one (a document or a URL opened by a verb). Throws what Run throws.
    static Start(target, dir, options) {
        pid := 0
        Run(target, dir, options, &pid)
        return pid
    }
}
