#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include NewElementCatalog.ahk

; Adding a new element in the editor (WI-0099, REQ-EDT-050, PROTOCOL 4.11): the pointer places the box of a new element of a
; kind (EditorPointer, the fields at the top left of the canvas); this class asks for the class from the list (the seam
; chooser: the window shows the tree dialog, the headless driver answers with the test's choice) and then adds the element
; as one patch (element.add, one undo step) and selects it. Cancel at any point adds nothing: the element exists only
; after the choice.
;
; The class list shows the classes of the user's level (userLevel, set by the role from the settings). The settings of the
; class (EditorSettings, WI-0106) open between the choice and the patch: OK adds the element with the values of the settings,
; Cancel adds nothing. Without settings (settings is "") the element is added at once with the defaults.
class EditorAdd {
    __New(model) {
        this.model := model
        this.userLevel := "Beginner"   ; the setting userLevel (REQ-USE-010), set by the role
        this.chooser := ""             ; the seam: chooser.Choose(kind, groups, done); done(classId) once, "" for a cancel
        this.busy := false             ; a class list is open: another placement waits
        this.settings := ""            ; EditorSettings: the settings of the chosen class (WI-0106)
    }

    ; An element of kind is placed with its top left corner at the flow position (x, y): the class list opens. Returns false
    ; when nothing opens (a list is open, no seam, or the flow is not loaded yet).
    Placed(kind, x, y) => this.Add(kind, x, y)

    ; The same with more operations in the same patch (WI-0100, a connection to the new element): connect is "" or a function
    ; (newId) => Array of operations that go into the patch after element.add. done(ok) is called once when the answer is
    ; known: ok is false for a cancel and for a patch that was refused (then nothing is added).
    Add(kind, x, y, connect := "", done := "") {
        if (this.busy || !IsObject(this.chooser) || !(this.model.draft.root is Map))
            return false
        groups := NewElementCatalog.Groups(kind, this.userLevel)
        this.busy := true
        this.chooser.Choose(kind, groups, (classId) => this._Chosen(kind, x, y, classId, connect, done))
        return true
    }

    ; The answer of the list: classId is the qualified ID of the class, or "" for a cancel (nothing is added). Then the
    ; settings of the class open (done(ok) follows their OK or Cancel) or, without settings, the element is added.
    _Chosen(kind, x, y, classId, connect, done) {
        this.busy := false
        draft := this.model.draft
        if (classId = "" || !(draft.root is Map)) {
            if (IsObject(done))
                done(false)
            return false
        }
        if (IsObject(this.settings))
            return this.settings.OpenNew(kind, classId, x, y, connect, done)
        return this.Create(kind, classId, x, y, connect, done)
    }

    ; Adds the element of the class to the flow as one patch (one undo step) and selects it. form: "" for the defaults of the
    ; class, or the values of the settings (a Map "pars", "name", "standardName"). done(ok) is called once, as in Add.
    Create(kind, classId, x, y, connect, done, form := "") {
        draft := this.model.draft
        if (!(draft.root is Map)) {
            if (IsObject(done))
                done(false)
            return false
        }
        id := draft.NextId("element")
        el := NewElementCatalog.NewElement(kind, classId, x, y, id, NewElementCatalog.HasManualTrigger(draft.root))
        if (IsObject(form)) {
            el["pars"] := form["pars"]
            el["name"] := form["name"]
            el["StandardName"] := form["standardName"] ? 1 : 0
        }
        ops := [Map("op", "element.add", "element", el)]
        if (IsObject(connect)) {
            for op in connect(id)
                ops.Push(op)
        }
        res := draft.Commit(ops, true)
        if (!res["ok"]) {
            if (IsObject(connect))
                this.model.Notice("The connection was not made")
            if (IsObject(done))
                done(false)
            return false
        }
        draft.SetSelection([id], "one")
        this.model.SelectionChanged()
        if (IsObject(done))
            done(true)
        return true
    }
}
