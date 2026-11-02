#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk  ; AhfError of the screen function (also included by AhfElement.ahk; once per script)
#Include MonitorDdc.ahk        ; the DDC/CI settings behind the screen functions (WI-0127)

; The indirection for the actions of elements that disturb the computer or cannot be undone (E0103, WI-0117): shutdown,
; locking, ejecting drives, emptying the recycle bin, the screen, sound and speech, blocking the input, the mouse and the
; keyboard of the whole desktop, and the idle time of the user. An element never calls these functions itself; it calls
; SystemOps.<name> with the arguments of the AutoHotkey function of the same name (doc/ELEMENT-API-V2.md 3.3a).
;
; The product uses the real functions (SystemOps.Real). The test entries of the worker and the trigger host register a
; provider (SystemOps.UseProvider, tests/integration/helpers/TestSystemProvider.ahk), which records every call and answers
; from a script, so an element runs headless and never shuts down, locks, ejects, moves the mouse or makes a sound.
; arch_check.py (rule system-seam) forbids the direct calls in src/elements/ and UseProvider everywhere in src/.
;
; Return values are those of the AutoHotkey function (nothing where it returns nothing). Keep the functions sorted by
; group; a new function is added here and in doc/ELEMENT-API-V2.md 3.3a in the same commit.
class SystemOps {
    static provider := ""
    static _realOps := ""
    static speaker := ""                ; the SAPI voice of this process (SpeakText), created on the first speech
    static inputBlocked := false        ; this process has blocked the input and not released it (WI-0126, ReleaseInput)
    static flowId := ""
    static elementId := ""

    ; Registers the provider of the process. "" restores the real functions. Called by test entries only (rule system-seam).
    static UseProvider(provider) {
        SystemOps.provider := provider
    }

    ; Called before an element runs (ElementRunner, the trigger host): the provider logs the element and flow of a call.
    static Enter(flowId, elementId) {
        SystemOps.flowId := flowId
        SystemOps.elementId := elementId
    }

    ; --- power and session -------------------------------------------------------------------------------------------
    static Shutdown(flags) => SystemOps._Provider().Shutdown(flags)
    static LockWorkStation() => SystemOps._Provider().LockWorkStation()
    static Hibernate(force := 0) => SystemOps._Provider().Hibernate(force)
    static Suspend(force := 0) => SystemOps._Provider().Suspend(force)

    ; --- drives ------------------------------------------------------------------------------------------------------
    static DriveEject(args*) => SystemOps._Provider().DriveEject(args*)
    static DriveSetLabel(args*) => SystemOps._Provider().DriveSetLabel(args*)
    static DriveLock(args*) => SystemOps._Provider().DriveLock(args*)
    static DriveRetract(args*) => SystemOps._Provider().DriveRetract(args*)
    static DriveUnlock(args*) => SystemOps._Provider().DriveUnlock(args*)

    ; --- recycle bin -------------------------------------------------------------------------------------------------
    static FileRecycle(args*) => SystemOps._Provider().FileRecycle(args*)
    static FileRecycleEmpty(args*) => SystemOps._Provider().FileRecycleEmpty(args*)

    ; --- screen ------------------------------------------------------------------------------------------------------
    static MonitorCount() => SystemOps._Provider().MonitorCount()
    static MonitorGetSetting(monitor, name, channel := 0) =>
        SystemOps._Provider().MonitorGetSetting(monitor, name, channel)
    static MonitorSetSetting(monitor, name, value, channel := 0) =>
        SystemOps._Provider().MonitorSetSetting(monitor, name, value, channel)

    ; --- sound and speech --------------------------------------------------------------------------------------------
    static SoundBeep(args*) => SystemOps._Provider().SoundBeep(args*)
    static SoundPlay(args*) => SystemOps._Provider().SoundPlay(args*)
    static SoundSetMute(args*) => SystemOps._Provider().SoundSetMute(args*)
    static SoundSetVolume(args*) => SystemOps._Provider().SoundSetVolume(args*)
    static SoundStop() => SystemOps._Provider().SoundStop()
    static SpeakText(text, voice := "", rate := 0, volume := 100, pitch := 0, wait := 1, purge := 0) =>
        SystemOps._Provider().SpeakText(text, voice, rate, volume, pitch, wait, purge)
    static SpeechVoices() => SystemOps._Provider().SpeechVoices()
    static SpeechWait() => SystemOps._Provider().SpeechWait()

    ; --- input (the whole desktop) -----------------------------------------------------------------------------------
    ; "On" or "Off" (the element passes only these). The state is remembered, so ReleaseInput can undo a block of this process.
    static BlockInput(state) {
        SystemOps._Provider().BlockInput(state)
        SystemOps.inputBlocked := (state = "On")
    }

    ; Ends a block of this process (WI-0126): the worker calls it when it shuts down, so that no input stays blocked after
    ; the worker has ended. A process that has not blocked the input does nothing.
    static ReleaseInput() {
        if (SystemOps.inputBlocked)
            SystemOps.BlockInput("Off")
    }

    static Click(args*) => SystemOps._Provider().Click(args*)
    static MouseClickDrag(args*) => SystemOps._Provider().MouseClickDrag(args*)
    static MouseGetPos(flag := 0) => SystemOps._Provider().MouseGetPos(flag)
    static MouseMove(args*) => SystemOps._Provider().MouseMove(args*)
    static Send(keys, mode := "") => SystemOps._Provider().Send(keys, mode)
    static SetCapsLockState(args*) => SystemOps._Provider().SetCapsLockState(args*)
    static SetNumLockState(args*) => SystemOps._Provider().SetNumLockState(args*)
    static SetScrollLockState(args*) => SystemOps._Provider().SetScrollLockState(args*)

    ; --- windows of the desktop (WI-0125): every window of the user, not one of the element ---------------------------
    static WinMinimizeAll() => SystemOps._Provider().WinMinimizeAll()
    static WinMinimizeAllUndo() => SystemOps._Provider().WinMinimizeAllUndo()

    ; --- idle time of the user (milliseconds) ------------------------------------------------------------------------
    static TimeIdle() => SystemOps._Provider().TimeIdle()
    static TimeIdlePhysical() => SystemOps._Provider().TimeIdlePhysical()

    static _Provider() {
        if (IsObject(SystemOps.provider))
            return SystemOps.provider
        if (!IsObject(SystemOps._realOps))
            SystemOps._realOps := SystemOps.Real()
        return SystemOps._realOps
    }

    ; The text as XML character data (for SAPI, SpeakText): &, < and > become entities.
    static _XmlEscape(text) {
        text := StrReplace(text, "&", "&amp;")
        text := StrReplace(text, "<", "&lt;")
        return StrReplace(text, ">", "&gt;")
    }

    ; The real functions: the built-in functions, called with the same arguments. The only place in src/elements/ that
    ; may call them (exempt from the arch rules, tools/arch_check.py). Nothing here runs in a test: the test entries
    ; register a provider.
    class Real {
        Shutdown(flags) {
            return Shutdown(flags)
        }

        LockWorkStation() {
            return DllCall("LockWorkStation")
        }

        ; SetSuspendState (PowrProf): hibernate when the first argument is 1, suspend (sleep) when it is 0.
        Hibernate(force := 0) {
            return DllCall("PowrProf\SetSuspendState", "int", 1, "int", force, "int", 0)
        }

        Suspend(force := 0) {
            return DllCall("PowrProf\SetSuspendState", "int", 0, "int", force, "int", 0)
        }

        DriveEject(args*) {
            return DriveEject(args*)
        }

        DriveSetLabel(args*) {
            return DriveSetLabel(args*)
        }

        DriveLock(args*) {
            return DriveLock(args*)
        }

        DriveRetract(args*) {
            return DriveRetract(args*)
        }

        DriveUnlock(args*) {
            return DriveUnlock(args*)
        }

        FileRecycle(args*) {
            return FileRecycle(args*)
        }

        FileRecycleEmpty(args*) {
            return FileRecycleEmpty(args*)
        }

        ; The number of monitors (GetSystemMetrics SM_CMONITORS).
        MonitorCount() {
            return DllCall("user32\GetSystemMetrics", "Int", 80, "Int")
        }

        ; The DDC/CI settings of a monitor (MonitorDdc.ahk): a Map with current, min and max.
        MonitorGetSetting(monitor, name, channel := 0) {
            return MonitorDdc.Get(monitor, name, channel)
        }

        MonitorSetSetting(monitor, name, value, channel := 0) {
            MonitorDdc.Set(monitor, name, value, channel)
        }

        SoundBeep(args*) {
            return SoundBeep(args*)
        }

        SoundPlay(args*) {
            return SoundPlay(args*)
        }

        SoundSetMute(args*) {
            return SoundSetMute(args*)
        }

        SoundSetVolume(args*) {
            return SoundSetVolume(args*)
        }

        ; Stops the sound of this process: AutoHotkey stops the playing file when it plays a file that does not exist
        ; (SoundPlay remarks), and the error of that call is expected. A sound of another process is not reached (M-0131).
        SoundStop() {
            try SoundPlay("ahf-no-such-sound.wav")
        }

        ; SAPI through COM (WI-0124). The voice object lives as long as the process: a speech that does not wait goes on
        ; after the job has ended, and the next speech of this process reuses the object. voice "" is the default voice;
        ; rate -10 to 10, volume 0 to 100, pitch -10 to 10 (an XML tag in front of the text). wait 1 returns when the text
        ; is spoken; purge 1 stops the speech of this process before the text starts (SPF_PURGEBEFORESPEAK).
        SpeakText(text, voice := "", rate := 0, volume := 100, pitch := 0, wait := 1, purge := 0) {
            if (!IsObject(SystemOps.speaker))
                SystemOps.speaker := ComObject("SAPI.SpVoice")
            sp := SystemOps.speaker
            if (voice != "")
                sp.Voice := sp.GetVoices("Name=" voice).Item(0)
            sp.Rate := rate
            sp.Volume := volume
            flags := 8                          ; SPF_IS_XML: the text is written as XML (the pitch tag, escaped text)
            if (!wait)
                flags |= 1                      ; SPF_ASYNC
            if (purge)
                flags |= 2                      ; SPF_PURGEBEFORESPEAK
            sp.Speak("<pitch absmiddle='" Integer(pitch) "'/>" SystemOps._XmlEscape(text), flags)
        }

        ; The names of the voices installed on the machine (the Name attribute, which SpeakText takes).
        SpeechVoices() {
            names := []
            tokens := ComObject("SAPI.SpVoice").GetVoices()
            loop tokens.Count
                names.Push(tokens.Item(A_Index - 1).GetAttribute("Name"))
            return names
        }

        ; Returns when the speech of this process has ended (SAPI RunningState 2 = reading, v1 Default_Lib_TTS).
        SpeechWait() {
            if (!IsObject(SystemOps.speaker))
                return
            while (SystemOps.speaker.Status.RunningState = 2)
                Sleep(50)    ; arch-ok: blocking the speech wait runs in a worker only (the engine never calls SpeechWait)
        }

        BlockInput(args*) {
            return BlockInput(args*)
        }

        Click(args*) {
            return Click(args*)
        }

        MouseClickDrag(args*) {
            return MouseClickDrag(args*)
        }

        ; The mouse position and the window and control under it: [x, y, window, control]. flag 2 gives the handle of the
        ; control (as v1 Get mouse position), 0 its ClassNN. The position is read only (no change of the desktop).
        MouseGetPos(flag := 0) {
            MouseGetPos(&x, &y, &win, &ctrl, flag)
            return [x, y, win, ctrl]
        }

        MouseMove(args*) {
            return MouseMove(args*)
        }

        ; mode (Input, Event, Play, Raw) sets SendMode for this call only; "" keeps the current mode.
        Send(keys, mode := "") {
            if (mode = "")
                return Send(keys)
            previous := A_SendMode
            SendMode(mode)
            try {
                return Send(keys)
            } finally {
                SendMode(previous)
            }
        }

        SetCapsLockState(args*) {
            return SetCapsLockState(args*)
        }

        SetNumLockState(args*) {
            return SetNumLockState(args*)
        }

        SetScrollLockState(args*) {
            return SetScrollLockState(args*)
        }

        WinMinimizeAll() {
            return WinMinimizeAll()
        }

        WinMinimizeAllUndo() {
            return WinMinimizeAllUndo()
        }

        TimeIdle() {
            return A_TimeIdle
        }

        TimeIdlePhysical() {
            return A_TimeIdlePhysical
        }
    }
}
