#Requires AutoHotkey v2.0
#Include ..\..\expr\ExprNames.ahk

; Rules for names of variables (WI-0040, doc/EXPRESSION-LANGUAGE.md section 18). Ports of v1 Var_RetrieveDestination,
; Var_RetrieveDestination_Common and Var_CheckName (v1/Source_Execution/Variables/Variables.ahk:219,
; v1/Source_Common/Variables/Global variables.ahk:358 and :553). The scope of a variable follows from its name:
;   A_...      loop, thread or built-in (case does not matter: a_index is A_Index)
;   global_... global (all flows)
;   static_... static (all instances of one flow)
;   any other  instance
; "common" is the place without an instance and a thread (v1 *_Common: editor, manager, settings); only global
; and static variables can be set there.
class VarNames {
    ; Answers of Destination that are errors (the texts of v1).
    static NO_PERMISSION := "error_noPermission"
    static NOT_A := "error_NotStartWith_A"

    ; "a" for an A_ name, "global", "static" or "" for any other name.
    static Kind(name) {
        if (SubStr(name, 1, 2) = "A_")
            return "a"
        if (SubStr(name, 1, 7) = "global_")
            return "global"
        if (SubStr(name, 1, 7) = "static_")
            return "static"
        return ""
    }

    static IsA(name) => SubStr(name, 1, 2) = "A_"

    ; Where a variable with this name is set (v1 Var_RetrieveDestination). location is "" or, for an A_ name,
    ; "thread" or "loop" (case does not matter). Returns "loop", "thread", "instance", "global", "static",
    ; NO_PERMISSION (an A_ name without the location thread or loop; in common every A_ and every instance name)
    ; or NOT_A (the location thread or loop for a name that does not start with A_).
    static Destination(name, location := "", common := false) {
        kind := VarNames.Kind(name)
        if (common) {
            if (kind = "global" || kind = "static")
                return kind
            return VarNames.NO_PERMISSION
        }
        loc := StrLower(location)
        if (kind = "a")
            return (loc = "thread" || loc = "loop") ? loc : VarNames.NO_PERMISSION
        if (loc = "thread" || loc = "loop")
            return VarNames.NOT_A
        return (kind = "") ? "instance" : kind
    }

    ; "OK", "Empty", "StartsWithNumber" or "ForbiddenCharacter" (v1 Var_CheckName(name, true)). The rule is the one
    ; of the expression language (ExprNames.Check); v1 tried to create an AutoHotkey variable with the name.
    static Check(name) => ExprNames.Check(name)

    ; The parts of a name with dots: "a.b.1" gives ["a", "b", "1"] (v1 parseObjectPath splits at every dot).
    static Split(text) => StrSplit(text, ".")
}
