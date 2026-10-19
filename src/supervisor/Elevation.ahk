#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\SettingsModel.ahk

; "Run as administrator" (WI-0079, E0073, REQ-SET-040, ARCHITECTURE 6.1 item 8): the decisions and the launch of the elevated
; restart. All processes of a session run with the rights of the supervisor, so the supervisor elevates itself before it
; starts any child. The real elevation (Run "*RunAs", the UAC question) is checked by hand only; tests use the hook
; --fake-elevation=accept|decline and --fake-admin, which exist only in the test entry (HooksAllowed).
class Elevation {
    static TRIED := "elevation-tried"
    static FAKE_ADMIN := "fake-admin"
    static FAKE := "fake-elevation"

    ; Whether this supervisor has administrator rights (or pretends to, in a test).
    static IsAdmin(opts) => (A_IsAdmin ? true : false) || (Elevation.HooksAllowed() && opts.Has(Elevation.FAKE_ADMIN))

    ; The test hooks exist only in the test entry (it registers the test roles through AhfTestRolesFn); the product entry ignores them.
    static HooksAllowed() {
        global AhfTestRolesFn
        return IsSet(AhfTestRolesFn) && AhfTestRolesFn != ""
    }

    ; The setting runAsAdmin, read from Settings.json before the hub runs. Anything unreadable counts as off: the engine
    ; handles a missing or broken file later.
    static WantsElevation(dataDir) {
        path := dataDir "\Settings.json"
        try {
            if (FileExist(path) = "")    ; arch-ok: file-io the one read of the supervisor, before the hub runs (ARCHITECTURE 6.1 item 8)
                return false
            text := FileRead(path, "UTF-8")    ; arch-ok: file-io see above
            values := SettingsModel.Normalize(SettingsModel.FromText(text), &problems)
            return values["runAsAdmin"] ? true : false
        } catch {
            return false
        }
    }

    ; The command line words as one text: the words of argv, those in drop removed, those in add appended; a word with a
    ; blank is put in quotes.
    static ArgText(argv, drop := [], add := []) {
        text := ""
        for word in argv {
            skip := false
            for name in drop
                if (word = "--" name || SubStr(word, 1, StrLen(name) + 3) = "--" name "=")
                    skip := true
            if (!skip)
                text .= " " Elevation._Quote(word)
        }
        for word in add
            text .= " " Elevation._Quote(word)
        return text
    }

    ; One word as the rules of CommandLineToArgvW read it: a word with a blank, a quote or no character is put in quotes; a quote
    ; inside becomes \" and the backslashes before it (or before the closing quote) are doubled.
    static _Quote(word) {
        if (word != "" && !InStr(word, " ") && !InStr(word, "`t") && !InStr(word, '"'))
            return word
        out := ""
        slashes := 0
        loop parse word {
            if (A_LoopField = "\") {
                slashes += 1
                continue
            }
            if (A_LoopField = '"')
                out .= Elevation._Repeat("\", 2 * slashes + 1) '"'
            else
                out .= Elevation._Repeat("\", slashes) A_LoopField
            slashes := 0
        }
        return '"' out Elevation._Repeat("\", 2 * slashes) '"'
    }

    static _Repeat(text, count) {
        out := ""
        loop count
            out .= text
        return out
    }

    ; Starts the supervisor script again with the words in argv (A_Args of this process) plus add. With elevate the real way is
    ; Run "*RunAs" (UAC); the hook of a test starts it normally ("accept", the new one counts as elevated through --fake-admin)
    ; or refuses ("decline"). True when the new process was started; false when the user declined or the start failed.
    static Launch(argv, add, elevate, fake := "") {
        if (elevate && fake = "decline")
            return false
        if (elevate && fake = "accept") {
            add := add.Clone()
            add.Push("--" Elevation.FAKE_ADMIN)
        }
        cmd := '"' A_AhkPath '" "' A_ScriptFullPath '"' Elevation.ArgText(argv, [Elevation.TRIED, Elevation.FAKE_ADMIN], add)
        try {
            Run((elevate && fake = "") ? "*RunAs " cmd : cmd, A_WorkingDir)    ; relative --data or --session paths survive
        } catch as e {
            Log.Write("a1", "supervisor", "the start of the new supervisor failed or was declined: " e.Message)
            return false
        }
        return true
    }
}
