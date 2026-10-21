#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ElementClipboard.ahk
#Include WinClipboard.ahk

; Delete, cut, copy and paste of the elements of the editor (WI-0101, REQ-EDT-080, E0091): the keys Del, Ctrl+X, Ctrl+C and
; Ctrl+V, and the trash button of the selection. The content is built from the draft (ElementClipboard) and goes to the
; clipboard (store: WinClipboard, the Windows clipboard); a paste reads it there and makes one patch with one undo step.
;
; Delete asks first (one question for the selection, the seam ask: ask.Confirm("selection", [count], done)); the answer
; "no" changes nothing. Cut copies and then deletes without a question (v1), and deletes only when the copy went in.
;
; The clipboard is never waited for (rule 3 of AGENTS.md): Write and Read answer at once, and a busy clipboard is tried
; again on the model's timer, RETRY_LIMIT times in all, then the status bar says "Clipboard busy". Every outcome is a text
; in the status bar (EditorModel.Notice), the answer to a caller is done(ok) once.
;
; A paste goes under the pointer when the caller gives the canvas pixel `at` (the window passes the mouse when it is over
; the canvas, the test its x and y); without a pixel it goes to the middle of the view (v1). The pasted elements are
; selected. A clipboard without our format, or a text that is not ours, does nothing and says so.
class EditorTransfer {
    static RETRY_MS := 50
    static RETRY_LIMIT := 5

    __New(model) {
        this.model := model
        this.store := WinClipboard       ; the clipboard: Write(text) and Read() (a test may give its own)
        this.ask := ""                   ; the seam of the question of Delete: ask.Confirm(kind, args, done)
    }

    ; Ctrl+C: the selected elements and the connections between them go to the clipboard. done(ok).
    Copy(done := "") => this._CopyIds(this.model.SelectionIds(), done)

    ; Ctrl+X: copy, then delete the selection without a question. Nothing is deleted when the copy did not go in.
    Cut(done := "") {
        ids := this.model.SelectionIds()
        this._CopyIds(ids, (ok) => (ok ? this._Remove(ids, done) : EditorTransfer._Done(done, false)))
    }

    ; Del and the trash button: one question for the selection, then one patch that removes it. done(ok) after the answer.
    Delete(done := "") {
        ids := this.model.SelectionIds()
        if (ids.Length = 0) {
            this.model.Notice("No elements selected")
            EditorTransfer._Done(done, false)
            return
        }
        if (!IsObject(this.ask)) {
            EditorTransfer._Done(done, false)
            return
        }
        this.ask.Confirm("selection", [ids.Length], (yes) => (yes ? this._Remove(ids, done)
            : EditorTransfer._Done(done, false)))
    }

    ; Ctrl+V: the content of the clipboard is pasted at the canvas pixel at (or in the middle of the view). done(ok).
    Paste(at := "", done := "") => this._Read(at, 1, done)

    ; --- copy ----------------------------------------------------------------------------------------------------------------

    _CopyIds(ids, done) {
        root := this.model.draft.root
        if (!(root is Map)) {
            EditorTransfer._Done(done, false)
            return
        }
        count := 0
        for id in ids {
            if (root["allElements"].Has(id))
                count += 1
        }
        if (count = 0) {
            this.model.Notice("No elements selected")
            EditorTransfer._Done(done, false)
            return
        }
        this._Write(ElementClipboard.Copied(root, ids), count, 1, done)
    }

    _Write(text, count, attempt, done) {
        res := this.store.Write(text)
        if (res = "ok") {
            this.model.Notice("Saved %1% elements to clipboard", count)
            EditorTransfer._Done(done, true)
            return
        }
        if (res = "busy" && attempt < EditorTransfer.RETRY_LIMIT) {
            this.model.Schedule(EditorTransfer.RETRY_MS, () => this._Write(text, count, attempt + 1, done))
            return
        }
        this.model.Notice(res = "busy" ? "Clipboard busy" : "Clipboard failed")
        EditorTransfer._Done(done, false)
    }

    ; --- delete --------------------------------------------------------------------------------------------------------------

    ; One patch that removes the IDs that the flow still has (with their connections). done(ok).
    _Remove(ids, done) {
        root := this.model.draft.root
        if (!(root is Map)) {
            EditorTransfer._Done(done, false)
            return
        }
        ops := ElementClipboard.DeleteOps(root, ids)
        if (ops.Length = 0) {
            EditorTransfer._Done(done, false)
            return
        }
        res := this.model.draft.Commit(ops, true)
        if (!res["ok"]) {
            this.model.Notice("Delete refused")
            EditorTransfer._Done(done, false)
            return
        }
        EditorTransfer._Done(done, true)
    }

    ; --- paste ---------------------------------------------------------------------------------------------------------------

    _Read(at, attempt, done) {
        res := this.store.Read()
        state := res["state"]
        if (state = "busy") {
            if (attempt < EditorTransfer.RETRY_LIMIT) {
                this.model.Schedule(EditorTransfer.RETRY_MS, () => this._Read(at, attempt + 1, done))
                return
            }
            this.model.Notice("Clipboard busy")
            EditorTransfer._Done(done, false)
            return
        }
        if (state = "failed") {
            this.model.Notice("Clipboard failed")
            EditorTransfer._Done(done, false)
            return
        }
        data := (state = "ok") ? ElementClipboard.Parse(res["text"]) : ""
        if (data = "") {
            this.model.Notice("No elements found in clipboard")
            EditorTransfer._Done(done, false)
            return
        }
        this._Paste(data, at, done)
    }

    _Paste(data, at, done) {
        draft := this.model.draft
        if (!(draft.root is Map)) {
            EditorTransfer._Done(done, false)
            return
        }
        view := this.model.view
        pt := IsObject(at) ? view.ToFlow(at[1], at[2]) : view.ToFlow(view.Width / 2, view.Height / 2)
        plan := ElementClipboard.Plan(draft.root, data, pt[1], pt[2])
        if (plan["ops"].Length = 0) {
            this.model.Notice("No elements found in clipboard")
            EditorTransfer._Done(done, false)
            return
        }
        res := draft.Commit(plan["ops"], true)
        if (!res["ok"]) {
            this.model.Notice("Paste refused")
            EditorTransfer._Done(done, false)
            return
        }
        draft.SetSelection(plan["ids"], "one")
        this.model.SelectionChanged()
        EditorTransfer._Done(done, true)
    }

    static _Done(done, ok) {
        if (IsObject(done))
            done(ok)
    }
}
