#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\ipc\Peer.ahk

; The second instance: sends cmd.app.command {argv} to the running supervisor and ends
; (doc/PROTOCOL 4.1; v2-phase2-final:v2-phase2-final:work_items/phase2/WI-0007-supervisor.md-supervisor.md). It never creates a hub pipe.
; Exit 0: the running supervisor answered ok. Exit 1: no answer, or the answer was an error.
;
;   SupervisorCommand(pipeName, ["text"]).Start()
class SupervisorCommand {
    static REQUEST_TIMEOUT_MS := 3000
    static CONNECT_BUDGET_MS := 3000
    static EXIT_OK := 0
    static EXIT_FAILED := 1
    static Current := ""

    __New(pipeName, argv) {
        this.argv := argv
        this.peer := Peer("command", pipeName, Map("reconnectTotalMs", SupervisorCommand.CONNECT_BUDGET_MS
            , "helloTimeoutMs", SupervisorCommand.CONNECT_BUDGET_MS))
        this.peer.OnReady := () => this._OnReady()
        this.peer.OnClosed := () => this._OnClosed()
    }

    Start() {
        Persistent()
        SupervisorCommand.Current := this      ; keeps the object alive while its timers run
        this.peer.Connect()
    }

    _OnReady() {
        this.peer.Request("supervisor", "cmd.app.command", Map("argv", this.argv)
            , (res) => this._OnAnswer(res), SupervisorCommand.REQUEST_TIMEOUT_MS)
    }

    _OnAnswer(res) {
        ok := IsObject(res) && res.payload.Get("ok", false) ? true : false
        if (ok) {
            Log.Write("a1", "command", "delivered to the running supervisor")
            ExitApp(SupervisorCommand.EXIT_OK)
        }
        detail := IsObject(res) ? (res.payload.Has("error") ? res.payload["error"]["message"] : res.type) : "no answer"
        Log.Write("a0", "command", "not delivered: " detail)
        ExitApp(SupervisorCommand.EXIT_FAILED)
    }

    _OnClosed() {
        Log.Write("a0", "command", "no running supervisor reachable on this session")
        ExitApp(SupervisorCommand.EXIT_FAILED)
    }
}
