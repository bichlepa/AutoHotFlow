#Requires AutoHotkey v2.0
#Include ..\..\..\src\expr\ExprResolveError.ahk

; A simple resolver for the evaluator tests (the real one comes with WI-0040): one table of variables, names ignore
; case, a path walks into Map values. Setting a member creates the Maps on the way. A variable whose name starts
; with "ro_" is read-only (Set throws ExprResolveError). Parts of a path are compared as text.
class ExprTestResolver {
    vars := ""
    ; Every call as text, in order: "has a.b", "get a.b", "set a.b".
    calls := []

    __New(initial := "") {
        this.vars := ExprTestResolver.NewMap()
        if (initial != "") {
            for name, value in initial
                this.vars[name] := value
        }
    }

    static NewMap() {
        m := Map()
        m.CaseSense := "Off"
        return m
    }

    static Text(path) {
        s := ""
        for part in path
            s .= (A_Index = 1 ? "" : ".") part
        return s
    }

    Has(path) {
        this.calls.Push("has " ExprTestResolver.Text(path))
        return this._Walk(path) ? 1 : 0
    }

    Get(path) {
        this.calls.Push("get " ExprTestResolver.Text(path))
        holder := this._Walk(path)
        if (!holder)
            throw Error("Get called for a path that does not exist: " ExprTestResolver.Text(path))
        return holder[String(path[path.Length])]
    }

    Set(path, value) {
        this.calls.Push("set " ExprTestResolver.Text(path))
        if (SubStr(path[1], 1, 3) = "ro_")
            throw ExprResolveError("variable '" path[1] "' is read-only")
        holder := this.vars
        loop path.Length - 1 {
            key := String(path[A_Index])
            if (!holder.Has(key))
                holder[key] := ExprTestResolver.NewMap()
            holder := holder[key]
            if (!(holder is Map))
                throw ExprResolveError("'" key "' has no members")
        }
        holder[String(path[path.Length])] := value
    }

    ; The Map that holds the last part of the path, or 0 if the path does not exist.
    _Walk(path) {
        holder := this.vars
        loop path.Length - 1 {
            key := String(path[A_Index])
            if (!holder.Has(key))
                return 0
            holder := holder[key]
            if (!(holder is Map))
                return 0
        }
        return holder.Has(String(path[path.Length])) ? holder : 0
    }
}
