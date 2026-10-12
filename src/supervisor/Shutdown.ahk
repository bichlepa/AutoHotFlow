#Requires AutoHotkey v2.0
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include Children.ahk

; Ending the session in two phases (doc/ARCHITECTURE 6.3, WI-07).
;
; Phase 1, prepare (cancellable, no deadline): cmd.app.prepareExit goes to every connected manager and
; editor. Any answer with cancel:true stops the exit (evt.app.exitCancelled, nothing is stopped). A
; client that disconnects counts as "no cancel". The phase has no hard deadline, but each request ends:
; without an answer after PREPARE_LIMIT_MS (10 minutes) the UI counts as "no cancel" (see Hub.Request).
;
; Phase 2, shutdown (hard deadline): sys.shutdown {reason, deadlineMs} to the children in rank order
; (UI first, storage last). A group is done when each child has sent sys.bye or has ended. At the
; deadline the remaining children are terminated (exit code FORCED). Connected clients that are not
; children get sys.shutdown too, but the supervisor does not wait for them.
;
; Result: onDone(exitCode) is called once: 0 = every child ended by itself, 5 = at least one was terminated.
;
;   shutdown := Shutdown(children, hub)
;   shutdown.onDone := (code) => ...
;   shutdown.BeginExit("user", 5000, "py")   ; false if an exit is already running
;   shutdown.Tick(now)                        ; from the supervisor's timer
class Shutdown {
    static EXIT_CLEAN := 0
    static EXIT_FORCED := 5
    static KILL_WAIT_MS := 1500
    ; Upper bound for the answers to cmd.app.prepareExit (10 minutes). It is not a hard deadline of the exit
    ; (ARCHITECTURE 6.3 has none for phase 1): a UI may take long to decide, but a request must still end.
    ; When it passes, the UI counts as "no cancel" and the exit goes on. Not sent to the UIs, not a protocol value.
    static PREPARE_LIMIT_MS := 600000

    onDone := ""

    __New(children, hub) {
        this.children := children
        this.hub := hub
        this.prepareLimitMs := Shutdown.PREPARE_LIMIT_MS     ; the supervisor may lower it for tests (--prepare-limit)
        this.phase := "idle"          ; idle | prepare | shutdown | kill | done
        this.gen := 0                 ; identifies the answers of the current prepare round
        this.pending := 0
        this.reason := ""
        this.deadlineMs := 0
        this.deadlineAt := 0
        this.killDeadline := 0
        this.forced := false
        this.groups := []
        this.groupIndex := 0
    }

    ; Starts the exit. Returns false when an exit is already running (or finished).
    BeginExit(reason, deadlineMs, by) {
        if (this.phase != "idle")
            return false
        this.gen += 1
        this.phase := "prepare"
        this.reason := reason
        this.deadlineMs := deadlineMs
        Log.Write("a1", "shutdown", "exit requested by " by " (" reason ", deadline " deadlineMs " ms)")
        targets := this.hub.LinkNamesWithBase(["manager", "editor"])
        this.pending := targets.Length
        if (targets.Length = 0) {
            this._StartShutdown()
            return true
        }
        for name in targets
            this.hub.Request(name, "cmd.app.prepareExit", Map(), this._PrepareCallback(this.gen), this.prepareLimitMs)
        return true
    }

    Tick(now) {
        if (this.phase = "shutdown") {
            if (this.children.AllGone()) {
                this._Done(Shutdown.EXIT_CLEAN)
                return
            }
            if (now >= this.deadlineAt) {
                this._Force(now)
                return
            }
            while (this.groupIndex <= this.groups.Length && this.children.GroupDone(this.groups[this.groupIndex])) {
                this.groupIndex += 1
                this._SendGroup(now)
            }
        } else if (this.phase = "kill") {
            ; Whether the exit is forced is decided in _Done by Children.AnyKilled (F-33, WI-33): a process that ended by itself
            ; at the deadline and is only judged now was not terminated, so it must not make the exit code 5.
            if (this.children.AllGone() || now >= this.killDeadline)
                this._Done(Shutdown.EXIT_CLEAN)
        }
    }

    ; A child said sys.hello (Supervisor._OnHello, after Children.OnHello). A child that was still starting when its group
    ; got sys.shutdown (the warm worker, an editor, the debug window) could not be reached then (F-41, WI-34): without
    ; this its group would wait for a bye that never comes, the later groups (storage last) would never get sys.shutdown,
    ; and all of them would be terminated at the deadline. So in phase 2 a child whose group has had its turn (or is
    ; having it now) gets sys.shutdown at its hello, with the rest of the deadline. A child of a later group waits for the
    ; turn of its group (the order of the ranks applies). A child in no group (its process was being created when the
    ; groups were made) gets it at once: nobody waits for it in the order, but the shutdown waits for its end (AllGone).
    ; In the prepare phase nothing is needed (the groups are made later and include it), in the kill phase neither
    ; (KillAlive has ended every process that was alive).
    OnHello(name, now := "") {
        if (this.phase != "shutdown" || !this.children.Has(name) || this.children.IsGone(name))
            return
        if (this._GroupOf(name) > this.groupIndex)
            return
        if (now = "")
            now := Time.NowMs()
        remaining := Max(1, Integer(this.deadlineAt - now))
        Log.Write("a1", "shutdown", name " connected during the shutdown, sys.shutdown sent (" remaining " ms left)")
        this.children.SendShutdown(name, this.reason, remaining)
    }

    ; Index of the group of name in this.groups, 0 when it is in none.
    _GroupOf(name) {
        for i, group in this.groups
            for n in group
                if (n = name)
                    return i
        return 0
    }

    ; The supervisor stood still for ms (Stall, WI-33, F-16): the deadline of the shutdown and the wait after the hard end
    ; move by that time, so the children keep their rest of the time. (The answer limit of phase 1 is a Hub request and
    ; moves with the hub.)
    Shift(ms) {
        if (this.deadlineAt > 0)
            this.deadlineAt += ms
        if (this.killDeadline > 0)
            this.killDeadline += ms
    }

    ; --- phase 1 -----------------------------------------------------------------------------

    _PrepareCallback(gen) => (res) => this._OnPrepare(gen, res)

    ; res is the answer of a UI, "" when the UI disconnected before it answered, or the synthetic timeout
    ; answer (ok false): neither of those cancels the exit.
    _OnPrepare(gen, res) {
        if (gen != this.gen || this.phase != "prepare")
            return
        if (IsObject(res) && res.payload.Get("cancel", false)) {
            this.phase := "idle"
            Log.Write("a1", "shutdown", "exit cancelled by " res.from)
            this.hub.Publish("process", "evt.app.exitCancelled", Map("by", res.from))
            return
        }
        this.pending -= 1
        if (this.pending <= 0)
            this._StartShutdown()
    }

    ; --- phase 2 -----------------------------------------------------------------------------

    _StartShutdown() {
        now := Time.NowMs()
        this.phase := "shutdown"
        this.deadlineAt := now + this.deadlineMs
        this.children.BeginShutdown()
        for name in this.hub.LinkNames() {
            if (!this.children.Has(name))
                this.hub.Send(name, "sys.shutdown", Map("reason", this.reason, "deadlineMs", this.deadlineMs))
        }
        this.groups := this.children.ShutdownGroups()
        this.groupIndex := 1
        this._SendGroup(now)
    }

    _SendGroup(now) {
        if (this.groupIndex > this.groups.Length)
            return
        remaining := Max(1, Integer(this.deadlineAt - now))
        for name in this.groups[this.groupIndex]
            this.children.SendShutdown(name, this.reason, remaining)
    }

    _Force(now) {
        this.forced := true
        this.phase := "kill"
        this.killDeadline := now + Shutdown.KILL_WAIT_MS
        Log.Write("a0", "shutdown", "deadline reached, terminating the remaining processes")
        this.children.KillAlive()
    }

    _Done(code) {
        ; A child that was terminated (at the deadline, or earlier after a hang) makes the exit forced.
        if (this.children.AnyKilled())
            code := Shutdown.EXIT_FORCED
        this.phase := "done"
        Log.Write("a1", "shutdown", "finished with exit code " code)
        fn := this.onDone
        if (IsObject(fn))
            fn(code)
    }
}
