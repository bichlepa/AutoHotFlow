#Requires AutoHotkey v2.0
#Include Errors.ahk

; Monotonic time in milliseconds for timeouts and measurements. Not used for ids (see Ids.ahk).
class Time {
    static frequency := 0

    ; Milliseconds (float) since an arbitrary fixed point. Never goes backwards.
    static NowMs() {
        if (this.frequency = 0) {
            freq := 0
            if (!DllCall("QueryPerformanceFrequency", "Int64*", &freq))
                throw AhfError("Time: QueryPerformanceFrequency failed", ErrCode.INTERNAL)
            this.frequency := freq
        }
        count := 0
        if (!DllCall("QueryPerformanceCounter", "Int64*", &count))
            throw AhfError("Time: QueryPerformanceCounter failed", ErrCode.INTERNAL)
        return count * 1000.0 / this.frequency
    }
}
