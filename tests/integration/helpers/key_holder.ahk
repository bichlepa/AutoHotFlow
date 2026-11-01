#Requires AutoHotkey v2.0
#SingleInstance Off
; Holds one key down for the test of Condition_Key_Is_Down (WI-0126): Send "{key down}" with the key of the first argument
; (an unassigned key, for example vk88, so that no window reacts to it). Args: key, ready file, stop file. The key is
; released when the stop file exists, and the script ends then. The test holds the input lock while this runs
; (tests/support/inputlock.py), so no other input test sends keys meanwhile.
key := A_Args[1]
readyPath := A_Args[2]
stopPath := A_Args[3]
Send("{" key " down}")
FileAppend("ready`n", readyPath, "UTF-8")
SetTimer(CheckStop, 100)

CheckStop() {
    if FileExist(stopPath) {
        Send("{" key " up}")
        ExitApp(0)
    }
}
