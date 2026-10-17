#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Json.ahk

; The order of the flow list (WI-0071, E0067): the categories in their order and, per category, the flow IDs in theirs.
; A pure model: no file, no storage, no flow table. The engine gives it the members of every flow (flow ID and category)
; and calls Reconcile after each change, so the category of a flow stays the one of its flow file. The order holds only
; the sequence. "" is the uncategorized group: it is always listed last and cannot be renamed, created or removed.
;
; Reconcile: a flow that is not in the order (a new flow, a file copied in by hand, a moved flow) is appended to the end of
; its category; a flow ID that no flow has is dropped; a category without flows stays (empty categories survive).
class FlowOrder {
    static FORMAT_VERSION := 1
    static UNCATEGORIZED := ""

    __New() {
        this._names := [FlowOrder.UNCATEGORIZED]   ; category names in order; the uncategorized group is last
        this._flows := Map()                       ; category name -> Array of flow IDs in order
        this._flows.CaseSense := "On"
        this._flows[FlowOrder.UNCATEGORIZED] := []
    }

    ; --- reading -----------------------------------------------------------------------------------

    ; The category names in order (a copy), the uncategorized group last.
    Names() => this._names.Clone()

    ; True when the category exists (the uncategorized group always does).
    Has(name) => this._flows.Has(name)

    ; The flow IDs of one category in order (a copy); an empty Array for an unknown category.
    FlowsOf(name) => this._flows.Has(name) ? this._flows[name].Clone() : []

    ; The whole order as Array of Map(name, flows), in order: the snapshot, the event and the file.
    Entries() {
        out := []
        for name in this._names
            out.Push(Map("name", name, "flows", this._flows[name].Clone()))
        return out
    }

    ; A text that changes whenever the order changes (the engine compares it, it is not a file).
    Signature() => Json.Stringify(this.Entries())

    ; The text of Categories.json.
    Text() => Json.Stringify(Map("formatVersion", FlowOrder.FORMAT_VERSION, "categories", this.Entries()), 2)

    ; Reads the text of Categories.json into an Array of entries (Map(name, flows)). Throws AhfError for a file that is not
    ; in this format; the engine then keeps the file as broken and builds the order again.
    static Parse(text) {
        try {
            root := Json.Parse(text)
        } catch as e {
            throw AhfError("not valid JSON: " e.Message, ErrCode.BAD_JSON)
        }
        if (!(root is Map))
            throw AhfError("the root is not an object", ErrCode.BAD_PAYLOAD)
        if (!root.Has("formatVersion") || root["formatVersion"] != FlowOrder.FORMAT_VERSION)
            throw AhfError("unknown format version", ErrCode.BAD_PAYLOAD)
        list := root.Get("categories", [])
        if (!(list is Array))
            throw AhfError("'categories' is not a list", ErrCode.BAD_PAYLOAD)
        entries := []
        seen := Map()
        seen.CaseSense := "On"
        for item in list {
            if (!(item is Map))
                throw AhfError("a category is not an object", ErrCode.BAD_PAYLOAD)
            rawName := item.Get("name", "")
            if (IsObject(rawName))
                throw AhfError("a category name is not a text", ErrCode.BAD_PAYLOAD)
            name := String(rawName)
            if (seen.Has(name))
                throw AhfError("category '" name "' is listed twice", ErrCode.BAD_PAYLOAD)
            seen[name] := true
            rawFlows := item.Get("flows", [])
            if (!(rawFlows is Array))
                throw AhfError("the flows of category '" name "' are not a list", ErrCode.BAD_PAYLOAD)
            ids := []
            for id in rawFlows {
                if (IsObject(id))
                    throw AhfError("the flows of category '" name "' have an object in their list", ErrCode.BAD_PAYLOAD)
                ids.Push(String(id))
            }
            entries.Push(Map("name", name, "flows", ids))
        }
        return entries
    }

    ; --- building ----------------------------------------------------------------------------------

    ; An independent copy of the order (a command changes the copy and keeps it only when every check passed).
    Clone() {
        copy := FlowOrder()
        copy.Load(this.Entries())
        return copy
    }

    ; Replaces the order with the entries of a file (Parse). The uncategorized group is taken from its entry, wherever it
    ; stands in the file, and placed last.
    Load(entries) {
        this._names := []
        this._flows := Map()
        this._flows.CaseSense := "On"
        uncategorized := []
        for entry in entries {
            name := entry["name"]
            if (name == FlowOrder.UNCATEGORIZED) {
                uncategorized := entry["flows"]
                continue
            }
            this._names.Push(name)
            this._flows[name] := entry["flows"]
        }
        this._names.Push(FlowOrder.UNCATEGORIZED)
        this._flows[FlowOrder.UNCATEGORIZED] := uncategorized
    }

    ; Brings the order in line with the flows. members: Array of Map(flowId, category), in the order to append them.
    Reconcile(members) {
        category := Map()
        category.CaseSense := "On"
        for member in members
            category[member["flowId"]] := member["category"]
        placed := Map()
        placed.CaseSense := "On"
        for name in this._names {
            kept := []
            for id in this._flows[name] {
                if (!placed.Has(id) && category.Has(id) && category[id] == name) {
                    kept.Push(id)
                    placed[id] := true
                }
            }
            this._flows[name] := kept
        }
        for member in members {
            id := member["flowId"]
            if (placed.Has(id))
                continue
            placed[id] := true
            this._Group(member["category"]).Push(id)
        }
    }

    ; Sorts the categories and the flows of each category by name, ignoring case, once (cmd.category.sort). nameOf maps
    ; a flow ID to its name. The uncategorized group stays last.
    SortAlphabetically(nameOf) {
        named := []
        for name in this._names
            if (name != FlowOrder.UNCATEGORIZED)
                named.Push(name)
        FlowOrder._Sort(named, (a, b) => FlowOrder._Compare(a, b))
        named.Push(FlowOrder.UNCATEGORIZED)
        this._names := named
        for name in this._names {
            ids := this._flows[name]
            FlowOrder._Sort(ids, (a, b) => FlowOrder._CompareIds(a, b, nameOf))
        }
    }

    ; --- changes -----------------------------------------------------------------------------------

    ; Appends a new, empty category before the uncategorized group. The caller has checked the name.
    Create(name) {
        if (this._flows.Has(name) || name == FlowOrder.UNCATEGORIZED)
            throw AhfError("category '" name "' exists already", ErrCode.BAD_PAYLOAD)
        this._names.InsertAt(this._names.Length, name)
        this._flows[name] := []
    }

    ; Renames a category: it keeps its place and its flows.
    Rename(oldName, newName) {
        if (oldName == FlowOrder.UNCATEGORIZED || !this._flows.Has(oldName))
            throw AhfError("category '" oldName "' cannot be renamed", ErrCode.BAD_PAYLOAD)
        if (oldName == newName)
            return
        if (this._flows.Has(newName))
            throw AhfError("category '" newName "' exists already", ErrCode.BAD_PAYLOAD)
        for index, name in this._names {
            if (name == oldName) {
                this._names[index] := newName
                break
            }
        }
        this._flows[newName] := this._flows[oldName]
        this._flows.Delete(oldName)
    }

    ; Appends the flows of one category to the end of another (the flows move first when a category is deleted).
    MoveAll(fromName, toName) {
        if (!this._flows.Has(fromName) || !this._flows.Has(toName))
            throw AhfError("unknown category", ErrCode.BAD_PAYLOAD)
        for id in this._flows[fromName]
            this._flows[toName].Push(id)
        this._flows[fromName] := []
    }

    ; Removes an empty category (the uncategorized group cannot be removed).
    Remove(name) {
        if (name == FlowOrder.UNCATEGORIZED || !this._flows.Has(name))
            throw AhfError("category '" name "' cannot be deleted", ErrCode.BAD_PAYLOAD)
        if (this._flows[name].Length > 0)
            throw AhfError("category '" name "' still has flows", ErrCode.INTERNAL)
        for index, existing in this._names {
            if (existing == name) {
                this._names.RemoveAt(index)
                break
            }
        }
        this._flows.Delete(name)
    }

    ; The new order of the categories: every category exactly once; the uncategorized group may be given last.
    SetCategories(newNames) {
        given := []
        for name in newNames {
            if (IsObject(name))
                throw AhfError("the categories must be texts", ErrCode.BAD_PAYLOAD)
            given.Push(String(name))
        }
        if (given.Length && given[given.Length] == FlowOrder.UNCATEGORIZED)
            given.Pop()
        if (given.Length != this._names.Length - 1)
            throw AhfError("the categories must list every category once", ErrCode.BAD_PAYLOAD)
        seen := Map()
        seen.CaseSense := "On"
        for name in given {
            if (name == FlowOrder.UNCATEGORIZED || !this._flows.Has(name) || seen.Has(name))
                throw AhfError("the categories must list every category once", ErrCode.BAD_PAYLOAD)
            seen[name] := true
        }
        given.Push(FlowOrder.UNCATEGORIZED)
        this._names := given
    }

    ; The new order of the flows of one category: a permutation of its members.
    SetFlows(name, newIds) {
        if (!this._flows.Has(name))
            throw AhfError("unknown category '" name "'", ErrCode.BAD_PAYLOAD)
        current := this._flows[name]
        if (newIds.Length != current.Length)
            throw AhfError("the flows of '" name "' must be the flows of that category, each once", ErrCode.BAD_PAYLOAD)
        members := Map()
        members.CaseSense := "On"
        for id in current
            members[id] := true
        given := Map()
        given.CaseSense := "On"
        out := []
        for id in newIds {
            if (IsObject(id) || !members.Has(id) || given.Has(id))
                throw AhfError("the flows of '" name "' must be the flows of that category, each once", ErrCode.BAD_PAYLOAD)
            given[id] := true
            out.Push(String(id))
        }
        this._flows[name] := out
    }

    ; --- helpers -----------------------------------------------------------------------------------

    ; The list of a category, created before the uncategorized group when it is new.
    _Group(name) {
        if (!this._flows.Has(name)) {
            this._names.InsertAt(this._names.Length, name)
            this._flows[name] := []
        }
        return this._flows[name]
    }

    ; Insertion sort in place (an Array has no Sort method in AHK v2; the lists are short). cmp(a, b) < 0 when a comes first.
    static _Sort(items, cmp) {
        loop items.Length - 1 {
            i := A_Index + 1
            j := i
            while (j > 1 && cmp(items[j], items[j - 1]) < 0) {
                tmp := items[j]
                items[j] := items[j - 1]
                items[j - 1] := tmp
                j -= 1
            }
        }
        return items
    }

    ; Flows by name, then by ID (a total order).
    static _CompareIds(a, b, nameOf) {
        c := FlowOrder._Compare(nameOf.Get(a, a), nameOf.Get(b, b))
        return c ? c : StrCompare(a, b)
    }

    ; Alphabetical order without case (an equal text in another case sorts by its code, so the order is total).
    static _Compare(a, b) {
        c := StrCompare(StrLower(a), StrLower(b))
        return c ? c : StrCompare(a, b)
    }
}
