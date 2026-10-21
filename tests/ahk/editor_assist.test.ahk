#Requires AutoHotkey v2.0
; Unit tests of the assistants of the element settings (WI-0110, src/editor/assist/*, EditorSettings.StartAssistant): the
; colour formats and the map of the keys (AssistantValues), the window assistant (WindowAssistant), the mouse tracker
; (MouseAssistant) and the colour dialog (ColorAssistant, replaced by a function), each with a fake source: no real window
; is read, no real mouse is moved, no real dialog is shown. The windows are built WITHOUT showing them (show false).
; The mouse tracker registers its Ctrl hotkeys while it is open: they are switched off again in its Close (tested here).
; Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\EditorSettings.ahk
#Include ..\..\src\editor\ElementSettingsWindow.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk
#Include ..\elements\Test\_includes_engine.ahk

; The windows of the fake desktop: hwnd 101 (Notepad), 102 (Explorer); the settings window (the editor) is 900.
class FakeAssistSource {
    __New() {
        this.pointer := Map("x", 0, "y", 0, "hwnd", 0, "ctl", 0)
        this.colors := Map()
        this.infos := Map(101, Map("id", 101, "title", "Untitled - Notepad", "class", "Notepad", "exe", "notepad.exe"
                , "pid", 4321, "x", 10, "y", 20, "w", 300, "h", 200)
            , 102, Map("id", 102, "title", "Folder", "class", "CabinetWClass", "exe", "explorer.exe"
                , "pid", 555, "x", 0, "y", 0, "w", 800, "h", 600))
        this.modes := []
    }

    ; The fake mouse: the position in every mode is the same point.
    Mouse(mode) {
        this.modes.Push(mode)
        return Map("x", this.pointer["x"], "y", this.pointer["y"], "hwnd", this.pointer["hwnd"], "ctl", 0)
    }

    Color(x, y, mode, method) {
        key := x "," y
        return this.colors.Has(key) ? this.colors[key] : "0x000000"
    }

    WindowList() => [101, 102]

    WindowInfo(hwnd) => this.infos.Has(hwnd) ? this.infos[hwnd] : Map("id", hwnd, "title", "", "class", "", "exe", ""
        , "pid", 0, "x", 0, "y", 0, "w", 0, "h", 0)

    ; A point on the fake desktop: the window under it.
    Point(x, y, hwnd) {
        this.pointer["x"] := x
        this.pointer["y"] := y
        this.pointer["hwnd"] := hwnd
    }
}

AssertNot(v, msg := "") => Assert.True(!v, msg)

; The model of the controller: only the notices are used.
class AssistTestModel {
    Notice(textKey, args*) {
    }
}

TestRun.Init()

TestRun.Case("Assist: the keys of an assistant go to the ids of the form; a key without an id is dropped", ValuesToIds)
TestRun.Case("Assist: a colour text and the COLORREF of the colour dialog convert both ways", ColorFormats)
TestRun.Case("Assist: the window assistant lists the windows but not its own, and follows the mouse after it rests", WindowFollows)
TestRun.Case("Assist: OK of the window assistant gives the window identification (ids only when asked), Cancel gives nothing", WindowTake)
TestRun.Case("Assist: the mouse tracker takes the position after the mouse rests, and the colour under it", MouseTakes)
TestRun.Case("Assist: the mouse tracker gives the values it shows (the coordinate mode, the method, the colour)", MouseValues)
TestRun.Case("Assist: the mouse tracker switches its Ctrl hotkeys off when it closes, and closes twice without error", MouseHotkeysOff)
TestRun.Case("Assist: StartAssistant of the colour dialog writes the picked colour into the form by the map", StartColor)
TestRun.Case("Assist: StartAssistant of the window assistant disables the window, and OK writes the values into the form", StartWindow)
TestRun.Case("Assist: an unknown kind is refused; a second assistant is refused while one runs", StartRefusals)
TestRun.Case("Assist: discarding the settings closes a running assistant", DiscardClosesAssistant)
TestRun.Case("Assist: a Button with an assistant is enabled in the window, a Button without one stays disabled", ButtonEnabled)

ValuesToIds() {
    values := Map("Wintitle", "Untitled", "ahk_class", "Notepad", "excludeTitle", "")
    mapping := Map("Wintitle", "WinTitle", "ahk_class", "Class", "ahk_pid", "Pid")
    out := AssistantValues.ToIds(values, mapping)
    Assert.Equal(out.Count, 2, "the key ahk_pid is not in the values")
    Assert.Equal(out["WinTitle"], "Untitled")
    Assert.Equal(out["Class"], "Notepad")
    AssertNot(out.Has("Pid"))
    AssertNot(out.Has("excludeTitle"), "a value without a key in the map is dropped")
}

ColorFormats() {
    Assert.Equal(AssistantValues.ToColorref("0x112233"), 0x332211, "red is the low byte of a COLORREF")
    Assert.Equal(AssistantValues.FromColorref(0x332211), "0x112233", "and back")
    Assert.Equal(AssistantValues.FromColorref(AssistantValues.ToColorref("0xFF8000")), "0xFF8000", "round trip")
    Assert.Equal(AssistantValues.ToColorref(""), 0, "no colour yet is black")
    Assert.True(AssistantValues.IsKnown("window") && AssistantValues.IsKnown("mouse") && AssistantValues.IsKnown("color"))
    AssertNot(AssistantValues.IsKnown("help"))
}

WindowFollows() {
    src := FakeAssistSource()
    done := []
    assist := WindowAssistant(src, (values) => done.Push(values))
    assist.Open(false)
    Assert.Equal(assist.hwnds.Length, 2, "the two windows of the fake desktop, not the window of the assistant")
    src.Point(50, 50, 102)                  ; the mouse on Explorer: the first tick sees a move
    assist.Follow()
    Assert.Equal(assist.list.Value, 1, "not selected while the mouse moves")
    assist.Follow()
    assist.Follow()
    Assert.Equal(assist.list.Value, 2, "after it rested on Explorer, its entry is selected")
    src.Point(60, 50, 900)                  ; the mouse moves onto a window that is not in the list
    assist.Follow()
    Assert.Equal(assist.list.Value, 2, "a move alone does not select it")
    assist.Follow()
    assist.Follow()
    Assert.Equal(assist.list.Value, 3, "after it rested there, the window is added and selected")
    Assert.Equal(assist.hwnds.Length, 3)
    assist.Cancel()
}

WindowTake() {
    src := FakeAssistSource()
    got := []
    assist := WindowAssistant(src, (values) => got.Push(values))
    assist.Open(false)
    assist.list.Value := 1
    assist.Take()
    Assert.Equal(got.Length, 1, "OK gives one answer")
    values := got[1]
    Assert.Equal(values["Wintitle"], "Untitled - Notepad")
    Assert.Equal(values["ahk_class"], "Notepad")
    Assert.Equal(values["ahk_exe"], "notepad.exe")
    Assert.Equal(values["excludeTitle"], "", "v1 empties the excludes")
    Assert.Equal(values["ahk_id"], "", "the unique ids are not taken without the checkbox")
    Assert.Equal(values["ahk_pid"], "")
    AssertNot(IsObject(assist.gui), "OK closes the window")
    assist.Close()

    assist := WindowAssistant(src, (values) => got.Push(values))
    assist.Open(false)
    assist.list.Value := 1
    assist.importIds.Value := 1
    assist.Take()
    Assert.Equal(got[2]["ahk_id"], "101", "the window ID with the checkbox")
    Assert.Equal(got[2]["ahk_pid"], "4321", "the process ID with the checkbox")

    assist := WindowAssistant(src, (values) => got.Push(values))
    assist.Open(false)
    assist.Cancel()
    Assert.Equal(got[3].Count, 0, "Cancel gives an empty Map")
    AssertNot(IsObject(assist.gui), "and closes the window")
    Assert.True(assist.Take() = false, "a closed assistant takes nothing")
}

MouseTakes() {
    src := FakeAssistSource()
    src.colors["40,30"] := "0xABCDEF"
    got := []
    mapping := Map("xpos", "X", "ypos", "Y", "color", "C")
    assist := MouseAssistant(src, mapping, Map(), (values) => got.Push(values))
    assist.Open(false)
    src.Point(40, 30, 102)
    assist.Tick()                           ; first sight: the position is new, nothing is taken yet
    assist.Tick()
    assist.Tick()
    Assert.Equal(assist.x, "", "the mouse must rest after a move")
    assist.Tick()                           ; resting for STILL ticks after the move
    Assert.Equal(assist.x, 40, "the x position is taken after the rest")
    Assert.Equal(assist.y, 30)
    Assert.Equal(assist.color, "0xABCDEF", "the colour under the position is read")
    src.Point(90, 90, assist.gui.Hwnd)      ; the mouse over the tracker: nothing is taken
    assist.Tick()
    assist.Tick()
    assist.Tick()
    assist.Tick()
    Assert.Equal(assist.x, 40, "the mouse over the tracker does not change the position")
    assist.Take()
    Assert.Equal(got[1]["xpos"], "40")
    Assert.Equal(got[1]["ypos"], "30")
    Assert.Equal(got[1]["color"], "0xABCDEF")
    AssertNot(got[1].Has("CoordMode"), "CoordMode is not asked for by this mapping")
}

MouseValues() {
    src := FakeAssistSource()
    got := []
    mapping := Map("xpos", "X", "ypos", "Y", "CoordMode", "M", "colorGetMethod", "G")
    assist := MouseAssistant(src, mapping, Map("CoordMode", "client", "colorGetMethod", "slow"), (values) => got.Push(values))
    Assert.Equal(assist.Mode, "Client", "the initial coordinate mode is read from the form (any case)")
    Assert.Equal(assist.Method, "slow")
    assist.Open(false)
    assist._ModeChosen(1)                   ; Screen
    Assert.Equal(assist.Mode, "Screen")
    assist._MethodChosen(2)                 ; alt
    Assert.Equal(assist.Method, "alt")
    src.Point(7, 8, 102)
    assist.Tick()
    assist.Tick()
    assist.Tick()
    assist.Tick()
    assist.Take()
    Assert.Equal(got[1]["CoordMode"], "Screen", "the mode the window shows")
    Assert.Equal(got[1]["colorGetMethod"], "alt", "the method the window shows")
    Assert.True(src.modes.Length > 0 && src.modes[1] = "Screen", "the reads use the mode the user chose")
    AssertNot(got[1].Has("color"), "no colour without a colour in the mapping")
}

MouseHotkeysOff() {
    src := FakeAssistSource()
    assist := MouseAssistant(src, Map("xpos", "X", "ypos", "Y"), Map(), (values) => 0)
    assist.Open(false)
    Assert.True(assist.hotOn, "the Ctrl cursor keys are on while the tracker is open")
    assist.Close()
    AssertNot(assist.hotOn, "and off after Close")
    assist.Close()                          ; a second Close does nothing
    assist.Cancel()
}

StartColor() {
    settings := EditorSettings(AssistTestModel())
    Assert.True(settings.OpenNew("action", "Test.Action_TestForm", 0, 0, "", ""), "the settings open")
    saved := ColorAssistant.Pick
    ColorAssistant.Pick := (current, owner) => (current = "0x112233" ? "0x445566" : "none")
    try {
        field := {assistant: "color", assistMap: Map("color", "Sentence")}
        settings.session["form"].SetValue("Sentence", "0x112233")
        Assert.True(settings.StartAssistant(field), "the colour dialog runs")
        Assert.Equal(settings.Form.GetValue("Sentence"), "0x445566", "the picked colour went into the form by the map")
        AssertNot(IsObject(settings.assist), "no assistant stays after a colour pick")
    } finally {
        ColorAssistant.Pick := saved
    }
    settings.Discard()
}

StartWindow() {
    settings := EditorSettings(AssistTestModel())
    settings.assistSource := FakeAssistSource()
    Assert.True(settings.OpenNew("action", "Test.Action_TestForm", 0, 0, "", ""), "the settings open")
    window := ElementSettingsWindow(0)
    settings.window := window
    window.Build(settings, "", false)
    field := {assistant: "window", assistMap: Map("Wintitle", "Sentence", "ahk_class", "Choice", "ahk_id", "Pick")}
    Assert.True(settings.StartAssistant(field), "the window assistant starts")
    Assert.True(IsObject(settings.assist), "the assistant is running")
    AssertNot(settings.StartAssistant(field), "a second assistant is refused")
    settings.assist.list.Value := 2
    settings.assist.Take()
    AssertNot(IsObject(settings.assist), "OK ends the assistant")
    Assert.Equal(settings.Form.GetValue("Sentence"), "Folder", "the title went into the form by the map")
    Assert.Equal(settings.Form.GetValue("Choice"), "CabinetWClass", "the class went into the form")
    window.Hide()
    settings.Discard()
}

StartRefusals() {
    settings := EditorSettings(AssistTestModel())
    settings.assistSource := FakeAssistSource()
    Assert.True(settings.OpenNew("action", "Test.Action_TestForm", 0, 0, "", ""), "the settings open")
    AssertNot(settings.StartAssistant({assistant: "help", assistMap: Map()}), "an unknown kind is refused")
    AssertNot(settings.StartAssistant({assistant: "", assistMap: Map()}), "a button without an assistant is refused")
    Assert.True(settings.StartAssistant({assistant: "mouse", assistMap: Map("xpos", "Sentence")}), "the mouse tracker starts")
    AssertNot(settings.StartAssistant({assistant: "window", assistMap: Map()}), "a second one is refused while one runs")
    settings.Discard()
}

DiscardClosesAssistant() {
    settings := EditorSettings(AssistTestModel())
    settings.assistSource := FakeAssistSource()
    Assert.True(settings.OpenNew("action", "Test.Action_TestForm", 0, 0, "", ""), "the settings open")
    Assert.True(settings.StartAssistant({assistant: "window", assistMap: Map()}), "the window assistant starts")
    assist := settings.assist
    settings.Discard()
    AssertNot(IsObject(settings.assist), "the assistant is gone with the settings")
    AssertNot(IsObject(assist.gui), "its window is destroyed")
}

ButtonEnabled() {
    settings := EditorSettings(AssistTestModel())
    Assert.True(settings.OpenNew("trigger", "Default.Trigger_Hotkey", 0, 0, "", ""), "the hotkey trigger opens")
    settings.SetValue("UseWindow", "WindowIsActive")       ; the window parameters are shown for a window condition
    window := ElementSettingsWindow(0)
    window.Build(settings, "", false)
    for entry in window.entries {
        if (entry["id"] = "GetWindowInformation")
            Assert.True(entry["ctls"][1].Enabled, "the window button has its assistant")
    }
    window.Hide()
    settings.Discard()
    settings := EditorSettings(AssistTestModel())
    Assert.True(settings.OpenNew("action", "Test.Action_TestForm", 0, 0, "", ""), "the test element opens")
    window := ElementSettingsWindow(0)
    window.Build(settings, "", false)
    for entry in window.entries {
        if (entry["kind"] = "button")
            AssertNot(entry["ctls"][1].Enabled, "a button without an assistant stays disabled")
    }
    window.Hide()
    settings.Discard()
}

TestRun.Finish()
