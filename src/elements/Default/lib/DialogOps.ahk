#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk

; Shared parts of the dialog elements of the package Default (WI-0056): Action_Message_Box and
; Condition_Confirmation_Dialog. Both use the window of Dialogs.Window (ELEMENT-API-V2 3.3) and the same timeout units
; as v1 (Seconds, Minutes, Hours).
class DialogOps {
    static UNIT_MS := Map("seconds", 1000, "minutes", 60000, "hours", 3600000)

    ; A checkbox value of a flow as a truth value: 1, a text other than "", "0" or "false", and not an object.
    static Truthy(value) => !IsObject(value) && value != "" && value != 0 && value != "0" && value != "false"

    ; The timeout in milliseconds for amount in unit (the v1 choice text, any case). Throws ElementError for a unit that is
    ; not one of the three, or an amount that is not a number of 0 or more.
    static TimeoutMs(amount, unit) {
        key := StrLower(String(unit))
        if (IsObject(unit) || !this.UNIT_MS.Has(key))
            throw ElementError("Timeout: unknown unit '" (IsObject(unit) ? Type(unit) : unit) "'")
        if (IsObject(amount) || !IsNumber(amount) || amount < 0)
            throw ElementError("Timeout: the amount must be a number of 0 or more, not '" (IsObject(amount) ? Type(amount) : amount) "'")
        return Integer(amount * this.UNIT_MS[key])
    }
}
