#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include AhfElement.ahk

; Registry of element classes, keyed by class id (the v1 class id, e.g. "Action_Sleep").
; Lookup is case-insensitive: v1 writes both "trigger_manual" and "Trigger_Manual".
; Each element file ends with ElementRegistry.Register(<class>).
class ElementRegistry {
    static classes := Map()

    ; Runs once when the class is loaded. The key case must be set before the first insert.
    static __New() {
        this.classes.CaseSense := "Off"
    }

    ; Class id of an element class. The class name cannot be read from cls.Name, because
    ; element classes define a static Name() method that hides it. The id is the type name of an instance.
    static IdOf(cls) => Type(cls())

    ; Registers an element class. Throws AhfError for a non-element, an invalid Mode or a duplicate id.
    static Register(cls) {
        if (Type(cls) != "Class" || !HasBase(cls, AhfElement))
            throw AhfError("ElementRegistry.Register: not an element class", ErrCode.BAD_ARGS)
        id := ElementRegistry.IdOf(cls)
        mode := cls.Mode
        if (mode != "inline" && mode != "worker" && mode != "trigger")
            throw AhfError("ElementRegistry.Register: " id " has invalid Mode '" mode "'", ErrCode.BAD_ARGS)
        if (this.classes.Has(id))
            throw AhfError("ElementRegistry.Register: duplicate class id '" id "'", ErrCode.CONFLICT)
        this.classes[id] := cls
    }

    ; Returns the class for an id (any case), or "" if unknown.
    static Get(classId) => this.classes.Get(classId, "")

    ; Mode of a registered class ("inline", "worker", "trigger"), or "" if unknown.
    static ModeOf(classId) {
        cls := this.Get(classId)
        return IsObject(cls) ? cls.Mode : ""
    }

    ; All registered classes as an Array, sorted by class id (Map order).
    static All() {
        out := []
        for id, cls in this.classes
            out.Push(cls)
        return out
    }
}
