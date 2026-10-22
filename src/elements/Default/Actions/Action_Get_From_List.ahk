#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk
#Include ..\lib\TextOps.ahk

; Action Get from list of the package Default (WI-0119): writes one value of a list to a variable: the first or the last
; value (the lowest or highest Integer key), a random one, or the value of a given key or position.
; Specification: the help text of v1 (help/en/Actions/Get_from_list.md). Class ID, parameter IDs, enum values, defaults
; and language keys are those of v1 (Source_Elements/Default/Actions/Get_from_list.ahk). The list logic is in
; lib/ListOps.ahk.
;
;   WhichPosition  First, Last, Random (a random Integer key of the list, MIGRATION M-0109) or Specified (Position, a key
;                  of any kind, a number or a text). The default is the enum value (M-0099); a stored position is read as
;                  the enum value at that position.
class Action_Get_From_List extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Get From List")
    static Category() => Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input list")},
        {type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Key or position")},
        {type: "Radio", id: "WhichPosition", default: "First", result: "enum", choices: [Lang("First integer position"), Lang("Last integer position"), Lang("Random integer position"), Lang("Following position or key")], enum: ["First", "Last", "Random", "Specified"]},
        {type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        which := ListOps.EnumValue(TextOps.Par(params, "WhichPosition"), ["First", "Last", "Random", "Specified"])
        positionText := " - "
        switch which {
            case "First": positionText .= Lang("First value")
            case "Last": positionText .= Lang("Last value")
            case "Random": positionText .= Lang("Random value")
            case "Specified": positionText .= Lang("At position '%1%'", TextOps.Par(params, "Position"))
        }
        return Lang("Get from list %1%", TextOps.Par(params, "ListName")) positionText " - " TextOps.Par(params, "Varname")
    }

    static CheckSettings(form, params, staticValues) {
        form.Enable("Position", ListOps.EnumValue(params.WhichPosition, ["First", "Last", "Random", "Specified"]) = "Specified")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "Position")
        which := ListOps.EnumValue(p.WhichPosition, ["First", "Last", "Random", "Specified"])
        list := ListOps.Require(p.ListName, Lang("Variable '%1%' does not contain a list.", params.ListName))
        noIntegerKey := Lang("The list '%1%' does not contain an integer key.", params.ListName)
        switch which {
            case "First":
                key := ListOps.MinIndex(list)
                if (key = "")
                    throw ElementError(noIntegerKey)
            case "Last":
                key := ListOps.MaxIndex(list)
                if (key = "")
                    throw ElementError(noIntegerKey)
            case "Random":
                keys := ListOps.IntKeys(list)
                if (keys.Length = 0)
                    throw ElementError(noIntegerKey)
                key := keys[Random(1, keys.Length)]
            case "Specified":
                p := ctx.EvalMoreParams(p, params, "Position")
                if (IsObject(p.Position) || String(p.Position) = "")
                    throw ElementError(Lang("%1% is not specified.", Lang("Position")))
                if (!ListOps.HasKey(list, p.Position))
                    throw ElementError(Lang("The list '%1%' does not contain the key '%2%'.", params.ListName, p.Position))
                key := ListOps.NormKey(p.Position)
            default:
                throw ElementError("Get from list: unknown position '" p.WhichPosition "'")
        }
        if (!ctx.SetVar(p.Varname, list[key]))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
