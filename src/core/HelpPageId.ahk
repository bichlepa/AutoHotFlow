#Requires AutoHotkey v2.0

; The ID of a help page (WI-0111, PROTOCOL 4.12): the path of the page's Markdown source under the help root, without
; ".md": an element page "<Kind>/<Name>" (Actions/Sleep) or a general page "<Name>" (Welcome). The empty ID is the index.
; The supervisor checks the IDs of cmd.help.show with it; the help role maps them to files (src/help/HelpPages.ahk).
class HelpPageId {
    static MAX_CHARS := 80
    ; The class name prefix of an element to the folder of its kind (the class is Action_Sleep, the page Actions/Sleep).
    static KINDS := Map("Action", "Actions", "Condition", "Conditions", "Loop", "Loops", "Trigger", "Triggers")

    ; The page ID of an element class ("Action_Sleep" -> "Actions/Sleep"), "" when the name has no known kind.
    static ElementId(className) {
        if (IsObject(className))
            return ""
        p := InStr(className, "_")
        if (!p)
            return ""
        kind := SubStr(className, 1, p - 1)
        if (!HelpPageId.KINDS.Has(kind))
            return ""
        return HelpPageId.KINDS[kind] "/" SubStr(className, p + 1)
    }

    ; True for "" (the index), a name, or a kind folder and a name, separated by one "/". Letters, digits and "_" only.
    static IdOk(id) {
        if (IsObject(id))
            return false
        if (id = "")
            return true
        return StrLen(id) <= HelpPageId.MAX_CHARS && RegExMatch(id, "^(?:[A-Za-z]+/)?[A-Za-z0-9_]+$")
    }
}
