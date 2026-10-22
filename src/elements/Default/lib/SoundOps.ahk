#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The shared functions of the sound and speech elements of the package Default (WI-0124): the system sounds and the
; speech voices for the drop-downs, and the path of a system sound. The elements that play sounds or speak are workers
; (ARCHITECTURE 2.3) and call the seam SystemOps for every call that makes a sound (E0103).
;
; The lists are read only with a context (the editor): the engine calls Parameters("") to convert the flows and must not
; read the media folder or ask the speech engine (ELEMENT-API-V2 section 2, Parameters).
class SoundOps {
    ; The file names of the system sounds (the folder %WinDir%\media), for the drop-down of Play sound.
    static SystemSounds(ctx) {
        names := []
        if (!IsObject(ctx))
            return names
        try {
            loop files A_WinDir "\media\*"    ; arch-ok: file-io the system sounds for the drop-down (an editor list; the engine passes no context)
                names.Push(A_LoopFileName)
        }
        return names
    }

    ; The full path of a system sound (v1: a_windir "\media\" name).
    static SystemSoundPath(name) => A_WinDir "\media\" name

    ; The names of the speech voices for the drop-down of Speech output, with a context only (see above).
    static Voices(ctx) {
        if (!IsObject(ctx))
            return []
        try return SystemOps.SpeechVoices()
        catch
            return []
    }

    ; True when the speech voice of that name is installed.
    static HasVoice(name) {
        try {
            for voice in SystemOps.SpeechVoices() {
                if (voice = name)
                    return true
            }
        }
        return false
    }
}
