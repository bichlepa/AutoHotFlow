#Requires AutoHotkey v2.0
#Include ..\..\core\AhfVersion.ahk

; Built-in variables (WI-0040, doc/EXPRESSION-LANGUAGE.md section 18.4): the 55 variables of v1 that come from
; AutoHotkey and the 13 of AutoHotFlow itself (v1/Source_Common/Variables/Global variables.ahk:2 and :4, values in
; BuiltInVariable_Get, :164). Names ignore case. They are read-only and exist in every place, also in common.
;
; env is a Map with the values that depend on the execution: flowId, elementId, flowName, elementName, workingDir,
; and optionally ahfVersion (tests). A getter never throws: a failing system call gives the empty text.
class BuiltInVars {
    static _getters := ""

    ; The default working directory of flows until the settings exist (E0028, v1 Settings.ahk:15).
    static DefaultWorkingDir() => A_MyDocuments "\AutoHotFlow"

    ; The working directory of a flow (v1 xx_GetWorkingDir and the check in v1 Load.ahk:214): the flow's own
    ; folder if flowSettings.DefaultWorkingDir is off and flowSettings.WorkingDir is set, else the default.
    static WorkingDirOf(flowSettings) {
        if (!(flowSettings is Map))
            return BuiltInVars.DefaultWorkingDir()
        useDefault := flowSettings.Get("DefaultWorkingDir", "")
        own := String(IsObject(flowSettings.Get("WorkingDir", "")) ? "" : flowSettings.Get("WorkingDir", ""))
        if (BuiltInVars._Truthy(useDefault) || Trim(own) = "")
            return BuiltInVars.DefaultWorkingDir()
        return own
    }

    static Has(name) => BuiltInVars._Table().Has(name)

    ; The value of a built-in variable, or "" if there is none with this name.
    static Get(name, env) {
        t := BuiltInVars._Table()
        if (!t.Has(name))
            return ""
        try {
            return t[name](env)
        } catch {
            return ""
        }
    }

    ; All names, in the spelling of v1.
    static Names() {
        out := []
        for name in BuiltInVars._Table()
            out.Push(name)
        return out
    }

    static _Table() {
        if (BuiltInVars._getters != "")
            return BuiltInVars._getters
        t := Map()
        t.CaseSense := "Off"
        ; From AutoHotkey (v1 global_AllBuiltInVars). AutoHotkey v2 has the same variables, except where noted.
        t["A_Space"] := (env) => A_Space
        t["A_Tab"] := (env) => A_Tab
        t["A_YYYY"] := (env) => A_YYYY
        t["A_Year"] := (env) => A_Year
        t["A_MM"] := (env) => A_MM
        t["A_Mon"] := (env) => A_Mon
        t["A_DD"] := (env) => A_DD
        t["A_MDay"] := (env) => A_MDay
        t["A_MMMM"] := (env) => A_MMMM
        t["A_MMM"] := (env) => A_MMM
        t["A_DDDD"] := (env) => A_DDDD
        t["A_DDD"] := (env) => A_DDD
        t["A_WDay"] := (env) => A_WDay
        t["A_YDay"] := (env) => A_YDay
        t["A_Hour"] := (env) => A_Hour
        t["A_Min"] := (env) => A_Min
        t["A_Sec"] := (env) => A_Sec
        t["A_MSec"] := (env) => A_MSec
        t["A_TickCount"] := (env) => A_TickCount
        t["A_TimeIdle"] := (env) => A_TimeIdle
        t["A_TimeIdlePhysical"] := (env) => A_TimeIdlePhysical
        t["A_Temp"] := (env) => A_Temp
        t["A_OSVersion"] := (env) => A_OSVersion
        t["A_Is64bitOS"] := (env) => A_Is64bitOS
        t["A_PtrSize"] := (env) => A_PtrSize                ; 8: 64 bit only (E0004); v1 was 4
        t["A_Language"] := (env) => A_Language
        t["A_ComputerName"] := (env) => A_ComputerName
        t["A_UserName"] := (env) => A_UserName
        t["A_ScriptDir"] := (env) => A_ScriptDir            ; the folder of the program (of AutoHotFlow.ahk)
        t["A_WinDir"] := (env) => A_WinDir
        t["A_ProgramFiles"] := (env) => A_ProgramFiles
        t["A_AppData"] := (env) => A_AppData
        t["A_AppDataCommon"] := (env) => A_AppDataCommon
        t["A_Desktop"] := (env) => A_Desktop
        t["A_DesktopCommon"] := (env) => A_DesktopCommon
        t["A_StartMenu"] := (env) => A_StartMenu
        t["A_StartMenuCommon"] := (env) => A_StartMenuCommon
        t["A_Programs"] := (env) => A_Programs
        t["A_ProgramsCommon"] := (env) => A_ProgramsCommon
        t["A_Startup"] := (env) => A_Startup
        t["A_StartupCommon"] := (env) => A_StartupCommon
        t["A_MyDocuments"] := (env) => A_MyDocuments
        t["A_IsAdmin"] := (env) => A_IsAdmin
        t["A_ScreenWidth"] := (env) => A_ScreenWidth
        t["A_ScreenHeight"] := (env) => A_ScreenHeight
        t["A_ScreenDPI"] := (env) => A_ScreenDPI
        t["A_IPAddress1"] := (env) => BuiltInVars._IPAddress(1)  ; v2 has SysGetIPAddresses() instead
        t["A_IPAddress2"] := (env) => BuiltInVars._IPAddress(2)
        t["A_IPAddress3"] := (env) => BuiltInVars._IPAddress(3)
        t["A_IPAddress4"] := (env) => BuiltInVars._IPAddress(4)
        t["A_Cursor"] := (env) => A_Cursor
        t["A_CaretX"] := (env) => BuiltInVars._Caret(1)           ; v2 has CaretGetPos() instead
        t["A_CaretY"] := (env) => BuiltInVars._Caret(2)
        t["A_Now"] := (env) => A_Now
        t["A_NowUTC"] := (env) => A_NowUTC
        ; Of AutoHotFlow (v1 global_AllCustomBuiltInVars).
        t["A_YWeek"] := (env) => SubStr(A_YWeek, -2)               ; only the week, as v1
        t["A_LineFeed"] := (env) => "`n"
        t["A_LF"] := (env) => "`n"
        t["A_CR"] := (env) => "`r"
        t["A_CarriageReturn"] := (env) => "`r"
        t["A_WorkingDir"] := (env) => env.Get("workingDir", "")
        t["A_LanguageName"] := (env) => BuiltInVars._LanguageName()
        t["A_NowString"] := (env) => FormatTime(A_Now)
        t["A_FlowName"] := (env) => env.Get("flowName", "")
        t["A_FlowID"] := (env) => env.Get("flowId", "")
        t["A_ElementName"] := (env) => env.Get("elementName", "")
        t["A_ElementID"] := (env) => env.Get("elementId", "")
        t["A_AhfVersion"] := (env) => env.Get("ahfVersion", AhfVersion.Current)
        BuiltInVars._getters := t
        return t
    }

    ; A_IPAddress1 to 4 of v1: the address of the n-th network adapter, "0.0.0.0" if there is none.
    static _IPAddress(n) {
        ips := SysGetIPAddresses()
        return (n <= ips.Length) ? ips[n] : "0.0.0.0"
    }

    ; A_CaretX and A_CaretY of v1: relative to the active window (CoordMode Window), empty without a caret.
    static _Caret(which) {
        prev := A_CoordModeCaret
        CoordMode("Caret", "Window")
        try {
            if (!CaretGetPos(&x, &y))
                return ""
            return (which = 1) ? x : y
        } finally {
            CoordMode("Caret", prev)
        }
    }

    ; The English name of the user's language (A_Language). v1 always gave the empty text (a TODO in the v1 code).
    static _LanguageName() {
        name := Buffer(85 * 2, 0)
        if (!DllCall("LCIDToLocaleName", "UInt", Integer("0x" A_Language), "Ptr", name, "Int", 85, "UInt", 0, "Int"))
            return ""
        buf := Buffer(256, 0)
        if (!DllCall("GetLocaleInfoEx", "Ptr", name, "UInt", 0x1001, "Ptr", buf, "Int", 128, "Int"))  ; LOCALE_SENGLISHLANGUAGENAME
            return ""
        return StrGet(buf)
    }

    static _Truthy(v) {
        if (IsObject(v))
            return false
        s := Trim(String(v))
        return !(s = "" || s = "0" || s = "false")
    }
}
