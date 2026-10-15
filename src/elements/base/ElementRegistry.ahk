#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include AhfElement.ahk

; Registry of element classes, keyed by the qualified ID "<package>.<class>" (E0045, doc/ELEMENT-API-V2.md section 2),
; e.g. "Default.Action_Sleep". Each element package is an AutoHotkey class whose body includes the element files, so
; the type name of an element class is its qualified ID. The generated block of a package
; (src/elements/<package>/_includes_<role>.ahk, tools/gen_element_includes.py) registers the package and its classes.
;
; Lookup is case-insensitive: v1 writes both "trigger_manual" and "Trigger_Manual", and "default" as the package.
; A flow element names its package and its class separately; a missing or empty package is DEFAULT_PACKAGE.
class ElementRegistry {
    static DEFAULT_PACKAGE := "Default"
    static classes := Map()          ; qualified ID -> class
    static packages := Map()         ; package name -> version ("" if the package came only with its classes)

    ; Runs once when the class is loaded. The key case must be set before the first insert.
    static __New() {
        this.classes.CaseSense := "Off"
        this.packages.CaseSense := "Off"
    }

    ; Qualified ID of an element class ("Default.Action_Sleep"). The class name cannot be read from cls.Name, because
    ; element classes define a static Name() method that hides it. The ID is the type name of an instance.
    static IdOf(cls) => Type(cls())

    ; The qualified ID of a class of a package, as a flow element names them ("package", "class"). A missing or empty
    ; package means DEFAULT_PACKAGE (E0045).
    static QualifiedId(package, classId) => ((package = "") ? ElementRegistry.DEFAULT_PACKAGE : package) "." classId

    ; The package part of a qualified ID ("" if there is none).
    static PackageOf(qualifiedId) {
        pos := InStr(qualifiedId, ".")
        return pos ? SubStr(qualifiedId, 1, pos - 1) : ""
    }

    ; The class part of a qualified ID (the whole text if there is no package part).
    static ClassOf(qualifiedId) {
        pos := InStr(qualifiedId, ".")
        return pos ? SubStr(qualifiedId, pos + 1) : qualifiedId
    }

    ; Registers a package and its version (the description of the package). Registering it again with the same
    ; version does nothing; with another version it throws AhfError.
    static RegisterPackage(name, version) {
        if (name = "" || InStr(name, "."))
            throw AhfError("ElementRegistry.RegisterPackage: invalid package name '" name "'", ErrCode.BAD_ARGS)
        old := this.packages.Get(name, "")
        if (old != "" && old != version)
            throw AhfError("ElementRegistry.RegisterPackage: package '" name "' is registered with version " old
                . ", not " version, ErrCode.CONFLICT)
        this.packages[name] := version
    }

    ; Registers an element class of a package. Throws AhfError for a non-element, a class that is not in a package (its
    ; type name is not "<package>.<class>"), an invalid Mode or a duplicate ID. A package that was not registered with
    ; RegisterPackage is added without version.
    static Register(cls) {
        if (Type(cls) != "Class" || !HasBase(cls, AhfElement))
            throw AhfError("ElementRegistry.Register: not an element class", ErrCode.BAD_ARGS)
        id := ElementRegistry.IdOf(cls)
        parts := StrSplit(id, ".")
        if (parts.Length != 2 || parts[1] = "" || parts[2] = "")
            throw AhfError("ElementRegistry.Register: " id " is not a class of a package (<package>.<class>, E0045)"
                , ErrCode.BAD_ARGS)
        mode := cls.Mode
        if (mode != "inline" && mode != "worker" && mode != "trigger")
            throw AhfError("ElementRegistry.Register: " id " has invalid Mode '" mode "'", ErrCode.BAD_ARGS)
        if (this.classes.Has(id))
            throw AhfError("ElementRegistry.Register: duplicate class id '" id "'", ErrCode.CONFLICT)
        if (!this.packages.Has(parts[1]))
            this.packages[parts[1]] := ""
        this.classes[id] := cls
    }

    ; Returns the class for a qualified ID (any case), or "" if unknown.
    static Get(qualifiedId) => this.classes.Get(qualifiedId, "")

    ; Returns the class of a flow element (its "package" and "class"), or "" if unknown.
    static Lookup(package, classId) => this.Get(ElementRegistry.QualifiedId(package, classId))

    ; Mode of a registered class ("inline", "worker", "trigger"), or "" if unknown.
    static ModeOf(qualifiedId) {
        cls := this.Get(qualifiedId)
        return IsObject(cls) ? cls.Mode : ""
    }

    ; True if the package is known in this process (registered, or one of its classes is).
    static HasPackage(name) => this.packages.Has(name)

    ; Version of a registered package ("" if unknown or registered without version).
    static PackageVersion(name) => this.packages.Get(name, "")

    ; The text for an element whose class is not in the registry: the package is not installed (not known in this
    ; process), or it has no such class.
    static MissingText(qualifiedId) {
        package := ElementRegistry.PackageOf(qualifiedId)
        if (package != "" && !this.HasPackage(package))
            return "element class '" qualifiedId "' is not available: package '" package "' is not installed"
        return "unknown element class '" qualifiedId "'"
    }

    ; All registered classes as an Array, sorted by qualified ID (Map order).
    static All() {
        out := []
        for id, cls in this.classes
            out.Push(cls)
        return out
    }
}
