#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Lang.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include FlowGeometry.ahk

; The class list of a new element and the element it makes (WI-0099, REQ-EDT-050, REQ-USE-010, REQ-USE-020, PROTOCOL 4.11).
; Pure functions, no window and no message: the list (Groups), the default values of a class (Defaults) and the element
; of a new one (NewElement). The window and the headless driver show the list; EditorAdd asks for it and commits the element.
;
; The kind of a class is the prefix of its name (Action_, Condition_, Loop_, Trigger_), as its folder says (ELEMENT-API-V2
; section 2). The level of a class is hidden above the user's level (REQ-USE-010, v1 ShouldShowThatElementLevel): Beginner
; shows the Beginner classes, Advanced the Beginner and Advanced ones, Programmer all. A class of the kind that is not shown
; is left out, except the class named by keepId (the class the element has already, v1). An experimental class stays in
; the list and its label carries the mark (REQ-USE-020).
;
; The default values come from the class: Parameters("") (the id and default of each parameter), the name from
; GenerateName (under try; the display name when that fails or is empty, as v1 gave a standard name) and the package and its
; version from the registry. A loop gets the default height of its bar (v1 Element_SetType: 150). The first manual trigger
; of a flow is its DefaultTrigger (the others are not, as v1 Element_checkAndFixDefaultTrigger keeps one).
class NewElementCatalog {
    static KINDS := Map("action", "Action_", "condition", "Condition_", "loop", "Loop_", "trigger", "Trigger_")
    static LEVELS := Map("Beginner", 1, "Advanced", 2, "Programmer", 3)
    static LOOP_HEIGHT := 150        ; v1 Element_SetType: the height of the bar of a new loop
    static MANUAL_TRIGGER := "Trigger_Manual"

    ; The kind ("action", "condition", "loop", "trigger") of a qualified ID ("Default.Action_Sleep"), or "" for none.
    static KindOf(qualifiedId) {
        cls := ElementRegistry.ClassOf(qualifiedId)
        for kind, prefix in NewElementCatalog.KINDS {
            if (SubStr(cls, 1, StrLen(prefix)) = prefix)
                return kind
        }
        return ""
    }

    ; The rank of a level (Beginner 1, Advanced 2, Programmer 3); an unknown level counts as Beginner.
    static RankOf(level) => NewElementCatalog.LEVELS.Get(level, 1)

    ; True when a class of this level is shown to a user of userLevel.
    static Shown(level, userLevel) => NewElementCatalog.RankOf(level) <= NewElementCatalog.RankOf(userLevel)

    ; The categories of a class: its Category() text, split at "|" (a class may name several, v1). Unique, in order.
    static CategoriesOf(cls) {
        text := ""
        try {
            text := cls.Category()
        } catch {
            text := ""
        }
        out := []
        for part in StrSplit(text, "|") {
            if (part != "" && !NewElementCatalog._Has(out, part))
                out.Push(part)
        }
        return out
    }

    ; The list for the kind, as the class selector shows it: an Array of [category, items], the categories sorted by name;
    ; an item is [qualifiedId, label] with the labels sorted. The label is the display name, with the mark of an
    ; experimental class. classes: the classes to choose from (default: every registered class; a test gives its own).
    static Groups(kind, userLevel, keepId := "", classes := "") {
        if (classes = "")
            classes := ElementRegistry.All()
        byCategory := Map()
        order := []
        for cls in classes {
            id := ElementRegistry.IdOf(cls)
            if (NewElementCatalog.KindOf(id) != kind)
                continue
            if (id != keepId && !NewElementCatalog.Shown(cls.Level, userLevel))
                continue
            label := cls.Name()
            if (cls.Stability = "Experimental")
                label .= " (" Lang("Experimental element") ")"
            for category in NewElementCatalog.CategoriesOf(cls) {
                if (!byCategory.Has(category)) {
                    byCategory[category] := []
                    order.Push(category)
                }
                byCategory[category].Push([id, label])
            }
        }
        NewElementCatalog._Sort(order, (a, b) => StrCompare(a, b, "Off"))
        groups := []
        for category in order {
            items := byCategory[category]
            NewElementCatalog._Sort(items, (a, b) => StrCompare(a[2], b[2], "Off"))
            groups.Push([category, items])
        }
        return groups
    }

    ; The defaults of a class: Map("pars", Map of the parameter defaults, "name", the default name, "package", "packageVersion",
    ; "class" (the class name without the package) and "kind"). cls: the class when it is not in the registry (a test).
    ; A class whose Parameters("") or GenerateName fails gives what it has: no parameters, and the display name.
    static Defaults(qualifiedId, cls := "") {
        if (cls = "")
            cls := ElementRegistry.Get(qualifiedId)
        if (!IsObject(cls))
            throw AhfError("no element class '" qualifiedId "'", ErrCode.BAD_ARGS)
        pars := Map()
        try {
            for entry in cls.Parameters("") {
                if (entry is Object && entry.HasProp("id") && entry.HasProp("default"))
                    pars[entry.id] := entry.default
            }
        } catch {
            pars := Map()
        }
        name := ""
        try {
            name := cls.GenerateName("", NewElementCatalog._ParamsOf(pars))
        } catch {
            name := ""
        }
        if (name = "")
            name := cls.Name()
        package := ElementRegistry.PackageOf(qualifiedId)
        return Map("pars", pars, "name", name, "package", package
            , "packageVersion", ElementRegistry.PackageVersion(package)
            , "class", ElementRegistry.ClassOf(qualifiedId), "kind", NewElementCatalog.KindOf(qualifiedId))
    }

    ; The element of a new one (the operation element.add of PROTOCOL 4.2): kind, the class (qualified ID), its position
    ; (flow units), the new ID, and whether the flow has a manual trigger already (then the new one is no default).
    static NewElement(kind, qualifiedId, x, y, elementId, hasManualTrigger) {
        d := NewElementCatalog.Defaults(qualifiedId)
        if (d["kind"] != kind)
            throw AhfError("'" qualifiedId "' is not a " kind, ErrCode.BAD_ARGS)
        el := Map("ID", elementId, "type", kind, "class", d["class"], "package", d["package"]
            , "packageVersion", d["packageVersion"], "x", x, "y", y, "name", d["name"], "StandardName", 1
            , "pars", d["pars"])
        if (kind = "loop")
            el["HeightOfVerticalBar"] := NewElementCatalog.LOOP_HEIGHT
        if (kind = "trigger" && d["class"] = NewElementCatalog.MANUAL_TRIGGER && !hasManualTrigger)
            el["DefaultTrigger"] := 1
        return el
    }

    ; The top left corner (flow units, snapped to the grid) of a new element whose centre is at the flow point (fx, fy):
    ; v1 put the element under the mouse (Editor GUI User Input, the menu of the new elements).
    static Origin(fx, fy) => [FlowGeometry.Snap(fx - FlowGeometry.ELEMENT_WIDTH / 2)
        , FlowGeometry.Snap(fy - FlowGeometry.ELEMENT_HEIGHT / 2)]

    ; True when the flow (a Map, the definition of the engine or the draft) has a manual trigger.
    static HasManualTrigger(root) {
        if (!(root is Map) || !(root.Get("allElements", "") is Map))
            return false
        for id, el in root["allElements"] {
            if (el is Map && StrLower(String(el.Get("type", ""))) = "trigger"
                    && StrLower(String(el.Get("class", ""))) = StrLower(NewElementCatalog.MANUAL_TRIGGER))
                return true
        }
        return false
    }

    ; An object whose properties are the parameters (the element code reads params.Name and params.HasProp("Name")).
    static _ParamsOf(pars) {
        o := {}
        for name, value in pars
            o.%name% := value
        return o
    }

    static _Has(arr, value) {
        for item in arr {
            if (item = value)
                return true
        }
        return false
    }

    ; Insertion sort of an Array by cmp(a, b) (negative, zero or positive). The lists are short.
    static _Sort(arr, cmp) {
        loop arr.Length - 1 {
            i := A_Index + 1
            item := arr[i]
            j := i - 1
            while (j >= 1 && cmp(arr[j], item) > 0) {
                arr[j + 1] := arr[j]
                j -= 1
            }
            arr[j + 1] := item
        }
    }
}
