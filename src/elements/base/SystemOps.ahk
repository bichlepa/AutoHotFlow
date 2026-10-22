#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk  ; AhfError of the screen function (also included by AhfElement.ahk; once per script)

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
    static DriveUnlock(args*) => SystemOps._Provider().DriveUnlock(args*)

    ; --- recycle bin -------------------------------------------------------------------------------------------------
    static FileRecycle(args*) => SystemOps._Provider().FileRecycle(args*)
    static FileRecycleEmpty(args*) => SystemOps._Provider().FileRecycleEmpty(args*)

    ; --- screen ------------------------------------------------------------------------------------------------------
    static ChangeDisplaySettings(args*) => SystemOps._Provider().ChangeDisplaySettings(args*)

    ; --- sound and speech --------------------------------------------------------------------------------------------
    static SoundBeep(args*) => SystemOps._Provider().SoundBeep(args*)
    static SoundPlay(args*) => SystemOps._Provider().SoundPlay(args*)
    static SoundSetMute(args*) => SystemOps._Provider().SoundSetMute(args*)
    static SoundSetVolume(args*) => SystemOps._Provider().SoundSetVolume(args*)
    static SpeakText(text, rate := 0, volume := 100, wait := 1) => SystemOps._Provider().SpeakText(text, rate, volume, wait)
    static SpeechVoices() => SystemOps._Provider().SpeechVoices()

    ; --- input (the whole desktop) -----------------------------------------------------------------------------------
    static BlockInput(args*) => SystemOps._Provider().BlockInput(args*)
    static Click(args*) => SystemOps._Provider().Click(args*)
    static MouseClickDrag(args*) => SystemOps._Provider().MouseClickDrag(args*)
    static MouseMove(args*) => SystemOps._Provider().MouseMove(args*)
    static Send(keys, mode := "") => SystemOps._Provider().Send(keys, mode)
    static SetCapsLockState(args*) => SystemOps._Provider().SetCapsLockState(args*)
    static SetNumLockState(args*) => SystemOps._Provider().SetNumLockState(args*)
    static SetScrollLockState(args*) => SystemOps._Provider().SetScrollLockState(args*)

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

        DriveUnlock(args*) {
            return DriveUnlock(args*)
        }

        FileRecycle(args*) {
            return FileRecycle(args*)
        }

        FileRecycleEmpty(args*) {
            return FileRecycleEmpty(args*)
        }

        ; Not implemented yet: the screen settings come with WI-0127 (DEVMODE handling). An element that calls it ends
        ; with "exception" until then.
        ChangeDisplaySettings(args*) {
            throw AhfError("ChangeDisplaySettings is not implemented yet (WI-0127)", ErrCode.NOT_FOUND)
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

        ; SAPI through COM. wait 1 returns when the text is spoken; rate -10 to 10, volume 0 to 100.
        SpeakText(text, rate := 0, volume := 100, wait := 1) {
            voice := ComObject("SAPI.SpVoice")
            voice.Rate := rate
            voice.Volume := volume
            voice.Speak(text, wait ? 0 : 1)     ; SPF_ASYNC (1) when not waiting
        }

        ; The descriptions of the voices installed on the machine (for a drop-down).
        SpeechVoices() {
            voices := []
            tokens := ComObject("SAPI.SpVoice").GetVoices()
            loop tokens.Count
                voices.Push(tokens.Item(A_Index - 1).GetDescription())
            return voices
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

        TimeIdle() {
            return A_TimeIdle
        }

        TimeIdlePhysical() {
            return A_TimeIdlePhysical
        }
    }
}
