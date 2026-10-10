#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk

; Stack of loop variables per thread (WI-08, ARCHITEKTUR 5.2).
;
; Port of v1 LoopVariable_AddToStack and LoopVariable_RestoreFromStack
; (v1/Source_Execution/Variables/Variables.ahk:174 and :194). Used from
; v1/Source_Execution/Execution Task/Execution Task.ahk:125 (pop when leaving a loop with
; "tail" or "exception") and :144 (push when entering a loop at its "head").
;
; v1 keeps two parallel stacks: visible loop variables and hidden loop variables (variables of an
; outer loop, hidden while an inner loop runs). Push stores copies of both current maps, Pop
; restores the last pair. Push does not clear the current maps (v1 does not either).
;
; The class file name is fixed by the work package (Loops.ahk), the class is LoopStack.
; Variable names are case-insensitive, as in v1 (CaseSense "Off").
class LoopStack {
    __New() {
        this.Visible := LoopStack.NewMap()
        this.Hidden := LoopStack.NewMap()
        this.stackVisible := []
        this.stackHidden := []
    }

    ; Number of pushed levels that have not been popped (v1 "entering a loop at head").
    Depth {
        get {
            return this.stackVisible.Length
        }
    }

    ; Copy of the visible and hidden maps onto the stacks (v1 LoopVariable_AddToStack).
    Push() {
        this.stackVisible.Push(LoopStack.CopyMap(this.Visible))
        this.stackHidden.Push(LoopStack.CopyMap(this.Hidden))
    }

    ; Restores the last pushed pair (v1 LoopVariable_RestoreFromStack).
    ; Popping an empty stack is an error. v1 silently restored "", which hides a broken loop.
    Pop() {
        if (this.stackVisible.Length = 0)
            throw AhfError("LoopStack.Pop: loop stack is empty", ErrCode.INTERNAL)
        this.Visible := this.stackVisible.Pop()
        this.Hidden := this.stackHidden.Pop()
    }

    ; Deep enough copy for thread cloning (v1 newThread copies the loop stacks as well).
    Clone() {
        other := LoopStack()
        other.Visible := LoopStack.CopyMap(this.Visible)
        other.Hidden := LoopStack.CopyMap(this.Hidden)
        for m in this.stackVisible
            other.stackVisible.Push(LoopStack.CopyMap(m))
        for m in this.stackHidden
            other.stackHidden.Push(LoopStack.CopyMap(m))
        return other
    }

    static NewMap() {
        m := Map()
        m.CaseSense := "Off"
        return m
    }

    ; Copies the entries into a new map with the same case rule. Map.Clone() is not used:
    ; its CaseSense handling is not part of the verified behavior.
    static CopyMap(source) {
        m := LoopStack.NewMap()
        for name, value in source
            m[name] := value
        return m
    }
}
