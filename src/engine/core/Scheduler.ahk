#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ThreadState.ahk
#Include Instance.ahk
#Include FlowDefinition.ahk

; Choice of the next connection after an element finished (WI-08, ARCHITEKTUR 5.2).
;
; Port of the finished branch of executionTask in
; v1/Source_Execution/Execution Task/Execution Task.ahk, lines 98 to 170:
;   - a connection matches if its ConnectionType equals the result (case-insensitive, line 119),
;     or if the element is a loop and fromPart equals the result (line 119, "type = loop").
;   - for a loop that is left with "tail" or "exception", the loop stack is restored (lines 123 to
;     126). This happens for each matching connection, as in v1.
;   - the first match moves the thread, every further match gets a clone (lines 128 to 133).
;   - when the next element is a loop entered at "head", the loop stack is pushed (lines 142 to 145).
;   - no match: the thread is removed (line 166). A result "exception" without a match is
;     reported as unhandled (lines 156 to 162), the caller logs f0.
;
; Pure logic: no IPC, no files, no GUI. Thread IDs come from the caller (newId is a function
; without arguments that returns a new unique thread ID).
class Scheduler {
    ; Connections that match the thread's result, as connection Maps, in FromConnections order.
    ; Does not change anything. Empty array if none match.
    static ResolveNext(flow, thread, result) {
        kind := flow.ElementKind(thread.ElementId)
        matches := []
        for connId in flow.FromConnections(thread.ElementId) {
            conn := flow.Connection(connId)
            if (Scheduler.Matches(kind, result, conn))
                matches.Push(conn)
        }
        return matches
    }

    ; One matching connection for a result. v1 line 119.
    static Matches(kind, result, conn) {
        if (StrLower(String(conn["ConnectionType"])) = StrLower(result))
            return true
        if (kind = "loop" && conn.Has("fromPart") && StrLower(String(conn["fromPart"])) = StrLower(result))
            return true
        return false
    }

    ; Moves a finished thread on. Changes instance and thread (see the header).
    ; Returns a Map:
    ;   "outcome"   : "next" (threads are ready), "removed" (no match), "not_finished" (nothing done)
    ;   "unhandled" : true if outcome is "removed" and the result is "exception"
    ;   "threadIds" : IDs of the threads that are ready now (the first is thread.Id)
    static Advance(instance, flow, thread, newId) {
        if (thread.State != "finished")
            return Scheduler.Outcome("not_finished", false, [])

        result := thread.Result
        kind := flow.ElementKind(thread.ElementId)
        matches := Scheduler.ResolveNext(flow, thread, result)

        if (matches.Length = 0) {
            unhandled := (StrLower(result) = "exception")
            instance.ReleaseThread(thread.Id, "no matching connection")
            return Scheduler.Outcome("removed", unhandled, [])
        }

        leavesLoop := (kind = "loop" && (StrLower(result) = "tail" || StrLower(result) = "exception"))
        ids := []
        first := true
        for conn in matches {
            if (leavesLoop)
                thread.Loops.Pop()

            if (first) {
                target := thread
                target.TryTransition("ready", "next element")
            } else {
                target := thread.Clone(newId.Call())
                instance.AddThread(target)
            }
            target.ElementId := String(conn["to"])
            target.EntryPoint := conn.Has("toPart") ? String(conn["toPart"]) : ""
            if (flow.ElementKind(target.ElementId) = "loop" && StrLower(target.EntryPoint) = "head")
                target.Loops.Push()

            ids.Push(target.Id)
            first := false
        }
        return Scheduler.Outcome("next", false, ids)
    }

    static Outcome(outcome, unhandled, threadIds) {
        return Map("outcome", outcome, "unhandled", unhandled, "threadIds", threadIds)
    }
}
