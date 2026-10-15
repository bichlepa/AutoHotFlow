#Requires AutoHotkey v2.0
; Unit test for PipeConnection after a write found the peer gone (F-0031): the frames that the peer wrote before it
; ended are read and delivered first, even when the first Pump after that comes late (a stand-still of the process,
; so WRITE_GONE_MAX_MS has passed long ago), and the connection then ends with peer_closed.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\ipc\PipeListener.ahk
#Include ..\..\src\core\Time.ahk

class Collector {
    frames := []
    reasons := []
    OnFrame(conn, text) {
        this.frames.Push(text)
    }
    OnClose(conn, reason) {
        this.reasons.Push(reason)
    }
}

CheckFramesBeforeTheEndAreReadAfterALateFirstPump() {
    name := "ahf.writegone." A_TickCount
    listener := PipeListener(name)
    client := PipeConnection.Connect(name, 2000)
    server := ""
    loop 100 {
        server := listener.Accept()
        if (IsObject(server))
            break
        DllCall("Sleep", "uint", 10)
    }
    Assert.True(IsObject(server), "the server did not accept the client")
    got := Collector()
    server.OnFrame := ObjBindMethod(got, "OnFrame")
    server.OnClose := ObjBindMethod(got, "OnClose")
    Assert.True(client.SendFrame("last words"), "the client could not queue its frame")
    client.Close()
    ; The write to the gone client fails: only the write side is closed, the unread frame stays readable.
    server.SendFrame("answer")
    Assert.True(server._writeGoneAt > 0, "the write to the gone peer did not fail, the test shows nothing")
    Assert.True(server.IsOpen, "the connection was closed by the failed write")
    ; The process stood still: the first Pump comes WRITE_GONE_MAX_MS after the failed write.
    server._writeGoneAt := Time.NowMs() - 5 * PipeConnection.WRITE_GONE_MAX_MS
    server.Pump()
    listener.Close()
    Assert.Equal(got.frames.Length, 1, "frames delivered")
    Assert.Equal(got.frames[1], "last words")
    Assert.Equal(got.reasons.Length, 1, "close notifications")
    Assert.Equal(got.reasons[1], "peer_closed")
}

TestRun.Init()

TestRun.Case("A frame written before the peer ended is delivered although the first Pump after a failed write is late"
    , CheckFramesBeforeTheEndAreReadAfterALateFirstPump)

TestRun.Finish()
