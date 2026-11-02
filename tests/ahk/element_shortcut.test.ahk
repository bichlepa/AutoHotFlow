#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests for src/elements/Default/Triggers/Trigger_Shortcut.ahk (WI-0133, REQ-TRG-240): the path rule, the command
; text, the command line of the shortcut (script, session, data), the request to storage on Enable and Disable, and the
; disarm reasons that remove the shortcut (only disarm and rearm, and only with the option). No file is touched: the
; requests are recorded by a fake context.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Shortcut.ahk

; The parts of the trigger context that the element uses. Request records the call; the answer is given by the test.
class FakeShortcutCtx {
    State := {}
    flowId := "Flow 100"
    elementId := "element0000000002"
    launch := Map("script", "C:\AHF\src\AutoHotFlow.ahk", "session", "main", "data", "C:\AHF\data")
    DisarmReason := ""
    requests := []
    logs := []
    Request(to, msgType, payload, callback, timeoutMs := 5000) {
        this.requests.Push(Map("to", to, "type", msgType, "payload", payload, "callback", callback))
        return this.requests.Length
    }
    Log(level, text) {
        this.logs.Push(level " " text)
    }
}

Case1() {
    ; The path rule: absolute (drive or UNC), one line, extension .lnk.
    Assert.True(Trigger_Shortcut.PathOk("C:\Users\me\Desktop\x.lnk"), "a drive path")
    Assert.True(Trigger_Shortcut.PathOk("\\server\share\x.LNK"), "a UNC path, any case of the extension")
    Assert.True(!Trigger_Shortcut.PathOk("x.lnk"), "relative")
    Assert.True(!Trigger_Shortcut.PathOk("C:\x.txt"), "another extension")
    Assert.True(!Trigger_Shortcut.PathOk("C:\x`n.lnk"), "a line break")
    Assert.Equal(Trigger_Shortcut.Command("Flow 1", "element0000000002"), "Trigger|Flow 1|element0000000002", "the command text")
}

Case2() {
    ; The shortcut: the interpreter, the program script, session, data and the command, quoted; the folder of the script.
    ctx := FakeShortcutCtx()
    s := Trigger_Shortcut.Shortcut(ctx, "C:\Users\me\Desktop\x.lnk")
    Assert.Equal(s["path"], "C:\Users\me\Desktop\x.lnk", "the path")
    Assert.Equal(s["target"], A_AhkPath, "the interpreter of this program")
    Assert.Equal(s["workDir"], "C:\AHF\src", "the folder of the program script")
    Assert.Equal(s["args"], '"C:\AHF\src\AutoHotFlow.ahk" "--session=main" "--data=C:\AHF\data" "--command=Trigger|Flow 100|element0000000002"', "the arguments")
    ; Without a session or data folder those options are left out.
    ctx.launch := Map("script", "C:\AHF\src\AutoHotFlow.ahk", "session", "", "data", "")
    s := Trigger_Shortcut.Shortcut(ctx, "C:\x.lnk")
    Assert.Equal(s["args"], '"C:\AHF\src\AutoHotFlow.ahk" "--command=Trigger|Flow 100|element0000000002"', "no session and no data")
    ; A missing program script is an element error: no shortcut can be made.
    ctx.launch := Map("script", "", "session", "main", "data", "")
    Assert.Throws(() => Trigger_Shortcut.Shortcut(ctx, "C:\x.lnk"), ElementError, "no program script")
}

Case3() {
    ; Enable: a bad path is refused with the v1 text and asks nothing; a good one asks storage for the write.
    ctx := FakeShortcutCtx()
    params := {ShortCutPath: "relative.lnk", RemoveShortcutOnDisabling: 1}
    e := Assert.Throws(() => Trigger_Shortcut.Enable(ctx, params), ElementError, "a relative path is refused")
    Assert.True(InStr(e.Message, "ShortCutPath"), "the message names the parameter")
    Assert.Equal(ctx.requests.Length, 0, "nothing is requested for a bad path")
    params.ShortCutPath := "C:\AHF\data\ok.lnk"
    Trigger_Shortcut.Enable(ctx, params)
    Assert.Equal(ctx.requests.Length, 1, "one request")
    Assert.Equal(ctx.requests[1]["to"], "storage", "to storage")
    Assert.Equal(ctx.requests[1]["type"], "cmd.storage.shortcut.write", "the write request")
    Assert.Equal(ctx.State.path, "C:\AHF\data\ok.lnk", "the path is kept for Disable")
    Assert.True(ctx.State.remove, "the option is kept for Disable")
}

Case4() {
    ; The answer of the write: a failure is an element error (the trigger reports it), a success is logged.
    ctx := FakeShortcutCtx()
    ctx.State.path := "C:\AHF\data\ok.lnk"
    Assert.Throws(() => Trigger_Shortcut._Written(ctx, Map("ok", false, "error", Map("code", "internal", "message", "no folder"))), ElementError, "a failed write")
    Trigger_Shortcut._Written(ctx, Map("ok", true, "action", "created"))
    Assert.True(InStr(ctx.logs[1], "created"), "the success is logged")
}

Case5() {
    ; Disable removes the shortcut only when the user switched the trigger off or changed it (disarm, rearm) and the
    ; option is on. A reset (the engine restarts), a shutdown and a failed Enable keep the file.
    ctx := FakeShortcutCtx()
    ctx.State.path := "C:\AHF\data\ok.lnk"
    ctx.State.remove := true
    for reason in ["reset", "shutdown", "failed"] {
        ctx.DisarmReason := reason
        Trigger_Shortcut.Disable(ctx)
    }
    Assert.Equal(ctx.requests.Length, 0, "reset, shutdown and failed keep the shortcut")
    for reason in ["disarm", "rearm"] {
        ctx.DisarmReason := reason
        Trigger_Shortcut.Disable(ctx)
    }
    Assert.Equal(ctx.requests.Length, 2, "disarm and rearm remove it")
    Assert.Equal(ctx.requests[1]["type"], "cmd.storage.shortcut.remove", "the remove request")
    Assert.Equal(ctx.requests[1]["payload"]["path"], "C:\AHF\data\ok.lnk", "the path of the shortcut")
    ; The option off keeps the shortcut for every reason.
    ctx.requests := []
    ctx.State.remove := false
    ctx.DisarmReason := "disarm"
    Trigger_Shortcut.Disable(ctx)
    Assert.Equal(ctx.requests.Length, 0, "option off keeps the file")
}

Case6() {
    ; Disable of a trigger that never wrote a shortcut (its Enable was refused) asks nothing.
    ctx := FakeShortcutCtx()
    ctx.DisarmReason := "disarm"
    Trigger_Shortcut.Disable(ctx)
    Assert.Equal(ctx.requests.Length, 0, "no path, nothing to remove")
}

TestRun.Case("The path rule and the command text", Case1)
TestRun.Case("The command line of the shortcut: script, session, data, command", Case2)
TestRun.Case("Enable refuses a bad path and asks storage for a good one", Case3)
TestRun.Case("The answer of the write is an error or a log line", Case4)
TestRun.Case("Disable removes the shortcut only on disarm or rearm, with the option", Case5)
TestRun.Case("Disable without a written shortcut asks nothing", Case6)

TestRun.Finish()
