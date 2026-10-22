#Requires AutoHotkey v2.0
; Tests for the seam SystemOps (E0103, WI-0117): every function hands its arguments to the registered provider unchanged
; and returns the answer of the provider; Enter tells the provider which element and flow make the call. The real
; functions are never called here: the stub answers every call (the integration tests are tests/integration/test_system_seam.py).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\base\SystemOps.ahk

; A provider that records the name and the arguments of every call and answers with the name of the function.
class StubSystemProvider {
    calls := []

    _Record(name, args) {
        this.calls.Push([name, args])
        return name
    }

    Shutdown(flags) => this._Record("Shutdown", [flags])
    LockWorkStation() => this._Record("LockWorkStation", [])
    Hibernate(force := 0) => this._Record("Hibernate", [force])
    Suspend(force := 0) => this._Record("Suspend", [force])
    DriveEject(args*) => this._Record("DriveEject", args)
    DriveSetLabel(args*) => this._Record("DriveSetLabel", args)
    DriveLock(args*) => this._Record("DriveLock", args)
    DriveUnlock(args*) => this._Record("DriveUnlock", args)
    FileRecycleEmpty(args*) => this._Record("FileRecycleEmpty", args)
    ChangeDisplaySettings(args*) => this._Record("ChangeDisplaySettings", args)
    SoundBeep(args*) => this._Record("SoundBeep", args)
    SoundPlay(args*) => this._Record("SoundPlay", args)
    SoundSetMute(args*) => this._Record("SoundSetMute", args)
    SoundSetVolume(args*) => this._Record("SoundSetVolume", args)
    SpeakText(text, rate, volume, wait) => this._Record("SpeakText", [text, rate, volume, wait])
    SpeechVoices() => this._Record("SpeechVoices", [])
    BlockInput(args*) => this._Record("BlockInput", args)
    Click(args*) => this._Record("Click", args)
    MouseClickDrag(args*) => this._Record("MouseClickDrag", args)
    MouseMove(args*) => this._Record("MouseMove", args)
    Send(keys, mode) => this._Record("Send", [keys, mode])
    SetCapsLockState(args*) => this._Record("SetCapsLockState", args)
    SetNumLockState(args*) => this._Record("SetNumLockState", args)
    SetScrollLockState(args*) => this._Record("SetScrollLockState", args)
    TimeIdle() => this._Record("TimeIdle", [])
    TimeIdlePhysical() => this._Record("TimeIdlePhysical", [])
}

TestRun.Init()

TestRun.Case("every group passes its arguments on and returns the answer of the provider", () => (
    p := StubSystemProvider(),
    SystemOps.UseProvider(p),
    Assert.Equal(SystemOps.Shutdown(4), "Shutdown"),
    Assert.Equal(SystemOps.LockWorkStation(), "LockWorkStation"),
    Assert.Equal(SystemOps.Hibernate(), "Hibernate"),
    Assert.Equal(SystemOps.DriveEject("E:", 1), "DriveEject"),
    Assert.Equal(SystemOps.FileRecycleEmpty("C:\"), "FileRecycleEmpty"),
    Assert.Equal(SystemOps.SoundBeep(800, 100), "SoundBeep"),
    Assert.Equal(SystemOps.SpeakText("hi", 1, 50, 0), "SpeakText"),
    Assert.Equal(SystemOps.BlockInput("On"), "BlockInput"),
    Assert.Equal(SystemOps.Send("{Enter}", "Input"), "Send"),
    Assert.Equal(SystemOps.MouseMove(10, 20, 0), "MouseMove"),
    Assert.Equal(SystemOps.SetCapsLockState("AlwaysOff"), "SetCapsLockState"),
    Assert.Equal(SystemOps.TimeIdle(), "TimeIdle"),
    Assert.Equal(p.calls[1][2][1], 4, "Shutdown gets its flags"),
    Assert.Equal(p.calls[4][2].Length, 2, "a variadic call passes all its arguments"),
    Assert.Equal(p.calls[9][2][2], "Input", "Send passes its mode"),
    Assert.Equal(p.calls[10][2].Length, 3),
    Assert.Equal(p.calls[11][2][1], "AlwaysOff"),
    Assert.Equal(p.calls.Length, 12),
    SystemOps.UseProvider("")
))

TestRun.Case("Enter gives the provider the element and the flow of the call", () => (
    p := StubSystemProvider(),
    SystemOps.UseProvider(p),
    SystemOps.Enter("flow-1", "elem-2"),
    Assert.Equal(SystemOps.flowId, "flow-1"),
    Assert.Equal(SystemOps.elementId, "elem-2"),
    SystemOps.UseProvider("")
))

TestRun.Case("a provider is replaced and removed again", () => (
    SystemOps.UseProvider(StubSystemProvider()),
    Assert.True(IsObject(SystemOps.provider)),
    SystemOps.UseProvider(""),
    Assert.Equal(SystemOps.provider, "")
))

TestRun.Finish()
