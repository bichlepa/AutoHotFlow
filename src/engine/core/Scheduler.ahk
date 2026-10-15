#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ThreadState.ahk
#Include Instance.ahk
#Include FlowDefinition.ahk

; Choice of the next connection after an element finished (WI-0008, ARCHITECTURE 5.2).
;
; Port of the finished branch of executionTask in
; v1/Source_Execution/Execution Task/Execution Task.ahk, lines 98 to 170:
;   - a connection matches if its ConnectionType equals the result (case-insensitive, line 119),
;     or if the element is a loop and fromPart equals the result (line 119, "type = loop").
;   - for a loop that is left with "tail" or "exception", the loop stack is restored (lines 123 to
;     126). v1 does this once per matching connection; v2 does it once per finished loop element
;     (a second pop would throw on the stack of depth 1, WI-0021, MIGRATION M-0019).
;   - the first match moves the thread, every further match gets a clone (lines 128 to 133).
;   - when the next element is a loop entered at "head", the loop stack is pushed (lines 142 to 145).
;     v1 pushes onto the origin thread (OneThreadID); v2 pushes onto the thread that enters the loop
;     (M-0019). Clones are made before any push, so only the thread that enters the loop gets it.
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
        ; The loop is left once, however many connections match: pop the stack before any clone is made, so
        ; every branch starts from the restored state. v1 popped once per connection (M-0014, M-0019).
        if (leavesLoop && thread.Loops.Depth = 0) {
            ; Broken loop (for example entered at "tail"): Pop would throw out of the finish callback and
            ; leave the thread "finished" for ever, so the instance would never end (F-0012). End the thread
            ; as an unhandled exception instead; the caller logs f0 with this message.
            thread.Message := "loop stack is empty when leaving loop " thread.ElementId " with '" result "'"
            instance.ReleaseThread(thread.Id, "loop stack is empty")
            return Scheduler.Outcome("removed", true, [])
        }
        if (leavesLoop)
            thread.Loops.Pop()
        thread.TryTransition("ready", "next element")

        ; Clones are made before any thread is changed, so a clone never inherits the loop push of another
        ; branch. The moved thread is the first one, the clones follow in connection order.
        targets := [thread]
        loop matches.Length - 1 {
            clone := thread.Clone(newId.Call())
            instance.AddThread(clone)
            targets.Push(clone)
        }

        ids := []
        for i, conn in matches {
            target := targets[i]
            target.ElementId := String(conn["to"])
            target.EntryPoint := conn.Has("toPart") ? String(conn["toPart"]) : ""
            if (flow.ElementKind(target.ElementId) = "loop" && StrLower(target.EntryPoint) = "head")
                target.Loops.Push()
            ids.Push(target.Id)
        }
        return Scheduler.Outcome("next", false, ids)
    }

    static Outcome(outcome, unhandled, threadIds) {
        return Map("outcome", outcome, "unhandled", unhandled, "threadIds", threadIds)
    }
}
