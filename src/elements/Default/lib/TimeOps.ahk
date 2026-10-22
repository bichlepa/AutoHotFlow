#Requires AutoHotkey v2.0

; The shared part of the time elements of the package Default (WI-0118): the units that the functions DateAdd and
; DateDiff take, which are the units of the v1 elements Time calculation and Time difference. The check of a time stamp
; is the function IsTime of AutoHotkey v2 (MIGRATION M-0053); a pure function, no ctx and no I/O.
class TimeOps {
    static Units := ["Seconds", "Minutes", "Hours", "Days"]

    ; True for one of the units, without regard to case (AutoHotkey string comparison).
    static IsUnit(unit) {
        for name in TimeOps.Units {
            if (unit = name)
                return true
        }
        return false
    }
}
