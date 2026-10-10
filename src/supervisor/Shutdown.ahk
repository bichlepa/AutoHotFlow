#Requires AutoHotkey v2.0
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include Children.ahk

; Ending the session in two phases (doc/ARCHITEKTUR 6.3, WI-07).
;
; Phase 1, prepare (cancellable, no deadline): cmd.app.prepareExit goes to every connected manager and
; editor. Any answer with cancel:true stops the exit (evt.app.exitCancelled, nothing is stopped). A
; client that disconnects counts as "no cancel". Without an answer the phase waits: the user decides.
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

    onDone := ""

    __New(children, hub) {
        this.children := children
        this.hub := hub
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
            this.hub.Request(name, "cmd.app.prepareExit", Map(), this._PrepareCallback(this.gen))
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
            if (this.children.AllGone() || now >= this.killDeadline)
                this._Done(Shutdown.EXIT_FORCED)
        }
    }

    ; --- phase 1 -----------------------------------------------------------------------------

    _PrepareCallback(gen) => (res) => this._OnPrepare(gen, res)

    ; res is the answer of a UI, or "" when the UI disconnected before it answered.
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
        ; A child that was terminated earlier (after a hang) also makes the exit forced.
        if (this.children.AnyKilled())
            code := Shutdown.EXIT_FORCED
        this.phase := "done"
        Log.Write("a1", "shutdown", "finished with exit code " code)
        fn := this.onDone
        if (IsObject(fn))
            fn(code)
    }
}
