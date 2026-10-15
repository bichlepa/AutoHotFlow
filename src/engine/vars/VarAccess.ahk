#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Log.ahk
#Include ..\..\expr\ExprResolveError.ahk
#Include VarValues.ahk
#Include VarNames.ahk
#Include VarJson.ahk
#Include BuiltInVars.ahk
#Include EngineVars.ahk

; Access to the variables from one place of execution (WI-0040, doc/EXPRESSION-LANGUAGE.md section 18): the view of
; one element of one thread on the loop, thread, instance, static, global and built-in variables. Port of the v1
; functions Var_Get, Var_Set, Var_GetLocation, Var_Delete, Var_GetType, Var_GetListOf*, Var_replaceVariables
; (v1/Source_Execution/Variables/Variables.ahk) and their *_Common forms (v1/Source_Common/Variables/
; Global variables.ahk), which work without an instance and a thread (editor, manager).
;
; It is also the resolver of the evaluator (Has, Get, Set with a path, doc/EXPRESSION-LANGUAGE.md section 17).
;
; The object holds references to the tables of its owners (EngineVars, Instance, ThreadState); it is made for one
; element run in the engine and never leaves the engine process. Values go in and out as copies.
;
;   store   EngineVars (global and static)
;   inst    an object with the Maps Vars and HiddenVars (Instance), or "" for the common place
;   thread  an object with Vars, HiddenVars and Loops (ThreadState with its LoopStack), or "" for the common place
;   env     Map: flowId, elementId, flowName, elementName, workingDir (built-in variables), optional ahfVersion
;   logFn   logFn(level, text), or "" for the engine log
class VarAccess {
    static SCOPES := ["loop", "thread", "instance", "static", "global"]

    __New(store, inst, thread, env, logFn := "") {
        this.store := store
        this.inst := inst
        this.thread := thread
        this.env := env
        this.common := !IsObject(inst) || !IsObject(thread)
        this.logFn := logFn
    }

    ; ---- element API ------------------------------------------------------------------------------------------

    ; The value of a variable or of a member ("a.b.1"), as a copy; default if it does not exist.
    GetVar(name, default := "", hidden := false) {
        found := this._Find(VarNames.Split(name), hidden)
        if (!IsObject(found))
            return default
        return this._ValueOf(found)
    }

    HasVar(name, hidden := false) => IsObject(this._Find(VarNames.Split(name), hidden)) ? 1 : 0

    ; Where an existing variable is: "loop", "thread", "builtin", "instance", "static", "global", or "" if it
    ; does not exist (v1 Var_GetLocation; the spelling of v1 was "Loop", "Thread", "BuiltIn").
    Location(name, hidden := false) {
        found := this._Find(VarNames.Split(name), hidden)
        return IsObject(found) ? found["loc"] : ""
    }

    ; "object", "normal", or "" if the variable does not exist (v1 Var_GetType).
    VarType(name, hidden := false) {
        found := this._Find(VarNames.Split(name), hidden)
        if (!IsObject(found))
            return ""
        return (this._ValueOf(found) is Map) ? "object" : "normal"
    }

    ; Sets a variable (v1 Var_Set). location: "" or, for an A_ name, "thread" or "loop". The name decides the scope.
    ; Returns 1, or 0 after an f0 log entry with the text of v1 (an empty name, a forbidden character, no
    ; permission, a location thread or loop for a name without A_). As in v1 a name that starts with a digit is
    ; accepted here, and a dot is a forbidden character (members are set through an expression).
    SetVar(name, value, location := "", hidden := false) {
        check := VarNames.Check(name)
        if (check = "Empty") {
            this._Log("f0", "Setting a variable failed. Its name is empty.")
            return 0
        }
        if (check = "ForbiddenCharacter") {
            this._Log("f0", "Setting variable '" name "' failed. It contains forbidden characters.")
            return 0
        }
        dest := VarNames.Destination(name, location, this.common)
        if (dest = VarNames.NO_PERMISSION) {
            this._Log("f0", "Setting variable '" name "' failed. No permission.")
            return 0
        }
        if (dest = VarNames.NOT_A) {
            this._Log("f0", "Setting variable '" name "' failed. It does not start with 'A_'.")
            return 0
        }
        if (hidden && (dest = "global" || dest = "static"))
            throw ElementError("a " dest " variable cannot be hidden ('" name "')")
        this._Table(dest, hidden)[name] := VarValues.Import(value)
        this._Touch(dest, name)
        return 1
    }

    ; Deletes a variable or a member. Returns 1, or 0 if it does not exist or is built-in (v1 Var_Delete).
    DeleteVar(name, hidden := false) {
        found := this._Find(VarNames.Split(name), hidden)
        if (!IsObject(found) || found["loc"] = "builtin")
            return 0
        found["holder"].Delete(found["key"])
        this._Touch(found["loc"], VarNames.Split(name)[1])
        return 1
    }

    ; The names of the visible variables of one scope ("loop", "thread", "instance", "static", "global"), or of all
    ; of them in this order for scope "" (v1 Var_GetListOf*Vars). Hidden and built-in variables are not listed.
    ListVars(scope := "") {
        scopes := (scope = "") ? VarAccess.SCOPES : [StrLower(scope)]
        out := []
        for s in scopes {
            if (!VarAccess._IsScope(s))
                throw ValueError("unknown variable scope '" scope "'")
            if (this.common && (s = "loop" || s = "thread" || s = "instance"))
                continue
            for name in this._Table(s, false)
                out.Push(name)
        }
        return out
    }

    ; Replaces %name% in a text by the value of the variable (v1 Var_replaceVariables, ported step by step,
    ; including its odd cases: the first pair of percent signs is taken, a name is anything between them, and each
    ; step replaces the first occurrence). A variable that does not exist gives the empty text and an f0 log entry;
    ; its name is added to missing (an Array) if given. An object gives the empty text, or with convertObjects its
    ; JSON text (indented by 2 spaces; on one line in the common place, as v1).
    Replace(text, convertObjects := false, missing := "") {
        out := text
        rest := text
        loop {
            if (!RegExMatch(rest, "SU).*%(.+)%.*", &m))
                break
            name := m[1]
            found := this._Find(VarNames.Split(name), false)
            if (IsObject(found)) {
                value := this._ValueOf(found, false)
            } else {
                value := ""
                this._Log("f0", "Retrieving variable '" name "' failed. It does not exist"
                    . (this.common ? " or is neither global nor static" : ""))
                if (IsObject(missing))
                    missing.Push(name)
            }
            if (IsObject(value))
                value := convertObjects ? VarJson.Stringify(value, this.common ? 0 : 2) : ""
            out := StrReplace(out, "%" name "%", String(value), false, , 1)
            rest := StrReplace(rest, "%" name "%", "_", false, , 1)
        }
        return out
    }

    ; A copy of the visible instance variables, name -> value (v1 x_ExportAllInstanceVars, WI-0042). Empty in common.
    ExportInstance() {
        out := VarValues.NewMap()
        if (this.common)
            return out
        for name, value in this.inst.Vars
            out[name] := VarValues.Copy(value)
        return out
    }

    ; Sets every entry of a Map (name -> value) as a visible instance variable (v1 x_ImportInstanceVars, which set the
    ; instance variables directly, whatever the prefix of the name). An empty name or one with a forbidden character
    ; is skipped with an f0 entry. Throws ElementError in common (there are no instance variables).
    ImportInstance(vars) {
        if (this.common)
            throw ElementError("instance variables are not available here")
        if (!(vars is Map))
            throw ElementError("ImportInstanceVars needs a Map of name -> value")
        for name, value in vars {
            check := VarNames.Check(String(name))
            if (check = "Empty" || check = "ForbiddenCharacter") {
                this._Log("f0", "Setting variable '" name "' failed. It contains forbidden characters.")
                continue
            }
            this.inst.Vars[String(name)] := VarValues.Import(value)
        }
    }

    ; ---- resolver of the evaluator ----------------------------------------------------------------------------

    Has(path) => IsObject(this._Find(path, false)) ? 1 : 0

    Get(path) {
        found := this._Find(path, false)
        if (!IsObject(found))
            throw Error("VarAccess.Get called for a path that does not exist: " VarAccess._PathText(path, path.Length))
        return this._ValueOf(found)
    }

    ; An assignment in an expression. The root name decides the scope, as for SetVar without a location: an A_ name
    ; cannot be set from an expression (no permission, as in v1). A member of a variable that does not exist yet
    ; creates it as an object, and so do the members on the way.
    Set(path, value) {
        root := path[1]
        dest := VarNames.Destination(root, "", this.common)
        if (dest = VarNames.NO_PERMISSION)
            throw ExprResolveError("Setting variable '" root "' failed. No permission.")
        try {
            stored := VarValues.Import(value)
        } catch ValueError as e {
            throw ExprResolveError(e.Message)
        }
        ; Refuse before anything is created: the loop below makes the missing objects on the way, and one that a
        ; refused assignment leaves behind would exist in memory but never be written (nothing marks it).
        loop path.Length - 1 {
            if (IsObject(path[A_Index + 1]))
                throw ExprResolveError("an object cannot be the key of a member")
        }
        holder := this._Table(dest, false)
        key := root
        loop path.Length - 1 {
            if (!holder.Has(key))
                holder[key] := VarValues.NewMap()
            next := holder[key]
            if (!(next is Map))
                throw ExprResolveError("'" VarAccess._PathText(path, A_Index) "' is not an object; its member '"
                    . VarAccess._PartText(path[A_Index + 1]) "' cannot be set")
            part := path[A_Index + 1]
            if (IsObject(part))
                throw ExprResolveError("an object cannot be the key of a member")
            k := VarValues.FindKey(next, part)
            holder := next
            key := IsObject(k) ? VarValues.NormKey(part) : k
        }
        holder[key] := stored
        this._Touch(dest, root)
    }

    ; ---- internals --------------------------------------------------------------------------------------------

    ; The place of an existing variable or member: Map("loc", location, "holder", Map, "key", key), or "" if it does
    ; not exist. A built-in variable has no holder and no members.
    _Find(path, hidden) {
        if (path.Length = 0)
            return ""
        root := path[1]
        if (IsObject(root))
            return ""
        loc := this._RootLocation(root, hidden)
        if (loc = "")
            return ""
        if (loc = "builtin")
            return (path.Length = 1) ? Map("loc", "builtin", "name", root) : ""
        holder := this._Table(loc, hidden)
        key := root
        loop path.Length - 1 {
            value := holder[key]
            part := path[A_Index + 1]
            if (!(value is Map) || IsObject(part))
                return ""
            k := VarValues.FindKey(value, part)
            if (IsObject(k))
                return ""
            holder := value
            key := k
        }
        return Map("loc", loc, "holder", holder, "key", key)
    }

    ; v1 Var_GetLocation and Var_GetLocation_Common for one name.
    _RootLocation(name, hidden) {
        kind := VarNames.Kind(name)
        if (hidden) {
            if (this.common)
                return ""
            if (kind = "a") {
                if (this.thread.Loops.Hidden.Has(name))
                    return "loop"
                if (this.thread.HiddenVars.Has(name))
                    return "thread"
                return ""
            }
            return this.inst.HiddenVars.Has(name) ? "instance" : ""
        }
        switch kind {
            case "a":
                if (!this.common) {
                    if (this.thread.Loops.Visible.Has(name))
                        return "loop"
                    if (this.thread.Vars.Has(name))
                        return "thread"
                }
                return BuiltInVars.Has(name) ? "builtin" : ""
            case "global":
                return this.store.Global.Has(name) ? "global" : ""
            case "static":
                return this.store.Static(this.env.Get("flowId", "")).Has(name) ? "static" : ""
        }
        if (this.common)
            return ""
        return this.inst.Vars.Has(name) ? "instance" : ""
    }

    ; A global or static variable has changed: VarWriter writes it (WI-0041). name is the root name.
    _Touch(location, name) {
        if (location = "global") {
            this.store.Touch("global", "", name)
        } else if (location = "static") {
            flowId := this.env.Get("flowId", "")
            if (flowId != "")
                this.store.Touch("static", flowId, name)
        }
    }

    ; The Map of a scope.
    _Table(location, hidden) {
        switch location {
            case "loop":
                return hidden ? this.thread.Loops.Hidden : this.thread.Loops.Visible
            case "thread":
                return hidden ? this.thread.HiddenVars : this.thread.Vars
            case "instance":
                return hidden ? this.inst.HiddenVars : this.inst.Vars
            case "global":
                return this.store.Global
            case "static":
                return this.store.Static(this.env.Get("flowId", ""))
        }
        throw ValueError("unknown variable scope '" location "'")
    }

    ; The value at a place found by _Find; a copy for an object unless copy is false (read only use).
    _ValueOf(found, copy := true) {
        if (found["loc"] = "builtin")
            return BuiltInVars.Get(found["name"], this.env)
        value := found["holder"][found["key"]]
        return copy ? VarValues.Copy(value) : value
    }

    _Log(level, text) {
        fn := this.logFn
        if (IsObject(fn)) {
            fn(level, text)
            return
        }
        Log.Write(level, "engine", text, this.env.Get("flowId", ""))
    }

    static _IsScope(s) {
        for name in VarAccess.SCOPES {
            if (name = s)
                return true
        }
        return false
    }

    static _PartText(part) => IsObject(part) ? "<" Type(part) ">" : String(part)

    ; The first n parts of a path, joined with dots.
    static _PathText(path, n) {
        s := ""
        loop n
            s .= (A_Index = 1 ? "" : ".") VarAccess._PartText(path[A_Index])
        return s
    }
}
