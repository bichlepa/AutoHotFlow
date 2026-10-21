#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include NewElementCatalog.ahk

; Adding a new element in the editor (WI-0099, REQ-EDT-050, PROTOCOL 4.11): the pointer places the box of a new element of a
; kind (EditorPointer, the fields at the top left of the canvas); this class asks for the class from the list (the seam
; chooser: the window shows the tree dialog, the headless driver answers with the test's choice) and then adds the element
; as one patch (element.add, one undo step) and selects it. Cancel at any point adds nothing: the element exists only
; after the choice.
;
; The class list shows the classes of the user's level (userLevel, set by the role from the settings). The settings dialog
; of the class (S0007, WI-0106) opens between the choice and the patch; until then the element is added at once.
class EditorAdd {
    __New(model) {
        this.model := model
        this.userLevel := "Beginner"   ; the setting userLevel (REQ-USE-010), set by the role
        this.chooser := ""             ; the seam: chooser.Choose(kind, groups, done); done(classId) once, "" for a cancel
        this.busy := false             ; a class list is open: another placement waits
    }

    ; An element of kind is placed with its top left corner at the flow position (x, y): the class list opens. Returns false
    ; when nothing opens (a list is open, no seam, or the flow is not loaded yet).
    Placed(kind, x, y) {
        if (this.busy || !IsObject(this.chooser) || !(this.model.draft.root is Map))
            return false
        groups := NewElementCatalog.Groups(kind, this.userLevel)
        this.busy := true
        this.chooser.Choose(kind, groups, (classId) => this._Chosen(kind, x, y, classId))
        return true
    }

    ; The answer of the list: classId is the qualified ID of the class, or "" for a cancel (nothing is added).
    _Chosen(kind, x, y, classId) {
        this.busy := false
        draft := this.model.draft
        if (classId = "" || !(draft.root is Map))
            return false
        id := draft.NextId("element")
        el := NewElementCatalog.NewElement(kind, classId, x, y, id, NewElementCatalog.HasManualTrigger(draft.root))
        res := draft.Commit([Map("op", "element.add", "element", el)], true)
        if (!res["ok"])
            return false
        draft.SetSelection([id], "one")
        this.model.SelectionChanged()
        return true
    }
}
