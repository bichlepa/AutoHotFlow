; Returns the path of AHF
GetAhfPath()
{
	if fileexist(_ScriptDir "\AutoHotFlow.exe")
	{
		return _ScriptDir "\AutoHotFlow.exe"
	}
	else if fileexist(_ScriptDir "\AutoHotFlow.ahk")
	{
		return _ScriptDir "\AutoHotFlow.ahk"
	}
	else
	{
		logger("a0", "Can't find AutoHotflow.exe")
		return
	}
}

; sets the icon of a GUI.
; before call of this function, the command has to be called: gui, +LastFound
setGuiIcon(iconPath)
{
	global 

	local hIcon := DllCall("LoadImage", uint, 0, str, iconPath, uint, 1, int, 0, int, 0, uint, 0x10)

	SendMessage 0x80, 0, hIcon  ; 0x80 is WM_SETICON; and 1 means ICON_BIG (vs. 0 for ICON_SMALL).
	SendMessage 0x80, 1, hIcon  ; 0x80 is WM_SETICON; and 1 means ICON_BIG (vs. 0 for ICON_SMALL).
}