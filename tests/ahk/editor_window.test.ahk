#Requires AutoHotkey v2.0
; Unit tests for src/editor/EditorWindow.ahk (WI-0088): the title, the back buffer that follows the client size, the frame
; that is drawn only when the scene changed, WM_ERASEBKGND and the messages of other windows, and the close. The window is
; created but never shown (no window appears on the desktop, so this is not a gui test); the messages are called by hand.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\core\Json.ahk
#Include ..\..\src\editor\EditorWindow.ahk
#Include ..\..\src\editor\EditorModel.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk

; The role the window talks to: a model, the renderer, the log, the close.
class FakeRole {
    __New(model) {
        this.model := model
        this.flowId := "flow"
        this.renderer := ""
        this.logs := []
        this.closed := false
    }

    _Renderer() {
        if (!IsObject(this.renderer)) {
            Gdip.Startup()
            this.renderer := Renderer()
        }
        return this.renderer
    }

    _Log(level, source, text) {
        this.logs.Push(text)
    }

    _OnWindowClose() {
        this.closed := true
    }
}

; The peer of a model that is never asked: the definition is set directly.
class QuietPeer {
    Subscribe(topic) {
    }

    Request(to, type, payload, callback, timeoutMs := 5000) {
    }
}

FlowDef() {
    return Json.Parse('{"name": "Demo", "flowSettings": {"zoomFactor": "1.000000", "Offsetx": "0", "Offsety": "0"},'
        . '"allElements": {'
        . '"T": {"ID": "T", "type": "trigger", "class": "Trigger_Manual", "package": "Default", "x": 0, "y": 0, "DefaultTrigger": "1"},'
        . '"A": {"ID": "A", "type": "action", "class": "action_Sleep", "package": "Default", "x": 0, "y": 300}},'
        . '"allConnections": {"c1": {"ID": "c1", "from": "T", "to": "A", "ConnectionType": "normal"}}}')
}

; A window of a loaded model (the definition is set, the states follow by Restate).
Made() {
    model := EditorModel(QuietPeer(), "flow")
    model.definition := FlowDef()
    model.name := "Demo"
    model.rev := 1
    model.view := EditorView(1, 0, 0, 96, 0, 0)
    model._Rebuild()
    role := FakeRole(model)
    win := EditorWindow(role)
    return Map("win", win, "role", role, "model", model)
}

; lParam of WM_SIZE: the client width in the low word, the height in the high word.
SizeParam(w, h) => w | (h << 16)

TitleFollowsTheFlowAndTheName() {
    t := Made()
    win := t["win"]
    Assert.Equal(win.win.Gui.Title, "AutoHotFlow " Lang("Editor") " - Demo", "the title has the name of the flow")
    t["model"].name := "Renamed"
    win.Refresh()
    Assert.Equal(win.win.Gui.Title, "AutoHotFlow " Lang("Editor") " - Renamed", "a rename changes the title")
    win.Close()
}

BackBufferFollowsTheClientSize() {
    t := Made()
    win := t["win"]
    win._OnSize(SizeParam(640, 480), win.hwnd)
    Assert.Equal(win.canvas.width, 640, "back buffer width")
    Assert.Equal(win.canvas.height, 480, "back buffer height")
    Assert.Equal(t["model"].view.Width, 640, "the view takes the size")
    win._OnSize(SizeParam(640, 480), win.hwnd)
    Assert.Equal(win.canvas.width, 640, "the same size: the same back buffer is kept")
    win._OnSize(SizeParam(0, 0), win.hwnd)
    Assert.Equal(win.canvas.width, 640, "a minimized window (0 x 0) keeps the back buffer")
    win.Close()
}

FrameOnlyWhenTheSceneChanged() {
    t := Made()
    win := t["win"]
    win._OnSize(SizeParam(400, 300), win.hwnd)
    win._Frame()
    Assert.Equal(win.frames, 1, "the first scene is drawn")
    win._Frame()
    Assert.Equal(win.frames, 1, "the same scene version: no frame")
    t["model"].SetCanvas(400, 300, 96)
    t["model"]._Restate()
    win.Request()
    win._Frame()
    Assert.Equal(win.frames, 2, "a new scene version: a frame")
    win.Close()
}

RequestsAreCoalesced() {
    t := Made()
    win := t["win"]
    win._OnSize(SizeParam(400, 300), win.hwnd)
    win.Request()
    win.Request()
    win.Request()
    Assert.True(win.scheduled, "one frame is waiting")
    win._Frame()
    Assert.True(!win.scheduled, "the frame has run")
    win.Close()
}

PaintAndEraseOnlyForOurWindow() {
    t := Made()
    win := t["win"]
    win._OnSize(SizeParam(400, 300), win.hwnd)
    Assert.Equal(win._OnErase(win.hwnd), 1, "no background erase for the window (no flicker)")
    Assert.Equal(win._OnErase(0), "", "another window is left to Windows")
    Assert.Equal(win._OnPaint(0), "", "a paint of another window is not ours")
    win.Close()
}

CloseEndsOnceAndStopsTheFrames() {
    t := Made()
    win := t["win"]
    win._OnSize(SizeParam(400, 300), win.hwnd)
    win.Close()
    Assert.True(win.closed, "the window is closed")
    Assert.True(win.canvas == "", "the back buffer is freed")
    win.Request()
    Assert.True(!win.scheduled, "no frame after the close")
    win.Close()
    Assert.True(win.closed, "a second close does nothing")
}

Raised() {
    t := Made()
    win := t["win"]
    win.Close()
    Assert.True(!win.Visible, "a closed window is not visible")
}

TestRun.Init()

TestRun.Case("Editor window: the title has the flow name and follows a rename", TitleFollowsTheFlowAndTheName)
TestRun.Case("Editor window: the back buffer follows the client size, a minimized window keeps it", BackBufferFollowsTheClientSize)
TestRun.Case("Editor window: a frame is drawn only when the scene changed", FrameOnlyWhenTheSceneChanged)
TestRun.Case("Editor window: frame requests are coalesced into one timer", RequestsAreCoalesced)
TestRun.Case("Editor window: no erase of the background, other windows are left alone", PaintAndEraseOnlyForOurWindow)
TestRun.Case("Editor window: the close frees the back buffer and stops the frames", CloseEndsOnceAndStopsTheFrames)
TestRun.Case("Editor window: a closed window is not visible", Raised)

TestRun.Finish()
