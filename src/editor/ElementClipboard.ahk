#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\FlowPatch.ahk
#Include FlowGeometry.ahk
#Include NewElementCatalog.ahk

; The content of the editor's clipboard and the patches that cut, copy, paste and delete make (WI-0101, REQ-EDT-080, E0091).
; Pure functions, no window and no clipboard: the Windows clipboard is EditorTransfer's and WinClipboard's job.
;
; The text in the clipboard is JSON {formatVersion, elements, connections}: elements is a list of element definitions and
; connections a list of connection definitions, both as they stand in the flow. formatVersion is 1. The text goes into a
; clipboard format of AutoHotFlow only (WinClipboard), never as plain text: a text copied from elsewhere is not an element
; (E0091).
;
; Copied(root, selection): the selected elements and the connections whose both ends are selected elements (v1). A
; connection that is selected alone is not copied: it has no ends in the copy. Sorted by ID, so the text is the same for
; the same selection.
; Parse(text): the content, or "" when the text is not one of ours (wrong JSON, another formatVersion, a missing list).
; Plan(root, data, px, py): the operations of a paste into root (one patch). The new IDs are the next free ones of the flow
; (ElementIDCounter on, as the editor does for a new element). The first element of the copy that lies furthest top left
; (its anchor) is put with its centre at the flow point (px, py), snapped to the grid; the others keep their distance to it
; (v1 loadFromClipboard). A pasted manual trigger is not the default when the flow has one; when it has none, the first
; manual trigger of the copy that had the default gets it, else the first manual trigger (v1). The class name and every
; other field stay as they are: an unknown class is kept (the engine handles it, E0092).
; DeleteOps(root, selection): the operations that remove the selected elements with their connections and the selected
; connections, as one patch (connections first, then the elements).
class ElementClipboard {
    static VERSION := 1

    ; The JSON text of the selection (selection: the IDs of the selected elements and connections, an Array).
    static Copied(root, selection) {
        chosen := Map()
        for id in selection
            chosen[id] := true
        elements := []
        for id in ElementClipboard._Sorted(root["allElements"]) {
            if (chosen.Has(id))
                elements.Push(root["allElements"][id])
        }
        connections := []
        for id in ElementClipboard._Sorted(root["allConnections"]) {
            c := root["allConnections"][id]
            if (chosen.Has(String(c.Get("from", ""))) && chosen.Has(String(c.Get("to", ""))))
                connections.Push(c)
        }
        content := Map("formatVersion", ElementClipboard.VERSION, "elements", elements, "connections", connections)
        return Json.Stringify(content)
    }

    ; The content of a clipboard text, as a Map (elements, connections), or "" when the text is not ours.
    static Parse(text) {
        try {
            data := Json.Parse(text)
        } catch {
            return ""
        }
        if (!(data is Map) || data.Get("formatVersion", 0) != ElementClipboard.VERSION)
            return ""
        if (!(data.Get("elements", "") is Array) || !(data.Get("connections", "") is Array))
            return ""
        for el in data["elements"] {
            if (!(el is Map) || !el.Has("ID") || IsObject(el["ID"]) || !el.Has("x") || !el.Has("y")
                    || !IsNumber(el["x"]) || !IsNumber(el["y"]))
                return ""
        }
        for c in data["connections"] {
            if (!(c is Map) || !c.Has("ID") || IsObject(c["ID"]) || !c.Has("from") || !c.Has("to")
                    || IsObject(c["from"]) || IsObject(c["to"]))
                return ""
        }
        return Map("elements", data["elements"], "connections", data["connections"])
    }

    ; The operations of a paste into root, and the IDs of what they add: Map("ops", Array, "ids", Array). ops is empty when
    ; the copy has no element. px, py: the flow point the anchor element is centred on.
    static Plan(root, data, px, py) {
        ops := []
        ids := []
        if (data["elements"].Length = 0)
            return Map("ops", ops, "ids", ids)
        state := Map("n", ElementClipboard._CounterOf(root))
        used := Map()
        anchor := ElementClipboard._Anchor(data["elements"])
        offX := FlowGeometry.Snap(px - (anchor["x"] + 0) - FlowGeometry.ELEMENT_WIDTH / 2)
        offY := FlowGeometry.Snap(py - (anchor["y"] + 0) - FlowGeometry.ELEMENT_HEIGHT / 2)
        hasManual := NewElementCatalog.HasManualTrigger(root)
        chosen := hasManual ? "" : ElementClipboard._ChosenDefault(data["elements"])
        idMap := Map()
        for el in ElementClipboard._SortedList(data["elements"]) {
            newId := ElementClipboard._NewId(root, "element", state, used)
            idMap[String(el["ID"])] := newId
            copy := FlowPatch._Copy(el)
            copy["ID"] := newId
            copy["x"] := FlowGeometry.Snap((el["x"] + 0) + offX)
            copy["y"] := FlowGeometry.Snap((el["y"] + 0) + offY)
            if (FlowPatch._IsManualMap(copy)) {
                if (copy.Has(FlowPatch.DEFAULT_KEY))
                    copy.Delete(FlowPatch.DEFAULT_KEY)
                if (!hasManual && chosen = String(el["ID"]))
                    copy[FlowPatch.DEFAULT_KEY] := Json.True
            }
            ops.Push(Map("op", "element.add", "element", copy))
            ids.Push(newId)
        }
        for c in ElementClipboard._SortedList(data["connections"]) {
            from := String(c["from"])
            to := String(c["to"])
            if (!idMap.Has(from) || !idMap.Has(to))
                continue                  ; an end outside the copy: the connection is not copied
            newId := ElementClipboard._NewId(root, "connection", state, used)
            copy := FlowPatch._Copy(c)
            copy["ID"] := newId
            copy["from"] := idMap[from]
            copy["to"] := idMap[to]
            ops.Push(Map("op", "connection.add", "connection", copy))
            ids.Push(newId)
        }
        return Map("ops", ops, "ids", ids)
    }

    ; The operations that remove the selected elements with their connections and the selected connections (one patch).
    static DeleteOps(root, selection) {
        ops := []
        removedEls := Map()
        for id in selection {
            if (root["allElements"].Has(id))
                removedEls[id] := true
        }
        for id in ElementClipboard._Sorted(root["allConnections"]) {
            c := root["allConnections"][id]
            if (ElementClipboard._Chosen(selection, id) || removedEls.Has(String(c.Get("from", "")))
                    || removedEls.Has(String(c.Get("to", ""))))
                ops.Push(Map("op", "connection.remove", "id", id))
        }
        for id in ElementClipboard._Sorted(removedEls)
            ops.Push(Map("op", "element.remove", "id", id))
        return ops
    }

    ; --- helpers ----------------------------------------------------------------------------------------------------------

    ; The element that lies furthest top left (the smallest x, then y), the anchor of a paste.
    static _Anchor(elements) {
        best := elements[1]
        for el in elements {
            if ((el["x"] + 0) < (best["x"] + 0) || ((el["x"] + 0) = (best["x"] + 0) && (el["y"] + 0) < (best["y"] + 0)))
                best := el
        }
        return best
    }

    ; The manual trigger of the copy that gets the default: the first one flagged DefaultTrigger, else the first one. ""
    ; when the copy has no manual trigger.
    static _ChosenDefault(elements) {
        first := ""
        for el in ElementClipboard._SortedList(elements) {
            if (!FlowPatch._IsManualMap(el))
                continue
            if (FlowPatch._Truthy(el.Get(FlowPatch.DEFAULT_KEY, "")))
                return String(el["ID"])
            if (first = "")
                first := String(el["ID"])
        }
        return first
    }

    ; The next free ID of prefix ("element" or "connection"): the counter goes on from state["n"], and an ID that the flow or
    ; this paste uses is skipped.
    static _NewId(root, prefix, state, used) {
        loop {
            id := prefix Format("{:010}", state["n"])
            state["n"] += 1
            if (!used.Has(id) && !root["allElements"].Has(id) && !root["allConnections"].Has(id)) {
                used[id] := true
                return id
            }
        }
    }

    static _CounterOf(root) {
        cur := root.Get(FlowPatch.COUNTER_KEY, 1)
        return IsInteger(cur) ? Integer(cur) : 1
    }

    static _Chosen(selection, id) {
        for item in selection {
            if (item = id)
                return true
        }
        return false
    }

    ; The keys of a map, sorted (the IDs are digits after a prefix: a plain string order is the order of their numbers).
    static _Sorted(m) {
        keys := []
        for k in m
            keys.Push(k)
        return ElementClipboard._SortedList(keys)
    }

    ; An Array sorted by the ID of each item (a list of definitions) or of its text (a list of keys).
    static _SortedList(items) {
        sorted := []
        for item in items
            sorted.Push(item)
        n := sorted.Length
        loop n - 1 {
            i := A_Index + 1
            value := sorted[i]
            j := i - 1
            while (j >= 1 && StrCompare(ElementClipboard._KeyOf(sorted[j]), ElementClipboard._KeyOf(value), "Off") > 0) {
                sorted[j + 1] := sorted[j]
                j -= 1
            }
            sorted[j + 1] := value
        }
        return sorted
    }

    static _KeyOf(item) => (item is Map) ? String(item.Get("ID", "")) : String(item)
}
